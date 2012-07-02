NEWSBLUR.Views.SocialPageComments = Backbone.View.extend({
    
    events: {
        "click .NB-story-comments-public-teaser": "load_public_story_comments"
    },
    
    initialize: function() {
        var self = this;
        this.comment_views = [];
        this.story_view = this.options.story_view;
        
        this.$('.NB-story-comment').each(function() {
            var $comment = $(this);
            var comment_view = new NEWSBLUR.Views.StoryComment({
                el: $comment,
                on_social_page: true,
                story: self.model
            });
            self.comment_views.push(comment_view);
        });
    },
    
    load_public_story_comments: function() {
        $.get('/social/public_comments', {
            story_id: this.model.id,
            feed_id: this.model.get('story_feed_id'),
            user_id: NEWSBLUR.Globals.blurblog_user_id,
            format: "html"
        }, _.bind(function(template) {
            var $template = $($.trim(template));
            var $header = this.make('div', { 
                "class": 'NB-story-comments-public-header-wrapper' 
            }, this.make('div', { 
                "class": 'NB-story-comments-public-header' 
            }, Inflector.pluralize(' public comment', $('.NB-story-comment', $template).length, true)));

            this.$(".NB-story-comments-public-teaser-wrapper").replaceWith($template);
            $template.before($header);
        }, this));
    },
    
    replace_comments: function(html) {
        var $new_comments = $(html);
        this.$el.replaceWith($new_comments);
        this.setElement($new_comments);
        this.story_view.attach_tooltips();
        this.initialize();
    }
    
});
