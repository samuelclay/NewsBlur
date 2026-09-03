const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function repo_file(relative_path) {
    return fs.readFileSync(path.join(__dirname, '..', '..', relative_path), 'utf8');
}

test('notification channel controls share icons and a flat enabled underline', function () {
    const popover_js = repo_file('media/js/newsblur/views/classifier_notification_popover.js');
    const feed_js = repo_file('media/js/newsblur/views/feed_notification_view.js');
    const classifier_js = repo_file('media/js/newsblur/views/classifier_notification_view.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(popover_js, /make_channel_content/);
    assert.match(popover_js, /NB-notification-channel-option/);
    assert.match(popover_js, /NB-notification-channel-icon/);
    assert.match(feed_js, /NB-notification-channel-option/);
    assert.match(feed_js, /NB-notification-channel-icon/);
    assert.match(classifier_js, /make_channel_content/);
    assert.match(classifier_js, /NB-notification-channel-option/);

    assert.match(css, /\.NB-notification-channel-option\s*\{[^}]*display:\s*inline-flex;[^}]*border:\s*0;/s);
    assert.match(css, /\.NB-notification-channel-icon svg\s*\{/);
    assert.match(
        css,
        /\.NB-notification-channel-option\.NB-active\s*\{[^}]*box-shadow:\s*inset 0 -2px 0 #4A90D9;/s
    );
});

test('all four channels keep their existing shared icon source', function () {
    const popover_js = repo_file('media/js/newsblur/views/classifier_notification_popover.js');

    for (const channel of ['email', 'web', 'ios', 'android']) {
        assert.match(popover_js, new RegExp("make_channel_content\\('" + channel + "'"));
        assert.match(popover_js, new RegExp(channel + ": '<svg"));
    }
});

test('four-channel controls leave enough room for the Android icon and label', function () {
    const css = repo_file('media/css/reader/reader.css');

    assert.match(
        css,
        /\.NB-feed-notification \.NB-feed-notification-types,\s*\.NB-classifier-notification \.NB-classifier-notification-types\s*\{[^}]*width:\s*248px;/s
    );
});
