const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// media_player_restore.test.js: Loads media/js/newsblur/views/media_player_view.js with the
// globals restore_state touches, and returns a player whose rendering and media calls are recorded
// instead of run.
function load_player(playback_state) {
    const window_events = { off: function () { return window_events; }, on: function () { return window_events; } };
    const context = {
        NEWSBLUR: { Views: {}, assets: { playback_state: playback_state } },
        Backbone: { View: { extend: function (methods) { return methods; } } },
        $: function () { return window_events; },
        window: {},
        setTimeout: function () { return 0; },
        clearTimeout: function () {},
        gettext: function (message) { return message; }
    };
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/vendor/underscore-1.4.3.js'), 'utf8'), context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/newsblur/views/media_player_view.js'), 'utf8'), context);

    const player = Object.create(context.NEWSBLUR.Views.MediaPlayerView);
    player.initialize();
    player.calls = [];
    ['render', 'show_player', 'create_media_element', 'probe_queue_durations', 'seek_to',
        'update_progress_display'].forEach(function (method) {
        player[method] = function () { player.calls.push(method); return player; };
    });
    return player;
}

// media_player_restore.test.js: The Up Next entry the iOS and Android Listen players add for a
// story, without ever setting current_media_url.
const mobile_queue_item = {
    story_hash: '42:abcdef',
    media_url: '/listen/story/42:abcdef',
    media_type: 'listen',
    media_title: 'Queued on a phone',
    feed_id: 42,
    image_url: ''
};
const history_item = {
    story_hash: '42:123456',
    media_url: '/listen/story/42:123456',
    media_type: 'listen',
    media_title: 'Listened yesterday',
    feed_id: 42
};

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

test('restore_state keeps an Up Next queue saved without a current item', function () {
    const player = load_player({
        queue: [mobile_queue_item],
        history: [history_item],
        skip_back_seconds: 10,
        skip_forward_seconds: 45
    });

    player.restore_state();

    assert.deepEqual(plain(player.queue), [mobile_queue_item]);
    assert.deepEqual(plain(player.history), [history_item]);
    assert.equal(player.skip_back_seconds, 10);
    assert.equal(player.skip_forward_seconds, 45);
    assert.equal(player.current_media, null);
    assert.deepEqual(player.calls, []);
});

test('restore_state keeps the Up Next queue when resume on load is off', function () {
    const player = load_player({
        current_story_hash: '7:podcast',
        current_media_url: 'https://example.com/episode.mp3',
        current_media_type: 'audio',
        current_media_title: 'An episode',
        current_feed_id: 7,
        resume_on_load: false,
        queue: [mobile_queue_item],
        history: [history_item]
    });

    player.restore_state();

    assert.deepEqual(plain(player.queue), [mobile_queue_item]);
    assert.deepEqual(plain(player.history), [history_item]);
    assert.equal(player.resume_on_load, false);
    assert.equal(player.current_media, null);
    assert.deepEqual(player.calls, []);
});

test('restore_state restores the current item together with its queue', function () {
    const player = load_player({
        current_story_hash: '7:podcast',
        current_media_url: 'https://example.com/episode.mp3',
        current_media_type: 'audio',
        current_media_title: 'An episode',
        current_feed_id: 7,
        current_position: 120,
        queue: [mobile_queue_item],
        history: [history_item]
    });

    player.restore_state();

    assert.equal(player.current_media.media_url, 'https://example.com/episode.mp3');
    assert.equal(player.current_position, 120);
    assert.deepEqual(plain(player.queue), [mobile_queue_item]);
    assert.deepEqual(plain(player.history), [history_item]);
    assert.deepEqual(player.calls.slice(0, 4), ['probe_queue_durations', 'render', 'show_player',
        'create_media_element']);
});

test('restore_state starts with an empty queue when nothing was saved', function () {
    const player = load_player(null);

    player.restore_state();

    assert.deepEqual(plain(player.queue), []);
    assert.deepEqual(plain(player.history), []);
    assert.equal(player.state_restored, true);
    assert.deepEqual(player.calls, []);
});
