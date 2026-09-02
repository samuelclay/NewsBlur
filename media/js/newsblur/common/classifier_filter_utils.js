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

    function story_title_highlight_selector(type) {
        var selectors = {
            title: '.NB-storytitles-title',
            author: '.NB-storytitles-author',
            text: '.NB-storytitles-content-preview'
        };
        return selectors[type] || null;
    }

    return {
        preserve_active_filter: preserve_active_filter,
        format_result_summary: format_result_summary,
        story_title_highlight_selector: story_title_highlight_selector
    };
});
