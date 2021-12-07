NEWSBLUR.Views.SocialProfileBadge = Backbone.View.extend({
    
    className: "NB-profile-badge",
    
    events: {
        "click .NB-profile-badge-action-follow": "follow_user",
        "click .NB-profile-badge-action-unfollow": "unfollow_user",
        "click .NB-profile-badge-action-preview": "preview_user",
        "click .NB-profile-badge-action-mute": "mute_user",
        "click .NB-profile-badge-action-approve": "approve_user",
        "click .NB-profile-badge-action-ignore": "ignore_user",
        "click .NB-profile-badge-username": "open_profile",
        "click .NB-profile-badge-action-edit": "open_edit_profile",
        "click .NB-profile-badge-action-admin": "open_user_admin",
        "mouseenter .NB-profile-badge-action-unfollow": "mouseenter_unfollow",
        "mouseleave .NB-profile-badge-action-unfollow": "mouseleave_unfollow",
        "mouseenter .NB-profile-badge-action-follow": "mouseenter_follow",
        "mouseleave .NB-profile-badge-action-follow": "mouseleave_follow"
    },
    
    constructor : function(options) {
        Backbone.View.call(this, options);
        this.render();

        return this.el;
    },
    
    initialize: function() {
        _.bindAll(this, 'render');
        this.model.bind('change', this.render);
    },
    
    render: function() {
        var profile = this.model;
        this.$el.html($.make('table', {}, [
            $.make('tr', [
                $.make('td', { className: 'NB-profile-badge-photo-wrapper' }, [
                    $.make('div', { className: 'NB-profile-badge-photo' }, [
                        $.make('img', { src: profile.photo_url({'size': this.options.photo_size}) })
                    ])
                ]),
                $.make('td', { className: 'NB-profile-badge-info' }, [
                    $.make('div', { className: 'NB-profile-badge-actions' }, [
                        $.make('div', { className: 'NB-loading' })
                    ]),
                    $.make('div', { className: 'NB-profile-badge-username NB-splash-link' }, profile.get('username')),
                    $.make('div', { className: 'NB-profile-badge-location' }, profile.get('location')),
                    (profile.get('website') && $.make('a', { 
                        href: profile.get('website'), 
                        target: '_blank',
                        rel: 'nofollow',
                        className: 'NB-profile-badge-website NB-splash-link'
                    }, profile.get('website').replace('http://', ''))),
                    $.make('div', { className: 'NB-profile-badge-bio' }, profile.get('bio')),
                    (_.isNumber(profile.get('shared_stories_count')) && 
                     $.make('div', { className: 'NB-profile-badge-stats' }, [
                        $.make('span', { className: 'NB-count' }, Inflector.commas(profile.get('shared_stories_count'))),
                        'shared ',
                        Inflector.pluralize('story', profile.get('shared_stories_count')),
                        ' &middot; ',
                        $.make('a', { href: profile.blurblog_url(), target: "_blank", className: "NB-profile-badge-blurblog-link NB-splash-link" }, profile.blurblog_url().replace('http://', '')),
                        (this.model.get('following_you') && $.make('span', [
                            ' &middot; ',
                            $.make('div', { className: 'NB-profile-badge-following-you' }, 'Follows you')
                        ])),
                        (NEWSBLUR.Globals.is_admin && $.make('span', [
                            ' &middot; ',
                            $.make('span', { className: 'NB-profile-badge-action-admin' })
                        ]))
                    ]))
                ])
            ])
        ]));

        var $actions;
        if (this.options.request_approval) {
            $actions = $.make('div', { className: 'NB-profile-badge-action-buttons' }, [
                $.make('div', { 
                    className: 'NB-profile-badge-action-approve NB-modal-submit-button NB-modal-submit-green' 
                }, [
                    $.make('span', 'Approve')
                ]),
                $.make('div', { 
                    className: 'NB-profile-badge-action-ignore NB-modal-submit-button NB-modal-submit-grey ' +
                               (!profile.get('shared_stories_count') ? 'NB-disabled' : '')
                }, 'Ignore')
            ]);            
        } else if (NEWSBLUR.reader.model.user_profile.get('user_id') == profile.get('user_id')) {
            $actions = $.make('div', { className: 'NB-profile-badge-action-buttons' }, [
                $.make('div', { 
                    className: 'NB-profile-badge-action-self NB-modal-submit-button' 
                }, 'You'),
                (this.options.show_edit_button && $.make('div', { 
                    className: 'NB-profile-badge-action-edit NB-modal-submit-button NB-modal-submit-grey ' +
                               (!profile.get('shared_stories_count') ? 'NB-disabled' : '')
                }, 'Edit Profile'))
            ]);
        } else if (profile.get('followed_by_you')) {
            $actions = $.make('div', { 
                className: 'NB-profile-badge-action-unfollow NB-profile-badge-action-buttons NB-modal-submit-button NB-modal-submit-grey' 
            }, 'Following');
        } else if (profile.get('requested_follow')) {
            $actions = $.make('div', { 
                className: 'NB-profile-badge-action-unfollow NB-profile-badge-action-buttons NB-modal-submit-button NB-modal-submit-grey' 
            }, [
                $.make('span', 'Requested')
            ]);
        } else if (profile.get('protected')) {
            $actions = $.make('div', { className: 'NB-profile-badge-action-buttons' }, [
                $.make('div', { 
                    className: 'NB-profile-badge-action-follow NB-profile-badge-action-protected-follow NB-modal-submit-button NB-modal-submit-green' 
                }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/g_icn_lock.png' }),
                    $.make('span', 'Follow')
                ]),
                (!profile.get('private') && $.make('div', { 
                    className: 'NB-profile-badge-action-preview NB-modal-submit-button NB-modal-submit-grey ' +
                               (!profile.get('shared_stories_count') ? 'NB-disabled' : '')
                }, 'Preview')),
                ($.make('div', { 
                    className: 'NB-profile-badge-action-mute NB-modal-submit-button NB-modal-submit-grey'
                }, $.make('span', (profile.get('muted') ? 'Unmute' : 'Mute'))))
            ]);            
        } else {
            $actions = $.make('div', { className: 'NB-profile-badge-action-buttons' }, [
                $.make('div', { 
                    className: 'NB-profile-badge-action-follow NB-modal-submit-button NB-modal-submit-green' 
                }, [
                    $.make('span', 'Follow')
                ]),
                $.make('div', { 
                    className: 'NB-profile-badge-action-preview NB-modal-submit-button NB-modal-submit-grey ' +
                               (!profile.get('shared_stories_count') ? 'NB-disabled' : '')
                }, 'Preview'),
                $.make('div', { 
                    className: 'NB-profile-badge-action-mute NB-modal-submit-button NB-modal-submit-grey '
                }, $.make('span', (profile.get('muted') ? 'Unmute' : 'Mute')))
            ]);
        }
        this.$('.NB-profile-badge-actions').append($actions);
        
        if (this.options.embiggen) {
            this.$el.addClass("NB-profile-badge-embiggen");
        }
        
        return this;
    },
    
    follow_user: function() {
        this.$('.NB-loading').addClass('NB-active');
        NEWSBLUR.assets.follow_user(this.model.get('user_id'), _.bind(function(data) {
            this.$('.NB-loading').removeClass('NB-active');
            this.model.set(data.follow_profile);
            
            var $button = this.$('.NB-profile-badge-action-follow');
            $button.find('span').text(this.model.get('protected') ? 'Requested' : 'Following');
            $button.removeClass('NB-modal-submit-green')
                .removeClass('NB-modal-submit-red')
                .addClass('NB-modal-submit-grey');
            $button.removeClass('NB-profile-badge-action-follow')
                .addClass('NB-profile-badge-action-unfollow');
                
            NEWSBLUR.app.feed_list.make_social_feeds();
        }, this));
    },
    
    unfollow_user: function() {
        this.$('.NB-loading').addClass('NB-active');
        NEWSBLUR.reader.model.unfollow_user(this.model.get('user_id'), _.bind(function(data, unfollow_user) {
            this.$('.NB-loading').removeClass('NB-active');
            this.model.set(data.unfollow_profile);
            
            var $button = this.$('.NB-profile-badge-action-follow');
            $button.find('span').text(this.model.get('protected') ? 'Canceled Request' : 'Unfollowed');
            $button.removeClass('NB-modal-submit-grey')
                .addClass('NB-modal-submit-red');
            $button.removeClass('NB-profile-badge-action-unfollow')
                .addClass('NB-profile-badge-action-follow');
                
            NEWSBLUR.app.feed_list.make_social_feeds();
        }, this));
    },
    
    approve_user: function() {
        this.$('.NB-loading').addClass('NB-active');
        NEWSBLUR.assets.approve_follower(this.model.get('user_id'), _.bind(function(data) {
            this.$('.NB-loading').removeClass('NB-active');
            
            var $button = this.$('.NB-profile-badge-action-approve');
            $button.find('span').text('Approved');
            $button.removeClass('NB-modal-submit-green');
            $button.removeClass('NB-profile-badge-action-follow')
                .addClass('NB-profile-badge-action-self');

            var $button = this.$('.NB-profile-badge-action-ignore');
            $button.remove();
        }, this));
    },
    
    ignore_user: function() {
        this.$('.NB-loading').addClass('NB-active');
        NEWSBLUR.assets.ignore_follower(this.model.get('user_id'), _.bind(function(data) {
            this.$('.NB-loading').removeClass('NB-active');
            
            var $button = this.$('.NB-profile-badge-action-approve');
            $button.find('span').text('Ignored');
            $button.removeClass('NB-modal-submit-green');
            $button.removeClass('NB-profile-badge-action-follow')
                .addClass('NB-profile-badge-action-self');

            var $button = this.$('.NB-profile-badge-action-ignore');
            $button.remove();
        }, this));
    },
    
    mute_user: function () {
        if (this.model.get('muted')) {
            return this.unmute_user();
        }

        this.$('.NB-loading').addClass('NB-active');
        NEWSBLUR.assets.mute_user(this.model.get('user_id'), _.bind(function(data) {
            this.model.set('muted', true);
            
            this.$('.NB-loading').removeClass('NB-active');
            var $button = this.$('.NB-profile-badge-action-mute');
            $button.find('span').text('Muted');
        }, this));
    },
    
    unmute_user: function() {
        this.$('.NB-loading').addClass('NB-active');
        NEWSBLUR.assets.unmute_user(this.model.get('user_id'), _.bind(function(data) {
            this.model.set('muted', false);
            
            this.$('.NB-loading').removeClass('NB-active');
            var $button = this.$('.NB-profile-badge-action-mute');
            $button.find('span').text('Unmuted');
        }, this));
    },
    
    preview_user: function() {
        if (this.$('.NB-profile-badge-action-preview').hasClass('NB-disabled')) return;
        var open_preview = _.bind(function() {
            window.ss = this.model;
            var socialsub = NEWSBLUR.reader.model.add_social_feed(this.model);
            NEWSBLUR.reader.load_social_feed_in_tryfeed_view(socialsub);
        }, this);
        
        if (!_.keys($.modal.impl.d).length) {
            open_preview();
        } else {
            $.modal.close(open_preview);
        }
    },

    open_profile: function() {
        var user_id = this.model.get('user_id');
        NEWSBLUR.reader.model.add_user_profiles([this.model]);
        
        if ($('.NB-modal').is(':visible')) {
            $.modal.close(function() {
                NEWSBLUR.reader.open_social_profile_modal(user_id);
            });
        } else {
            NEWSBLUR.reader.open_social_profile_modal(user_id);
        }
    },
    
    open_edit_profile: function() {
        $.modal.close(function() {
            NEWSBLUR.reader.open_profile_editor_modal();
        });
    },
    
    mouseenter_unfollow: function() {
        this.$('.NB-profile-badge-action-unfollow span').text(this.model.get('requested_follow') ? 'Cancel' : 'Unfollow').addClass('NB-active');
    },
    
    mouseleave_unfollow: function() {
        this.$('.NB-profile-badge-action-unfollow span').text(this.model.get('requested_follow') ? 'Requested' : 'Following').removeClass('NB-active');
    },
    
    mouseenter_follow: function() {
        this.$('.NB-profile-badge-action-follow span').text('Follow').addClass('NB-active');
    },
    
    mouseleave_follow: function() {
        this.$('.NB-profile-badge-action-follow span').text('Follow').removeClass('NB-active');
    },
    
    open_user_admin: function() {
        NEWSBLUR.reader.open_user_admin_modal({user: this.model});
    }
    
});
