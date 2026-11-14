const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// mobile_story_view_preferences.test.js runs the real pager preference methods against saved
// feed settings, including the interval before reader.js selects the newly arriving story.
function pager_fixture(active_feed) {
    const settings = new Map([[active_feed, 'feed'], [101, 'text'], [202, 'feed']]);
    const saves = [];
    const context = {
        NEWSBLUR: {
            Views: {},
            reader: { active_feed: active_feed },
            assets: {
                view_setting: function (feed_id, setting) {
                    if (typeof setting === 'object') {
                        settings.set(feed_id, setting.view);
                        saves.push({ feed_id: feed_id, view: setting.view });
                    }
                    return settings.get(feed_id);
                },
                get_feed: function () { return { get: function () { return false; } }; }
            },
            utils: { is_url_iframe_buster: function () { return false; } }
        },
        Backbone: {
            View: { extend: function (methods) { return methods; } },
            Router: { extend: function (methods) { return methods; } }
        },
        $: function (element) { return element; },
        window: { addEventListener: function () {} },
        console: { log: function () {} }
    };
    context.jQuery = context.$;
    vm.createContext(context);
    ['media/js/vendor/underscore-1.4.3.js', 'media/js/vendor/underscore.string.js',
        'media/js/newsblur/reader/reader.js',
        'media/js/newsblur/views/mobile_story_pager_view.js'].forEach(function (filename) {
        vm.runInContext(fs.readFileSync(path.join(repo_root, filename), 'utf8'), context);
    });
    context.NEWSBLUR.reader.active_story_view = context.NEWSBLUR.Reader.active_story_view;
    const pager = Object.create(context.NEWSBLUR.Views.MobileStoryPager);
    pager.pages = { current: {} };
    // mobile_story_view_preferences.test.js: the pager tells the layout when its page changes.
    pager.mobile = { sync_page_scroll: function () {} };
    pager.render_page = function () { pager.rendered_mode = pager.story_view_mode(); };
    pager.update_chrome = function () {};
    function story(feed_id) {
        return { get: function (key) { return key === 'story_feed_id' ? feed_id : undefined; } };
    }
    function select(view) {
        pager.select_view({ currentTarget: {
            data: function () { return view; }, hasClass: function () { return false; }
        } });
    }
    return { pager, reader: context.NEWSBLUR.reader, settings, saves, story, select };
}

for (const active_feed of ['river:everything', 'river:folder:Technology']) {
    test('paging ' + active_feed + ' uses each source feed view before and after selection', function () {
        const h = pager_fixture(active_feed);
        const first = h.story(101);
        const second = h.story(202);
        h.pager.story = first;
        h.reader.active_story = first;
        assert.equal(h.reader.active_story_view(), 101);
        assert.equal(h.pager.story_view_mode(), 'text');

        h.pager.story = second;
        assert.equal(h.pager.story_view_mode(), 'feed', 'arriving story is resolved before global selection');
        h.reader.active_story = second;
        assert.equal(h.pager.story_view_mode(), 'feed');
        h.pager.story = first;
        assert.equal(h.pager.story_view_mode(), 'text', 'paging back restores the first feed preference');
    });

    test('changing view in ' + active_feed + ' saves only the current source feed', function () {
        const h = pager_fixture(active_feed);
        h.pager.story = h.story(101);
        h.reader.active_story = h.pager.story;
        h.select('feed');
        assert.deepEqual(h.saves, [{ feed_id: 101, view: 'feed' }]);
        assert.equal(h.pager.rendered_mode, 'feed');
        h.pager.story = h.story(202);
        h.reader.active_story = h.pager.story;
        h.select('text');
        assert.deepEqual(h.saves, [{ feed_id: 101, view: 'feed' }, { feed_id: 202, view: 'text' }]);
        assert.equal(h.settings.get(active_feed), 'feed', 'river preference is unchanged');
        assert.equal(h.settings.get(101), 'feed', 'other feed preference is unchanged');
        assert.equal(h.pager.rendered_mode, 'text');
    });
}

test('non-river reading preserves the active view setting and Story mode mapping', function () {
    const h = pager_fixture('starred');
    h.pager.story = h.story(101);
    h.reader.active_story = h.pager.story;
    assert.equal(h.reader.active_story_view(), 'starred');
    assert.equal(h.pager.story_view_mode(), 'feed');
    h.select('story');
    assert.deepEqual(h.saves, [{ feed_id: 'starred', view: 'story' }]);
    assert.equal(h.pager.rendered_mode, 'story');
    assert.equal(h.reader.story_view, 'feed', 'desktop reader stays out of its own story iframe');
});
