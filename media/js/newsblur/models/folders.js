NEWSBLUR.Models.FeedOrFolder = Backbone.Model.extend({
    
    initialize: function(model) {
        console.log(["constructing model", model]);
        if (_.isNumber(model)) {
            this.model = NEWSBLUR.assets.feeds.get(model);
        } else {
            this.model = new NEWSBLUR.Collections.Folders();
            this.title = _.keys(model)[0];
            var children = model[this.title];
            this.model.parse(children);
        }
    }
    
});

NEWSBLUR.Collections.Folders = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.FeedOrFolder,
    
    parse: function(models) {
        console.log(["parse", this.models, models]);
        this.reset(models);
    }

    
});