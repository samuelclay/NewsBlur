NEWSBLUR.Collections.DiscoverStories = NEWSBLUR.Collections.Stories.extend({

    url: function () {
        return '/rss_feeds/discover/stories/' + this.similar_to_story_hash + '/';
    },

    parse: function (response) {
        if (response.feeds && Object.keys(response.feeds).length > 0) {
            // console.log(['Adding related stories feeds', response.feeds]);
            _.each(response.feeds, function (feed) {
                NEWSBLUR.assets.set_temp_feed(feed.id, feed);
            });
        }

        return response.discover_stories;
    }

});
