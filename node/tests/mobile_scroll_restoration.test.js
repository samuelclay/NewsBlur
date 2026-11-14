const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// mobile_scroll_restoration.test.js exercises navigation with a document that shrinks when its active screen changes.
function fixture() {
    const context = {
        NEWSBLUR: { Views: {}, Globals: {}, reader: { active_feed: null, flags: {} },
            assets: { preference: () => false, view_setting: () => 'list' },
            motion: { remove() {}, enter() {}, duration: () => 0 }, app: {} },
        Backbone: { View: { extend: methods => methods }, Router: { extend: methods => methods },
            History: { started: true }, history: { fragment: '', getFragment: () => 'site/123' } },
        window: { location: { pathname: '/site/123' }, scrollY: 900, addEventListener() {},
            scrollTo({ top }) { this.scrollY = top; } },
        document: { body: {} }, gettext: value => value,
        setTimeout() {}, clearTimeout() {},
        $: value => value, jQuery: value => value
    };
    vm.createContext(context);
    const root = path.resolve(__dirname, '../..');
    for (const file of ['media/js/vendor/underscore-1.4.3.js',
        'media/js/newsblur/reader/reader.js', 'media/js/newsblur/views/mobile_layout_view.js',
        'media/js/newsblur/views/mobile_story_pager_view.js', 'media/js/newsblur/views/story_titles_view.js']) {
        vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context);
    }
    return context;
}

test('Forward after reloading the feed list keeps the routed titles entry and its forward story', () => {
    const c = fixture();
    const layout = Object.create(c.NEWSBLUR.Views.MobileLayout);
    const history = ['feeds', 'titles', 'story'];
    Object.assign(layout, {
        active: true, screen: 'feeds', depth: 0,
        story_pager: { story_hash: () => null },
        utils: { read_history_state: state => state, transition_direction: () => 'push' },
        own_scroll_restoration() {}, restore_parent() {}, update_titles_bar() {},
        browser_swiped: () => false, show_screen(screen) { this.screen = screen; },
        expect_entry(screen) { history.splice(2, 1, screen); }
    });
    layout.handle_popstate({ state: { tagged: true, screen: 'titles', depth: 1 } });
    c.NEWSBLUR.reader.active_feed = 123;
    layout.reader_opened();
    assert.equal(layout.screen, 'titles');
    assert.deepEqual(history, ['feeds', 'titles', 'story'], 'the completed route must not replace the forward story with a duplicate titles entry');
});

test('an unavailable titles entry still returns to feeds when no router can restore it', () => {
    const c = fixture();
    c.Backbone.history.getFragment = () => '';
    const layout = Object.create(c.NEWSBLUR.Views.MobileLayout);
    Object.assign(layout, {
        active: true, screen: 'story', depth: 2,
        story_pager: { story_hash: () => null },
        utils: { read_history_state: state => state, transition_direction: () => 'pop' },
        own_scroll_restoration() {}, restore_parent() {}, update_titles_bar() {},
        browser_swiped: () => false, show_screen(screen) { this.screen = screen; }
    });
    layout.handle_popstate({ state: { tagged: true, screen: 'titles', depth: 1 } });
    assert.equal(layout.screen, 'feeds');
});

test('an immediate screen change saves the outgoing scroll before its document height collapses', () => {
    const c = fixture();
    const scrolls = { titles: { scrollTop: 0 }, story: { scrollTop: 0 } };
    const body = {
        removeClass(classes) {
            if (classes.includes('NB-mobile-screen-is-titles')) c.window.scrollY = 0;
            return this;
        },
        addClass() { return this; }
    };
    const layout = Object.create(c.NEWSBLUR.Views.MobileLayout);
    Object.assign(layout, {
        screen: 'titles', page_scroll_screen: 'titles', $body: body, $screens: {},
        finish_transition() {}, close_sideoption_sheet() {}, clear_drag() {},
        page_scroller: screen => scrolls[screen], hold_page_scroll_events() {},
        measure_browser_chrome() {}, measure_page_bars() {}, wants_page_scroll() { return this.screen; }
    });
    layout.set_screen('story');
    layout.set_screen('titles');
    assert.equal(c.window.scrollY, 900, 'returning to titles must restore the place that was visible before opening the story');
});

test('the last page adds only a viewport of trailing space even when the list is thousands of pixels tall', () => {
    const c = fixture();
    let padding;
    c.$.make = () => ({ css(name, value) { if (name === 'paddingBottom') padding = value; return this; }, find: () => [{}] });
    const titles = Object.create(c.NEWSBLUR.Views.StoryTitlesView);
    Object.assign(titles, {
        options: {}, collection: { length: 100 }, $: () => ({}), $el: { append() {} },
        $story_titles: { height: () => 8000 }, page_scrolls: () => true
    });
    c.NEWSBLUR.app.mobile = { page_viewport_height: () => 700 };
    titles.show_no_more_stories();
    assert.ok(padding >= 20 && padding <= 700, `the final spacer was ${padding}px for a 700px viewport`);
});

test('keyboard paging moves one visible viewport rather than the entire content-sized story list', () => {
    const c = fixture();
    c.NEWSBLUR.assets.preference = key => key === 'space_bar_action' ? 'scroll_only' : false;
    c.NEWSBLUR.app.story_titles = { viewport_height: () => 700 };
    let movement;
    const reader = { $s: { $story_pane: { height: () => 700 }, $story_titles: { height: () => 8000 } },
        flags: {}, scroll_in_story: (height, direction) => { movement = height * direction; } };
    c.NEWSBLUR.Reader.page_in_story.call(reader, 100, 1);
    assert.equal(movement, 700);
});

test('a cancelled reduced-motion swipe returns scrolling to the page immediately', () => {
    const c = fixture();
    let page_scrolling = false;
    const track = { removeClass() { return this; }, css() { return this; } };
    const pager = { $track: track, mobile: { sync_page_scroll() { page_scrolling = true; } } };
    c.NEWSBLUR.Views.MobileStoryPager.snap_back.call(pager);
    assert.equal(page_scrolling, true);
});

test('the registered resize handlers skip mobile height changes but deliver width changes and desktop resizes', () => {
    const c = fixture();
    const listeners = [];
    const jquery_listeners = [];
    c.window.innerWidth = 393;
    c.window.addEventListener = (name, callback) => { if (name === 'resize') listeners.push(callback); };
    c.$ = target => ({ bind(name, callback) {
        if (target === c.window && name === 'resize.reader') jquery_listeners.push(callback);
        return this;
    } });
    c.$.rescope = (callback, owner) => callback.bind(owner);
    c._.throttle = callback => callback;
    c.NEWSBLUR.AssetModel = function () {};
    // mobile_scroll_restoration.test.js stops after init registers its real handlers; no live feed or dashboard is needed.
    const reader = Object.create(c.NEWSBLUR.Reader);
    let layouts = 0;
    Object.assign(reader, { handle_keystrokes() {}, check_and_load_ssl: () => true, resize_window() { layouts += 1; } });
    // reader.js closes over jQuery when loaded, so supply the registration fixture before evaluating its module.
    c.jQuery = c.$;
    vm.runInContext(fs.readFileSync(path.resolve(__dirname, '../../media/js/newsblur/reader/reader.js'), 'utf8'), c);
    // mobile_scroll_restoration.test.js models nav_dropdown.js registering jQuery's shared dispatcher at DOM ready, before reader.init.
    listeners.push(event => jquery_listeners.forEach(callback => callback(event)));
    c.NEWSBLUR.Reader.init.call(reader, {});
    const mobile = c.NEWSBLUR.app.mobile = Object.create(c.NEWSBLUR.Views.MobileLayout);
    Object.assign(mobile, { resize_width: 393, page_scroll_screen: 'titles' });
    function resize(width) {
        c.window.innerWidth = width;
        let stopped = false;
        const event = { stopImmediatePropagation() { stopped = true; } };
        // mobile_scroll_restoration.test.js models window-target registration order, including a later capture listener.
        for (const callback of listeners) { if (!stopped) callback(event); }
    }
    resize(393);
    assert.equal(layouts, 0, 'browser toolbar height changes must not reach the earlier reader handler');
    resize(420);
    assert.equal(layouts, 1, 'changing width still updates the reader layout');
    mobile.page_scroll_screen = null;
    resize(420);
    assert.equal(layouts, 2, 'fixed desktop panes still respond to height changes');
});
