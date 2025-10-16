NEWSBLUR.ReaderServices = function(options) {
    var defaults = {
        width: 800
    };
        
    this.options = $.extend({}, defaults, options);
    this.sync_checks = 0;
    this.runner();
};

NEWSBLUR.ReaderServices.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderServices.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        this.fetch_services();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
        this.$modal.bind('keyup', $.rescope(this.handle_keyup, this));
        this.handle_profile_counts();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal NB-modal-services' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-services' }, 'Services'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-shortcuts' }, 'Sharing Shortcuts'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-' }, '')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Sharing Services',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('div', { className: 'NB-tab NB-tab-services NB-active' }, [
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
            ])
        ]);
    },
    
    fetch_services: function(callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        NEWSBLUR.assets.fetch_services(_.bind(function(data) {
            this.profile = NEWSBLUR.assets.user_profile.clone();
            this.services = data.services;
            callback && callback();
            _.defer(_.bind(this.resize, this));
        }, this), _.bind(function(data) {
            console.log(['Services fetch error', data]);
            callback && callback();
            _.defer(_.bind(this.resize, this));            
        }, this));
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
    
    make_find_friends_and_services: function() {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        var $services = $('.NB-friends-services', this.$modal).empty();
        var service_syncing = false;
        
        _.each(['twitter', 'facebook'], _.bind(function(service) {
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
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function($t, $p) {
            e.preventDefault();
            var newtab;
            if ($t.hasClass('NB-modal-tab-services')) {
                newtab = 'services';
            } else if ($t.hasClass('NB-modal-tab-shortcuts')) {
                newtab = 'shortcuts';
            } else if ($t.hasClass('NB-modal-tab-')) {
                newtab = '';
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
    }
    
});