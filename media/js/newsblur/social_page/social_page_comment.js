NEWSBLUR.Views.SocialPageComment = Backbone.View.extend({
    
    events: {
        "click .NB-story-comment-edit-button": "open_edit",
        "click .NB-story-comment-delete": "delete_comment",
        "click .NB-story-comment-reply .NB-modal-submit-green": "save_social_comment_reply",
        "click .NB-story-comment-reply .NB-modal-submit-delete": "delete_social_comment_reply",
        "click .NB-story-comment-reply-button": "open_reply",
        "click .NB-story-comment-edit-reply-button": "edit_reply",
        "click .NB-story-comment-like": "like_comment"
    },
    
    initialize: function(options) {
        this.story_view = options.story_view;
        this.story_comments_view = options.story_comments_view;
    },
    
    // ===========
    // = Actions =
    // ===========
    
    fetch_comment: function(callback) {
        this.$('.NB-spinner').addClass('NB-active');
        
        this.model.fetch({
            success: _.bind(function() {
                this.$('.NB-spinner').removeClass('NB-active');
                callback && callback();
            }, this)
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    open_edit: function() {
        this.fetch_comment(_.bind(function() {
            var $edit = this.options.story_comments_view.$('.NB-story-comment-edit');
            var $input = $('.NB-story-comment-input', $edit);
            var $del = $('.NB-story-comment-delete', $edit);
            
            this.$el.after($edit);
            this.$el.addClass('NB-hidden');
            $edit.removeClass('NB-hidden');
            $del.removeClass('NB-hidden');
            $input.html(this.model.get('comments')).focus();
        }, this));
    },
    
    edit_reply: function(e) {
        var $reply = $(e.currentTarget).closest(".NB-story-comment-reply");
        
        this.open_reply({
            $reply: $reply,
            is_editing: true,
            reply_comments: $(".NB-story-comment-reply-content", $reply).text(),
            reply_id: $reply.data("id")
        });
    },
    
    open_reply: function(options) {
        options = options || {};
        var current_user = NEWSBLUR.assets.user_profile;

        if (NEWSBLUR.Globals.blurblog_protected && !NEWSBLUR.Globals.blurblog_following) {
            var $error = this.$('.NB-story-comment-error');
            $error.text("You must be following " + NEWSBLUR.Globals.blurblog_username + " to reply");
            return;
        }
        var $form = $.make('div', { className: 'NB-story-comment-reply NB-story-comment-reply-form' }, [
            $.make('img', { className: 'NB-user-avatar NB-story-comment-reply-photo', src: current_user.get('photo_url') }),
            $.make('div', { className: 'NB-story-comment-username NB-story-comment-reply-username' }, current_user.get('username')),
            $.make('input', { type: 'text', className: 'NB-input NB-story-comment-reply-comments', value: options.reply_comments }),
            $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green' }, options.is_editing ? 'Save' : 'Post'),
            (options.is_editing && $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-grey NB-modal-submit-delete' }, 'Delete'))
        ]);
        this.remove_social_comment_reply_form();
        
        if (options.is_editing && options.$reply) {
            $form.data('reply_id', options.reply_id);
            options.$reply.hide().addClass('NB-story-comment-reply-hidden');
            options.$reply.after($form);
        } else {
            this.$el.append($form);
        }
        
        $('.NB-story-comment-reply-comments', $form).bind('keydown', 'enter', 
            _.bind(this.save_social_comment_reply, this));
        $('.NB-story-comment-reply-comments', $form).bind('keydown', 'return', 
            _.bind(this.save_social_comment_reply, this));
        $('.NB-story-comment-reply-comments', $form).bind('keydown', 'esc', _.bind(function(e) {
            e.preventDefault();
            this.remove_social_comment_reply_form();
        }, this));
        $('input', $form).focus();
        
        if (NEWSBLUR.app.story_list) {
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }
    },
    
    remove_social_comment_reply_form: function() {
        this.$('.NB-story-comment-reply-form').remove();
        this.$('.NB-story-comment-reply-hidden').show();
    },
    
    save_social_comment_reply: function() {
        var $form = this.$('.NB-story-comment-reply-form');
        var $submit = $(".NB-modal-submit-green", $form);
        var $delete_button = $(".NB-modal-submit-delete", $form);
        var comment_user_id = this.model.get('user_id');
        var comment_reply = $('.NB-story-comment-reply-comments', $form).val();
        var reply_id = $form.data('reply_id');
        
        if (!comment_reply || comment_reply.length <= 1) {
            this.remove_social_comment_reply_form();
            if (NEWSBLUR.app.story_list) {
                NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
            }
            return;
        }
        
        if ($submit.hasClass('NB-disabled')) {
            return;
        }
        
        $delete_button.hide();
        $submit.addClass('NB-disabled').text('Posting...');
        NEWSBLUR.assets.save_comment_reply(this.options.story.id, this.options.story.get('story_feed_id'), 
                                      comment_user_id, comment_reply, 
                                      reply_id,
                                      _.bind(function(data) {
            this.options.story_comments_view.replace_comment(this, data);
        }, this), _.bind(function(data) {
            var message = data && data.message || "Sorry, this reply could not be posted. Probably Adblock.";
            if (!NEWSBLUR.Globals.is_authenticated) {
                message = "You need to be logged in to reply to a comment.";
            }
            var $error = $.make('div', { className: 'NB-error' }, message);
            $submit.removeClass('NB-disabled').text('Post');
            $form.find('.NB-error').remove();
            $form.append($error);
            if (NEWSBLUR.app.story_list) {
                NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
            }
        }, this));
    },
    
    delete_comment: function() {
        this.story_view.mark_story_as_unshared();
    },
    
    delete_social_comment_reply: function() {
        var $form = this.$('.NB-story-comment-reply-form');
        var $submit = $(".NB-modal-submit-green", $form);
        var $delete_button = $(".NB-modal-submit-delete", $form);
        var comment_user_id = this.model.get('user_id');
        var reply_id = $form.data('reply_id');
                
        if ($submit.hasClass('NB-disabled') || $delete_button.hasClass('NB-disabled')) {
            return;
        }
        
        $submit.addClass('NB-disabled');
        $delete_button.addClass('NB-disabled').text('Deleting...');
        NEWSBLUR.assets.delete_comment_reply(this.options.story.id,
                                             this.options.story.get('story_feed_id'), 
                                             comment_user_id, reply_id,
                                             _.bind(function(data) {
            this.options.story_comments_view.replace_comment(this, data);
        }, this), _.bind(function(data) {
            var message = data && data.message || "Sorry, this reply could not be deleted.";
            var $error = $.make('div', { className: 'NB-error' }, message);
            $submit.removeClass('NB-disabled').text('Post');
            $delete_button.removeClass('NB-disabled').text('Delete');
            $form.find('.NB-error').remove();
            $form.append($error);
            if (NEWSBLUR.app.story_list) {
                NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
            }
        }, this));
    },
    
    like_comment: function() {
        var comment_user_id = this.model.get('user_id');
        var liked = $(".NB-story-comment-like", this.$el).hasClass('NB-active');
        
        if (!liked) {
            NEWSBLUR.assets.like_comment(this.options.story.id, 
                                         this.options.story.get('story_feed_id'),
                                         comment_user_id, _.bind(function(data) {
            this.options.story_comments_view.replace_comment(this, data);
        }, this));
        } else {
            NEWSBLUR.assets.remove_like_comment(this.options.story.id, 
                                                this.options.story.get('story_feed_id'),
                                                comment_user_id, _.bind(function(data) {
            this.options.story_comments_view.replace_comment(this, data);
        }, this));
        }
    }
    
});