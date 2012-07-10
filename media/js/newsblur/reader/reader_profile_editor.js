NEWSBLUR.ReaderProfileEditor = function(options) {
    var defaults = {
        width: 800
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.assets;
    this.profile = this.model.user_profile;
    
    this.runner();
};

NEWSBLUR.ReaderProfileEditor.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderProfileEditor.prototype, {
    
    runner: function() {
        this.options.onOpen = _.bind(function() {
            this.resize_modal();
        }, this);

        this.make_modal();
        this.open_modal();
        this.fetch_user_profile();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.handle_profile_counts();
        this.delegate_change();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal NB-modal-profile-editor' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-profile' }, 'Profile'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-blurblog' }, 'Blurblog')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, 'Your Profile'),
            $.make('div', { className: 'NB-tab NB-tab-profile NB-active' }, [
                $.make('fieldset', [
                    $.make('legend', 'Preview'),
                    $.make('div', { className: 'NB-modal-section NB-friends-findfriends-profile' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Profile picture'),
                    $.make('div', { className: 'NB-modal-section NB-friends-profilephoto'})
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Profile Details'),
                    $.make('div', { className: 'NB-modal-section NB-friends-profile'}, [
                        $.make('form', [
                            $.make('label', 'Username'),
                            $.make('div', { className: 'NB-profile-username' }, [
                                NEWSBLUR.Globals.username,
                                $.make('a', { className: 'NB-splash-link NB-account-link', href: '#' }, 'Change')
                            ]),
                            $.make('label', { 'for': 'NB-profile-location' }, 'Location'),
                            $.make('input', { id: 'NB-profile-location', name: 'location', type: 'text', className: 'NB-input', style: 'width: 300px', value: this.profile.get('location'), "data-max": 40 }),
                            $.make('span', { className: 'NB-count NB-count-location' }),
                            $.make('label', { 'for': 'NB-profile-website' }, 'Website'),
                            $.make('input', { id: 'NB-profile-website', name: 'website', type: 'text', className: 'NB-input', style: 'width: 440px', value: this.profile.get('website'), "data-max": 200 }),
                            $.make('span', { className: 'NB-count NB-count-website' }),
                            $.make('label', { 'for': 'NB-profile-bio' }, 'Bio'),
                            $.make('input', { id: 'NB-profile-bio', name: 'bio', type: 'text', className: 'NB-input', style: 'width: 580px', value: this.profile.get('bio'), "data-max": 160 }),
                            $.make('span', { className: 'NB-count NB-count-bio' })
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-modal-submit-grey NB-profile-save-button NB-modal-submit-button' }, 'Save my profile')
            ]),
            $.make('div', { className: 'NB-tab NB-tab-blurblog' }, [
                $.make('fieldset', [
                    $.make('legend', 'Your Blurblog'),
                    $.make('div', { className: 'NB-modal-section NB-profile-editor-blurblog-preview' })
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Custom CSS'),
                    $.make('div', { className: 'NB-modal-section NB-profile-editor-blurblog-custom-css'})
                ]),
                $.make('fieldset', [
                    $.make('legend', 'Comments'),
                    $.make('div', { className: 'NB-modal-section NB-profile-editor-blurblog'})
                ]),
                $.make('div', { className: 'NB-modal-submit-grey NB-profile-save-button NB-modal-submit-button' }, 'Save my blurblog settings')
            ]),
            $.make('div', { className: 'NB-tab NB-tab-following' }),
            $.make('div', { className: 'NB-tab NB-tab-followers' })
        ]);
    },
    
    make_profile_section: function() {
        var $badge = $('.NB-friends-findfriends-profile', this.$modal).empty();
        var $profile_badge;
        var profile = this.profile;
        
        $profile_badge = new NEWSBLUR.Views.SocialProfileBadge({model: profile});
        $badge.append($profile_badge);
    },
    
    make_profile_photo_chooser: function() {
        var $profiles = $('.NB-friends-profilephoto', this.$modal).empty();
        
        _.each(['nothing', 'twitter', 'facebook', 'gravatar'], _.bind(function(service) {
            var $profile = $.make('div', { className: 'NB-friends-profile-photo-group NB-friends-photo-'+service }, [
                $.make('div', { className: 'NB-friends-photo-title' }, [
                    $.make('input', { type: 'radio', name: 'profile_photo_service', value: service, id: 'NB-profile-photo-service-'+service }),
                    $.make('label', { 'for': 'NB-profile-photo-service-'+service }, _.string.capitalize(service))
                ]),
                $.make('div', { className: 'NB-friends-photo-image' }, [
                    $.make('label', { 'for': 'NB-profile-photo-service-'+service }, [
                        $.make('div', { className: 'NB-photo-loader' }),
                        $.make('img', { src: service == 'nothing' || !this.services[service][service+'_picture_url'] ?
                            NEWSBLUR.Globals.MEDIA_URL + 'img/reader/default_profile_photo.png' :
                            this.services[service][service+'_picture_url']
                        })
                    ])
                ]),
                (service == 'upload' && $.make('div', { className: 'NB-photo-link' }, [
                    $.make('a', { href: '#', className: 'NB-photo-upload-link NB-splash-link' }, 'Upload picture'),
                    $.make('input', { type: 'file', name: 'photo' })
                ])),
                (service == 'gravatar' && $.make('div', { className: 'NB-gravatar-link' }, [
                    $.make('a', { href: 'http://www.gravatar.com', className: 'NB-splash-link', target: '_blank' }, 'gravatar.com')
                ])),
                (_.contains(['facebook', 'twitter'], service) && $.make('div', { className: 'NB-friends-link' }, [
                    $.make('div', { className: 'NB-splash-link' }, 'connect')
                ]))
            ]);
            if (service == this.profile.get('photo_service') ||
                (service == 'nothing' && !this.profile.get('photo_service'))) {
                $('input[type=radio]', $profile).attr('checked', true);
            }
            $profiles.append($profile);
        }, this));
    },
    
    fetch_user_profile: function(callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        this.model.load_current_user_profile(_.bind(function(data) {
            $('.NB-modal-loading', this.$modal).removeClass('NB-active');
            this.profile = this.model.user_profile;
            this.services = data.services;
            this.make_profile_section();
            this.make_profile_photo_chooser();
            callback && callback();
        }, this));
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
        
        this.resize_modal();
    },

    close_and_load_account: function() {
        this.close(function() {
            NEWSBLUR.reader.open_account_modal();
        });
    },
    
    close_and_load_friends: function() {
        this.close(function() {
            NEWSBLUR.reader.open_friends_modal();
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
            this.animate_profile_badge();
            this.disable_save();
        }, this));
        this.disable_save();
        $('.NB-profile-save-button', this.$modal).text('Saving...');
    },
    
    animate_profile_badge: function($badge) {
        $badge = $('table', $badge) || $('.NB-friends-findfriends-profile .NB-profile-badge table', this.$modal);
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
        }, this), 800);
        $badge.closest('.NB-tab').scrollTo(0, { 
            duration: 1000,
            axis: 'y', 
            easing: 'easeInOutQuint', 
            offset: 0, 
            queue: false
        });
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function($t, $p) {
            e.preventDefault();
            var newtab;
            if ($t.hasClass('NB-modal-tab-profile')) {
                newtab = 'profile';
            } else if ($t.hasClass('NB-modal-tab-blurblog')) {
                newtab = 'blurblog';
            }
            self.switch_tab(newtab);
        });        
        $.targetIs(e, { tagSelector: '.NB-profile-save-button' }, function($t, $p) {
            e.preventDefault();
            
            self.save_profile();
        });
        $.targetIs(e, { tagSelector: '.NB-account-link' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_account();
        });
        $.targetIs(e, { tagSelector: '.NB-friends-link' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_friends();
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
        $('.NB-tab-profile', this.$modal).delegate('input[type=radio],input[type=checkbox],select', 'change', _.bind(this.enable_save, this));
        $('.NB-tab-profile', this.$modal).delegate('input[type=text]', 'keydown', _.bind(this.enable_save, this));
    },
    
    enable_save: function() {
        console.log(["enable_save"]);
        $('.NB-profile-save-button', this.$modal)
            .removeClass('NB-modal-submit-grey')
            .addClass('NB-modal-submit-green')
            .text('Save My Profile');
    },
    
    disable_save: function() {
        $('.NB-profile-save-button', this.$modal)
            .addClass('NB-modal-submit-grey')
            .removeClass('NB-modal-submit-green')
            .text('Change what you like above...');
    }
    
});