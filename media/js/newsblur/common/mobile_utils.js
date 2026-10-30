// mobile_utils.js: pure helpers behind the phone layout (views/mobile_layout_view.js and
// views/mobile_story_pager_view.js). Kept free of DOM and Backbone so node/tests can cover them.
(function (root, factory) {
    var api = factory();

    root.NEWSBLUR = root.NEWSBLUR || {};
    root.NEWSBLUR.mobile_utils = api;

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    // Phones show stories as either an inline-expanding list or a card grid that pushes a
    // full-screen story. Desktop layouts fold into those two: magazine is the closest to grid,
    // and split and full have no second pane to put the story in, so they read as a list.
    var MOBILE_LAYOUTS = ['list', 'grid'];
    var MAX_WIDTH = 768;
    // A phone turned sideways is wider than MAX_WIDTH but still short, so short touch screens
    // count as phones too. Tablets in landscape keep the desktop layout.
    var MAX_LANDSCAPE_HEIGHT = 500;
    var MEDIA_QUERY = '(max-width: ' + MAX_WIDTH + 'px), ' +
        '(pointer: coarse) and (max-height: ' + MAX_LANDSCAPE_HEIGHT + 'px)';

    // Fraction of the screen the swiped screen must cross before a release completes the move.
    var COMPLETE_FRACTION = 0.35;
    // Fling speed in px/ms that completes a move no matter how far it got.
    var FLING_VELOCITY = 0.45;

    function mobile_story_layout(layout) {
        if (layout === 'grid' || layout === 'magazine') return 'grid';
        return 'list';
    }

    // Opening a feed on a phone writes back the layout it shows. Skip the write when the stored
    // desktop layout already maps to it, so a split feed stays split on desktop.
    function should_save_mobile_layout(stored_layout, new_layout) {
        if (!stored_layout) return true;
        return mobile_story_layout(stored_layout) !== mobile_story_layout(new_layout);
    }

    function is_phone_viewport(width, height, coarse_pointer) {
        if (width > 0 && width <= MAX_WIDTH) return true;
        return !!coarse_pointer && height > 0 && height <= MAX_LANDSCAPE_HEIGHT;
    }

    // First path segments of the Backbone routes that open a story list or Add + Discover
    // (media/js/newsblur/common/router.js). Everything else, including the bare root and
    // /welcome, lands on the feed list.
    var TITLES_ROUTES = [
        'site', 'folder', 'social', 'saved', 'read', 'archive', 'briefing', 'briefing-admin', 'try', 'add'
    ];

    function screen_for_path(pathname) {
        var segment = (pathname || '').replace(/^\/+/, '').split('/')[0];
        return TITLES_ROUTES.indexOf(segment) >= 0 ? 'titles' : 'feeds';
    }

    // Each history entry the phone layout touches carries {screen, depth, parent_depth,
    // parent_screen}. Depth counts how many in-app entries sit below it, so a back button knows
    // whether going back stays inside NewsBlur. The parent is the entry of the screen beneath
    // this one: a search or the next feed adds entries on the same screen, and the nav bar's
    // back button skips past them to the screen below.
    function read_history_state(state, pathname) {
        var mobile = state && state.nb_mobile;
        if (mobile && mobile.screen) {
            return {
                screen: mobile.screen,
                depth: mobile.depth || 0,
                parent_depth: typeof mobile.parent_depth === 'number' ? mobile.parent_depth : null,
                parent_screen: mobile.parent_screen || null,
                story_hash: mobile.story_hash || null,
                tagged: true
            };
        }
        return {
            screen: screen_for_path(pathname),
            depth: null,
            parent_depth: null,
            parent_screen: null,
            story_hash: null,
            tagged: false
        };
    }

    // entry is {screen, depth, story_hash, parent_depth, parent_screen}; only screen and depth
    // are required.
    function make_history_state(state, entry) {
        var next = {};
        if (state && typeof state === 'object') {
            for (var key in state) {
                if (Object.prototype.hasOwnProperty.call(state, key)) next[key] = state[key];
            }
        }
        next.nb_mobile = { screen: entry.screen, depth: entry.depth };
        if (entry.story_hash) next.nb_mobile.story_hash = entry.story_hash;
        if (typeof entry.parent_depth === 'number') next.nb_mobile.parent_depth = entry.parent_depth;
        if (entry.parent_screen) next.nb_mobile.parent_screen = entry.parent_screen;
        return next;
    }

    // How many history entries the nav bar's back button walks to reach the screen beneath.
    // 0 means there is no in-app entry to return to (a deep link or reload).
    function back_steps(entry) {
        if (!entry || !entry.tagged || !entry.depth) return 0;
        if (typeof entry.parent_depth === 'number' && entry.parent_depth < entry.depth) {
            return entry.depth - entry.parent_depth;
        }
        return 1;
    }

    // Moving to a deeper history entry slides the new screen in from the trailing edge; moving
    // to a shallower one slides the current screen back out. Untagged entries (depth null) are
    // ordered by screen instead.
    var SCREEN_LEVELS = { feeds: 0, dashboard: 1, titles: 1, story: 2 };

    function transition_direction(from, to) {
        if (!from || !to) return 'none';
        if (from.screen === to.screen && from.story_hash === to.story_hash) return 'none';
        if (from.depth !== null && to.depth !== null && from.depth !== to.depth) {
            return to.depth > from.depth ? 'push' : 'pop';
        }
        var from_level = SCREEN_LEVELS[from.screen] || 0;
        var to_level = SCREEN_LEVELS[to.screen] || 0;
        if (to_level === from_level) return from.screen === to.screen ? 'none' : 'push';
        return to_level > from_level ? 'push' : 'pop';
    }

    function parent_screen(screen) {
        if (screen === 'story') return 'titles';
        return 'feeds';
    }

    // A drag ends by completing (the screen leaves) or snapping back. dx is the distance moved
    // toward completion, velocity is px/ms in that same direction.
    function swipe_completes(dx, velocity, width) {
        if (!width) return false;
        if (velocity > FLING_VELOCITY && dx > 0) return true;
        if (velocity < -FLING_VELOCITY) return false;
        return dx / width > COMPLETE_FRACTION;
    }

    // Story pager: dx > 0 drags toward the previous story. Returns -1 (previous), 1 (next) or 0.
    function pager_step(dx, velocity, width, has_previous, has_next) {
        var toward_previous = swipe_completes(dx, velocity, width);
        var toward_next = swipe_completes(-dx, -velocity, width);
        if (toward_previous && has_previous) return -1;
        if (toward_next && has_next) return 1;
        return 0;
    }

    // Past the last story the page follows the finger at a fraction of the distance, the way
    // native scroll views resist overscroll.
    function rubber_band(dx, width) {
        if (!width) return 0;
        var sign = dx < 0 ? -1 : 1;
        var distance = Math.abs(dx);
        return sign * (width * 0.25) * (1 - 1 / (distance / (width * 0.5) + 1));
    }

    // Decides whether a touch is a horizontal drag once it has moved far enough to tell.
    // Returns 'horizontal', 'vertical' or null while still undecided.
    function gesture_axis(dx, dy, threshold) {
        threshold = threshold || 8;
        var abs_x = Math.abs(dx);
        var abs_y = Math.abs(dy);
        if (abs_x < threshold && abs_y < threshold) return null;
        return abs_x > abs_y * 1.2 ? 'horizontal' : 'vertical';
    }

    return {
        MOBILE_LAYOUTS: MOBILE_LAYOUTS,
        MAX_WIDTH: MAX_WIDTH,
        MEDIA_QUERY: MEDIA_QUERY,
        mobile_story_layout: mobile_story_layout,
        should_save_mobile_layout: should_save_mobile_layout,
        is_phone_viewport: is_phone_viewport,
        screen_for_path: screen_for_path,
        read_history_state: read_history_state,
        make_history_state: make_history_state,
        transition_direction: transition_direction,
        back_steps: back_steps,
        parent_screen: parent_screen,
        swipe_completes: swipe_completes,
        pager_step: pager_step,
        rubber_band: rubber_band,
        gesture_axis: gesture_axis
    };
});
