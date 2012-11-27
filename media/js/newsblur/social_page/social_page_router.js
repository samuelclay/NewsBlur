NEWSBLUR.Router = Backbone.Router.extend({
    
    routes : {
        "": "index",
        "story/:slug/:guid": "story_slug",
        "story/:slug/:guid/": "story_slug",
        "story/:guid": "story",
        "story/:guid/": "story",
        "site/:feed_id": "site",
        "site/:feed_id/": "site"
    },
    
    index: function() {
        
    },
    
    story: function(guid) {
        this.story_guid = guid.replace(/\?(.*)$/, '');
    },
    
    story_slug: function(slug, guid) {
        this.story_guid = guid.replace(/\?(.*)$/, '');
    },
    
    site: function(feed_id) {
        this.feed_id = feed_id;
    }
    
});