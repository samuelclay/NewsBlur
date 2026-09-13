(function (root, factory) {
    var api = factory();

    root.NEWSBLUR = root.NEWSBLUR || {};
    root.NEWSBLUR.classifier_filter_utils = api;

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    function preserve_active_filter(options, active_filter) {
        options = options || {};

        if (active_filter && !Object.prototype.hasOwnProperty.call(options, 'classifier_filter')) {
            options.classifier_filter = active_filter;
        }

        return options;
    }

    function read_filter_for_matching_view(read_filter, active_filter) {
        return active_filter ? 'all' : read_filter;
    }

    function story_title_highlight_selector(type) {
        var selectors = {
            title: '.NB-storytitles-title',
            author: '.NB-storytitles-author',
            text: '.NB-storytitles-content-preview'
        };
        return selectors[type] || null;
    }

    function context_for_matching_view(options) {
        options = options || {};
        var is_folder_river = options.is_river && !options.is_social;

        var context = {
            scope: is_folder_river ? 'folder' : 'feed',
            folder_name: is_folder_river ? (options.folder_name || 'Everything') : null,
            feed_id: options.source_feed_id
        };
        if (options.source_story_hash) {
            context.story_hash = options.source_story_hash;
        }
        return context;
    }

    return {
        context_for_matching_view: context_for_matching_view,
        preserve_active_filter: preserve_active_filter,
        read_filter_for_matching_view: read_filter_for_matching_view,
        story_title_highlight_selector: story_title_highlight_selector
    };
});
