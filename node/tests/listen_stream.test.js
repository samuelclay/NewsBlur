// node/tests/listen_stream.test.js: runs the Listen stream handler (node/listen.coffee, compiled to node/listen.js)
// against a fake Redis, ElevenLabs and S3, so its locking, generation budget and timeouts are checked offline.
const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');

const log = require('../log.js');
const { listen } = require('../listen.js');

const JOB_ID = 'a'.repeat(32);
const CACHE_KEY = 'segment-key';
const JOB_KEY = `listen:job:${JOB_ID}`;
const LOCK_KEY = `listen:lock:${CACHE_KEY}`;
const CACHED_KEY = `listen:cached:${CACHE_KEY}`;
const GENERATIONS_KEY = `listen:generations:${JOB_ID}`;
const S3_PUT_URL = 'https://s3.test/put';
const S3_GET_URL = 'https://s3.test/get';
// The handler's waits, shortened from production's seconds (node/listen.coffee DEFAULT_TIMING) to milliseconds.
const TIMING = {
    wait_for_cache_ms: 100,
    poll_ms: 5,
    speech_response_ms: 50,
    speech_stall_ms: 50,
    speech_deadline_ms: 300,
    s3_upload_ms: 50
};
// Long enough for every timeout above, short enough that a handler stuck forever fails the test quickly.
const HANDLER_LIMIT_MS = 2000;

test.mock.method(log, 'debug', function () {});
process.env.ELEVENLABS_API_KEY = 'test-key';

// A node-redis v3 style client (callback last) holding keys in memory, with a clock tests can move forward.
function make_redis(initial) {
    const store = new Map(Object.entries(initial || {}));
    const expires_at = new Map();
    let now = 0;
    const redis = {
        store: store,
        after_get: null,
        on: function () {},
        advance: function (seconds) {
            now += seconds * 1000;
            for (const [key, at] of expires_at) {
                if (at <= now) {
                    store.delete(key);
                    expires_at.delete(key);
                }
            }
        },
        get: function (key, callback) {
            const value = store.has(key) ? store.get(key) : null;
            if (redis.after_get) redis.after_get(key);
            reply(callback, value);
        },
        set: function (key, value, ...args) {
            const callback = args.pop();
            const nx = args.includes('NX');
            const ex_index = args.indexOf('EX');
            if (nx && store.has(key)) return reply(callback, null);
            store.set(key, String(value));
            expires_at.delete(key);
            if (ex_index >= 0) expires_at.set(key, now + Number(args[ex_index + 1]) * 1000);
            reply(callback, 'OK');
        },
        del: function (key, callback) {
            const existed = store.delete(key);
            expires_at.delete(key);
            reply(callback, existed ? 1 : 0);
        },
        incr: function (key, callback) {
            const value = Number(store.get(key) || 0) + 1;
            store.set(key, String(value));
            reply(callback, value);
        },
        expire: function (key, seconds, callback) {
            if (!store.has(key)) return reply(callback, 0);
            expires_at.set(key, now + seconds * 1000);
            reply(callback, 1);
        },
        ttl: function (key, callback) {
            if (!store.has(key)) return reply(callback, -2);
            if (!expires_at.has(key)) return reply(callback, -1);
            reply(callback, Math.ceil((expires_at.get(key) - now) / 1000));
        }
    };
    return redis;
}

function reply(callback, value) {
    setImmediate(function () {
        callback(null, value);
    });
}

function job_record(overrides) {
    return JSON.stringify(Object.assign({
        user_id: 1,
        text: 'A paragraph of the story.',
        previous_text: '',
        next_text: '',
        voice_id: 'voice-premade',
        fallback_voice_id: null,
        is_premade_voice: true,
        model_id: 'eleven_v4_turbo',
        language_code: 'en',
        voice_settings: { stability: 0.5 },
        output_format: 'mp3_44100_64',
        cache_key: CACHE_KEY,
        s3_put_url: S3_PUT_URL,
        s3_get_url: S3_GET_URL
    }, overrides));
}

function bytes(text) {
    return new TextEncoder().encode(text);
}

// Scripted ElevenLabs replies. Each is called with the fetch options and returns what fetch would.
const speech = {
    audio: function (...parts) {
        return function () {
            const body = new ReadableStream({
                start: function (controller) {
                    parts.forEach(function (part) { controller.enqueue(bytes(part)); });
                    controller.close();
                }
            });
            return Promise.resolve(new Response(body, { status: 200 }));
        };
    },
    status: function (code, detail) {
        return function () {
            return Promise.resolve(new Response(detail || 'Service unavailable', { status: code }));
        };
    },
    network_error: function () {
        return function () {
            return Promise.reject(new TypeError('fetch failed'));
        };
    },
    // Accepts the connection, then never sends headers. Ignores the abort signal on purpose: the handler must give
    // up on its own, and the test checks separately that it aborted the signal so the real fetch drops the socket.
    no_response: function () {
        return function () {
            return new Promise(function () {});
        };
    },
    // Sends headers and one chunk, then goes silent with the connection still open.
    stall_after: function (part, state) {
        return function () {
            const body = new ReadableStream({
                start: function (controller) { controller.enqueue(bytes(part)); },
                cancel: function () { state.cancelled = true; }
            });
            return Promise.resolve(new Response(body, { status: 200 }));
        };
    },
    // Keeps sending a chunk every few milliseconds, far past any deadline. It does end after HANDLER_LIMIT_MS so a
    // handler without a deadline fails the test instead of keeping the test process alive.
    trickle: function (part, every_ms, state) {
        return function () {
            let sent = 0;
            const body = new ReadableStream({
                pull: function (controller) {
                    return new Promise(function (resolve) {
                        setTimeout(function () {
                            sent += 1;
                            if (state.cancelled) return resolve();
                            if (sent * every_ms > HANDLER_LIMIT_MS) controller.close();
                            else controller.enqueue(bytes(part));
                            resolve();
                        }, every_ms);
                    });
                },
                cancel: function () { state.cancelled = true; }
            });
            return Promise.resolve(new Response(body, { status: 200 }));
        };
    }
};

const s3 = {
    ok: function () {
        return Promise.resolve(new Response(null, { status: 200 }));
    },
    error: function () {
        return Promise.resolve(new Response('Internal error', { status: 500 }));
    },
    no_response: function () {
        return new Promise(function () {});
    }
};

function make_response() {
    return {
        statusCode: 200,
        headers: {},
        body: null,
        chunks: [],
        redirected_to: null,
        headersSent: false,
        ended: false,
        destroyed: false,
        status: function (code) {
            this.statusCode = code;
            return this;
        },
        set: function (name, value) {
            this.headers[name.toLowerCase()] = String(value);
            return this;
        },
        json: function (body) {
            this.body = body;
            this.headersSent = true;
            this.ended = true;
            return this;
        },
        redirect: function (code, url) {
            this.statusCode = code;
            this.redirected_to = url;
            this.headersSent = true;
            this.ended = true;
        },
        writeHead: function (code, headers) {
            this.statusCode = code;
            for (const name of Object.keys(headers || {})) this.headers[name.toLowerCase()] = headers[name];
            this.headersSent = true;
        },
        write: function (chunk) {
            this.chunks.push(Buffer.from(chunk));
            return true;
        },
        end: function () {
            this.ended = true;
        },
        destroy: function () {
            this.destroyed = true;
        },
        audio: function () {
            return Buffer.concat(this.chunks).toString();
        }
    };
}

function within(promise, ms, message) {
    let timer;
    const limit = new Promise(function (resolve, reject) {
        timer = setTimeout(function () { reject(new Error(message)); }, ms);
    });
    return Promise.race([promise, limit]).finally(function () { clearTimeout(timer); });
}

// Mounts node/listen.js on a fake Express app. Every request to ElevenLabs takes the next scripted reply.
function make_server(options) {
    const redis = options.redis || make_redis({ [JOB_KEY]: job_record() });
    const script = (options.speech || []).slice();
    const calls = { speech: [], s3: [] };
    const fetch = function (url, init) {
        if (url.startsWith('https://api.elevenlabs.io/')) {
            calls.speech.push({ url: url, init: init || {} });
            const next = script.shift();
            if (!next) return Promise.reject(new Error(`Unscripted ElevenLabs request to ${url}`));
            return next(init || {});
        }
        calls.s3.push({ url: url, init: init || {} });
        return (options.s3 || s3.ok)(init || {});
    };
    const routes = [];
    const app = {
        get: function (pattern, handler) {
            routes.push({ pattern: pattern, handler: handler });
        }
    };
    listen(app, { redis_client: redis, fetch: fetch, timing: TIMING });

    const request = async function (method) {
        const path = `/listen/stream/${JOB_ID}.mp3`;
        const route = routes.find(function (candidate) { return candidate.pattern.test(path); });
        const req = new EventEmitter();
        req.method = method || 'GET';
        req.params = route.pattern.exec(path).slice(1);
        const res = make_response();
        await within(route.handler(req, res), HANDLER_LIMIT_MS, 'the stream handler never finished');
        return res;
    };
    return { redis: redis, calls: calls, request: request };
}

// =============================================================
// = Timeouts on ElevenLabs and S3 (node/listen.coffee:73)     =
// =============================================================

test('gives up with 504 and releases the lock when ElevenLabs never sends headers', async function () {
    const server = make_server({ speech: [speech.no_response()] });

    const res = await server.request();

    assert.equal(res.statusCode, 504);
    assert.ok(res.body.error);
    assert.equal(server.calls.speech.length, 1);
    assert.equal(server.calls.speech[0].init.signal.aborted, true, 'the ElevenLabs fetch was not aborted');
    assert.equal(server.redis.store.has(LOCK_KEY), false, 'the generation lock leaked');
    assert.equal(server.redis.store.has(GENERATIONS_KEY), false, 'an unanswered request used up the job');
});

test('destroys the response and skips the upload when ElevenLabs stalls mid-stream', async function () {
    const state = {};
    const server = make_server({ speech: [speech.stall_after('ID3', state)] });

    const res = await server.request();

    assert.equal(res.statusCode, 200);
    assert.equal(res.audio(), 'ID3');
    assert.equal(res.destroyed, true, 'the player was not told the segment is incomplete');
    assert.equal(res.ended, false);
    assert.equal(state.cancelled, true, 'the stalled ElevenLabs body was not cancelled');
    assert.equal(server.calls.speech[0].init.signal.aborted, true, 'the ElevenLabs fetch was not aborted');
    assert.equal(server.calls.s3.length, 0, 'partial audio was uploaded');
    assert.equal(server.redis.store.has(CACHED_KEY), false);
    assert.equal(server.redis.store.has(LOCK_KEY), false, 'the generation lock leaked');
    assert.equal(server.redis.store.get(GENERATIONS_KEY), '1', 'accepted audio was not counted');
});

test('ends a generation that keeps trickling past the overall deadline', async function () {
    const state = {};
    const server = make_server({ speech: [speech.trickle('x', 10, state)] });

    const res = await server.request();

    assert.ok(res.chunks.length > 1, 'the trickle was cut off by the stall timer instead of the deadline');
    assert.equal(res.destroyed, true);
    assert.equal(state.cancelled, true);
    assert.equal(server.calls.s3.length, 0);
    assert.equal(server.redis.store.has(LOCK_KEY), false, 'the generation lock leaked');
});

test('abandons an S3 upload that never answers but still finishes the stream', async function () {
    const server = make_server({ speech: [speech.audio('ID3', 'DATA')], s3: s3.no_response });

    const res = await server.request();

    assert.equal(res.statusCode, 200);
    assert.equal(res.audio(), 'ID3DATA');
    assert.equal(res.ended, true);
    assert.equal(res.destroyed, false, 'a stream the player already received in full was destroyed');
    assert.equal(server.calls.s3.length, 1);
    assert.equal(server.calls.s3[0].init.signal.aborted, true, 'the S3 PUT was not aborted');
    assert.equal(server.redis.store.has(CACHED_KEY), false);
    assert.equal(server.redis.store.has(LOCK_KEY), false, 'the generation lock leaked');
});

// =============================================================
// = One generator per segment (node/listen.coffee:171)        =
// =============================================================

test('does not generate while another server still holds the lock', async function () {
    const redis = make_redis({ [JOB_KEY]: job_record(), [LOCK_KEY]: 'b'.repeat(32) });
    const server = make_server({ redis: redis, speech: [speech.audio('ID3')] });

    const res = await server.request();

    assert.equal(server.calls.speech.length, 0, 'a second paid generation started');
    assert.equal(res.statusCode, 503);
    assert.ok(Number(res.headers['retry-after']) > 0);
    assert.equal(redis.store.get(LOCK_KEY), 'b'.repeat(32), 'the other server lost its lock');
});

test('redirects to S3 when the other server caches the segment just as its lock frees', async function () {
    const redis = make_redis({ [JOB_KEY]: job_record(), [LOCK_KEY]: 'b'.repeat(32) });
    const server = make_server({ redis: redis, speech: [speech.audio('ID3')] });
    // The other server caches the segment and releases its lock right after this request's first check of the
    // cache while waiting (the handler's own check before taking the lock is the first read of the key).
    let cache_reads = 0;
    redis.after_get = function (key) {
        if (key !== CACHED_KEY) return;
        cache_reads += 1;
        if (cache_reads === 2) {
            redis.store.set(CACHED_KEY, JSON.stringify({ duration: 1, bytes: 8000 }));
            redis.store.delete(LOCK_KEY);
        }
    };

    const res = await server.request();

    assert.equal(server.calls.speech.length, 0, 'cached audio was generated again');
    assert.equal(res.statusCode, 302);
    assert.equal(res.redirected_to, S3_GET_URL);
    assert.equal(redis.store.has(LOCK_KEY), false, 'the generation lock leaked');
});

test('takes over when the other server gives up without caching', async function () {
    const redis = make_redis({ [JOB_KEY]: job_record(), [LOCK_KEY]: 'b'.repeat(32) });
    const server = make_server({ redis: redis, speech: [speech.audio('ID3')] });
    setTimeout(function () { redis.store.delete(LOCK_KEY); }, 20);

    const res = await server.request();

    assert.equal(res.statusCode, 200);
    assert.equal(res.audio(), 'ID3');
    assert.equal(server.calls.speech.length, 1);
    assert.ok(redis.store.has(CACHED_KEY));
    assert.equal(redis.store.has(LOCK_KEY), false);
});

// =============================================================
// = Generation budget (node/listen.coffee:173)                =
// =============================================================

test('plays after ElevenLabs recovers from a network error and a 503', async function () {
    const server = make_server({
        speech: [speech.network_error(), speech.status(503), speech.audio('ID3', 'DATA')]
    });

    const first = await server.request();
    const second = await server.request();
    const third = await server.request();

    assert.equal(third.statusCode, 200, 'temporary failures used up the job');
    assert.equal(third.audio(), 'ID3DATA');
    assert.equal(first.statusCode, 502);
    assert.equal(second.statusCode, 502);
    assert.equal(server.calls.speech.length, 3);
    assert.ok(server.redis.store.has(CACHED_KEY));
    assert.equal(server.redis.store.get(GENERATIONS_KEY), '1');
});

test('still refuses a third generation of audio that could not be cached', async function () {
    const server = make_server({
        speech: [speech.audio('ID3'), speech.audio('ID3'), speech.audio('ID3')],
        s3: s3.error
    });

    const first = await server.request();
    const second = await server.request();
    const third = await server.request();

    assert.equal(first.statusCode, 200);
    assert.equal(second.statusCode, 200);
    assert.equal(third.statusCode, 429);
    assert.equal(server.calls.speech.length, 2, 'a third paid generation started');
    assert.equal(server.redis.store.has(LOCK_KEY), false);
});

test('throttles repeated upstream failures, then lets the job retry once the window passes', async function () {
    const server = make_server({
        speech: [speech.status(503), speech.status(500), speech.status(503), speech.audio('ID3')]
    });

    for (let attempt = 0; attempt < 3; attempt++) {
        assert.equal((await server.request()).statusCode, 502);
    }
    const throttled = await server.request();

    assert.equal(throttled.statusCode, 503);
    assert.ok(Number(throttled.headers['retry-after']) > 0);
    assert.equal(server.calls.speech.length, 3, 'a throttled job still called ElevenLabs');
    assert.equal(server.redis.store.has(LOCK_KEY), false, 'the throttled request leaked the lock');

    server.redis.advance(61);
    const recovered = await server.request();

    assert.equal(recovered.statusCode, 200);
    assert.equal(recovered.audio(), 'ID3');
});

test('a library voice refusal falls back to the stand-in voice without using up the job', async function () {
    const redis = make_redis({
        [JOB_KEY]: job_record({ voice_id: 'voice-library', fallback_voice_id: 'voice-premade', is_premade_voice: false })
    });
    const server = make_server({
        redis: redis,
        speech: [speech.status(402, 'paid_plan_required'), speech.audio('ID3')]
    });

    const res = await server.request();

    assert.equal(res.statusCode, 200);
    assert.equal(res.audio(), 'ID3');
    assert.match(server.calls.speech[1].url, /\/voice-premade\/stream/);
    assert.equal(redis.store.get('listen:library_blocked'), '1');
    assert.equal(server.calls.s3.length, 0, 'the stand-in voice was cached under the library voice key');
    assert.equal(redis.store.has(JOB_KEY), false);
    assert.equal(redis.store.has(LOCK_KEY), false);
});

// =============================================================
// = Lock release on refusal (node/listen.coffee:177)          =
// =============================================================

test('releases the lock when it refuses a job that has used its generations', async function () {
    const redis = make_redis({ [JOB_KEY]: job_record(), [GENERATIONS_KEY]: '2' });
    const server = make_server({ redis: redis });

    const res = await server.request();

    assert.equal(res.statusCode, 429);
    assert.equal(server.calls.speech.length, 0);
    assert.equal(redis.store.has(LOCK_KEY), false, 'a refused job kept the generation lock');
});
