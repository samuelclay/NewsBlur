NEWSBLUR.Models.DiscoverStory = Backbone.Model.extend({
    initialize: function () {
        var feedData = this.get("feed");
        var storiesData = this.get("stories");

        this.set("feed", new NEWSBLUR.Models.Feed(feedData));
        this.set("stories", new NEWSBLUR.Collections.Stories(storiesData));
    }
});

NEWSBLUR.Collections.DiscoverStories = Backbone.Collection.extend({

    model: NEWSBLUR.Models.DiscoverStory,

    url: function () {
        var url = '/rss_feeds/discover/stories/' + this.similar_to_story_hash + '/';
        if (this.feed_ids && this.feed_ids.length > 0) {
            url += '?feed_id=' + this.feed_ids.join("&feed_id=");
        }

        return url;
    },

    parse: function (response) {
        return _.map(response.discover_stories, function (feedWithStories, feed_id) {
            return {
                id: parseInt(feed_id, 10),
                feed: feedWithStories.feed,
                stories: feedWithStories.stories
            };
        });
    },

    comparator: function (feedWithStories) {
        var feedId = feedWithStories.get("id");
        if (!this.feed_ids || this.feed_ids.length === 0) {
            return 0;
        }
        return this.feed_ids.indexOf(feedId);
    }

});
