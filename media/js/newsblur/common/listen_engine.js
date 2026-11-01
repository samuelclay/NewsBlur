// media/js/newsblur/common/listen_engine.js
//
// NEWSBLUR.ListenEngine reads a story aloud (apps/listen) as a chain of short audio segments,
// usually one paragraph each, while looking like a single HTMLMediaElement to
// media_player_view.js: play(), pause(), currentTime, duration, playbackRate, volume, paused and
// the timeupdate/play/playing/pause/ended/loadedmetadata/durationchange/waiting/error events.
//
// Internally it asks POST /listen/manifest for the story's paragraphs and segments, then
// POST /listen/segment for each segment's audio URL, plays the segments back to back with Audio
// elements and buffers exactly one segment ahead. Times are cumulative across segments, using the
// manifest's estimated durations until each segment's real duration is known. Free previews stop
// hard at manifest.preview.seconds with a short fade.
//
// Extra events, all prefixed with "listen:", carry Listen specific state to the player:
//   listen:manifest       detail = manifest (also fired when the manifest is refetched)
//   listen:segment        detail = {index, paragraphs} when a segment starts
//   listen:usage          detail = usage object from any response
//   listen:preview_ended  the free preview reached its limit
//   listen:limit          detail = {reason, message, usage} for sample_limit, cap_reached, preview_ended
//   listen:failure        detail = {reason, message} for anything retryable
NEWSBLUR.ListenEngine = function (options) {
    options = options || {};
    this.story_hash = options.story_hash;
    this.language = options.language || null;
    this.voice_id = options.voice_id || null;
    this.start_paragraph = _.isNumber(options.start_paragraph) ? options.start_paragraph : null;
    this.pending_time = options.start_time || 0;
    this.duration_hint = options.duration || 0;

    this.listeners = {};
    this.manifest = null;
    this.segments = [];
    this.segment_index = 0;
    this.audio = null;
    this.audio_index = null;
    this.prefetched = null;
    this.stream_retries = {};
    this.manifest_loading = false;
    this.manifest_callbacks = [];
    this.generation = 0;
    this.wants_play = false;
    this.is_paused = true;
    this.is_ended = false;
    this.preview_finished = false;
    this.fade_multiplier = 1;
    this.fade_timer = null;
    this.seek_wait = null;
    this.seek_settle_timer = null;
    // listen_engine.js: The segment a seek or resume moved to, until its audio starts (see
    // start_offset).
    this.landing_index = null;
    this.current_request = null;
    this.progress_seconds = 0;
    this.progress_baseline = null;
    this.progress_timer = null;
    this.last_failure = null;
    this.destroyed = false;
    this._playback_rate = 1;
    this._volume = 1;
};

NEWSBLUR.ListenEngine.MANIFEST_EXPIRY_MARGIN = 30;
NEWSBLUR.ListenEngine.PREVIEW_FADE_SECONDS = 1.5;
// listen_engine.js: How long a segment that's still being generated may go without streaming in
// any more audio before it's asked for again.
NEWSBLUR.ListenEngine.SEEK_STALL_MS = 8000;
NEWSBLUR.ListenEngine.SEEK_RELOADS = 4;
NEWSBLUR.ListenEngine.SEEK_SETTLE_MS = 300;
NEWSBLUR.ListenEngine.PROGRESS_INTERVAL_MS = 30000;
// listen_engine.js: A larger jump between two timeupdates is a seek, not playback.
NEWSBLUR.ListenEngine.PROGRESS_MAX_STEP = 10;

// listen_engine.js: Sends a listening report to POST /listen/progress (listen-spec.md "Listening
// analytics beacon"). It's fire-and-forget: one retry, then dropped silently. During page unload
// it goes out with navigator.sendBeacon.
NEWSBLUR.ListenEngine.send_progress = function (data, use_beacon) {
    if (use_beacon && navigator.sendBeacon) {
        var form = new FormData();
        _.each(data, function (value, key) { form.append(key, value); });
        navigator.sendBeacon('/listen/progress', form);
        return;
    }
    var attempt = function (can_retry) {
        NEWSBLUR.assets.listen_progress(data, function () { }, function () {
            if (can_retry) attempt(false);
        });
    };
    attempt(true);
};
NEWSBLUR.ListenEngine.LIMIT_REASONS = ['sample_limit', 'cap_reached', 'preview_ended', 'preview_limit'];

// listen_engine.js: Pulls {reason, message, usage} out of either a {code: -1} JSON response or a
// failed jqXHR (whose body may still be the JSON error).
NEWSBLUR.ListenEngine.normalize_error = function (response, text_status) {
    var body = response;
    if (response && response.responseJSON) {
        body = response.responseJSON;
    } else if (response && response.responseText && !response.reason) {
        try {
            body = JSON.parse(response.responseText);
        } catch (e) {
            body = {};
        }
    }
    body = body || {};
    var message = body.message;
    if (!message || !_.isString(message)) {
        message = text_status === 'timeout' ?
            gettext("Listen timed out. Try again in a moment.") :
            gettext("Couldn't load audio for this story.");
    }
    return {
        reason: body.reason || (text_status === 'timeout' ? 'timeout' : 'error'),
        message: message,
        usage: body.usage || null
    };
};

_.extend(NEWSBLUR.ListenEngine.prototype, {

    // ====================
    // = Event Interface  =
    // ====================

    addEventListener: function (type, callback) {
        if (!this.listeners[type]) this.listeners[type] = [];
        this.listeners[type].push(callback);
    },

    removeEventListener: function (type, callback) {
        if (!this.listeners[type]) return;
        this.listeners[type] = _.without(this.listeners[type], callback);
    },

    dispatch: function (type, detail) {
        if (this.destroyed) return;
        var event = { type: type, target: this, detail: detail };
        _.each((this.listeners[type] || []).slice(), function (callback) {
            try {
                callback.call(this, event);
            } catch (e) {
                // listen_engine.js: Like a media element, one failing listener doesn't stop the rest.
                if (window.console) console.error('ListenEngine listener error', type, e);
            }
        }, this);
    },

    // =====================
    // = Media Element API =
    // =====================

    play: function () {
        if (this.destroyed) return Promise.resolve();
        if (this.preview_finished) {
            this.dispatch('listen:preview_ended');
            return Promise.resolve();
        }
        if (this.is_ended) {
            this.is_ended = false;
            this.pending_time = 0;
            this.segment_index = 0;
            this.discard_audio();
        }
        this.wants_play = true;
        if (this.is_paused) {
            this.is_paused = false;
            this.start_progress_timer();
            this.dispatch('play');
        }

        if (!this.manifest) {
            this.dispatch('waiting');
            // listen_engine.js: Play, pause, play before the manifest arrives starts it only once.
            if (!this.manifest_loading) this.load_manifest(_.bind(this.start_current_segment, this));
        } else if (this.seek_settle_timer) {
            this.dispatch('waiting');
        } else if (this.audio && this.audio_index === this.segment_index) {
            // listen_engine.js: During a seek wait the element is muted, so playing it only keeps
            // the download going.
            this.play_audio(this.audio);
        } else {
            this.start_current_segment();
        }
        return Promise.resolve();
    },

    pause: function () {
        this.wants_play = false;
        if (this.audio) {
            try {
                this.audio.pause();
            } catch (e) { }
        }
        this.stop_fade_timer();
        this.stop_progress_timer();
        this.clear_seek_settle();
        this.flush_progress();
        if (!this.is_paused) {
            this.is_paused = true;
            this.dispatch('pause');
        }
    },

    destroy: function () {
        this.pause();
        this.stop_progress_timer();
        this.generation += 1;
        this.discard_audio();
        this.discard_prefetch();
        this.clear_seek_wait();
        this.clear_seek_settle();
        this.listeners = {};
        this.destroyed = true;
    },

    // listen_engine.js: Retries whatever failed last: the manifest, a segment request or a stream.
    retry: function () {
        this.last_failure = null;
        this.pending_time = this.get_current_time();
        if (!this.manifest) {
            this.manifest_loading = false;
            this.manifest_callbacks = [];
        }
        this.stream_retries = {};
        this.discard_audio();
        this.play();
    },

    get_current_time: function () {
        if (!this.manifest) return this.pending_time || 0;
        var segment = this.segments[this.segment_index];
        if (!segment) return this.total_duration();
        var offset = this.pending_time - segment.start;
        if (this.audio && this.audio_index === this.segment_index && this.audio.readyState >= 1 && !this.seek_wait) {
            offset = this.audio.currentTime || 0;
        }
        return Math.min(this.total_duration(), segment.start + Math.max(0, offset));
    },

    total_duration: function () {
        if (!this.manifest) return this.duration_hint || 0;
        var last = _.last(this.segments);
        if (!last) return 0;
        var total = last.start + last.duration;
        // listen_engine.js: A preview's scrubber ends where the preview stops.
        var limit = this.preview_seconds();
        return limit ? Math.min(total, limit) : total;
    },

    set_playback_rate: function (rate) {
        rate = Math.max(0.5, Math.min(3, parseFloat(rate) || 1));
        // listen_engine.js: Listening reports carry one speed, so a change closes the current span.
        if (rate !== this._playback_rate) this.flush_progress();
        this._playback_rate = rate;
        this.apply_rate(this.audio);
        this.apply_rate(this.prefetched && this.prefetched.audio);
    },

    set_volume: function (volume) {
        this._volume = Math.max(0, Math.min(1, volume));
        this.apply_volume();
    },

    // ============
    // = Manifest =
    // ============

    manifest_params: function () {
        var params = { story_hash: this.story_hash };
        if (this.language) params.language = this.language;
        if (this.voice_id) params.voice_id = this.voice_id;
        return params;
    },

    load_manifest: function (callback) {
        if (callback) this.manifest_callbacks.push(callback);
        if (this.manifest_loading) return;
        this.manifest_loading = true;
        var generation = this.generation;

        NEWSBLUR.assets.listen_manifest(this.manifest_params(), _.bind(function (response) {
            if (this.destroyed || generation !== this.generation) return;
            this.manifest_loading = false;
            this.apply_manifest(response);
            var callbacks = this.manifest_callbacks;
            this.manifest_callbacks = [];
            _.each(callbacks, function (cb) { cb(); });
        }, this), _.bind(function (response, data, text_status) {
            if (this.destroyed || generation !== this.generation) return;
            this.manifest_loading = false;
            this.manifest_callbacks = [];
            this.fail(NEWSBLUR.ListenEngine.normalize_error(response, text_status));
        }, this));
    },

    apply_manifest: function (manifest) {
        var previous_paragraph = this.manifest ? this.current_paragraph() : null;
        this.manifest = manifest;
        this.language = manifest.language || this.language;
        if (manifest.voice && manifest.voice.voice_id && !manifest.voice_fallback) {
            this.voice_id = manifest.voice.voice_id;
        }
        this.segments = _.map(manifest.segments || [], function (segment) {
            return {
                index: segment.index,
                paragraphs: segment.paragraphs || [],
                duration: Math.max(0.1, parseFloat(segment.duration) || 0.1),
                estimated: segment.estimated !== false && !segment.cached,
                start: 0
            };
        });
        this.recompute_starts();

        // listen_engine.js: Land on the same paragraph after a refetch or a settings restart,
        // otherwise on the saved resume time.
        var paragraph = _.isNumber(previous_paragraph) ? previous_paragraph : this.start_paragraph;
        if (_.isNumber(paragraph)) {
            this.segment_index = this.segment_for_paragraph(paragraph);
            this.pending_time = this.segments[this.segment_index] ? this.segments[this.segment_index].start : 0;
        } else {
            // listen_engine.js: A resume time or a seek made before the manifest arrived lands in
            // a segment that hasn't played yet.
            var position = this.locate(this.pending_time || 0);
            this.segment_index = position.index;
            this.pending_time = position.time;
            this.landing_index = position.index;
        }
        this.start_paragraph = null;

        if (manifest.usage) this.dispatch('listen:usage', manifest.usage);
        this.dispatch('loadedmetadata');
        this.dispatch('durationchange');
        this.dispatch('listen:manifest', manifest);
    },

    // listen_engine.js: Concurrent refreshes share one request; apply_manifest keeps the
    // current paragraph, so in-flight segment requests stay valid.
    refresh_manifest: function (callback) {
        this.load_manifest(callback);
    },

    manifest_expired: function () {
        if (!this.manifest || !this.manifest.expires_at) return false;
        var now = Date.now() / 1000;
        return now > this.manifest.expires_at - NEWSBLUR.ListenEngine.MANIFEST_EXPIRY_MARGIN;
    },

    is_preview: function () {
        return !!(this.manifest && this.manifest.preview && this.manifest.preview.is_preview);
    },

    preview_seconds: function () {
        if (!this.is_preview()) return null;
        return parseFloat(this.manifest.preview.seconds) || 30;
    },

    // ============
    // = Segments =
    // ============

    recompute_starts: function () {
        var start = 0;
        _.each(this.segments, function (segment) {
            segment.start = start;
            start += segment.duration;
        });
    },

    locate: function (time) {
        if (!this.segments.length) return { index: 0, time: 0, offset: 0 };
        time = Math.max(0, time);
        for (var i = 0; i < this.segments.length; i++) {
            var segment = this.segments[i];
            if (time < segment.start + segment.duration || i === this.segments.length - 1) {
                var offset = Math.min(Math.max(0, time - segment.start), segment.duration);
                return { index: i, time: segment.start + offset, offset: offset };
            }
        }
        return { index: 0, time: 0, offset: 0 };
    },

    segment_for_paragraph: function (paragraph_index) {
        var match = _.find(this.segments, function (segment) {
            return _.contains(segment.paragraphs, paragraph_index);
        });
        if (match) return match.index;
        // listen_engine.js: A paragraph past the end of a truncated preview maps to its last segment.
        var before = _.filter(this.segments, function (segment) {
            return _.min(segment.paragraphs) <= paragraph_index;
        });
        return before.length ? _.last(before).index : 0;
    },

    current_paragraphs: function () {
        var segment = this.segments[this.segment_index];
        return segment ? segment.paragraphs : [];
    },

    current_paragraph: function () {
        var paragraphs = this.current_paragraphs();
        return paragraphs.length ? paragraphs[0] : null;
    },

    seek_to_paragraph: function (paragraph_index) {
        if (!this.manifest) {
            this.start_paragraph = paragraph_index;
            return;
        }
        var index = this.segment_for_paragraph(paragraph_index);
        this.seek(this.segments[index].start);
    },

    // listen_engine.js: options.is_retry marks the second try after a manifest refresh, and
    // options.on_error hears every failure before the usual handling.
    request_segment: function (index, callback, options) {
        options = options || {};
        var is_retry = options.is_retry;
        var generation = this.generation;
        var request = _.bind(function () {
            NEWSBLUR.assets.listen_segment(this.manifest.manifest_id, index, _.bind(function (response) {
                if (this.destroyed || generation !== this.generation) return;
                if (response.usage) this.dispatch('listen:usage', response.usage);
                if (_.isNumber(response.duration) && response.duration > 0) {
                    this.learn_duration(index, response.duration);
                }
                callback(response);
            }, this), _.bind(function (response, data, text_status) {
                if (this.destroyed || generation !== this.generation) return;
                var error = NEWSBLUR.ListenEngine.normalize_error(response, text_status);
                if (error.reason === 'manifest_expired' && !is_retry) {
                    // listen_engine.js: Refetch the manifest, which resumes at the same paragraph,
                    // then ask for this segment again.
                    this.refresh_manifest(_.bind(function () {
                        this.request_segment(index, callback, _.extend({}, options, { is_retry: true }));
                    }, this));
                    return;
                }
                if (options.on_error) options.on_error(error);
                if (index !== this.segment_index) return; // A failed prefetch is retried when it's reached
                this.fail(error);
            }, this));
        }, this);

        if (this.manifest_expired() && !is_retry) {
            this.refresh_manifest(_.bind(function () {
                this.request_segment(index, callback, _.extend({}, options, { is_retry: true }));
            }, this));
        } else {
            request();
        }
    },

    start_current_segment: function () {
        if (this.destroyed || !this.manifest) return;
        if (!this.segments.length) {
            this.fail({ reason: 'no_text', message: gettext("There's nothing to read aloud in this story.") });
            return;
        }
        this.clear_seek_settle();
        var index = this.segment_index;
        if (this.prefetched && this.prefetched.index !== index && this.prefetched.index !== index + 1) {
            // listen_engine.js: A seek left the buffered segment behind.
            this.discard_prefetch();
        }

        if (this.prefetched && this.prefetched.index === index) {
            var entry = this.prefetched;
            if (entry.audio) {
                this.prefetched = null;
                this.use_audio(entry.audio, index, this.start_offset(entry.audio, index, entry.cached));
                return;
            }
            // listen_engine.js: The prefetch request is still out; it starts playing when it
            // answers rather than asking node for the same segment twice.
            this.discard_audio();
            entry.promote = true;
            this.dispatch('waiting');
            return;
        }

        // listen_engine.js: Already asked for this segment and waiting on the answer.
        if (this.current_request && this.current_request.index === index) return;

        this.discard_audio();
        this.dispatch('waiting');
        var request = { index: index };
        this.current_request = request;
        this.request_segment(index, _.bind(function (response) {
            if (this.current_request === request) this.current_request = null;
            if (index !== this.segment_index) return;
            var audio = this.make_audio(response.url);
            this.use_audio(audio, index, this.start_offset(audio, index, response.cached));
        }, this), {
            on_error: _.bind(function () {
                if (this.current_request === request) this.current_request = null;
            }, this)
        });
    },

    offset_in_segment: function (index) {
        return Math.max(0, this.pending_time - this.segments[index].start);
    },

    // listen_engine.js: Where a segment's audio starts. A seek or resume into a segment that hasn't
    // played picks its offset from the manifest's estimated durations, which can lie past the
    // paragraph's real end. Audio still streaming live from node can't seek past what it has
    // downloaded, so seek_within would play it muted to its end and reading would pick up a
    // paragraph later. Instead a live stream that hasn't downloaded the offset yet is read aloud
    // from the start of the paragraph, and the timeline snaps there. Cached audio (S3) lands on the
    // exact offset, and so does any segment that was already playing.
    start_offset: function (audio, index, cached) {
        var offset = this.offset_in_segment(index);
        var landed = this.landing_index === index;
        this.landing_index = null;
        if (!landed || cached || this.is_seekable(audio, offset)) return offset;
        return 0;
    },

    make_audio: function (url) {
        var audio = new Audio();
        audio.preload = 'auto';
        this.apply_rate(audio);
        audio.src = url;
        return audio;
    },

    use_audio: function (audio, index, offset, attempt) {
        this.discard_audio();
        this.pending_time = this.segments[index].start + offset;
        this.audio = audio;
        this.audio_index = index;
        this.progress_baseline = offset > 0.25 ? null : { audio: audio, time: 0 };
        this.bind_audio(audio, index);
        this.apply_rate(audio);
        this.apply_volume();

        this.dispatch('listen:segment', { index: index, paragraphs: this.segments[index].paragraphs });
        if (offset > 0.25) {
            // listen_engine.js: seek_within starts playback once the offset can be reached.
            this.seek_within(audio, offset, attempt);
        } else if (this.wants_play) {
            this.play_audio(audio);
        }
    },

    play_audio: function (audio) {
        var promise = audio.play();
        if (promise && promise.catch) {
            promise.catch(_.bind(function (error) {
                if (this.destroyed || audio !== this.audio) return;
                if (error && error.name === 'NotAllowedError') {
                    this.pause();
                } else if (error && error.name === 'AbortError') {
                    // listen_engine.js: A pause or seek interrupted play(); nothing is wrong.
                    return;
                } else {
                    // listen_engine.js: Anything else means the audio can't play, like a dead
                    // stream, so it gets the same single retry as a stream error.
                    this.handle_stream_error(this.audio_index, audio);
                }
            }, this));
        }
        if (this.is_preview()) this.start_fade_timer();
    },

    bind_audio: function (audio, index) {
        var self = this;
        audio._listen_handlers = {
            playing: function () {
                if (audio !== self.audio) return;
                self.dispatch('playing');
                self.prefetch(index + 1);
            },
            waiting: function () {
                if (audio === self.audio) self.dispatch('waiting');
            },
            timeupdate: function () {
                if (audio !== self.audio) return;
                self.track_progress(audio);
                self.check_preview_limit();
                self.dispatch('timeupdate');
            },
            durationchange: function () {
                if (isFinite(audio.duration) && audio.duration > 0) {
                    self.learn_duration(index, audio.duration);
                }
            },
            ended: function () {
                if (audio !== self.audio) return;
                self.track_progress(audio);
                var played = audio.currentTime;
                if (isFinite(played) && played > 0) self.learn_duration(index, played);
                self.advance();
            },
            error: function () {
                if (audio !== self.audio) return;
                self.handle_stream_error(index, audio);
            }
        };
        _.each(audio._listen_handlers, function (handler, type) {
            audio.addEventListener(type, handler);
        });
        audio.addEventListener('loadedmetadata', audio._listen_handlers.durationchange);
    },

    unbind_audio: function (audio) {
        if (!audio || !audio._listen_handlers) return;
        _.each(audio._listen_handlers, function (handler, type) {
            audio.removeEventListener(type, handler);
        });
        audio.removeEventListener('loadedmetadata', audio._listen_handlers.durationchange);
        audio._listen_handlers = null;
    },

    discard_audio: function () {
        if (this.audio) this.track_progress(this.audio);
        this.progress_baseline = null;
        if (this.audio && this.audio_index === this.segment_index) {
            this.pending_time = this.get_current_time();
        }
        this.clear_seek_wait();
        if (!this.audio) return;
        var audio = this.audio;
        this.unbind_audio(audio);
        try {
            audio.pause();
            audio.removeAttribute('src');
            audio.load();
        } catch (e) { }
        this.audio = null;
        this.audio_index = null;
    },

    discard_prefetch: function () {
        if (!this.prefetched) return;
        var audio = this.prefetched.audio;
        this.prefetched = null;
        if (!audio) return;
        try {
            audio.removeAttribute('src');
            audio.load();
        } catch (e) { }
    },

    // listen_engine.js: Buffer the next segment, and never more than one ahead.
    prefetch: function (index) {
        if (index >= this.segments.length) {
            this.discard_prefetch();
            return;
        }
        if (this.prefetched && this.prefetched.index === index) return;
        if (this.is_preview() && this.segments[index].start >= this.preview_seconds()) return;
        this.discard_prefetch();
        // listen_engine.js: cached says whether the audio is the seekable S3 copy rather than a
        // live node stream, for start_offset.
        var entry = { index: index, audio: null, cached: false, promote: false };
        this.prefetched = entry;
        this.request_segment(index, _.bind(function (response) {
            if (this.prefetched !== entry) return;
            var audio = this.make_audio(response.url);
            if (entry.promote && index === this.segment_index) {
                this.prefetched = null;
                this.use_audio(audio, index, this.start_offset(audio, index, response.cached));
                return;
            }
            entry.audio = audio;
            entry.cached = !!response.cached;
            audio.addEventListener('error', _.bind(function () {
                // listen_engine.js: A dead prefetch (a 502 or 429 from node) is dropped, so the
                // segment is asked for again when it's reached instead of playing a broken element.
                if (this.prefetched === entry) this.discard_prefetch();
            }, this));
            audio.load();
        }, this), {
            on_error: _.bind(function () {
                if (this.prefetched === entry) this.prefetched = null;
            }, this)
        });
    },

    advance: function () {
        var next = this.segment_index + 1;
        if (next >= this.segments.length) {
            this.finish();
            return;
        }
        this.segment_index = next;
        this.pending_time = this.segments[next].start;
        this.start_current_segment();
    },

    finish: function () {
        this.stop_fade_timer();
        this.wants_play = false;
        if (this.is_preview()) {
            this.end_preview();
            return;
        }
        this.is_ended = true;
        this.is_paused = true;
        this.stop_progress_timer();
        this.flush_progress({ finished: true });
        this.dispatch('pause');
        this.dispatch('ended');
    },

    learn_duration: function (index, duration) {
        var segment = this.segments[index];
        if (!segment || !isFinite(duration) || duration <= 0) return;
        if (!segment.estimated && Math.abs(segment.duration - duration) < 0.05) return;
        var position = this.get_current_time();
        var current_segment = this.segments[this.segment_index];
        var offset_in_current = current_segment ? position - current_segment.start : 0;
        segment.duration = duration;
        segment.estimated = false;
        this.recompute_starts();
        if (current_segment) {
            this.pending_time = current_segment.start + Math.max(0, offset_in_current);
        }
        this.dispatch('durationchange');
    },

    // ===========
    // = Seeking =
    // ===========

    seek: function (time) {
        if (!this.manifest) {
            this.pending_time = Math.max(0, time);
            this.start_paragraph = null;
            return;
        }
        if (this.preview_finished) return;
        var limit = this.preview_seconds();
        if (limit) time = Math.min(time, limit - NEWSBLUR.ListenEngine.PREVIEW_FADE_SECONDS - 0.5);
        var position = this.locate(time);
        this.is_ended = false;
        this.pending_time = position.time;
        this.skip_progress_jump();
        this.dispatch('seeking');

        if (position.index === this.segment_index && this.audio && this.audio_index === position.index) {
            this.seek_within(this.audio, position.offset);
        } else {
            // listen_engine.js: Moving to another segment lands there (see start_offset). A seek
            // within the current one keeps whatever it had: still landing if its audio hasn't
            // started, otherwise not.
            if (position.index !== this.segment_index) this.landing_index = position.index;
            this.segment_index = position.index;
            if (this.wants_play) {
                // listen_engine.js: Dragging the scrubber crosses many segments, and every segment
                // asked for is generated and counted against the weekly cap, so only the one the
                // scrubber settles on is requested.
                this.discard_audio();
                this.clear_seek_settle();
                this.dispatch('waiting');
                this.seek_settle_timer = setTimeout(_.bind(function () {
                    this.seek_settle_timer = null;
                    this.start_current_segment();
                }, this), NEWSBLUR.ListenEngine.SEEK_SETTLE_MS);
            } else {
                // listen_engine.js: While paused, only remember where to start.
                this.discard_audio();
                this.dispatch('listen:segment', { index: position.index, paragraphs: this.segments[position.index].paragraphs });
            }
        }
        this.dispatch('timeupdate');
        this.dispatch('seeked');
    },

    // listen_engine.js: A segment streamed live from node has no Range support, and a paused
    // element stops downloading, so an offset past what's buffered is reached by playing the
    // stream muted until the download covers it, then jumping there. A finished stream that can't
    // seek is asked for again, which returns the cached, seekable S3 copy.
    seek_within: function (audio, offset, attempt) {
        attempt = attempt || 0;
        this.clear_seek_wait();
        if (audio.readyState < 1) {
            var on_metadata = _.bind(function () {
                audio.removeEventListener('loadedmetadata', on_metadata);
                if (audio === this.audio) this.seek_within(audio, offset, attempt);
            }, this);
            audio.addEventListener('loadedmetadata', on_metadata);
            audio.muted = true;
            this.seek_wait = { audio: audio, timer: null };
            return;
        }
        if (this.past_segment_end(audio, offset)) {
            this.finish_segment(audio);
            return;
        }
        if (this.is_seekable(audio, offset)) {
            this.skip_progress_jump();
            audio.currentTime = offset;
            if (this.wants_play) this.play_audio(audio);
            return;
        }
        if (!this.wants_play) {
            // listen_engine.js: While paused, only remember the spot; play asks for the segment
            // again, and it's the cached copy by then.
            var position = this.segments[this.audio_index].start + offset;
            this.discard_audio();
            this.pending_time = position;
            return;
        }
        if (isFinite(audio.duration)) {
            this.reload_for_seek(audio, offset, attempt);
            return;
        }

        var wait = { audio: audio, timer: null };
        var buffered_end = 0;
        var grew_at = Date.now();
        this.seek_wait = wait;
        this.dispatch('waiting');
        audio.muted = true;
        this.play_audio(audio);
        wait.timer = setInterval(_.bind(function () {
            if (this.seek_wait !== wait || audio !== this.audio) {
                clearInterval(wait.timer);
                return;
            }
            var ranges = audio.buffered;
            var end = ranges && ranges.length ? ranges.end(ranges.length - 1) : 0;
            if (end > buffered_end) {
                buffered_end = end;
                grew_at = Date.now();
            }
            if (this.past_segment_end(audio, offset)) {
                this.clear_seek_wait();
                this.finish_segment(audio);
            } else if (this.in_ranges(audio.buffered, offset)) {
                this.clear_seek_wait();
                this.skip_progress_jump();
                audio.currentTime = offset;
                if (!this.wants_play) audio.pause();
            } else if (isFinite(audio.duration) || Date.now() - grew_at > NEWSBLUR.ListenEngine.SEEK_STALL_MS) {
                this.clear_seek_wait();
                this.reload_for_seek(audio, offset, attempt);
            }
        }, this), 200);
    },

    // listen_engine.js: The segment turned out shorter than its estimate and the target is past its
    // end, so it finishes and the next one starts.
    past_segment_end: function (audio, offset) {
        return isFinite(audio.duration) && offset >= audio.duration - 0.1;
    },

    finish_segment: function (audio) {
        this.skip_progress_jump();
        audio.currentTime = Math.max(0, audio.duration - 0.05);
        if (this.wants_play) this.play_audio(audio);
    },

    reload_for_seek: function (audio, offset, attempt) {
        if (attempt >= NEWSBLUR.ListenEngine.SEEK_RELOADS) {
            // listen_engine.js: Still not seekable, so read the paragraph from its start.
            this.pending_time = this.segments[this.audio_index].start;
            this.skip_progress_jump();
            audio.currentTime = 0;
            if (this.wants_play) this.play_audio(audio);
            return;
        }
        var index = this.audio_index;
        this.request_segment(index, _.bind(function (response) {
            if (index !== this.segment_index) return;
            this.use_audio(this.make_audio(response.url), index, offset, attempt + 1);
        }, this));
    },

    clear_seek_settle: function () {
        if (this.seek_settle_timer) {
            clearTimeout(this.seek_settle_timer);
            this.seek_settle_timer = null;
        }
    },

    clear_seek_wait: function () {
        if (this.seek_wait) {
            if (this.seek_wait.timer) clearInterval(this.seek_wait.timer);
            if (this.seek_wait.audio) this.seek_wait.audio.muted = false;
        }
        this.seek_wait = null;
    },

    // listen_engine.js: Anything already downloaded can be reached. Beyond that only a complete,
    // Range-capable copy (S3) can seek; a live node stream reports an endless seekable range it
    // can't actually serve, so it waits for the audio to stream in.
    is_seekable: function (audio, offset) {
        if (this.in_ranges(audio.buffered, offset)) return true;
        return isFinite(audio.duration) && this.in_ranges(audio.seekable, offset);
    },

    in_ranges: function (ranges, offset) {
        if (!ranges) return false;
        for (var i = 0; i < ranges.length; i++) {
            if (offset >= ranges.start(i) && offset <= ranges.end(i)) return true;
        }
        return false;
    },

    // ==========
    // = Errors =
    // ==========

    handle_stream_error: function (index, audio) {
        // listen_engine.js: An element's error event and its rejected play() report one failure.
        if (audio._listen_failed) return;
        audio._listen_failed = true;
        var offset = audio.currentTime || 0;
        if (!this.stream_retries[index]) {
            // listen_engine.js: Asking /listen/segment again for the same manifest and index
            // within an hour is free, so one retry is always safe.
            this.stream_retries[index] = true;
            this.request_segment(index, _.bind(function (response) {
                if (index !== this.segment_index) return;
                this.use_audio(this.make_audio(response.url), index, offset);
            }, this));
            return;
        }
        this.fail({ reason: 'stream_error', message: gettext("The audio stream was interrupted.") });
    },

    fail: function (error) {
        this.last_failure = error;
        this.stop_fade_timer();
        this.wants_play = false;
        // listen_engine.js: Drop the failed audio (keeping its position) so the next play()
        // requests the segment again.
        this.discard_audio();
        this.stop_progress_timer();
        this.flush_progress();
        if (!this.is_paused) {
            this.is_paused = true;
            this.dispatch('pause');
        }
        if (error.usage) this.dispatch('listen:usage', error.usage);
        if (_.contains(NEWSBLUR.ListenEngine.LIMIT_REASONS, error.reason)) {
            if (error.reason === 'preview_ended') this.preview_finished = true;
            this.dispatch('listen:limit', error);
        } else {
            this.dispatch('listen:failure', error);
        }
    },

    // ===========
    // = Preview =
    // ===========

    check_preview_limit: function () {
        var limit = this.preview_seconds();
        if (!limit || this.preview_finished) return;
        var time = this.get_current_time();
        var fade = NEWSBLUR.ListenEngine.PREVIEW_FADE_SECONDS;
        if (time >= limit) {
            this.end_preview();
        } else if (time >= limit - fade) {
            this.fade_multiplier = Math.max(0, (limit - time) / fade);
            this.apply_volume();
        } else if (this.fade_multiplier !== 1) {
            this.fade_multiplier = 1;
            this.apply_volume();
        }
    },

    start_fade_timer: function () {
        this.stop_fade_timer();
        this.fade_timer = setInterval(_.bind(this.check_preview_limit, this), 100);
    },

    stop_fade_timer: function () {
        if (this.fade_timer) {
            clearInterval(this.fade_timer);
            this.fade_timer = null;
        }
    },

    end_preview: function () {
        if (this.preview_finished) return;
        this.preview_finished = true;
        this.stop_fade_timer();
        this.wants_play = false;
        if (this.audio) {
            try {
                this.audio.pause();
            } catch (e) { }
        }
        this.discard_prefetch();
        this.stop_progress_timer();
        this.flush_progress();
        if (!this.is_paused) {
            this.is_paused = true;
            this.dispatch('pause');
        }
        this.dispatch('listen:preview_ended');
    },

    remaining_preview_seconds: function () {
        var limit = this.preview_seconds();
        if (!limit) return null;
        return Math.max(0, limit - this.get_current_time());
    },

    // =====================
    // = Listening Reports =
    // =====================

    // listen_engine.js: Counts how far playback advanced through the audio: the change in
    // currentTime between timeupdates, which already leaves out time paused or buffering.
    track_progress: function (audio) {
        if (!audio || audio !== this.audio) return;
        if (this.seek_wait) {
            // listen_engine.js: Muted buffering toward a seek target isn't listening.
            this.progress_baseline = null;
            return;
        }
        var time = audio.currentTime || 0;
        var baseline = this.progress_baseline;
        if (baseline && baseline.audio === audio) {
            var step = time - baseline.time;
            if (step > 0 && step < NEWSBLUR.ListenEngine.PROGRESS_MAX_STEP) {
                this.progress_seconds += step;
            }
        }
        this.progress_baseline = { audio: audio, time: time };
    },

    // listen_engine.js: Seeks, skips and scrubbing jump the timeline without playing it.
    skip_progress_jump: function () {
        if (this.audio) this.track_progress(this.audio);
        this.progress_baseline = null;
    },

    start_progress_timer: function () {
        this.stop_progress_timer();
        this.progress_timer = setInterval(_.bind(this.flush_progress, this), NEWSBLUR.ListenEngine.PROGRESS_INTERVAL_MS);
    },

    stop_progress_timer: function () {
        if (this.progress_timer) {
            clearInterval(this.progress_timer);
            this.progress_timer = null;
        }
    },

    // listen_engine.js: Reports what was played since the last report. Under a second is held for
    // the next one, unless the story just finished. options.beacon is for page unload.
    flush_progress: function (options) {
        options = options || {};
        if (this.destroyed || !this.manifest || !this.manifest.manifest_id) return;
        if (this.audio) this.track_progress(this.audio);
        var seconds = Math.round(this.progress_seconds * 10) / 10;
        if (seconds < 1 && !options.finished) return;
        this.progress_seconds = 0;
        var data = {
            manifest_id: this.manifest.manifest_id,
            seconds: seconds,
            speed: this._playback_rate
        };
        if (options.finished) data.finished = 'true';
        NEWSBLUR.ListenEngine.send_progress(data, options.beacon);
    },

    // ===========
    // = Helpers =
    // ===========

    apply_rate: function (audio) {
        if (!audio) return;
        // listen_engine.js: Speed never regenerates audio; it's the player's rate with pitch kept.
        audio.preservesPitch = true;
        audio.mozPreservesPitch = true;
        audio.webkitPreservesPitch = true;
        audio.defaultPlaybackRate = this._playback_rate;
        audio.playbackRate = this._playback_rate;
    },

    apply_volume: function () {
        if (this.audio) {
            this.audio.volume = Math.max(0, Math.min(1, this._volume * this.fade_multiplier));
        }
    }

});

Object.defineProperties(NEWSBLUR.ListenEngine.prototype, {
    currentTime: {
        get: function () { return this.get_current_time(); },
        set: function (value) { this.seek(parseFloat(value) || 0); }
    },
    duration: {
        get: function () { return this.total_duration(); }
    },
    paused: {
        get: function () { return this.is_paused; }
    },
    ended: {
        get: function () { return this.is_ended; }
    },
    playbackRate: {
        get: function () { return this._playback_rate; },
        set: function (value) { this.set_playback_rate(value); }
    },
    volume: {
        get: function () { return this._volume; },
        set: function (value) { this.set_volume(parseFloat(value)); }
    }
});
