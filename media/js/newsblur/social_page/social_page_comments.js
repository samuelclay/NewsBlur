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
            format: "html"
        }, _.bind(function(template) {
            var $template = $(template);
            var $header = this.make('div', { 
                "class": 'NB-story-comments-public-header-wrapper' 
            }, this.make('div', { 
                "class": 'NB-story-comments-public-header' 
            }, Inflector.pluralize(' public comment', $template.length, true)));

            this.$(".NB-story-comments-public-teaser-wrapper").replaceWith($template);
            $template.before($header);
        }, this));
    }
    
});
