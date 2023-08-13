NEWSBLUR.Models.DiscoverFeed = Backbone.Model.extend({
    initialize: function() {
        var feedData = this.get("feed");
        var storiesData = this.get("stories");
        console.log("Discover feed model", this, feedData, storiesData);
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
        return '/discover/feeds/?' + this.feed_ids.join("&feed_id=");
    },

    parse: function (response) {
        console.log("Discover feeds parse", response);
        return _.map(response.discover_feeds, function (feedWithStories, feed_id) {
            console.log("Discover feeds parse", feedWithStories, feed_id);
            return {
                id: feed_id,
                feed: feedWithStories.feed,
                stories: feedWithStories.stories
            };
        });
    }

});
