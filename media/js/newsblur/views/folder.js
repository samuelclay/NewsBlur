NEWSBLUR.Views.Folder = Backbone.View.extend({

    className: 'NB-folder',
    
    initialize: function(models) {
        this.models = models;
    },
    
    render: function() {
        console.log(["render models", this.models]);
        var $feeds = _.map(this.models, function(model) {
            var $model;
            console.log(["model", model]);
            if (_.isNumber(model)) {
                var model = NEWSBLUR.assets.feeds.get(model);
                return new NEWSBLUR.Views.Feed({model: model}).render().el;
            } else {
                return new NEWSBLUR.Views.Folder(model).render().el;
            }
        });
        $(this.el).append($feeds);
        return this;
    }
    
});