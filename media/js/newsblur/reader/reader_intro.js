NEWSBLUR.ReaderIntro = function(options) {
    var defaults = {};
    
    _.bindAll(this, 'close');
    
    this.options = $.extend({
      'page_number': 1
    }, defaults, options);
    this.model   = NEWSBLUR.AssetModel.reader();
    this.services = {
        'twitter': {},
        'facebook': {}
    };
    this.autofollow = true;
    
    this.page_number = this.options.page_number;
    this.slider_value = 0;
    this.intervals = {};
    this.runner();
};

NEWSBLUR.ReaderIntro.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderIntro.prototype.constructor = NEWSBLUR.ReaderIntro;

_.extend(NEWSBLUR.ReaderIntro.prototype, {
    
    TITLES: [
      'Welcome to NewsBlur',
      'Welcome to NewsBlur',
      'Welcome to NewsBlur',
      'Welcome to NewsBlur',
      'Welcome to NewsBlur'
    ],
    
    runner: function() {
        this.make_modal();
        this.make_find_friends_and_services();
        this.open_modal();
        this.page(this.page_number);
        this.fetch_friends();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },
        
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-intro NB-modal' }, [
            $.make('div', { className: 'NB-modal-page' }),
            $.make('span', { className: 'NB-modal-loading NB-spinner'}),
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('img', { className: 'NB-intro-spinning-logo', src: NEWSBLUR.Globals.MEDIA_URL + 'img/logo_512.png' }),
            $.make('div', { className: 'NB-page NB-page-1' }, [
                $.make('h4', { className: 'NB-page-1-started' }, "So much time and so little to do. Strike that! Reverse it.")
            ]),
            $.make('div', { className: 'NB-page NB-page-2 carousel' }, [
                $.make('div', { className: 'carousel-inner NB-intro-imports' }, [
                    $.make('div', { className: 'item NB-intro-imports-start' }, [
                        $.make('h4', { className: 'NB-page-2-started' }, "Let's get some sites to read."),
                        $.make('div', { className: 'NB-intro-import NB-intro-import-google' }, [
                            $.make('h3', [
                                'Import from', 
                                $.make('br'), 
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/google-reader-logo.gif' })
                            ]),
                            $.make('a', { href: NEWSBLUR.URLs['google-reader-authorize'], className: 'NB-google-reader-oauth NB-modal-submit-green NB-modal-submit-button' }, [
                                'Connect to Google'
                            ]),
                            $.make('div', { className: 'NB-error' })
                        ]),
                        $.make('div', { className: 'NB-intro-import NB-intro-import-opml' }, [
                            $.make('h3', ['Upload an', $.make('br'), 'OPML file']),
                            $.make('form', { method: 'post', enctype: 'multipart/form-data', className: 'NB-opml-upload-form' }, [
                                $.make('div', { href: '#', className: 'NB-intro-upload-opml NB-modal-submit-green NB-modal-submit-button' }, [
                                    'Upload OPML File',
                                    $.make('input', { type: 'file', name: 'file', id: 'NB-intro-upload-opml-button', className: 'NB-intro-upload-opml-button' })
                                ])
                            ]),
                            $.make('div', { className: 'NB-error' })
                        ])
                    ]),
                    $.make('div', { className: 'item NB-intro-imports-progress' }, [
                        $.make('h4', { className: 'NB-page-2-started' }, "Importing your sites..."),
                        $.make('div', { className: 'NB-loading' })
                    ]),
                    $.make('div', { className: 'item NB-intro-imports-sites' }, [
                        $.make('h4'),
                        $.make('div', { className: 'NB-intro-import-restart NB-modal-submit-grey NB-modal-submit-button' }, [
                            '&laquo; Restart and re-import your sites'
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-intro-bookmarklet' }, [
                    NEWSBLUR.generate_bookmarklet(),
                    $.make('div', { className: 'NB-intro-bookmarklet-arrow' }, '&larr;'),
                    $.make('div', { className: 'NB-intro-bookmarklet-info' }, 'Install the bookmarklet')
                ])
            ]),
            $.make('div', { className: 'NB-page NB-page-3' }, [
                $.make('h4', { className: 'NB-page-3-started' }, "Connect with friends"),
                $.make('div', { className: 'NB-intro-services' })
            ]),
            $.make('div', { className: 'NB-page NB-page-4' }, [
                $.make('h4', { className: 'NB-page-4-started' }, "Feed chooser/premium")
            ]),
            $.make('div', { className: 'NB-page NB-page-5' }, [
                $.make('h4', { className: 'NB-page-5-started' }, "Feedback")
            ]),
            $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-page-next NB-modal-submit-button NB-modal-submit-green NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-tutorial-next-page-text' }, "Let's Get Started "),
                $.make('span', { className: 'NB-raquo' }, '&raquo;')
              ])
            ])
        ]);
        
        $('.carousel', this.$modal).carousel({
            interval: 1000
        });
    },
    
    set_title: function() {
      $('.NB-modal-title', this.$modal).text(this.TITLES[this.page_number-1]);
    },

    // ==========
    // = Social =
    // ==========
    
    fetch_friends: function(callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        this.model.fetch_friends(_.bind(function(data) {
            this.profile = this.model.user_profile;
            this.services = data.services;
            this.autofollow = data.autofollow;
            this.make_find_friends_and_services();
            callback && callback();
        }, this));
    },
    
    make_find_friends_and_services: function() {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        var $services = $('.NB-intro-services', this.$modal).empty();
        
        _.each(['twitter', 'facebook'], _.bind(function(service) {
            var $service;
            if (this.services && this.services[service][service+'_uid']) {
                $service = $.make('div', { className: 'NB-friends-service NB-connected NB-friends-service-'+service }, [
                    $.make('div', { className: 'NB-friends-service-title' }, _.string.capitalize(service)),
                    $.make('div', { className: 'NB-friends-service-connected' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_icon.png' }),
                        'Connected'
                    ])
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
       
        $autofollow = $.make('div', { className: 'NB-friends-autofollow'}, [
            $.make('input', { type: 'checkbox', className: 'NB-friends-autofollow-checkbox', id: 'NB-friends-autofollow-checkbox', checked: this.autofollow ? 'checked' : null }),
            $.make('label', { className: 'NB-friends-autofollow-label', 'for': 'NB-friends-autofollow-checkbox' }, 'and auto-follow them')
        ]);
        $services.prepend($autofollow);
        this.resize();
        
        if (this.services.twitter.twitter_uid || this.services.facebook.facebook_uid) {
            $('.NB-tutorial-next-page-text', this.$modal).text('Next step ');
        }
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
    
    // ==========
    // = Paging =
    // ==========
    
    next_page: function() {
      return this.page(this.page_number+1, this.page_number);
    },
    
    previous_page: function() {
      return this.page(this.page_number-1, this.page_number);
    },
    
    page: function(page_number, from_page) {
      if (page_number == null) {
        return this.page_number;
      }
      var page_count = $('.NB-page', this.$modal).length;
      this.page_number = page_number;
      
      if (page_number == page_count) {
        $('.NB-tutorial-next-page-text', this.$modal).text('All Done ');
      } else if (page_number > page_count) {
        return this.close();
      } else if (page_number == 1) {
        $('.NB-tutorial-next-page-text', this.$modal).text("Let's Get Started ");
      } else {
        $('.NB-tutorial-next-page-text', this.$modal).text('Skip this step ');
      }
      $('.NB-page', this.$modal).css({'display': 'none'});
      $('.NB-page-'+this.page_number, this.$modal).css({'display': 'block'});
      $('.NB-modal-page', this.$modal).html($.make('div', [
        'Step ',
        $.make('b', this.page_number),
        ' of ',
        $.make('b', page_count)
      ]));
      if (page_number > 1) {
          $('.NB-intro-spinning-logo', this.$modal).css({'top': 0, 'left': 0, 'width': 48, 'height': 48});
          $('.NB-modal-title', this.$modal).css({'paddingLeft': 42});
      }
      
      this.set_title();
      
      if (page_number == 2) {
          this.advance_import_carousel();
      }
    },
    
    advance_import_carousel: function(page) {
        var $carousel = $('.carousel', this.$modal);
        $carousel.carousel('pause');
        
        if (!_.isNumber(page)) { 
            if (_.size(this.model.feeds) && !this.options.force_import) {
                page = 2;
                $('.NB-intro-imports-sites', this.$modal).addClass('active');
            } else {
                page = 0;
                $('.NB-intro-imports-start', this.$modal).addClass('active');
            }
        }
        
        if (page >= 2) {
            $('.NB-tutorial-next-page-text', this.$modal).text('Next step ');
        }
        
        $carousel.carousel(page);
        $carousel.carousel('pause');
        this.count_feeds();
    },
    
    count_feeds: function() {
        $(".NB-intro-imports-sites h4", this.$modal).text([
            'You are subscribed to ',
            Inflector.pluralize(' site', _.size(this.model.feeds), true),
            '.'
        ].join(""));
    },
    
    fade_out_logo: function() {
        var self = this;
        var $logo = $('.NB-intro-spinning-logo', this.$modal);
        var $page1 = $('.NB-page-1', this.$modal);
        var $page2 = $('.NB-page-2', this.$modal);
        var $submit = $('.NB-modal-submit', this.$modal);
        var $title = $('.NB-modal-title', this.$modal);
        
        $submit.animate({'opacity': 0}, {'duration': 800, 'easing': 'easeInOutQuad'});
        $page1.animate({'opacity': 0}, {
            'duration': 800, 
            'easing': 'easeInOutQuint', 
            'complete': function() {
                $logo.animate({'top': 0, 'left': 0, 'width': 48, 'height': 48}, {
                    'duration': 1160,
                    'easing': 'easeInOutCubic',
                    'complete': function() {
                        $page2.css({'opacity': 0});
                        self.page(2);
                        $page2.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeInOutQuad'});
                        $submit.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeInOutQuad'});
                    }
                });
                $title.animate({'paddingLeft': 42}, {'duration': 1100, 'easing': 'easeInOutQuart'});
            }
        });
    },
    
    close_and_load_newsblur_blog: function() {
      this.close();
      NEWSBLUR.reader.load_feed_in_tryfeed_view(this.newsblur_feed.id, this.newsblur_feed);
    },
    
    // ==========
    // = Import =
    // ==========
    
    google_reader_connect: function() {
        var options = "location=0,status=0,width=800,height=500";
        var url = "/import/authorize?modal=true";
        this.connect_window = window.open(url, '_blank', options);
        NEWSBLUR.reader.flags.importing_from_google_reader = true;
    },
    
    start_import_from_google_reader: function(data) {
        var $error = $('.NB-intro-gitgoogle .NB-error', this.$modal);
        var $loading = $('.NB-intro-imports-progress .NB-loading', this.$modal);

        if (data.error) {
            $error.show().text(data.error);
            this.advance_import_carousel(0);
        } else {
            $error.hide();
            NEWSBLUR.reader.flags.importing_from_google_reader = false;
            this.advance_import_carousel(1);
            $loading.addClass('NB-active');
            this.model.start_import_from_google_reader($.rescope(this.finish_import_from_google_reader, this));    
        }
    },
    
    finish_import_from_google_reader: function() {
        var $loading = $('.NB-intro-imports-progress .NB-loading', this.$modal);
        $loading.removeClass('NB-active');
        
        NEWSBLUR.reader.load_feeds(_.bind(function() {
            this.advance_import_carousel(2);
        }, this));
    },
    
    handle_opml_upload: function() {
        var self = this;
        var $loading = $('.NB-intro-imports-progress .NB-loading', this.$modal);
        var $error = $('.NB-intro-import-opml .NB-error', this.$modal);
        var $file = $('.NB-intro-upload-opml-button', this.$modal);
        $error.slideUp(300);
        $loading.addClass('NB-active');

        if (NEWSBLUR.Globals.is_anonymous) {
            var $error = $('.NB-error', '.NB-fieldset.NB-add-opml');
            $error.text("Please create an account. Not much to do without an account.");
            $error.slideDown(300);
            $loading.removeClass('NB-active');
            return false;
        }
        
        this.advance_import_carousel(1);
        
        // NEWSBLUR.log(['Uploading']);
        var formData = new FormData($file.closest('form')[0]);
        $.ajax({
            url: NEWSBLUR.URLs['opml-upload'],
            type: 'POST',
            success: function (data, status) {
                console.log(["upload opml success", status, data]);
                $loading.removeClass('NB-active');
                NEWSBLUR.reader.load_feeds(function() {
                    self.advance_import_carousel(2);
                });
                NEWSBLUR.reader.load_recommended_feed();
            },
            error: function (data, status, e) {
                self.advance_import_carousel(0);
                $loading.removeClass('NB-active');
                NEWSBLUR.log(['Error', data, status, e]);
                $error.text("There was a problem uploading your OPML file. Try e-mailing it to samuel@ofbrooklyn.com.");
                $error.slideDown(300);
            },
            data: formData,
            cache: false,
            contentType: false,
            processData: false
        });
        
        $file.replaceWith($file.clone());
        
        return false;
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-page-next' }, function($t, $p) {
            e.preventDefault();
            
            if (self.page_number == 1) {
                self.fade_out_logo();
            } else {
                self.next_page();
            }
        });
        $.targetIs(e, { tagSelector: '.NB-tutorial-finish-newsblur-blog' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_newsblur_blog();
        });
        
        $.targetIs(e, { tagSelector: '.NB-google-reader-oauth' }, function($t, $p) {
            e.preventDefault();
            self.google_reader_connect();
        });
        $.targetIs(e, { tagSelector: '.NB-intro-import-restart' }, function($t, $p) {
            e.preventDefault();
            self.advance_import_carousel(0);
        });
        $.targetIs(e, { tagSelector: '.NB-intro-upload-opml' }, function($t, $p) {
            // e.preventDefault();
            // return false;
        });
        $.targetIs(e, { tagSelector: '.NB-goodies-bookmarklet-button' }, function($t, $p) {
            e.preventDefault();
            
            alert('Drag this button to your bookmark toolbar.');
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
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-intro-upload-opml-button' }, function($t, $p) {
            e.preventDefault();
            
            self.handle_opml_upload();
        });
    }
    
});