NEWSBLUR.Views.SocialPageComments = Backbone.View.extend({
    
    events: {
        "click .NB-story-comment-reply-button"  : "check_reply_or_login",
        "focus .NB-story-comment-input"         : "check_comment_or_login",
        "click .NB-story-comments-public-teaser": "load_public_story_comments"
    },
    
    initialize: function() {
        this.comment_views = [];
        this.story_view = this.options.story_view;
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.attach_comments();
        }
    },
    
    attach_comments: function() {
        var self = this;
        
        this.$('.NB-story-comment').each(function() {
            var $comment = $(this);
            var comment = new NEWSBLUR.Models.Comment({
                id: $comment.data('id'),
                user_id: $comment.data('userId')
            });
            var comment_view = new NEWSBLUR.Views.SocialPageComment({
                el: $comment,
                on_social_page: true,
                story: self.model,
                story_comments_view: self,
                story_view: self.story_view,
                model: comment,
                public_comment: $comment.closest(".NB-story-comments-public").length
            });
            self.comment_views.push(comment_view);
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    check_reply_or_login: function(e) {
        if (!NEWSBLUR.Globals.is_authenticated) {
            e.preventDefault();
            e.stopPropagation();
            this.story_view.login_view.toggle_login_dialog({
                resize_open: true,
                scroll: true
            });
            return false;
        }
    },
    
    check_comment_or_login: function(e) {
        if (!NEWSBLUR.Globals.is_authenticated) {
            e.preventDefault();
            e.stopPropagation();
            this.story_view.expand_story({instant: true});
            this.story_view.login_view.toggle_login_dialog({
                resize_open: true,
                scroll: true
            });
            return false;
        }
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
    
    replace_comments: function($new_comments) {
        this.$el.replaceWith($new_comments);
        this.setElement($new_comments);
        this.initialize();
    },
    
    replace_comment: function(comment_user_id, html) {
        var comment_view = _.detect(this.comment_views, function(view) {
            return view.model.get('user_id') == comment_user_id;
        });
        var $new_comment = $(html);
        comment_view.$el.replaceWith($new_comment);
        comment_view.setElement($new_comment);
        this.story_view.attach_tooltips();
        this.initialize();
    }
    
});
