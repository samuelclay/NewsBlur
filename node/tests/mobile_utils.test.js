const test = require('node:test');
const assert = require('node:assert/strict');

const mobile_utils = require('../../media/js/newsblur/common/mobile_utils.js');

test('phone layouts fold desktop layouts into list or grid', function () {
    assert.equal(mobile_utils.mobile_story_layout('split'), 'list');
    assert.equal(mobile_utils.mobile_story_layout('full'), 'list');
    assert.equal(mobile_utils.mobile_story_layout('list'), 'list');
    assert.equal(mobile_utils.mobile_story_layout('magazine'), 'grid');
    assert.equal(mobile_utils.mobile_story_layout('grid'), 'grid');
    assert.equal(mobile_utils.mobile_story_layout(undefined), 'list');
});

test('opening a feed on a phone leaves the desktop layout alone unless it changes', function () {
    // A split feed shows as a list on a phone; writing "list" back would lose split on desktop.
    assert.equal(mobile_utils.should_save_mobile_layout('split', 'list'), false);
    assert.equal(mobile_utils.should_save_mobile_layout('full', 'list'), false);
    assert.equal(mobile_utils.should_save_mobile_layout('magazine', 'grid'), false);
    // Choosing the other phone layout is a real change and is saved.
    assert.equal(mobile_utils.should_save_mobile_layout('split', 'grid'), true);
    assert.equal(mobile_utils.should_save_mobile_layout('grid', 'list'), true);
    assert.equal(mobile_utils.should_save_mobile_layout(undefined, 'grid'), true);
});

test('routes that open a story list land on the titles screen', function () {
    assert.equal(mobile_utils.screen_for_path('/'), 'feeds');
    assert.equal(mobile_utils.screen_for_path(''), 'feeds');
    assert.equal(mobile_utils.screen_for_path('/welcome'), 'feeds');
    assert.equal(mobile_utils.screen_for_path('/site/476/daring-fireball'), 'titles');
    assert.equal(mobile_utils.screen_for_path('/folder/everything'), 'titles');
    assert.equal(mobile_utils.screen_for_path('/social/12/samuel'), 'titles');
    assert.equal(mobile_utils.screen_for_path('/saved/recipes'), 'titles');
    assert.equal(mobile_utils.screen_for_path('/read'), 'titles');
    assert.equal(mobile_utils.screen_for_path('/briefing'), 'titles');
});

test('history entries keep their tag and fall back to the URL when untagged', function () {
    const tagged = mobile_utils.read_history_state({
        nb_mobile: { screen: 'story', depth: 2, story_hash: '476:abc' }
    }, '/site/476/df');
    assert.deepEqual(tagged, {
        screen: 'story', depth: 2, parent_depth: null, parent_screen: null, story_hash: '476:abc', tagged: true
    });

    const untagged = mobile_utils.read_history_state({}, '/site/476/df');
    assert.deepEqual(untagged, {
        screen: 'titles', depth: null, parent_depth: null, parent_screen: null, story_hash: null, tagged: false
    });

    const empty = mobile_utils.read_history_state(null, '/');
    assert.equal(empty.screen, 'feeds');
});

test('tagging an entry preserves state other code stored on it', function () {
    const state = mobile_utils.make_history_state({ classifier: 'tag' }, { screen: 'titles', depth: 1 });
    assert.equal(state.classifier, 'tag');
    assert.deepEqual(state.nb_mobile, { screen: 'titles', depth: 1 });

    const story_state = mobile_utils.make_history_state(null, { screen: 'story', depth: 2, story_hash: '476:abc' });
    assert.deepEqual(story_state.nb_mobile, { screen: 'story', depth: 2, story_hash: '476:abc' });
});

test('history entries remember the screen beneath them', function () {
    const state = mobile_utils.make_history_state({}, {
        screen: 'titles', depth: 3, parent_depth: 1, parent_screen: 'dashboard'
    });
    const entry = mobile_utils.read_history_state(state, '/site/476/df?search=apple');
    assert.equal(entry.parent_depth, 1);
    assert.equal(entry.parent_screen, 'dashboard');
    // Older entries without a parent still read cleanly.
    const legacy = mobile_utils.read_history_state({ nb_mobile: { screen: 'titles', depth: 1 } }, '/');
    assert.equal(legacy.parent_depth, null);
});

test('the back button skips same-screen entries to reach the screen beneath', function () {
    // feeds(0) -> titles(1) -> search on the same list(2): back returns to feeds.
    assert.equal(mobile_utils.back_steps({ tagged: true, depth: 2, parent_depth: 0 }), 2);
    // A story pushed from that list goes back one entry.
    assert.equal(mobile_utils.back_steps({ tagged: true, depth: 3, parent_depth: 2 }), 1);
    // Without a recorded parent, back walks a single entry.
    assert.equal(mobile_utils.back_steps({ tagged: true, depth: 2, parent_depth: null }), 1);
    // A deep link has nothing in-app behind it.
    assert.equal(mobile_utils.back_steps({ tagged: true, depth: 0, parent_depth: null }), 0);
    assert.equal(mobile_utils.back_steps({ tagged: false, depth: null, parent_depth: null }), 0);
});

test('deeper history entries push and shallower ones pop', function () {
    const feeds = { screen: 'feeds', depth: 0, story_hash: null };
    const titles = { screen: 'titles', depth: 1, story_hash: null };
    const story = { screen: 'story', depth: 2, story_hash: '476:abc' };
    const next_story = { screen: 'story', depth: 2, story_hash: '476:def' };

    assert.equal(mobile_utils.transition_direction(feeds, titles), 'push');
    assert.equal(mobile_utils.transition_direction(titles, story), 'push');
    assert.equal(mobile_utils.transition_direction(story, titles), 'pop');
    assert.equal(mobile_utils.transition_direction(titles, feeds), 'pop');
    assert.equal(mobile_utils.transition_direction(titles, titles), 'none');
    // Another story at the same depth swaps the pager's content in place, with no slide.
    assert.equal(mobile_utils.transition_direction(story, next_story), 'none');
    // Opening another feed from the titles screen is a deeper entry on the same screen.
    assert.equal(mobile_utils.transition_direction(titles, { screen: 'titles', depth: 2 }), 'push');
});

test('untagged entries are ordered by screen level', function () {
    const story = { screen: 'story', depth: 2, story_hash: '476:abc' };
    const untagged_titles = { screen: 'titles', depth: null, story_hash: null };
    const untagged_feeds = { screen: 'feeds', depth: null, story_hash: null };

    assert.equal(mobile_utils.transition_direction(story, untagged_titles), 'pop');
    assert.equal(mobile_utils.transition_direction(untagged_feeds, untagged_titles), 'push');
});

test('back goes from a story to its list and from a list to the feeds', function () {
    assert.equal(mobile_utils.parent_screen('story'), 'titles');
    assert.equal(mobile_utils.parent_screen('titles'), 'feeds');
    assert.equal(mobile_utils.parent_screen('dashboard'), 'feeds');
});

test('a released swipe completes past a third of the screen or on a fling', function () {
    const width = 390;
    assert.equal(mobile_utils.swipe_completes(100, 0.1, width), false);
    assert.equal(mobile_utils.swipe_completes(150, 0.1, width), true);
    assert.equal(mobile_utils.swipe_completes(40, 0.9, width), true);
    // Flicking back toward the start cancels even after a long drag.
    assert.equal(mobile_utils.swipe_completes(300, -0.9, width), false);
    assert.equal(mobile_utils.swipe_completes(0, 0.9, width), false);
    assert.equal(mobile_utils.swipe_completes(200, 0, 0), false);
});

test('the story pager steps only toward stories that exist', function () {
    const width = 390;
    assert.equal(mobile_utils.pager_step(-200, -0.2, width, true, true), 1);
    assert.equal(mobile_utils.pager_step(200, 0.2, width, true, true), -1);
    assert.equal(mobile_utils.pager_step(-200, -0.2, width, true, false), 0);
    assert.equal(mobile_utils.pager_step(200, 0.2, width, false, true), 0);
    assert.equal(mobile_utils.pager_step(-30, -0.05, width, true, true), 0);
    assert.equal(mobile_utils.pager_step(-30, -0.8, width, true, true), 1);
});

test('overscroll past the last story resists the finger', function () {
    const width = 400;
    const pulled = mobile_utils.rubber_band(-300, width);
    assert.ok(pulled < 0);
    assert.ok(Math.abs(pulled) < 100);
    assert.ok(Math.abs(mobile_utils.rubber_band(-600, width)) > Math.abs(pulled));
    assert.equal(mobile_utils.rubber_band(50, 0), 0);
});

test('a touch commits to an axis once it has moved far enough', function () {
    assert.equal(mobile_utils.gesture_axis(3, 2), null);
    assert.equal(mobile_utils.gesture_axis(20, 4), 'horizontal');
    assert.equal(mobile_utils.gesture_axis(4, 20), 'vertical');
    assert.equal(mobile_utils.gesture_axis(-20, 5), 'horizontal');
    // A diagonal drag scrolls the page instead of swiping.
    assert.equal(mobile_utils.gesture_axis(15, 14), 'vertical');
});

test('the phone layout covers phones in either orientation and small tablets in portrait', function () {
    assert.equal(mobile_utils.is_phone_viewport(390, 844, true), true);
    assert.equal(mobile_utils.is_phone_viewport(768, 1024, true), true);
    // An iPhone turned sideways stays a phone.
    assert.equal(mobile_utils.is_phone_viewport(844, 390, true), true);
    // An iPad in landscape and a short desktop window keep the desktop layout.
    assert.equal(mobile_utils.is_phone_viewport(1024, 768, true), false);
    assert.equal(mobile_utils.is_phone_viewport(1200, 450, false), false);
    assert.equal(mobile_utils.is_phone_viewport(0, 0, false), false);
    assert.match(mobile_utils.MEDIA_QUERY, /max-width: 768px/);
    assert.match(mobile_utils.MEDIA_QUERY, /pointer: coarse/);
});
