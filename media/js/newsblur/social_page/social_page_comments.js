NEWSBLUR.Views.SocialPageComments = Backbone.View.extend({
    
    events: {
        "click .NB-story-comments-public-teaser": "load_public_story_comments"
    },
    
    initialize: function() {
        
    },
    
    load_public_story_comments: function() {
        $.get('/social/public_comments', {
            story_id: this.options.story_id,
            feed_id: this.options.feed_id,
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
    }
    
});
