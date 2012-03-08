NEWSBLUR.ReaderFriends = function(options) {
    var defaults = {
        width: 800
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.AssetModel.reader();

    this.runner();
};

NEWSBLUR.ReaderFriends.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderFriends.prototype, {
    
    runner: function() {
        this.options.onOpen = _.bind(function() {
            this.resize_modal();
        }, this);

        this.make_modal();
        this.open_modal();
        this.fetch_friends();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
        this.handle_profile_counts();
        this.delegate_change();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal NB-modal-friends' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-findfriends' }, 'Find Friends'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-profile' }, 'Profile'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-following' }, 'I\'m Following'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-followers' }, 'Following Me')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, 'Friends and Followers'),
            $.make('div', { className: 'NB-tab NB-tab-findfriends NB-active' }, [
                $.make('fieldset', [
                    $.make('legend', 'Social Connections'),
                    $.make('div', { className: 'NB-modal-section NB-friends-services'})
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Your profile'),
                    $.make('div', { className: 'NB-modal-section NB-friends-findfriends-profile' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Search for friends'),
                    $.make('div', { className: 'NB-modal-section NB-friends-search'}, [
                        $.make('label', { 'for': 'NB-friends-search-input' }, 'Username or email:'),
                        $.make('input', { type: 'text', className: 'NB-input', id: 'NB-friends-search-input' }),
                        $.make('div', { className: 'NB-friends-search-badge' })
                    ])
                ]),
                $.make('fieldset', [
                    $.make('legend', 'People You Know'),
                    $.make('div', { className: 'NB-modal-section NB-friends-findlist'}, [
                        $.make('div', { className: 'NB-ghost' }, 'You\'re auto-following new friends, so no need to manually follow them. Score!')
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-tab NB-tab-profile' }, [
                $.make('fieldset', [
                    $.make('legend', 'Profile picture'),
                    $.make('div', { className: 'NB-modal-section NB-friends-profilephoto'})
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Profile'),
                    $.make('div', { className: 'NB-modal-section NB-friends-profile'})
                ]),
                $.make('div', { className: 'NB-modal-submit-close NB-profile-save-button NB-modal-submit-button' }, 'Save my profile')
            ]),
            $.make('div', { className: 'NB-tab NB-tab-following' }),
            $.make('div', { className: 'NB-tab NB-tab-followers' })
        ]);
    },
    
    fetch_friends: function(callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        this.model.fetch_friends(_.bind(function(data) {
            this.profile = this.model.user_profile;
            this.services = data.services;
            this.autofollow = data.autofollow;
            this.make_find_friends_and_services();
            this.make_profile_section();
            this.make_profile_tab();
            this.make_followers_tab();
            this.make_following_tab();
            callback && callback();
        }, this));
    },
    
    make_find_friends_and_services: function() {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        var $services = $('.NB-friends-services', this.$modal).empty();
        
        _.each(['twitter', 'facebook'], _.bind(function(service) {
            var $service;
            if (this.services && this.services[service][service+'_uid']) {
                $service = $.make('div', { className: 'NB-friends-service NB-connected NB-friends-service-'+service }, [
                    $.make('div', { className: 'NB-friends-service-title' }, _.string.capitalize(service)),
                    $.make('div', { className: 'NB-friends-service-connect NB-modal-submit-button NB-modal-submit-close' }, 'Disconnect')
                ]);
            } else {
                $service = $.make('div', { className: 'NB-friends-service NB-friends-service-'+service }, [
                    $.make('div', { className: 'NB-friends-service-title' }, _.string.capitalize(service)),
                    $.make('div', { className: 'NB-friends-service-connect NB-modal-submit-button NB-modal-submit-green' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_icon.png' }),
                        'Find ' + _.string.capitalize(service) + ' Friends'
                    ])
                ]);
            }
            $services.append($service);
        }, this));
       
        $autofollow = $.make('div', { className: 'NB-friends-service NB-friends-autofollow'}, [
            $.make('input', { type: 'checkbox', className: 'NB-friends-autofollow-checkbox', id: 'NB-friends-autofollow-checkbox', checked: this.autofollow ? 'checked' : null }),
            $.make('label', { className: 'NB-friends-autofollow-label', 'for': 'NB-friends-autofollow-checkbox' }, [
                'Auto-follow',
                $.make('br'),
                'my friends'
            ])
        ]);
        $services.prepend($autofollow);
        this.resize();
    },
    
    make_profile_section: function() {
        var $badge = $('.NB-friends-findfriends-profile', this.$modal).empty();
        var $profile_badge;
        var profile = this.profile;
        
        if (!profile.get('location') && !profile.get('bio') && !profile.get('website')) {
            $profile_badge = $.make('a', { 
                className: 'NB-friends-profile-link NB-modal-submit-button NB-modal-submit-green', 
                href: '#'
            }, [
                'Fill out your profile ',
                $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/eye.png', style: 'padding-left: 10px' }),
                $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/eye.png' })
            ]);
        } else {
            $profile_badge = new NEWSBLUR.Views.SocialProfileBadge({
                model: profile,
                user_profile: this.profile
            });
        }
        
        $badge.append($profile_badge);
    },
    
    make_profile_tab: function() {
        var $profile_container = $('.NB-friends-profile', this.$modal).empty();
        var $profile = $.make('form', [
            $.make('label', 'Username'),
            $.make('div', { className: 'NB-profile-username' }, [
                NEWSBLUR.Globals.username,
                $.make('a', { className: 'NB-splash-link NB-account-link', href: '#' }, 'Change')
            ]),
            $.make('label', { 'for': 'NB-profile-location' }, 'Location'),
            $.make('input', { id: 'NB-profile-location', name: 'location', type: 'text', className: 'NB-input', style: 'width: 220px', value: this.profile.get('location'), "data-max": 40 }),
            $.make('span', { className: 'NB-count NB-count-location' }),
            $.make('label', { 'for': 'NB-profile-website' }, 'Website'),
            $.make('input', { id: 'NB-profile-website', name: 'website', type: 'text', className: 'NB-input', style: 'width: 300px', value: this.profile.get('website'), "data-max": 200 }),
            $.make('span', { className: 'NB-count NB-count-website' }),
            $.make('label', { 'for': 'NB-profile-bio' }, 'Bio'),
            $.make('input', { id: 'NB-profile-bio', name: 'bio', type: 'text', className: 'NB-input', style: 'width: 380px', value: this.profile.get('bio'), "data-max": 80 }),
            $.make('span', { className: 'NB-count NB-count-bio' })
        ]);
        $profile_container.html($profile);
        this.make_profile_photo_chooser();
        this.disable_save();
    },
    
    make_profile_photo_chooser: function() {
        var $profiles = $('.NB-friends-profilephoto', this.$modal).empty();
        
        _.each(['twitter', 'facebook', 'gravatar'], _.bind(function(service) {
            var $profile = $.make('div', { className: 'NB-friends-profile-photo-group NB-friends-photo-'+service }, [
                $.make('div', { className: 'NB-friends-photo-title' }, [
                    $.make('input', { type: 'radio', name: 'profile_photo_service', value: service, id: 'NB-profile-photo-service-'+service }),
                    $.make('label', { 'for': 'NB-profile-photo-service-'+service }, _.string.capitalize(service))
                ]),
                $.make('div', { className: 'NB-friends-photo-image' }, [
                    $.make('label', { 'for': 'NB-profile-photo-service-'+service }, [
                        $.make('div', { className: 'NB-photo-loader' }),
                        $.make('img', { src: this.services[service][service+'_picture_url'] })
                    ])
                ]),
                (service == 'upload' && $.make('div', { className: 'NB-photo-link' }, [
                    $.make('a', { href: '#', className: 'NB-photo-upload-link NB-splash-link' }, 'Upload picture'),
                    $.make('input', { type: 'file', name: 'photo' })
                ])),
                (service == 'gravatar' && $.make('div', { className: 'NB-gravatar-link' }, [
                    $.make('a', { href: 'http://www.gravatar.com', className: 'NB-splash-link', target: '_blank' }, 'gravatar.com')
                ]))
            ]);
            if (service == this.profile.get('photo_service')) {
                $('input[type=radio]', $profile).attr('checked', true);
            }
            $profiles.append($profile);
        }, this));
    },
    
    make_followers_tab: function() {
        var $tab = $('.NB-tab-followers', this.$modal).empty();
        if (this.profile.get('follower_count') <= 0) {
            var $ghost = $.make('div', { className: 'NB-ghost NB-modal-section' }, 'Nobody has yet subscribed to your shared stories.');
            $tab.append($ghost);
        } else {
            var $heading = $.make('div', { className: 'NB-profile-section-heading' }, [
                'You are followed by ',
                Inflector.pluralize('person', this.profile.get('follower_count'), true),
                '.'
            ]);
            $tab.append($heading);
            this.model.follower_profiles.each(_.bind(function(profile) {
                $tab.append(new NEWSBLUR.Views.SocialProfileBadge({
                    model: profile,
                    user_profile: this.profile
                }));
            }, this));
        }
    },
    
    make_following_tab: function() {
        var $tab = $('.NB-tab-following', this.$modal).empty();
        if (this.profile.get('following_count') <= 0) {
            var $ghost = $.make('div', { className: 'NB-ghost NB-modal-section' }, 'You have not yet subscribed to anybody\'s shared stories.');
            $tab.append($ghost);
        } else {
            var $heading = $.make('div', { className: 'NB-profile-section-heading' }, [
                'You are following ',
                Inflector.pluralize('person', this.profile.get('following_count'), true),
                '.'
            ]);
            $tab.append($heading);
            this.model.following_profiles.each(_.bind(function(profile) {
                $tab.append(new NEWSBLUR.Views.SocialProfileBadge({
                    model: profile,
                    user_profile: this.profile
                }));
            }, this));
        }
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
                    setTimeout(function() {
                        $(window).resize();
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
    
    resize_modal: function(count) {
        var $tab = $('.NB-tab.NB-active', this.$modal);
        var $modal = this.$modal;
        var $modal_container = $modal.closest('.simplemodal-container');
        
        if (count > 50) return;
        
        if ($modal.height() > $modal_container.height() - 24) {
            $tab.height($tab.height() - 5);
            this.resize_modal(count+1);
        }
        
    },
    
    switch_tab: function(newtab) {
        var $modal_tabs = $('.NB-modal-tab', this.$modal);
        var $tabs = $('.NB-tab', this.$modal);
        
        $modal_tabs.removeClass('NB-active');
        $tabs.removeClass('NB-active');
        
        $modal_tabs.filter('.NB-modal-tab-'+newtab).addClass('NB-active');
        $tabs.filter('.NB-tab-'+newtab).addClass('NB-active');
        
        if (newtab == 'following') {
            this.make_following_tab();
        } else if (newtab == 'followers') {
            this.make_followers_tab();
        }
        this.resize_modal();
    },
    
    connect: function(service) {
        var options = "location=0,status=0,width=800,height=500";
        var url = "/social/" + service + "_connect";
        this.connect_window = window.open(url, '_blank', options);
    },
    
    disconnect: function(service) {
        var $service = $('.NB-friends-service-'+service, this.$modal);
        $('.NB-friends-service-connect', $service).text('Disconnecting...');
        this.model.disconnect_social_service(service, _.bind(function(data) {
            this.services = data.services;
            this.make_find_friends_and_services();
            this.make_profile_section();
            this.make_profile_tab();
        }, this));
    },
    
    post_connect: function(data) {
        $('.NB-error', this.$modal).remove();
        if (data.error) {
            var $error = $.make('div', { className: 'NB-error' }, [
                $.make('span', { className: 'NB-raquo' }, '&raquo; '),
                data.error
            ]).css('opacity', 0);
            $('.NB-friends-services', this.$modal).append($error);
            $error.animate({'opacity': 1}, {'duration': 1000});
            this.resize();
        } else {
            this.fetch_friends();
            NEWSBLUR.reader.hide_find_friends();
        }
    },

    close_and_load_account: function() {
        this.close(function() {
            NEWSBLUR.reader.open_account_modal();
        });
    },
    
    save_profile: function() {
        var data = {
            'photo_service': $('input[name=profile_photo_service]:checked', this.$modal).val(),
            'location': $('input[name=location]', this.$modal).val(),
            'website': $('input[name=website]', this.$modal).val(),
            'bio': $('input[name=bio]', this.$modal).val()
        };
        this.model.save_user_profile(data, _.bind(function() {
            this.fetch_friends(_.bind(function() {
                this.animate_profile_badge();
            }, this));
            this.switch_tab('findfriends');
        }, this));
        this.disable_save();
        $('.NB-profile-save-button', this.$modal).text('Saving...');
    },
    
    animate_profile_badge: function($badge) {
        $badge = $badge || $('.NB-friends-findfriends-profile .NB-profile-badge', this.$modal);
        _.delay(_.bind(function() {
            $badge.css('backgroundColor', 'white').animate({
                'backgroundColor': 'gold'
            }, {
                'queue': false,
                'duration': 600,
                'easing': 'linear',
                'complete': function() {
                    $badge.animate({
                        'backgroundColor': 'white'
                    }, {
                        'queue': false,
                        'duration': 1250,
                        'easing': 'easeOutQuad'
                    });
                }
            });
        }, this), 200);
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function($t, $p) {
            e.preventDefault();
            var newtab;
            if ($t.hasClass('NB-modal-tab-findfriends')) {
                newtab = 'findfriends';
            } else if ($t.hasClass('NB-modal-tab-profile')) {
                newtab = 'profile';
            } else if ($t.hasClass('NB-modal-tab-followers')) {
                newtab = 'followers';
            } else if ($t.hasClass('NB-modal-tab-following')) {
                newtab = 'following';
            }
            self.switch_tab(newtab);
        });        
        $.targetIs(e, { tagSelector: '.NB-friends-service-connect' }, function($t, $p) {
            e.preventDefault();
            var service;
            var $service = $t.closest('.NB-friends-service');
            if ($service.hasClass('NB-friends-service-twitter')) {
                service = 'twitter';
            } else if ($service.hasClass('NB-friends-service-facebook')) {
                service = 'facebook';
            }
            if ($service.hasClass('NB-connected')) {
                self.disconnect(service);
            } else {
                self.connect(service);
            }
        });
        $.targetIs(e, { tagSelector: '.NB-friends-profile-link' }, function($t, $p) {
            e.preventDefault();
            
            self.switch_tab('profile');
        });
        $.targetIs(e, { tagSelector: '.NB-profile-save-button' }, function($t, $p) {
            e.preventDefault();
            
            self.save_profile();
        });
        $.targetIs(e, { tagSelector: '.NB-account-link' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_account();
        });
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-friends-autofollow-checkbox' }, function($t, $p) {
            e.preventDefault();
            
            self.model.preference('autofollow_friends', $t.is(':checked'));
        });
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
    
    handle_profile_counts: function() {
        var focus = function(e) {
            var $input = $(e.currentTarget);
            var $count = $input.next('.NB-count').eq(0);
            var count = parseInt($input.data('max'), 10) - $input.val().length;
            $count.text(count);
            $count.toggleClass('NB-red', count < 0);
            $count.show();
        };
        $('.NB-tab-profile', this.$modal).delegate('input[type=text]', 'focus', focus)
            .delegate('input[type=text]', 'keyup', focus)
            .delegate('input[type=text]', 'keydown', focus)
            .delegate('input[type=text]', 'change', focus)
            .delegate('input[type=text]', 'blur', function(e) {
            var $input = $(e.currentTarget);
            var $count = $input.next('.NB-count').eq(0);
            $count.hide();
        });
    },
    
    delegate_change: function() {
        $('.NB-tab-profile', this.$modal).delegate('input[type=radio],input[type=checkbox],select,input[type=text]', 'change', _.bind(this.enable_save, this));
        $('.NB-tab-profile', this.$modal).delegate('input[type=text]', 'keydown', _.bind(this.enable_save, this));
    },
    
    enable_save: function() {
        $('.NB-profile-save-button', this.$modal).addClass('NB-modal-submit-green').text('Save My Profile');
    },
    
    disable_save: function() {
        $('.NB-profile-save-button', this.$modal).removeClass('NB-modal-submit-green').text('Change what you like above...');
    }
    
});