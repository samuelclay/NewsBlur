const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function load(file) {
    let submitted;
    let unload;
    const element = { off() { return this; }, on(event, callback) { unload = callback; return this; } };
    const $ = () => element;
    $.extend = Object.assign;
    $.ajax = options => { submitted = options.data; };
    const context = {
        NEWSBLUR: { Views: {}, Modal: function () {} },
        Backbone: { View: { extend: methods => methods } },
        _: { extend: Object.assign },
        $,
        window: {},
        navigator: { sendBeacon(url, data) { submitted = data; } },
        FormData,
        // test_web.js deliberately changes every message to expose translated protocol identifiers.
        gettext: message => 'übersetzt:' + message,
    };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '..', file), 'utf8'), context);
    return { context, submitted: () => submitted, unload: () => unload() };
}

test('icon uploads keep feed and folder field names in a non-English interface', () => {
    const fixture = load('media/js/newsblur/reader/reader_feed_exception.js');
    const upload = fixture.context.NEWSBLUR.ReaderFeedException.prototype.upload_icon_file;
    const file = new Blob(['icon']);
    upload.call({ feed: true, feed_id: 123 }, file);
    assert.deepEqual([...fixture.submitted().keys()], ['feed_id', 'photo']);
    assert.equal(fixture.submitted().get('feed_id'), '123');
    upload.call({ folder: true, folder_title: 'My folder' }, file);
    assert.deepEqual([...fixture.submitted().keys()], ['folder_title', 'photo']);
    assert.equal(fixture.submitted().get('folder_title'), 'My folder');
});

test('voice transcription keeps the audio request field name', () => {
    const fixture = load('media/js/newsblur/common/voice_recorder.js');
    fixture.context.NEWSBLUR.VoiceRecorder.prototype.transcribe_audio.call(
        { options: { on_transcription_start() {} } }, new Blob(['audio'], { type: 'audio/webm' }),
    );
    assert.deepEqual([...fixture.submitted().keys()], ['audio']);
});

test('unload beacon preserves playback API fields', () => {
    const fixture = load('media/js/newsblur/views/media_player_view.js');
    fixture.context.NEWSBLUR.Views.MediaPlayerView.setup_beforeunload.call({
        current_media: { story_hash: '123:abc', media_url: 'https://example.test/audio', media_type: 'audio', media_title: 'Story', feed_id: 123 },
        get_current_time: () => 42, get_duration: () => 100,
        playback_rate: 1, volume: 0.5, skip_back_seconds: 10, skip_forward_seconds: 30,
        auto_play_next: true, remember_position: true, resume_on_load: false,
    });
    fixture.unload();
    assert.deepEqual([...fixture.submitted().keys()], [
        'current_story_hash', 'current_media_url', 'current_media_type', 'current_media_title',
        'current_feed_id', 'current_image_url', 'current_position', 'current_duration',
        'current_playback_rate', 'current_volume', 'is_playing', 'skip_back_seconds',
        'skip_forward_seconds', 'auto_play_next', 'remember_position', 'resume_on_load',
    ]);
    assert.equal(fixture.submitted().get('current_position'), '42');
});
