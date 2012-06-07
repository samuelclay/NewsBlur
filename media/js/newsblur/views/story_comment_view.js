NEWSBLUR.Views.StoryComment = Backbone.View.extend({
    
    className: 'NB-story-comment',
    
    events: {
        "click .NB-user-avatar": "open_social_profile_modal",
        "click .NB-story-comment-username": "open_social_profile_modal",
        "click .NB-story-comment-reply-button": "open_reply",
        "click .NB-story-comment-share-edit-button": "toggle_feed_story_share_dialog",
        "click .NB-story-comment-reply .NB-modal-submit-button": "save_social_comment_reply"
    },
    
    initialize: function(options) {
        this.story = options.story;
        this.user = NEWSBLUR.assets.user_profiles.find(this.model.get('user_id'));
    },
    
    render: function() {
        this.model.set('comments', this.model.get('comments').replace(/\n+/g, '<br><br>'));
        var reshare_class = this.model.get('source_user_id') ? 'NB-story-comment-reshare' : '';

        var $comment = $.make('div', [
            $.make('div', { className: 'NB-user-avatar ' + reshare_class }, [
                $.make('img', { src: this.user.get('photo_url') })
            ]),
            $.make('div', { className: 'NB-story-comment-author-container' }, [
                (this.model.get('source_user_id') && $.make('div', { className: 'NB-story-comment-reshares' }, [
                    NEWSBLUR.Views.ProfileThumb.create(this.model.get('source_user_id'))
                ])),
                $.make('div', { className: 'NB-story-comment-username' }, this.user.get('username')),
                $.make('div', { className: 'NB-story-comment-date' }, this.model.get('shared_date') + ' ago'),
                (this.model.get('user_id') == NEWSBLUR.Globals.user_id && $.make('div', { className: 'NB-story-comment-edit-button NB-story-comment-share-edit-button' }, [
                    $.make('div', { className: 'NB-story-comment-edit-button-wrapper' }, 'edit')
                ])),
                $.make('div', { className: 'NB-story-comment-reply-button' }, [
                    $.make('div', { className: 'NB-story-comment-reply-button-wrapper' }, 'reply')
                ])
            ]),
            $.make('div', { className: 'NB-story-comment-content' }, this.model.get('comments')),
            this.make_story_share_comment_replies()
        ]);
        
        this.$el.html($comment);

        return this;
    },
    
    make_story_share_comment_replies: function() {
        if (!this.model.replies || !this.model.replies.length) return;
        
        var user_id = NEWSBLUR.Globals.user_id;
        var $replies = this.model.replies.map(_.bind(function(reply) {
            return new NEWSBLUR.Views.StoryCommentReply({model: reply, comment: this}).render().el;
        }, this));
        $replies = $.make('div', { className: 'NB-story-comment-replies' }, $replies);

        return $replies;
    },
    
    
    // ==========
    // = Events =
    // ==========
    
    open_social_profile_modal: function() {
        NEWSBLUR.reader.open_social_profile_modal(this.model.get("user_id"));
    },
    
    toggle_feed_story_share_dialog: function() {
        this.story.story_share_view.toggle_feed_story_share_dialog();
    },
    
    open_reply: function(options) {
        options = options || {};
        var current_user = NEWSBLUR.assets.user_profile;
        
        var $form = $.make('div', { className: 'NB-story-comment-reply NB-story-comment-reply-form' }, [
            $.make('img', { className: 'NB-story-comment-reply-photo', src: current_user.get('photo_url') }),
            $.make('div', { className: 'NB-story-comment-username NB-story-comment-reply-username' }, current_user.get('username')),
            $.make('input', { type: 'text', className: 'NB-input NB-story-comment-reply-comments' }),
            $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green' }, options.is_editing ? 'Save' : 'Post')
        ]);
        this.remove_social_comment_reply_form();
        
        if (options.is_editing && options.$reply) {
            var original_message = $('.NB-story-comment-reply-content', options.$reply).text();
            $('input', $form).val(original_message);
            $form.data('original_message', original_message);
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
        // this.fetch_story_locations_in_feed_view();
    },
    
    remove_social_comment_reply_form: function() {
        this.$('.NB-story-comment-reply-form').remove();
        this.$('.NB-story-comment-reply-hidden').show();
    },
    
    save_social_comment_reply: function() {
        var $form = this.$('.NB-story-comment-reply-form');
        var $submit = $(".NB-modal-submit-button", $form);
        var comment_user_id = this.model.get('user_id');
        var comment_reply = $('.NB-story-comment-reply-comments', $form).val();
        var original_message = $form.data('original_message');
        
        if (!comment_reply || comment_reply.length <= 1) {
            this.remove_social_comment_reply_form();
            // this.fetch_story_locations_in_feed_view();
            return;
        }
        
        if ($submit.hasClass('NB-disabled')) {
            return;
        }
        
        $submit.addClass('NB-disabled').text('Posting...');
        NEWSBLUR.assets.save_comment_reply(this.options.story.id, this.options.story.get('story_feed_id'), 
                                      comment_user_id, comment_reply, 
                                      original_message,
                                      _.bind(function(data) {
            this.model.set(data.comment);
            this.render();
            // this.fetch_story_locations_in_feed_view();
        }, this), _.bind(function(data) {
            var message = data && data.message || "Sorry, this reply could not be posted. Probably a bug.";
            if (!NEWSBLUR.Globals.is_authenticated) {
                message = "You need to be logged in to reply to a comment.";
            }
            var $error = $.make('div', { className: 'NB-error' }, message);
            $submit.removeClass('NB-disabled').text('Post');
            $form.find('.NB-error').remove();
            $form.append($error);
            // this.fetch_story_locations_in_feed_view();
        }, this));
    }
    
});