NEWSBLUR.Views.SocialPageStory = Backbone.View.extend({
    
    initialize: function() {
        var story_id = this.$el.data("storyId");
        var feed_id = this.$el.data("feedId");
        var user_comments = this.$el.data("userComments");
        
        this.comments_view = new NEWSBLUR.Views.SocialPageComments({
            el: this.$('.NB-story-comments'),
            story_id: story_id,
            feed_id: feed_id
        });
        
        var story = new Backbone.Model({
            story_feed_id: feed_id,
            id: story_id,
            shared_comments: user_comments,
            shared: !!user_comments
        });
        _.delay(_.bind(function() {
            this.share_view = new NEWSBLUR.Views.StoryShareView({
                el: this.el,
                model: story,
                on_social_page: true
            });
            this.$('.NB-feed-story-sideoptions-container').append($(this.share_view.template({
                story: story,
                social_services: NEWSBLUR.assets.social_services
            })));
        }, this), 50);
        
        this.$('.NB-user-avatar').tipsy({
            delayIn: 50,
            gravity: 's',
            fade: true,
            offset: 3
        });
    }
    
});