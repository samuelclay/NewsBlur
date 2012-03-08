NEWSBLUR.Views.SocialProfileBadge = Backbone.View.extend({
    
    events: {
        "click .NB-profile-badge-action-follow": "follow_user",
        "click .NB-profile-badge-action-unfollow": "unfollow_user"
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
        this.$el.html($.make('table', { className: "NB-profile-badge " + (this.options.embiggen ? "NB-profile-badge-embiggen" : "") }, [
            $.make('tr', [
                $.make('td', [
                    $.make('div', { className: 'NB-profile-badge-photo' }, [
                        $.make('img', { src: profile.get('photo_url') })
                    ])
                ]),
                $.make('td', { className: 'NB-profile-badge-info' }, [
                    $.make('div', { className: 'NB-profile-badge-actions' }),
                    $.make('div', { className: 'NB-profile-badge-username' }, profile.get('username')),
                    $.make('div', { className: 'NB-profile-badge-location' }, profile.get('location')),
                    (profile.get('website') && $.make('a', { 
                        href: profile.get('website'), 
                        target: '_blank',
                        rel: 'nofollow',
                        className: 'NB-profile-badge-website NB-splash-link'
                    }, profile.get('website').replace('http://', ''))),
                    $.make('div', { className: 'NB-profile-badge-bio' }, profile.get('bio')),
                    (_.isNumber(profile.get('shared_stories_count')) && $.make('div', { className: 'NB-profile-badge-stats' }, [
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
            $actions = $.make('div', { className: 'NB-profile-badge-action-self NB-modal-submit-button' }, 'You');
        } else if (_.contains(NEWSBLUR.reader.model.user_profile.get('following_user_ids'), profile.get('user_id'))) {
            $actions = $.make('div', { 
                className: 'NB-profile-badge-action-unfollow NB-modal-submit-button NB-modal-submit-close' 
            }, 'Following');
        } else {
            $actions = $.make('div', { 
                className: 'NB-profile-badge-action-follow NB-modal-submit-button NB-modal-submit-green' 
            }, 'Follow');
        }
        this.$('.NB-profile-badge-actions').append($actions);
        
        return this;
    },
    
    follow_user: function() {
        NEWSBLUR.reader.model.follow_user(this.model.get('user_id'), _.bind(function(data, follow_user) {
            // this.make_profile_section();
            this.model.set(follow_user);
            
            var $button = this.$('.NB-modal-submit-button');
            $button.text('Following');
            $button.removeClass('NB-modal-submit-green')
                .removeClass('NB-modal-submit-red')
                .addClass('NB-modal-submit-close');
            $button.removeClass('NB-profile-badge-action-follow')
                .addClass('NB-profile-badge-action-unfollow');
                
            NEWSBLUR.reader.make_social_feeds();
        }, this));
    },
    
    unfollow_user: function() {
        NEWSBLUR.reader.model.unfollow_user(this.model.get('user_id'), _.bind(function(data, unfollow_user) {
            // this.make_profile_section();
            this.model.set(unfollow_user);
            
            var $button = this.$('.NB-modal-submit-button');
            $button.text('Unfollowed');
            $button.removeClass('NB-modal-submit-close')
                .addClass('NB-modal-submit-red');
            $button.removeClass('NB-profile-badge-action-unfollow')
                .addClass('NB-profile-badge-action-follow');
                
            NEWSBLUR.reader.make_social_feeds();
        }, this));
    }
    
});