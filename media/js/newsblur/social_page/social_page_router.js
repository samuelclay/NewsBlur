NEWSBLUR.Router = Backbone.Router.extend({
    
    routes : {
        "": "index",
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
    
    site: function(feed_id) {
        this.feed_id = feed_id;
    }
    
});