(function($) {
    
    NEWSBLUR.Reader = function() {
        var self = this;
        
        // ===========
        // = Globals =
        // ===========
        
        this.model = NEWSBLUR.AssetModel.reader();
        this.story_view = 'page';
        this.$s = {
            $body: $('body'),
            $feed_list: $('#feed_list'),
            $story_titles: $('#story_titles'),
            $content_pane: $('.content-pane'),
            $story_taskbar: $('#story_taskbar'),
            $story_pane: $('#story_pane .NB-story-pane-container'),
            $feed_view: $('.NB-feed-story-view'),
            $feed_stories: $('.NB-feed-stories'),
            $feed_iframe: $('.NB-feed-iframe'),
            $story_iframe: $('.NB-story-iframe'),
            $intelligence_slider: $('.NB-intelligence-slider'),
            $mouse_indicator: $('#mouse-indicator'),
            $feed_link_loader: $('#NB-feeds-list-loader'),
            $feeds_progress: $('#NB-progress'),
            $dashboard: $('.NB-feeds-header-dashboard'),
            $river_header: $('.NB-feeds-header-river'),
            $starred_header: $('.NB-feeds-header-starred'),
            $tryfeed_header: $('.NB-feeds-header-tryfeed'),
            $taskbar: $('.taskbar_nav'),
            $feed_floater: $('.NB-feed-story-view-floater')
        };
        this.flags = {
            'feed_view_images_loaded': {},
            'bouncing_callout': false,
            'has_unfetched_feeds': false,
            'count_unreads_after_import_working': false,
            'import_from_google_reader_working': false,
            'favicons_downloaded': false
        };
        this.locks = {};
        this.counts = {
            'feature_page': 0,
            'unfetched_feeds': 0,
            'fetched_feeds': 0,
            'page_fill_outs': 0,
            'recommended_feed_page': 0
        };
        this.cache = {
            'iframe_stories': {},
            'feed_view_stories': {},
            'iframe_story_positions': {},
            'feed_view_story_positions': {},
            'iframe_story_positions_keys': [],
            'feed_view_story_positions_keys': [],
            'river_feeds_with_unreads': [],
            'mouse_position_y': parseInt(this.model.preference('lock_mouse_indicator'), 10),
            '$feed_in_feed_list': {},
            '$feed_counts_in_feed_list': {}
        };
        this.layout = {};
        this.constants = {
          FEED_REFRESH_INTERVAL: (1000 * 60) * 1, // 1 minute
          FILL_OUT_PAGES: 8,
          RIVER_STORIES_FOR_STANDARD_ACCOUNT: 12
        };
        
        // ==================
        // = Event Handlers =
        // ==================
        
        $(window).bind('resize.reader', _.throttle($.rescope(this.resize_window, this), 1000));
        this.$s.$body.bind('dblclick.reader', $.rescope(this.handle_dblclicks, this));
        this.$s.$body.bind('click.reader', $.rescope(this.handle_clicks, this));
        this.$s.$body.live('contextmenu.reader', $.rescope(this.handle_rightclicks, this));
        this.$s.$story_titles.scroll($.rescope(this.handle_scroll_story_titles, this));
        this.$s.$feed_stories.scroll($.rescope(this.handle_scroll_feed_view, this));
        this.$s.$feed_stories.bind('mousemove', $.rescope(this.handle_mousemove_feed_view, this));
        this.handle_keystrokes();
        
        // ==================
        // = Initialization =
        // ==================
        
        this.load_javascript_elements_on_page();
        this.unload_feed_iframe();
        this.unload_story_iframe();
        this.apply_resizable_layout();
        this.add_body_classes();
        if (NEWSBLUR.Flags['start_import_from_google_reader']) {
          this.start_import_from_google_reader();
        } else {
          this.load_feeds();
        }
        this.cornerize_buttons();
        this.setup_feed_page_iframe_load();
        this.load_intelligence_slider();
        this.handle_mouse_indicator_hover();
        this.position_mouse_indicator();
        this.handle_login_and_signup_forms();
        this.iframe_buster_buster();
        this.apply_story_styling();
        this.apply_tipsy_titles();
        this.load_recommended_feeds();
        this.setup_dashboard_graphs();
        this.setup_howitworks_hovers();
        this.load_url_next_param();
    };

    NEWSBLUR.Reader.prototype = {
       
        // ========
        // = Page =
        // ========
        
        load_javascript_elements_on_page: function() {
          $('.NB-javascript').removeClass('NB-javascript');
        },
        
        resize_window: function() {
            var flag;
            var view = this.story_view;
            
            if (this.flags['page_view_showing_feed_view']) {
                view = 'feed';
                flag = 'page';
            } else if (this.flags['feed_view_showing_story_view']) {
                view = 'story';
                flag = 'story';
            }
            
            this.flags.scrolling_by_selecting_story_title = true;
            clearTimeout(this.locks.scrolling);
            this.locks.scrolling = _.delay(_.bind(function() {
                this.flags.scrolling_by_selecting_story_title = false;
            }, this), 1000);
            
            this.switch_taskbar_view(view, flag);
            this.check_story_titles_last_story();
            this.flags.fetch_story_locations_in_feed_view = this.flags.fetch_story_locations_in_feed_view ||
                                                            _.throttle(_.bind(this.fetch_story_locations_in_feed_view, this), 2000);
            this.flags.fetch_story_locations_in_feed_view();
        },
        
        apply_resizable_layout: function(refresh) {
            var story_anchor = this.model.preference('story_pane_anchor');
            var right_pane_hidden = !$('.right-pane').is(':visible');
            
            if (refresh) {
                this.layout.contentLayout && this.layout.contentLayout.destroy();
                this.layout.rightLayout && this.layout.rightLayout.destroy();
                this.layout.leftCenterLayout && this.layout.leftCenterLayout.destroy();
                this.layout.leftLayout && this.layout.leftLayout.destroy();
                this.layout.outerLayout && this.layout.outerLayout.destroy();

                var feed_stories_bin = $.make('div').append(this.$s.$feed_stories.children());
                var story_titles_bin = $.make('div').append(this.$s.$story_titles.children());
            }
            
            $('.right-pane').removeClass('NB-story-pane-west')
                            .removeClass('NB-story-pane-north')
                            .removeClass('NB-story-pane-south')
                            .addClass('NB-story-pane-'+story_anchor);
                            
            this.layout.outerLayout = this.$s.$body.layout({ 
                closable: true,
                center__paneSelector:   ".right-pane",
                west__paneSelector:     ".left-pane",
                west__size:             this.model.preference('feed_pane_size'),
                west__onresize_end:     $.rescope(this.save_feed_pane_size, this),
                spacing_open:           4,
                resizerDragOpacity:     0.6,
                resizeWhileDragging:    true,
                enableCursorHotkey:     false
            }); 
            
            this.layout.leftLayout = $('.left-pane').layout({
                closable:               false,
                resizeWhileDragging:    true,
                fxName:                 "scale",
                fxSettings:             { duration: 500, easing: "easeInOutQuint" },
                north__paneSelector:    ".left-north",
                north__size:            18,
                north__resizeable:      false,
                north__spacing_open:    0,
                center__paneSelector:   ".left-center",
                center__resizable:      false,
                south__paneSelector:    ".left-south",
                south__size:            31,
                south__resizable:       false,
                south__spacing_open:    0,
                enableCursorHotkey:     false
            });
            
            this.layout.leftCenterLayout = $('.left-center').layout({
                closable:               false,
                slidable:               false, 
                resizeWhileDragging:    true,
                center__paneSelector:   ".left-center-content",
                center__resizable:      false,
                south__paneSelector:    ".left-center-footer",
                south__size:            'auto',
                south__resizable:       false,
                south__slidable:        true,
                south__spacing_open:    0,
                south__spacing_closed:  0,
                south__closable:        true,
                south__initClosed:      true,
                fxName:                 "slide",
                fxSpeed:                 1000,
                fxSettings:             { duration: 1000, easing: "easeInOutQuint" },
                enableCursorHotkey:     false
            });
            
            var rightLayoutOptions = { 
                resizeWhileDragging:    true,
                center__paneSelector:   ".content-pane",
                spacing_open:           story_anchor == 'west' ? 4 : 10,
                resizerDragOpacity:     0.6,
                enableCursorHotkey:     false
            };
            rightLayoutOptions[story_anchor+'__paneSelector'] = '.right-north';
            rightLayoutOptions[story_anchor+'__size'] = this.model.preference('story_titles_pane_size');
            rightLayoutOptions[story_anchor+'__onresize_end'] = $.rescope(this.save_story_titles_pane_size, this);
            this.layout.rightLayout = $('.right-pane').layout(rightLayoutOptions); 

            var contentLayoutOptions = { 
                resizeWhileDragging:    true,
                center__paneSelector:   ".content-center",
                spacing_open:           0,
                resizerDragOpacity:     0.6,
                enableCursorHotkey:     false
            };
            if (story_anchor == 'west') {
                contentLayoutOptions['north__paneSelector'] = '.content-north';
                contentLayoutOptions['north__size'] = 30;
            } else {
                contentLayoutOptions[story_anchor+'__paneSelector'] = '.content-north';
                contentLayoutOptions[story_anchor+'__size'] = 30;
            }
            this.layout.contentLayout = this.$s.$content_pane.layout(contentLayoutOptions); 

            if (!refresh) {
                $('.right-pane').hide();
            } else {
                this.$s.$feed_stories.append(feed_stories_bin.children());
                this.$s.$story_titles.append(story_titles_bin.children());
                this.resize_window();
                if (right_pane_hidden) {
                    $('.right-pane').hide();
                }
            }
        },
        
        apply_tipsy_titles: function() {
            if (this.model.preference('show_tooltips')) {
                $('.NB-taskbar-sidebar-toggle-close').tipsy({
                    gravity: 'se',
                    delayIn: 375
                });
                $('.NB-taskbar-sidebar-toggle-open').tipsy({
                    gravity: 'sw',
                    delayIn: 375
                });
                $('.NB-task-add').tipsy({
                    gravity: 'sw',
                    delayIn: 375
                });
                $('.NB-task-manage').tipsy({
                    gravity: 's',
                    delayIn: 375
                });
            } else {
                $('.NB-taskbar-sidebar-toggle-close').tipsy('disable');
                $('.NB-taskbar-sidebar-toggle-open').tipsy('disable');
                $('.NB-task-add').tipsy('disable');
                $('.NB-task-manage').tipsy('disable');
            }
        },
        
        save_feed_pane_size: function(w, pane, $pane, state, options, name) {
            var feed_pane_size = state.size;
            
            $('#NB-splash').css('left', feed_pane_size);
            this.flags.set_feed_pane_size = this.flags.set_feed_pane_size || _.debounce( _.bind(function() {
                var feed_pane_size = this.layout.outerLayout.state.west.size;
                this.model.preference('feed_pane_size', feed_pane_size);
                this.flags.set_feed_pane_size = null;
            }, this), 1000);
            this.flags.set_feed_pane_size();
        },
        
        save_story_titles_pane_size: function(w, pane, $pane, state, options, name) {
            this.flags.scrolling_by_selecting_story_title = true;
            clearTimeout(this.locks.scrolling);
            
            var offset = 0;
            if (this.story_view == 'feed') {
                offset = this.$s.$feed_iframe.width();
            } else if (this.story_view == 'story') {
                offset = 2 * this.$s.$feed_iframe.width();
            }
            this.$s.$story_pane.css('left', -1 * offset);
            
            this.flags.set_story_titles_size = this.flags.set_story_titles_size || _.debounce( _.bind(function() {
                var story_titles_size = this.layout.rightLayout.state[this.model.preference('story_pane_anchor')].size;
                this.model.preference('story_titles_pane_size', story_titles_size);
                this.flags.set_story_titles_size = null;
                this.locks.scrolling = _.delay(_.bind(function() {
                    this.flags.scrolling_by_selecting_story_title = false;
                }, this), 100);
            }, this), 1000);
            this.flags.set_story_titles_size();
            
            this.flags.resize_window = this.flags.resize_window || _.debounce( _.bind(function() {
                this.resize_window();
                this.flags.resize_window = null;
            }, this), 10);
            this.flags.resize_window();
            
        },
        
        cornerize_buttons: function() {
            $('.button').corner();
        },
        
        add_body_classes: function() {
            this.$s.$body.toggleClass('NB-is-premium',       NEWSBLUR.Globals.is_premium);
            this.$s.$body.toggleClass('NB-is-anonymous',     NEWSBLUR.Globals.is_anonymous);
            this.$s.$body.toggleClass('NB-is-authenticated', NEWSBLUR.Globals.is_authenticated);
        },
        
        hide_splash_page: function() {
            var self = this;
            $('.right-pane').show();
            $('#NB-splash').hide();
            $('.NB-splash-info').hide();
            $('#NB-splash-overlay').hide();
            this.$s.$body.layout().resizeAll();
            this.$s.$dashboard.addClass('NB-active');
            
            if (NEWSBLUR.Globals.is_anonymous) {
                this.setup_ftux_signup_callout();
            }
        },
        
        show_splash_page: function() {
            this.reset_feed();
            this.unload_feed_iframe();
            this.unload_story_iframe();
            this.mark_feed_as_selected(null, null);
            $('.right-pane').hide();
            $('.NB-splash-info').show();
            $('#NB-splash').show();
            $('#NB-splash-overlay').show();
            this.$s.$dashboard.removeClass('NB-active');
        },
        
        iframe_buster_buster: function() {
            var self = this;
            var prevent_bust = 0;
            window.onbeforeunload = function() { 
              prevent_bust++;
            };
            clearInterval(this.locks.iframe_buster_buster);
            this.locks.iframe_buster_buster = setInterval(function() {
                if (prevent_bust > 0) {
                    prevent_bust -= 2;
                    if (!self.flags['iframe_view_loaded'] && 
                        !self.flags['iframe_view_not_busting'] && 
                        _.contains(['page', 'story'], self.story_view) && 
                        self.active_feed) {
                      $('.task_view_feed').click();
                      $('.NB-feed-frame').attr('src', '');
                      window.top.location = '/reader/buster';
                    }
                }
            }, 1);
        },

        add_url_from_querystring: function() {
            if (this.flags['added_url_from_querystring']) return;
            
            var url = $.getQueryString('url');
            this.flags['added_url_from_querystring'] = true;

            if (url) {
                this.open_add_feed_modal({url: url});
            }
        },
        
        load_url_next_param: function() {
            var next = $.getQueryString('next');
            if (next == 'optout') {
                this.open_account_modal({'animate_email': true});
            } else if (next == 'goodies') {
                this.open_goodies_modal();
            } else if (next == 'password') {
                this.open_account_modal({'change_password': true});
            }
            
            if (window.history.replaceState) {
                window.history.replaceState({}, null, '/');
            }
        },
        
        animate_progress_bar: function($bar, seconds, percentage) {
            var self = this;
            percentage = percentage || 0;
            seconds = parseFloat(Math.max(1, parseInt(seconds, 10)), 10);
            
            if (percentage > 90) {
                time = seconds / 5;
            } else if (percentage > 80) {
                time = seconds / 12;
            } else if (percentage > 70) {
                time = seconds / 30;
            } else if (percentage > 60) {
                time = seconds / 80;
            } else if (percentage > 50) {
                time = seconds / 120;
            } else if (percentage > 40) {
                time = seconds / 160;
            } else if (percentage > 30) {
                time = seconds / 200;
            } else if (percentage > 20) {
                time = seconds / 300;
            } else if (percentage > 10) {
                time = seconds / 400;
            } else {
                time = seconds / 500;
            }
            
            if (percentage <= 100) {
                this.locks['animate_progress_bar'] = setTimeout(function() {
                    percentage += 1;
                    $bar.progressbar({value: percentage});
                    self.animate_progress_bar($bar, seconds, percentage);
                }, time * 1000);
            }
        },
        
        // =======================
        // = Getters and Finders =
        // =======================
        
        get_current_story_from_story_titles: function($feed_view_stories) {
            var $feed_view = this.$s.$feed_view;
            var $feed_view_stories = $feed_view_stories || $(".NB-feed-story", $feed_view);
            var story = this.active_story;
            var $current_story;
            
            if (story) {
                $feed_view_stories.each(function() {
                  if ($(this).data('story') == story.id) {
                      $current_story = $(this);
                      return false;
                  }
                });
            }
            
            return $current_story;
        },
        
        get_current_story_id: function() {
            var $story = this.get_current_story_from_story_titles();
            
            return $story && $story.data('story_id');
        },
        
        find_feed_in_feed_list: function(feed_id) {
            if (_.contains(this.cache.$feed_in_feed_list, feed_id)) {
                return this.cache.$feed_in_feed_list[feed_id];
            }
            
            var $feed_list = this.$s.$feed_list;
            var $feeds = $([]);
            
            $('.feed', $feed_list).each(function() {
                if (parseInt($(this).attr('data-id'), 10) == feed_id) {
                    $feeds.push($(this).get(0));
                }
            });
            
            this.cache.$feed_in_feed_list[feed_id] = $feeds;
            
            return $feeds;
        },
        
        find_folder_in_feed_list: function(folder_name) {
            var $feed_list = this.$s.$feed_list;
            var $folders = $([]);
            $('.folder_title_text', $feed_list).each(function() {
                if ($(this).text() == folder_name) {
                    $folders.push($(this).parents('li.folder').eq(0)[0]);
                }
            });
            
            return $folders;
        },
        
        find_story_in_story_titles: function(story_id) {
            var story = this.model.get_story(story_id);
            var $stories = $('.story', this.$s.$story_titles);
            var $story_title;
            
            if (story) {
                $stories.each(function() {
                    var $this = $(this);
                    if ($this.data('story_id') == story.id) {
                        $story_title = $this;
                        // NEWSBLUR.log(['Finding story in story titles', $this, story]);
                        return false;
                    }
                });
            }
            
            return $story_title;
        },
        
        find_story_in_feed_view: function(story) {
            if (!story) return;
            
            var $feed_view = this.$s.$feed_view;
            var $stories = $('.NB-feed-story', $feed_view);
            var $story;
            
            for (var s=0, s_count = $stories.length; s < s_count; s++) {
                if ($stories.eq(s).data('story') == story.id) {
                    $story = $stories.eq(s);
                    break;
                }
            }
            
            return $story;
        },
        
        find_story_in_feed_iframe: function(story, $iframe) {
            if (!story) return $([]);
            
            $iframe = $iframe || this.$s.$feed_iframe.contents();
            var $stories = $([]);
            
            if (this.flags['iframe_story_locations_fetched'] || story.id in this.cache.iframe_stories) {
                return this.cache.iframe_stories[story.id];
            }
            
            var title = story.story_title.replace(/&nbsp;|[^a-z0-9-,]/gi, '');
                            
            var search_document = function(node, title) {
                var skip = 0;
                
                if (node && node.nodeType == 3) {
                    var pos = node.data.replace(/&nbsp;|[^a-z0-9-,]/gi, '')
                                       .indexOf(title);
                    if (pos >= 0) {
                        $stories.push($(node).parent());
                    }
                }
                else if (node && node.nodeType == 1 && node.childNodes && !(/(script|style)/i.test(node.tagName))) {
                    for (var i = 0; i < node.childNodes.length; ++i) {
                        i += search_document(node.childNodes[i], title);
                    }
                }
                return skip;
            };
            
            search_document($iframe.find('body')[0], title);
            
            $stories = $stories.filter(function() {
                return $(this).is(':visible');
            });
            
            if (!$stories.length) {
                // Not found straight, so check all header tags with styling children removed.
                this.cache.iframe['headers'] = this.cache.iframe['headers'] 
                                               || $('h1,h2,h3,h4,h5,h6', $iframe).filter(':visible');
                this.cache.iframe['headers'].each(function() {
                    pos = $(this).text().replace(/&nbsp;|[^a-z0-9-,]/gi, '')
                                 .indexOf(title);
                    // NEWSBLUR.log(['Search headers', title, pos, $(this), $(this).text()]);
                    if (pos >= 0) {
                        $stories.push($(this));
                        return false;
                    }
                });
            }
            
            if (!$stories.length) {
                // Still not found, so check Tumblr style .post's
                this.cache.iframe['posts'] = this.cache.iframe['posts'] 
                                             || $('.entry,.post,.postProp,#postContent,.article',
                                                  $iframe).filter(':visible');
                this.cache.iframe['posts'].each(function() {
                    pos = $(this).text().replace(/&nbsp;|[^a-z0-9-,]/gi, '')
                                 .indexOf(title);
                    // NEWSBLUR.log(['Search .post', title, pos, $(this), $(this).text().replace(/&nbsp;|[^a-z0-9-,]/gi, '')]);
                    if (pos >= 0) {
                        $stories.push($(this));
                        return false;
                    }
                });
            }
                        
            // Find the story with the biggest font size
            var max_size = 0;
            var $same_size_stories = $([]);
            $stories.each(function() {
                var $this = $(this);
                var size = parseInt($this.css('font-size'), 10);
                if (size > max_size) {
                    max_size = size;
                    $same_size_stories = $([]);
                }
                if (size == max_size) {
                    $same_size_stories.push($this);
                }
            });
            
            // NEWSBLUR.log(['Found stories', $stories.length, $same_size_stories.length, $same_size_stories, story.story_title]);
            
            // Multiple stories at the same big font size? Determine story title overlap,
            // and choose the smallest difference in title length.
            var $story = $([]);
            if ($same_size_stories.length > 1) {
                var story_similarity = 100;
                $same_size_stories.each(function() {
                    var $this = $(this);
                    var story_text = $this.text();
                    var overlap = Math.abs(story_text.length - story.story_title.length);
                    if (overlap < story_similarity) {
                        story_similarity = overlap;
                        $story = $this;
                    }
                });
            }

            if (!$story.length) {
                $story = $same_size_stories[0];
            }
            
            if ($story && $story.length) {
                var self = this;
                this.cache.iframe_stories[story.id] = $story;
                var position_original = parseInt($story.offset().top, 10);
                // var position_offset = parseInt($story.offsetParent().scrollTop(), 10);
                var position = position_original; // + position_offset;
                this.cache.iframe_story_positions[position] = story;
                this.cache.iframe_story_positions_keys.push(position);
            
                if (!this.flags['iframe_view_not_busting']) {
                    var feed_id = this.active_feed;
                    _.delay(function() {
                        if (feed_id == self.active_feed) {
                            self.flags['iframe_view_not_busting'] = true;
                        }
                    }, 1000);
                }
            }
            
            // NEWSBLUR.log(['Found story', $story]);
            return $story;
        },
        
        get_feed_ids_in_folder: function($folder) {
            var self = this;
            $folder = $folder || this.$s.$feed_list;
            
            var $feeds = $('.feed:not(.NB-empty)', $folder);
            var feeds = _.compact(_.map($('.feed:not(.NB-empty)', $folder), function(o) {
                var feed_id = parseInt($(o).attr('data-id'), 10);
                if (self.model.get_feed(feed_id).active) {
                  return feed_id;
                }
            }));
            
            return feeds;
        },
        
        // ==============
        // = Navigation =
        // ==============
        
        show_next_story: function(direction) {
            var $story_titles = this.$s.$story_titles;
            var $current_story = $('.selected:first', $story_titles);
            var $next_story;
            
            if (!$current_story.length) {
                $current_story = $('.story:first', $story_titles);
                $next_story = $current_story;
            } else if (direction == 1) {
                $next_story = $current_story.nextAll('.story:visible').eq(0);
            } else if (direction == -1) {
                $next_story = $current_story.prevAll('.story:visible').eq(0);
            }

            var story_id = $next_story.data('story_id');
            if (story_id) {
                var story = this.model.get_story(story_id);
                this.push_current_story_on_history();
                this.open_story(story, $next_story);
                this.scroll_story_titles_to_show_selected_story_title($next_story);
            }
        },
        
        show_next_unread_story: function() {
            var $story_titles = this.$s.$story_titles;
            var $current_story = $('.selected', $story_titles);
            var $next_story;
            var unread_count = this.get_unread_count(true);
            
            // NEWSBLUR.log(['show_next_unread_story', unread_count, $current_story, second_pass]);
            
            if (unread_count) {
                if (!$current_story.length) {
                    // Nothing selected, choose first unread.
                    $next_story = $('.story:not(.read):visible:first', $story_titles);
                } else {
                    // Start searching below, then search above current story.
                    $next_story = $current_story.nextAll('.story:not(.read):visible').eq(0);
                    if (!$next_story.length) {
                        $next_story = $current_story.prevAll('.story:not(.read):visible').eq(0);
                    }
                }
                
                if ($next_story && $next_story.length) {
                    this.counts['find_next_unread_on_page_of_feed_stories_load'] = 0;
                    var story_id = $next_story.data('story_id');
                    if (story_id) {
                        var story = this.model.get_story(story_id);
                        this.push_current_story_on_history();
                        this.open_story(story, $next_story);
                        this.scroll_story_titles_to_show_selected_story_title($next_story);
                    }
                } else if (this.counts['find_next_unread_on_page_of_feed_stories_load'] < this.constants.FILL_OUT_PAGES) {
                    // Nothing up, nothing down, but still unread. Load 1 page then find it.
                    this.counts['find_next_unread_on_page_of_feed_stories_load'] += 1;
                    this.load_page_of_feed_stories();
                }
            }
            
        },
        
        open_next_unread_story_across_feeds: function() {
          var unread_count = this.active_feed && this.get_unread_count(true);
          if (unread_count) {
            this.show_next_unread_story();
          } else {
            // Find next feed with unreads
            var $next_feed = this.get_next_unread_feed(1);
            var next_feed_id = parseInt($next_feed.attr('data-id'), 10);
            this.open_feed(next_feed_id, true, $next_feed);
            this.show_next_unread_story();
          }
        },
        
        show_previous_story: function() {
            if (this.cache['previous_stories_stack'].length) {
                var $previous_story = this.cache['previous_stories_stack'].pop();
                if ($previous_story.length && !$previous_story.is(':visible')) {
                    this.show_previous_story();
                    return;
                }
                
                var story_id = $previous_story.data('story_id');
                if (story_id) {
                    var story = this.model.get_story(story_id);
                    this.open_story(story, $previous_story);
                    this.scroll_story_titles_to_show_selected_story_title($previous_story);
                }
            }
        },
        
        scroll_story_titles_to_show_selected_story_title: function($story) {
            var $story_titles = this.$s.$story_titles;
            var story_title_visisble = $story_titles.isScrollVisible($story);
            if (!story_title_visisble) {
                var container_offset = $story_titles.position().top;
                var scroll = $story.position().top;
                var container = $story_titles.scrollTop();
                var height = $story_titles.outerHeight();
                $story_titles.scrollTop(scroll+container-height/5);
            }    
        },
        
        show_next_feed: function(direction, $current_feed) {
            var $feed_list = this.$s.$feed_list;
            var $next_feed = this.get_next_feed(direction, $current_feed);

            var feed_id = parseInt($next_feed.attr('data-id'), 10);
            if (feed_id && feed_id == this.active_feed) {
                this.show_next_feed(direction, $next_feed);
            } else if (feed_id) {
                var position = $feed_list.scrollTop() + $next_feed.offset().top - $next_feed.outerHeight();
                var showing = $feed_list.height() - 100;
                if (position > showing) {
                    scroll = position;
                } else {
                    scroll = 0;
                }
                $feed_list.scrollTop(scroll);
                this.open_feed(feed_id, false, $next_feed, 350);
            }
        },
        
        get_next_feed: function(direction, $current_feed) {
            var self = this;
            var $feed_list = this.$s.$feed_list;
            var $current_feed = $current_feed || $('.selected', $feed_list);
            var $next_feed,
                scroll;
            var $feeds = $('.feed:visible:not(.NB-empty)', $feed_list).add('.feed.selected');
            if (!$current_feed.length) {
                $current_feed = $('.feed:visible:not(.NB-empty)', $feed_list)[direction==1?'first':'last']();
                $next_feed = $current_feed;
            } else {
                $feeds.each(function(i) {
                    if (this == $current_feed[0]) {
                        current_feed = i;
                        return false;
                    }
                });
                $next_feed = $feeds.eq((current_feed+direction) % ($feeds.length));
            }
            
            return $next_feed;
        },
        
        get_next_unread_feed: function(direction, $current_feed) {
            var self = this;
            var $feed_list = this.$s.$feed_list;
            $current_feed = $current_feed || $('.selected', $feed_list);
            var unread_view = this.get_unread_view_name();
            var $next_feed;
            var $feeds = $('.feed:visible:not(.NB-empty)', $feed_list).filter(function() {
              var $this = $(this);
              if (unread_view == 'positive') {
                return $this.is('.unread_positive');
              } else if (unread_view == 'neutral') {
                return $this.is('.unread_positive,.unread_neutral');
              } else if (unread_view == 'negative') {
                return $this.is('.unread_positive,.unread_neutral,.unread_negative');
              }
            }).add('.feed.selected');
            if (!$current_feed.length) {
              $next_feed = $feeds.first();
            } else {
              $feeds.each(function(i) {
                  if (this == $current_feed[0]) {
                      current_feed = i;
                      return false;
                  }
              });
              $next_feed = $feeds.eq((current_feed+direction) % ($feeds.length));
            }
            
            return $next_feed;
        },
        
        get_current_folder: function() {
            var $folder = $('.folder.NB-selected', this.$s.$feed_list);
            if ($folder.length) {
                return $folder.eq(0);
            }
        },
        
        navigate_story_titles_to_story: function(story) {
            if (!story) return;
            var $next_story_title = this.find_story_in_story_titles(story.id);
            if ($next_story_title && 
                $next_story_title.length && 
                $next_story_title.is(':visible') && 
                !$next_story_title.hasClass('selected')) {
                // NEWSBLUR.log(['navigate_story_titles_to_story', story, $next_story_title]);
                
                this.scroll_story_titles_to_show_selected_story_title($next_story_title);
                if (this.active_story != story) {
                    this.push_current_story_on_history();
                    this.active_story = story;
                    this.mark_story_title_as_selected($next_story_title);
                    this.mark_story_as_read(story.id);
                    this.mark_story_as_read_in_feed_view(story, {'animate': this.story_view == 'feed'});
                }
            }
        },
        
        mark_story_as_read_in_feed_view: function(story, options) {
            if (!story) return;
            options = options || {};
            $story = this.cache.feed_view_stories[story.id] || this.find_story_in_feed_view(story);
            if ($story) {
                $story.addClass('read');
            }

            // This block animates the falling of the sentiment bullet. It's neat, 
            // but it stutters a fast scroll. Hence the delay.
            //
            // if (false && options.animate && !$story.hasClass('read')) {
            //     var $feed_view = this.$s.$feed_view;
            //     var start = $feed_view.scrollTop();
            //     (function(start) {
            //         _.delay(function() {
            //             $story.addClass('read');
            //             var end = $feed_view.scrollTop();
            //             if (end - start > 25) {
            //                 $('.NB-feed-story-sentiment-animate', $story).remove();
            //                 return;
            //             }
            //             var top = $('.NB-feed-story-header-info', $story).height();
            //             $('.NB-feed-story-sentiment-animate', $story).addClass('NB-animating').animate({
            //                 'top': top
            //             }, {
            //                 'duration': 550, 
            //                 'easing': 'easeInOutQuint', 
            //                 'complete': function() {
            //                     $(this).remove();
            //                 }
            //             });
            //         }, 20);
            //     })(start);
            // }
        },
        
        page_in_story: function(amount, direction) {
            var page_height = this.$s.$story_pane.height();
            var scroll_height = parseInt(page_height * amount, 10);
            var dir = '+';
            if (direction == -1) {
                dir = '-';
            }
            // NEWSBLUR.log(['page_in_story', this.$s.$story_pane, direction, page_height, scroll_height]);
            if (this.story_view == 'page') {
                this.$s.$feed_iframe.scrollTo({top:dir+'='+scroll_height, left:'+=0'}, 260);
            } else if (this.story_view == 'feed') {
                this.$s.$feed_stories.scrollTo({top:dir+'='+scroll_height, left:'+=0'}, 370);
            }
        },
        
        push_current_story_on_history: function() {
            var $current_story = $('.selected', this.$s.$story_titles);
            if ($current_story.length) {
                this.cache['previous_stories_stack'].push($current_story);
            }
        },
        
        // =============
        // = Feed Pane =
        // =============
        
        load_feeds: function() {
            var self = this;

            if ($('#feed_list').length) {
                $('.NB-callout-ftux .NB-callout-text').text('Loading feeds...');
                this.$s.$feed_link_loader.css({'display': 'block'});
                this.flags['favicons_downloaded'] = false;
                this.model.load_feeds($.rescope(this.make_feeds, this));
            }
        },
        
        make_feeds: function() {
            var self = this;
            var $feed_list = this.$s.$feed_list;
            var folders = this.model.folders;
            var feeds = this.model.feeds;
            
            // NEWSBLUR.log(['Making feeds', {'folders': folders, 'feeds': feeds}]);
            $feed_list.empty();
            
            this.$s.$story_taskbar.css({'display': 'block'});
            this.flags['has_chosen_feeds'] = this.detect_all_inactive_feeds();
            var $feeds = this.make_feeds_folder(folders, 0);
            $feed_list.css({
                'display': 'block', 
                'opacity': 0
            });
            $feed_list.html($feeds);
            // this.sort_feeds($feed_list);
            this.count_collapsed_unread_stories();
            $feed_list.animate({'opacity': 1}, {'duration': 700});
            this.hover_over_feed_titles($feed_list);
            this.$s.$feed_link_loader.fadeOut(250);

            if (folders.length) {
                $('.NB-task-manage').removeClass('NB-disabled');
                $('.NB-callout-ftux').fadeOut(500);
            }
            
            if (NEWSBLUR.Globals.is_authenticated && this.flags['has_chosen_feeds']) {
                _.delay(_.bind(this.start_count_unreads_after_import, this), 1000);
                this.force_feeds_refresh($.rescope(this.finish_count_unreads_after_import, this), true);
            } else if (!this.flags['has_chosen_feeds'] && this.flags['favicons_downloaded'] && folders.length) {
                _.defer(_.bind(this.open_feedchooser_modal, this), 100);
                return;
            } else if (NEWSBLUR.Globals.is_authenticated && !folders.length) {
                this.setup_ftux_add_feed_callout();
            }
            
            if (folders.length) {
                this.load_sortable_feeds();
                this.update_header_counts();
                _.delay(_.bind(this.update_starred_count, this), 250);
            }
            
            if (this.flags['showing_feed_in_tryfeed_view']) {
                this.hide_tryfeed_view();
                this.force_feed_refresh();
            }
            this.add_url_from_querystring();
            _.defer(_.bind(function() {
              this.model.load_feed_favicons($.rescope(this.make_feed_favicons, this), this.flags['favicons_downloaded'], this.flags['has_chosen_feeds']);
            }, this));
        },
        
        make_feed_favicons: function() {
          var model = this.model;
          this.flags['favicons_downloaded'] = true;
          $('.feed_favicon', this.$s.$feed_list).each(function() {
            var $feed_favicon = $(this);
            var feed_id = $feed_favicon.closest('.feed').attr('data-id');
            $feed_favicon.attr('src', $.favicon(model.get_feed(feed_id).favicon));
          });
          
          if (!this.flags['has_chosen_feeds'] && this.model.folders.length) {
              _.defer(_.bind(this.open_feedchooser_modal, this), 100);
          }
        },
        
        sort_items: function(items) {
          var self = this;
          var sort_order = this.model.preference('feed_order');
          
          if (sort_order == 'ALPHABETICAL' || !sort_order) {
            return items.sort(function(a, b) {
              var feedA, feedB;
              if (_.isNumber(a)) feedA = self.model.get_feed(a);
              if (_.isNumber(b)) feedB = self.model.get_feed(b);
              if (feedA && feedB) {
                return feedA.feed_title.toLowerCase() > feedB.feed_title.toLowerCase() ? 1 : -1;
              } else if (feedA && !feedB) {
                return -1;
              } else if (!feedA && feedB) {
                return 1;
              } else if (!feedA && !feedB && !_.isNumber(a) && !_.isNumber(b)) {
                // console.log(['a b 1', a, b]);
                var folderA = _.keys(a)[0];
                var folderB = _.keys(b)[0];
                return folderA.toLowerCase() > folderB.toLowerCase() ? 1 : -1;
              }
            });
          } else if (sort_order == 'MOSTUSED') {
            return items.sort(function(a, b) {
              var feedA, feedB;
              if (_.isNumber(a)) feedA = self.model.get_feed(a);
              if (_.isNumber(b)) feedB = self.model.get_feed(b);
              if (feedA && feedB) {
                return feedA.feed_opens < feedB.feed_opens ? 1 : 
                (feedA.feed_opens > feedB.feed_opens ? -1 : 
                  (feedA.feed_title.toLowerCase() > feedB.feed_title.toLowerCase() ? 1 : -1));
              } else if (feedA && !feedB) {
                return -1;
              } else if (!feedA && feedB) {
                return 1;
              } else if (!feedA && !feedB && !_.isNumber(a) && !_.isNumber(b)) {
                // console.log(['a b 2', a, b]);
                var folderA = _.keys(a)[0];
                var folderB = _.keys(b)[0];
                return folderA.toLowerCase() > folderB.toLowerCase() ? 1 : -1;
              }
            });
          }
        },
        
        sort_feeds: function($feeds) {
            $('.feed', $feeds).tsort('.feed_title');
            $('.folder', $feeds).tsort('.folder_title_text');
        },
        
        detect_all_inactive_feeds: function() {
          var feeds = this.model.feeds;
          var has_chosen_feeds = _.any(feeds, function(feed) {
            return feed.active;
          });
          return has_chosen_feeds;
        },
        
        make_feeds_folder: function(items, depth, collapsed_parent) {
            var self = this;
            var $feeds = "";
            
            items = this.sort_items(items);
            
            for (var i in items) {
                var item = items[i];

                if (typeof item == "number") {
                    var feed = this.model.get_feed(item);
                    if (!feed) continue;
                    var $feed = this.make_feed_title_template(feed, 'feed', depth);
                    $feeds += $feed;
                    
                    if (feed.not_yet_fetched) {
                        // NEWSBLUR.log(['Feed not fetched', feed]);
                        this.flags['has_unfetched_feeds'] = true;
                    }
                } else if (typeof item == "object" && item) {
                    for (var o in item) {
                        var is_collapsed = _.contains(NEWSBLUR.Preferences.collapsed_folders, o);
                        var folder = item[o];
                        var $folder_pre = _.template('\
                        <li class="folder">\
                          <div class="folder_title <% if (depth == 0) { %>NB-toplevel<% } %>">\
                            <div class="NB-folder-icon"></div>\
                            <div class="NB-feedlist-collapse-icon" title="<% if (is_collapsed) { %>Expand Folder<% } else {%>Collapse Folder<% } %>"></div>\
                            <div class="NB-feedlist-manage-icon"></div>\
                            <span class="folder_title_text"><%= folder_title %></span>\
                          </div>\
                          <ul class="folder" <% if (is_collapsed) { %>style="display: none"<% } %>>\
                        ', {
                          depth         : depth,
                          folder_title  : o,
                          is_collapsed  : is_collapsed
                        });
                        var $folder_post = "</ul></li>";
                        $feeds += $folder_pre + this.make_feeds_folder(folder, depth+1, is_collapsed) + $folder_post;
                    }
                }
            }
            $feeds += '<li class="feed NB-empty"></li>';
            return $feeds;
        },
        
        make_feed_title_template: function(feed, type, depth) {
            var unread_class = '';
            var exception_class = '';
            if (feed.ps) {
                unread_class += ' unread_positive';
            }
            if (feed.nt) {
                unread_class += ' unread_neutral';
            }
            if (feed.ng) {
                unread_class += ' unread_negative';
            }
            if (feed.has_exception && feed.exception_type == 'feed') {
                exception_class += ' NB-feed-exception';
            }
            if (feed.not_yet_fetched && !feed.has_exception) {
                exception_class += ' NB-feed-unfetched';
            }
            if (!feed.active) {
                exception_class += ' NB-feed-inactive';
            }
            var feed_counts_floater = this.make_feed_counts_floater(feed.ps, feed.nt, feed.ng, true);
            var $feed = _.template('\
            <<%= list_type %> class="feed <%= unread_class %> <%= exception_class %> <% if (toplevel) { %>NB-toplevel<% } %>" data-id="<%= feed.id %>">\
              <div class="feed_counts">\
                <%= feed_counts_floater %>\
              </div>\
              <img class="feed_favicon" src="<%= $.favicon(feed.favicon, true) %>">\
              <span class="feed_title">\
                <%= feed.feed_title %>\
                <% if (type == "story") { %>\
                  <span class="NB-feedbar-train-feed" title="Train Intelligence"></span>\
                  <span class="NB-feedbar-statistics" title="Statistics"></span>\
                <% } %>\
              </span>\
              <% if (type == "story") { %>\
                <div class="NB-feedbar-last-updated">\
                  <span class="NB-feedbar-last-updated-label">Updated:</span>\
                  <span class="NB-feedbar-last-updated-date">\
                    <% if (feed.updated) { %>\
                      <%= feed.updated %> ago\
                    <% } else { %>\
                      Loading...\
                    <% } %>\
                  </span>\
                </div>\
                <div class="NB-feedbar-mark-feed-read">Mark All as Read</div>\
              <% } %>\
              <div class="NB-feed-exception-icon"></div>\
              <div class="NB-feed-unfetched-icon"></div>\
              <div class="NB-feedlist-manage-icon"></div>\
            </<%= list_type %>>\
            ', {
              feed                : feed,
              type                : type,
              feed_counts_floater : feed_counts_floater,
              unread_class        : unread_class,
              exception_class     : exception_class,
              toplevel            : depth == 0,
              list_type           : type == 'feed' ? 'li' : 'div'
            });
            
            return $feed;
        },
        
        make_feed_counts_floater: function(positive_count, neutral_count, negative_count, skip_render) {
            var unread_class = "";
            if (positive_count) {
                unread_class += ' unread_positive';
            }
            if (neutral_count) {
                unread_class += ' unread_neutral';
            }
            if (negative_count) {
                unread_class += ' unread_negative';
            }
            
            var $floater = _.template('\
            <div class="feed_counts_floater <%= unread_class %>">\
              <span class="unread_count unread_count_positive <% if (positive_count) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
                <%= positive_count %>\
              </span>\
              <span class="unread_count unread_count_neutral <% if (neutral_count) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
                <%= neutral_count %>\
              </span>\
              <span class="unread_count unread_count_negative <% if (negative_count) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
                <%= negative_count %>\
              </span>\
            </div>\
            ', {
              positive_count  : positive_count,
              neutral_count   : neutral_count,
              negative_count  : negative_count,
              unread_class    : unread_class
            });
            
            if (!skip_render) {
              $floater = $($floater);
            }
            
            return $floater;
        },
        
        load_sortable_feeds: function() {
            var self = this;
            
            this.$s.$feed_list.sortable({
                items: '.feed,li.folder',
                connectWith: 'ul.folder,.feed.NB-empty',
                placeholder: 'NB-feeds-list-highlight',
                axis: 'y',
                distance: 4,
                cursor: 'move',
                containment: '.NB-feedlist',
                tolerance: 'pointer',
                scrollSensitivity: 35,
                start: function(e, ui) {
                    self.flags['sorting_feed'] = true;
                    ui.placeholder.attr('class', ui.item.attr('class') + ' NB-feeds-list-highlight');
                    ui.item.addClass('NB-feed-sorting');
                    self.$s.$feed_list.addClass('NB-feed-sorting');
                    if (ui.item.is('.folder')) {
                        ui.placeholder.html(ui.item.children().clone());
                        ui.item.data('previously_collapsed', ui.item.data('collapsed'));
                        self.collapse_folder(ui.item.children('.folder_title'), true);
                        self.collapse_folder(ui.placeholder.children('.folder_title'), true);
                        ui.item.css('height', ui.item.children('.folder_title').outerHeight(true) + 'px');
                        ui.helper.css('height', ui.helper.children('.folder_title').outerHeight(true) + 'px');
                    } else {
                        ui.placeholder.html(ui.item.children().clone());
                    }
                },
                change: function(e, ui) {
                    var $feeds = ui.placeholder.closest('ul.folder');
                    self.sort_feeds($feeds);
                },
                stop: function(e, ui) {
                    setTimeout(function() {
                        self.flags['sorting_feed'] = false;
                    }, 100);
                    ui.item.removeClass('NB-feed-sorting');
                    self.$s.$feed_list.removeClass('NB-feed-sorting');
                    self.sort_feeds(e.target);
                    self.save_feed_order();
                    ui.item.css({'backgroundColor': '#D7DDE6'})
                           .animate({'backgroundColor': '#F0F076'}, {'duration': 800})
                           .animate({'backgroundColor': '#D7DDE6'}, {'duration': 1000});
                    if (ui.item.is('.folder') && !ui.item.data('previously_collapsed')) {
                        self.collapse_folder(ui.item.children('.folder_title'));
                        self.collapse_folder(ui.placeholder.children('.folder_title'));
                    }
                }
            });
        },
        
        save_feed_order: function() {
            var combine_folders = function($folder) {
                var folders = [];
                var $items = $folder.children('li.folder, .feed');
                
                for (var i=0, i_count=$items.length; i < i_count; i++) {
                    var $item = $items.eq(i);

                    if ($item.hasClass('feed')) {
                        var feed_id = parseInt($item.attr('data-id'), 10);
                        if (feed_id) {
                            folders.push(feed_id);
                        }
                    } else if ($item.hasClass('folder')) {
                        var folder_title = $item.find('.folder_title_text').eq(0).text();
                        var child_folders = {};
                        child_folders[folder_title] = combine_folders($item.children('ul.folder').eq(0));
                        folders.push(child_folders);
                    }
                }
                
                return folders;
            };
            
            var combined_folders = combine_folders(this.$s.$feed_list);
            // NEWSBLUR.log(['Save new folder/feed order', {'combined': combined_folders}]);
            this.model.save_feed_order(combined_folders);
        },
        
        count_collapsed_unread_stories: function() {
            var self = this;
            
            _.each(NEWSBLUR.Preferences.collapsed_folders, _.bind(function(folder) {
                var $folder_title = $('.folder_title_text', this.$s.$feed_list).filter(function() {
                    return $.trim($(this).text()) == $.trim(folder);
                }).closest('.folder_title');
                this.collapse_folder($folder_title, true);
                var $folder = $folder_title.parent('li.folder');
                var $children = $folder.children('ul.folder');
                this.show_collapsed_folder_count($folder_title, $children, {'skip_animation': true});
            }, this));
            
            if (this.model.preference('folder_counts')) {
                var $folder_titles = $('.folder_title', this.$s.$feed_list);
                $folder_titles.each(function() {
                    var $folder_title = $(this);
                    if (!_.contains(NEWSBLUR.Preferences.collapsed_folders, $folder_title.text())) {
                        var $folder = $folder_title.parent('li.folder');
                        var $children = $folder.children('ul.folder');
                        self.show_collapsed_folder_count($folder_title, $children, {'skip_animation': true});
                    }
                });
            }
        },
        
        collapse_folder: function($folder_title, force_collapse) {
            var self = this;
            var $feed_list = this.$s.$feed_list;
            var $folder = $folder_title.parent('li.folder');
            var $children = $folder.children('ul.folder');
            
            // Hiding / Collapsing
            if (force_collapse || 
                ($children.length && 
                 $children.eq(0).is(':visible') && 
                 !$folder.data('collapsed'))) {
                this.model.collapsed_folders($('.folder_title_text', $folder_title).text(), true);
                $folder.data('collapsed', true).addClass('NB-folder-collapsed');
                $children.animate({'opacity': 0}, {
                    'queue': false,
                    'duration': force_collapse ? 0 : 200,
                    'complete': function() {
                        self.show_collapsed_folder_count($folder_title, $children);
                        $children.slideUp({
                            'duration': 270,
                            'easing': 'easeOutQuart'
                        });
                    }
                });
            } 
            // Showing / Expanding
            else if ($children.length && 
                       ($folder.data('collapsed') || !$children.eq(0).is(':visible'))) {
                this.model.collapsed_folders($('.folder_title_text', $folder_title).text(), false);
                $folder.data('collapsed', false).removeClass('NB-folder-collapsed');
                if (!this.model.preference('folder_counts')) {
                    this.hide_collapsed_folder_count($folder_title);
                }
                $children.css({'opacity': 0}).slideDown({
                    'duration': 240,
                    'easing': 'easeInOutCubic',
                    'complete': function() {
                        $children.animate({'opacity': 1}, {'queue': false, 'duration': 200});
                    }
                });
            }
        },
        
        show_collapsed_folder_count: function($folder_title, $children, options) {
            options = options || {};
            var $counts = $('.feed_counts_floater', $folder_title);
            $counts.remove();
            $children = $('li.feed', $children).not('.NB-feed-inactive');
            var $river = $('.NB-feedlist-collapse-icon', $folder_title);
            
            var positive_count = 0;
            var neutral_count = 0;
            var negative_count = 0;
            $('.unread_count_positive.unread_count_full', $children).each(function() {
                positive_count += parseInt($(this).text(), 10);
            });
            $('.unread_count_neutral.unread_count_full', $children).each(function() {
                neutral_count += parseInt($(this).text(), 10);
            });
            $('.unread_count_negative.unread_count_full', $children).each(function() {
                negative_count += parseInt($(this).text(), 10);
            });
            
            if ($folder_title.hasClass('NB-hover')) {
                $river.animate({'opacity': 0}, {'duration': options.skip_animation ? 0 : 100});
                $folder_title.addClass('NB-feedlist-folder-title-recently-collapsed');
                $folder_title.one('mouseover', function() {
                    $river.css({'opacity': ''});
                    $folder_title.removeClass('NB-feedlist-folder-title-recently-collapsed');
                });
            }
            
            var $counts = this.make_feed_counts_floater(positive_count, neutral_count, negative_count);
            $folder_title.prepend($counts.css({
                'opacity': 0
            }));
            $counts.animate({'opacity': 1}, {'duration': options.skip_animation ? 0 : 400});
        },
        
        hide_collapsed_folder_count: function($folder_title) {
            var $counts = $('.feed_counts_floater', $folder_title);
            var $river = $('.NB-feedlist-collapse-icon', $folder_title);
            
            $counts.animate({'opacity': 0}, {
                'duration': 300 
            });
            
            $river.animate({'opacity': .6}, {'duration': 400});
            $folder_title.removeClass('NB-feedlist-folder-title-recently-collapsed');
            $folder_title.one('mouseover', function() {
                $river.css({'opacity': ''});
                // $folder_title.removeClass('NB-feedlist-folder-title-recently-collapsed');
            });
        },
        
        hover_over_feed_titles: function($folder) {
            var self = this;
            var $feeds;
            $folder = $folder || this.$s.$feed_list;
            
            if ($folder.is('.feed')) {
                $feeds = $folder;
            } else {
                $feeds = $('.feed, .folder_title', $folder);
            }

            // NEWSBLUR.log(['hover_over_feed_titles', $folder, $feeds]);
            
            $feeds.unbind('mouseenter').unbind('mouseleave');
            
            $feeds.hover(function() {
                if (!self.$s.$feed_list.hasClass('NB-feed-sorting')) {
                    var $this = $(this);
                    // _.defer(function() { $('.NB-hover', $folder).not($this).removeClass('NB-hover'); });
                    // NEWSBLUR.log(['scroll', $this.scrollTop(), $this.offset(), $this.position()]);
                    if ($this.offset().top > $(window).height() - 270) {
                        $this.addClass('NB-hover-inverse');
                    } 
                }
            }, function() {
                var $this = $(this);
                $this.removeClass('NB-hover-inverse');
            });
        },
        
        show_feed_chooser_button: function() {
            var self = this;
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            var percentage = 0;
            
            $('.NB-progress-title', $progress).text('Get Started');
            $('.NB-progress-counts', $progress).hide();
            $('.NB-progress-percentage', $progress).hide();
            $progress.addClass('NB-progress-error').addClass('NB-progress-big');
            $('.NB-progress-link', $progress).html($.make('a', { href: '#', className: 'NB-splash-link NB-menu-manage-feedchooser' }, 'Choose your 64'));
            
            this.show_progress_bar();
        },
        
        hide_feed_chooser_button: function() {
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            $progress.removeClass('NB-progress-error').removeClass('NB-progress-big');
            
            this.hide_progress_bar();
        },
        
        // ================
        // = Progress Bar =
        // ================
        
        check_feed_fetch_progress: function() {
            $.extend(this.counts, {
                'unfetched_feeds': 0,
                'fetched_feeds': 0
            });
            
            if (this.flags['has_unfetched_feeds']) {
                var counts = this.model.count_unfetched_feeds();
                this.counts['unfetched_feeds'] = counts['unfetched_feeds'];
                this.counts['fetched_feeds'] = counts['fetched_feeds'];

                if (this.counts['unfetched_feeds'] == 0) {
                    this.flags['has_unfetched_feeds'] = false;
                    this.hide_unfetched_feed_progress();
                } else {
                    this.flags['has_unfetched_feeds'] = true;
                    this.show_unfetched_feed_progress();
                }
            }
        },
        
        show_progress_bar: function() {
            var $layout = this.$s.$feeds_progress.parents('.left-center').layout();
            if (!this.flags['showing_progress_bar']) {
                this.flags['showing_progress_bar'] = true;
                $layout.open('south');
            }
            $layout.sizePane('south');
        },

        hide_progress_bar: function(permanent) {
            var self = this;
          
            if (permanent) {
                this.model.preference('hide_fetch_progress', true);
            }
            
            this.flags['showing_progress_bar'] = false;
            this.$s.$feeds_progress.parents('.left-center').layout().close('south');
        },
        
        show_unfetched_feed_progress: function() {
            var self = this;
            var $progress = this.$s.$feeds_progress;
            var percentage = parseInt(this.counts['fetched_feeds'] / (this.counts['unfetched_feeds'] + this.counts['fetched_feeds']) * 100, 10);

            $('.NB-progress-title', $progress).text('Fetching your feeds');
            $('.NB-progress-counts', $progress).show();
            $('.NB-progress-counts-fetched', $progress).text(this.counts['fetched_feeds']);
            $('.NB-progress-counts-total', $progress).text(this.counts['unfetched_feeds'] + this.counts['fetched_feeds']);
            $('.NB-progress-percentage', $progress).show().text(percentage + '%');
            $('.NB-progress-bar', $progress).progressbar({
                value: percentage
            });
            
            if (!$progress.is(':visible') && !this.model.preference('hide_fetch_progress')) {
                setTimeout(function() {
                    self.show_progress_bar();
                }, 1000);
            }
            
            this.setup_feed_refresh(true);
        },
        
        hide_unfetched_feed_progress: function(permanent) {
            if (permanent) {
                this.model.preference('hide_fetch_progress', true);
            }
            
            this.setup_feed_refresh();
            this.hide_progress_bar();
        },
        
        switch_preferences_hide_read_feeds: function() {
            var hide_read_feeds = parseInt(this.model.preference('hide_read_feeds'), 10);
            var $button = $('.NB-feeds-header-sites');
            
            if (this.model.preference('show_tooltips')) {
                if (hide_read_feeds) {
                    $button.tipsy('hide');
                    $button.attr('title', 'Show only unread stories');
                    $button.tipsy('show');
                } else {
                    $button.tipsy('hide');
                    $button.attr('title', 'Show all sites');
                    $button.tipsy('show');
                }
            }
            
            this.model.preference('hide_read_feeds', hide_read_feeds ? 0 : 1);
            this.switch_feed_view_unread_view();
        },
        
        // ===============================
        // = Feed bar - Individual Feeds =
        // ===============================
        
        reset_feed: function() {
            $.extend(this.flags, {
                'iframe_story_locations_fetched': false,
                'iframe_view_loaded': false,
                'iframe_view_not_busting': false,
                'feed_view_images_loaded': {},
                'feed_view_positions_calculated': false,
                'scrolling_by_selecting_story_title': false,
                'switching_to_feed_view': false,
                'page_view_showing_feed_view': false,
                'feed_view_showing_story_view': false,
                'iframe_fetching_story_locations': false,
                'story_titles_loaded': false,
                'iframe_prevented_from_loading': false,
                'pause_feed_refreshing': false,
                'feed_list_showing_manage_menu': false,
                'unread_threshold_temporarily': null,
                'river_view': false,
                'non_premium_river_view': false
            });
            
            $.extend(this.cache, {
                'iframe': {},
                'iframe_stories': {},
                'feed_view_stories': {},
                'iframe_story_positions': {},
                'feed_view_story_positions': {},
                'iframe_story_positions_keys': [],
                'feed_view_story_positions_keys': [],
                'previous_stories_stack': [],
                'river_feeds_with_unreads': [],
                'mouse_position_y': parseInt(this.model.preference('lock_mouse_indicator'), 10),
                'prefetch_last_story': 0,
                'prefetch_iteration': 0,
                'feed_title_floater_feed_id': null,
                'feed_title_floater_story_id': null,
                'last_feed_view_story_feed_id': null,
                '$feed_in_feed_list': {},
                '$feed_counts_in_feed_list': {}
            });
            
            $.extend(this.counts, {
                'page_fill_outs': 0,
                'find_next_unread_on_page_of_feed_stories_load': 0
            });
            
            this.active_feed = null;
            this.active_story = null;
            this.$s.$story_titles.data('page', 1);
            this.$s.$story_titles.data('feed_id', null);
            this.$s.$feed_stories.scrollTop(0);
            this.$s.$feed_stories.empty();
            this.$s.$story_titles.empty();
            this.$s.$starred_header.removeClass('NB-selected');
            this.$s.$river_header.removeClass('NB-selected');
            this.$s.$tryfeed_header.removeClass('NB-selected');
            $('.NB-selected', this.$s.$feed_list).removeClass('NB-selected');
            this.$s.$body.removeClass('NB-view-river');
            $('.task_view_page', this.$s.$taskbar).removeClass('NB-disabled');
            $('.task_view_page', this.$s.$taskbar).removeClass('NB-task-return');
            this.hide_content_pane_feed_counter();
            
            if (this.flags['showing_feed_in_tryfeed_view']) {
                this.hide_tryfeed_view();
            }
        },
        
        open_feed: function(feed_id, force, $feed_link, delay) {
            var self = this;
            var $story_titles = this.$s.$story_titles;
            this.flags['opening_feed'] = true;
            
            if (feed_id != this.active_feed || force) {
                $story_titles.empty().scrollTop(0);
                this.reset_feed();
                this.hide_splash_page();
            
                this.active_feed = feed_id;
                this.next_feed = feed_id;
                
                this.show_stories_progress_bar();
                $story_titles.data('page', 1);
                $story_titles.data('feed_id', feed_id);
                this.iframe_scroll = null;
                this.set_correct_story_view_for_feed(feed_id);
                $feed_link = $feed_link || $('.feed.selected', this.$s.$feed_list).eq(0);
                this.mark_feed_as_selected(feed_id, $feed_link);
                this.show_feed_title_in_stories(feed_id);
                this.show_feedbar_loading();
                this.switch_taskbar_view(this.story_view);

                _.delay(_.bind(function() {
                    if (!delay || feed_id == self.next_feed) {
                        this.model.load_feed(feed_id, 1, true, $.rescope(this.post_open_feed, this));
                    }
                }, this), delay || 0);

                if (!this.story_view || this.story_view == 'page') {
                    _.delay(_.bind(function() {
                        if (!delay || feed_id == this.next_feed) {
                            this.load_feed_iframe(feed_id);
                        }
                    }, this), delay || 0);
                } else {
                    this.unload_feed_iframe();
                    this.flags['iframe_prevented_from_loading'] = true;
                }
                this.setup_mousemove_on_views();
            }
        },
        
        post_open_feed: function(e, data, first_load) {
            if (!data) {
                return this.open_feed(this.active_feed, true);
            }
            var stories = data.stories;
            var tags = data.tags;
            var feed_id = data.feed_id;
            
            if (data.dupe_feed_id && this.active_feed == data.dupe_feed_id) {
                this.active_feed = data.feed_id;
            }
            
            if (this.active_feed != feed_id) return;
            
            // NEWSBLUR.log(['post_open_feed', data.stories, this.flags]);
            this.flags['opening_feed'] = false;
            this.flags['feed_view_positions_calculated'] = false;
            this.story_titles_clear_loading_endbar();
            this.create_story_titles(stories);
            this.make_story_feed_entries(stories, first_load);
            this.show_feed_hidden_story_title_indicator(true);
            this.show_story_titles_above_intelligence_level({'animate': false});
            this.fill_out_story_titles();
            $('.NB-feedbar-last-updated-date').text(data.last_update + ' ago');
            if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                this.show_next_unread_story(true);
            }
            this.flags['story_titles_loaded'] = true;
            if (!first_load) {
                var stories_count = this.cache['iframe_story_positions_keys'].length;
                this.flags['iframe_story_locations_fetched'] = false;
                var $iframe = this.$s.$feed_iframe.contents();
                this.fetch_story_locations_in_story_frame(stories_count, false, $iframe);
                if (this.story_view == 'feed' || this.flags['page_view_showing_feed_view']) {
                    this.prefetch_story_locations_in_feed_view();
                }
            } else {
                if (this.story_view == 'page') {
                  if (this.flags['iframe_view_loaded']) {
                      // NEWSBLUR.log(['Titles loaded, iframe loaded']);
                      var $iframe = this.$s.$feed_iframe.contents();
                      this.fetch_story_locations_in_story_frame(0, true, $iframe);
                  } else {
                      // NEWSBLUR.log(['Titles loaded, iframe NOT loaded -- prefetching now']);
                      _.delay(_.bind(function() {
                          this.prefetch_story_locations_in_story_frame();
                      }, this), 250);
                  }
                } else if (this.story_view == 'feed') {
                    this.prefetch_story_locations_in_feed_view();
                } else if (this.story_view == 'story') {
                    this.show_next_story(1);
                }
            }
            if (this.flags['open_unread_stories_in_tabs']) {
                _.defer(_.bind(this.open_unread_stories_in_tabs, this));
            }
            this.hide_stories_progress_bar();
            if (this.flags['showing_feed_in_tryfeed_view']) {
                this.show_tryfeed_add_button();
            }
            this.make_content_pane_feed_counter(feed_id);
        },
        
        setup_mousemove_on_views: function() {
            var $iframe_contents = this.$s.$feed_iframe.contents();
            $iframe_contents
                .unbind('scroll')
                .scroll($.rescope(this.handle_scroll_feed_iframe, this));
            this.hide_mouse_indicator();
            $iframe_contents
                .unbind('mousemove.reader')
                .bind('mousemove.reader', $.rescope(this.handle_mousemove_iframe_view, this));
            this.$s.$content_pane
                .unbind('mouseleave.reader')
                .bind('mouseleave.reader', $.rescope(this.hide_mouse_indicator, this));
            this.$s.$content_pane
                .unbind('mouseenter.reader')
                .bind('mouseenter.reader', $.rescope(this.show_mouse_indicator, this));
        },
        
        set_correct_story_view_for_feed: function(feed_id, view) {
          var feed = this.model.get_feed(feed_id);
          view = view || this.model.view_setting(feed_id);
          
          if (feed && feed.has_exception && feed.exception_type == 'page') {
            if (view == 'page') {
              view = 'feed';
            }
            $('.task_view_page').addClass('NB-exception-page');
          } else {
            $('.task_view_page').removeClass('NB-exception-page');
          }
          
          this.story_view = view;
        },
        
        // ===============
        // = Feed Header =
        // ===============
        
        update_header_counts: function(skip_sites) {
            if (!skip_sites) {
                var feeds_count = _.select(this.model.feeds, function(f) {
                  return f.active;
                }).length;
                if (feeds_count) {
                  $('.NB-feeds-header-right .NB-feeds-header-sites').text(feeds_count + Inflector.pluralize(' site', feeds_count));
                }
            }
              
            var unread_counts = _.reduce(this.model.feeds, function(m, v) {
                if (v.active) {
                    m['positive'] += v.ps;
                    m['neutral'] += v.nt;
                    m['negative'] += v.ng;
                }
                return m;
            }, {'positive': 0, 'negative': 0, 'neutral': 0});
            _(['positive', 'neutral', 'negative']).each(function(level) {
                var $count = $('.NB-feeds-header-'+level);
                $count.text(unread_counts[level]);
                $count.toggleClass('NB-empty', unread_counts[level] == 0);
            });
        },
        
        update_starred_count: function() {
            var starred_count = this.model.starred_count;
            var $starred_count = $('.NB-feeds-header-count', this.$s.$starred_header);
            var $starred_container = this.$s.$starred_header.closest('.NB-feeds-header-container');

            if (starred_count <= 0) {
                this.$s.$starred_header.addClass('NB-empty');
                $starred_count.text('');
                $starred_container.slideUp(350);
            } else if (starred_count > 0) {
                $starred_count.text(starred_count);
                this.$s.$starred_header.removeClass('NB-empty');
                $starred_container.slideDown(350);
            }
        },
        
        open_starred_stories: function() {
            var $story_titles = this.$s.$story_titles;
            
            $story_titles.empty().scrollTop('0px');
            this.reset_feed();
            this.hide_splash_page();
            this.active_feed = 'starred';

            $story_titles.data('page', 1);
            $story_titles.data('feed_id', null);
            this.iframe_scroll = null;
            this.mark_feed_as_selected(null, null);
            this.show_correct_feed_in_feed_title_floater();
            this.$s.$starred_header.addClass('NB-selected');
            this.$s.$body.addClass('NB-view-river');
            this.flags.river_view = true;
            $('.task_view_page', this.$s.$taskbar).addClass('NB-disabled');
            var explicit_view_setting = NEWSBLUR.Preferences.view_settings[this.active_feed];
            if (!explicit_view_setting) {
              explicit_view_setting = 'feed';
            }
            this.set_correct_story_view_for_feed(this.active_feed, explicit_view_setting);
            // this.show_feed_title_in_stories(feed_id);
            this.show_feedbar_loading();
            this.switch_taskbar_view(this.story_view);
            this.setup_mousemove_on_views();
            
            this.model.fetch_starred_stories(1, _.bind(this.post_open_starred_stories, this), true);
        },
        
        post_open_starred_stories: function(data, first_load) {
            if (this.active_feed == 'starred') {
                // NEWSBLUR.log(['post_open_starred_stories', data.stories.length, first_load]);
                this.flags['feed_view_positions_calculated'] = false;
                this.story_titles_clear_loading_endbar();
                this.create_story_titles(data.stories, {'river_stories': true});
                this.make_story_feed_entries(data.stories, first_load, {'river_stories': true});
                this.show_story_titles_above_intelligence_level({'animate': false});
                // $('.NB-feedbar-last-updated-date').text(data.last_update + ' ago');
                this.flags['story_titles_loaded'] = true;
                this.prefetch_story_locations_in_feed_view();
                this.fill_out_story_titles();
            }
        },
        
        // =================
        // = River of News =
        // =================
        
        open_river_stories: function($folder, folder_title) {
            var $story_titles = this.$s.$story_titles;
            $folder = $folder || this.$s.$feed_list;
            
            $story_titles.empty().scrollTop('0px');
            this.reset_feed();
            this.hide_splash_page();
            if (!folder_title) {
                this.active_feed = 'river:';
                this.$s.$river_header.addClass('NB-selected');
            } else {
                this.active_feed = 'river:' + folder_title;
                $folder.addClass('NB-selected');
            }
            
            $story_titles.data('page', 1);
            $story_titles.data('feed_id', null);
            this.iframe_scroll = null;
            this.flags['opening_feed'] = true;
            this.mark_feed_as_selected(null, null);
            this.show_correct_feed_in_feed_title_floater();
            this.$s.$body.addClass('NB-view-river');
            this.flags.river_view = true;
            
            
            $('.task_view_page', this.$s.$taskbar).addClass('NB-disabled');
            var explicit_view_setting = NEWSBLUR.Preferences.view_settings[this.active_feed];
            if (!explicit_view_setting) {
              explicit_view_setting = 'feed';
            }
            this.set_correct_story_view_for_feed(this.active_feed, explicit_view_setting);
            // this.show_feed_title_in_stories(feed_id);
            this.show_feedbar_loading();
            this.switch_taskbar_view(this.story_view);
            this.setup_mousemove_on_views();
            
            var feeds = this.list_feeds_with_unreads_in_folder($folder, false, true);
            this.cache['river_feeds_with_unreads'] = feeds;
            this.show_stories_progress_bar(feeds.length);
            this.model.fetch_river_stories(this.active_feed, feeds, 1, 
                _.bind(this.post_open_river_stories, this), true);
        },
        
        post_open_river_stories: function(data, first_load) {
            // NEWSBLUR.log(['post_open_river_stories', data, this.active_feed]);
            if (this.active_feed && this.active_feed.indexOf('river:') != -1) {
                if (!NEWSBLUR.Globals.is_premium &&
                    NEWSBLUR.Globals.is_authenticated &&
                    this.flags['river_view'] &&
                    this.active_feed.indexOf('river:') != -1) {
                    this.flags['non_premium_river_view'] = true;
                }
                this.flags['opening_feed'] = false;
                this.flags['feed_view_positions_calculated'] = false;
                this.story_titles_clear_loading_endbar();
                this.create_story_titles(data.stories, {'river_stories': true});
                this.make_story_feed_entries(data.stories, first_load, {'river_stories': true});
                this.show_story_titles_above_intelligence_level({'animate': false});
                // $('.NB-feedbar-last-updated-date').text(data.last_update + ' ago');
                this.flags['story_titles_loaded'] = true;
                if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                }
                this.fill_out_story_titles();
                this.prefetch_story_locations_in_feed_view();
                this.hide_stories_progress_bar();
            }
        },
        
        list_feeds_with_unreads_in_folder: function($folder, counts_only, visible_only) {
            var model = this.model;
            var unread_view = this.get_unread_view_name();
            $folder = $folder || this.$s.$feed_list;
            
            var $feeds = $('.feed:not(.NB-empty)', $folder);
            var feeds = _.compact(_.map($('.feed:not(.NB-empty)', $folder), function(o) {
                var feed_id = parseInt($(o).attr('data-id'), 10);
                var feed = model.get_feed(feed_id);
                if (!feed) {
                    return;
                } else if (counts_only && !visible_only) {
                    return feed.ps + feed.nt + feed.ng;
                } else if (counts_only && visible_only) {
                    if (unread_view == 'positive') return feed.ps;
                    if (unread_view == 'neutral')  return feed.ps + feed.nt;
                    if (unread_view == 'negative') return feed.ps + feed.nt + feed.ng;
                } else if (!counts_only && visible_only) {
                    if (unread_view == 'positive') return feed.ps && feed_id;
                    if (unread_view == 'neutral')  return (feed.ps || feed.nt) && feed_id;
                    if (unread_view == 'negative') return (feed.ps || feed.nt || feed.ng) && feed_id;
                } else {
                    return (feed.ps || feed.nt || feed.ng) && feed_id;
                }
            }));
            
            return feeds;
        },
        
        show_stories_progress_bar: function(feeds_loading) {
            var $progress = $.make('div', { className: 'NB-river-progress' }, [
                $.make('div', { className: 'NB-river-progress-text' }),
                $.make('div', { className: 'NB-river-progress-bar' })
            ]).css({'opacity': 0});
            
            this.$s.$story_taskbar.append($progress);
            
            $progress.animate({'opacity': 1}, {'duration': 500, 'queue': false});
            
            var $bar = $('.NB-river-progress-bar', $progress);
            var unreads;
            if (feeds_loading) unreads = feeds_loading;
            else unreads = this.get_unread_count(false) / 10;
            this.animate_progress_bar($bar, unreads);
            
            $('.NB-river-progress-text', $progress).text('Fetching stories');
            // Center the progress bar
            var i_width = $progress.width();
            var o_width = this.$s.$story_taskbar.width();
            var left = (o_width / 2.0) - (i_width / 2.0);
            $progress.css({'left': left});
        },
        
        hide_stories_progress_bar: function() {
            var $progress = $('.NB-river-progress', this.$s.$story_taskbar);
            $progress.stop().animate({'opacity': 0}, {
              'duration': 250, 
              'queue': false, 
              'complete': function() {
                $progress.remove();
              }
            });
        },
        
        // ==========================
        // = Story Pane - All Views =
        // ==========================
        
        open_story: function(story, $story_title) {
            var self = this;
            var feed_position;
            var iframe_position;
            // NEWSBLUR.log(['open_story', this.story_view, story]);
            
            if (this.active_story != story) {
                this.active_story = story;
                this.mark_story_title_as_selected($story_title);
                this.mark_story_as_read_in_feed_view(story, {'animate': true});
                this.unload_story_iframe();
                
                // Used when auto-tracking the user as they move over the feed/page.
                // No need to find the story, since they have already found it.
                clearTimeout(this.locks.scrolling);
                if (_.contains(['feed', 'page'], this.story_view)) {
                    this.flags['scrolling_by_selecting_story_title'] = true;
                }
                
                // User clicks on story, scroll them to it.
                var $feed_story = this.find_story_in_feed_view(story);
                
                if (this.story_view == 'page') {
                    var $iframe_story = this.find_story_in_feed_iframe(story);
                    if (!$iframe_story || !$iframe_story.length || !this.flags['story_titles_loaded']) {
                        // If the iframe has not yet loaded, we can't touch it.
                        // So just assume story not found.
                        this.switch_to_correct_view(false);
                        feed_position = this.scroll_to_story_in_story_feed(story, $feed_story);
                    } else {
                        iframe_position = this.scroll_to_story_in_iframe(story, $iframe_story);
                        this.switch_to_correct_view(iframe_position);
                    }
                } else if (this.story_view == 'feed') {
                    this.switch_to_correct_view();
                    feed_position = this.scroll_to_story_in_story_feed(story, $feed_story);
                    this.show_stories_preference_in_feed_view(true);
                } else if (this.story_view == 'story') {
                    this.open_story_in_story_view(story);
                }
                _.defer(_.bind(this.mark_story_as_read, this, story.id));
            }
        },
        
        switch_to_correct_view: function(found_story_in_page) {
            // NEWSBLUR.log(['Found story', this.story_view, found_story_in_page, this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
            if (found_story_in_page === false) {
                // Story not found, show in feed view with link to page view
                if (this.story_view == 'page' && !this.flags['page_view_showing_feed_view']) {
                    // console.log(['turn on feed view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                    this.flags['page_view_showing_feed_view'] = true;
                    this.flags['feed_view_showing_story_view'] = false;
                    this.switch_taskbar_view('feed', 'page');
                    this.show_stories_preference_in_feed_view();
                }
            } else {
              if (this.story_view == 'page' && this.flags['page_view_showing_feed_view']) {
                  // console.log(['turn off feed view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                  this.flags['page_view_showing_feed_view'] = false;
                  this.flags['feed_view_showing_story_view'] = false;
                  this.switch_taskbar_view('page');
              } else if (this.flags['feed_view_showing_story_view']) {
                  // console.log(['turn off story view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                  this.flags['page_view_showing_feed_view'] = false;
                  this.flags['feed_view_showing_story_view'] = false;
                  this.switch_taskbar_view(this.story_view, true);
              }
            }
        },
        
        scroll_to_story_in_story_feed: function(story, $story, skip_scroll) {
            var self = this;
            var $feed_view = this.$s.$feed_view;
            var $feed_stories = this.$s.$feed_stories;

            if (!story || !$story || !$story.length) {
                $story = $('.story:first', $feed_view);
                story = this.model.get_story($story.data('story'));
            }
            if (!story || !$story || !$story.length) {
                return;
            }
            
            if (!this.model.preference('animations')) skip_scroll = true;
            
            if ($story && $story.length) {
                if (skip_scroll || 
                    (this.story_view == 'feed'  &&
                     this.model.preference('feed_view_single_story')) ||
                    (this.story_view == 'page' && 
                     !this.flags['page_view_showing_feed_view'])) {
                    this.locks.scrolling = setTimeout(function() {
                        self.flags.scrolling_by_selecting_story_title = false;
                    }, 100);
                    $feed_stories.scrollTo($story, { duration: 0, axis: 'y', offset: 0 }); // Do this at view switch instead.
                } else if (this.story_view == 'feed' || this.flags['page_view_showing_feed_view']) {
                    $feed_stories.scrollable().stop();
                    $feed_stories.scrollTo($story, { 
                        duration: 340,
                        axis: 'y', 
                        easing: 'easeInOutQuint', 
                        offset: 0, 
                        queue: false, 
                        onAfter: function() {
                            self.locks.scrolling = setTimeout(function() {
                                self.flags.scrolling_by_selecting_story_title = false;
                            }, 100);
                        }
                    });
                } 
            }
            
            var parent_scroll = $story.parents('.NB-feed-story-view').scrollTop();
            var story_offset = $story.offset().top;
            return story_offset + parent_scroll;
        },
        
        scroll_to_story_in_iframe: function(story, $story, skip_scroll) {
            var self = this;
            var $iframe = this.$s.$feed_iframe;
            
            if (!this.model.preference('animations')) skip_scroll = true;
            
            if ($story && $story.length) {
                if (skip_scroll
                    || this.story_view == 'feed'
                    || this.story_view == 'story'
                    || this.flags['page_view_showing_feed_view']) {
                    $iframe.scrollTo($story, { duration: 0, axis: 'y', offset: -24 }); // Do this at story_view switch
                    self.locks.scrolling = setTimeout(function() {
                        self.flags.scrolling_by_selecting_story_title = false;
                    }, 100);
                } else if (this.story_view == 'page') {
                    $iframe.scrollable().stop();
                    $iframe.scrollTo($story, { 
                        duration: 380,
                        axis: 'y', 
                        easing: 'easeInOutQuint', 
                        offset: -24, 
                        queue: false, 
                        onAfter: function() {
                            self.locks.scrolling = setTimeout(function() {
                                self.flags.scrolling_by_selecting_story_title = false;
                            }, 100);
                        }
                    });
                }
                var parent_scroll = $story.parents('.NB-feed-story-view').scrollTop();
                var story_offset = $story.offset().top;

                return story_offset + parent_scroll;
            }

            return false;
        },
        
        prefetch_story_locations_in_story_frame: function() {
            var self = this;
            var stories = this.model.stories;
            var $iframe = this.$s.$feed_iframe.contents();
            var prefetch_tries_left = 3;
            this.cache['prefetch_iteration'] += 1;
            
            // NEWSBLUR.log(['Prefetching', !this.flags['iframe_fetching_story_locations']]);
            if (!this.flags['iframe_fetching_story_locations'] 
                && !this.flags['iframe_story_locations_fetched']) {
                $iframe.unbind('scroll').scroll($.rescope(this.handle_scroll_feed_iframe, this));
                $iframe
                    .unbind('mousemove.reader')
                    .bind('mousemove.reader', $.rescope(this.handle_mousemove_iframe_view, this));
                    
                var last_story_index = this.cache.iframe_story_positions_keys.length;
                var last_story_position = _.last(this.cache.iframe_story_positions_keys);
                var last_story = this.cache.iframe_story_positions[last_story_position];
                var $last_story;
                if (last_story) {
                    $last_story = this.find_story_in_feed_iframe(last_story, $iframe);
                }
                // NEWSBLUR.log(['last_story', last_story_index, last_story_position, last_story, $last_story]);
                var last_story_same_position;
                if ($last_story && $last_story.length) {
                    last_story_same_position = parseInt($last_story.offset().top, 10)==last_story_position;
                    if (!last_story_same_position) {
                        $.extend(this.cache, {
                            'iframe_stories': {},
                            'iframe_story_positions': {},
                            'iframe_story_positions_keys': []
                        });
                    }
                }
                
                for (var s in stories) {
                    if (last_story_same_position && parseInt(s, 10) < last_story_index) continue; 
                    var story = stories[s];
                    var $story = this.find_story_in_feed_iframe(story, $iframe);
                    // NEWSBLUR.log(['Pre-fetching', parseInt(s, 10), last_story_index, last_story_same_position, $story, story.story_title]);
                    if (!$story || 
                        !$story.length || 
                        this.flags['iframe_fetching_story_locations'] ||
                        this.flags['iframe_story_locations_fetched'] ||
                        parseInt($story.offset().top, 10) > this.cache['prefetch_iteration']*2000) {
                        if ($story && $story.length) {
                            // NEWSBLUR.log(['Prefetch break on position too far', parseInt($story.offset().top, 10), this.cache['prefetch_iteration']*4000]);
                            break;
                        }
                        if (!prefetch_tries_left) {
                            break;
                        } else {
                            prefetch_tries_left -= 1;
                        }
                    }
                }
            }
            
            if (!this.flags['iframe_fetching_story_locations']
                && !this.flags['iframe_story_locations_fetched']) {
                setTimeout(function() {
                    if (!self.flags['iframe_fetching_story_locations']
                        && !self.flags['iframe_story_locations_fetched']) {
                        self.prefetch_story_locations_in_story_frame();
                    }
                }, 1000);
            }
        },
        
        fetch_story_locations_in_story_frame: function(s, clear_cache, $iframe) {
            var self = this;
            var stories = this.model.stories;
            if (!s) s = 0;
            var story = stories[s];
            if (!$iframe) $iframe = this.$s.$feed_iframe.contents();
            
            this.flags['iframe_fetching_story_locations'] = true;
            this.flags['iframe_story_locations_fetched'] = false;

            if (clear_cache) {
                $.extend(this.cache, {
                    'iframe_stories': {},
                    'iframe_story_positions': {},
                    'iframe_story_positions_keys': []
                });
            }
            
            if (story && story['story_feed_id'] == this.active_feed) {
                var $story = this.find_story_in_feed_iframe(story, $iframe);
                // NEWSBLUR.log(['Fetching story', s, story.story_title, $story]);
                
                setTimeout(function() {
                    if ((stories.length-1) >= (s+1) 
                        && (s < 3
                            || ((self.cache.iframe_stories[stories[s].id] 
                                 && self.cache.iframe_stories[stories[s].id].length)
                                || (self.cache.iframe_stories[stories[s-1].id] 
                                    && self.cache.iframe_stories[stories[s-1].id].length)
                                || (self.cache.iframe_stories[stories[s-2].id] 
                                    && self.cache.iframe_stories[stories[s-2].id].length)))) {
                        self.fetch_story_locations_in_story_frame(s+1, false, $iframe);
                        self.flags['iframe_story_locations_fetched'] = false;
                    } else {
                        NEWSBLUR.log(['iFrame view entirely loaded', (s-2) + ' stories', self.cache.iframe_stories]);
                        self.flags['iframe_story_locations_fetched'] = true;
                        self.flags['iframe_fetching_story_locations'] = false;
                        clearInterval(self.flags['iframe_scroll_snapback_check']);
                    }
                }, 20);
            } else if (story && story['story_feed_id'] != this.active_feed) {
                NEWSBLUR.log(['Switched off iframe early']);
            }
        },
        
        open_story_link: function(story, $st) {
            window.open(story['story_permalink'], '_blank');
            window.focus();
        },
        
        mark_story_title_as_selected: function($story_title) {
            var $story_titles = this.$s.$story_titles;
            $('.selected', $story_titles).removeClass('selected');
            // $('.after_selected', $story_titles).removeClass('after_selected');
            $story_title.addClass('selected');
            // $story_title.parent('.story').next('.story').children('a').addClass('after_selected');
        },
        
        mark_story_as_read: function(story_id) {
            var self = this;
            var $story_title = this.find_story_in_story_titles(story_id);
            var feed_id = parseInt($story_title.data('feed_id'), 10) || this.active_feed;
            
            this.model.mark_story_as_read(story_id, feed_id, function(read) {
                self.update_read_count(story_id, feed_id, false, read);
            });
        },
        
        mark_story_as_unread: function(story_id, feed_id) {
            var self = this;
            feed_id = feed_id || this.model.get_story(story_id).story_feed_id;
            
            this.model.mark_story_as_unread(story_id, feed_id, function() {
                self.update_read_count(story_id, feed_id, true);
            });
        },
        
        update_read_count: function(story_id, feed_id, unread, previously_read) {
            // NEWSBLUR.log(['update_read_count', feed_id, unread, previously_read]);
            if (previously_read) return;
            
            var feed                  = this.model.get_feed(feed_id);
            var $feed_list            = this.$s.$feed_list;
            var $feed                 = this.find_feed_in_feed_list(feed_id);
            var $feed_counts          = this.cache.$feed_counts_in_feed_list[feed_id] || $('.feed_counts_floater', $feed);
            var $story_title          = this.find_story_in_story_titles(story_id);
            var $content_pane         = this.$s.$content_pane;
            var $floater              = $('.feed_counts_floater', $content_pane);
            var unread_view           = this.get_unread_view_name();
            
            this.cache.$feed_counts_in_feed_list[feed_id] = $feed_counts;

            $story_title.toggleClass('read', !unread);
            // NEWSBLUR.log(['marked read', feed.ps, feed.nt, feed.ng, $story_title.is('.NB-story-positive'), $story_title.is('.NB-story-neutral'), $story_title.is('.NB-story-negative')]);
            
            if ($story_title.is('.NB-story-positive')) {
                var count = Math.max(feed.ps + (unread?1:-1), 0);
                feed.ps = count;
                $('.unread_count_positive', $feed).text(count);
                $('.unread_count_positive', $content_pane).text(count);
                if (count == 0) {
                    $feed.removeClass('unread_positive');
                    $feed_counts.removeClass('unread_positive');
                } else {
                    $feed.addClass('unread_positive');
                    $feed_counts.addClass('unread_positive');
                }
            } else if ($story_title.is('.NB-story-neutral')) {
                var count = Math.max(feed.nt + (unread?1:-1), 0);
                feed.nt = count;
                $('.unread_count_neutral', $feed).text(count);
                $('.unread_count_neutral', $content_pane).text(count);
                if (count == 0) {
                    $feed.removeClass('unread_neutral');
                    $feed_counts.removeClass('unread_neutral');
                } else {
                    $feed.addClass('unread_neutral');
                    $feed_counts.addClass('unread_neutral');
                }
            } else if ($story_title.is('.NB-story-negative')) {
                var count = Math.max(feed.ng + (unread?1:-1), 0);
                feed.ng = count;
                $('.unread_count_negative', $feed).text(count);
                $('.unread_count_negative', $content_pane).text(count);
                if (count == 0) {
                    $feed.removeClass('unread_negative');
                    $feed_counts.removeClass('unread_negative');
                } else {
                    $feed.addClass('unread_negative');
                    $feed_counts.addClass('unread_negative');
                }
            }
            
            _.defer(function() {
              $floater.animate({'opacity': 1}, {'duration': 250, 'queue': false});
              _.delay(function() {
                  $floater.animate({'opacity': .1}, {'duration': 250, 'queue': false});
              }, 400);
            });
            
            if (!$feed.is(':visible') || this.model.preference('folder_counts')) {
                var $folder_title = $feed.closest('li.folder:visible').children('.folder_title');
                var $children = $folder_title.closest('li.folder').children('ul.folder, .feed');
                this.show_collapsed_folder_count($folder_title, $children);
            }
            
            if ((unread_view == 'positive' && feed.ps == 0) ||
                (unread_view == 'neutral' && feed.ps == 0 && feed.nt == 0) ||
                (unread_view == 'negative' && feed.ps == 0 && feed.nt == 0 && feed.ng == 0)) {
                  _.delay(function() {
                    $floater.animate({
                      'top': $('#story_taskbar').height()
                    }, {
                      'duration': 500, 
                      'queue': false,
                      'easing': 'easeOutQuint'
                    });
                  }, 500);
            }
            
            this.update_header_counts(true);
        },
        
        mark_feed_as_read: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            this.mark_feed_as_read_update_counts(feed_id);

            this.model.mark_feed_as_read([feed_id]);
            this.update_header_counts(true);
            if (this.model.preference('folder_counts')) {
                var $feed = this.find_feed_in_feed_list(feed_id);
                var $folder_title = $feed.closest('li.folder:visible').children('.folder_title');
                var $children = $folder_title.closest('li.folder').children('ul.folder, .feed');
                this.show_collapsed_folder_count($folder_title, $children);
            }
        },
        
        mark_folder_as_read: function(folder_name, $folder) {
            $folder = $folder || this.get_current_folder();
            folder_name = folder_name || $('.folder_title_text', $folder).eq(0).text();
            var feeds = this.get_feed_ids_in_folder($folder);
            
            _.each(feeds, _.bind(function(feed_id) {
                this.mark_feed_as_read_update_counts(feed_id);
            }, this));
            this.mark_feed_as_read_update_counts(null, $folder);
            this.model.mark_feed_as_read(feeds);
            this.update_header_counts(true);
            
            if (_.includes(this.active_feed, folder_name)) {
                $('.story:not(.read)', this.$s.$story_titles).addClass('read');
                _.each(this.model.stories, _.bind(function(story) {
                    this.mark_story_as_read_in_feed_view(story);
                }, this));
            }
        },
        
        mark_feed_as_read_update_counts: function(feed_id, $folder) {
            if (feed_id) {
                var feed = this.model.get_feed(feed_id);
                if (!feed) return;
                var $feed = this.find_feed_in_feed_list(feed_id);
                var $feed_counts = $('.feed_counts_floater', $feed);
                var $content_pane = this.$s.$content_pane;
                var $story_titles = this.$s.$story_titles;

                feed.ps = 0;
                feed.nt = 0;
                feed.ng = 0;
                $('.unread_count_neutral', $feed).text(0);
                $('.unread_count_positive', $feed).text(0);
                $('.unread_count_negative', $feed).text(0);
                if (feed_id == this.active_feed) {
                    $('.unread_count_neutral', $content_pane).text(0);
                    $('.unread_count_positive', $content_pane).text(0);
                    $('.unread_count_negative', $content_pane).text(0);
                    $('.story:not(.read)', $story_titles).addClass('read');
                }
                $feed.removeClass('unread_neutral');
                $feed.removeClass('unread_positive');
                $feed.removeClass('unread_negative');
                $feed_counts.removeClass('unread_neutral');
                $feed_counts.removeClass('unread_positive');
                $feed_counts.removeClass('unread_negative');
            }
            
            if ($folder) {
                $('.unread_count_neutral', $folder).text(0);
                $('.unread_count_positive', $folder).text(0);
                $('.unread_count_negative', $folder).text(0);
                $feed_counts = $('.feed_counts_floater', $folder);
                $feed_counts.removeClass('unread_neutral');
                $feed_counts.removeClass('unread_positive');
                $feed_counts.removeClass('unread_negative');
            }
        },
        
        open_story_trainer: function(story_id, feed_id) {
            story_id = story_id || this.get_current_story_id();
            feed_id = feed_id || (story_id && this.model.get_story(story_id).story_feed_id);
            
            if (story_id && feed_id) {
                NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierStory(story_id, feed_id, {
                    'feed_loaded': !this.flags['river_view']
                });
            }
        },
        
        mark_story_as_starred: function(story_id, $story) {
            var story = this.model.get_story(story_id);
            var $star = $('.NB-storytitles-star', $story);
            $story.addClass('NB-story-starred');
            $star.attr({'title': 'Saved!'});
            $star.tipsy({
                gravity: 'sw',
                fade: true,
                trigger: 'manual',
                offsetOpposite: -1
            });
            $star.tipsy('enable');
            $star.tipsy('show');
            _.delay(function() {
                $star.tipsy('hide');
                $star.tipsy('disable');
            }, 850);
            this.model.mark_story_as_starred(story_id, story.story_feed_id, function() {});
            this.update_starred_count();
        },
        
        mark_story_as_unstarred: function(story_id, $story) {
            var $star = $('.NB-storytitles-star', $story);
            $story.one('mouseout', function() {
                $story.removeClass('NB-unstarred');
            });
            $star.attr({'title': 'Removed'});
            $star.tipsy({
                gravity: 'sw',
                fade: true,
                trigger: 'manual',
                offsetOpposite: -1
            });
            $star.tipsy('enable');
            $star.tipsy('show');
            _.delay(function() {
                $star.tipsy('hide');
                $star.tipsy('disable');
            }, 850);
            $story.removeClass('NB-story-starred');
            this.model.mark_story_as_unstarred(story_id, function() {});
            this.update_starred_count();
        },
        
        send_story_to_instapaper: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.instapaper.com/edit';
            var instapaper_url = [
              url,
              '?url=',
              encodeURIComponent(story.story_permalink),
              '&title=',
              encodeURIComponent(story.story_title)
            ].join('');
            window.open(instapaper_url, '_blank');
            this.mark_story_as_read(story_id);
        },
        
        send_story_to_readitlater: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://readitlaterlist.com/save';
            var readitlater_url = [
              url,
              '?url=',
              encodeURIComponent(story.story_permalink),
              '&title=',
              encodeURIComponent(story.story_title)
            ].join('');
            window.open(readitlater_url, '_blank');
            this.mark_story_as_read(story_id);
        },
        
        send_story_to_readability: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://readability.com/save';
            var readability_url = [
              url,
              '?url=',
              encodeURIComponent(story.story_permalink),
              '&title=',
              encodeURIComponent(story.story_title)
            ].join('');
            window.open(readability_url, '_blank');
            this.mark_story_as_read(story_id);
        },
        
        send_story_to_twitter: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://twitter.com/';
            var twitter_url = [
              url,
              '?status=',
              encodeURIComponent(story.story_title),
              ': ',
              encodeURIComponent(story.story_permalink)
            ].join('');
            window.open(twitter_url, '_blank');
            this.mark_story_as_read(story_id);
        },
        
        send_story_to_facebook: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.facebook.com/sharer.php?src=newsblur&v=3.14159265&i=1.61803399';
            var facebook_url = [
              url,
              '&u=',
              encodeURIComponent(story.story_permalink),
              '&t=',
              encodeURIComponent(story.story_title)
            ].join('');
            window.open(facebook_url, '_blank');
            this.mark_story_as_read(story_id);
        },
        
        send_story_to_email: function(story_id) {
            NEWSBLUR.reader_send_email = new NEWSBLUR.ReaderSendEmail(story_id);
            this.mark_story_as_read(story_id);
        },
        
        // =====================
        // = Story Titles Pane =
        // =====================
        
        hide_content_pane_feed_counter: function() {
            var $content_pane = this.$s.$content_pane;
            $('.feed_counts_floater', $content_pane).remove();
        },
        
        make_content_pane_feed_counter: function(feed_id) {
            var $content_pane = this.$s.$content_pane;
            feed_id = feed_id || this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var $counter = this.make_feed_counts_floater(feed.ps, feed.nt, feed.ng);
            $counter.css({'opacity': 0});
            
            $('.feed_counts_floater', $content_pane).remove();
            this.$s.$story_taskbar.append($counter);
            _.delay(function() {
                $counter.animate({'opacity': .1}, {'duration': 1000, 'queue': false});
            }, 500);
            
            $('.unread_count', $content_pane).corner('4px');
            
            // Center the counter
            var i_width = $('.feed_counts_floater', $content_pane).width();
            var o_width = $content_pane.width();
            var left = (o_width / 2.0) - (i_width / 2.0);
            $('.feed_counts_floater', $content_pane).css({'left': left});
        },
        
        create_story_titles: function(stories, options) {
            var $story_titles = this.$s.$story_titles;
            options = options || {};
            
            for (s in stories) {
                if (this.flags['non_premium_river_view'] && $story_titles.children(':visible').length >= this.constants.RIVER_STORIES_FOR_STANDARD_ACCOUNT) {
                    this.append_story_titles_endbar();
                    break;
                }
                var story = stories[s];
                var $story_title = this.make_story_title(story, options);
                $story_titles.append($story_title);
            }
            if (!stories || stories.length == 0) {
                this.append_story_titles_endbar();
            }
            
            this.hover_story_titles();
        },
        
        make_story_title: function(story, options) {
            var unread_view = this.model.preference('unread_view');
            var read = story.read_status
                ? ' read '
                : '';
            var score = NEWSBLUR.utils.compute_story_score(story);
            var score_color = 'neutral';
            var starred = story.starred ? ' NB-story-starred ' : '';
            if (options.river_stories) {
                var feed = this.model.get_feed(story.story_feed_id);
            }
            if (score > 0) score_color = 'positive';
            if (score < 0) score_color = 'negative';
            var $story_tags = $.make('span', { className: 'NB-storytitles-tags'});
            
            for (var t in story.story_tags) {
                var tag = story.story_tags[t];
                var $tag = $.make('span', { className: 'NB-storytitles-tag'}, tag).corner('4px');
                $story_tags.append($tag);
                break;
            }
            var $story_title = $.make('div', { className: 'story ' + read + starred + 'NB-story-' + score_color }, [
                $.make('div', { className: 'NB-storytitles-sentiment'}),
                $.make('a', { href: story.story_permalink, className: 'story_title' }, [
                    (options['river_stories'] && feed &&
                        $.make('div', { className: 'NB-story-feed' }, [
                            $.make('img', { className: 'feed_favicon', src: $.favicon(feed.favicon) }),
                            $.make('span', { className: 'feed_title' }, feed.feed_title)
                        ])),
                    $.make('div', { className: 'NB-storytitles-star'}),
                    $.make('span', { className: 'NB-storytitles-title' }, story.story_title),
                    $.make('span', { className: 'NB-storytitles-author' }, story.story_authors),
                    $story_tags
                ]),
                $.make('span', { className: 'story_date' }, story.short_parsed_date),
                $.make('span', { className: 'story_id' }, ''+story.id),
                $.make('div', { className: 'NB-story-manage-icon' })
            ]).data('story_id', story.id).data('feed_id', story.story_feed_id);
            
            if (unread_view > score) {
                $story_title.css({'display': 'none'});
            }
          
            if (this.model.preference('show_tooltips')) {
                $('.NB-story-sentiment', $story_title).tipsy({
                    delayIn: 375,
                    gravity: 's'
                });
            }
            
            return $story_title;
        },
        
        hover_story_titles: function() {
            var $story_titles = $('#story_titles .story,.NB-feedbar .feed');
            $story_titles.unbind('mouseenter').unbind('mouseleave');
            
            $story_titles.hover(function() {
                var $this = $(this);
                var menu_height = $this.hasClass('story') ? 150 : 270;

                if ($this.offset().top > $(window).height() - menu_height) {
                    $this.addClass('NB-hover-inverse');
                } 
            }, function() {
                $(this).removeClass('NB-hover-inverse');
            });
        },
        
        story_titles_clear_loading_endbar: function() {
            var $story_titles = this.$s.$story_titles;
            
            var $endbar = $('.NB-story-titles-end-stories-line', $story_titles);
            if ($endbar.length) {
                $endbar.remove();
                clearInterval(this.feed_stories_loading);
            }
        },
        
        recalculate_story_scores: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            this.model.recalculate_story_scores(feed_id);
            
            var replace_stories = _.bind(function($story, story_id) {
                var story = this.model.get_story(story_id);
                if (story.story_feed_id != feed_id) return;
                var score = NEWSBLUR.utils.compute_story_score(story);
                $story.removeClass('NB-story-positive')
                      .removeClass('NB-story-neutral')
                      .removeClass('NB-story-negative');
                if (score > 0) {
                    $story.addClass('NB-story-positive');
                } else if (score == 0) {
                    $story.addClass('NB-story-neutral');
                } else if (score < 0) {
                    $story.addClass('NB-story-negative');
                }
                NEWSBLUR.log(['story recalculation', story, story.read_status, $story]);
                // $story.toggleClass('read', !story.read_status);
                $('.NB-feed-story-tags', $story).replaceWith(this.make_story_feed_tags(story));
                $('.NB-feed-story-author', $story).replaceWith(this.make_story_feed_author(story));
                $('.NB-feed-story-title', $story).replaceWith(this.make_story_feed_title(story));
                
                if (this.model.preference('new_window') == 1) {
                    $('a', $story).attr('target', '_blank');
                }
            }, this);
            
            _.each(this.cache.feed_view_stories, _.bind(function($story, story_id) { 
                replace_stories($story, story_id);
            }));
            
            $('.story', this.$s.$story_titles).each(function() {
                var $story = $(this);
                var story_id = $story.data('story_id');
                replace_stories($story, story_id);
            });
        },
        
        // =================================
        // = Story Pane - iFrame/Page View =
        // =================================
        
        unload_feed_iframe: function() {
            var $feed_iframe = this.$s.$feed_iframe;
            var $taskbar_view_page = $('.NB-taskbar .task_view_page');
            $taskbar_view_page.removeClass('NB-disabled');
            $taskbar_view_page.removeClass('NB-task-return');
            
            this.flags['iframe_view_loaded'] = false;
            this.flags['iframe_story_locations_fetched'] = false;
            this.flags['iframe_prevented_from_loading'] = false;
            
            $.extend(this.cache, {
                'iframe_stories': {},
                'iframe_story_positions': {},
                'iframe_story_positions_keys': []
            });
            
            $feed_iframe.removeAttr('src');
            $feed_iframe.empty();
            
            this.$s.$story_iframe.attr('src', '');
            this.$s.$story_iframe.empty();
        },
        
        load_feed_iframe: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            var self = this;
            var $feed_view = this.$s.$story_pane;
            var $feed_iframe = this.$s.$feed_iframe;
            
            this.unload_feed_iframe();
            
            if (!feed_id) {
                feed_id = $feed_iframe.data('feed_id');
            } else {
                $feed_iframe.data('feed_id', feed_id);
            }
            
            this.flags.iframe_scroll_snap_back_prepared = true;
            this.iframe_link_attacher_num_links = 0;
            
            $feed_iframe.removeAttr('src').attr({src: '/reader/page/'+feed_id});

            if (this.flags['iframe_view_loaded']) {
                // NEWSBLUR.log(['Titles loaded, iframe loaded']);
                var $iframe = this.$s.$feed_iframe.contents();
                this.fetch_story_locations_in_story_frame(0, true, $iframe);
            } else {
                // NEWSBLUR.log(['Titles loaded, iframe NOT loaded -- prefetching now']);
                _.delay(_.bind(function() {
                    this.prefetch_story_locations_in_story_frame();
                }, this), 500);
            }

            $feed_iframe.ready(function() {

                setTimeout(function() {
                    $feed_iframe.load(function() {
                        self.return_to_snapback_position(true);
                    });
                }, 50);
                self.flags['iframe_scroll_snapback_check'] = setInterval(function() {
                    // NEWSBLUR.log(['Checking scroll', self.iframe_scroll, self.flags.iframe_scroll_snap_back_prepared]);
                    if (self.iframe_scroll && self.flags.iframe_scroll_snap_back_prepared) {
                        self.return_to_snapback_position();
                    } else {
                        clearInterval(self.flags['iframe_scroll_snapback_check']);
                    }
                }, 500);
                
                // NEWSBLUR.log(['iFrame domain', $feed_iframe.attr('src').indexOf('/reader/page?feed_id='+feed_id), $feed_iframe.attr('src')]);
                if ($feed_iframe.attr('src').indexOf('/reader/page/'+feed_id) != -1) {
                    var iframe_link_attacher = function() {
                        var num_links = $feed_iframe.contents().find('a').length;
                        // NEWSBLUR.log(['Finding links', self.iframe_link_attacher_num_links, num_links]);
                        if (self.iframe_link_attacher_num_links != num_links) {
                            // NEWSBLUR.log(['Found new links', num_links, self.iframe_link_attacher_num_links]);
                            self.iframe_link_attacher_num_links = num_links;
                            $feed_iframe.contents().find('a')
                                .unbind('click.NB-taskbar')
                                .bind('click.NB-taskbar', function() {
                                self.taskbar_show_return_to_page();
                            });
                        }
                    };
                    clearInterval(self.iframe_link_attacher);
                    self.iframe_link_attacher = setInterval(iframe_link_attacher, 2000);
                    iframe_link_attacher();
                    $feed_iframe.load(function() {
                        clearInterval(self.iframe_link_attacher);
                    });
                }
            });
        },
        
        return_to_snapback_position: function(iframe_loaded) {
            var $feed_iframe = this.$s.$feed_iframe;
            
            if (this.iframe_scroll
                && this.flags.iframe_scroll_snap_back_prepared 
                && $feed_iframe.contents().scrollTop() == 0) {
                // NEWSBLUR.log(['Snap back, loaded, scroll', this.iframe_scroll]);
                $feed_iframe.contents().scrollTop(this.iframe_scroll);
                if (iframe_loaded) {
                    this.flags.iframe_scroll_snap_back_prepared = false;
                    clearInterval(self.flags['iframe_scroll_snapback_check']);
                }
            }
        },
        
        setup_feed_page_iframe_load: function() {
            var self = this;
            var $story_pane = this.$s.$story_pane;
            var $feed_iframe = this.$s.$feed_iframe;
                
            $feed_iframe.removeAttr('src').load(function() {
                self.flags.iframe_view_loaded = true;
                try {
                    var $iframe_contents = $feed_iframe.contents();
                    $iframe_contents.find('a')
                        .unbind('click.NB-taskbar')
                        .bind('click.NB-taskbar', function(e) {
                        var href = $(this).attr('href');
                        if (href.indexOf('#') == 0) {
                            e.preventDefault();
                            var $footnote = $('a[name='+href.substr(1)+'], [id='+href.substr(1)+']',
                                              $iframe_contents);
                            // NEWSBLUR.log(['Footnote', $footnote, href, href.substr(1)]);
                            $iframe_contents.scrollTo($footnote, { 
                                duration: 600,
                                axis: 'y', 
                                easing: 'easeInOutQuint', 
                                offset: 0, 
                                queue: false 
                            });
                            return false;
                        }
                        self.taskbar_show_return_to_page();
                    });
                    $iframe_contents
                        .unbind('scroll')
                        .scroll($.rescope(self.handle_scroll_feed_iframe, self));
                    $iframe_contents
                        .unbind('mousemove.reader')
                        .bind('mousemove.reader', $.rescope(self.handle_mousemove_iframe_view, self));
                    if (self.flags['story_titles_loaded']) {
                        // NEWSBLUR.log(['iframe loaded, titles loaded']);
                        self.fetch_story_locations_in_story_frame(0, true, $iframe_contents);
                    }
                } catch(e) {
                    // Not on local domain. Ignore.
                }
            });
        },
        
        taskbar_show_return_to_page: function() {
            var self = this;
            var $feed_iframe = $('.NB-feed-frame');

            _.delay(function() {
                var $feed_iframe = $('.NB-feed-frame');
                var $taskbar_view_page = $('.NB-taskbar .task_view_page');
        
                try {
                    NEWSBLUR.log(['return', $feed_iframe.contents().find('body')]);
                    var length = $feed_iframe.contents().find('body').length;
                    if (length) {
                        return false;
                    }
                } catch(e) {
                    $taskbar_view_page.addClass('NB-task-return');    
                } finally {
                    $taskbar_view_page.addClass('NB-task-return');    
                }
            }, 1000);
        },
        
        load_page_of_feed_stories: function(hide_loading) {
            var $story_titles = this.$s.$story_titles;
            var feed_id = $story_titles.data('feed_id');
            var page = $story_titles.data('page');

            if (!this.flags['opening_feed']) {
                
                if (!hide_loading) this.show_feedbar_loading();
                $story_titles.data('page', page+1);
                if (this.active_feed == 'starred') {
                    this.model.fetch_starred_stories(page+1, 
                        _.bind(this.post_open_starred_stories, this), false);
                } else if (this.flags['river_view']) {
                    this.model.fetch_river_stories(this.active_feed, this.cache['river_feeds_with_unreads'],
                        page+1, _.bind(this.post_open_river_stories, this), false);
                } else {
                    this.model.load_feed(feed_id, page+1, false, 
                                         $.rescope(this.post_open_feed, this));                                 
                }
            }
        },
        
        fill_out_story_titles: function() {
            var $last = $('.story:visible:last', this.$s.$story_titles);
            var container_height = this.$s.$story_titles.height();
            var $feedbar = $('.NB-story-titles-end-stories-line');
            // console.log(['fill_out_story_titles', $last.length, $last, $('#story_titles').scrollTop(), this.constants.FILL_OUT_PAGES, this.counts['page_fill_outs'], $last.length && $last.position().top, $last.length && $last.height(), container_height]);
            if (!$feedbar.length && 
                ($last.length == 0 ||
                 ($('#story_titles').scrollTop() == 0 && 
                  $last.position().top + $last.height() - 13 < container_height))) {
                if (this.counts['page_fill_outs'] < this.constants.FILL_OUT_PAGES) {
                    this.counts['page_fill_outs'] += 1;
                    _.delay(_.bind(this.load_page_of_feed_stories, this, true), 250);
                } else {
                    this.append_story_titles_endbar();
                }
            }
        },
        
        show_feedbar_loading: function() {
            var $story_titles = this.$s.$story_titles;
            var $feedbar = $('.NB-story-titles-end-stories-line');
            
            if (!$feedbar.length) {
                $feedbar = $.make('div', { className: 'NB-story-titles-end-stories-line' });
            }
            $feedbar.css({'background': '#E1EBFF'});
            $story_titles.append($feedbar);
            
            $feedbar.animate({'backgroundColor': '#5C89C9'}, {'duration': 750})
                    .animate({'backgroundColor': '#E1EBFF'}, 750);
            this.feed_stories_loading = setInterval(function() {
                $feedbar.animate({'backgroundColor': '#5C89C9'}, {'duration': 750})
                        .animate({'backgroundColor': '#E1EBFF'}, 750);
            }, 1500);
        },
        
        show_feed_title_in_stories: function(feed_id) {
            var $story_titles = this.$s.$story_titles;
            var feed = this.model.get_feed(feed_id);
            if (!feed) return;

            var $feedbar = $.make('div', { className: 'NB-feedbar' }, [
                $(this.make_feed_title_template(feed, 'story')),
                // $.make('div', { className: 'NB-feedbar-intelligence' }, [
                //     $.make('div', { className: 'NB-feed-sentiment NB-feed-like', title: 'What I like about this site...' }),
                //     $.make('div', { className: 'NB-feed-sentiment NB-feed-dislike', title: 'What I dislike about this site...' })
                // ]),
                $.make('span', { className: 'feed_id' }, ''+feed.id)
            ]).hover(function() {
                $(this).addClass('NB-feedbar-hover');
            },function() {
                $(this).removeClass('NB-feedbar-hover');
            });
            
            if (this.model.preference('show_tooltips')) {
                $('.NB-feedbar-train-feed, .NB-feedbar-statistics', $feedbar).tipsy({
                    gravity: 's',
                    delayIn: 375
                });
            }
            
            $story_titles.prepend($feedbar);
            $('.unread_count', $feedbar).corner('4px');
        },
        
        show_feed_hidden_story_title_indicator: function(is_feed_load) {
            if (is_feed_load && this.flags['unread_threshold_temporarily']) return;
            else this.flags['unread_threshold_temporarily'] = null;
            
            var $story_titles = this.$s.$story_titles;
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var unread_view_name = this.get_unread_view_name();
            var $indicator = $('.NB-story-title-indicator', $story_titles);
            var hidden_stories = _.any(this.model.stories, _.bind(function(story) {
                var score = NEWSBLUR.utils.compute_story_score(story);

                if (unread_view_name == 'positive') return score <= 0;
                else if (unread_view_name == 'neutral') return score < 0;
            }, this));
            
            if (hidden_stories) {
                if ($indicator.length) {
                    var $counts = this.make_feed_counts_floater(feed.ps, feed.nt, feed.ng);
                    $('.feed_counts_floater', $indicator).replaceWith($counts);
                    this.cache.$feed_counts_in_feed_list[feed_id] = null;
                    $indicator.css({'opacity': 1});
                } else if (feed) {
                    $indicator = $.make('div', { className: 'NB-story-title-indicator' }, [
                        this.make_feed_counts_floater(feed.ps, feed.nt, feed.ng),
                        $.make('span', { className: 'NB-story-title-indicator-text' }, 'show hidden stories')
                    ]).css({
                        'opacity': 0
                    });
                    $('.NB-feedbar .feed .feed_title', this.$story_titles).prepend($indicator);
                    _.delay(function() {
                        $indicator.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeOutCubic'});
                    }, 500);
                }
            
                $indicator.removeClass('unread_threshold_positive')
                          .removeClass('unread_threshold_neutral')
                          .removeClass('unread_threshold_negative')
                          .addClass('unread_threshold_'+unread_view_name);
            }
        },
        
        check_story_titles_last_story: function() {
            var $story_titles = this.$s.$story_titles;

            if (!($('.NB-story-titles-end-stories-line', $story_titles).length)) {
                var $last_story = $('#story_titles .story').last();
                var container_offset = $story_titles.position().top;
                var full_height = ($last_story.offset() && $last_story.offset().top) + $last_story.height() - container_offset;
                var visible_height = $('#story_titles').height();
                var scroll_y = $('#story_titles').scrollTop();
                // NEWSBLUR.log(['Story_titles Scroll', full_height, container_offset, visible_height, scroll_y]);
            
                // Fudge factor is simply because it looks better at 13 pixels off.
                if ((visible_height + 13) >= full_height) {
                    this.load_page_of_feed_stories();
                }
            }
        },
        
        show_hidden_story_titles: function() {
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var $indicator = $('.NB-story-title-indicator', this.$s.$story_titles);
            var unread_view_name = $indicator.hasClass('unread_threshold_positive') ?
                                   'positive' :
                                   'neutral';
            var hidden_stories_at_threshold = _.any(this.model.stories, _.bind(function(story) {
                var score = NEWSBLUR.utils.compute_story_score(story);

                if (unread_view_name == 'positive') return score == 0;
                else if (unread_view_name == 'neutral') return score < 0;
            }, this));
            var hidden_stories_below_threshold = unread_view_name == 'positive' && 
                                                 _.any(this.model.stories, _.bind(function(story) {
                var score = NEWSBLUR.utils.compute_story_score(story);
                return score < 0;
            }, this));
            
            // NEWSBLUR.log(['show_hidden_story_titles', hidden_stories_at_threshold, hidden_stories_below_threshold, unread_view_name]);
            
            // First click, open neutral. Second click, open negative.
            if (unread_view_name == 'positive' && hidden_stories_at_threshold && hidden_stories_below_threshold) {
                this.flags['unread_threshold_temporarily'] = 'neutral';
                this.show_story_titles_above_intelligence_level({
                    'unread_view_name': 'neutral',
                    'animate': true,
                    'follow': true,
                    'temporary': true
                });
                $indicator.removeClass('unread_threshold_positive').addClass('unread_threshold_neutral');
            } else {
                this.flags['unread_threshold_temporarily'] = 'negative';
                this.show_story_titles_above_intelligence_level({
                    'unread_view_name': 'negative',
                    'animate': true,
                    'follow': true,
                    'temporary': true
                });
                $indicator.removeClass('unread_threshold_positive')
                          .removeClass('unread_threshold_neutral')
                          .addClass('unread_threshold_negative');
                $indicator.animate({'opacity': 0}, {'duration': 500});
            }
        },
        
        open_feed_link: function(feed_id, $fd) {
            if (!feed_id) feed_id = this.active_feed;
            this.mark_feed_as_read(feed_id);
            var feed = this.model.get_feed(feed_id);
            window.open(feed['feed_link'], '_blank');
            // window.focus();
        },
        
        open_story_in_new_tab: function(story_id, $t) {
            story_id = story_id || this.get_current_story_id();
            if (story_id) {
                var story = this.model.get_story(story_id);
                window.open(story['story_permalink'], '_blank');
                window.focus();
            }
        },
        
        open_unread_stories_in_tabs: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            if (this.active_feed == feed_id) {
                this.flags['open_unread_stories_in_tabs'] = false;
                _.each(this.model.stories, function(story) {
                    NEWSBLUR.log(['story', story, !story.read_status]);
                    if (!story.read_status) {
                        window.open(story['story_permalink'], '_blank');
                        window.focus();
                    }
                });
                this.mark_feed_as_read(feed_id);
            } else {
                this.flags['open_unread_stories_in_tabs'] = true;
                var $feed = this.find_feed_in_feed_list(feed_id);
                this.open_feed(feed_id, false, $feed);
            }
        },
        
        mark_feed_as_selected: function(feed_id, $feed_link) {
            if ($feed_link === undefined) {
              $feed_link = $('.feed.selected', this.$feed_list).eq(0);
            }
            
            $('#feed_list .selected').removeClass('selected');
            $('#feed_list .after_selected').removeClass('after_selected');
            if ($feed_link) {
                $feed_link.addClass('selected');
                $feed_link.parent('.feed').next('.feed').children('a').addClass('after_selected');
            }
        },
        
        open_feed_intelligence_modal: function(score, feed_id, feed_loaded) {
            feed_id = feed_id || this.active_feed;
            
            if (feed_id) {
                NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierFeed(feed_id, {
                    'score': score,
                    'feed_loaded': feed_loaded
                });
            }
        },
        
        open_trainer_modal: function(score) {
            var feed_id = this.active_feed;

            // NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierFeed(feed_id, {'score': score});
            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierTrainer({'score': score});
        },
        
        open_recommend_modal: function(feed_id) {
            NEWSBLUR.recommend_feed = new NEWSBLUR.ReaderRecommendFeed(feed_id);
        },
        
        open_tutorial_modal: function() {
            NEWSBLUR.tutorial = new NEWSBLUR.ReaderTutorial();
        },
        
        hide_tutorial: function() {
          var $tutorial = $('.NB-module-tutorial');
          
          this.model.preference('tutorial_finished', true);
          $tutorial.animate({
            'opacity': 0
          }, {
            'duration': 500,
            'complete': function() {
              $tutorial.slideUp(350);
            }
          });
        },
        
        hide_mobile: function() {
          var $mobile = $('.NB-module-mobile');
          
          this.model.preference('hide_mobile', true);
          $mobile.animate({
            'opacity': 0
          }, {
            'duration': 500,
            'complete': function() {
              $mobile.slideUp(350);
            }
          });
        },
        
        // ==========================
        // = Story Pane - Feed View =
        // ==========================
        
        make_story_feed_entries: function(stories, first_load, options) {
            var $feed_view = this.$s.$feed_view;
            var $stories = this.$s.$feed_stories;
            var self = this;
            var unread_view = this.model.preference('unread_view');
            var river_same_feed;
            var feed = this.model.get_feed(this.active_feed);
            
            options = options || {};
            
            if (first_load && !options.refresh_load) {
                $('.NB-feed-story-endbar', $feed_view).remove();
            }

            for (var s in stories) {
                if (this.flags['non_premium_river_view'] && $stories.children(':visible').length >= this.constants.RIVER_STORIES_FOR_STANDARD_ACCOUNT) {
                    this.append_story_titles_endbar();
                    this.append_river_premium_only_notification();
                    break;
                }
                
                var story = stories[s];
                var story_has_modifications = false;
                if (options.river_stories) feed = this.model.get_feed(story.story_feed_id);
                var read = story.read_status
                    ? ' read '
                    : '';
                var score = NEWSBLUR.utils.compute_story_score(story);
                var score_color = 'neutral';
                var river_stories = options['river_stories']
                    ? ' NB-river-story '
                    : '';
                if (score > 0) score_color = 'positive';
                if (score < 0) score_color = 'negative';
                if (story.story_content.indexOf('<ins') != -1) story_has_modifications = true;
                if (!story_has_modifications && this.model.preference('hide_story_changes')) {
                  if (story.story_content.indexOf('<del') != -1) story_has_modifications = true;
                }
                
                river_same_feed = "";
                if (this.cache.last_feed_view_story_feed_id == story.story_feed_id) {
                    river_same_feed = 'NB-feed-story-river-same-feed';
                }
                var $story = $.make('li', { className: 'NB-feed-story ' + read + river_stories + ' NB-story-' + score_color }, [
                    $.make('div', { className: 'NB-feed-story-header' }, [
                        $.make('div', { className: 'NB-feed-story-header-feed' }, [
                            (options.river_stories && feed && // !river_same_feed
                                $.make('div', { className: 'NB-feed-story-feed' }, [
                                   $.make('img', { className: 'feed_favicon', src: $.favicon(feed.favicon) }),
                                   $.make('span', { className: 'feed_title' }, feed.feed_title)
                                ])
                            )
                        ]).css('background-image', NEWSBLUR.utils.generate_gradient(feed, 'webkit'))
                          .css('background-image', NEWSBLUR.utils.generate_gradient(feed, 'moz'))
                          .css('borderBottom', NEWSBLUR.utils.generate_gradient(feed, 'border'))
                          .css('borderTop', NEWSBLUR.utils.generate_gradient(feed, 'border'))
                          .toggleClass('NB-inverse', NEWSBLUR.utils.is_feed_floater_gradient_light(feed)),
                        $.make('div', { className: 'NB-feed-story-header-info' }, [
                            (story.story_authors &&
                                this.make_story_feed_author(story)),
                            (story.story_tags && story.story_tags.length && this.make_story_feed_tags(story)),
                            $.make('div', { className: 'NB-feed-story-title-container' }, [
                                $.make('div', { className: 'NB-feed-story-sentiment' }),
                                $.make('div', { className: 'NB-feed-story-manage-icon' }),
                                // $.make('div', { className: 'NB-feed-story-sentiment NB-feed-story-sentiment-animate' }),
                                this.make_story_feed_title(story)
                            ]),
                            (story.long_parsed_date &&
                                $.make('span', { className: 'NB-feed-story-date' }, [
                                    (story_has_modifications && $.make('div', { 
                                      className: 'NB-feed-story-hide-changes', 
                                      title: (this.model.preference('hide_story_changes') ?
                                             'Show' : 'Hide') + ' story modifications' 
                                    })),
                                    story.long_parsed_date
                                ])),
                            (story.starred_date &&
                                $.make('span', { className: 'NB-feed-story-starred-date' }, story.starred_date))
                        ])
                    ]),
                    $.make('div', { className: 'NB-feed-story-content' }, story.story_content)                
                ]).data('story', story.id).data('story_id', story.id).data('feed_id', story.story_feed_id);
                
                if (story_has_modifications && this.model.preference('show_tooltips')) {
                    $('.NB-feed-story-hide-changes', $story).tipsy({
                        delayIn: 375
                    });
                }
                if (story_has_modifications && this.model.preference('hide_story_changes')) {
                    $('ins', $story).css({'text-decoration': 'none'});
                    $('del', $story).css({'display': 'none'});
                }
                if (this.model.preference('new_window') == 1) {
                    $('a', $story).attr('target', '_blank');
                }
                
                if (options.refresh_load) {
                    $stories.prepend($story);
                } else {
                    $stories.append($story);
                }

                this.cache.last_feed_view_story_feed_id = story.story_feed_id;
                this.cache.feed_view_stories[story.id] = $story;
                
                var image_count = $('img', $story).length;
                if (!image_count) {
                    this.flags.feed_view_images_loaded[story.id] = true;
                } else {
                    // Progressively load the images in each story, so that when one story
                    // loads, the position is calculated and the next story can calculate
                    // its position (atfer its own images are loaded).
                    this.flags.feed_view_images_loaded[story.id] = false;
                    (function($story, story, image_count) {
                        $('img', $story).load(function() {
                            // NEWSBLUR.log(['Loaded image', $story, story, image_count]);
                            if (image_count == 1) {
                                self.flags.feed_view_images_loaded[story.id] = true;
                            } else {
                                image_count--;
                            }
                            return true;
                        });
                    })($story, story, image_count);
                }
            }
            
            if (!stories || !stories.length) {
                this.fetch_story_locations_in_feed_view();
            }
            
            this.append_feed_view_story_endbar();
            this.hover_story_feed_titles();
            if (first_load) this.show_stories_preference_in_feed_view(true);
        },
        
        make_story_feed_title: function(story) {
            var title = story.story_title;
            var feed_titles = this.model.classifiers[story.story_feed_id] && 
                              this.model.classifiers[story.story_feed_id].titles ||
                              [];
            
            _.each(feed_titles, function(score, title_classifier) {
                if (title.indexOf(title_classifier) != -1) {
                    title = title.replace(title_classifier, '<span class="NB-score-'+score+'">'+title_classifier+'</span>');
                }
            });
            return $.make('a', { className: 'NB-feed-story-title', href: story.story_permalink }, title);
        },
        
        make_story_feed_author: function(story) {
            var score = this.model.classifiers[story.story_feed_id] && 
                        this.model.classifiers[story.story_feed_id].authors[story.story_authors];

            return $.make('div', { 
                className: 'NB-feed-story-author ' + (!!score && 'NB-score-'+score || '') 
            }, story.story_authors).data('author', story.story_authors);
        },
        
        make_story_feed_tags: function(story) {
            var feed_tags = this.model.classifiers[story.story_feed_id] && 
                            this.model.classifiers[story.story_feed_id].tags ||
                            {};

            return $.make('div', { className: 'NB-feed-story-tags' }, 
                _.map(story.story_tags, function(tag) { 
                    var score = feed_tags[tag];
                    return $.make('div', { 
                        className: 'NB-feed-story-tag ' + (!!score && 'NB-score-'+score || '')
                    }, tag).data('tag', tag); 
                }));
        },
        
        hover_story_feed_titles: function() {
            var $story_titles = $('.NB-feed-story-header-info');
            $story_titles.unbind('mouseenter').unbind('mouseleave');
            
            $story_titles.hover(function() {
                var $this = $(this);
                var menu_height = $this.hasClass('story') ? 150 : 270;
                if ($this.offset().top > $(window).height() - menu_height) {
                    $this.closest('.NB-feed-story').addClass('NB-hover-inverse');
                } 
            }, function() {
                $(this).closest('.NB-feed-story').removeClass('NB-hover-inverse');
            });
        },
        

        
        preserve_classifier_color: function($story, classifier_type, value, score) {
            var $t;
            $('.NB-feed-story-'+classifier_type, $story).each(function() {
                if ($(this).data(classifier_type) == value) {
                    $t = $(this);
                    return false;
                }
            });
            $t.removeClass('NB-score-now-1')
              .removeClass('NB-score-now--1')
              .removeClass('NB-score-now-0')
              .addClass('NB-score-now-'+score)
              .one('mouseleave', function() {
                  $t.removeClass('NB-score-now-'+score);
              });
              _.defer(function() {
                  $t.one('mouseenter', function() {
                      $t.removeClass('NB-score-now-'+score);
                  });
              });
        },
        
        save_classifier: function(type, value, score, feed_id, callback) {
            var data = {
                'feed_id': feed_id
            };
            if (score == 0) {
                data['remove_like_'+type] = value;
            } else if (score == 1) {
                data['like_'+type] = value;
            } else if (score == -1) {
                data['dislike_'+type] = value;
            }
            
            this.model.classifiers[feed_id][type+'s'][value] = score;
            this.model.save_classifier(data, _.bind(function(resp) {
                this.force_feeds_refresh(callback, true, feed_id);
            }, this));
            this.recalculate_story_scores(feed_id);
        },
        
        show_correct_feed_in_feed_title_floater: function(story) {
            var $story, $header;
            
            if (story && this.cache.feed_title_floater_feed_id != story.story_feed_id) {
                var $feed_floater = this.$s.$feed_floater;
                $story = this.find_story_in_feed_view(story);
                $header = $('.NB-feed-story-header-feed', $story);
                var $new_header = $header.clone();
                
                if (!$new_header.find('.NB-feed-story-feed').length) {
                  var feed = this.model.get_feed(story.story_feed_id);
                  feed && $new_header.append($.make('div', { className: 'NB-feed-story-feed' }, [
                    $.make('img', { className: 'feed_favicon', src: $.favicon(feed.favicon) }),
                    $.make('span', { className: 'feed_title' }, feed.feed_title)
                  ]));
                }
                
                $feed_floater.empty().append($new_header);
                this.cache.feed_title_floater_feed_id = story.story_feed_id;
                $feed_floater.width($header.outerWidth());
            } else if (!story) {
                this.$s.$feed_floater.empty();
                this.cache.feed_title_floater_feed_id = null;
            }
              
            if (story && this.cache.feed_title_floater_story_id != story.id) {
                $story = $story || this.find_story_in_feed_view(story);
                $header = $header || $('.NB-feed-story-header-feed', $story);
                $('.NB-floater').removeClass('NB-floater');
                $header.addClass('NB-floater');
                this.cache.feed_title_floater_story_id = story.id;
            } else if (!story) {
                this.cache.feed_title_floater_story_id = null;
            }
        },
        
        apply_story_styling: function(reset_stories) {
            var $body = this.$s.$body;
            $body.removeClass('NB-theme-sans-serif');
            $body.removeClass('NB-theme-serif');
            
            if (NEWSBLUR.Preferences['story_styling'] == 'sans-serif') {
                $body.addClass('NB-theme-sans-serif');
            } else if (NEWSBLUR.Preferences['story_styling'] == 'serif') {
                $body.addClass('NB-theme-serif');
            }
            
            if (reset_stories) {
                this.show_story_titles_above_intelligence_level({'animate': true, 'follow': true});
            }
        },
        
        hide_story_changes: function($story) {
            var $button = $('.NB-feed-story-hide-changes', $story);
            
            if (this.model.preference('hide_story_changes')) {
                $('ins', $story).css({'text-decoration': 'underline'});
                $('del', $story).css({'display': 'inline'});
            } else {
                $('ins', $story).css({'text-decoration': 'none'});
                $('del', $story).css({'display': 'none'});
            }
            $button.css('opacity', 1).fadeOut(400);
            $button.tipsy('hide').tipsy('disable');
        },
        
        prefetch_story_locations_in_feed_view: function() {
            var self = this;
            var stories = this.model.stories;
            
            // NEWSBLUR.log(['Prefetching', this.flags['feed_view_positions_calculated'], this.flags.feed_view_images_loaded, (_.keys(this.flags.feed_view_images_loaded).length > 0 || this.cache.feed_view_story_positions_keys.length > 0)]);
            if (!this.flags['feed_view_positions_calculated']) {
                
                $.extend(this.cache, {
                    'feed_view_story_positions': {},
                    'feed_view_story_positions_keys': []
                });
            
                for (var s in stories) {
                    var story = stories[s];
                    var $story = self.cache.feed_view_stories[story.id];
                    this.determine_feed_view_story_position($story, story);
                    // NEWSBLUR.log(['Pre-fetching', $story, story.story_title, this.flags.feed_view_images_loaded[story.id]]);
                    if (!$story || !$story.length || this.flags['feed_view_positions_calculated']) break;
                }
            }
            if (_.all(this.flags.feed_view_images_loaded) &&
                (_.keys(this.flags.feed_view_images_loaded).length > 0 ||
                 this.cache.feed_view_story_positions_keys.length > 0)) {
                this.fetch_story_locations_in_feed_view();
            } else {
                // NEWSBLUR.log(['Still loading feed view...', _.keys(this.flags.feed_view_images_loaded).length, this.cache.feed_view_story_positions_keys.length, this.flags.feed_view_images_loaded]);
            }
            
            if (!this.flags['feed_view_positions_calculated']) {
                setTimeout(function() {
                    if (!self.flags['feed_view_positions_calculated']) {
                        self.prefetch_story_locations_in_feed_view();
                    }
                }, 2000);
            }
        },
        
        fetch_story_locations_in_feed_view: function() {
            var stories = this.model.stories;
            if (!stories || !stories.length) return;

            $.extend(this.cache, {
                'feed_view_story_positions': {},
                'feed_view_story_positions_keys': []
            });

            for (var s in stories) {
                var story = stories[s];
                var $story = this.cache.feed_view_stories[story.id];
                this.determine_feed_view_story_position($story, story);
            }

            this.flags['feed_view_positions_calculated'] = true;
            NEWSBLUR.log(['Feed view entirely loaded', this.model.stories.length + " stories"]);
        },
        
        determine_feed_view_story_position: function($story, story) {
            if ($story && $story.is(':visible')) {
                var position_original = parseInt($story.position().top, 10);
                var position_offset = parseInt($story.offsetParent().scrollTop(), 10);
                var position = position_original + position_offset;
                this.cache.feed_view_story_positions[position] = story;
                this.cache.feed_view_story_positions_keys.push(position);
                this.cache.feed_view_story_positions_keys.sort(function(a, b) { return a-b; });    
                // NEWSBLUR.log(['Positioning story', position, $story, story, this.cache.feed_view_story_positions_keys]);
            }
        },
        
        append_feed_view_story_endbar: function() {
            var $feed_view = this.$s.$feed_view;
            var $stories = this.$s.$feed_stories;
            var $endbar = $.make('div', { className: 'NB-feed-story-endbar' });
            $stories.find('.NB-feed-story-endbar').remove();
            $stories.append($endbar);
        },
        
        append_story_titles_endbar: function() {
            var $story_titles = this.$s.$story_titles;
            var $end_stories_line = $.make('div', { 
                className: 'NB-story-titles-end-stories-line'
            });

            if (!($('.NB-story-titles-end-stories-line', $story_titles).length)) {
                $story_titles.append($end_stories_line);
            }
        },
        
        append_river_premium_only_notification: function() {
            var $story_titles = this.$s.$story_titles;
            var $notice = $.make('div', { className: 'NB-feed-story-premium-only' }, [
                $.make('div', { className: 'NB-feed-story-premium-only-divider'}),
                $.make('div', { className: 'NB-feed-story-premium-only-text'}, [
                    'The full River of News is a ',
                    $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
                    '.'
                ])
            ]);
            $('.NB-feed-story-premium-only', $story_titles).remove();
            $story_titles.append($notice);
        },
        
        // ===================
        // = Taskbar - Story =
        // ===================
        
        switch_taskbar_view: function(view, skip_save_type) {
            // NEWSBLUR.log(['switch_taskbar_view', view]);
            var self = this;
            var $story_pane = this.$s.$story_pane;
            var feed = this.model.get_feed(this.active_feed);
            
            if (view == 'page' && feed && feed.has_exception && feed.exception_type == 'page') {
              this.open_feed_exception_modal(this.active_feed);
              return;
            } else if ($('.task_button_view.task_view_'+view).hasClass('NB-disabled')) {
                return;
            }
            // NEWSBLUR.log(['$button', $button, this.flags['page_view_showing_feed_view'], $button.hasClass('NB-active'), skip_save_type]);
            var $taskbar_buttons = $('.NB-taskbar .task_button_view');
            var $feed_view = this.$s.$feed_view;
            var $feed_iframe = this.$s.$feed_iframe;
            var $page_to_feed_arrow = $('.NB-taskbar .NB-task-view-page-to-feed-arrow');
            var $feed_to_story_arrow = $('.NB-taskbar .NB-task-view-feed-to-story-arrow');
            
            if (!skip_save_type && this.story_view != view) {
                this.model.view_setting(this.active_feed, view);
            }
            
            $page_to_feed_arrow.hide();
            $feed_to_story_arrow.hide();
            this.flags['page_view_showing_feed_view'] = false;
            if (skip_save_type == 'page') {
                $page_to_feed_arrow.show();
                this.flags['page_view_showing_feed_view'] = true;
            } else if (skip_save_type == 'story') {
                $feed_to_story_arrow.show();
                this.flags['feed_view_showing_story_view'] = true;
            } else {
                $taskbar_buttons.removeClass('NB-active');
                $('.task_button_view.task_view_'+view).addClass('NB-active');
                this.story_view = view;
            }
            
            // this.flags.scrolling_by_selecting_story_title = true;
            // clearInterval(this.locks.scrolling);
            // this.locks.scrolling = setTimeout(function() {
            //     self.flags.scrolling_by_selecting_story_title = false;
            // }, 1000);
            if (view == 'page') {
                if (this.flags['iframe_prevented_from_loading']) {
                    this.load_feed_iframe(this.active_feed);
                }
                var $iframe_story = this.find_story_in_feed_iframe(this.active_story);
                this.scroll_to_story_in_iframe(this.active_story, $iframe_story, true);
                
                $story_pane.animate({
                    'left': 0
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
            } else if (view == 'feed') {
                if (this.active_story) {
                    var $feed_story = this.find_story_in_feed_view(this.active_story);
                    this.scroll_to_story_in_story_feed(this.active_story, $feed_story, true);
                }
                
                $story_pane.animate({
                    'left': -1 * $feed_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
                
                this.flags['switching_to_feed_view'] = true;
                setTimeout(function() {
                    self.flags['switching_to_feed_view'] = false;
                }, 100);
                
                this.show_stories_preference_in_feed_view();
                if (!this.flags['feed_view_positions_calculated']) {
                    this.prefetch_story_locations_in_feed_view();
                }
            } else if (view == 'story') {
                $story_pane.animate({
                    'left': -2 * $feed_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
                this.load_story_iframe();
                if (!this.active_story) {
                    this.show_next_story(1);
                }
            }
            
        },
        
        switch_taskbar_view_direction: function(direction) {
            var $active = $('.taskbar_nav_view .NB-active');
            var view;
            
            if (direction == -1) {
                if ($active.hasClass('task_view_page')) {
                    // view = 'page';
                } else if ($active.hasClass('task_view_feed')) {
                    view = 'page';
                } else if ($active.hasClass('task_view_story')) {
                    view = 'feed';
                } 
            } else if (direction == 1) {
                if ($active.hasClass('task_view_page')) {
                    view = 'feed';
                } else if ($active.hasClass('task_view_feed')) {
                    view = 'story';
                } else if ($active.hasClass('task_view_story')) {
                    // view = 'story';
                } 
            }
            
            if (view) {
                this.switch_taskbar_view(view);  
            }
        },
        
        show_stories_preference_in_feed_view: function(is_creating) {
            var $feed_view = this.$s.$feed_view;
            var $feed_view_stories = $(".NB-feed-story", $feed_view);
            var $stories = this.$s.$feed_stories;
            var story = this.active_story;

            if (story && this.model.preference('feed_view_single_story')) {
                // NEWSBLUR.log(['show_stories_preference_in_feed_view', is_creating, this.model.preference('feed_view_single_story'), $feed_view_stories.length + " stories"]);
                $stories.removeClass('NB-feed-view-feed').addClass('NB-feed-view-story');
                $feed_view_stories.css({'display': 'none'});
                if (is_creating) this.$s.$feed_stories.scrollTop('0px');
                var $current_story = this.get_current_story_from_story_titles($feed_view_stories);
                if ($current_story && $current_story.length) {
                    $current_story.css({'display': 'block'});
                }
                this.flags['feed_view_positions_calculated'] = false;
            } else {
                $stories.removeClass('NB-feed-view-story').addClass('NB-feed-view-feed');
                if (!is_creating) {
                    this.show_story_titles_above_intelligence_level({'animate': false});
                }
            }
            this.cache.story_pane_position = null;
        },
        
        // ==============
        // = Story View =
        // ==============
        
        open_story_in_story_view: function(story, is_temporary) {
            if (!story) story = this.active_story;
            this.switch_taskbar_view('story', is_temporary ? 'story' : false);
            this.load_story_iframe(story, story.story_feed_id);
        },
        
        load_story_iframe: function(story, feed_id) {
            story = story || this.active_story;
            if (!story) return;
            feed_id = feed_id || this.active_feed;
            var self = this;
            var $story_iframe = this.$s.$story_iframe;
            
            if ($story_iframe.attr('src') != story.story_permalink) {
                // NEWSBLUR.log(['load_story_iframe', story.story_permalink, $story_iframe.attr('src')]);
                this.unload_story_iframe();
            
                if (!feed_id) {
                    feed_id = $story_iframe.data('feed_id');
                } else {
                    $story_iframe.data('feed_id', feed_id);
                }
            
                this.flags.iframe_scroll_snap_back_prepared = true;
                this.iframe_link_attacher_num_links = 0;
                $story_iframe.removeAttr('src').attr({src: story.story_permalink});
            }
        },
        
        unload_story_iframe: function() {
            var $story_iframe = this.$s.$story_iframe;
            
            $story_iframe.empty();
            $story_iframe.removeAttr('src').attr({src: 'about:blank'});
        },
        
        // ===================
        // = Taskbar - Feeds =
        // ===================
        
        open_add_feed_modal: function(options) {
            clearInterval(this.flags['bouncing_callout']);
            $.modal.close();
            
            NEWSBLUR.add_feed = new NEWSBLUR.ReaderAddFeed(options);
        },
        
        open_manage_feed_modal: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            NEWSBLUR.manage_feed = new NEWSBLUR.ReaderManageFeed(feed_id);
        },

        open_mark_read_modal: function() {
            NEWSBLUR.mark_read = new NEWSBLUR.ReaderMarkRead();
        },

        open_keyboard_shortcuts_modal: function() {
            NEWSBLUR.keyboard = new NEWSBLUR.ReaderKeyboard();
        },
                
        open_goodies_modal: function() {
            NEWSBLUR.goodies = new NEWSBLUR.ReaderGoodies();
        },
                        
        open_preferences_modal: function() {
            NEWSBLUR.preferences = new NEWSBLUR.ReaderPreferences();
        },
                        
        open_account_modal: function(options) {
            NEWSBLUR.account = new NEWSBLUR.ReaderAccount(options);
        },
        
        open_feedchooser_modal: function() {
            NEWSBLUR.feedchooser = new NEWSBLUR.ReaderFeedchooser();
        },
        
        open_feed_exception_modal: function(feed_id) {
            NEWSBLUR.feed_exception = new NEWSBLUR.ReaderFeedException(feed_id);
        },
        
        open_feed_statistics_modal: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            NEWSBLUR.statistics = new NEWSBLUR.ReaderStatistics(feed_id);
        },
        
        close_sidebar: function() {
            this.$s.$body.layout().close('west');
            this.resize_window();
            this.flags['sidebar_closed'] = true;
            $('.NB-taskbar-sidebar-toggle-open').stop().animate({
                'left': -1
            }, {
                'duration': 1000,
                'easing': 'easeOutQuint',
                'queue': false
            });
        },
        
        open_sidebar: function() {
            this.$s.$body.layout().open('west');
            this.resize_window();
            this.flags['sidebar_closed'] = false;
            $('.NB-taskbar-sidebar-toggle-open').stop().css({
                'left': -24
            });
        },
        
        // =======================
        // = Sidebar Manage Menu =
        // =======================

        make_manage_menu: function(type, feed_id, story_id, inverse, $item) {
            var $manage_menu;
            
            if (type == 'site') {
                var show_chooser = !NEWSBLUR.Globals.is_premium && NEWSBLUR.Globals.is_authenticated;
                $manage_menu = $.make('ul', { className: 'NB-menu-manage' }, [
                    $.make('li', { className: 'NB-menu-manage-site-info' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('span', { className: 'NB-menu-manage-title' }, "Manage NewsBlur")
                    ]).corner('tl tr 8px'),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-manage-account' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'My Account')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-preferences' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Preferences')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-manage-keyboard' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Keyboard shortcuts')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-tutorial' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Tutorial')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-manage-mark-read NB-menu-manage-site-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark everything as read'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Choose how many days back.')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-trainer' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence Trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Accurate filters are happy filters.')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-goodies' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Goodies'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Extensions and extras.')
                    ]),
                    (show_chooser && $.make('li', { className: 'NB-menu-manage-feedchooser' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Choose Your 64'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Enable the sites you want.')
                    ]))
                ]);
                $manage_menu.addClass('NB-menu-manage-notop');
            } else if (type == 'feed') {
                var feed = this.model.get_feed(feed_id);
                if (!feed) return;
                var unread_count = this.get_unread_count(true, feed_id);
                var tab_unread_count = Math.min(25, unread_count);
                $manage_menu = $.make('ul', { className: 'NB-menu-manage' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    (feed.has_exception && $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-exception' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Fix this misbehaving site')
                    ])),
                    (feed.has_exception && $.make('li', { className: 'NB-menu-separator-inverse' })),
                    (feed.exception_type != 'feed' && $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-mark-read NB-menu-manage-feed-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as read')
                    ])),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-reload' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Insta-fetch stories')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-stats' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Statistics')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-recommend' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Recommend this site')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-move NB-menu-manage-feed-move' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Move to folder')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-confirm NB-menu-manage-feed-move-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-menu-manage-move-save NB-menu-manage-feed-move-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                            $.make('div', { className: 'NB-menu-manage-image' }),
                            $.make('div', { className: 'NB-add-folders' }, NEWSBLUR.utils.make_folders(this.model))
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-rename NB-menu-manage-feed-rename' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Rename this site')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-confirm NB-menu-manage-feed-rename-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-menu-manage-rename-save NB-menu-manage-feed-rename-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                            $.make('div', { className: 'NB-menu-manage-image' }),
                            $.make('input', { name: 'new_title', className: 'NB-menu-manage-title', value: feed.feed_title })
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-delete NB-menu-manage-feed-delete' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Delete this site')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-delete-confirm NB-menu-manage-feed-delete-confirm' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Really delete?')
                    ])
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('$feed', $item);
                if (feed_id && unread_count == 0) {
                    $('.NB-menu-manage-feed-mark-read', $manage_menu).addClass('NB-disabled');
                    $('.NB-menu-manage-feed-unreadtabs', $manage_menu).addClass('NB-disabled');
                }
            } else if (type == 'folder') {
                $manage_menu = $.make('ul', { className: 'NB-menu-manage' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-mark-read NB-menu-manage-folder-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark folder as read')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-move NB-menu-manage-folder-move' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Move to folder')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-confirm NB-menu-manage-folder-move-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-menu-manage-move-save NB-menu-manage-folder-move-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                            $.make('div', { className: 'NB-menu-manage-image' }),
                            $.make('div', { className: 'NB-add-folders' }, NEWSBLUR.utils.make_folders(this.model))
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-rename NB-menu-manage-folder-rename' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Rename this folder')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-confirm NB-menu-manage-folder-rename-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-menu-manage-rename-save NB-menu-manage-folder-rename-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                            $.make('div', { className: 'NB-menu-manage-image' }),
                            $.make('input', { name: 'new_title', className: 'NB-menu-manage-title', value: feed_id })
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-delete NB-menu-manage-folder-delete' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Delete this folder')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-delete-confirm NB-menu-manage-folder-delete-confirm' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Really delete?')
                    ])
                ]);
                $manage_menu.data('folder_name', feed_id);
                $manage_menu.data('$folder', $item);
            } else if (type == 'story') {
                var feed          = this.model.get_feed(feed_id);
                var story         = this.model.get_story(story_id);
                var starred_class = story.starred ? 'NB-story-starred' : '';
                var starred_title = story.starred ? 'Remove bookmark' : 'Save This Story';

                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-story ' + starred_class }, [
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-story-open' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Open')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-story-star' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, starred_title)
                    ]),
                    $.make('li', { className: 'NB-menu-manage-story-thirdparty' }, [
                        (NEWSBLUR.Preferences['story_share_facebook'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-facebook'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Send to Facebook').parent().addClass('NB-menu-manage-highlight-facebook');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Send to Instapaper').parent().removeClass('NB-menu-manage-highlight-facebook');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_twitter'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-twitter'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Send to Twitter').parent().addClass('NB-menu-manage-highlight-twitter');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Send to Instapaper').parent().removeClass('NB-menu-manage-highlight-twitter');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_readitlater'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-readitlater'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Read It Later').parent().addClass('NB-menu-manage-highlight-readitlater');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Send to Instapaper').parent().removeClass('NB-menu-manage-highlight-readitlater');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_email'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-email'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Send to email').parent().addClass('NB-menu-manage-highlight-email');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Send to Instapaper').parent().removeClass('NB-menu-manage-highlight-email');
                        }, this))),
                        // (NEWSBLUR.Preferences['story_share_readability'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-readability'}).bind('mouseenter', _.bind(function(e) {
                        //     $(e.target).siblings('.NB-menu-manage-title').text('Send to Readability').parent().addClass('NB-menu-manage-highlight-readability');
                        // }, this)).bind('mouseleave', _.bind(function(e) {
                        //     $(e.target).siblings('.NB-menu-manage-title').text('Send to Instapaper').parent().removeClass('NB-menu-manage-highlight-readability');
                        // }, this))),
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Send to Instapaper')
                    ]).bind('click', _.bind(function(e) {
                      e.preventDefault();
                      e.stopPropagation();
                      var $target = $(e.target);
                      if ($target.hasClass('NB-menu-manage-thirdparty-facebook')) {
                          this.send_story_to_facebook(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-twitter')) {
                          this.send_story_to_twitter(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-readitlater')) {
                          this.send_story_to_readitlater(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-readability')) {
                          this.send_story_to_readability(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-email')) {
                          this.send_story_to_email(story.id);
                      } else {
                          this.send_story_to_instapaper(story.id);
                      }
                    }, this)),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-story-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ])
                    // (story.read_status && $.make('li', { className: 'NB-menu-separator' })),
                    // (story.read_status && $.make('li', { className: 'NB-menu-manage-story-unread' }, [
                    //     $.make('div', { className: 'NB-menu-manage-image' }),
                    //     $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as unread')
                    // ]))
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('story_id', story_id);
                $manage_menu.data('$story', $item);
            }
            
            if (inverse) $manage_menu.addClass('NB-inverse');
            return $manage_menu;
        },
        
        show_manage_menu: function(type, $item, options) {
            var self = this;
            var options = _.extend({
              'toplevel': false,
              'inverse':  false
            }, options);
            var $manage_menu_container = $('.NB-menu-manage-container');
            // NEWSBLUR.log(['show_manage_menu', type, $item, $manage_menu_container.data('item'), $item && $item[0] == $manage_menu_container.data('item')]);
            clearTimeout(this.flags.closed_manage_menu);
            
            // If another menu is open, hide it first.
            // If this menu is already open, then hide it instead.
            if (($item && $item[0] == $manage_menu_container.data('item')) && 
                parseInt($manage_menu_container.css('opacity'), 10) == 1) {
                this.hide_manage_menu(type, $item);
                return;
            } else {
                this.hide_manage_menu(type, $item);
            }
            
            if ($item.hasClass('NB-empty')) return;
            
            $item.addClass('NB-showing-menu');
            
            // Create menu, size and position it, then attach to the right place.
            var feed_id, inverse, story_id;
            if (type == 'folder') {
                feed_id = $('.folder_title_text', $item).eq(0).text();
                inverse = options.inverse || $('.folder_title', $item).hasClass("NB-hover-inverse");
            } else if (type == 'feed') {
                feed_id = $item && parseInt($item.attr('data-id'), 10);
                inverse = options.inverse || $item.hasClass("NB-hover-inverse");
            } else if (type == 'story') {
                story_id = $item.data('story_id');
                if ($item.hasClass('NB-hover-inverse')) inverse = true; 
            } else if (type == 'site') {
                $('.NB-task-manage').tipsy('hide');
                $('.NB-task-manage').tipsy('disable');
            }
            var toplevel = options.toplevel || $item.hasClass("NB-toplevel") ||
                           $item.children('.folder_title').hasClass("NB-toplevel");
            var $manage_menu = this.make_manage_menu(type, feed_id, story_id, inverse, $item);
            $manage_menu_container.empty().append($manage_menu);
            $manage_menu_container.data('item', $item && $item[0]);
            $('.NB-task-manage').parents('.NB-taskbar').css('z-index', 2);
            if (type == 'site') {
                $manage_menu_container.align($('.NB-task-manage'), '-bottom -left', {
                    'top': -32, 
                    'left': -2
                });
                $('.NB-task-manage').addClass('NB-hover');
                $manage_menu_container.corner('tl tr 8px');
            } else if (type == 'feed' || type == 'folder' || type == 'story') {
                var left, top;
                // NEWSBLUR.log(['menu open', $item, inverse, toplevel, type]);
                if (inverse) {
                    var $align = $item;
                    if (type == 'feed') {
                        left = toplevel ? 0 : -20;
                        top = toplevel ? 21 : 21;
                    } else if (type == 'folder') {
                        left = toplevel ? 0 : -20;
                        top = toplevel ? 24 : 24;
                        $align = $('.folder_title', $item);
                    } else if (type == 'story') {
                        left = 4;
                        top = 24    ;
                        $align = $('.NB-story-manage-icon,.NB-feed-story-manage-icon', $item);
                    }
                    $manage_menu_container.align($align, '-bottom -left', {
                        'top': -1 * top, 
                        'left': left
                    });
                    $manage_menu_container.corner('br 8px');
                    $('li', $manage_menu_container).each(function() {
                        $(this).prependTo($(this).parent());
                    });
                } else {
                    var $align = $item;
                    if (type == 'feed') {
                        left = toplevel ? 2 : -18;
                        top = toplevel ? 21 : 21;
                        $align = $('.NB-feedlist-manage-icon', $item);
                    } else if (type == 'folder') {
                        left = toplevel ? 2 : -20;
                        top = toplevel ? 22 : 21;
                    } else if (type == 'story') {
                        left = 4;
                        top = 18;
                        $align = $('.NB-story-manage-icon,.NB-feed-story-manage-icon', $item);
                    }
                    $manage_menu_container.align($align, '-top -left', {
                        'top': top, 
                        'left': left
                    });
                    $manage_menu_container.corner('tr 8px');
                }
            }
            $manage_menu_container.stop().css({'display': 'block', 'opacity': 1});
            
            // Create and position the arrow tab
            if (type == 'feed' || type == 'folder' || type == 'story') {
                var $arrow = $.make('div', { className: 'NB-menu-manage-arrow' });
                if (inverse) {
                    $arrow.corner('bl br 5px');
                    $manage_menu_container.append($arrow);
                    $arrow.addClass('NB-inverse');
                } else {
                    $arrow.corner('tl tr 5px');
                    $manage_menu_container.prepend($arrow);
                }
            }
            
            // Hide menu on click outside menu.
            _.defer(function() {
                $(document).bind('click.menu', function(e) {
                    if (e.button == 2) return; // Ignore right-clicks
                    self.hide_manage_menu(type, $item, false);
                });
            });
            
            // Hide menu on mouseout (on a delay).
            $manage_menu_container.hover(function() {
                clearTimeout(self.flags.closed_manage_menu);
            }, function() {
                clearTimeout(self.flags.closed_manage_menu);
                self.flags.closed_manage_menu = setTimeout(function() {
                    if (self.flags.closed_manage_menu) {
                        self.hide_manage_menu(type, $item, true);
                    }
                }, 1000);
            });
            
            // Hide menu on scroll.
            var $scroll;
            this.flags['feed_list_showing_manage_menu'] = true;
            if (type == 'feed') {
                $scroll = this.$s.$feed_list.parent();
            } else if (type == 'story') {
                $scroll = this.$s.$story_titles.add(this.$s.$feed_stories);
            }
            $scroll && $scroll.unbind('scroll.manage_menu').bind('scroll.manage_menu', function(e) {
                if (self.flags['feed_list_showing_manage_menu']) {
                    self.hide_manage_menu(type, $item, true);
                } else {
                    $scroll.unbind('scroll.manage_menu');
                }
            });
        },
        
        hide_manage_menu: function(type, $item, animate) {
            var $manage_menu_container = $('.NB-menu-manage-container');
            var height = $manage_menu_container.outerHeight();
            if (this.flags['showing_confirm_input_on_manage_menu'] && animate) return;
            // NEWSBLUR.log(['hide_manage_menu', type, $item, animate, $manage_menu_container.css('opacity')]);
            
            clearTimeout(this.flags.closed_manage_menu);
            this.flags['feed_list_showing_manage_menu'] = false;
            $(document).unbind('click.menu');
            $manage_menu_container.uncorner();
            if (this.model.preference('show_tooltips')) {
                $('.NB-task-manage').tipsy('enable');
            }
            
            $item.removeClass('NB-showing-menu');
            
            if (animate) {
                $manage_menu_container.stop().animate({
                    'opacity': 0
                }, {
                    'duration': 250, 
                    'queue': false,
                    'complete': function() {
                        $manage_menu_container.css({'display': 'none', 'opacity': 0});
                    }
                });
            } else {
                $manage_menu_container.css({'display': 'none', 'opacity': 0});
            }
            $('.NB-task-manage').removeClass('NB-hover');
        },
        
        // ========================
        // = Manage menu - Delete =
        // ========================
        
        show_confirm_delete_menu_item: function() {
            var $delete = $('.NB-menu-manage-feed-delete,.NB-menu-manage-folder-delete');
            var $confirm = $('.NB-menu-manage-feed-delete-confirm,.NB-menu-manage-folder-delete-confirm');
            
            $delete.addClass('NB-menu-manage-feed-delete-cancel');
            $('.NB-menu-manage-title', $delete).text('Cancel delete');
            $confirm.slideDown(500);
        },
        
        hide_confirm_delete_menu_item: function() {
            var $delete = $('.NB-menu-manage-feed-delete,.NB-menu-manage-folder-delete');
            var $confirm = $('.NB-menu-manage-feed-delete-confirm,.NB-menu-manage-folder-delete-confirm');
            
            $delete.removeClass('NB-menu-manage-feed-delete-cancel');

            var text = $delete.hasClass('NB-menu-manage-folder-delete') ?
                       'Delete this folder' :
                       'Delete this site';
            $('.NB-menu-manage-title', $delete).text(text);
            $confirm.slideUp(500);
        },
        
        manage_menu_delete_feed: function(feed, $feed) {
            var self = this;
            var feed_id = feed || this.active_feed;
            $feed = $feed || this.find_feed_in_feed_list(feed_id);
            
            var in_folder = $feed.parents('li.folder').eq(0).find('.folder_title_text').eq(0).text();
            var duplicate_feed = this.find_feed_in_feed_list(feed_id).length > 1;

            this.model.delete_feed(feed_id, in_folder, function() {
                self.delete_feed(feed_id, $feed);
            }, duplicate_feed);
        },
        
        manage_menu_delete_folder: function(folder, $folder) {
            var self = this;
            var in_folder = '';
            var $parent = $folder.parents('li.folder');
            var feeds = this.get_feed_ids_in_folder($folder);
            if ($parent.length) {
                in_folder = $parent.eq(0).find('.folder_title_text').eq(0).text();
            }
        
            this.model.delete_folder(folder, in_folder, feeds, function() {
                self.delete_folder(folder, $folder);
            });
        },
        
        delete_feed: function(feed_id, $feed) {
            var self = this;
            $feed = $feed || this.find_feed_in_feed_list(feed_id);
            $feed.slideUp(500);
            
            if (this.active_feed == parseInt($feed.attr('data-id'), 10)) {
                this.reset_feed();
                this.show_splash_page();
            }
            this.update_header_counts();
        },
        
        delete_folder: function(folder_name, $folder) {
            var self = this;
            var feeds = this.get_feed_ids_in_folder($folder);

            if ($folder.length) {
                $folder.slideUp(500);
            }
            
            // If the active feed is under this folder, deselect it.
            var feed_active = false;
            _.each(feeds, _.bind(function(feed_id) {
                if (self.active_feed == feed_id) {
                    this.reset_feed();
                    this.show_splash_page();
                    return false;
                }
            }, this));
            
            this.update_header_counts();
        },
        
        // ========================
        // = Manage menu - Move =
        // ========================
        
        show_confirm_move_menu_item: function(feed_id, $feed) {
            var self = this;
            var $move = $('.NB-menu-manage-feed-move,.NB-menu-manage-folder-move');
            var $confirm = $('.NB-menu-manage-feed-move-confirm,.NB-menu-manage-folder-move-confirm');
            var $position = $('.NB-menu-manage-confirm-position', $confirm);
            var $select = $('select', $confirm);
            var $parent    = $feed.closest('li.folder');
            var in_folder = '';

            if ($parent.length) {
                in_folder = $feed.eq(0).closest('li.folder').find('.folder_title_text').eq(0).text();
            }
            
            $move.addClass('NB-menu-manage-feed-move-cancel');
            $('.NB-menu-manage-title', $move).text('Cancel move');
            $position.css('position', 'relative');
            var height = $confirm.height();
            $position.css('position', 'absolute');
            $confirm.css({'height': 0, 'display': 'block'}).animate({'height': height}, {
                'duration': 500, 
                'easing': 'easeOutQuart'
            });
            $('select', $confirm).focus().select();
            this.flags['showing_confirm_input_on_manage_menu'] = true;
            console.log(["$select", $select, $('option', $select)]);
            $('option', $select).each(function() {
                console.log(["show_confirm_move_menu_item", in_folder, $(this).attr('value')]);
                if ($(this).attr('value') == in_folder) {
                    $(this).attr('selected', 'selected');
                    return false;
                }
            });
        },
        
        hide_confirm_move_menu_item: function(moved) {
            var $move = $('.NB-menu-manage-feed-move,.NB-menu-manage-folder-move');
            var $confirm = $('.NB-menu-manage-feed-move-confirm,.NB-menu-manage-folder-move-confirm');
            
            $move.removeClass('NB-menu-manage-feed-move-cancel');
            var text = 'Move to folder';
            if (moved) {
                text = 'Moved';
                $move.addClass('NB-active');
            } else {
                $move.removeClass('NB-active');
            }
            $('.NB-menu-manage-title', $move).text(text);
            $confirm.slideUp(500);
            this.flags['showing_confirm_input_on_manage_menu'] = false;
        },
        
        manage_menu_move_feed: function(feed, $feed) {
            var self       = this;
            var feed_id    = feed || this.active_feed;
            $feed          = $feed || this.find_feed_in_feed_list(feed_id);
            var $parent    = $feed.closest('li.folder');
            var in_folder  = '';
            var new_folder = $('.NB-menu-manage-feed-move-confirm select').val();
            
            if (new_folder.length <= 0) return this.hide_confirm_move_menu_item();
            
            if ($parent.length) {
                in_folder = $feed.eq(0).closest('li.folder').find('.folder_title_text').eq(0).text();
            }
            
            this.model.move_feed_to_folder(feed_id, new_folder, function() {});

            this.hide_confirm_move_menu_item(true);
        },
        
        manage_menu_move_folder: function(folder, $folder) {
            var self       = this;
            var in_folder  = '';
            var $parent    = $folder.closest('li.folder');
            var new_folder = $('.NB-menu-manage-folder-move-confirm select').val();

            if (new_folder.length <= 0) return this.hide_confirm_move_menu_item();
            
            if ($parent.length) {
                in_folder = $parent.find('.folder_title_text').eq(0).text();
            }
        
            this.model.move_folder_to_folder(folder, new_folder, in_folder, function() {});
            this.hide_confirm_move_menu_item(true);
        },
        
        // ========================
        // = Manage menu - Rename =
        // ========================
        
        show_confirm_rename_menu_item: function() {
            var self = this;
            var $rename = $('.NB-menu-manage-feed-rename,.NB-menu-manage-folder-rename');
            var $confirm = $('.NB-menu-manage-feed-rename-confirm,.NB-menu-manage-folder-rename-confirm');
            var $position = $('.NB-menu-manage-confirm-position', $confirm);
            
            $rename.addClass('NB-menu-manage-feed-rename-cancel');
            $('.NB-menu-manage-title', $rename).text('Cancel rename');
            $position.css('position', 'relative');
            var height = $confirm.height();
            $position.css('position', 'absolute');
            $confirm.css({'height': 0, 'display': 'block'}).animate({'height': height}, {
                'duration': 500, 
                'easing': 'easeOutQuart'
            });
            $('input', $confirm).focus().select();
            this.flags['showing_confirm_input_on_manage_menu'] = true;
            $('.NB-menu-manage-feed-rename-confirm input.NB-menu-manage-title').bind('keyup', 'return', function(e) {
                var $t = $(e.target);
                var feed_id = $t.closest('.NB-menu-manage').data('feed_id');
                var $feed = $t.closest('.NB-menu-manage').data('$feed');
                self.manage_menu_rename_feed(feed_id, $feed);
            });
            $('.NB-menu-manage-folder-rename-confirm input.NB-menu-manage-title').bind('keyup', 'return', function(e) {
                var $t = $(e.target);
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.manage_menu_rename_folder(folder_name, $folder);
            });
        },
        
        hide_confirm_rename_menu_item: function(renamed) {
            var $rename = $('.NB-menu-manage-feed-rename,.NB-menu-manage-folder-rename');
            var $confirm = $('.NB-menu-manage-feed-rename-confirm,.NB-menu-manage-folder-rename-confirm');
            
            $rename.removeClass('NB-menu-manage-feed-rename-cancel');
            var text = $rename.hasClass('NB-menu-manage-folder-rename') ?
                       'Rename this folder' :
                       'Rename this site';
            if (renamed) {
                text = 'Renamed';
                $rename.addClass('NB-active');
            } else {
                $rename.removeClass('NB-active');
            }
            $('.NB-menu-manage-title', $rename).text(text);
            $confirm.slideUp(500);
            this.flags['showing_confirm_input_on_manage_menu'] = false;
        },
        
        manage_menu_rename_feed: function(feed, $feed) {
            var self      = this;
            var feed_id   = feed || this.active_feed;
            $feed         = $feed || this.find_feed_in_feed_list(feed_id);
            var new_title = $('.NB-menu-manage-feed-rename-confirm .NB-menu-manage-title').val();
            
            if (new_title.length <= 0) return this.hide_confirm_rename_menu_item();
            
            this.model.rename_feed(feed_id, new_title, function() {
            });

            $('.feed_title', $feed).text(new_title);
            if (feed_id == this.active_feed) {
                $('.feed_title', this.$s.$story_titles).text(new_title);
            }
            this.hide_confirm_rename_menu_item(true);
        },
        
        manage_menu_rename_folder: function(folder, $folder) {
            var self      = this;
            var in_folder = '';
            var $parent   = $folder.parents('li.folder');
            var new_folder_name = $('.NB-menu-manage-folder-rename-confirm .NB-menu-manage-title').val();

            if (new_folder_name.length <= 0) return this.hide_confirm_rename_menu_item();
            
            if ($parent.length) {
                in_folder = $parent.eq(0).find('.folder_title_text').eq(0).text();
            }
        
            this.model.rename_folder(folder, new_folder_name, in_folder, function() {
            });
            NEWSBLUR.log(['rename', $folder, new_folder_name]);
            $('.folder_title_text', $folder).text(new_folder_name);
            this.hide_confirm_rename_menu_item(true);
            
            $('.NB-menu-manage-folder-rename').parents('.NB-menu-manage').data('folder_name', new_folder_name);
        },
        
        // ==========================
        // = Taskbar - Intelligence =
        // ==========================
        
        load_intelligence_slider: function() {
            var self = this;
            var $slider = this.$s.$intelligence_slider;
            var unread_view = this.model.preference('unread_view');
            
            this.switch_feed_view_unread_view(unread_view);
            
            $slider.slider({
                range: 'max',
                min: -1,
                max: 1,
                step: 1,
                value: unread_view,
                slide: function(e, ui) {
                    self.switch_feed_view_unread_view(ui.value);
                },
                stop: function(e, ui) {
                    self.slide_intelligence_slider(ui.value);
                }
            });
        },
        
        slide_intelligence_slider: function(value) {
            if (this.model.preference('unread_view') != value) {
                this.model.preference('unread_view', value);
            }
            this.flags['feed_view_positions_calculated'] = false;
            this.switch_feed_view_unread_view(value);
            this.show_feed_hidden_story_title_indicator();
            this.show_story_titles_above_intelligence_level({'animate': true, 'follow': true});
        },
        
        move_intelligence_slider: function(direction) {
            var $slider = this.$s.$intelligence_slider;
            var value = this.model.preference('unread_view') + direction;
            $slider.slider({value: value});
            this.slide_intelligence_slider(value);
        },
        
        switch_feed_view_unread_view: function(unread_view) {
            if (!_.isNumber(unread_view)) unread_view = this.model.preference('unread_view');
            var $feed_list             = this.$s.$feed_list;
            var unread_view_name       = this.get_unread_view_name(unread_view);
            var $next_story_button     = $('.task_story_next_unread');
            var $story_title_indicator = $('.NB-story-title-indicator', this.$story_titles);
            var $hidereadfeeds_button  = $('.NB-feeds-header-sites');

            $feed_list.removeClass('unread_view_positive')
                      .removeClass('unread_view_neutral')
                      .removeClass('unread_view_negative')
                      .addClass('unread_view_'+unread_view_name);
            
            if (NEWSBLUR.Preferences['hide_read_feeds'] == 1) {
                $hidereadfeeds_button.attr('title', 'Show all sites');
                this.$s.$body.addClass('NB-feedlist-hide-read-feeds');
            } else {
                $hidereadfeeds_button.attr('title', 'Show only unread stories');
                this.$s.$body.removeClass('NB-feedlist-hide-read-feeds');
            }
            if (this.model.preference('show_tooltips')) {
                $hidereadfeeds_button.tipsy({
                    gravity: 'n',
                    delayIn: 375
                });
            }

            $next_story_button.removeClass('task_story_next_positive')
                              .removeClass('task_story_next_neutral')
                              .removeClass('task_story_next_negative')
                              .addClass('task_story_next_'+unread_view_name);
                              
            $story_title_indicator.removeClass('unread_threshold_positive')
                                  .removeClass('unread_threshold_neutral')
                                  .removeClass('unread_threshold_negative')
                                  .addClass('unread_threshold_'+unread_view_name);
        },
        
        get_unread_view_name: function(unread_view) {
            if (typeof unread_view == 'undefined') {
                unread_view = this.model.preference('unread_view');
            }

            return (unread_view > 0
                    ? 'positive'
                    : unread_view < 0
                      ? 'negative'
                      : 'neutral');
        },
        
        get_unread_count: function(visible_only, feed_id) {
            var total = 0;
            var $folder;
            feed_id = feed_id || this.active_feed;
            
            if (feed_id == 'starred') {
                // Umm, no. Not yet.
            } else if (this.flags['river_view']) {
                if (feed_id == 'river:') {
                    $folder = this.$s.$feed_list;
                } else {
                    $folder = $('li.folder.NB-selected');
                }
                var counts = this.list_feeds_with_unreads_in_folder($folder, true, visible_only);
                return _.reduce(counts, function(m, c) { return m + c; }, 0);
            } else {
                var feed = this.model.get_feed(feed_id);
                if (!visible_only) {
                    total = feed.ng + feed.nt + feed.ps;
                } else {
                    var unread_view_name = this.get_unread_view_name();
                    if (unread_view_name == 'positive') {
                        total = feed.ps;
                    } else if (unread_view_name == 'neutral') {
                        total = feed.ps + feed.nt;
                    } else if (unread_view_name == 'negative') {
                        total = feed.ps + feed.nt + feed.ng;
                    }
                }
                return total;
            }
        },
        
        show_story_titles_above_intelligence_level: function(opts) {
            var defaults = {
                'unread_view_name': null,
                'animate': true,
                'follow': true,
                'temporary': false
            };
            var options = $.extend({}, defaults, opts);
            var self = this;
            var $story_titles = this.$s.$story_titles;
            var unread_view_name = options['unread_view_name'] || this.get_unread_view_name();
            var $stories_show, $stories_hide;
            
            if (this.flags['unread_threshold_temporarily']) {
              unread_view_name = this.flags['unread_threshold_temporarily'];
              options['temporary'] = true;
            }

            if (unread_view_name == 'positive') {
                $stories_show = $('.story,.NB-feed-story').filter('.NB-story-positive');
                $stories_hide = $('.story,.NB-feed-story')
                                .filter('.NB-story-neutral,.NB-story-negative');
            } else if (unread_view_name == 'neutral') {
                $stories_show = $('.story,.NB-feed-story')
                                .filter('.NB-story-positive,.NB-story-neutral');
                $stories_hide = $('.story,.NB-feed-story').filter('.NB-story-negative');
                if (options['temporary']) {
                  $stories_show.filter('.NB-story-neutral').addClass('NB-story-hidden-visible');
                } else {
                  $stories_show.filter('.NB-story-hidden-visible').removeClass('NB-story-hidden-visible');
                }
            } else if (unread_view_name == 'negative') {
                $stories_show = $('.story,.NB-feed-story')
                                .filter('.NB-story-positive,.NB-story-neutral,.NB-story-negative');
                $stories_hide = $();
                if (options['temporary']) {
                  $stories_show.filter('.NB-story-negative,.NB-story-neutral:not(:visible)')
                               .addClass('NB-story-hidden-visible');
                } else {
                  $stories_show.filter('.NB-story-hidden-visible').removeClass('NB-story-hidden-visible');
                }
            }
            
            if (this.story_view == 'feed' && this.model.preference('feed_view_single_story')) {
                // No need to show/hide feed view stories under single_story preference. 
                // If the user switches to feed/page, then no animation is happening 
                // and this will work anyway.
                var active_story = this.active_story;
                var $active_story = active_story && $('.NB-feed-story').filter(function() { 
                  return $(this).data('story_id') == active_story.id; 
                });
                if ($active_story && $active_story.length) {
                  $stories_show = $stories_show.not('.NB-feed-story').add($active_story);
                  $stories_hide = $stories_hide.add('.NB-feed-story').not($stories_show);
                }
            }
            
            if (!options['animate']) {
                $stories_hide.css({'display': 'none'});
                $stories_show.css({'display': 'block'});
                this.check_story_titles_last_story();
            }
            
            if (this.story_view == 'feed' && !this.model.preference('feed_view_single_story')) {
                if ($stories_show.filter(':visible').length != $stories_show.length
                    || $stories_hide.filter(':visible').length != 0) {
                    // NEWSBLUR.log(['Show/Hide stories', $stories_show.filter(':visible').length, $stories_show.length, $stories_hide.filter(':visible').length, $stories_hide.length]);
                    setTimeout(function() {
                        self.flags['feed_view_positions_calculated'] = false;
                        self.prefetch_story_locations_in_feed_view();
                    }, 500);
                }
            }
            
            // NEWSBLUR.log(['Showing correct stories', this.story_view, this.flags['feed_view_positions_calculated'], unread_view_name, $stories_show.length, $stories_hide.length]);
            if (options['animate'] && options['follow']) {
                if (this.model.preference('animations')) {
                    $stories_hide.slideUp(500, function() {
                        self.check_story_titles_last_story();
                    });
                    $stories_show.slideDown(500);
                } else {
                    $stories_hide.css({'display': 'none'});
                    $stories_show.css({'display': 'block'});
                    this.check_story_titles_last_story();
                }
                setTimeout(function() {
                    if (!self.active_story) return;
                    var $story = self.find_story_in_story_titles(self.active_story.id);
                    // NEWSBLUR.log(['$story', $story]);
                    if ($story && $story.length && $story.is(':visible')) {
                        var story = self.active_story;
                        self.active_story = null; // Set is in open_story(), which allows it to scroll.
                        self.open_story(story, $story);
                        self.scroll_story_titles_to_show_selected_story_title($story);
                    }
                }, this.model.preference('animations') ? 550 : 0);
            }
        },
        
        // ===================
        // = Feed Refreshing =
        // ===================
        
        force_instafetch_stories: function(feed_id) {
            var self = this;
            feed_id = feed_id || this.active_feed;
            var $feed = this.find_feed_in_feed_list(feed_id);
            $feed.addClass('NB-feed-unfetched').removeClass('NB-feed-exception');

            this.model.save_exception_retry(feed_id, _.bind(this.force_feed_refresh, this, feed_id, $feed));
        },
        
        setup_feed_refresh: function(new_feeds) {
            var self = this;
            var refresh_interval = this.constants.FEED_REFRESH_INTERVAL;
            var feed_count = _.size(this.model.feeds);
            
            if (!NEWSBLUR.Globals.is_premium) {
                refresh_interval *= 2;
            }
            if (feed_count > 250) {
                refresh_interval *= 4;
            }
            if (feed_count > 500) {
                refresh_interval *= 1.5;
            }

            if (new_feeds && feed_count < 250) {
                refresh_interval = (1000 * 60) * 1/10;
            } else if (new_feeds && feed_count < 500) {
                refresh_interval = (1000 * 60) * 1/4;
            }
            
            clearInterval(this.flags.feed_refresh);
            
            this.flags.feed_refresh = setInterval(function() {
                if (!self.flags['pause_feed_refreshing']) {
                  self.model.refresh_feeds(_.bind(function(updated_feeds) {
                      self.post_feed_refresh(updated_feeds);
                  }, self), self.flags['has_unfetched_feeds']);
                }
            }, refresh_interval);
        },
        
        force_feed_refresh: function(feed_id, $feed) {
            var self = this;
            feed_id  = feed_id || this.active_feed;
            $feed    = $feed || this.find_feed_in_feed_list(feed_id);

            this.force_feeds_refresh(function(feeds) {
                var $new_feed = $(self.make_feed_title_template(feeds[feed_id], 'feed'));
                if ($feed.hasClass('NB-toplevel')) $new_feed.addClass('NB-toplevel');
                $feed.replaceWith($new_feed);
                self.cache.$feed_in_feed_list[feed_id] = null;
                self.hover_over_feed_titles($new_feed);
                if (self.active_feed == feed_id) {
                    self.open_feed(feed_id, true, $new_feed);
                }
            }, false, feed_id);
        },
        
        force_feeds_refresh: function(callback, replace_active_feed, feed_id) {
            if (callback) {
                this.cache.refresh_callback = callback;
            } else {
                delete this.cache.refresh_callback;
            }

            this.flags['pause_feed_refreshing'] = true;
            
            this.model.refresh_feeds(_.bind(function(updated_feeds) {
              this.post_feed_refresh(updated_feeds, replace_active_feed, feed_id);
            }, this), this.flags['has_unfetched_feeds'], feed_id);
        },
        
        post_feed_refresh: function(updated_feeds, replace_active_feed, single_feed_id) {
            var feeds = this.model.feeds;
            
            if (this.cache.refresh_callback && $.isFunction(this.cache.refresh_callback)) {
                this.cache.refresh_callback(feeds);
                delete this.cache.refresh_callback;
            }
            
            for (var f in updated_feeds) {
                var feed_id = updated_feeds[f];
                var feed = this.model.get_feed(feed_id);
                if (!feed) continue;
                var $feed = $(this.make_feed_title_template(feed, 'feed'));
                var $feed_on_page = this.find_feed_in_feed_list(feed_id);
                
                if (feed_id == this.active_feed) {
                    NEWSBLUR.log(['UPDATING INLINE', feed.feed_title, $feed, $feed_on_page, replace_active_feed]);
                    if (!replace_active_feed) {
                        // this.model.refresh_feed(feed_id, $.rescope(this.post_refresh_active_feed, this));
                        // Set the unread counts to what the client thinks they are, so when
                        // the counts can be updated, they will force a refresh of the feed.
                        this.model.feeds[feed_id].ps = parseInt($('.unread_count_positive', $feed_on_page).text(), 10);
                        this.model.feeds[feed_id].nt = parseInt($('.unread_count_neutral', $feed_on_page).text(), 10);
                        this.model.feeds[feed_id].ng = parseInt($('.unread_count_negative', $feed_on_page).text(), 10);
                    } else {
                        if ($feed_on_page.hasClass('NB-toplevel')) $feed.addClass('NB-toplevel');
                        $feed_on_page.replaceWith($feed);
                        this.cache.$feed_in_feed_list[feed_id] = null;
                        this.mark_feed_as_selected(this.active_feed, $feed);
                        if (!single_feed_id) this.recalculate_story_scores(feed_id);
                        this.show_feed_hidden_story_title_indicator();
                        this.make_content_pane_feed_counter();
                    }
                } else {
                    if (!this.flags['has_unfetched_feeds']) {
                        NEWSBLUR.log(['UPDATING', feed.feed_title, $feed, $feed_on_page]);
                    }
                    if ($feed_on_page.hasClass('NB-toplevel')) $feed.addClass('NB-toplevel');
                    $feed_on_page.replaceWith($feed);
                    this.cache.$feed_in_feed_list[feed_id] = null;
                    (function($feed) {
                      $feed.css({'backgroundColor': '#D7DDE6'});
                      $feed.animate({
                        'backgroundColor': '#F0F076'
                      }, {
                        'duration': 800, 
                        'queue': false, 
                        'complete': function() {
                          $feed.animate({'backgroundColor': '#D7DDE6'}, {'duration': 1000, 'queue': false});
                        }
                      });
                    })($feed);
                }
                this.hover_over_feed_titles($feed);
            }
            
            this.check_feed_fetch_progress();
            this.update_header_counts();
            this.count_collapsed_unread_stories();

            this.flags['pause_feed_refreshing'] = false;
        },
        
        post_refresh_active_feed: function(e, data, first_load) {
            var stories = data.stories;
            var tags = data.tags;
            var feed_id = this.active_feed;
            var new_stories = [];
            var $first_story = $('.story:first', this.$s.$story_titles);
            
            for (var s in stories) {
                feed_id = stories[s].story_feed_id;
                break;
            }
            
            if (this.active_feed == feed_id) {
                for (var s in this.model.stories) {
                    var story = this.model.stories[s];
                    var $story = this.find_story_in_story_titles(story.id);
                    var $feed_story = this.find_story_in_feed_view(story);
                    
                    if ($story && $story.length) {
                        // Just update intelligence
                        var score = NEWSBLUR.utils.compute_story_score(story);
                        $story.removeClass('NB-story-neutral')
                              .removeClass('NB-story-negative')
                              .removeClass('NB-story-positive');
                        $feed_story.removeClass('NB-story-neutral')
                              .removeClass('NB-story-negative')
                              .removeClass('NB-story-positive');
                        if (score < 0) {
                            $story.addClass('NB-story-negative');
                            $feed_story.addClass('NB-story-negative');
                        } else if (score > 0) {
                            $story.addClass('NB-story-positive');
                            $feed_story.addClass('NB-story-positive');
                        } else if (score == 0) {
                            $story.addClass('NB-story-neutral');
                            $feed_story.addClass('NB-story-neutral');
                        }
                    } else {
                        // New story! Prepend.
                        new_stories.unshift(story);
                        $new_story = this.make_story_title(story);
                        $new_story.css({'display': 'none'});
                        $first_story.before($new_story);
                        NEWSBLUR.log(['New story', $new_story, $first_story]);
                    }
                }
                if (new_stories.length) {
                    this.make_story_feed_entries(new_stories, false, {'refresh_load': true});
                    this.flags['feed_view_positions_calculated'] = false;
                }
                this.show_story_titles_above_intelligence_level({'animate': true, 'follow': false});
            }
            this.update_header_counts();
        },
        
        // ===================
        // = Mouse Indicator =
        // ===================
        
        hide_mouse_indicator: function() {
            var self = this;

            if (!this.flags['mouse_indicator_hidden']) {
                this.flags['mouse_indicator_hidden'] = true;
                this.$s.$mouse_indicator.animate({'opacity': 0, 'left': -10}, {
                    'duration': 200, 
                    'queue': false, 
                    'complete': function() {
                        self.flags['mouse_indicator_hidden'] = true;
                    }
                });
            }
        },
        
        show_mouse_indicator: function() {
            var self = this;
            
            if (this.flags['mouse_indicator_hidden']) {
                this.flags['mouse_indicator_hidden'] = false;
                this.$s.$mouse_indicator.animate({'opacity': 1, 'left': 0}, {
                    'duration': 200, 
                    'queue': false,
                    'complete': function() {
                        self.flags['mouse_indicator_hidden'] = false;
                    }
                });
            }
        },
        
        handle_mouse_indicator_hover: function() {
            var self = this;
            var $callout = $('.NB-callout-mouse-indicator');
            $('.NB-callout-text', $callout).text('Lock');
            $callout.corner('5px');
            
            this.$s.$mouse_indicator.hover(function() {
                if (parseInt(self.model.preference('lock_mouse_indicator'), 10)) {
                    $('.NB-callout-text', $callout).text('Unlock');
                } else {
                    $('.NB-callout-text', $callout).text('Lock');
                }
                self.flags['still_hovering_on_mouse_indicator'] = true;
                setTimeout(function() {
                    if (self.flags['still_hovering_on_mouse_indicator']) {
                        $callout.css({
                            'display': 'block'
                        }).animate({
                            'opacity': 1,
                            'left': '20px'
                        }, {'duration': 200, 'queue': false});
                    }
                }, 50);
            }, function() {
                self.flags['still_hovering_on_mouse_indicator'] = false;
                $callout.animate({'opacity': 0, 'left': '-100px'}, {'duration': 200, 'queue': false});
            });
        },
        
        lock_mouse_indicator: function() {
            var self = this;
            var $callout = $('.NB-callout-mouse-indicator');
            
            if (parseInt(self.model.preference('lock_mouse_indicator'), 10)) {
                self.model.preference('lock_mouse_indicator', 0);
                $('.NB-callout-text', $callout).text('Unlocked');
            } else {
                self.model.preference('lock_mouse_indicator', this.cache.mouse_position_y);
                $('.NB-callout-text', $callout).text('Locked');
            }
            
            setTimeout(function() {
                self.flags['still_hovering_on_mouse_indicator'] = true;
                $callout.fadeOut(200);
            }, 500);
        },
        
        position_mouse_indicator: function() {
            var position = parseInt(this.model.preference('lock_mouse_indicator'), 10);
            if (position == 0) {
                position = 50; // Start with a 50 offset
            } else {
                position = position - 8; // Compensate for mouse indicator height.
            }
            this.$s.$mouse_indicator.css('top', position);
        },
        
        // ==========================
        // = Login and Signup Forms =
        // ==========================
        
        handle_login_and_signup_forms: function() {
            var self = this;
            var $hidden_inputs = $('.NB-signup-hidden');
            var $signup_username = $('input[name=signup-username]');
            
            $signup_username.bind('focus', function() {
                $hidden_inputs.slideDown(300);
            }).bind('blur', function() {
                if ($signup_username.val().length < 1) {
                    $hidden_inputs.slideUp(300);
                }
            });
        },
        
        // ==================
        // = Features Board =
        // ==================
        
        load_feature_page: function(direction) {
            var self = this;
            var $module = $('.NB-module-features');
            var $next = $('.NB-module-features .NB-module-next-page');
            var $previous = $('.NB-module-features .NB-module-previous-page');

            $module.addClass('NB-loading');
            
            if (direction == -1 && !this.counts['feature_page']) {
                $module.removeClass('NB-loading');
                return;
            }
            if (direction == 1 && this.flags['features_last_page']) {
                $module.removeClass('NB-loading');
                return;
            }
            
            this.model.get_features_page(this.counts['feature_page']+direction, function(features) {
                $module.removeClass('NB-loading');
                self.counts['feature_page'] += direction;
                
                var $table = $.make('table', { className: 'NB-features', cellSpacing: 0, cellPadding: 0 });
                for (var f in features) {
                    if (f == 3) break;
                    var feature = features[f];
                    var $tr = $.make('tr', { className: 'NB-module-feature' }, [
                        $.make('td', { className: 'NB-module-feature-date' }, feature.date),
                        $.make('td', { className: 'NB-module-feature-description' }, feature.description)
                    ]);
                    $table.append($tr);
                }
                
                $('.NB-module-features .NB-features').replaceWith($table);
                
                var features_count = features.length;
                if (features_count < 4) {
                    $next.addClass('NB-disabled');
                    self.flags['features_last_page'] = true;
                } else {
                    $next.removeClass('NB-disabled');
                    self.flags['features_last_page'] = false;
                }
                if (self.counts['feature_page'] > 0) {
                    $previous.removeClass('NB-disabled');
                } else {
                    $previous.addClass('NB-disabled');
                }
                
            });
        },
        
        setup_howitworks_hovers: function() {
            var $page_indicators = $('.NB-module-howitworks .NB-module-page-indicator');
            $page_indicators.bind('mouseenter', _.bind(function(e) {
                var page = $(e.target).prevAll('.NB-module-page-indicator').length;
                this.load_howitworks_page(page);
            }, this));
        },
        
        load_howitworks_page: function(page) {
            var self = this;
            var $next = $('.NB-module-howitworks .NB-module-next-page');
            var $previous = $('.NB-module-howitworks .NB-module-previous-page');
            var $pages = $('.NB-howitworks-page');
            var $page_indicators = $('.NB-module-howitworks .NB-module-page-indicator');
            var pages_count = $pages.length;
            
            if (page == -1) {
                return;
            }
            if (page >= pages_count) {
                return;
            }
            
            $pages.removeClass("NB-active");
            $page_indicators.removeClass("NB-active");
            $pages.eq(page).addClass("NB-active");
            $page_indicators.eq(page).addClass("NB-active");
            
            if (page >= pages_count - 1) {
                $next.addClass('NB-disabled');
            } else {
                $next.removeClass('NB-disabled');
            }
            if (page <= 0) {
                $previous.addClass('NB-disabled');
            } else {
                $previous.removeClass('NB-disabled');
            }
        },
        
        // ========
        // = FTUX =
        // ========
        
        setup_ftux_add_feed_callout: function() {
            var self = this;
            
            $('.NB-callout-ftux .NB-callout-text').text('First things first...');
            $('.NB-callout-ftux').corner('5px');
            $('.NB-callout-ftux').css({
                'opacity': 0,
                'display': 'block'
            }).animate({
                'opacity': 1,
                'bottom': 6
            }, {
                'duration': 750,
                'easing': 'easeInOutQuint'
            }).each(function() {
                var $this = $(this);
                self.flags['bouncing_callout'] = setInterval(function() {
                    $this.animate({'bottom': '+=2px'}, {'duration': 200, 'easing': 'easeInOutQuint'})
                         .animate({'bottom': '+=0px'}, {'duration': 50})
                         .animate({'bottom': '-=2px'}, {'duration': 200, 'easing': 'easeInOutQuint'});
                }, 1000);
            });
        },
        
        setup_ftux_signup_callout: function() {
            var self = this;
            
            if (!self.flags['bouncing_callout']) {
                $('.NB-callout-ftux-signup .NB-callout-text').text('Signup');
                $('.NB-callout-ftux-signup').corner('5px');
                $('.NB-callout-ftux-signup').css({
                    'opacity': 0,
                    'display': 'block'
                }).animate({
                    'opacity': 1,
                    'bottom': 36
                }, {
                    'duration': 750,
                    'easing': 'easeInOutQuint'
                }).each(function() {
                    var $this = $(this);
                        self.flags['bouncing_callout'] = setInterval(function() {
                            $this.animate({'bottom': '+=2px'}, {'duration': 200, 'easing': 'easeInOutQuint'})
                                 .animate({'bottom': '+=0px'}, {'duration': 50})
                                 .animate({'bottom': '-=2px'}, {'duration': 200, 'easing': 'easeInOutQuint'});
                        }, 10000);
                });
            }
        },
        
        // =============================
        // = Import from Google Reader =
        // =============================

        start_import_from_google_reader: function() {
            var self = this;
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            var percentage = 0;
            this.flags['import_from_google_reader_working'] = true;
            
            $('.NB-progress-title', $progress).text('Importing from Google Reader');
            $('.NB-progress-counts', $progress).hide();
            $('.NB-progress-percentage', $progress).hide();
            $bar.progressbar({
                value: percentage
            });
            
            this.animate_progress_bar($bar, 4);
            
            this.model.start_import_from_google_reader($.rescope(this.finish_import_from_google_reader, this));
            this.show_progress_bar();
        },

        finish_import_from_google_reader: function(e, data) {
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            this.flags['import_from_google_reader_working'] = false;
            clearTimeout(this.locks['animate_progress_bar']);
            
            if (data.code >= 1) {
                $bar.progressbar({value: 100});
                this.load_feeds();
            } else {
                NEWSBLUR.log(['Import Error!', data]);
                this.$s.$feed_link_loader.fadeOut(250);
                $progress.addClass('NB-progress-error');
                $('.NB-progress-title', $progress).text('Error importing Google Reader');
                $('.NB-progress-link', $progress).html($.make('a', { href: NEWSBLUR.URLs['google-reader-authorize'], className: 'NB-splash-link' }, 'Try importing again'));
                $('.left-center-footer').css('height', 'auto');
            }
        },

        start_count_unreads_after_import: function() {
            var self = this;
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            var percentage = 0;
            var feeds_count = _.keys(this.model.feeds).length;
            
            if (!this.flags['pause_feed_refreshing']) return;
            
            this.flags['count_unreads_after_import_working'] = true;
            
            $('.NB-progress-title', $progress).text('Counting is difficult');
            $('.NB-progress-counts', $progress).hide();
            $('.NB-progress-percentage', $progress).hide();
            $bar.progressbar({
                value: percentage
            });
            
            setTimeout(function() {
                if (self.flags['count_unreads_after_import_working']) {
                    self.animate_progress_bar($bar, feeds_count / 10);
                    self.show_progress_bar();
                }
            }, 500);
        },

        finish_count_unreads_after_import: function(e, data) {
            $('.NB-progress-bar', this.$s.$feeds_progress).progressbar({
                value: 100
            });
            this.flags['count_unreads_after_import_working'] = false;
            clearTimeout(this.locks['animate_progress_bar']);
            this.$s.$feed_link_loader.fadeOut(250);
            this.setup_feed_refresh();
            if (!this.flags['has_unfetched_feeds']) {
                this.hide_progress_bar();
            }
        },
        
        // =====================
        // = Recommended Feeds =
        // =====================
        
        load_recommended_feeds: function() {
          // Reload recommended feeds every 10 minutes.
          clearInterval(this.locks.load_recommended_feed);
          this.locks.load_recommended_feed = setInterval(_.bind(function() {
              this.load_recommended_feed(0, true);
          }, this), 10*60*1000);
        },
        
        load_feed_in_tryfeed_view: function(feed_id, feed) {
            feed = feed || {};
            var $recommended_feeds = $('.NB-module-recommended');
            var $tryfeed_container = this.$s.$tryfeed_header.closest('.NB-feeds-header-container');
            var feed = {
                feed_id     : feed_id,
                feed_title  : feed.feed_title || $('.NB-recommended-title', $recommended_feeds).text(),
                favicon     : feed.favicon ? $.favicon(feed.favicon) : $('.NB-recommended-favicon', $recommended_feeds).attr('src'),
                feed_address : feed.feed_address
            };

            this.reset_feed();
            this.model.set_feed(feed_id, feed);

            $('.NB-feeds-header-title', this.$s.$tryfeed_header).text(feed.feed_title);
            $('.NB-feeds-header-icon',  this.$s.$tryfeed_header).attr('src', feed.favicon);

            $tryfeed_container.slideDown(350, _.bind(function() {
                this.open_feed(feed_id);
                this.flags['showing_feed_in_tryfeed_view'] = true;
                this.$s.$tryfeed_header.addClass('NB-selected');
            }, this));
        },
        
        hide_tryfeed_view: function() {
            var $tryfeed_container = this.$s.$tryfeed_header.closest('.NB-feeds-header-container');
            $tryfeed_container.slideUp(350);
            this.$s.$story_taskbar.find('.NB-tryfeed-add').remove();
            this.flags['showing_feed_in_tryfeed_view'] = false;
        },
        
        show_tryfeed_add_button: function() {
            if (this.$s.$story_taskbar.find('.NB-tryfeed-add:visible').length) return;
            
            var $add = $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-tryfeed-add NB-modal-submit-green NB-modal-submit-button' }, 'Add')
            ]).css({'opacity': 0});
            this.$s.$story_taskbar.find('.NB-taskbar').append($add);
            $add.animate({'opacity': 1}, {'duration': 600});
        },
        
        add_recommended_feed: function(feed_id) {
            var feed_address = this.model.get_feed(feed_id ? feed_id : this.active_feed).feed_address;
            
            this.open_add_feed_modal({url: feed_address});
        },
        
        approve_feed_in_moderation_queue: function(feed_id) {
            var self = this;
            var $module = $('.NB-module-recommended.NB-recommended-unmoderated');
            $module.addClass('NB-loading');
            var date = $('.NB-recommended-moderation-date').val();
            
            this.model.approve_feed_in_moderation_queue(feed_id, date, function(resp) {
                if (!resp) return;
                $module.removeClass('NB-loading');
                $module.replaceWith(resp);
                self.load_javascript_elements_on_page();
            });
        },
        
        decline_feed_in_moderation_queue: function(feed_id) {
            var self = this;
            var $module = $('.NB-module-recommended.NB-recommended-unmoderated');
            $module.addClass('NB-loading');
            
            this.model.decline_feed_in_moderation_queue(feed_id, function(resp) {
                if (!resp) return;
                $module.removeClass('NB-loading');
                $module.replaceWith(resp);
                self.load_javascript_elements_on_page();
            });
        },
        
        load_recommended_feed: function(direction, refresh, unmoderated) {
            var self = this;
            var $module = unmoderated ? 
                          $('.NB-module-recommended.NB-recommended-unmoderated') :
                          $('.NB-module-recommended:not(.NB-recommended-unmoderated)');
            
            $module.addClass('NB-loading');
            direction = direction || 0;
            
            this.model.load_recommended_feed(this.counts['recommended_feed_page']+direction, 
                                             !!refresh, unmoderated, function(resp) {
                if (!resp) return;
                self.counts['recommended_feed_page'] += direction;

                $module.removeClass('NB-loading');
                $module.replaceWith(resp);
                self.load_javascript_elements_on_page();
            }, $.noop);
        },
        
        // ====================
        // = Dashboard Graphs =
        // ====================
        
        setup_dashboard_graphs: function() {
          // Reload dashboard graphs every 10 minutes.
          clearInterval(this.locks.load_dashboard_graphs);
          this.locks.load_dashboard_graphs = setInterval(_.bind(function() {
              this.load_dashboard_graphs();
          }, this), 10*60*1000);
        },
        
        load_dashboard_graphs: function(direction, refresh) {
            var self = this;
            var $module = $('.NB-module-stats');
            $module.addClass('NB-loading');
            
            this.model.load_dashboard_graphs(function(resp) {
                if (!resp) return;
                $module.removeClass('NB-loading');
                $module.replaceWith(resp);
                self.load_javascript_elements_on_page();
            }, $.noop);
        },
        
        // ==========
        // = Events =
        // ==========

        handle_clicks: function(elem, e) {
            var self = this;
            var stopPropagation = false;
            // var start = (new Date().getMilliseconds());
            
            // NEWSBLUR.log(['click', e, e.button]);
            // Feeds ==========================================================
            
            $.targetIs(e, { tagSelector: '#feed_list .NB-feedlist-manage-icon' }, function($t, $p) {
                e.preventDefault();
                if (!self.flags['sorting_feed']) {
                    stopPropagation = true;
                    if ($t.parent().hasClass('feed')) {
                        self.show_manage_menu('feed', $t.closest('.feed'));
                    } else {
                        var $folder = $t.closest('.folder');
                        self.show_manage_menu('folder', $folder);
                        $folder.addClass('NB-hover');
                    }
                }
            });
            if (stopPropagation) return;
            $.targetIs(e, { tagSelector: '#feed_list .feed.NB-feed-exception' }, function($t, $p){
                e.preventDefault();
                if (!self.flags['sorting_feed']) {
                    var feed_id = parseInt($t.attr('data-id'), 10);
                    stopPropagation = true;
                    self.open_feed_exception_modal(feed_id, $t);
                }
            });
            if (stopPropagation) return;
            
            $.targetIs(e, { tagSelector: '#feed_list .feed:not(.NB-empty)' }, function($t, $p){
                e.preventDefault();
                if (!self.flags['sorting_feed']) {
                    var feed_id = parseInt($t.attr('data-id'), 10);
                    if (NEWSBLUR.hotkeys.command) {
                        self.open_unread_stories_in_tabs(feed_id);
                    } else {
                        self.open_feed(feed_id, false, $t);
                    }
                }
            });
            $.targetIs(e, { tagSelector: '#feed_list .folder_title .NB-feedlist-collapse-icon' }, function($t, $p){
                e.preventDefault();
                stopPropagation = true;
                var $folder = $t.closest('.folder_title');
                if (!self.flags['sorting_feed']) {
                    self.collapse_folder($folder);
                }
            });
            if (stopPropagation) return;
            $.targetIs(e, { tagSelector: '#feed_list .folder_title' }, function($t, $p){
                e.preventDefault();
                var $folder = $t.closest('li.folder');
                var folder_title = $t.find('.folder_title_text').text();
                self.open_river_stories($folder, folder_title);
            });
            
            // ============
            // = Feed Bar =
            // ============
            
            $.targetIs(e, { tagSelector: '.NB-feedbar .NB-feedlist-manage-icon' }, function($t, $p) {
                e.preventDefault();
                self.show_manage_menu('feed', $t.closest('.feed'), {toplevel: true});
            });
            $.targetIs(e, { tagSelector: '.NB-feedbar-mark-feed-read' }, function($t, $p){
                e.preventDefault();
                var feed_id = parseInt($t.closest('.feed').attr('data-id'), 10);
                self.mark_feed_as_read(feed_id, $t);
                $t.fadeOut(400);
            });
            $.targetIs(e, { tagSelector: '.NB-feedbar-statistics' }, function($t, $p){
                self.open_feed_statistics_modal();
            });
            $.targetIs(e, { tagSelector: '.NB-feedbar-train-feed' }, function($t, $p){
                e.preventDefault();
                if (!$('.NB-task-manage').hasClass('NB-disabled')) {
                    self.open_feed_intelligence_modal(1, this.active_feed, true);
                }
            }); 
            $.targetIs(e, { tagSelector: '.NB-story-title-indicator' }, function($t, $p){
                e.preventDefault();
                self.show_hidden_story_titles();
            }); 
            
            // = Feed Header ==================================================
            
            $.targetIs(e, { tagSelector: '.NB-feeds-header-starred' }, function($t, $p){
                e.preventDefault();
                self.open_starred_stories();
            });
            $.targetIs(e, { tagSelector: '.NB-feeds-header-river' }, function($t, $p){
                e.preventDefault();
                self.open_river_stories();
            });
            
            // = Feed Bar =====================================================
            
            $.targetIs(e, { tagSelector: '.NB-feed-like' }, function($t, $p){
                e.preventDefault();
                self.open_feed_intelligence_modal(1);
            });
            $.targetIs(e, { tagSelector: '.NB-feed-dislike' }, function($t, $p){
                e.preventDefault();
                self.open_feed_intelligence_modal(-1);
            });
            
            // = Stories ======================================================
            
            var story_prevent_bubbling = false;
            $.targetIs(e, { tagSelector: '.NB-story-manage-icon' }, function($t, $p) {
                e.preventDefault();
                story_prevent_bubbling = true;
                self.show_manage_menu('story', $t.closest('.story'));
            });
            $.targetIs(e, { tagSelector: '.NB-feed-story-manage-icon' }, function($t, $p) {
                e.preventDefault();
                story_prevent_bubbling = true;
                self.show_manage_menu('story', $t.closest('.NB-feed-story'));
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-open' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-menu-manage-story').data('story_id');
                self.open_story_in_new_tab(story_id);
                story_prevent_bubbling = true;
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-star' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-menu-manage-story').data('story_id');
                var $story = self.find_story_in_story_titles(story_id);
                if ($story.hasClass('NB-story-starred')) {
                  self.mark_story_as_unstarred(story_id, $story);
                } else {
                  self.mark_story_as_starred(story_id, $story);
                }
                story_prevent_bubbling = true;
            });
            $.targetIs(e, { tagSelector: '.NB-feed-story-hide-changes' }, function($t, $p){
                e.preventDefault();
                var $story = $t.closest('.NB-feed-story');
                self.hide_story_changes($story);
                story_prevent_bubbling = true;
            });
            
            if (story_prevent_bubbling) return false;
            
            $.targetIs(e, { tagSelector: '.NB-feed-story-tag' }, function($t, $p){
                e.preventDefault();
                var $story = $t.closest('.NB-feed-story');
                var feed_id = $story.data('feed_id');
                var classifier_type = 'tag';
                var tag = $t.data(classifier_type);
                var score = $t.hasClass('NB-score-1') ? -1 : $t.hasClass('NB-score--1') ? 0 : 1;
                self.save_classifier(classifier_type, tag, score, feed_id);
                self.preserve_classifier_color($story, classifier_type, tag, score);
            });
            
            $.targetIs(e, { tagSelector: '.NB-feed-story-author' }, function($t, $p){
                e.preventDefault();
                var $story = $t.closest('.NB-feed-story');
                var feed_id = $story.data('feed_id');
                var classifier_type = 'author';
                var author = $t.data(classifier_type);
                var score = $t.hasClass('NB-score-1') ? -1 : $t.hasClass('NB-score--1') ? 0 : 1;
                self.save_classifier(classifier_type, author, score, feed_id);
                self.preserve_classifier_color($story, classifier_type, author, score);
            });
            
            $.targetIs(e, { tagSelector: '.story' }, function($t, $p){
                e.preventDefault();
                var story_id = $('.story_id', $t).text();
                self.push_current_story_on_history();
                if (NEWSBLUR.hotkeys.command) {
                    self.open_story_in_new_tab(story_id, $t);
                } else {
                    var story = self.model.get_story(story_id);
                    self.open_story(story, $t);
                }
            });
            $.targetIs(e, { tagSelector: 'a.mark_story_as_read' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.attr('href').slice(1).split('/');
                self.mark_story_as_read(story_id);
            });
            $.targetIs(e, { tagSelector: '.NB-feed-story-premium-only a' }, function($t, $p){
                e.preventDefault();
                self.open_feedchooser_modal();
            });
            
            
            // = Taskbar ======================================================
            
            $.targetIs(e, { tagSelector: '.NB-task-add' }, function($t, $p){
                e.preventDefault();
                self.open_add_feed_modal();
            });  
            $.targetIs(e, { tagSelector: '.NB-task-manage' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.show_manage_menu('site', $t);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-taskbar-sidebar-toggle-close' }, function($t, $p){
                e.preventDefault();
                self.close_sidebar();
            });  
            $.targetIs(e, { tagSelector: '.NB-taskbar-sidebar-toggle-open' }, function($t, $p){
                e.preventDefault();
                self.open_sidebar();
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-train' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                    self.open_feed_intelligence_modal(1, feed_id, false);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-recommend' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                self.open_recommend_modal(feed_id);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-train' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.closest('.NB-menu-manage').data('feed_id');
                    var story_id = $t.closest('.NB-menu-manage').data('story_id');
                    self.open_story_trainer(story_id, feed_id);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-trainer' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_trainer_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-tutorial' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_tutorial_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-stats' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                    NEWSBLUR.log(['statistics feed_id', feed_id]);
                    self.open_feed_statistics_modal(feed_id);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-reload' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                    self.force_instafetch_stories(feed_id);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-delete' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                if ($t.hasClass('NB-menu-manage-feed-delete-cancel') ||
                    $t.hasClass('NB-menu-manage-folder-delete-cancel')) {
                    self.hide_confirm_delete_menu_item();
                } else {
                    self.show_confirm_delete_menu_item();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-delete-confirm' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                self.manage_menu_delete_feed(feed_id, $feed);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-delete-confirm' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.manage_menu_delete_folder(folder_name, $folder);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-move' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                
                if ($t.hasClass('NB-menu-manage-feed-move-cancel') ||
                    $t.hasClass('NB-menu-manage-folder-move-cancel')) {
                    self.hide_confirm_move_menu_item();
                } else {
                    self.show_confirm_move_menu_item(feed_id || folder_name, $feed || $folder);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-move-save' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.manage_menu_rename_folder(folder_name, $folder);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-move-save' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                self.manage_menu_move_feed(feed_id, $feed);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-move-confirm' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-move-confirm' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-rename' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                if ($t.hasClass('NB-menu-manage-feed-rename-cancel') ||
                    $t.hasClass('NB-menu-manage-folder-rename-cancel')) {
                    self.hide_confirm_rename_menu_item();
                } else {
                    self.show_confirm_rename_menu_item();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-rename-save' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.manage_menu_rename_folder(folder_name, $folder);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-rename-save' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                self.manage_menu_rename_feed(feed_id, $feed);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-rename-confirm' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-rename-confirm' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-mark-read' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                self.mark_feed_as_read(feed_id);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-mark-read' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.mark_folder_as_read(folder_name, $folder);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-site-mark-read' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_mark_read_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-keyboard' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_keyboard_shortcuts_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-exception' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');                    
                self.open_feed_exception_modal(feed_id, $t);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-goodies' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_goodies_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-preferences' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_preferences_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-account' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_account_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feedchooser' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_feedchooser_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-account-upgrade' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_feedchooser_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-account-train' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_trainer_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-launch-tutorial' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_tutorial_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-tutorial-hide' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.hide_tutorial();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-mobile-hide' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.hide_mobile();
                }
            });  
            
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-unread' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-menu-manage').data('feed_id'); 
                var story_id = $t.closest('.NB-menu-manage').data('story_id'); 
                self.mark_story_as_unread(story_id, feed_id);
            });  
            
            $.targetIs(e, { tagSelector: '.task_view_page:not(.NB-task-return)' }, function($t, $p){
                e.preventDefault();
                self.switch_taskbar_view('page');
            });
            $.targetIs(e, { tagSelector: '.task_view_feed' }, function($t, $p){
                e.preventDefault();
                self.switch_taskbar_view('feed');
            });
            $.targetIs(e, { tagSelector: '.task_view_story' }, function($t, $p){
                e.preventDefault();
                self.switch_taskbar_view('story');
            });
            $.targetIs(e, { tagSelector: '.NB-task-return' }, function($t, $p){
                e.preventDefault();
                self.load_feed_iframe();
            });         
            $.targetIs(e, { tagSelector: '.task_button_story.task_story_next_unread' }, function($t, $p){
                e.preventDefault();
                self.open_next_unread_story_across_feeds();
            }); 
            $.targetIs(e, { tagSelector: '.task_button_story.task_story_next' }, function($t, $p){
                e.preventDefault();
                self.show_next_story(1);
            }); 
            $.targetIs(e, { tagSelector: '.task_button_story.task_story_previous' }, function($t, $p){
                e.preventDefault();
                self.show_previous_story();
            }); 
            $.targetIs(e, { tagSelector: '.task_button_signup' }, function($t, $p){
                e.preventDefault();
                self.show_splash_page();
            }); 
            $.targetIs(e, { tagSelector: '.NB-feeds-header-sites' }, function($t, $p){
                e.preventDefault();

                stopPropagation = true;
                self.switch_preferences_hide_read_feeds();
            }); 
            if (stopPropagation) return;
            $.targetIs(e, { tagSelector: '.NB-feeds-header-dashboard' }, function($t, $p){
                e.preventDefault();
                self.show_splash_page();
            }); 
            
            // =====================
            // = Recommended Feeds =
            // =====================
            
            $.targetIs(e, { tagSelector: '.NB-recommended-statistics' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').attr('data-feed-id');
                $('.NB-module-recommended').addClass('NB-loading');
                self.model.load_canonical_feed(feed_id, function() {
                    $('.NB-module-recommended').removeClass('NB-loading');
                    self.open_feed_statistics_modal(feed_id);
                });
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-intelligence' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').attr('data-feed-id');
                $('.NB-module-recommended').addClass('NB-loading');
                self.model.load_canonical_feed(feed_id, function() {
                    $('.NB-module-recommended').removeClass('NB-loading');
                    self.open_feed_intelligence_modal(1, feed_id);
                });
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-try' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').attr('data-feed-id');
                self.load_feed_in_tryfeed_view(feed_id);
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-add' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').attr('data-feed-id');
                $('.NB-module-recommended').addClass('NB-loading');
                self.model.load_canonical_feed(feed_id, function() {
                    $('.NB-module-recommended').removeClass('NB-loading');
                    self.add_recommended_feed(feed_id);
                });
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-decline' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').attr('data-feed-id');
                self.decline_feed_in_moderation_queue(feed_id);
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-approve' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').attr('data-feed-id');
                self.approve_feed_in_moderation_queue(feed_id);
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-module-recommended .NB-module-next-page' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    console.log(['parent', $t.closest('.NB-module-recommended'), $t.closest('.NB-module-recommended').hasClass('NB-recommended-unmoderated')]);
                    var unmoderated = $t.closest('.NB-module-recommended').hasClass('NB-recommended-unmoderated');
                    self.load_recommended_feed(1, false, unmoderated);
                }
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-module-recommended .NB-module-previous-page' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var unmoderated = $t.closest('.NB-module-recommended').hasClass('NB-recommended-unmoderated');
                    console.log(['parent', $t.closest('.NB-module-recommended')]);
                    self.load_recommended_feed(-1, false, unmoderated);
                }
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-tryfeed-add' }, function($t, $p){
                e.preventDefault();
                var feed_id = self.active_feed;
                self.add_recommended_feed(feed_id);
            }); 
            
            // = One-offs =====================================================
            
            var clicked = false;
            $.targetIs(e, { tagSelector: '#mouse-indicator' }, function($t, $p){
                e.preventDefault();
                self.lock_mouse_indicator();
            }); 
            $.targetIs(e, { tagSelector: '.NB-progress-close' }, function($t, $p){
                e.preventDefault();
                self.hide_unfetched_feed_progress(true);
            });
            $.targetIs(e, { tagSelector: '.NB-module-next-page', childOf: '.NB-module-features' }, function($t, $p){
                e.preventDefault();
                self.load_feature_page(1);
            }); 
            $.targetIs(e, { tagSelector: '.NB-module-previous-page', childOf: '.NB-module-features' }, function($t, $p){
                e.preventDefault();
                self.load_feature_page(-1);
            });
            $.targetIs(e, { tagSelector: '.NB-module-next-page', childOf: '.NB-module-howitworks' }, function($t, $p){
                e.preventDefault();
                var page = $('.NB-howitworks-page.NB-active').prevAll('.NB-howitworks-page').length;
                self.load_howitworks_page(page+1);
            }); 
            $.targetIs(e, { tagSelector: '.NB-module-previous-page', childOf: '.NB-module-howitworks' }, function($t, $p){
                e.preventDefault();
                var page = $('.NB-howitworks-page.NB-active').prevAll('.NB-howitworks-page').length;
                self.load_howitworks_page(page-1);
            });
            $.targetIs(e, { tagSelector: '.NB-module-page-indicator', childOf: '.NB-module-howitworks' }, function($t, $p){
                e.preventDefault();
                var page = $t.prevAll('.NB-module-page-indicator').length;
                self.load_howitworks_page(page);
            }); 
            $.targetIs(e, { tagSelector: '.NB-splash-meta-about' }, function($t, $p){
              e.preventDefault();
              NEWSBLUR.about = new NEWSBLUR.About();
            }); 
            $.targetIs(e, { tagSelector: '.NB-splash-meta-faq' }, function($t, $p){
              e.preventDefault();
              NEWSBLUR.faq = new NEWSBLUR.Faq();
            }); 
            
            
            
            // NEWSBLUR.log(['End', (new Date().getMilliseconds()) - start]);
        },
        
        handle_dblclicks: function(elem, e) {
            var self = this;
            
            var stopPropagation = false;
            $.targetIs(e, { tagSelector: '#feed_list .NB-feedlist-manage-icon' }, function($t, $p) {
                e.preventDefault();
                e.stopPropagation();
                stopPropagation = true;
            });
            if (stopPropagation) return;
            $.targetIs(e, { tagSelector: '#feed_list .feed.NB-feed-exception' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                exception = true;
            });
            if (stopPropagation) return;
            
            $.targetIs(e, { tagSelector: '#story_titles .story' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                // NEWSBLUR.log(['Story dblclick', $t]);
                var story_id = $('.story_id', $t).text();
                var story = self.model.get_story(story_id); 
                self.open_story_in_story_view(story, true);
            });
            $.targetIs(e, { tagSelector: '#feed_list .feed' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                // NEWSBLUR.log(['Feed dblclick', $('.feed_id', $t), $t]);
                var feed_id = parseInt($t.attr('data-id'), 10);
                self.open_feed_link(feed_id, $t);
            });
        },
        
        handle_rightclicks: function(elem, e) {
            var self = this;
            
            // NEWSBLUR.log(['right click', e.button, e, e.target, e.currentTarget]);
            
            $.targetIs(e, { tagSelector: '.feed', childOf: '#feed_list' }, function($t, $p) {
                e.preventDefault();
                self.show_manage_menu('feed', $t);
            });
            $.targetIs(e, { tagSelector: '.folder_title', childOf: '#feed_list' }, function($t, $p) {
                e.preventDefault();
                self.show_manage_menu('folder', $t.closest('li.folder'));
            });
            $.targetIs(e, { tagSelector: '.story', childOf: '#story_titles' }, function($t, $p) {
                e.preventDefault();
                self.show_manage_menu('story', $t);
            });
            $.targetIs(e, { tagSelector: '.NB-feed-story-header', childOf: '#story_pane' }, function($t, $p) {
                e.preventDefault();
                self.show_manage_menu('story', $t.closest('.NB-feed-story'));
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage' }, function($t, $p) {
                e.preventDefault();
            });
            
            $.targetIs(e, { tagSelector: '.NB-menu-manage-arrow' }, function($t, $p) {
                e.preventDefault();
            });
        },
        
        handle_scroll_story_titles: function(elem, e) {
            var self = this;
            this.check_story_titles_last_story();
        },
        
        handle_scroll_feed_iframe: function(elem, e) {
            var self = this;
            if (this.story_view == 'page'
                && !this.flags['page_view_showing_feed_view']
                && !this.flags['scrolling_by_selecting_story_title']) {
                var from_top = this.cache.mouse_position_y + this.$s.$feed_iframe.contents().scrollTop();
                var positions = this.cache.iframe_story_positions_keys;
                var closest = $.closest(from_top, positions);
                var story = this.cache.iframe_story_positions[positions[closest]];
                // NEWSBLUR.log(['Scroll iframe', from_top, closest, positions[closest], this.cache.iframe_story_positions[positions[closest]]]);
                this.navigate_story_titles_to_story(story);
                if (!this.flags.iframe_scroll_snap_back_prepared) {
                    this.iframe_scroll = from_top - this.cache.mouse_position_y;
                }
                this.flags.iframe_scroll_snap_back_prepared = false;
                // NEWSBLUR.log(['Setting snap back', this.iframe_scroll]);
            }
        },
        
        handle_mousemove_iframe_view: function(elem, e) {
            var self = this;   
                     
            this.show_mouse_indicator();

            if (parseInt(this.model.preference('lock_mouse_indicator'), 10)) {
                return;
            }

            var scroll_top = this.$s.$feed_iframe.contents().scrollTop();
            this.cache.mouse_position_y = e.pageY - scroll_top;
            this.$s.$mouse_indicator.css('top', this.cache.mouse_position_y - 8);

            setTimeout(function() {
                self.flags['mousemove_timeout'] = false;
            }, 40);
            if (!this.flags['mousemove_timeout']
                && !this.flags.scrolling_by_selecting_story_title) {
                var from_top = this.cache.mouse_position_y + scroll_top;
                var positions = this.cache.iframe_story_positions_keys;
                var closest = $.closest(from_top, positions);
                var story = this.cache.iframe_story_positions[positions[closest]];
                this.flags['mousemove_timeout'] = true;
                this.navigate_story_titles_to_story(story);
                // NEWSBLUR.log(['Setting snap back', this.iframe_scroll]);
            }
        },
        
        handle_mousemove_feed_view: function(elem, e) {
            var self = this;
            
            if (this.model.preference('feed_view_single_story')) {
                return this.hide_mouse_indicator();
            } else {
                this.show_mouse_indicator();
            }
            
            if (parseInt(this.model.preference('lock_mouse_indicator'), 10)) {
                return;
            }

            this.cache.mouse_position_y = e.pageY ;
            if (this.cache.story_pane_position == null) {
                this.cache.story_pane_position = this.$s.$feed_stories.offsetParent().offset().top;
            }
            this.$s.$mouse_indicator.css('top', this.cache.mouse_position_y - this.cache.story_pane_position - 8);
            
            if (this.flags['mousemove_timeout']) {
                return;
            }
            
            setTimeout(function() {
                self.flags['mousemove_timeout'] = false;
            }, 40);
            
            if (!this.flags['mousemove_timeout']
                && !this.flags['switching_to_feed_view']
                && !this.flags.scrolling_by_selecting_story_title 
                && this.story_view != 'story') {
                var from_top = this.cache.mouse_position_y + this.$s.$feed_stories.scrollTop();
                var offset = this.cache.story_pane_position;
                var position = from_top - offset;
                var positions = this.cache.feed_view_story_positions_keys;
                var closest = $.closest(position, positions);
                var story = this.cache.feed_view_story_positions[positions[closest]];
                this.flags['mousemove_timeout'] = true;
                if (story == this.active_story) return;
                // NEWSBLUR.log(['Mousemove feed view', from_top, closest, positions[closest]]);
                this.navigate_story_titles_to_story(story);
            }
        },
        
        handle_scroll_feed_view: function(elem, e) {
            var self = this;
            
            // NEWSBLUR.log(['handle_scroll_feed_view', this.story_view, this.flags['switching_to_feed_view'], this.flags['scrolling_by_selecting_story_title']]);
            if ((this.story_view == 'feed' ||
                 (this.story_view == 'page' && this.flags['page_view_showing_feed_view'])) &&
                !this.flags['switching_to_feed_view'] &&
                !this.flags['scrolling_by_selecting_story_title'] &&
                !this.model.preference('feed_view_single_story')) {
                var from_top = this.cache.mouse_position_y + this.$s.$feed_stories.scrollTop();
                var offset = this.cache.story_pane_position;
                var position = from_top - offset;
                var positions = this.cache.feed_view_story_positions_keys;
                var closest = $.closest(position, positions);
                var story = this.cache.feed_view_story_positions[positions[closest]];
                // NEWSBLUR.log(['Scroll feed view', from_top, e, closest, positions[closest], this.cache.feed_view_story_positions_keys, positions, self.cache]);
                this.navigate_story_titles_to_story(story);
            }
            
            if (this.flags.river_view &&
                !this.model.preference('feed_view_single_story')) {
                var story;
                if (this.flags.scrolling_by_selecting_story_title) {
                    story = this.active_story;
                } else {
                    var from_top = Math.max(1, this.$s.$feed_stories.scrollTop());
                    var positions = this.cache.feed_view_story_positions_keys;
                    var closest = $.closest(from_top, positions);
                    story = this.cache.feed_view_story_positions[positions[closest]];
                }
                
                this.show_correct_feed_in_feed_title_floater(story);
            }
        },
        
        handle_keystrokes: function() {      
            var self = this;
            var $document = $(document);
            
            NEWSBLUR.hotkeys.initialize();
            
            $document.bind('keydown', '?', function(e) {
                e.preventDefault();
                self.open_keyboard_shortcuts_modal();
            });
            $document.bind('keydown', 'shift+/', function(e) {
                e.preventDefault();
                self.open_keyboard_shortcuts_modal();
            });
            $document.bind('keydown', 'down', function(e) {
                e.preventDefault();
                self.show_next_story(1);
            });
            $document.bind('keydown', 'up', function(e) {
                e.preventDefault();
                self.show_next_story(-1);
            });                                                           
            $document.bind('keydown', 'j', function(e) {
                e.preventDefault();
                self.show_next_story(1);
            });
            $document.bind('keydown', 'k', function(e) {
                e.preventDefault();
                self.show_next_story(-1);
            });                                     
            $document.bind('keydown', 'shift+j', function(e) {
                e.preventDefault();
                self.show_next_feed(1);
            });
            $document.bind('keydown', 'shift+k', function(e) {
                e.preventDefault();
                self.show_next_feed(-1);
            });                       
            $document.bind('keydown', 'shift+down', function(e) {
                e.preventDefault();
                self.show_next_feed(1);
            });
            $document.bind('keydown', 'shift+up', function(e) {
                e.preventDefault();
                self.show_next_feed(-1);
            });
            $document.bind('keydown', 'left', function(e) {
                e.preventDefault();
                self.switch_taskbar_view_direction(-1);
            });
            $document.bind('keydown', 'right', function(e) {
                e.preventDefault();
                self.switch_taskbar_view_direction(1);
            });
            $document.bind('keydown', 'h', function(e) {
                e.preventDefault();
                self.switch_taskbar_view_direction(-1);
            });
            $document.bind('keydown', 'l', function(e) {
                e.preventDefault();
                self.switch_taskbar_view_direction(1);
            });
            $document.bind('keydown', 'r', function(e) {
                e.preventDefault();
                self.open_river_stories();
            });
            $document.bind('keydown', 'enter', function(e) {
                e.preventDefault();
                self.open_story_in_story_view(null, true);
            });
            $document.bind('keydown', 'return', function(e) {
                e.preventDefault();
                self.open_story_in_story_view(null, true);
            });
            $document.bind('keydown', 'space', function(e) {
                e.preventDefault();
                self.page_in_story(0.2, 1);
            });
            $document.bind('keydown', 'shift+space', function(e) {
                e.preventDefault();
                self.page_in_story(0.4, -1);
            });
            $document.bind('keydown', 'u', function(e) {
                e.preventDefault();
                if (self.flags['sidebar_closed']) {
                    self.open_sidebar();
                } else {
                    self.close_sidebar();
                }
            });
            $document.bind('keydown', 'n', function(e) {
                e.preventDefault();
                self.open_next_unread_story_across_feeds();
            });
            $document.bind('keydown', 'b', function(e) {
                e.preventDefault();
                self.show_previous_story();
            });
            $document.bind('keydown', 's', function(e) {
                e.preventDefault();
                if (self.active_story) {
                    var story_id = self.active_story.id;
                    var $story = self.find_story_in_story_titles(story_id);
                    if ($story.hasClass('NB-story-starred')) {
                      self.mark_story_as_unstarred(story_id, $story);
                    } else {
                      self.mark_story_as_starred(story_id, $story);
                    }
                }
            });
            $document.bind('keypress', '+', function(e) {
                e.preventDefault();
                self.move_intelligence_slider(1);
            });
            $document.bind('keypress', '-', function(e) {
                e.preventDefault();
                self.move_intelligence_slider(-1);
            });
            $document.bind('keypress', 'd', function(e) {
                e.preventDefault();
                self.show_splash_page();
            });
            $document.bind('keypress', 't', function(e) {
                e.preventDefault();
                self.open_story_trainer();
            });
            $document.bind('keypress', 'f', function(e) {
                e.preventDefault();
                self.open_feed_intelligence_modal(1);
            });
            $document.bind('keypress', 'o', function(e) {
                e.preventDefault();
                self.open_story_in_new_tab();
            });
            $document.bind('keydown', 'shift+a', function(e) {
                e.preventDefault();
                if (self.flags.river_view) {
                    self.mark_folder_as_read();
                } else {
                    self.mark_feed_as_read();
                }
            });
        }
        
    };

})(jQuery);