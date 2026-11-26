const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// favicon.test.js: $.favicon from jquery.newsblur.js, loaded with a jQuery that only collects what
// the file adds to it.
function load_favicon() {
    const jQuery = { fn: { extend() {} }, extend(methods) { Object.assign(jQuery, methods); return jQuery; } };
    const context = {
        jQuery,
        NEWSBLUR: {
            Globals: { MEDIA_URL: '/media/' },
            URLs: { favicon: '/rss_feeds/icon/{id}' },
            assets: { get_folder_icon: () => null, get_feed_icon: () => null, get_feed: () => undefined },
        },
        _: {
            isNumber: value => typeof value === 'number',
            isString: value => typeof value === 'string',
            string: { startsWith: (text, prefix) => text.indexOf(prefix) === 0, include: (text, part) => String(text).indexOf(part) !== -1 },
        },
        console,
    };
    context.window = context;
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../media/js/vendor/jquery.newsblur.js'), 'utf8'), context);
    return jQuery.favicon;
}

test('an id with no icon of its own gets a stand-in instead of an error', () => {
    const favicon = load_favicon();

    // views/feed_folder_picker_view.js asks for an icon by every option's value. A saved search of
    // Read Stories is "search:read:<query>", which names no site, folder or tag, and an error here
    // stops the whole list from opening.
    assert.match(favicon('search:read:claude code'), /search\.svg$/);
    assert.match(favicon('search:archive:claude code'), /search\.svg$/);
    assert.match(favicon('something:else'), /world\.svg$/);
    assert.equal(favicon('search:feed:42:claude code'), '/rss_feeds/icon/42');
});
