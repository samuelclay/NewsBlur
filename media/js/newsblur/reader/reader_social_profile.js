NEWSBLUR.ReaderSocialProfile = function(user_id, options) {
    var defaults = {
        width: 800
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.AssetModel.reader();
    
    user_id = _.string.ltrim(user_id, 'social:');
    this.runner(user_id);
};

NEWSBLUR.ReaderSocialProfile.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderSocialProfile.prototype, {
    
    runner: function(user_id) {
        this.profile = new NEWSBLUR.Models.User();
        this.make_modal();
        this.open_modal();
        _.defer(_.bind(this.fetch_profile, this, user_id));
        // this.fetch_profile(user_id);

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal NB-modal-profile' }, [
            $.make('table', { className: 'NB-profile-info-table' }, [
                $.make('tr', [
                    $.make('td', [
                        $.make('img', { src: this.profile.get('photo_url'), className: 'NB-profile-photo' })
                    ]),
                    $.make('td', { className: 'NB-profile-info-header' }, this.make_profile_user_info_header())
                ])
            ]),
            $.make('div', { className: 'NB-profile-section' }, [
                $.make('h3', 'Following'),
                $.make('fieldset', [
                    $.make('legend', 'People you also follow'),
                    $.make('div', { className: 'NB-modal-section NB-profile-following-youknow' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Everybody'),
                    $.make('div', { className: 'NB-modal-section NB-friends-following-everybody' })
                ])
            ]),
            $.make('div', { className: 'NB-profile-section' }, [
                $.make('h3', 'Followers'),
                $.make('fieldset', [
                    $.make('legend', 'People you follow'),
                    $.make('div', { className: 'NB-modal-section NB-profile-following-youknow' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Everybody'),
                    $.make('div', { className: 'NB-modal-section NB-friends-following-everybody' })
                ])
            ])
        ]);
    },
    
    fetch_profile: function(user_id, callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        
        this.model.fetch_user_profile(user_id, _.bind(function(data) {
            this.profile = new NEWSBLUR.Models.User(data.user_profile);
            this.populate_friends(data);
            callback && callback();
        }, this));
    },
    
    populate_friends: function(data) {
        $('.NB-profile-info-header', this.$modal).html(this.make_profile_user_info_header());
        $('.NB-profile-following-youknow', this.$modal).html(this.make_profile_badges(data.following_youknow));
        $('.NB-profile-following-everybody', this.$modal).html(this.make_profile_badges(data.following_everybody));
        $('.NB-profile-followers-youknow', this.$modal).html(this.make_profile_badges(data.followers_youknow));
        $('.NB-profile-followers-everybody', this.$modal).html(this.make_profile_badges(data.followers_everybody));
    },
    
    make_profile_user_info_header: function() {
        var $info = $.make('div', [
            $.make('h2', { className: 'NB-modal-title' }, this.profile.get('username')),
            $.make('div', { className: 'NB-profile-location' }, this.profile.get('location')),
            $.make('div', { className: 'NB-profile-website' }, this.profile.get('website')),
            $.make('div', { className: 'NB-profile-bio' }, this.profile.get('bio')),
            $.make('div', { className: 'NB-profile-badge-stats' }, [
                $.make('span', { className: 'NB-count' }, this.profile.get('shared_stories_count')),
                'shared ',
                Inflector.pluralize('story', this.profile.get('shared_stories_count')),
                ' &middot; ',
                $.make('span', { className: 'NB-count' }, this.profile.get('follower_count')),
                Inflector.pluralize('follower', this.profile.get('follower_count'))
            ])
        ]);
        return $info;
    },
    
    make_profile_badges: function(profiles) {
        var $badges = $.make('div', _.map(profiles, function(profile) {
            return $.make('div', { className: 'NB-profile-badge', title: profile['username'] }, [
                $.make('img', { src: profile['photo_url'] })
            ]).data('user_id', profile['user_id']);
        }));
        return $badges;
    },
    
    open_modal: function(callback) {
        var self = this;
        
        this.$modal.modal({
            'minWidth': this.options.width,
            'maxWidth': this.options.width,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200, function() {
                        if (self.options.onOpen) {
                            self.options.onOpen();
                        }
                    });
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
                if (self.options.onShow) {
                    self.options.onShow();
                }
            },
            'onClose': function(dialog, callback) {
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(200, function() {
                    dialog.overlay.empty().remove();
                    $.modal.close(callback);
                });
                $('.NB-modal-holder').empty().remove();
            }
        });
    },
    
    follow_user: function(user_id, $badge) {
        this.model.follow_user(user_id, _.bind(function(data, follow_user) {
            this.make_profile_section();
            var $button = $('.NB-modal-submit-button', $badge);
            $button.text('Following');
            $button.removeClass('NB-modal-submit-green')
                .removeClass('NB-modal-submit-red')
                .addClass('NB-modal-submit-close');
            $button.removeClass('NB-profile-badge-action-follow')
                .addClass('NB-profile-badge-action-unfollow');
            $badge.replaceWith(this.make_profile_badge(follow_user));
            NEWSBLUR.reader.make_social_feeds();
        }, this));
    },
    
    unfollow_user: function(user_id, $badge) {
        this.model.unfollow_user(user_id, _.bind(function(data, unfollow_user) {
            this.make_profile_section();
            var $button = $('.NB-modal-submit-button', $badge);
            $button.text('Unfollowed');
            $button.removeClass('NB-modal-submit-close')
                .addClass('NB-modal-submit-red');
            $button.removeClass('NB-profile-badge-action-unfollow')
                .addClass('NB-profile-badge-action-follow');
            $badge.replaceWith(this.make_profile_badge(unfollow_user));
            NEWSBLUR.reader.make_social_feeds();
        }, this));
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-account-link' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_account();
        });
    }
    
});