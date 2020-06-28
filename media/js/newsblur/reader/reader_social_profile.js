NEWSBLUR.ReaderSocialProfile = function(user_id, options) {
    var defaults = {
        width: 800
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.assets;
    this.profiles = new NEWSBLUR.Collections.Users();
    user_id = parseInt(_.string.ltrim(user_id, 'social:'), 10);
    this.runner(user_id);
};

NEWSBLUR.ReaderSocialProfile.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderSocialProfile.prototype, {
    
    runner: function(user_id) {
        if (!this.model.user_profiles.find(user_id)) {
            this.model.add_user_profiles([{user_id: user_id}]);
        }
        this.profile = this.model.user_profiles.find(user_id).clone();
        this.make_modal();
        this.open_modal();
        _.defer(_.bind(this.fetch_profile, this, user_id));

        this.profile.bind('change', _.bind(this.populate_friends, this));
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        this.$profile = new NEWSBLUR.Views.SocialProfileBadge({
            model: this.profile,
            embiggen: true,
            photo_size: 'large',
            show_edit_button: true
        });

        this.$modal = $.make('div', { className: 'NB-modal NB-modal-profile' }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('div', { className: 'NB-profile-info-header' }, $(this.$profile)),
            $.make('fieldset', { className: 'NB-profile-section NB-profile-section-activities' }, [
                $.make('legend', 'Recent interactions'),
                $.make('div', { className: 'NB-profile-activities' })
            ]),
            $.make('div', { className: 'NB-profile-section' }, [
                $.make('table', { className: 'NB-profile-followers' }, [
                    $.make('tr', [
                        $.make('td', { className: 'NB-profile-follow-count' }, [
                            $.make('div', { className: 'NB-profile-following-count' }, this.profile.get('following_count')),
                            $.make('h3', 'Following')
                        ]),
                        $.make('td', [
                            $.make('fieldset', [
                                $.make('legend', 'People you know'),
                                $.make('div', { className: 'NB-modal-section NB-profile-following-youknow' })
                            ]),
                            $.make('fieldset', [
                                $.make('legend', 'Everybody'),
                                $.make('div', { className: 'NB-modal-section NB-profile-following-everybody' })
                            ])
                        ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-profile-section' }, [
                $.make('table', { className: 'NB-profile-followers' }, [
                    $.make('tr', [
                        $.make('td', { className: 'NB-profile-follow-count' }, [
                            $.make('div', { className: 'NB-profile-follower-count' }, this.profile.get('followers_count')),
                            $.make('h3', 'Followers')
                        ]),
                        $.make('td', [
                            $.make('fieldset', [
                                $.make('legend', 'People you know'),
                                $.make('div', { className: 'NB-modal-section NB-profile-followers-youknow' })
                            ]),
                            $.make('fieldset', [
                                $.make('legend', 'Everybody'),
                                $.make('div', { className: 'NB-modal-section NB-profile-followers-everybody' })
                            ])
                        ])
                    ])
                ])
            ])
        ]);
    },
    
    fetch_profile: function(user_id, callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');

        this.model.fetch_user_profile(user_id, _.bind(function(data) {
            $('.NB-modal-loading', this.$modal).removeClass('NB-active');
            this.profiles = data.profiles;
            this.activities = data.activities;
            this.data = data;

            this.profile.set(data.user_profile);
            // this.populate_friends(); # Bound to this.profile's change
            this.populate_activities(data.activities_html);
            this.load_images_and_resize();
            callback && callback();
        }, this));
    },
    
    populate_friends: function() {
        // NEWSBLUR.log(["populate_friends", this.profile.get('followers_youknow')]);
        _.each(['following_youknow', 'following_everybody', 'followers_youknow', 'followers_everybody'], _.bind(function(f) {
            var user_ids = this.profile.get(f);
            var $f = $('.NB-profile-'+f.replace('_', '-'), this.$modal);
            $f.html(this.make_profile_badges(user_ids, this.profiles));
            $f.closest('fieldset').toggle(!!user_ids.length);
        }, this));
        $('.NB-profile-follower-count', this.$modal).text(this.profile.get('follower_count'));
        $('.NB-profile-following-count', this.$modal).text(this.profile.get('following_count'));
        _.defer(_.bind(this.resize, this));
    },
    
    populate_activities: function(activities_html) {
        var $activities = $('.NB-profile-activities', this.$modal).empty();
        var $section = $(".NB-profile-section-activities", this.$modal);
        
        if (!this.activities.length) {
            $section.hide();
        } else {
            $section.show();
            // Ugh, hate how this is in a Django template.
            $activities.html(activities_html);
        }
    },
    
    load_images_and_resize: function() {
        var $images = $('img', this.$modal);
        var image_count = $images.length;
        $images.on('load', _.bind(function() {
            if (image_count > 1) {
                image_count -= 1;
            } else {
                this.resize();
            }
        }, this));
    },
    
    make_profile_badges: function(user_ids, profiles) {
        $('.tipsy').remove();
        var $badges = $.make('div', { className: 'NB-profile-links' }, _.map(user_ids, function(user_id) {
            var user = new NEWSBLUR.Models.User(profiles[user_id]);
            return $.make('div', { className: 'NB-profile-link', title: user.get('username') }, [
                $.make('img', { src: user.get('photo_url') })
            ]).tipsy({
                gravity: 's',
                delayIn: 1,
                offset: 3
            }).data('user_id', user_id);
        }));
        return $badges;
    },

    // ===========
    // = Actions =
    // ===========
    
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
                        self.resize();
                    });
                    self.resize();
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
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-account-link' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_account();
        });
        $.targetIs(e, { tagSelector: '.NB-profile-link' }, function($t, $p) {
            e.preventDefault();
            
            var user_id = $t.data('user_id');
            $t.tipsy('hide').tipsy('disable');
            self.fetch_profile(user_id);
        });
        $.targetIs(e, { tagSelector: '.NB-activity-follow' }, function($t, $p) {
            e.preventDefault();
            e.stopPropagation();
            
            var user_id = $t.data('userId');
            $t.tipsy('hide').tipsy('disable');
            self.fetch_profile(user_id);
        });

    }
    
});