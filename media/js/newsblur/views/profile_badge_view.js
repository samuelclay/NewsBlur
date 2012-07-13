NEWSBLUR.Views.SocialProfileBadge = Backbone.View.extend({
    
    className: "NB-profile-badge",
    
    events: {
        "click .NB-profile-badge-action-follow": "follow_user",
        "click .NB-profile-badge-action-unfollow": "unfollow_user",
        "click .NB-profile-badge-action-preview": "preview_user",
        "click .NB-profile-badge-username": "open_profile",
        "click .NB-profile-badge-action-edit": "open_edit_profile",
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
                        $.make('span', { className: 'NB-count' }, profile.get('shared_stories_count')),
                        'shared ',
                        Inflector.pluralize('story', profile.get('shared_stories_count')),
                        ' &middot; ',
                        $.make('span', { className: 'NB-count' }, profile.get('follower_count')),
                        Inflector.pluralize('follower', profile.get('follower_count'))
                    ]))
                ])
            ])
        ]));
        
        var $actions;
        if (NEWSBLUR.reader.model.user_profile.get('user_id') == profile.get('user_id')) {
            $actions = $.make('div', { className: 'NB-profile-badge-action-buttons' }, [
                $.make('div', { 
                    className: 'NB-profile-badge-action-self NB-modal-submit-button' 
                }, 'You'),
                (this.options.show_edit_button && $.make('div', { 
                    className: 'NB-profile-badge-action-edit NB-modal-submit-button NB-modal-submit-grey ' +
                               (!profile.get('shared_stories_count') ? 'NB-disabled' : '')
                }, 'Edit Profile'))
            ]);
        } else if (profile.get('following')) {
            $actions = $.make('div', { 
                className: 'NB-profile-badge-action-unfollow NB-profile-badge-action-buttons NB-modal-submit-button NB-modal-submit-grey' 
            }, 'Following');
        } else {
            $actions = $.make('div', { className: 'NB-profile-badge-action-buttons' }, [
                $.make('div', { 
                    className: 'NB-profile-badge-action-follow NB-modal-submit-button NB-modal-submit-green' 
                }, 'Follow'),
                $.make('div', { 
                    className: 'NB-profile-badge-action-preview NB-modal-submit-button NB-modal-submit-grey ' +
                               (!profile.get('shared_stories_count') ? 'NB-disabled' : '')
                }, 'Preview')
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
        NEWSBLUR.assets.follow_user(this.model.get('user_id'), _.bind(function(data, follow_user) {
            this.$('.NB-loading').removeClass('NB-active');
            this.model.set(follow_user);
            
            var $button = this.$('.NB-profile-badge-action-follow');
            $button.text('Following');
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
            this.model.set(unfollow_user);
            
            var $button = this.$('.NB-profile-badge-action-follow');
            $button.text('Unfollowed');
            $button.removeClass('NB-modal-submit-grey')
                .addClass('NB-modal-submit-red');
            $button.removeClass('NB-profile-badge-action-unfollow')
                .addClass('NB-profile-badge-action-follow');
                
            NEWSBLUR.app.feed_list.make_social_feeds();
        }, this));
    },
    
    preview_user: function() {
        if (this.$('.NB-profile-badge-action-preview').hasClass('NB-disabled')) return;
        
        $.modal.close(_.bind(function() {
            window.ss = this.model;
            var socialsub = NEWSBLUR.reader.model.add_social_feed(this.model);
            NEWSBLUR.reader.load_social_feed_in_tryfeed_view(socialsub);
        }, this));
    },
    
    open_profile: function() {
        var user_id = this.model.get('user_id');
        NEWSBLUR.reader.model.add_user_profiles([this.model]);

        $.modal.close(function() {
            NEWSBLUR.reader.open_social_profile_modal(user_id);
        });
    },
    
    open_edit_profile: function() {
        $.modal.close(function() {
            NEWSBLUR.reader.open_profile_editor_modal();
        });
    },
    
    mouseenter_unfollow: function() {
        this.$('.NB-profile-badge-action-unfollow').text('Unfollow').addClass('NB-active');
    },
    
    mouseleave_unfollow: function() {
        this.$('.NB-profile-badge-action-unfollow').text('Following').removeClass('NB-active');
    },
    
    mouseenter_follow: function() {
        this.$('.NB-profile-badge-action-follow').text('Follow').addClass('NB-active');
    },
    
    mouseleave_follow: function() {
        this.$('.NB-profile-badge-action-follow').text('Follow').removeClass('NB-active');
    }
    
});