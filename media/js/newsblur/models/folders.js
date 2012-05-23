NEWSBLUR.Models.FeedOrFolder = Backbone.Model.extend({
    
    initialize: function(model) {
        if (_.isNumber(model)) {
            this.feed = NEWSBLUR.assets.feeds.get(model);
            this.set('is_feed', true);
        } else if (model) {
            var title = _.keys(model)[0];
            var children = model[title];
            this.set('is_folder', true);
            this.set('folder_title', title);
            this.folders = new NEWSBLUR.Collections.Folders([], {title: title});
            this.folders.reset(children);
        }
    },
    
    is_feed: function() {
        return this.get('is_feed', false);
    },
    
    is_folder: function() {
        return this.get('is_folder', false);
    }
    
});

NEWSBLUR.Collections.Folders = Backbone.Collection.extend({
    
    options: {
        title: ''
    },
    
    initialize: function() {
        this.comparator = NEWSBLUR.Collections.Folders.comparator;
    },
    
    model: NEWSBLUR.Models.FeedOrFolder
    
}, {
    
    comparator: function(modelA, modelB) {
        var sort_order = NEWSBLUR.assets.preference('feed_order');
        
        
        if (modelA.is_feed() != modelB.is_feed()) {
            // Feeds above folders
            return modelA.is_feed() ? -1 : 1;
        }
        if (modelA.is_folder()) {
            // Folders are alphabetical
            return modelA.get('folder_title').toLowerCase() > modelB.get('folder_title').toLowerCase() ? 1 : -1;
        }
        
        var feedA = modelA.feed;
        var feedB = modelB.feed;
        if (sort_order == 'ALPHABETICAL' || !sort_order) {
            return feedA.get('feed_title').toLowerCase() > feedB.get('feed_title').toLowerCase() ? 1 : -1;
        } else if (sort_order == 'MOSTUSED') {
            return feedA.get('feed_opens') < feedB.get('feed_opens') ? 1 : 
                (feedA.get('feed_opens') > feedB.get('feed_opens') ? -1 : 
                (feedA.get('feed_title').toLowerCase() > feedB.get('feed_title').toLowerCase() ? 1 : -1));
        }
    }

});