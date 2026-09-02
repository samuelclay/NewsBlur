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

    return {
        preserve_active_filter: preserve_active_filter
    };
});
