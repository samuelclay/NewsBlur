NEWSBLUR.ReaderIntro = function(options) {
    var defaults = {
        modal_container_class: "NB-full-container"
    };
    var intro_page = NEWSBLUR.assets.preference('intro_page');
    
    _.bindAll(this, 'close', 'post_connect');
    this.options = $.extend({
      'page_number': intro_page && _.isNumber(intro_page) && intro_page <= 4 ? intro_page : 1
    }, defaults, options);
    this.services = {
        'twitter': {},
        'facebook': {}
    };
    this.flags = {};
    this.autofollow = true;
    this.chosen_categories = [];
    
    this.page_number = this.options.page_number;
    this.slider_value = 0;
    this.intervals = {};
    this.sync_checks = 0;
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
        this.fetch_categories();
        this.fetch_friends();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },
        
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-intro NB-modal' }, [
            $.make('div', { className: 'NB-modal-page' }, [
                $.make('span', { className: 'NB-modal-page-text' }),
                $.make('span', { className: 'NB-modal-loading NB-spinner'})
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                'Welcome to NewsBlur',
                $.make('div', { className: 'NB-divider' })
            ]),
            $.make('img', { className: 'NB-intro-spinning-logo', src: NEWSBLUR.Globals.MEDIA_URL + 'img/logo_512.png' }),
            $.make('div', { className: 'NB-page NB-page-1' }, [
                $.make('h4', { className: 'NB-page-1-started' }, "So much time and so little to do. Strike that! Reverse it.")
            ]),
            $.make('div', { className: 'NB-page NB-page-2' }, [
                $.make('div', { className: 'NB-intro-imports NB-intro-imports-start'}, [
                    $.make('div', { className: 'NB-page-2-started' }, [
                        $.make('h4', "Let's get some sites to read."),
                        $.make('div', { className: 'NB-intro-import-starred-message' })
                    ]),
                    $.make('div', { className: 'NB-intro-module-containers' }, [
                        $.make('div', { className: 'NB-intro-module-container NB-left' }, [
                            $.make('h3', { className: 'NB-module-content-header' }, 'Choose categories'),
                            $.make('div', { className: 'NB-intro-module NB-intro-categories-container' }, [
                                $.make('div', { className: "NB-intro-categories-loader" }),
                                $.make('div', { className: "NB-intro-categories" })
                            ])
                        ]),
                        $.make('div', { className: 'NB-intro-module-container NB-right' }, [
                            $.make('h3', { className: 'NB-module-content-header' }, 'Upload'),
                            $.make('div', { className: 'NB-intro-module NB-intro-import-opml' }, [
                                $.make('div', { className: 'NB-carousel'}, [
                                    $.make('div', { className: 'NB-carousel-inner NB-intro-imports' }, [
                                        $.make('div', { className: 'NB-carousel-item NB-intro-imports-start' }, [
                                            $.make('h3', 'OPML'),
                                            $.make('form', { method: 'post', enctype: 'multipart/form-data', encoding: 'multipart/form-data', className: 'NB-opml-upload-form' }, [
                                                $.make('div', { href: '#', className: 'NB-intro-upload-opml NB-modal-submit-green NB-modal-submit-button' }, [
                                                    'Upload OPML File',
                                                    $.make('input', { type: 'file', name: 'file', id: 'NB-intro-upload-opml-button', className: 'NB-intro-upload-opml-button' })
                                                ])
                                            ])
                                        ]),
                                        $.make('div', { className: 'NB-carousel-item NB-intro-imports-progress' }, [
                                            $.make('div', { className: 'NB-page-2-importing' }, "Importing your sites..."),
                                            $.make('div', { className: 'NB-loading' })
                                        ]),
                                        $.make('div', { className: 'NB-carousel-item NB-intro-imports-sites' }, [
                                            $.make('h6', { className: 'NB-intro-import-message' }),
                                            $.make('div', { className: 'NB-intro-import-delayed' }, [
                                                'There are too many sites and stories to process. ',
                                                'You will be emailed within a minute or three.'
                                            ]),
                                            $.make('div', { className: 'NB-intro-import-restart NB-modal-submit-grey NB-modal-submit-button' }, [
                                                '&laquo; Re-upload your sites'
                                            ]),
                                            $.make('div', { className: 'NB-intro-bookmarklet NB-intro-section NB-intro-import-container' }, [
                                                $.make('h3', { className: 'NB-module-content-header' }, 'Install'),
                                                $.make('div', { className: 'NB-intro-import NB-intro-module' }, [
                                                    NEWSBLUR.generate_bookmarklet(),
                                                    $.make('div', { className: 'NB-intro-bookmarklet-info' }, 'Drag this bookmarklet into your bookmarks bar')
                                                ])
                                            ])
                                        ])
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-page NB-page-3' }, [
                $.make('h4', { className: 'NB-page-3-started' }, "Connect with friends"),
                $.make('div', { className: 'NB-intro-services' })
            ]),
            $.make('div', { className: 'NB-page NB-page-4' }, [
                $.make('h4', { className: 'NB-page-4-started' }, "Keep up-to-date with NewsBlur"),
                $.make('table', { className: 'NB-intro-follows', cellpadding: 0, cellspacing: 0 }, [
                    $.make('tr', [
                        $.make('td', { className: 'NB-intro-uptodate-follow NB-intro-uptodate-follow-twitter' }, [
                            $.make('input', { type: 'checkbox', id: 'NB-intro-uptodate-follow-samuelclay' }),
                            $.make('label', { 'for': 'NB-intro-uptodate-follow-samuelclay' }, [
                                $.make('img', { src: "https://s3.amazonaws.com/static.newsblur.com/blog/Campeche%20Steps%20resized.jpeg", style: 'border-color: #505050;' }),
                                $.make('span', '@samuelclay')
                            ]),
                            $.make('iframe', { allowtransparency: "true", frameborder: "0", scrolling: "no", src: "//platform.twitter.com/widgets/follow_button.html?screen_name=samuelclay", width: 260, height: 20 })
                        ]),
                        $.make('td', { className: 'NB-intro-uptodate-follow NB-intro-uptodate-follow-twitter' }, [
                            $.make('input', { type: 'checkbox', id: 'NB-intro-uptodate-follow-newsblur' }),
                            $.make('label', { 'for': 'NB-intro-uptodate-follow-newsblur' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/logo_128.png', style: 'border-color: #505050;' }),
                                $.make('span', '@newsblur')
                            ]),
                            $.make('iframe', { allowtransparency: "true", frameborder: "0", scrolling: "no", src: "//platform.twitter.com/widgets/follow_button.html?screen_name=newsblur", width: 260, height: 20 })
                        ])
                    ]),
                    $.make('tr', { className: 'NB-intro-uptodate-subscribe' }, [
                        $.make('td', { className: 'NB-intro-uptodate-follow' }, [
                            $.make('div', [
                                $.make('img', { src: '/media/img/favicon.png' }),
                                'Popular Shared Stories'
                            ]),
                            $.make('div', { className: 'NB-intro-uptodate-follow-popular NB-modal-submit-green NB-modal-submit-button' }, [
                                'Subscribe'
                            ]),
                            $.make('div', { className: 'NB-subscribed' }, "Subscribed")
                        ]),
                        $.make('td', { className: 'NB-intro-uptodate-follow' }, [
                            $.make('div', [
                                $.make('img', { src: '/media/img/favicon.png' }),
                                'The NewsBlur Blog'
                            ]),
                            $.make('div', { className: 'NB-intro-uptodate-follow-blog NB-modal-submit-green NB-modal-submit-button' }, [
                                'Subscribe'
                            ]),
                            $.make('div', { className: 'NB-subscribed' }, "Subscribed")
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-intro-section' }, [
                    "You're ready to go! Hope you enjoy NewsBlur."
                ])
            ]),
            $.make('div', { className: 'NB-modal-submit-bottom' }, [
              $.make('div', { className: 'NB-page-next NB-modal-submit-button NB-modal-submit-green NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-tutorial-next-page-text' }, "Let's Get Started "),
                $.make('span', { className: 'NB-raquo' }, '&raquo;')
              ])
            ])
        ]);
        
        if (this.options.force_import) {
            // this.$modal.addClass('NB-intro-import-only');
        }
    },
    
    // ==============
    // = Categories =
    // ==============
    
    fetch_categories: function(callback) {
        $('.NB-intro-categories-loader', this.$modal).addClass('NB-active');
        NEWSBLUR.assets.fetch_categories(_.bind(function(data) {
            this.categories = data.categories;
            this.category_feeds = data.feeds;
            this.make_categories();
            callback && callback();
        }, this), _.bind(function(data) {
            console.log(['Categories fetch error', data]);
        }, this));
    },
    
    make_categories: function() {
        $('.NB-intro-categories-loader', this.$modal).removeClass('NB-active');

        var $categories = $(".NB-intro-categories", this.$modal);
        var categories = _.map(this.categories, _.bind(function(category) {
            var $feeds = _.compact(_.map(category.feed_ids, _.bind(function(feed_id) {
                var feed = this.category_feeds[feed_id];
                if (!feed) return;
                feed = new NEWSBLUR.Models.Feed(feed);
                var border = feed.get('favicon_color') || "707070";
                return $.make("div", { className: "NB-category-feed", style: "border-left: 4px solid #" + border + "; border-right: 4px solid #" + border }, [
                    $.make('img', { className: 'NB-category-feed-favicon', src: $.favicon(feed) }),
                    $.make('div', { className: 'NB-category-feed-title' }, feed.get('feed_title'))
                ]);
            }, this)));
            var $category = $.make('div', { className: 'NB-category' }, [
                $.make('div', { className: 'NB-category-title NB-modal-submit-grey NB-modal-submit-button' }, [
                    $.make('div', { className: 'NB-checkmark' }),
                    category.title
                ]),
                $.make('div', { className: 'NB-category-feeds' }, $feeds)
            ]).data('category', category.title);
            return $category;
        }, this));
        
        $categories.html($.make('div', categories));
    },
    
    toggle_category: function(category, $category) {
        var on = _.contains(this.chosen_categories, category);
        if (on) {
            this.chosen_categories = _.without(this.chosen_categories, category);
        } else {
            this.chosen_categories.push(category);
        }
        $category.toggleClass('NB-active', !on);
        $(".NB-category-title", $category).toggleClass('NB-modal-submit-grey', on)
                                          .toggleClass('NB-modal-submit-green', !on);

        if (this.chosen_categories.length) {
            NEWSBLUR.assets.preference('has_setup_feeds', true);
            NEWSBLUR.reader.check_hide_getting_started();
            $('.NB-tutorial-next-page-text', this.$modal).text('Next step ');
        }
    },
    
    submit_categories: function() {
        if (this.chosen_categories.length) {
            NEWSBLUR.assets.subscribe_to_categories(this.chosen_categories, function() {
                NEWSBLUR.assets.load_feeds();
            });
        }
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
        }, this), _.bind(function(data) {
            console.log(['Friends fetch error', data]);
        }, this));
    },
    
    make_find_friends_and_services: function() {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        var $services = $('.NB-intro-services', this.$modal).empty();
        var service_syncing = false;
        
        _.each(['twitter', 'facebook'], _.bind(function(service) {
            var $service;
            if (this.services && this.services[service][service+'_uid'] && !this.services[service].syncing) {
                $service = $.make('div', { className: 'NB-intro-module-container NB-friends-service NB-connected NB-friends-service-'+service }, [
                    $.make('h3', { className: 'NB-module-content-header' }, _.string.capitalize(service)),
                    $.make('div', { className: 'NB-intro-module NB-intro-module-'+service }, [
                        $.make('h3', [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_big.png', width: 44, height: 44 })
                        ]),
                        $.make('div', { className: 'NB-friends-service-connected' }, [
                            'Connected'
                        ])
                    ])
                ]);
            } else {
                var syncing = this.services && this.services[service] && this.services[service].syncing;
                if (syncing) service_syncing = true;
                
                $service = $.make('div', { className: 'NB-intro-module-container NB-friends-service NB-friends-service-'+service + (syncing ? ' NB-friends-service-syncing' : '') }, [
                    $.make('h3', { className: 'NB-module-content-header' }, _.string.capitalize(service)),
                    $.make('div', { className: 'NB-intro-module NB-intro-module-'+service }, [
                        $.make('h3', [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/' + service + '_big.png', width: 44, height: 44 })
                        ]),
                        $.make('div', { className: 'NB-friends-service-connect NB-modal-submit-button ' + (syncing ? 'NB-modal-submit-grey' : 'NB-modal-submit-green') }, [
                            (syncing ? 'Fetching...' : 'Find ' + _.string.capitalize(service) + ' Friends')
                        ])
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
            clearTimeout(this.sync_interval);
            this.sync_checks += 1;
            this.sync_interval = _.delay(_.bind(function() {
                this.fetch_friends();
            }, this), this.sync_checks * 1000);
        }
    },
    
    connect: function(service) {
        var options = "location=0,status=0,width=800,height=500";
        var url = "/oauth/" + service + "_connect";
        this.sync_checks = 0;
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
        // _gaq.push(['_trackEvent', 'reader_intro', 'Connect to ' + service.name + ' attempt']);
        
        NEWSBLUR.assets.preference('has_found_friends', true);
        NEWSBLUR.reader.check_hide_getting_started();
    },
    
    disconnect: function(service) {
        var $service = $('.NB-friends-service-'+service, this.$modal);
        $('.NB-friends-service-connect', $service).text('Disconnecting...');
        // _gaq.push(['_trackEvent', 'reader_intro', 'Disconnect from ' + service.name]);
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
        $(".NB-note", this.$modal).hide();
        if (data.error) {
            var $error = $.make('div', { className: 'NB-error' }, [
                $.make('span', { className: 'NB-raquo' }, '&raquo; '),
                data.error
            ]).css({'opacity': 0});
            $('.NB-intro-services', this.$modal).append($error);
            $error.animate({'opacity': 1}, {'duration': 1000});
            this.resize();
            // _gaq.push(['_trackEvent', 'reader_intro', 'Connect to service error']);
        } else {
            this.fetch_friends();
            // _gaq.push(['_trackEvent', 'reader_intro', 'Connect to service success']);
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
          NEWSBLUR.reader.check_hide_getting_started();
          NEWSBLUR.assets.preference('has_setup_feeds', true);
          this.close(_.bind(function() {
              NEWSBLUR.reader.open_dialog_after_feeds_loaded({
                  delayed_import: this.flags.delayed_import,
                  finished_intro: true
              });
          }, this));
          return;
      } else if (page_number == 1) {
        $('.NB-tutorial-next-page-text', this.$modal).text("Let's Get Started ");
      } else {
        $('.NB-tutorial-next-page-text', this.$modal).text('Skip this step ');
      }
      $('.NB-page', this.$modal).css({'display': 'none'});
      $('.NB-page-'+this.page_number, this.$modal).css({'display': 'block'});
      $('.NB-modal-page-text', this.$modal).html($.make('div', [
        'Step ',
        $.make('b', this.page_number),
        ' of ',
        $.make('b', page_count)
      ]));
      if (page_number > 1) {
          $('.NB-intro-spinning-logo', this.$modal).css({'top': 12, 'left': 12, 'width': 48, 'height': 48});
          // $('.NB-modal-title', this.$modal).css({'paddingLeft': 42});
      }
      
      if (page_number == 2) {
          this.advance_import_carousel();
      }
      if (page_number == 3) {
          this.submit_categories();
          this.make_find_friends_and_services();
      }
      if (page_number == 4) {
          this.show_twitter_follow_buttons();
      }
      
      clearTimeout(this.sync_interval);
      NEWSBLUR.assets.preference('intro_page', page_number);
      // _gaq.push(['_trackEvent', 'reader_intro', 'Page ' + this.page_number]);
    },
    
    advance_import_carousel: function(page, options) {
        options = options || {};
        var $carousel = $('.NB-carousel-inner', this.$modal);

        if (page >= 2) {
            NEWSBLUR.assets.preference('has_setup_feeds', true);
            NEWSBLUR.reader.check_hide_getting_started();
            $('.NB-tutorial-next-page-text', this.$modal).text('Next step ');
        }
        
        $carousel.animate({'left': (-1 * page * 100) + '%'}, {
            'queue': false,
            'easing': 'easeInOutQuint',
            'duration': 1000
        });
        this.count_feeds(options);
    },
    
    count_feeds: function(options) {
        options = options || {};
        var feed_count = options.fake_count || NEWSBLUR.assets.feeds.size();
        var starred_count = options.starred_count || NEWSBLUR.assets.starred_count;
        
        if (feed_count) {
            $(".NB-page-2-started h4", this.$modal).text([
                'You are subscribed to ',
                (options.fake_count && 'at least '),
                Inflector.pluralize(' site', feed_count, true),
                '.'
            ].join(""));
        }

        if (starred_count) {
            var $info = $(".NB-page-2-started .NB-intro-import-starred-message", this.$modal);
            $info.text([
                "And you have ",
                Inflector.pluralize(' saved story', starred_count, true),
                ". "
            ].join("")).show();
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
                $logo.animate({'top': 12, 'left': 12, 'width': 48, 'height': 48}, {
                    'duration': 1160,
                    'easing': 'easeInOutCubic',
                    'complete': function() {
                        $page2.css({'opacity': 0});
                        self.page(2);
                        $page2.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeInOutQuad'});
                        $submit.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeInOutQuad'});
                    }
                });
                // $title.animate({'paddingLeft': 42}, {'duration': 1100, 'easing': 'easeInOutQuart'});
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
    
    handle_opml_upload: function() {
        var self = this;
        var $loading = $('.NB-intro-imports-progress .NB-loading', this.$modal);
        var $file = $('.NB-intro-upload-opml-button', this.$modal);
        $loading.addClass('NB-active');

        this.advance_import_carousel(1);
        
        // NEWSBLUR.log(['Uploading']);
        var params = {
            url: NEWSBLUR.URLs['opml-upload'],
            type: 'POST',
            dataType: 'json',
            success: function (data, status) {
                NEWSBLUR.assets.load_feeds(function() {
                    console.log(["opml upload", data, status]);
                    $loading.removeClass('NB-active');
                    self.advance_import_carousel(2);
                    if (data.payload.delayed) {
                        NEWSBLUR.reader.flags.delayed_import = true;
                        self.count_feeds({fake_count: data.payload.feed_count});
                        $('.NB-intro-import-delayed', self.$modal).show();
                        $('.NB-intro-import-restart', self.$modal).hide();
                        $('.NB-intro-import-message', self.$modal).hide();
                    } else if (data.code < 0) {
                        $('.NB-intro-import-delayed', self.$modal).hide();
                        $('.NB-intro-import-restart', self.$modal).show();
                        $('.NB-intro-import-message', self.$modal).addClass('NB-error').show().text(data.message);
                    } else {
                        $('.NB-intro-import-message', self.$modal).text("All done!").removeClass('NB-error').show();
                        $('.NB-intro-import-delayed', self.$modal).hide();
                        $('.NB-intro-import-restart', self.$modal).show();
                    }
                });
                NEWSBLUR.reader.load_recommended_feed();
            },
            error: function (data, status, e) {
                self.advance_import_carousel(2);
                $loading.removeClass('NB-active');
                NEWSBLUR.log(['Error', data, status, e]);
                $('.NB-intro-import-message', self.$modal).text("There was a problem uploading your OPML file.").addClass('NB-error').css('display', 'block');
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
        var $button = $('.NB-intro-uptodate-follow-'+feed);
        var $parent = $button.closest(".NB-intro-uptodate-follow");
        var blog_url = 'http://blog.newsblur.com/rss';
        var popular_username = 'social:popular';
        console.log(["subscribe_to_feed", feed, $button, $parent]);
        $parent.addClass('NB-active');
        if (feed == 'blog') {
            NEWSBLUR.assets.save_add_url(blog_url, "", function() {
                NEWSBLUR.assets.load_feeds();
            }, {auto_active: false, skip_fetch: true});
            
        } else if (feed == 'popular') {
            NEWSBLUR.assets.follow_user(popular_username, function() {
                NEWSBLUR.app.feed_list.make_social_feeds();
            });
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
        
        $.targetIs(e, { tagSelector: '.NB-starredimport-button' }, function($t, $p) {
            e.preventDefault();
            // self.google_reader_connect({'starred_only': true});
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
        
        $.targetIs(e, { tagSelector: '.NB-intro-uptodate-follow-blog' }, function($t, $p) {
            self.subscribe_to_feed('blog');
        });
        $.targetIs(e, { tagSelector: '.NB-intro-uptodate-follow-popular' }, function($t, $p) {
            self.subscribe_to_feed('popular');
        });
        $.targetIs(e, { tagSelector: '.NB-category' }, function($t, $p) {
            var category = $t.data('category');
            self.toggle_category(category, $t);
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
    }
    
});
