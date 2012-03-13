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
        this.profile = this.model.user_profiles.get(user_id);
        this.make_modal();
        this.open_modal();
        _.defer(_.bind(this.fetch_profile, this, user_id));

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        var profile = new NEWSBLUR.Views.SocialProfileBadge({
            model: this.profile,
            embiggen: true,
            photo_size: 'large'
        });

        this.$modal = $.make('div', { className: 'NB-modal NB-modal-profile' }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('div', { className: 'NB-profile-info-header' }, $(profile)),
            $.make('div', { className: 'NB-profile-section' }, [
                $.make('h3', 'Followers'),
                $.make('fieldset', [
                    $.make('legend', 'People you follow'),
                    $.make('div', { className: 'NB-modal-section NB-profile-followers-youknow' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Everybody'),
                    $.make('div', { className: 'NB-modal-section NB-profile-followers-everybody' })
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
                    $.make('div', { className: 'NB-modal-section NB-profile-following-everybody' })
                ])
            ])
        ]);
    },
    
    fetch_profile: function(user_id, callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        
        this.model.fetch_user_profile(user_id, _.bind(function(data) {
            console.log(["profile", data]);
            $('.NB-modal-loading', this.$modal).removeClass('NB-active');
            this.profile.set(data.user_profile);
            this.populate_friends(data);
            callback && callback();
            this.resize();
        }, this));
    },
    
    populate_friends: function(data) {
        this.profiles = new NEWSBLUR.Collections.Users(data.profiles);
        $('.NB-profile-following-youknow', this.$modal).html(this.make_profile_badges(data.following_youknow));
        $('.NB-profile-following-everybody', this.$modal).html(this.make_profile_badges(data.following_everybody));
        $('.NB-profile-followers-youknow', this.$modal).html(this.make_profile_badges(data.followers_youknow));
        $('.NB-profile-followers-everybody', this.$modal).html(this.make_profile_badges(data.followers_everybody));
    },
    
    make_profile_badges: function(user_ids) {
        var profiles = this.profiles;
        var $badges = $.make('div', { className: 'NB-profile-links' }, _.map(user_ids, function(user_id) {
            var user = profiles.get(user_id);
            return $.make('div', { className: 'NB-profile-link', title: user.get('username') }, [
                $.make('img', { src: user.get('photo_url') })
            ]).tipsy({
                delayIn: 50,
                gravity: 's',
                fade: true,
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
    }
    
});