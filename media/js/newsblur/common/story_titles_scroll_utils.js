(function (root, factory) {
    var api = factory();

    root.NEWSBLUR = root.NEWSBLUR || {};
    root.NEWSBLUR.story_titles_scroll_utils = api;

    if (root.NEWSBLUR.utils) {
        root.NEWSBLUR.utils.story_titles_scroll_utils = api;
    }

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    function compute_selected_story_scroll_position(options) {
        options = options || {};

        var element_top = options.element_top;
        var element_height = options.element_height;
        var viewport_height = options.viewport_height;
        var container_scroll = options.container_scroll || 0;
        var force = !!options.force;
        var always_scroll = !!options.always_scroll;
        var scroll_up_only = !!options.scroll_up_only;

        if (typeof element_top !== 'number' ||
            typeof element_height !== 'number' ||
            typeof viewport_height !== 'number') {
            return null;
        }

        var element_bottom = element_top + element_height;
        var fully_visible = element_top >= 0 && element_bottom <= viewport_height;

        if (fully_visible && !force && !always_scroll) {
            return null;
        }

        var position = always_scroll
            ? element_top + container_scroll
            : element_top + container_scroll - viewport_height / 5;

        if (scroll_up_only && position >= container_scroll) {
            return null;
        }

        return position;
    }

    return {
        compute_selected_story_scroll_position: compute_selected_story_scroll_position
    };
});
