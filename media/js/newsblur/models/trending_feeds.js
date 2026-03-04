NEWSBLUR.Models.TrendingFeed = Backbone.Model.extend({
    initialize: function () {
        var feedData = this.get("feed");
        var storiesData = this.get("stories");

        this.set("feed", new NEWSBLUR.Models.Feed(feedData));
        this.set("stories", new NEWSBLUR.Collections.Stories(storiesData));
    }
});

NEWSBLUR.Collections.TrendingFeeds = Backbone.Collection.extend({

    model: NEWSBLUR.Models.TrendingFeed,

    url: function () {
        return '/discover/trending/';
    },

    parse: function (response) {
        this.has_more = response.has_more;
        return _.map(response.trending_feeds, function (feedWithStories, feed_id) {
            return {
                id: parseInt(feed_id, 10),
                feed: feedWithStories.feed,
                stories: feedWithStories.stories,
                trending_score: feedWithStories.trending_score
            };
        });
    }

});
