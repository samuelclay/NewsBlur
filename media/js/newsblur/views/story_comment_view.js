NEWSBLUR.Views.StoryComment = Backbone.View.extend({
    
    className: 'NB-story-comment',
    
    events: {
        "click .NB-user-avatar": "open_social_profile_modal",
        "click .NB-story-comment-username": "open_social_profile_modal",
        "click .NB-story-comment-reply-button": "open_reply",
        "click .NB-story-comment-like": "like_comment",
        "click .NB-story-comment-share-edit-button": "toggle_feed_story_share_dialog",
        "click .NB-story-comment-reply .NB-modal-submit-green": "save_social_comment_reply",
        "click .NB-story-comment-reply .NB-modal-submit-delete": "delete_social_comment_reply"
    },
    
    initialize: function(options) {
        this.story = options.story;
        if (!this.options.on_social_page) {
            this.user = NEWSBLUR.assets.user_profiles.find(this.model.get('user_id'));
            this.model.bind('change:liking_users', this.render, this);
            this.model.bind('change:liking_users', this.call_out_like, this);
        }
    },
    
    render: function() {
        var comments = this.model.get('comments').replace(/\n+/g, '<br><br>');
        var reshare_class = this.model.get('source_user_id') ? 'NB-story-comment-reshare' : '';
        var has_likes = _.any(this.model.get('liking_users'));
        var liked = _.contains(this.model.get('liking_users'), NEWSBLUR.Globals.user_id);
        var profile_thumb = NEWSBLUR.Views.ProfileThumb.create(this.model.get('source_user_id'));
        var $comment = $.make('div', { className: (this.options.friend_share ? "NB-story-comment-friend-share" : "") }, [
            $.make('div', { className: 'NB-story-comment-author-avatar NB-user-avatar ' + reshare_class }, [
                $.make('img', { src: this.user.get('photo_url') })
            ]),
            $.make('div', { className: 'NB-story-comment-author-container' }, [
                (this.model.get('source_user_id') && $.make('div', { className: 'NB-story-comment-reshares' }, [
                    profile_thumb && profile_thumb.render().el
                ])),
                $.make('div', { className: 'NB-story-comment-username' }, this.user.get('username')),
                $.make('div', { className: 'NB-story-comment-date' }, this.model.get('shared_date') + ' ago'),
                $.make('div', { className: 'NB-story-comment-reply-button' }, [
                    $.make('div', { className: 'NB-story-comment-reply-button-wrapper' }, [
                        (this.user.get('protected') && $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/g_icn_lock.png' })),
                        'reply'
                    ])
                ]),
                (this.model.get('user_id') == NEWSBLUR.Globals.user_id && $.make('div', { className: 'NB-story-comment-edit-button NB-story-comment-share-edit-button' }, [
                    $.make('div', { className: 'NB-story-comment-edit-button-wrapper' }, 'edit')
                ])),
                (has_likes && $.make('div', { className: 'NB-story-comment-likes NB-right' }, [
                    $.make('div', { className: 'NB-story-comment-like ' + (liked ? 'NB-active' : '') }),
                    this.render_liking_users()
                ])),
                (!has_likes && this.model.get('user_id') != NEWSBLUR.Globals.user_id && $.make('div', { className: 'NB-story-comment-likes NB-left' }, [
                    $.make('div', { className: 'NB-story-comment-like' })
                ])),
                $.make('div', { className: 'NB-story-comment-error' })
            ]),
            $.make('div', { className: 'NB-story-comment-content' }, comments),
            this.make_story_share_comment_replies()
        ]);
        
        this.$el.html($comment);

        return this;
    },
    
    make_story_share_comment_replies: function() {
        if (!this.model.replies || !this.model.replies.length) return;
        
        var user_id = NEWSBLUR.Globals.user_id;
        var $replies = this.model.replies.map(_.bind(function(reply) {
            if (!NEWSBLUR.assets.get_user(reply.get('user_id'))) return;
            return new NEWSBLUR.Views.StoryCommentReply({model: reply, comment: this}).render().el;
        }, this));
        $replies = $.make('div', { className: 'NB-story-comment-replies' }, $replies);

        return $replies;
    },
    
    render_liking_users: function() {
        var $users = $.make('div', { className: 'NB-story-comment-likes-users' });

        _.each(this.model.get('liking_users'), function(user_id) { 
            if (!NEWSBLUR.assets.get_user(user_id)) return;
            var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id).render().el;
            $users.append($thumb);
        });
        
        return $users;
    },
    
    call_out_like: function() {
        var $like = this.$('.NB-story-comment-like');
        var liked = _.contains(this.model.get('liking_users'), NEWSBLUR.Globals.user_id);
        
        $like.attr({'title': liked ? 'Favorited!' : 'Unfavorited'});
        $like.tipsy({
            gravity: 'sw',
            fade: true,
            trigger: 'manual',
            offsetOpposite: -1
        });
        var tipsy = $like.data('tipsy');
        _.defer(function() {
            if (!tipsy) return;
            tipsy.enable();
            tipsy.show();
        });

        $like.animate({
            'opacity': 1
        }, {
            'duration': 850,
            'queue': false,
            'complete': function() {
                if (tipsy && tipsy.enabled) {
                    tipsy.hide();
                    tipsy.disable();
                }
            }
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    open_social_profile_modal: function() {
        NEWSBLUR.reader.open_social_profile_modal(this.model.get("user_id"));
    },
    
    toggle_feed_story_save_dialog: function() {
        this.story.story_save_view.toggle_feed_story_save_dialog();
    },
    
    toggle_feed_story_share_dialog: function() {
        this.story.story_share_view.toggle_feed_story_share_dialog();
    },
    
    open_reply: function(options) {
        options = options || {};
        var current_user = NEWSBLUR.assets.user_profile;
        
        if (this.user.get('protected') && this.options.public_comment) {
            var $error = this.$('.NB-story-comment-error');
            $error.text("You must be following " + this.user.get('username') + " to reply");
            return;
        }
        var reply_comments = options.reply && options.reply.stripped_comments();

        var $form = $.make('div', { className: 'NB-story-comment-reply NB-story-comment-reply-form' }, [
            $.make('img', { className: 'NB-story-comment-reply-photo', src: current_user.get('photo_url') }),
            $.make('div', { className: 'NB-story-comment-username NB-story-comment-reply-username' }, current_user.get('username')),
            $.make('input', { type: 'text', className: 'NB-input NB-story-comment-reply-comments', value: reply_comments }),
            $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green' }, options.is_editing ? 'Save' : 'Post'),
            (options.is_editing && $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-grey NB-modal-submit-delete' }, 'Delete'))
        ]);
        this.remove_social_comment_reply_form();
        
        if (options.is_editing && options.$reply) {
            $form.data('reply_id', options.reply.get("reply_id"));
            options.$reply.hide().addClass('NB-story-comment-reply-hidden');
            options.$reply.after($form);
        } else {
            this.$el.append($form);
        }
        
        $('.NB-story-comment-reply-comments', $form).bind('keydown', 'return', 
            _.bind(this.save_social_comment_reply, this));
        $('.NB-story-comment-reply-comments', $form).bind('keydown', 'ctrl+return', 
            _.bind(this.save_social_comment_reply, this));
        $('.NB-story-comment-reply-comments', $form).bind('keydown', 'meta+return', 
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
            if (this.options.on_social_page) {
                this.options.story_comments_view.replace_comment(this.model.get('user_id'), data);
            } else {
                this.model.set(data.comment);
                this.render();
                NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
            }
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
            if (this.options.on_social_page) {
                this.options.story_comments_view.replace_comment(this.model.get('user_id'), data);
            } else {
                this.model.set(data.comment);
                this.render();
                NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
            }
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
        var liking_user_ids = this.model.get('liking_users') || [];
        var comment_user_id = this.model.get('user_id');
        var liked = _.contains(liking_user_ids, NEWSBLUR.Globals.user_id);
        
        if (!liked) {
            this.model.set('liking_users', _.union(liking_user_ids, NEWSBLUR.Globals.user_id));
            NEWSBLUR.assets.like_comment(this.options.story.id, 
                                         this.options.story.get('story_feed_id'),
                                         comment_user_id);
        } else {
            this.model.set('liking_users', _.without(liking_user_ids, NEWSBLUR.Globals.user_id));
            NEWSBLUR.assets.remove_like_comment(this.options.story.id, 
                                                this.options.story.get('story_feed_id'),
                                                comment_user_id);
        }
    }
    
});