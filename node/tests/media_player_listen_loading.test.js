const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// media_player_listen_loading.test.js: Elements found through the player's this.$(selector) record
// what they're given. An element is as tall as its content, so a message that appears in it makes
// the player taller.
function make_element(selector) {
    const classes = new Set();
    const element = {
        selector: selector,
        length: 1,
        content: '',
        classes: classes,
        html: function (value) {
            if (value === undefined) return element.content;
            element.content = String(value);
            return element;
        },
        text: function (value) {
            if (value === undefined) return element.content;
            element.content = String(value);
            return element;
        },
        attr: function (name, value) {
            if (name === 'class' && value !== undefined) {
                classes.clear();
                String(value).split(/\s+/).filter(Boolean).forEach(function (c) { classes.add(c); });
            }
            return element;
        },
        addClass: function (name) { classes.add(name); return element; },
        removeClass: function (name) { classes.delete(name); return element; },
        toggleClass: function (name, on) {
            if (on === undefined) on = !classes.has(name);
            if (on) classes.add(name); else classes.delete(name);
            return element;
        },
        hasClass: function (name) { return classes.has(name); },
        outerHeight: function () { return element.content ? 24 : 0; },
        val: function () { return element; },
        css: function () { return element; },
        show: function () { return element; },
        hide: function () { return element; },
        toggle: function () { return element; }
    };
    return element;
}

function load_player() {
    const elements = {};
    // media_player_listen_loading.test.js: Timers run only when a test calls run_timers, and
    // clearTimeout cancels them as the browser would.
    const timers = new Map();
    let last_timer_id = 0;
    const window_events = {
        off: function () { return window_events; },
        on: function () { return window_events; },
        each: function () { return window_events; }
    };
    const context = {
        NEWSBLUR: { Views: {}, assets: { playback_state: null } },
        Backbone: { View: { extend: function (methods) { return methods; } } },
        $: function () { return window_events; },
        window: {},
        navigator: {},
        setTimeout: function (fn) { last_timer_id += 1; timers.set(last_timer_id, fn); return last_timer_id; },
        clearTimeout: function (id) { timers.delete(id); },
        setInterval: function () { return 0; },
        clearInterval: function () {},
        gettext: function (message) { return message; },
        ngettext: function (one, many, count) { return count === 1 ? one : many; },
        interpolate: function (message) { return message; }
    };
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/vendor/underscore-1.4.3.js'), 'utf8'), context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/newsblur/views/media_player_view.js'), 'utf8'), context);

    const player = Object.create(context.NEWSBLUR.Views.MediaPlayerView);
    player.initialize();
    player.resizes = 0;
    player.resize_player = function () { player.resizes += 1; };
    player.$ = function (selector) {
        if (!elements[selector]) elements[selector] = make_element(selector);
        return elements[selector];
    };
    player.elements = elements;
    // media_player_listen_loading.test.js: A Listen story that's playing and waiting on a segment.
    const engine = {
        paused: false,
        is_preview: function () { return false; },
        preview_seconds: function () { return 0; },
        remaining_preview_seconds: function () { return 0; }
    };
    player.listen_engine = function () { return engine; };
    player.$('.NB-media-player-listen-banner').attr('class', 'NB-media-player-listen-banner NB-empty');
    player.current_position = 2;
    player.current_duration = 143;
    player.context = context;
    player.run_timers = function () {
        while (timers.size) {
            const id = timers.keys().next().value;
            const fn = timers.get(id);
            timers.delete(id);
            fn();
        }
    };
    return player;
}

// media_player_listen_loading.test.js: A stand-in for NEWSBLUR.ListenEngine
// (common/listen_engine.js). Like the real engine, play() fires play and then waiting while the
// story's first segment is fetched, and pause() fires pause once.
function FakeListenEngine(options) {
    this.options = options;
    this.listeners = {};
    this.paused = true;
    this.currentTime = 0;
    this.duration = 143;
    this.preview_finished = false;
}
FakeListenEngine.prototype.addEventListener = function (type, callback) {
    (this.listeners[type] = this.listeners[type] || []).push(callback);
};
FakeListenEngine.prototype.dispatch = function (type, detail) {
    const engine = this;
    (this.listeners[type] || []).slice().forEach(function (callback) {
        callback({ type: type, target: engine, detail: detail });
    });
};
FakeListenEngine.prototype.play = function () {
    if (this.paused) {
        this.paused = false;
        this.dispatch('play');
    }
    this.dispatch('waiting');
};
FakeListenEngine.prototype.pause = function () {
    if (this.paused) return;
    this.paused = true;
    this.dispatch('pause');
};
FakeListenEngine.prototype.is_preview = function () { return false; };
FakeListenEngine.prototype.preview_seconds = function () { return null; };
FakeListenEngine.prototype.remaining_preview_seconds = function () { return null; };

// media_player_listen_loading.test.js: A podcast episode's <audio> element.
function FakeAudio(url) {
    this.src = url;
    this.paused = true;
    this.currentTime = 0;
    this.duration = 0;
}
FakeAudio.prototype.addEventListener = function () {};
FakeAudio.prototype.play = function () { this.paused = false; };
FakeAudio.prototype.pause = function () { this.paused = true; };

// media_player_listen_loading.test.js: A player that plays items through play_media, as Next Story,
// Up Next and Listen do, with its real listen_engine(). Its $el.html() replaces every element, as a
// full re-render replaces the player's DOM, and keeps the markup it was given.
function load_playing_player() {
    const player = load_player();
    const context = player.context;
    delete player.listen_engine;
    context.NEWSBLUR.ListenEngine = FakeListenEngine;
    context.Audio = FakeAudio;
    Object.assign(context.NEWSBLUR.assets, {
        get_feed: function () { return null; },
        preference: function () { return undefined; },
        add_to_media_history: function () {},
        remove_from_media_queue: function () {},
        save_playback_state: function () {},
        clear_playback_state: function () {}
    });
    const player_classes = new Set();
    player.markup = '';
    player.$el = {
        0: { scrollHeight: 120 },
        html: function (markup) {
            player.markup = markup;
            Object.keys(player.elements).forEach(function (selector) { delete player.elements[selector]; });
            return player.$el;
        },
        addClass: function (name) { player_classes.add(name); return player.$el; },
        removeClass: function (name) { player_classes.delete(name); return player.$el; },
        toggleClass: function (name, on) {
            if (on) player_classes.add(name); else player_classes.delete(name);
            return player.$el;
        },
        hasClass: function (name) { return player_classes.has(name); }
    };
    return player;
}

function listen_item(story_hash, title) {
    return {
        story_hash: story_hash,
        media_url: '/listen/story/' + story_hash,
        media_type: 'listen',
        media_title: title,
        feed_id: 42,
        image_url: ''
    };
}

// media_player_listen_loading.test.js: The markup of the player's time display.
function time_display_markup(markup) {
    const match = /<div class="NB-media-player-time[^"]*">([\s\S]*?)<\/div>/.exec(markup);
    return match ? match[0] : '';
}

test('preparing audio does not grow the player', function () {
    const player = load_player();

    player.start_listen_loading();
    player.run_timers();

    const banner = player.elements['.NB-media-player-listen-banner'];
    assert.equal(player.listen_loading, true);
    assert.doesNotMatch(banner.content, /Preparing/, 'the banner row stays empty while audio is prepared');
    assert.equal(banner.outerHeight(), 0);
    assert.equal(player.resizes, 0, 'preparing audio never resizes the player');
});

test('preparing audio shows in the time display, which comes back when the audio starts', function () {
    const player = load_player();

    player.start_listen_loading();
    player.run_timers();
    const time = player.elements['.NB-media-player-time'];
    assert.ok(time && time.hasClass('NB-listen-loading'), 'the time display reads Preparing... while audio is prepared');

    player.stop_listen_loading();
    player.update_progress_display();
    assert.equal(time.hasClass('NB-listen-loading'), false, 'the time display shows the time again');
    assert.equal(player.elements['.NB-media-player-time-current'].content, '0:02');
    assert.equal(player.elements['.NB-media-player-time-duration'].content, '2:23');
    assert.equal(player.resizes, 0);
});

test('Next Story while listening prepares the next story in the time display without resizing the player', function () {
    const player = load_playing_player();

    player.play_media(listen_item('42:first', 'First story'));
    const first_engine = player.media_element;
    assert.ok(first_engine instanceof FakeListenEngine);
    // media_player_listen_loading.test.js: Audio that starts within LISTEN_LOADING_DELAY never
    // shows Preparing at all.
    first_engine.dispatch('playing');
    player.run_timers();
    assert.equal(player.listen_loading, false);
    assert.equal(player.elements['.NB-media-player-time'].hasClass('NB-listen-loading'), false);
    assert.match(time_display_markup(player.markup), /<span class="NB-media-player-time-loading">Preparing audio\.\.\.<\/span>/);
    player.resizes = 0;

    player.play_media(listen_item('42:second', 'Second story'));
    const next_engine = player.media_element;
    assert.notEqual(next_engine, first_engine);
    player.run_timers();

    const time = player.elements['.NB-media-player-time'];
    assert.equal(player.listen_loading, true);
    assert.ok(time.hasClass('NB-listen-loading'), 'the time display reads Preparing... while the next story is prepared');
    assert.doesNotMatch(player.elements['.NB-media-player-listen-banner'].content, /Preparing/);
    assert.equal(player.resizes, 0, 'preparing the next story never resizes the player');

    next_engine.dispatch('playing');
    assert.equal(player.listen_loading, false);
    assert.equal(time.hasClass('NB-listen-loading'), false, 'the times come back when the audio starts');
    assert.equal(player.resizes, 0, 'starting the audio never resizes the player');
});

test('a full re-render while audio is prepared keeps Preparing in the time display', function () {
    const player = load_playing_player();
    player.play_media(listen_item('42:first', 'First story'));
    player.run_timers();
    const time_before = player.elements['.NB-media-player-time'];
    assert.ok(time_before.hasClass('NB-listen-loading'));

    player.render();

    const time_after = player.elements['.NB-media-player-time'];
    assert.notEqual(time_after, time_before, 'render replaced the time display');
    assert.ok(time_after.hasClass('NB-listen-loading'), 'the new time display still reads Preparing...');
    assert.doesNotMatch(player.elements['.NB-media-player-listen-banner'].content, /Preparing/);

    player.media_element.dispatch('playing');
    assert.equal(time_after.hasClass('NB-listen-loading'), false);
    assert.equal(player.resizes, 0);
});

test('closing the player while audio is prepared clears Preparing from the time display', function () {
    const player = load_playing_player();
    player.play_media(listen_item('42:first', 'First story'));
    player.run_timers();
    const time = player.elements['.NB-media-player-time'];
    assert.ok(time.hasClass('NB-listen-loading'));

    player.close_player();

    assert.equal(player.listen_loading, false);
    assert.equal(time.hasClass('NB-listen-loading'), false);
});

test('pausing while audio is prepared shows the times again', function () {
    const player = load_playing_player();
    player.play_media(listen_item('42:first', 'First story'));
    player.run_timers();
    const time = player.elements['.NB-media-player-time'];
    assert.ok(time.hasClass('NB-listen-loading'));

    player.pause();

    assert.equal(player.listen_loading, false);
    assert.equal(time.hasClass('NB-listen-loading'), false);
});

test('switching to a podcast while audio is prepared shows its times, with no Preparing', function () {
    const player = load_playing_player();
    player.play_media(listen_item('42:first', 'First story'));
    player.run_timers();
    assert.ok(player.elements['.NB-media-player-time'].hasClass('NB-listen-loading'));

    player.play_media({
        story_hash: '7:episode',
        media_url: 'https://example.com/episode.mp3',
        media_type: 'audio',
        media_title: 'An episode',
        feed_id: 7,
        image_url: ''
    });
    player.run_timers();

    assert.ok(player.media_element instanceof FakeAudio);
    assert.equal(player.listen_loading, false);
    assert.equal(player.elements['.NB-media-player-time'].hasClass('NB-listen-loading'), false);
    assert.doesNotMatch(time_display_markup(player.markup), /NB-listen-loading|NB-media-player-time-loading/);
});
