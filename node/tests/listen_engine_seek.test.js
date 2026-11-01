const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// listen_engine_seek.test.js: TimeRanges for a fake audio element, as [[start, end], ...].
function time_ranges(ranges) {
    return {
        length: ranges.length,
        start: function (i) { return ranges[i][0]; },
        end: function (i) { return ranges[i][1]; }
    };
}

// listen_engine_seek.test.js: An audio element that loads nothing until the test says so. A live
// stream from node/listen.coffee has no known duration and only what's downloaded is buffered; the
// cached S3 copy has its duration and is seekable throughout.
function make_audio_class(created) {
    function FakeAudio() {
        this.src = '';
        this.preload = '';
        this.muted = false;
        this.paused = true;
        this.currentTime = 0;
        this.duration = NaN;
        this.readyState = 0;
        this.playbackRate = 1;
        this.volume = 1;
        this.buffered = time_ranges([]);
        this.seekable = time_ranges([]);
        this.plays = 0;
        this.listeners = {};
        created.push(this);
    }
    FakeAudio.prototype.addEventListener = function (type, handler) {
        (this.listeners[type] = this.listeners[type] || []).push(handler);
    };
    FakeAudio.prototype.removeEventListener = function (type, handler) {
        this.listeners[type] = (this.listeners[type] || []).filter(function (h) { return h !== handler; });
    };
    FakeAudio.prototype.fire = function (type) {
        (this.listeners[type] || []).slice().forEach(function (handler) { handler({ type: type }); });
    };
    FakeAudio.prototype.play = function () {
        this.paused = false;
        this.plays += 1;
        return Promise.resolve();
    };
    FakeAudio.prototype.pause = function () { this.paused = true; };
    FakeAudio.prototype.load = function () {};
    FakeAudio.prototype.removeAttribute = function (name) { if (name === 'src') this.src = ''; };
    // listen_engine_seek.test.js: Node has answered with the first seconds of a live stream.
    FakeAudio.prototype.stream_started = function (buffered_seconds) {
        this.readyState = 1;
        this.duration = Infinity;
        this.buffered = time_ranges([[0, buffered_seconds]]);
        this.fire('loadedmetadata');
        this.fire('durationchange');
    };
    // listen_engine_seek.test.js: The cached copy on S3, fully seekable.
    FakeAudio.prototype.cached_loaded = function (duration) {
        this.readyState = 4;
        this.duration = duration;
        this.buffered = time_ranges([[0, duration]]);
        this.seekable = time_ranges([[0, duration]]);
        this.fire('loadedmetadata');
        this.fire('durationchange');
    };
    return FakeAudio;
}

// listen_engine_seek.test.js: setTimeout and setInterval that only run when the test advances time.
function make_clock() {
    let now = 0;
    let next_id = 1;
    const timers = new Map();
    return {
        setTimeout: function (fn, ms) {
            const id = next_id++;
            timers.set(id, { fn: fn, at: now + (ms || 0), every: null });
            return id;
        },
        setInterval: function (fn, ms) {
            const id = next_id++;
            timers.set(id, { fn: fn, at: now + ms, every: ms });
            return id;
        },
        clear: function (id) { timers.delete(id); },
        tick: function (ms) {
            const end = now + ms;
            for (;;) {
                let due = null;
                for (const [id, timer] of timers) {
                    if (timer.at <= end && (!due || timer.at < due[1].at)) due = [id, timer];
                }
                if (!due) break;
                const [id, timer] = due;
                now = timer.at;
                if (timer.every) timer.at += timer.every;
                else timers.delete(id);
                timer.fn();
            }
            now = end;
        }
    };
}

// listen_engine_seek.test.js: Three paragraphs the manifest estimates at 20 seconds each, none
// generated yet. Each /listen/segment answer is the live node stream unless the test marks the
// segment cached.
function load_engine(options) {
    options = options || {};
    const created = [];
    const clock = make_clock();
    const cached = options.cached || {};
    const manifest = {
        code: 1,
        manifest_id: 'manifest-1',
        expires_at: Date.now() / 1000 + 3600,
        story_hash: '42:abcdef',
        language: 'en',
        voice: { voice_id: 'voice-1', name: 'Jon' },
        segments: [0, 1, 2].map(function (index) {
            return { index: index, paragraphs: [index], duration: 20, estimated: true, cached: false };
        })
    };
    const segment_requests = [];
    const context = {
        NEWSBLUR: {
            assets: {
                listen_manifest: function (params, callback) { callback(manifest); },
                listen_segment: function (manifest_id, index, callback) {
                    segment_requests.push(index);
                    if (cached[index]) {
                        callback({ code: 1, index: index, url: 'https://s3.example/' + index + '.mp3', cached: true, duration: cached[index] });
                    } else {
                        callback({ code: 1, index: index, url: '/listen/stream/job' + index + '.mp3', cached: false, duration: null });
                    }
                },
                listen_progress: function () {}
            },
            Globals: {}
        },
        Audio: make_audio_class(created),
        window: { console: console },
        navigator: {},
        console: console,
        Promise: Promise,
        Date: Date,
        setTimeout: clock.setTimeout,
        clearTimeout: clock.clear,
        setInterval: clock.setInterval,
        clearInterval: clock.clear,
        gettext: function (message) { return message; },
        ngettext: function (one, many, count) { return count === 1 ? one : many; },
        interpolate: function (message) { return message; }
    };
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/vendor/underscore-1.4.3.js'), 'utf8'), context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/newsblur/common/listen_engine.js'), 'utf8'), context);
    const engine = new context.NEWSBLUR.ListenEngine({ story_hash: '42:abcdef' });
    return { engine: engine, created: created, clock: clock, segment_requests: segment_requests };
}

function latest(created) {
    return created[created.length - 1];
}

test('scrubbing ahead into a paragraph that is still being generated reads it from its start', function () {
    const { engine, created, clock } = load_engine();
    engine.play();
    latest(created).stream_started(3);

    // listen_engine_seek.test.js: 52s is 12s into the third paragraph by the manifest's estimate,
    // which can lie past that paragraph's real end, so the stream may never reach it.
    engine.seek(52);
    clock.tick(1000);
    const audio = latest(created);
    assert.equal(audio.src, '/listen/stream/job2.mp3');
    audio.stream_started(2);
    clock.tick(1000);

    assert.equal(audio.muted, false, 'the paragraph plays out loud instead of waiting in silence');
    assert.equal(audio.paused, false);
    assert.ok(audio.currentTime < 0.25, 'it starts at the beginning of the paragraph, got ' + audio.currentTime);
    assert.equal(engine.get_current_time(), 40, 'the scrubber snaps to the start of the paragraph it reads');
});

test('scrubbing ahead into the buffered next paragraph that is still streaming reads it from its start', function () {
    const { engine, created, clock } = load_engine();
    engine.play();
    const first = latest(created);
    first.stream_started(5);
    first.fire('playing');
    const next = latest(created);
    assert.equal(next.src, '/listen/stream/job1.mp3', 'the next paragraph is buffered while the first plays');
    next.stream_started(3);

    engine.seek(30);
    clock.tick(1000);

    assert.equal(latest(created), next, 'the buffered stream is used rather than asked for again');
    assert.equal(next.muted, false, 'the paragraph plays out loud instead of waiting in silence');
    assert.equal(next.paused, false);
    assert.ok(next.currentTime < 0.25, 'it starts at the beginning of the paragraph, got ' + next.currentTime);
    assert.equal(engine.get_current_time(), 20, 'the scrubber snaps to the start of the paragraph it reads');
});

test('scrubbing into a paragraph whose audio is cached still lands on the exact spot', function () {
    const { engine, created, clock } = load_engine({ cached: { 2: 20 } });
    engine.play();
    latest(created).stream_started(3);

    engine.seek(52);
    clock.tick(1000);
    const audio = latest(created);
    assert.equal(audio.src, 'https://s3.example/2.mp3');
    audio.cached_loaded(20);
    clock.tick(1000);

    assert.equal(audio.muted, false);
    assert.equal(audio.paused, false);
    assert.equal(audio.currentTime, 12);
    assert.equal(engine.get_current_time(), 52);
});

test('a paused seek into a paragraph that is still being generated remembers the spot, then reads it from its start', function () {
    const { engine, created, clock, segment_requests } = load_engine();
    engine.play();
    latest(created).stream_started(3);
    engine.pause();

    engine.seek(52);
    clock.tick(1000);
    assert.deepEqual(segment_requests, [0], 'nothing is asked for while paused');
    assert.equal(engine.get_current_time(), 52, 'the paused scrubber stays where it was dropped');

    engine.play();
    const audio = latest(created);
    assert.equal(audio.src, '/listen/stream/job2.mp3');
    audio.stream_started(2);
    clock.tick(1000);

    assert.equal(audio.muted, false);
    assert.equal(audio.paused, false);
    assert.ok(audio.currentTime < 0.25, 'it starts at the beginning of the paragraph, got ' + audio.currentTime);
    assert.equal(engine.get_current_time(), 40);
});

test('resuming partway into a paragraph that is still being generated reads it from its start', function () {
    const { engine, created, clock, segment_requests } = load_engine();
    // listen_engine_seek.test.js: media_player_view.js play_media seeks to the saved position before
    // the manifest has loaded.
    engine.seek(52);
    engine.play();
    const audio = latest(created);
    assert.deepEqual(segment_requests, [2]);
    audio.stream_started(2);
    clock.tick(1000);

    assert.equal(audio.muted, false);
    assert.equal(audio.paused, false);
    assert.ok(audio.currentTime < 0.25, 'it starts at the beginning of the paragraph, got ' + audio.currentTime);
    assert.equal(engine.get_current_time(), 40);
});

test('the paragraph a seek snaps to is highlighted and what it reads aloud counts as listening', function () {
    const { engine, created, clock } = load_engine();
    const segments = [];
    engine.addEventListener('listen:segment', function (event) { segments.push(event.detail); });
    engine.play();
    latest(created).stream_started(3);

    engine.seek(52);
    clock.tick(1000);
    const audio = latest(created);
    audio.stream_started(2);
    audio.currentTime = 4;
    audio.fire('timeupdate');

    const last = segments[segments.length - 1];
    assert.equal(last.index, 2);
    assert.deepEqual(Array.from(last.paragraphs), [2]);
    assert.equal(engine.progress_seconds, 4);
    assert.equal(engine.get_current_time(), 44);
});

test('skipping ahead within the paragraph that is streaming still waits for the stream to reach the spot', function () {
    const { engine, created, clock, segment_requests } = load_engine();
    engine.play();
    const first = created[0];
    first.stream_started(3);
    first.fire('playing');

    engine.seek(10);
    clock.tick(1000);
    assert.equal(first.muted, true, 'it buffers toward the spot without playing ahead out loud');
    assert.equal(first.currentTime, 0);

    first.buffered = time_ranges([[0, 12]]);
    clock.tick(400);

    assert.equal(first.muted, false);
    assert.equal(first.currentTime, 10, 'it lands on the exact spot once the stream gets there');
    assert.equal(engine.get_current_time(), 10);
    assert.deepEqual(segment_requests, [0, 1], 'the paragraph is not asked for again');
});

test('scrubbing into the buffered next paragraph that has already streamed past the spot lands on it exactly', function () {
    const { engine, created, clock } = load_engine();
    engine.play();
    const first = latest(created);
    first.stream_started(5);
    first.fire('playing');
    const next = latest(created);
    next.stream_started(15);

    engine.seek(30);
    clock.tick(1000);

    assert.equal(latest(created), next);
    assert.equal(next.muted, false);
    assert.equal(next.paused, false);
    assert.equal(next.currentTime, 10);
    assert.equal(engine.get_current_time(), 30);
});
