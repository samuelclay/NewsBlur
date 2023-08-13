NEWSBLUR.Models.DiscoverFeed = Backbone.Model.extend({
    initialize: function() {
        var feedData = this.get("feed");
        var storiesData = this.get("stories");
        
        this.set("feed", new NEWSBLUR.Models.Feed(feedData));
        this.set("stories", new NEWSBLUR.Collections.Stories(storiesData));
    }
});

NEWSBLUR.Collections.DiscoverFeeds = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.DiscoverFeed,

    url: function() {
        if (!this.feed_ids || this.feed_ids.length === 0) {
            throw new Error("feed_ids are required to fetch the data");
        }
        
        // Assuming your base endpoint is /api/feed
        return '/discover/feeds/?feed_id=' + this.feed_ids.join("&feed_id=");
    },

    parse: function (response) {
        return _.map(response.discover_feeds, function (feedWithStories, feed_id) {
            return {
                id: parseInt(feed_id, 10),
                feed: feedWithStories.feed,
                stories: feedWithStories.stories
            };
        });
    },

    comparator: function (feedWithStories) {
        var feedId = feedWithStories.get("id");
        return this.feed_ids.indexOf(feedId);
    }

});
