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

    function format_result_summary(count, is_complete, context) {
        context = context || 'this view';
        if (count === null || count === undefined || (count === 0 && !is_complete)) {
            return 'Finding matching stories in ' + context + '\u2026';
        }
        if (count === 0) {
            return 'No matching stories in ' + context;
        }

        var story_label = count === 1 ? 'matching story' : 'matching stories';
        if (!is_complete) {
            return count + ' ' + story_label + ' loaded from ' + context;
        }
        return count + ' ' + story_label + ' in ' + context;
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
        format_result_summary: format_result_summary,
        read_filter_for_matching_view: read_filter_for_matching_view,
        story_title_highlight_selector: story_title_highlight_selector
    };
});
