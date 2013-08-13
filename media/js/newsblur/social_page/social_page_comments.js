NEWSBLUR.Views.SocialPageComments = Backbone.View.extend({
    
    events: {
        "click .NB-story-comment-reply-button"  : "check_reply_or_login",
        "click .NB-story-comment-input"         : "check_comment_or_login",
        "click .NB-story-comment-save"          : "check_comment_or_login",
        "click .NB-story-comment-like"          : "check_comment_or_login",
        "click .NB-story-comments-public-teaser": "load_public_story_comments"
    },
    
    initialize: function() {
        this.story_view = this.options.story_view;
        this.page_view = this.options.page_view;
        
        if (NEWSBLUR.Globals.is_authenticated) {
            var $comments = this.$('.NB-story-comment');
            this.attach_comments($comments);
        }
    },
    
    attach_comments: function($comments) {
        var self = this;
        
        $comments.each(function() {
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
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    check_reply_or_login: function(e) {
        if (!NEWSBLUR.Globals.is_authenticated) {
            e.preventDefault();
            e.stopPropagation();
            this.page_view.login_view.toggle_login_dialog({});
            return false;
        }
    },
    
    check_comment_or_login: function(e) {
        if (!NEWSBLUR.Globals.is_authenticated) {
            e.preventDefault();
            e.stopPropagation();
            this.page_view.login_view.toggle_login_dialog({
                open: true
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
            var $header = $.make('div', { 
                className: 'NB-story-comments-public-header-wrapper' 
            }, [
                $.make('div', { 
                    className: 'NB-story-comments-public-header' 
                }, Inflector.pluralize(' public comment', $('.NB-story-comment', $template).length, true))
            ]);

            this.$(".NB-story-comments-public-teaser-wrapper").replaceWith($template);
            $template.before($header);
        }, this));
    },
    
    replace_comments: function($new_comments) {
        this.$el.replaceWith($new_comments);
        this.setElement($new_comments);
        this.initialize();
    },
    
    replace_comment: function(comment_view, html) {
        if (html && html.code < 0) {
            console.log(["error", html]);
            return;
        }
        var $new_comment = $(html);
        
        comment_view.$el.replaceWith($new_comment);
        comment_view.remove();

        this.story_view.attach_tooltips();
        this.attach_comments($new_comment);
    }
    
});
