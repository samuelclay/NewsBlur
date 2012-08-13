NEWSBLUR.ReaderIntro = function(options) {
    var defaults = {};
    var intro_page = NEWSBLUR.assets.preference('intro_page');
    
    _.bindAll(this, 'close', 'start_import_from_google_reader', 'post_connect');
    this.options = $.extend({
      'page_number': intro_page && _.isNumber(intro_page) && intro_page <= 4 ? intro_page : 1
    }, defaults, options);
    this.services = {
        'twitter': {},
        'facebook': {}
    };
    this.flags = {};
    this.autofollow = true;
    
    this.page_number = this.options.page_number;
    this.slider_value = 0;
    this.intervals = {};
    this.runner();
};

NEWSBLUR.ReaderIntro.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderIntro.prototype.constructor = NEWSBLUR.ReaderIntro;

_.extend(NEWSBLUR.ReaderIntro.prototype, {
    
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
            $.make('h2', { className: 'NB-modal-title' }, 'Welcome to NewsBlur'),
            $.make('img', { className: 'NB-intro-spinning-logo', src: NEWSBLUR.Globals.MEDIA_URL + 'img/logo_512.png' }),
            $.make('div', { className: 'NB-page NB-page-1' }, [
                $.make('h4', { className: 'NB-page-1-started' }, "So much time and so little to do. Strike that! Reverse it.")
            ]),
            $.make('div', { className: 'NB-page NB-page-2' }, [
                $.make('div', { className: 'carousel slide'}, [
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
                                $.make('form', { method: 'post', enctype: 'multipart/form-data', encoding: 'multipart/form-data', className: 'NB-opml-upload-form' }, [
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
                            ]),
                            $.make('div', { className: 'NB-intro-import-delayed' }, [
                                'There are too many sites to process...',
                                $.make('br'),
                                'You will be emailed within a minute or three.'
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-intro-bookmarklet NB-intro-section' }, [
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
                $.make('h4', { className: 'NB-page-4-started' }, "Keep up-to-date with NewsBlur"),
                $.make('div', { className: 'NB-intro-section' }, [
                    $.make('div', { className: 'NB-intro-uptodate-follow NB-intro-uptodate-follow-twitter NB-right' }, [
                        $.make('input', { type: 'checkbox', id: 'NB-intro-uptodate-follow-newsblur' }),
                        $.make('label', { 'for': 'NB-intro-uptodate-follow-newsblur' }, [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/new-window-icon.png', className: 'NB-intro-uptodate-newwindow' }),
                            $.make('img', { src: 'http://a0.twimg.com/profile_images/1268996309/logo_128_normal.png', style: 'border-color: #505050;' }),
                            $.make('span', [
                                'Follow @newsblur on', 
                                $.make('br'), 
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/twitter_icon.png' }),
                                'Twitter'
                            ])
                        ])
                    ]),
                    $.make('div', { className: 'NB-intro-uptodate-follow NB-intro-uptodate-follow-twitter' }, [
                        $.make('input', { type: 'checkbox', id: 'NB-intro-uptodate-follow-samuelclay' }),
                        $.make('label', { 'for': 'NB-intro-uptodate-follow-samuelclay' }, [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/new-window-icon.png', className: 'NB-intro-uptodate-newwindow' }),
                            $.make('img', { src: 'http://a0.twimg.com/profile_images/1382021023/Campeche_Steps_normal.jpg', style: 'border-color: #505050;' }),
                            $.make('span', [
                                'Follow @samuelclay on', 
                                $.make('br'), 
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/twitter_icon.png' }),
                                'Twitter'
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-intro-section' }, [
                    $.make('div', { className: 'NB-intro-uptodate-follow NB-right' }, [
                        $.make('input', { type: 'checkbox', id: 'NB-intro-uptodate-follow-popular' }),
                        $.make('label', { 'for': 'NB-intro-uptodate-follow-popular' }, [
                            $.make('span', [
                                'Subscribe to', 
                                $.make('br'), 
                                $.make('img', { src: '/media/img/favicon.png' }),
                                'Popular Shared Stories'
                            ])
                        ])
                    ]),
                    $.make('div', { className: 'NB-intro-uptodate-follow' }, [
                        $.make('input', { type: 'checkbox', id: 'NB-intro-uptodate-follow-blog' }),
                        $.make('label', { 'for': 'NB-intro-uptodate-follow-blog' }, [
                            $.make('span', [
                                'Subscribe to', 
                                $.make('br'), 
                                $.make('img', { src: '/media/img/favicon.png' }),
                                'The NewsBlur Blog'
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-intro-section' }, [
                    "You're ready to go! Hope you enjoy NewsBlur."
                ])
            ]),
            $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-page-next NB-modal-submit-button NB-modal-submit-green NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-tutorial-next-page-text' }, "Let's Get Started "),
                $.make('span', { className: 'NB-raquo' }, '&raquo;')
              ])
            ])
        ]);
        
        $('.carousel', this.$modal).carousel({});
    },
    
    // ==========
    // = Social =
    // ==========
    
    fetch_friends: function(callback) {
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        NEWSBLUR.assets.fetch_friends(_.bind(function(data) {
            this.profile = NEWSBLUR.assets.user_profile;
            this.services = data.services;
            this.autofollow = data.autofollow;
            this.make_find_friends_and_services();
            callback && callback();
        }, this));
    },
    
    make_find_friends_and_services: function() {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        var $services = $('.NB-intro-services', this.$modal).empty();
        var service_syncing = false;
        
        _.each(['twitter', 'facebook'], _.bind(function(service) {
            var $service;
            if (this.services && this.services[service][service+'_uid'] && !this.services[service].syncing) {
                $service = $.make('div', { className: 'NB-friends-service NB-connected NB-friends-service-'+service }, [
                    $.make('div', { className: 'NB-friends-service-title' }, _.string.capitalize(service)),
                    $.make('div', { className: 'NB-friends-service-connected' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_icon.png' }),
                        'Connected'
                    ])
                ]);
                
            } else {
                var syncing = this.services && this.services[service] && this.services[service].syncing;
                if (syncing) service_syncing = true;
                
                $service = $.make('div', { className: 'NB-friends-service NB-friends-service-'+service + (syncing ? ' NB-friends-service-syncing' : '') }, [
                    $.make('div', { className: 'NB-friends-service-title' }, _.string.capitalize(service)),
                    $.make('div', { className: 'NB-friends-service-connect NB-modal-submit-button ' + (syncing ? 'NB-modal-submit-grey' : 'NB-modal-submit-green') }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_icon.png' }),
                        (syncing ? 'Fetching...' : 'Find ' + _.string.capitalize(service) + ' Friends')
                    ])
                ]);
            }
            $services.append($service);
        }, this));
       
        var $autofollow = $.make('div', { className: 'NB-friends-autofollow'}, [
            $.make('input', { type: 'checkbox', className: 'NB-friends-autofollow-checkbox', id: 'NB-friends-autofollow-checkbox', checked: this.autofollow ? 'checked' : null }),
            $.make('label', { className: 'NB-friends-autofollow-label', 'for': 'NB-friends-autofollow-checkbox' }, 'and auto-follow them')
        ]);
        $services.prepend($autofollow);
        
        if (!this.services.twitter.twitter_uid || !this.services.facebook.facebook_uid) {
             var $note = $.make('div', { className: 'NB-note'}, [
                'Feel comfortable connecting to these services.',
                $.make('br'),
                'Nothing happens without your permission.'
            ]);
            $services.append($note);
        }
        if (this.services.twitter.twitter_uid || this.services.facebook.facebook_uid) {
            var $stats = $.make('div', { className: 'NB-services-stats' });
            _.each(['following', 'follower'], _.bind(function(follow) {
                var $stat = $.make('div', { className: 'NB-intro-services-stats-count' }, [
                    $.make('div', { className: 'NB-intro-services-stats-count-number' }, this.profile.get(follow+'_count')),
                    $.make('div', { className: 'NB-intro-services-stats-count-description' }, Inflector.pluralize(follow, this.profile.get(follow+'_count')))
                ]);
                $stats.append($stat);
            }, this));
            $services.append($stats);
            $('.NB-tutorial-next-page-text', this.$modal).text('Next step ');
        }

        if (service_syncing) {
            clearInterval(this.sync_interval);
            this.sync_interval = setInterval(_.bind(function() {
                this.fetch_friends();
            }, this), 3000);
        }
    },
    
    connect: function(service) {
        var options = "location=0,status=0,width=800,height=500";
        var url = "/oauth/" + service + "_connect";
        this.connect_window = window.open(url, '_blank', options);
        this.connect_window_timer = setInterval(_.bind(function() {
            console.log(["post connect window?", this.connect_window, this.connect_window.closed, this.connect_window.location]);
            try {
                if (!this.connect_window || 
                    !this.connect_window.location || 
                    this.connect_window.closed) {
                    this.post_connect({});
                }
            } catch (err) {
                this.post_connect({});
            }
        }, this), 1000);
        _gaq.push(['_trackEvent', 'reader_intro', 'Connect to ' + service.name + ' attempt']);
    },
    
    disconnect: function(service) {
        var $service = $('.NB-friends-service-'+service, this.$modal);
        $('.NB-friends-service-connect', $service).text('Disconnecting...');
        _gaq.push(['_trackEvent', 'reader_intro', 'Disconnect from ' + service.name]);
        NEWSBLUR.assets.disconnect_social_service(service, _.bind(function(data) {
            this.services = data.services;
            this.make_find_friends_and_services();
            this.make_profile_section();
            this.make_profile_tab();
        }, this));
    },
    
    post_connect: function(data) {
        console.log(["Intro post_connect", data]);
        clearInterval(this.connect_window_timer);
        $('.NB-error', this.$modal).remove();
        if (data.error) {
            var $error = $.make('div', { className: 'NB-error' }, [
                $.make('span', { className: 'NB-raquo' }, '&raquo; '),
                data.error
            ]).css({'opacity': 0});
            $('.NB-intro-services', this.$modal).append($error);
            $error.animate({'opacity': 1}, {'duration': 1000});
            this.resize();
            _gaq.push(['_trackEvent', 'reader_intro', 'Connect to service error']);
        } else {
            this.fetch_friends();
            _gaq.push(['_trackEvent', 'reader_intro', 'Connect to service success']);
        }
        NEWSBLUR.assets.preference('has_found_friends', true);
        NEWSBLUR.reader.check_hide_getting_started();
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
          NEWSBLUR.assets.preference('has_setup_feeds', true);
          NEWSBLUR.reader.check_hide_getting_started();
          this.close(_.bind(function() {
              NEWSBLUR.reader.open_dialog_after_feeds_loaded({delayed_import: this.flags.delayed_import});
          }, this));
          return;
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
      
      if (page_number == 2) {
          this.advance_import_carousel();
      }
      if (page_number == 3) {
          this.make_find_friends_and_services();
      }
      if (page_number == 4) {
          this.show_twitter_follow_buttons();
      }
      
      clearInterval(this.sync_interval);
      NEWSBLUR.assets.preference('intro_page', page_number);
      _gaq.push(['_trackEvent', 'reader_intro', 'Page ' + this.page_number]);
    },
    
    advance_import_carousel: function(page) {
        var $carousel = $('.carousel', this.$modal);
        $carousel.carousel('pause');
        console.log(["Advancing import carousel", page, !_.isNumber(page), NEWSBLUR.assets.feeds.size(), !this.options.force_import]);
        if (!_.isNumber(page)) { 
            if (NEWSBLUR.assets.feeds.size() && !this.options.force_import) {
                page = 2;
                $('.NB-intro-imports-sites', this.$modal).addClass('active');
                $('.NB-intro-import-delayed', this.$modal).hide();
            } else {
                page = 0;
                $('.NB-intro-imports-start', this.$modal).addClass('active');
            }
        }
        
        if (page >= 2) {
            $('.NB-tutorial-next-page-text', this.$modal).text('Next step ');
        }
        
        $carousel.carousel(page && parseInt(page, 10) || 0);
        $carousel.carousel('pause');
        _.defer(function() {
            $carousel.carousel(page && parseInt(page, 10) || 0);
            $carousel.carousel('pause');
        });
        this.count_feeds();
    },
    
    count_feeds: function(fake_feed_count) {
        var feed_count = fake_feed_count || NEWSBLUR.assets.feeds.size();
        
        $(".NB-intro-imports-sites h4", this.$modal).text([
            'You are subscribed to ',
            (fake_feed_count && 'at least '),
            Inflector.pluralize(' site', feed_count, true),
            '.'
        ].join(""));

        if (feed_count) {
            NEWSBLUR.reader.check_hide_getting_started();
        }
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
      NEWSBLUR.reader.load_feed_in_tryfeed_view(this.newsblur_feed.id, {'feed': this.newsblur_feed});
    },
    
    // ==========
    // = Import =
    // ==========
    
    google_reader_connect: function() {
        var options = "location=0,status=0,width=800,height=500";
        var url = "/import/authorize?modal=true";
        this.connect_window = window.open(url, '_blank', options);
        this.connect_window_timer = setInterval(_.bind(function() {
            console.log(["post connect window?", this.connect_window, this.connect_window.closed, this.connect_window.location]);
            try {
                if (!this.connect_window || 
                    !this.connect_window.location || 
                    this.connect_window.closed) {
                    this.start_import_from_google_reader({});
                }
            } catch (err) {
                this.start_import_from_google_reader({});
            }
        }, this), 1000);

        NEWSBLUR.reader.flags.importing_from_google_reader = true;
    },
    
    start_import_from_google_reader: function(data) {
        clearInterval(this.connect_window_timer);
        var $error = $('.NB-intro-gitgoogle .NB-error', this.$modal);
        var $loading = $('.NB-intro-imports-progress .NB-loading', this.$modal);
        if (data && data.error) {
            $error.show().text(data.error);
            this.advance_import_carousel(0);
        } else {
            $error.hide();
            NEWSBLUR.reader.flags.importing_from_google_reader = false;
            this.advance_import_carousel(1);
            $loading.addClass('NB-active');
            NEWSBLUR.assets.start_import_from_google_reader($.rescope(this.finish_import_from_google_reader, this));
        }
    },
    
    finish_import_from_google_reader: function() {
        var $loading = $('.NB-intro-imports-progress .NB-loading', this.$modal);
        
        NEWSBLUR.assets.load_feeds(_.bind(function() {
            $loading.removeClass('NB-active');
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
        var params = {
            url: NEWSBLUR.URLs['opml-upload'],
            type: 'POST',
            dataType: 'json',
            success: function (data, status) {
                NEWSBLUR.assets.load_feeds(function() {
                    $loading.removeClass('NB-active');
                    self.advance_import_carousel(2);
                    if (data.payload.delayed) {
                        NEWSBLUR.reader.flags.delayed_import = true;
                        self.count_feeds(data.payload.feed_count);
                        $('.NB-intro-import-delayed', self.$modal).show();
                    }
                });
                NEWSBLUR.reader.load_recommended_feed();
            },
            error: function (data, status, e) {
                self.advance_import_carousel(0);
                $loading.removeClass('NB-active');
                NEWSBLUR.log(['Error', data, status, e]);
                $error.text("There was a problem uploading your OPML file. Try e-mailing it to samuel@newsblur.com.");
                $error.slideDown(300);
            },
            cache: false,
            contentType: false,
            processData: false
        };
        if (window.FormData) {
            var formData = new FormData($file.closest('form')[0]);
            params['data'] = formData;
            
            $.ajax(params);
        } else {
            // IE9 has no FormData
            params['secureuri'] = false;
            params['fileElementId'] = 'NB-intro-upload-opml-button';
            params['dataType'] = 'json';
            
            $.ajaxFileUpload(params);
        }
        
        $file.replaceWith($file.clone());
        
        return false;
    },
    
    // ===================
    // = Stay Up To Date =
    // ===================
    
    show_twitter_follow_buttons: function() {
        $('.NB-intro-uptodate-follow', this.$modal).toggleClass('NB-intro-uptodate-twitter-inactive', !this.services.twitter.twitter_uid);
    },
    
    follow_twitter_account: function(username) {
        var $input = $('#NB-intro-uptodate-follow-'+username, this.$modal);
        var $button = $input.closest('.NB-intro-uptodate-follow');
        
        if ($input.is(':checked')) {
            $button.addClass('NB-active');
            if (this.services.twitter.twitter_uid) {
                NEWSBLUR.assets.follow_twitter_account(username);
            } else {
                window.open('http://twitter.com/'+username, '_blank');
            }
        } else {
            $button.removeClass('NB-active');
            if (this.services.twitter.twitter_uid) {
                NEWSBLUR.assets.unfollow_twitter_account(username);
            }
        }
    },
    
    subscribe_to_feed: function(feed) {
        var $input = $('#NB-intro-uptodate-follow-'+feed, this.$modal);
        var $button = $input.closest('.NB-intro-uptodate-follow');
        var blog_url = 'http://blog.newsblur.com/';
        var popular_username = 'social:popular';
        
        if ($input.is(':checked')) {
            $button.addClass('NB-active');
            if (feed == 'blog') {
                NEWSBLUR.assets.save_add_url(blog_url, "", function() {
                    NEWSBLUR.assets.load_feeds();
                }, {auto_active: false});
            } else if (feed == 'popular') {
                NEWSBLUR.assets.follow_user(popular_username, function() {
                    NEWSBLUR.app.feed_list.make_social_feeds();
                });
            }
        } else {
            $button.removeClass('NB-active');
            if (feed == 'blog') {
                NEWSBLUR.assets.delete_feed_by_url(blog_url, "", function() {
                    NEWSBLUR.assets.load_feeds();
                });
            } else if (feed == 'popular') {
                NEWSBLUR.assets.unfollow_user(popular_username, function() {
                    NEWSBLUR.app.feed_list.make_social_feeds();
                });
            }
        }
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
        $.targetIs(e, { tagSelector: '.NB-friends-autofollow-checkbox' }, function($t, $p) {
            NEWSBLUR.assets.preference('autofollow_friends', $t.is(':checked'));
        });
        $.targetIs(e, { tagSelector: '#NB-intro-uptodate-follow-newsblur' }, function($t, $p) {
            self.follow_twitter_account('newsblur');
        });
        $.targetIs(e, { tagSelector: '#NB-intro-uptodate-follow-samuelclay' }, function($t, $p) {
            self.follow_twitter_account('samuelclay');
        });
        $.targetIs(e, { tagSelector: '#NB-intro-uptodate-follow-blog' }, function($t, $p) {
            self.subscribe_to_feed('blog');
        });
        $.targetIs(e, { tagSelector: '#NB-intro-uptodate-follow-popular' }, function($t, $p) {
            self.subscribe_to_feed('popular');
        });
    }
    
});