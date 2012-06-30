NEWSBLUR.Views.SocialPageStory = Backbone.View.extend({
    
    initialize: function() {
        this.comments_view = new NEWSBLUR.Views.SocialPageComments({
            el: this.$('.NB-story-comments'),
            story_id: this.$el.data("storyId"),
            feed_id: this.$el.data("feedId")
        });
        
        this.$('.NB-user-avatar').tipsy({
            delayIn: 50,
            gravity: 's',
            fade: true,
            offset: 3
        });
    }
    
});