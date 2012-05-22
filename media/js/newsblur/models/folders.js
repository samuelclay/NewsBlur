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
            this.folders.parse(children);
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
    
    model: NEWSBLUR.Models.FeedOrFolder,
    
    parse: function(models) {
        this.reset(models);
    }
    
}, {
    
    comparator: function(modelA, modelB) {
        var sort_order = NEWSBLUR.assets.preference('feed_order');
        var feedA, feedB;
        if (modelA && modelA.e instanceof jQuery) feedA = NEWSBLUR.assets.feeds.get(parseInt(a.e.data('id'), 10));
        if (modelB && modelB.e instanceof jQuery) feedB = NEWSBLUR.assets.feeds.get(parseInt(b.e.data('id'), 10));
        if (modelA && modelA.is_feed()) feedA = modelA.model;
        if (modelB && modelB.is_feed()) feedB = modelB.model;
        
        // console.log(["feeds", sort_order, modelA, modelB, feedA, feedB]);
        
        if (sort_order == 'ALPHABETICAL' || !sort_order) {
            if (feedA && feedB) {
                return feedA.get('feed_title').toLowerCase() > feedB.get('feed_title').toLowerCase() ? 1 : -1;
            } else if (feedA && !feedB) {
                return -1;
            } else if (!feedA && feedB) {
                return 1;
            } else if (!feedA && !feedB && modelA && modelB && !modelA.is_feed() && !modelB.is_feed() && !(modelA.e instanceof jQuery) && !(modelB.e instanceof jQuery)) {
                return modelA.get('folder_title').toLowerCase() > modelB.get('folder_title').toLowerCase() ? 1 : -1;
            }
        } else if (sort_order == 'MOSTUSED') {
            if (feedA && feedB) {
                return feedA.get('feed_opens') < feedB.get('feed_opens') ? 1 : 
                    (feedA.get('feed_opens') > feedB.get('feed_opens') ? -1 : 
                    (feedA.get('feed_title').toLowerCase() > feedB.get('feed_title').toLowerCase() ? 1 : -1));
            } else if (feedA && !feedB) {
                return -1;
            } else if (!feedA && feedB) {
                return 1;
            } else if (!feedA && !feedB && modelA && modelB && !modelA.is_feed() && !modelB.is_feed() && !(modelA.e instanceof jQuery) && !(modelB.e instanceof jQuery)) {
                return modelA.get('folder_title').toLowerCase() > modelB.get('folder_title').toLowerCase() ? 1 : -1;
            }
        }
    }

});