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
    // briefing_sections.js: No comparator — preserve insertion order to match
    // the section order from the AI-generated summary HTML.
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
