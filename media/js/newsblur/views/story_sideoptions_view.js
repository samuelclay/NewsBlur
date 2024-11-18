NEWSBLUR.Views.StorySideoptionsView = Backbone.View.extend({

    initialize: function () {
        this.save_view = new NEWSBLUR.Views.StorySaveView({
            model: this.model,
            el: this.el,
            sideoptions_view: this
        });
        this.share_view = new NEWSBLUR.Views.StoryShareView({
            model: this.model,
            el: this.el,
            sideoptions_view: this
        });
        this.discover_view = new NEWSBLUR.Views.StoryDiscoverView({
            model: this.model,
            el: this.el,
            sideoptions_view: this
        });
    },

    move_discover_view: function () {
        // Move discover view to the end of the ancestor NB-story-content-container's NB-feed-story-content div
        this.$('.NB-story-content-container').append(this.discover_view.$(".NB-sideoption-discover-wrapper"));
    }

});
