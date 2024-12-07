NEWSBLUR.Collections.DiscoverStories = NEWSBLUR.Collections.Stories.extend({

    url: function () {
        var url = '/rss_feeds/discover/stories/' + this.similar_to_story_hash + '/';
        if (this.feed_ids && this.feed_ids.length > 0) {
            url += '?feed_id=' + this.feed_ids.join("&feed_id=");
        }

        return url;
    },

    parse: function (response) {
        return response.discover_stories;
    }

});
