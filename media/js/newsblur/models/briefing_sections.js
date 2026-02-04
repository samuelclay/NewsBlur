NEWSBLUR.Models.BriefingSectionFeed = Backbone.Model.extend({
    initialize: function () {
        this.set('feed_title', this.get('section_name'));
        this.views = [];
    },
    is_social: function () { return false; },
    is_feed: function () { return false; },
    is_starred: function () { return false; },
    is_search: function () { return false; },
    is_briefing_section: function () { return true; },
    unread_counts: function () {
        return { ps: this.get('count') || 0, nt: 0, ng: 0 };
    }
});

NEWSBLUR.Collections.BriefingSectionFeeds = Backbone.Collection.extend({
    model: NEWSBLUR.Models.BriefingSectionFeed,
    parse: function (models) {
        _.each(models, function (feed) {
            feed.id = 'briefing:' + feed.section_key;
            feed.ps = feed.count;
        });
        return models;
    },
    comparator: function (a, b) {
        // briefing_sections.js: Sort by count descending, then alphabetical
        if (a.get('count') > b.get('count')) return -1;
        if (a.get('count') < b.get('count')) return 1;
        var title_a = (a.get('feed_title') || '').toLowerCase();
        var title_b = (b.get('feed_title') || '').toLowerCase();
        if (title_a > title_b) return 1;
        if (title_a < title_b) return -1;
        return 0;
    },
    selected: function () {
        return this.detect(function (feed) { return feed.get('selected'); });
    },
    deselect: function () {
        this.chain().select(function (feed) {
            return feed.get('selected');
        }).each(function (feed) {
            feed.set('selected', false);
        });
    }
});
