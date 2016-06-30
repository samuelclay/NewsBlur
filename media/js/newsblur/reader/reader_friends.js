NEWSBLUR.ReaderFriends = function(options) {
    var defaults = {
        width: 800
    };
        
    this.options = $.extend({}, defaults, options);
    this.sync_checks = 0;
    this.runner();
};

NEWSBLUR.ReaderFriends.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderFriends.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        this.fetch_friends();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
        this.$modal.bind('keyup', $.rescope(this.handle_keyup, this));
        this.handle_profile_counts();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal NB-modal-friends' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-findfriends' }, 'Find Friends'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-following' }, 'I\'m Following'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-followers' }, 'Following Me')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Friends and Followers',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('div', { className: 'NB-tab NB-tab-findfriends NB-active' }, [
                $.make('fieldset', [
                    $.make('legend', 'Your profile'),
                    $.make('div', { className: 'NB-modal-section NB-friends-findfriends-profile' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Social Connections'),
                    $.make('div', { className: 'NB-modal-section NB-friends-services' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'People to follow'),
                    $.make('div', { className: 'NB-modal-section NB-friends-findlist' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Search for friends'),
                    $.make('div', { className: 'NB-modal-section NB-friends-search' })
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
                $.make('div', { className: 'NB-modal-submit-grey NB-profile-save-button NB-modal-submit-button' }, 'Save my profile')
            ]),
            $.make('div', { className: 'NB-tab NB-tab-following' }),
            $.make('div', { className: 'NB-tab NB-tab-followers' })
        ]);
    },
    
    fetch_friends: function(callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        NEWSBLUR.assets.fetch_friends(_.bind(function(data) {
            this.profile = NEWSBLUR.assets.user_profile.clone();
            this.services = data.services;
            this.autofollow = data.autofollow;
            this.recommended_users = data.recommended_users;
            this.make_find_friends_and_services();
            this.make_profile_section();
            this.make_followers_tab();
            this.make_following_tab();
            callback && callback();
            _.defer(_.bind(this.resize, this));
        }, this), _.bind(function(data) {
            console.log(['Friends fetch error', data]);
            this.make_find_friends_and_services();
            this.make_profile_section();
            this.make_followers_tab();
            this.make_following_tab();
            callback && callback();
            _.defer(_.bind(this.resize, this));            
        }, this));
    },
    
    check_services_sync_status: function() {
        NEWSBLUR.assets.fetch_friends(_.bind(function(data) {
            console.log(["Find friends", data]);
            this.profile = NEWSBLUR.assets.user_profile;
            this.services = data.services;
            // if (!this.services['twitter'].syncing && !this.services['facebook'].syncing) {
                clearTimeout(this.sync_interval);
                this.make_find_friends_and_services();
            // }
        }, this), _.bind(function(data) {
            console.log(['Friends fetch error', data]);
            clearTimeout(this.sync_interval);
            this.make_find_friends_and_services();
        }, this));
    },
    
    make_find_friends_and_services: function() {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        var $services = $('.NB-friends-services', this.$modal).empty();
        var service_syncing = false;
        
        _.each(['twitter', 'facebook', 'appdotnet'], _.bind(function(service) {
            var $service;
            
            if (this.services && this.services[service][service+'_uid']) {
                var syncing = this.services[service].syncing;
                if (syncing) service_syncing = true;
                $service = $.make('div', { className: 'NB-friends-service NB-connected NB-friends-service-'+service + (this.services[service].syncing ? ' NB-friends-service-syncing' : '') }, [
                    $.make('div', { className: 'NB-friends-service-title' }, NEWSBLUR.utils.service_name(service)),
                    $.make('div', { className: 'NB-friends-service-connect NB-modal-submit-button NB-modal-submit-grey' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_service.png' }),
                        syncing ? 'Fetching...' : 'Connected'
                    ])
                ]);
            } else {
                $service = $.make('div', { className: 'NB-friends-service NB-friends-service-'+service }, [
                    $.make('div', { className: 'NB-friends-service-title' }, NEWSBLUR.utils.service_name(service)),
                    $.make('div', { className: 'NB-friends-service-connect NB-modal-submit-button NB-modal-submit-green' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_service_off.png' }),
                        'Find ' + NEWSBLUR.utils.service_name(service) + ' Friends'
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
        
        $('.NB-friends-search').html($.make('div', [
            $.make('div', { className: "NB-module-search-input NB-module-search-people" }, [
                $.make('div', { className: "NB-search-close" }),
                $.make('label', { 'for': "NB-friends-search-input" }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "img/reader/search_icon2.png" })
                ]),
                $.make('input', { id: "NB-friends-search-input", className: 'NB-input', placeholder: "Username or email..." })
            ]),
            $.make('div', { className: 'NB-loading NB-friends-search-loading' }),
            $.make('div', { className: 'NB-friends-search-badges' })
        ]));
        
        var $findlist = $('.NB-friends-findlist', this.$modal).empty();
        if (this.recommended_users && this.recommended_users.length) {
            _.each(this.recommended_users, function(profile) {
                var profile_model = new NEWSBLUR.Models.User(profile);
                $profile_badge = new NEWSBLUR.Views.SocialProfileBadge({
                    model: profile_model
                });
                $findlist.append($profile_badge);
            });
        } else {
            var $ghost = $.make('div', { className: 'NB-ghost' }, 'Nobody left to recommend. Good job!');
            $findlist.append($ghost);
        }
        
        if (service_syncing) {
            clearTimeout(this.sync_interval);
            this.sync_checks += 1;
            this.sync_interval = _.delay(_.bind(function() {
                this.check_services_sync_status();
            }, this), this.sync_checks * 1000);
        }
    },
    
    make_profile_section: function() {
        var $badge = $('.NB-friends-findfriends-profile', this.$modal).empty();
        var $profile_badge;
        var profile = this.profile;
        
        // if (!profile.get('location') && !profile.get('bio') && !profile.get('website')) {
        //     $profile_badge = $.make('a', { 
        //         className: 'NB-friends-profile-link NB-modal-submit-button NB-modal-submit-green', 
        //         href: '#'
        //     }, [
        //         'Fill out your profile ',
        //         $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/eye.png', style: 'padding-left: 10px' }),
        //         $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/eye.png' })
        //     ]);
        // } else {
            $profile_badge = new NEWSBLUR.Views.SocialProfileBadge({
                model: profile,
                show_edit_button: true
            });
        // }
        
        $badge.append($profile_badge);
    },
    
    make_followers_tab: function() {
        var $tab = $('.NB-tab-followers', this.$modal).empty();
        if (this.profile.get('follower_count') <= 0) {
            var $ghost = $.make('div', { className: 'NB-ghost NB-modal-section' }, 'Nobody has yet subscribed to your shared stories.');
            $tab.append($ghost);
        } else {
            var $heading = $.make('fieldset', [
                $.make('legend', { className: 'NB-profile-section-heading' }, [
                    'You are followed by ',
                    Inflector.pluralize('person', this.profile.get('follower_count'), true)
                ])
            ]);
            $tab.append($heading);
            NEWSBLUR.assets.follower_profiles.each(_.bind(function(profile) {
                $tab.append(new NEWSBLUR.Views.SocialProfileBadge({model: profile}));
            }, this));
        }
    },
    
    make_following_tab: function() {
        var $tab = $('.NB-tab-following', this.$modal).empty();
        if (this.profile.get('following_count') <= 0) {
            var $ghost = $.make('div', { className: 'NB-ghost NB-modal-section' }, 'You have not yet subscribed to anybody\'s shared stories.');
            $tab.append($ghost);
        } else {
            var $heading = $.make('fieldset', [
                $.make('legend', { className: 'NB-profile-section-heading' }, [
                    'You are following ',
                    Inflector.pluralize('person', this.profile.get('following_count'), true)
                ])
            ]);
            $tab.append($heading);
            NEWSBLUR.assets.following_profiles.each(_.bind(function(profile) {
                $tab.append(new NEWSBLUR.Views.SocialProfileBadge({model: profile}));
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
            'onClose': _.bind(function(dialog, callback) {
                clearTimeout(this.sync_interval);
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(200, function() {
                    dialog.overlay.empty().remove();
                    $.modal.close(callback);
                });
                $('.NB-modal-holder').empty().remove();
            }, this)
        });
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
    },
    
    connect: function(service) {
        var self = this;
        var options = "location=0,status=0,width=800,height=500";
        var url = "/oauth/" + service + "_connect";
        this.connect_window = window.open(url, '_blank', options);
        clearInterval(this.connect_window_timer);
        this.sync_checks = 0;
        this.connect_window_timer = setInterval(function() {
            console.log(["post connect window?", self, self.connect_window, self.connect_window.closed]);
            try {
                if (!self.connect_window || 
                    !self.connect_window.location || 
                    self.connect_window.closed) {
                    self.post_connect({});
                }
            } catch (err) {
                self.post_connect({});
            }
        }, 1000);
    },
    
    disconnect: function(service) {
        var $service = $('.NB-friends-service-'+service, this.$modal);
        $('.NB-friends-service-connect', $service).text('Disconnecting...');
        NEWSBLUR.assets.disconnect_social_service(service, _.bind(function(data) {
            this.services = data.services;
            this.make_find_friends_and_services();
            this.make_profile_section();
        }, this));
    },
    
    post_connect: function(data) {
        data = data || {};
        console.log(["post_connect", data, this, this.connect_window_timer]);
        clearInterval(this.connect_window_timer);
        $('.NB-error', this.$modal).remove();
        if (data.error) {
            var $error = $.make('div', { className: 'NB-error' }, [
                $.make('span', { className: 'NB-raquo' }, '&raquo; '),
                data.error
            ]).css('opacity', 0);
            $('.NB-friends-services', this.$modal).append($error);
            $error.animate({'opacity': 1}, {'duration': 1000});
        } else {
            this.fetch_friends();
        }
        
        NEWSBLUR.assets.preference('has_found_friends', true);
        NEWSBLUR.reader.check_hide_getting_started();
    },

    search_for_friends: function(query) {
        var $loading = $('.NB-friends-search .NB-friends-search-loading', this.$modal);
        var $badges = $('.NB-friends-search .NB-friends-search-badges', this.$modal);
        
        if (this.last_query && this.last_query == query) {
            return;
        } else {
            this.last_query = query;
        }
        
        if (!query) {
            $badges.html('');
            return;
        }
        
        $loading.addClass('NB-active');
        
        NEWSBLUR.assets.search_for_friends(query, _.bind(function(data) {
            $loading.removeClass('NB-active');
            if (!data || !data.profiles || !data.profiles.length) {
                $badges.html($.make('div', { 
                    className: 'NB-friends-search-badges-empty' 
                }, [
                    $.make('div', { className: 'NB-raquo' }, '&raquo;'),
                    'Sorry, nobody matches "'+query+'".'
                ]));
                return;
            }
            
            $badges.html($.make('div', _.map(data.profiles, function(profile) {
                var user = new NEWSBLUR.Models.User(profile);
                return new NEWSBLUR.Views.SocialProfileBadge({model: user});
            })));
            
        }, this));
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
            } else if ($service.hasClass('NB-friends-service-appdotnet')) {
                service = 'appdotnet';
            }
            if ($service.hasClass('NB-connected')) {
                self.disconnect(service);
            } else {
                self.connect(service);
            }
        });
        $.targetIs(e, { tagSelector: '.NB-friends-profile-link' }, function($t, $p) {
            e.preventDefault();
            
            self.close(function() {
                NEWSBLUR.reader.open_profile_editor_modal();
            });
        });
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-friends-autofollow-checkbox' }, function($t, $p) {
            e.preventDefault();
            
            NEWSBLUR.assets.preference('autofollow_friends', $t.is(':checked'));
        });
    },
    
    handle_keyup: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '#NB-friends-search-input' }, function($t, $p) {
            self.search_for_friends($t.val());
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
    }
    
});