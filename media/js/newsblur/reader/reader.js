(function($) {

    NEWSBLUR.Reader = Backbone.Router.extend({
    
        init: function(options) {
            
            var defaults = {};
            if (console && console.clear && _.isFunction(console.clear)) console.clear();
            
            // ===========
            // = Globals =
            // ===========
            
            NEWSBLUR.assets = new NEWSBLUR.AssetModel();
            this.model = NEWSBLUR.assets;
            this.story_view = 'page';
            this.story_layout = 'split';
            this.options = _.extend({}, defaults, options);
            this.$s = {
                $body: $('body'),
                $layout: $('.NB-layout'),
                $sidebar: $('.NB-sidebar'),
                $feed_lists: $('.NB-feedlists'),
                $feed_list: $('#feed_list'),
                $social_feeds: $('.NB-socialfeeds-folder'),
                $starred_feeds: $('.NB-starred-folder'),
                $story_titles: $('#story_titles'),
                $story_titles_header: $('.NB-story-titles-header'),
                $content_pane: $('.content-pane'),
                $story_taskbar: $('#story_taskbar'),
                $story_pane: $('#story_pane .NB-story-pane-container'),
                $feed_view: $('.NB-feed-story-view'),
                $feed_scroll: $('.NB-feed-stories-container'),
                $feed_stories: $('.NB-feed-stories'),
                $feed_iframe: $('.NB-feed-iframe'),
                $story_view: $('.NB-story-view'),
                $story_iframe: $('.NB-story-iframe'),
                $text_view: $('.NB-text-view'),
                $intelligence_slider: $('.NB-intelligence-slider'),
                $mouse_indicator: $('#mouse-indicator'),
                $feed_link_loader: $('#NB-feeds-list-loader'),
                $feeds_progress: $('#NB-progress'),
                $dashboard: $('.NB-feeds-header-dashboard'),
                $river_sites_header: $('.NB-feeds-header-river-sites'),
                $river_blurblogs_header: $('.NB-feeds-header-river-blurblogs'),
                $river_global_header: $('.NB-feeds-header-river-global'),
                $starred_header: $('.NB-feeds-header-starred'),
                $read_header: $('.NB-feeds-header-read'),
                $tryfeed_header: $('.NB-feeds-header-tryfeed'),
                $taskbar: $('.NB-taskbar-view'),
                $feed_floater: $('.NB-feed-story-view-floater'),
                $feedbar: $('.NB-feedbar'),
                $add_button: $('.NB-task-add'),
                $taskbar_options: $('.NB-taskbar-options')
            };
            this.flags = {
                'bouncing_callout': false,
                'has_unfetched_feeds': false,
                'count_unreads_after_import_working': false,
                'import_from_google_reader_working': false,
                'sidebar_closed': this.options.hide_sidebar
            };
            this.locks = {};
            this.counts = {
                'page': 1,
                'feature_page': 0,
                'unfetched_feeds': 0,
                'fetched_feeds': 0,
                'page_fill_outs': 0,
                'recommended_feed_page': 0,
                'interactions_page': 1,
                'activities_page': 1,
                'socket_reconnects': 0
            };
            this.cache = {
                'iframe_story_positions': {},
                'feed_view_story_positions': {},
                'iframe_story_positions_keys': [],
                'feed_view_story_positions_keys': [],
                'river_feeds_with_unreads': [],
                '$feed_in_social_feed_list': {}
            };
            this.views = {};
            this.layout = {};
            this.constants = {
              FEED_REFRESH_INTERVAL: (1000 * 60) * 1, // 1 minute
              FILL_OUT_PAGES: 100,
              FIND_NEXT_UNREAD_STORY_TRIES: 100,
              RIVER_STORIES_FOR_STANDARD_ACCOUNT: 5,
              MIN_FEED_LIST_SIZE: 206,
              MIN_STORY_LIST_SIZE: 68
            };
    
            // ==================
            // = Event Handlers =
            // ==================
    
            $(window).bind('resize.reader', _.throttle($.rescope(this.resize_window, this), 1000));
            this.$s.$body.bind('click.reader', $.rescope(this.handle_clicks, this));
            this.$s.$body.bind('keyup.reader', $.rescope(this.handle_keyup, this));
            this.handle_keystrokes();
        
            // ==================
            // = Initialization =
            // ==================
    
            var refresh_page = this.check_and_load_ssl();
            if (refresh_page) return;
            this.load_javascript_elements_on_page();
            this.apply_resizable_layout();
            this.add_body_classes();
            if (NEWSBLUR.Flags['start_import_from_google_reader']) {
                this.start_import_from_google_reader();
            }
            NEWSBLUR.app.sidebar_header = new NEWSBLUR.Views.SidebarHeader({
                feed_collection: NEWSBLUR.assets.feeds,
                socialfeed_collection: NEWSBLUR.assets.social_feeds
            });
            NEWSBLUR.app.sidebar = new NEWSBLUR.Views.Sidebar();
            NEWSBLUR.app.feed_list = new NEWSBLUR.Views.FeedList({el: this.$s.$feed_list[0]});
            NEWSBLUR.app.story_titles = new NEWSBLUR.Views.StoryTitlesView({collection: NEWSBLUR.assets.stories});
            NEWSBLUR.app.story_list = new NEWSBLUR.Views.StoryListView({collection: NEWSBLUR.assets.stories});
            NEWSBLUR.app.original_tab_view = new NEWSBLUR.Views.OriginalTabView({collection: NEWSBLUR.assets.stories});
            NEWSBLUR.app.story_tab_view = new NEWSBLUR.Views.StoryTabView({collection: NEWSBLUR.assets.stories});
            NEWSBLUR.app.text_tab_view = new NEWSBLUR.Views.TextTabView({
                el: this.$s.$text_view,
                collection: NEWSBLUR.assets.stories
            });
            NEWSBLUR.app.feed_selector = new NEWSBLUR.Views.FeedSelector();
            NEWSBLUR.app.follow_requests_module = new NEWSBLUR.Views.FollowRequestsModule();
            NEWSBLUR.app.dashboard_search = new NEWSBLUR.Views.DashboardSearch();
            NEWSBLUR.app.taskbar_info = new NEWSBLUR.Views.ReaderTaskbarInfo().render();
            NEWSBLUR.app.story_titles_header = new NEWSBLUR.Views.StoryTitlesHeader();
            
            this.load_intelligence_slider();
            this.handle_mouse_indicator_hover();
            this.handle_login_and_signup_forms();
            this.apply_story_styling();
            this.load_recommended_feeds();
            this.setup_dashboard_graphs();
            this.setup_feedback_table();
            this.setup_howitworks_hovers();
            this.setup_unfetched_feed_check();
            this.switch_story_layout();
            this.load_delayed_stylesheets();
        },

        // ========
        // = Page =
        // ========
        
        logout: function() {
            console.log(['Logout']);
            window.location.href = "/reader/logout";
        },
        
        check_and_load_ssl: function() {
            if (window.location.protocol == 'http:' && this.model.preference('ssl')) {
                window.location.href = window.location.href.replace('http:', 'https:');
                return true;
            }
        },
        
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
            } else if (this.flags['temporary_story_view']) {
                view = 'text';
                flag = 'text';
            }
            
            this.flags.scrolling_by_selecting_story_title = true;
            clearTimeout(this.locks.scrolling);
            this.locks.scrolling = _.delay(_.bind(function() {
                this.flags.scrolling_by_selecting_story_title = false;
            }, this), 1000);
            if (!this.flags['opening_feed'] && NEWSBLUR.app.story_unread_counter) {
                NEWSBLUR.app.story_unread_counter.center();
            }
            this.position_mouse_indicator();
            
            this.switch_taskbar_view(view, {
                skip_save_type: flag,
                resize: true
            });

            if (_.contains(['split', 'list', 'grid'],
                NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                NEWSBLUR.app.story_titles.fill_out();
            } else {
                NEWSBLUR.app.story_list.fill_out();
            }

            this.flags.fetch_story_locations_in_feed_view = this.flags.fetch_story_locations_in_feed_view ||
                                                            _.throttle(function() {
                                                                NEWSBLUR.app.story_list.reset_story_positions();
                                                            }, 2000);
            this.flags.fetch_story_locations_in_feed_view();
            this.adjust_for_narrow_window();
        },
        
        adjust_for_narrow_window: function() {
            var north, center, west;
            var story_layout = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
            var content_width;
            var $windows = this.$s.$body.add(this.$s.$feed_view)
                                        .add(this.$s.$story_titles)
                                        .add(this.$s.$text_view);
            if (story_layout == 'split') {
                north = NEWSBLUR.reader.layout.contentLayout.panes.north;
                center = NEWSBLUR.reader.layout.contentLayout.panes.center;
                west = NEWSBLUR.reader.layout.contentLayout.panes.west;
            } else {
                center = NEWSBLUR.reader.layout.rightLayout.panes.center;
            }
            if (center) {
                var center_width = center.width();
                var narrow = center_width < 780;
                if (NEWSBLUR.assets.preference('story_button_placement') == "bottom") {
                    narrow = true;
                }
                $windows.toggleClass('NB-narrow-content', narrow);
                var extranarrow = center_width < 580;
                $windows.toggleClass('NB-extra-narrow-content', extranarrow);
                var wide = center_width > 860;
                $windows.toggleClass('NB-wide-content', wide);
                var extrawide = center_width > 1180;
                $windows.toggleClass('NB-extra-wide-content', extrawide);
                this.flags.narrow_content = !!narrow;
                content_width = center_width + (west ? west.width() : 0);
            }
            
            if ((north && north.width() < 640) ||
                (content_width && content_width < 780)) {
                $windows.addClass('NB-narrow');
            } else {
                $windows.removeClass('NB-narrow');
            }
            
            var pane = this.layout.outerLayout.panes.west;
            var width = this.layout.outerLayout.state.west.size;
            pane.toggleClass("NB-narrow-pane-blue", width < 290);
            pane.toggleClass("NB-narrow-pane-green", width < 259);
            pane.toggleClass("NB-narrow-pane-yellow", width < 236);
            
            this.apply_tipsy_titles();
        },
        
        apply_resizable_layout: function(options) {
            options = options || {};
            var story_anchor = this.model.preference('story_pane_anchor');
            
            if (options.right_side) {
                this.layout.contentLayout && this.layout.contentLayout.destroy();
                this.layout.rightLayout && this.layout.rightLayout.destroy();
                // this.layout.leftCenterLayout && this.layout.leftCenterLayout.destroy();
                // this.layout.leftLayout && this.layout.leftLayout.destroy();
                // this.layout.outerLayout && this.layout.outerLayout.destroy();

                var feed_stories_bin = $.make('div').append(this.$s.$feed_stories.children());
                var story_titles_bin = $.make('div').append(this.$s.$story_titles.children());
            }
            
            $('.right-pane').removeClass('NB-story-pane-west')
                            .removeClass('NB-story-pane-north')
                            .removeClass('NB-story-pane-south')
                            .removeClass('NB-story-pane-hidden')
                            .toggleClass('NB-story-pane-'+story_anchor,
                                         NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'split');
            if (!options.right_side) {
                this.layout.outerLayout = this.$s.$layout.layout({ 
                    zIndex:                 2,
                    fxName:                 "slideOffscreen",
                    fxSettings:             { duration: 560, easing: "easeInOutQuint" },
                    center__paneSelector:   ".right-pane",
                    west__paneSelector:     ".left-pane",
                    west__size:             this.model.preference('feed_pane_size'),
                    west__minSize:          this.constants.MIN_FEED_LIST_SIZE,
                    west__onresize_end:     _.bind(this.save_feed_pane_size, this),
                    // west__initHidden:       this.options.hide_sidebar,
                    west__spacing_open:     this.options.hide_sidebar ? 1 : 1,
                    resizerDragOpacity:     0.6,
                    resizeWhileDragging:    true,
                    enableCursorHotkey:     false,
                    togglerLength_open:     0
                }); 
                
                // What the hell is this handling?
                // if (this.model.preference('feed_pane_size') < 242) {
                //     this.layout.outerLayout.resizeAll();
                // }

                this.layout.leftLayout = $('.left-pane').layout({
                    closable:               false,
                    resizeWhileDragging:    true,
                    fxName:                 "slideOffscreen",
                    fxSettings:             { duration: 560, easing: "easeInOutQuint" },
                    animatePaneSizing:      true,
                    north__paneSelector:    ".left-north",
                    north__size:            37,
                    north__resizeable:      false,
                    north__spacing_open:    0,
                    center__paneSelector:   ".left-center",
                    center__resizable:      false,
                    south__paneSelector:    ".left-south",
                    south__size:            31,
                    south__resizable:       false,
                    enableCursorHotkey:     false,
                    togglerLength_open:     0,
                    south__spacing_open:    0
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
                    fxName:                 "slideOffscreen",
                    fxSettings_close:       { duration: 560, easing: "easeInOutQuint" },
                    fxSettings_open:        { duration: 0 },
                    enableCursorHotkey:     false,
                    togglerLength_open:     0
                });
            }

            if (_.contains(['split', 'full'], 
                NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                var rightLayoutOptions = { 
                    resizeWhileDragging:    true,
                    center__paneSelector:   ".content-pane",
                    spacing_open:           0,
                    resizerDragOpacity:     0.6,
                    enableCursorHotkey:     false,
                    togglerLength_open:     0,
                    fxName:                 "slideOffscreen",
                    fxSettings_close:       { duration: 560, easing: "easeInOutQuint" },
                    fxSettings_open:        { duration: 0, easing: "easeInOutQuint" },
                    north__paneSelector:    ".content-north",
                    north__size:            37,
                    south__paneSelector:    ".content-south",
                    south__size:            31
                };

                this.layout.rightLayout = $('.right-pane').layout(rightLayoutOptions); 

                var contentLayoutOptions = { 
                    fxName:                 "slideOffscreen",
                    fxSettings_close:       { duration: 560, easing: "easeInOutQuint" },
                    fxSettings_open:        { duration: 0, easing: "easeInOutQuint" },
                    resizeWhileDragging:    true,
                    center__paneSelector:   ".content-center",
                    spacing_open:           story_anchor == 'west' ? 1 : 4,
                    resizerDragOpacity:     0.6,
                    enableCursorHotkey:     false,
                    togglerLength_open:     0
                };
                if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                    contentLayoutOptions[story_anchor+'__initHidden'] = true;
                    this.flags['story_titles_closed'] = true;                    
                } else {
                    this.flags['story_titles_closed'] = false;
                }
                contentLayoutOptions[story_anchor+'__paneSelector'] = '.right-north';
                contentLayoutOptions[story_anchor+'__minSize'] = this.constants.MIN_STORY_LIST_SIZE;
                contentLayoutOptions[story_anchor+'__size'] = this.model.preference('story_titles_pane_size');
                contentLayoutOptions[story_anchor+'__onresize_end'] = $.rescope(this.save_story_titles_pane_size, this);
                contentLayoutOptions[story_anchor+'__onclose_start'] = $.rescope(this.toggle_story_titles_pane, this);
                contentLayoutOptions[story_anchor+'__onopen_start'] = $.rescope(this.toggle_story_titles_pane, this);
                this.layout.contentLayout = this.$s.$content_pane.layout(contentLayoutOptions); 
            } else if (_.contains(['list', 'grid'],
                       NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                var rightLayoutOptions = { 
                    resizeWhileDragging:    true,
                    center__paneSelector:   ".content-pane",
                    spacing_open:           0,
                    resizerDragOpacity:     0.6,
                    enableCursorHotkey:     false,
                    togglerLength_open:     0,
                    fxName:                 "slideOffscreen",
                    fxSettings:             { duration: 560, easing: "easeInOutQuint" },
                    north__paneSelector:    ".content-north",
                    north__size:            37,
                    south__paneSelector:    ".content-south",
                    south__size:            31
                    
                };
                this.layout.rightLayout = $('.right-pane').layout(rightLayoutOptions); 
                
                var contentLayoutOptions = { 
                    resizeWhileDragging:    true,
                    center__paneSelector:   ".right-north",
                    spacing_open:           0,
                    resizerDragOpacity:     0.6,
                    enableCursorHotkey:     false,
                    togglerLength_open:     0
                };
                this.layout.contentLayout = this.$s.$content_pane.layout(contentLayoutOptions);                 
                this.flags['story_titles_closed'] = false;
            }

            if (options.right_side) {
                this.$s.$feed_stories.append(feed_stories_bin.children());
                this.$s.$story_titles.append(story_titles_bin.children());
                this.resize_window();
            }
            
            this.adjust_for_narrow_window();
        },
        
        apply_tipsy_titles: function() {
            $('.NB-task-add').tipsy('disable');
            $('.NB-task-manage').tipsy('disable');
            $('.NB-taskbar-button.NB-tipsy').each(function() {
                $(this).tipsy('disable');
            });
            
            if (this.model.preference('show_tooltips')) {
                $('.NB-task-add').tipsy({
                    gravity: 'sw',
                    delayIn: 375
                }).tipsy('enable');
                $('.NB-task-manage').tipsy({
                    gravity: 's',
                    delayIn: 375
                }).tipsy('enable');
                $('.NB-narrow .NB-taskbar-button.NB-tipsy').tipsy({
                    gravity: 's',
                    delayIn: 175,
                    title: 'tipsy-title'
                }).each(function() {
                    $(this).tipsy('enable');
                });
            }
            
            $('.NB-module-content-account-realtime').tipsy('disable').tipsy({
                gravity: 'se',
                delayIn: 0
            }).tipsy('enable');
        },
        
        save_feed_pane_size: function(w, pane, $pane, state, options, name) {
            var feed_pane_size = state.size;
            
            $('#NB-splash').css('left', feed_pane_size);
            this.adjust_for_narrow_window();
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
                var story_titles_size = this.layout.contentLayout.state[this.model.preference('story_pane_anchor')].size;
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
        
        add_body_classes: function() {
            this.$s.$body.toggleClass('NB-is-premium',        NEWSBLUR.Globals.is_premium);
            this.$s.$body.toggleClass('NB-is-anonymous',      NEWSBLUR.Globals.is_anonymous);
            this.$s.$body.toggleClass('NB-is-authenticated',  NEWSBLUR.Globals.is_authenticated);
            this.$s.$body.toggleClass('NB-pref-full-width-story', !!this.model.preference('full_width_story'));
            this.$s.$body.removeClass('NB-story-layout-full')
                         .removeClass('NB-story-layout-split')
                         .removeClass('NB-story-layout-list')
                         .addClass('NB-story-layout-'+NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'));
        },
        
        load_delayed_stylesheets: function() {
            _.delay(function() {
                var $stylesheets = $("head link");
                $stylesheets.each(function() {
                    var $ss = $(this);
                    if (!$ss.attr('delay')) return;
                    $("head").append($.make('link', {
                        rel: $ss.attr('rel'),
                        type: $ss.attr('type'),
                        href: $ss.attr('delay')
                    }));
                });
            }, 500);
        },
        
        hide_splash_page: function() {
            var self = this;
            var resize = false;
            if (!$('.right-pane').is(':visible')) {
                resize = true;
            }
            this.$s.$body.addClass('NB-show-reader');

            if (resize) {
                this.$s.$layout.layout().resizeAll();
                this.adjust_for_narrow_window();
            }
            
            this.apply_tipsy_titles();
            if (NEWSBLUR.Globals.is_anonymous) {
                this.setup_ftux_signup_callout();
            }
        },
        
        show_splash_page: function(skip_router) {
            this.reset_feed();
            this.$s.$body.removeClass('NB-show-reader');

            if (!skip_router) {
                NEWSBLUR.router.navigate('');
            }
        },
        
        animate_progress_bar: function($bar, seconds, percentage) {
            var self = this;
            percentage = percentage || 0;
            seconds = parseFloat(Math.max(1, parseInt(seconds, 10)), 10);
            
            if (percentage > 90) {
                time = seconds;
            } else if (percentage > 80) {
                time = seconds / 8;
            } else if (percentage > 70) {
                time = seconds / 16;
            } else if (percentage > 60) {
                time = seconds / 40;
            } else if (percentage > 50) {
                time = seconds / 80;
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
        
        blur_to_page: function(options) {
            options = options || {};
            
            if (options.manage_menu) {
                $('.NB-menu-manage-container .NB-menu-manage :focus').blur();
            } else {
                $(':focus').blur();
            }
        },
        
        // ==============
        // = Navigation =
        // ==============
        
        show_next_story: function(direction) {
            var story = NEWSBLUR.assets.stories.get_next_story(direction, {
                score: this.get_unread_view_score()
            });
            if (story) {
                story.set('selected', true);
            }
            
            if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full' &&
                !this.model.flags['no_more_stories']) {
                var visible = NEWSBLUR.assets.stories.visible();
                var visible_count = visible.length;
                var visible_index = visible.indexOf(this.active_story);
                
                if (visible_index >= visible_count - 3) {
                    this.load_page_of_feed_stories();
                }
            }
        },
        
        show_next_unread_story: function() {
            var unread_count = this.get_total_unread_count();

            if (this.flags['feed_list_showing_starred']) {
                this.slide_intelligence_slider(0);
                this.flags['feed_list_showing_starred'] = false;
                this.open_next_unread_story_across_feeds();
            } else if (unread_count) {
                var next_story = NEWSBLUR.assets.stories.get_next_unread_story();
                if (next_story) {
                    this.counts['find_next_unread_on_page_of_feed_stories_load'] = 0;
                    next_story.set('selected', true);
                } else if (this.counts['find_next_unread_on_page_of_feed_stories_load'] <
                           this.constants.FIND_NEXT_UNREAD_STORY_TRIES && 
                           !this.model.flags['no_more_stories']) {
                    // Nothing up, nothing down, but still unread. Load 1 page then find it.
                    this.counts['find_next_unread_on_page_of_feed_stories_load'] += 1;
                    this.load_page_of_feed_stories();
                } else if (this.counts['find_next_unread_on_page_of_feed_stories_load'] >=
                           this.constants.FIND_NEXT_UNREAD_STORY_TRIES) {
                    this.open_next_unread_story_across_feeds(true);
                }
            }
        },
        
        open_next_unread_story_across_feeds: function(force_next_feed) {
            var unread_count = !force_next_feed && this.active_feed && this.get_total_unread_count();

            if (!unread_count && !this.flags['feed_list_showing_starred']) {
                if (this.flags.river_view && !this.flags.social_view) {
                    var $next_folder = this.get_next_unread_folder(1);
                    var folder = NEWSBLUR.assets.folders.get_view($next_folder);
                    if (folder != this.active_folder) {
                        this.open_river_stories($next_folder, folder && folder.model);
                    }
                } else {
                    // Find next feed with unreads
                    var $next_feed = this.get_next_unread_feed(1);
                    if (!$next_feed || !$next_feed.length) return;
                    var next_feed_id = $next_feed.data('id');
                    if (next_feed_id == this.active_feed) return;
                    
                    if (NEWSBLUR.utils.is_feed_social(next_feed_id)) {
                        this.open_social_stories(next_feed_id, {force: true, $feed: $next_feed});
                    } else {
                        next_feed_id = parseInt(next_feed_id, 10);
                        this.open_feed(next_feed_id, {force: true, $feed: $next_feed});
                    }
                }
            }

            this.show_next_unread_story();
        },
        
        show_last_unread_story: function() {
            var unread_count = this.get_total_unread_count();
            
            if (unread_count) {
                var last_story = NEWSBLUR.assets.stories.get_last_unread_story(unread_count);
                
                if (last_story) {
                    this.counts['find_last_unread_on_page_of_feed_stories_load'] = 0;
                    last_story.set('selected', true);
                } else if (this.counts['find_last_unread_on_page_of_feed_stories_load'] < this.constants.FILL_OUT_PAGES && 
                           !this.model.flags['no_more_stories']) {
                    // Nothing up, nothing down, but still unread. Load 1 page then find it.
                    this.counts['find_last_unread_on_page_of_feed_stories_load'] += 1;
                    this.load_page_of_feed_stories();
                }
            }
        },
        
        select_story_in_feed: function() {
            var story_id = this.flags['select_story_in_feed'];
            var story = NEWSBLUR.assets.stories.get(story_id);
            // NEWSBLUR.log(['select_story_in_feed', story_id, story, this.story_view, this.counts['select_story_in_feed'], this.flags['no_more_stories']]);
            
            if (story) {
                this.counts['select_story_in_feed'] = 0;
                this.flags['select_story_in_feed'] = null;
                _.delay(_.bind(function() {
                    // Even though a story_id is specified, this just means go to the comments.
                    // Refactor when stories can be scrolled to separately from comments.
                    story.set('selected', true, {scroll_to_comments: true});
                }, this), 100);
            } else if (this.counts['select_story_in_feed'] < this.constants.FILL_OUT_PAGES && 
                       !this.model.flags['no_more_stories']) {
                // Nothing up, nothing down, but still not found. Load 1 page then find it.
                this.counts['select_story_in_feed'] += 1;
                this.load_page_of_feed_stories();
            } else {
                this.counts['select_story_in_feed'] = 0;
                this.flags['select_story_in_feed'] = null;
            }
        },
        
        show_previous_story: function() {
            NEWSBLUR.assets.stories.select_previous_story();
        },
        
        show_next_feed: function(direction, $current_feed) {
            var $feed_list = this.$s.$feed_list.add(this.$s.$social_feeds);
            
            if (this.flags.river_view && !this.flags.social_view) {
                return this.show_next_folder(direction, $current_feed);
            }
            
            var $next_feed = this.get_next_feed(direction, $current_feed, {
                include_selected: true,
                feed_id: this.active_feed
            });
            
            if (!$next_feed || $current_feed == $next_feed) return;
            if ($current_feed && $current_feed.data('id') == $next_feed.data('id')) return;
            
            var next_feed_id = $next_feed.data('id');
            if (next_feed_id && next_feed_id == this.active_feed) {
                this.show_next_feed(direction, $next_feed);
            } else if (NEWSBLUR.utils.is_feed_social(next_feed_id)) {
                this.open_social_stories(next_feed_id, {force: true, $feed: $next_feed});
            } else {
                next_feed_id = parseInt(next_feed_id, 10);
                this.open_feed(next_feed_id, {force: true, $feed: $next_feed});
            }
        },
        
        show_next_folder: function(direction, $current_folder) {
            var $next_folder = this.get_next_folder(direction, $current_folder);
            
            if (!$next_folder) return;
            
            var folder = NEWSBLUR.assets.folders.get_view($next_folder);

            this.open_river_stories($next_folder, folder && folder.model);
        },
        
        get_next_feed: function(direction, $current_feed, options) {
            options = options || {};
            var self = this;
            var $feed_list = this.$s.$feed_list.add(this.$s.$social_feeds);
            if (!$current_feed) {
                $current_feed = $('.selected', $feed_list);
            }
            if (options.feed_id && $current_feed && $current_feed.length) {
                var current_feed = NEWSBLUR.assets.get_feed(options.feed_id);
                if (current_feed) {
                    var selected_title_view = current_feed.get("selected_title_view");
                    if (selected_title_view) {
                        $current_feed = selected_title_view.$el;
                    }
                }
            }
            var $next_feed,
                scroll;
            var $feeds = $('.feed:visible:not(.NB-empty)', $feed_list);
            if (!$current_feed.length) {
                if (options.include_selected) {
                    $feeds = $feeds.add('.NB-feedlists .feed.NB-selected');
                }
                $current_feed = $('.feed:visible:not(.NB-empty)', $feed_list)[direction==-1?'last':'first']();
                $next_feed = $current_feed;
            } else {
                var current_feed = 0;
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
        
        get_next_folder: function(direction, $current_folder) {
            var self = this;
            var $feed_list = this.$s.$feed_list.add(this.$s.$social_feeds);
            var $current_folder = $('.folder.NB-selected', $feed_list);
            var $folders = $('li.folder:visible:not(.NB-empty)', $feed_list);
            var current_folder = 0;

            $folders.each(function(i) {
                if (this == $current_folder[0]) {
                    current_folder = i;
                    return false;
                }
            });
            
            var next_folder_index = (current_folder+direction) % ($folders.length);
            var $next_folder = $folders.eq(next_folder_index);
            
            return $next_folder;
        },

        get_next_unread_feed: function(direction, $current_feed) {
            var self = this;
            var $feed_list = this.$s.$feed_list.add(this.$s.$social_feeds);
            $current_feed = $current_feed || $('.selected', $feed_list);
            var unread_view = this.get_unread_view_name();
            var $next_feed;
            var current_feed;
            
            var $feeds = $('.feed:visible:not(.NB-empty)', $feed_list).filter(function() {
              var $this = $(this);
              if ($this.hasClass('selected')) {
                  return true;
              } else if (unread_view == 'positive') {
                return $this.is('.unread_positive');
              } else if (unread_view == 'neutral') {
                return $this.is('.unread_positive,.unread_neutral');
              } else if (unread_view == 'negative') {
                return $this.is('.unread_positive,.unread_neutral,.unread_negative');
              }
            }).add('.NB-feedlists .feed.NB-selected');
            if (!$current_feed.length) {
              $next_feed = $feeds.first();
            } else {
              $feeds.each(function(i) {
                  if (this == $current_feed.get(0)) {
                      current_feed = i;
                      return false;
                  }
              });
              $next_feed = $feeds.eq((current_feed+direction) % ($feeds.length));
            }
            
            return $next_feed;
        },
        
        get_next_unread_folder: function(direction) {
            var self = this;
            var $feed_list = this.$s.$feed_list.add(this.$s.$social_feeds);
            var $current_folder = $('.folder.NB-selected', $feed_list);
            var unread_view = this.get_unread_view_name();
            var $next_folder;
            var current_folder = 0;
            var $folders = $('li.folder:visible:not(.NB-empty)', $feed_list);
            
            $folders = $folders.filter(function() {
                var $this = $(this);
                var folder_view = NEWSBLUR.assets.folders.get_view($current_folder);
                var folder_model = folder_view && folder_view.model;
                if (!folder_model) return false;
                
                var counts = folder_model.collection.unread_counts();
                
                if (this == $current_folder[0]) return true;
                
                if (unread_view == 'positive') {
                    return counts.ps;
                } else if (unread_view == 'neutral') {
                    return counts.ps + counts.nt;
                } else if (unread_view == 'negative') {
                    return counts.ps + counts.nt + counts.ng;
                }
            });

            $folders.each(function(i) {
                if (this == $current_folder[0]) {
                    current_folder = i;
                    return false;
                }
            });
            $next_folder = $folders.eq((current_folder+direction) % ($folders.length));
            return $next_folder;
        },
        
        page_in_story: function(amount, direction) {
            amount = parseInt(amount, 10) / 100.0;
            var page_height = this.$s.$story_pane.height();
            if (_.contains(['list', 'grid'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                page_height = this.$s.$story_titles.height();
            }
            var scroll_height = parseInt(page_height * amount, 10);
            var feed_view = NEWSBLUR.assets.preference('feed_view_single_story') && 
                            ((this.story_view == 'feed' && !this.flags['temporary_story_view']) || 
                             this.flags['page_view_showing_feed_view']);
            var text_view = this.story_view == 'text' || this.flags['temporary_story_view'];
            
            this.scroll_in_story(scroll_height, direction);
            
            if (NEWSBLUR.assets.preference('space_bar_action') == 'scroll_only') return;
            if (NEWSBLUR.assets.preference('space_bar_action') == 'next_unread_50') {
                page_height = page_height / 2 + 36;
            }
            
            if (!this.active_story || !this.active_story.get('selected')) {
                this.open_next_unread_story_across_feeds();                
            } else if (_.contains(['split', 'full'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                if (direction > 0) {
                    if (feed_view) {
                        var scroll_top = this.$s.$feed_scroll.scrollTop();
                        var story_height = this.$s.$feed_scroll.find('.NB-feed-story.NB-selected').height()-12;
                        if (page_height + scroll_top >= story_height) {
                            this.open_next_unread_story_across_feeds();
                        }
                    } else if (text_view) {
                        var scroll_top = this.$s.$text_view.scrollTop();
                        var story_height = this.$s.$text_view.find('.NB-feed-story').height()-24;
                        if (page_height + scroll_top >= story_height) {
                            this.open_next_unread_story_across_feeds();
                        }
                    }
                } else if (split_layout && direction < 0) {
                    if (feed_view || text_view) {
                        var scroll_top = this.$s.$feed_scroll.scrollTop();
                        if (scroll_top == 0) {
                            this.show_previous_story();
                        }
                    }
                }
            } else if (_.contains(['list', 'grid'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                var scroll_top = this.$s.$story_titles.scrollTop();
                var $story = this.active_story.story_title_view.$el;
                var story_height = $story.height();
                var story_offset = $story.position().top;
                 console.log(['space list', $story[0], scroll_top, story_height, story_offset, story_height+story_offset-scroll_height, page_height]);
                 if (direction > 0 && 
                     (story_height+story_offset-scroll_height+52 < 0 || 
                      story_height+story_offset+52 < page_height)) {
                     this.open_next_unread_story_across_feeds();
                 } else if (direction < 0 && story_offset >= 0) {
                     this.show_previous_story();
                 }
            }
        },
        
        scroll_in_story: function(amount, direction) {
            var dir = '+';
            if (direction == -1) {
                dir = '-';
            }
            // NEWSBLUR.log(['scroll_in_story', this.$s.$story_pane, direction, amount]);
            if (_.contains(['list', 'grid'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                this.$s.$story_titles.stop().scrollTo({
                    top: dir+'='+amount, 
                    left:'+=0'
                }, 130, {queue: false});
            } else if (this.story_view == 'page' && 
                !this.flags['page_view_showing_feed_view'] &&
                !this.flags['temporary_story_view']) {
                this.$s.$feed_iframe.stop().scrollTo({
                    top: dir+'='+amount, 
                    left:'+=0'
                }, 130, {queue: false});
            } else if ((this.story_view == 'feed' &&
                        !this.flags['temporary_story_view']) || 
                       this.flags['page_view_showing_feed_view']) {
                this.$s.$feed_scroll.stop().scrollTo({
                    top: dir+'='+amount, 
                    left:'+=0'
                }, 130, {queue: false});
            } else if (this.story_view == 'text' ||
                       this.flags['temporary_story_view']) {
                this.$s.$text_view.stop().scrollTo({
                    top: dir+'='+amount, 
                    left:'+=0'
                }, 130, {queue: false});
            }
            
            this.show_mouse_indicator();
            // _.delay(_.bind(this.hide_mouse_indicator, this), 350);
        },
        
        find_story_with_action_preference_on_open_feed: function() {
            var open_feed_action = this.model.preference('open_feed_action');

            if (!this.active_story && open_feed_action == 'newest' &&
                !this.flags['feed_list_showing_starred']) {
                this.show_next_unread_story();
            }
        },
        
        // =============
        // = Feed Pane =
        // =============
        
        sort_feeds: function($feeds) {
            $('.feed', $feeds).tsort('', {sortFunction: NEWSBLUR.Collections.Folders.comparator});
            $('.folder', $feeds).tsort('.folder_title_text');
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
                containment: '#feed_list',
                tolerance: 'pointer',
                scrollSensitivity: 35,
                start: function(e, ui) {
                    self.flags['sorting_feed'] = true;
                    ui.placeholder.attr('class', ui.item.attr('class') + ' NB-feeds-list-highlight');
                    NEWSBLUR.app.feed_list.start_sorting();
                    ui.item.addClass('NB-feed-sorting');
                    ui.placeholder.data('id', ui.item.data('id'));
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
                    NEWSBLUR.app.feed_list.end_sorting();
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
                        var feed_id = parseInt($item.data('id'), 10);
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
        
        show_feed_chooser_button: function() {
            var self = this;
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            var percentage = 0;
            
            $('.NB-progress-title', $progress).text('Get Started');
            $('.NB-progress-counts', $progress).hide();
            $('.NB-progress-percentage', $progress).hide();
            $progress.addClass('NB-progress-error').addClass('NB-progress-big');
            $('.NB-progress-link', $progress).html($.make('div', { 
                className: 'NB-modal-submit-button NB-modal-submit-green NB-menu-manage-feedchooser'
            }, ['Choose your 64 sites']));
            
            this.show_progress_bar();
        },
        
        hide_feed_chooser_button: function() {
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            $progress.removeClass('NB-progress-error').removeClass('NB-progress-big');
            
            this.hide_progress_bar();
        },
        
        open_dialog_after_feeds_loaded: function(options) {
            options = options || {};
            if (!NEWSBLUR.Globals.is_authenticated) return;
            
            if (!NEWSBLUR.assets.folders.length ||
                !NEWSBLUR.assets.preference('has_setup_feeds')) {
                if (options.delayed_import || this.flags.delayed_import) {
                    this.setup_ftux_add_feed_callout("Check your email...");
                } else if (options.finished_intro || NEWSBLUR.assets.preference('has_setup_feeds')) {
                    this.setup_ftux_add_feed_callout();
                } else if (!NEWSBLUR.intro || !NEWSBLUR.intro.flags.open) {
                    _.defer(_.bind(this.open_intro_modal, this), 100);
                }
            } else if (!NEWSBLUR.assets.flags['has_chosen_feeds'] &&
                       NEWSBLUR.assets.folders.length) {
                if (NEWSBLUR.Globals.is_premium) {
                    this.model.save_feed_chooser(null, function() {
                        NEWSBLUR.reader.hide_feed_chooser_button();
                        NEWSBLUR.assets.load_feeds();
                    });
                } else {
                    _.defer(_.bind(this.open_feedchooser_modal, this), 100);
                }
            } else if (!NEWSBLUR.Globals.is_premium &&
                       NEWSBLUR.assets.feeds.active().length > 64) {
                _.defer(_.bind(this.open_feedchooser_modal, this), 100);
            }
        },
        
        // ================
        // = Progress Bar =
        // ================
        
        check_feed_fetch_progress: function() {
            $.extend(this.counts, {
                'unfetched_feeds': 0,
                'fetched_feeds': 0
            });
            
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
        
        // ===============================
        // = Feed bar - Individual Feeds =
        // ===============================
        
        reset_feed: function(options) {
            options = options || {};
            
            $.extend(this.flags, {
                'scrolling_by_selecting_story_title': false,
                'page_view_showing_feed_view': false,
                'feed_view_showing_story_view': false,
                'temporary_story_view': false,
                'story_titles_loaded': false,
                'iframe_prevented_from_loading': false,
                'pause_feed_refreshing': false,
                'feed_list_showing_manage_menu': false,
                'unread_threshold_temporarily': null,
                'river_view': false,
                'social_view': false,
                'starred_view': false,
                'select_story_in_feed': null,
                'global_blurblogs': false,
                'reloading_feeds': false
            });
            
            $.extend(this.cache, {
                'iframe': {},
                'iframe_stories': {},
                'iframe_story_positions': {},
                'feed_view_story_positions': {},
                'iframe_story_positions_keys': [],
                'feed_view_story_positions_keys': [],
                'river_feeds_with_unreads': [],
                'prefetch_last_story': 0,
                'prefetch_iteration': 0,
                'feed_title_floater_story_id': null,
                '$feed_in_social_feed_list': {}
            });
            
            $.extend(this.counts, {
                'page': 1,
                'page_fill_outs': 0,
                'find_next_unread_on_page_of_feed_stories_load': 0,
                'find_last_unread_on_page_of_feed_stories_load': 0,
                'select_story_in_feed': 0
            });
            
            if (_.isUndefined(options.search)) {
                this.flags.search = "";
                this.flags.searching = false;
            }
            this.model.flags['no_more_stories'] = false;
            this.$s.$feed_scroll.scrollTop(0);
            this.$s.$starred_header.removeClass('NB-selected');
            this.$s.$read_header.removeClass('NB-selected');
            this.$s.$river_sites_header.removeClass('NB-selected');
            this.$s.$river_blurblogs_header.removeClass('NB-selected');
            this.$s.$river_global_header.removeClass('NB-selected');
            this.$s.$tryfeed_header.removeClass('NB-selected');
            this.model.feeds.deselect();
            this.model.starred_feeds.deselect();
            if (_.string.contains(this.active_feed, 'social:')) {
                this.model.social_feeds.deselect();
            }
            if (_.string.contains(this.active_feed, 'river:')) {
                this.model.folders.deselect();
            }
            this.$s.$body.removeClass('NB-view-river');
            $('.task_view_page', this.$s.$taskbar).removeClass('NB-disabled');
            $('.task_view_story', this.$s.$taskbar).removeClass('NB-disabled');
            $('.task_view_page', this.$s.$taskbar).removeClass('NB-task-return');
            clearTimeout(this.flags['next_fetch']);
            
            if (this.flags['showing_feed_in_tryfeed_view'] ||
                this.flags['showing_social_feed_in_tryfeed_view']) {
                this.hide_tryfeed_view();
            }
            if (NEWSBLUR.Globals.is_anonymous) {
                if (options.router) {
                    this.$s.$layout.layout().show('west', true);
                    this.$s.$layout.show();
                }
                this.hide_tryout_signup_button();
            }
            
            this.active_folder = null;
            this.active_feed = null;
            this.active_story = null;
            
            NEWSBLUR.assets.stories.reset();
            NEWSBLUR.app.feed_selector.hide_feed_selector();
            NEWSBLUR.app.original_tab_view.unload_feed_iframe();
            NEWSBLUR.app.story_tab_view.unload_story_iframe();
            NEWSBLUR.app.text_tab_view.unload();
        },
        
        reload_feed: function(options) {
            options = options || {};
            
            if (this.flags['starred_view'] && this.flags['starred_tag']) {
                options['tag'] = this.flags['starred_tag'];
                this.open_starred_stories(options);
            } else if (this.flags['starred_view']) {
                this.open_starred_stories(options);
            } else if (this.active_feed == 'read') {
                this.open_read_stories(options);
            } else if (this.flags['social_view'] && 
                       this.active_feed == 'river:blurblogs') {
                this.open_river_blurblogs_stories();
            } else if (this.flags['social_view'] && 
                       this.active_feed == 'river:global') {
                this.open_river_blurblogs_stories({'global': true});
            } else if (this.flags['social_view']) {
                this.open_social_stories(this.active_feed, options);
            } else if (this.flags['river_view']) {
                this.open_river_stories(this.active_folder && 
                                        this.active_folder.folder_view &&
                                        this.active_folder.folder_view.$el,
                                        this.active_folder,
                                        options);
            } else if (this.active_feed) {
                this.open_feed(this.active_feed, options);
            }
            
            if (options.search && !_.contains(['feed', 'text', 'story'], this.story_view)) {
                this.switch_taskbar_view('feed', {
                    skip_save_type: true
                });
            }
        },
        
        open_feed: function(feed_id, options) {
            options = options || {};
            var self = this;
            var $story_titles = this.$s.$story_titles;
            var feed = this.model.get_feed(feed_id) || options.feed;
            var temp = feed && feed.get('temp') && !feed.get('subscribed');
            
            if (!feed || (temp && !options.try_feed)) {
                // Setup tryfeed views first, then come back here.
                console.log(["Temp open feed", feed_id, feed, options, temp]);
                options.feed = options.feed && options.feed.attributes;
                return this.load_feed_in_tryfeed_view(feed_id, options);
            }

            this.flags['opening_feed'] = true;
            
            if (options.try_feed || feed) {
                this.reset_feed(options);
                this.hide_splash_page();
                if (options.story_id) {
                    this.flags['select_story_in_feed'] = options.story_id;
                }
            
                this.active_feed = feed.id;
                this.next_feed = feed.id;
                
                if (options.$feed) {
                    var selected_title_view = _.detect(feed.views, function(view) {
                        return view.el == options.$feed.get(0);
                    });
                    if (selected_title_view) {
                        feed.set("selected_title_view", selected_title_view, {silent: true});
                    }
                }
                feed.set('selected', true, options);
                if (NEWSBLUR.app.story_unread_counter) {
                    NEWSBLUR.app.story_unread_counter.remove();
                }
                
                NEWSBLUR.app.taskbar_info.hide_stories_error();
                this.iframe_scroll = null;
                this.set_correct_story_view_for_feed(feed.id);
                this.make_feed_title_in_stories();
                this.switch_taskbar_view(this.story_view);
                this.switch_story_layout();
                
                if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                    NEWSBLUR.app.story_list.show_loading(options);
                } else {
                    NEWSBLUR.app.story_titles.show_loading(options);
                }

                _.delay(_.bind(function() {
                    if (!options.delay || feed.id == self.next_feed) {
                        this.model.load_feed(feed.id, 1, true, $.rescope(this.post_open_feed, this), 
                                             NEWSBLUR.app.taskbar_info.show_stories_error);
                    }
                }, this), options.delay || 0);

                if (_.contains(['split', 'full'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')) && 
                    (!this.story_view || this.story_view == 'page')) {
                    _.delay(_.bind(function() {
                        if (!options.delay || feed.id == this.next_feed) {
                            NEWSBLUR.app.original_tab_view.load_feed_iframe(feed.id);
                        }
                    }, this), options.delay || 0);
                } else {
                    NEWSBLUR.app.original_tab_view.unload_feed_iframe();
                    NEWSBLUR.app.story_tab_view.unload_story_iframe();
                    NEWSBLUR.app.text_tab_view.unload();
                    this.flags['iframe_prevented_from_loading'] = true;
                }
                this.setup_mousemove_on_views();
                
                if (!options.silent) {
                    var feed_title = feed.get('feed_title') || '';
                    var slug = _.string.words(_.string.clean(feed_title.replace(/[^a-z0-9\. ]/ig, ''))).join('-').toLowerCase();
                    var url = "site/" + feed.id + "/" + slug;
                    if (!_.string.include(window.location.pathname, url)) {
                        NEWSBLUR.log(["Navigating to url", url]);
                        NEWSBLUR.router.navigate(url);
                    }
                }
            }
        },
        
        post_open_feed: function(e, data, first_load) {
            if (!data) {
                NEWSBLUR.log(["No data from feed, trying again..."]);
                return this.open_feed(this.active_feed, {force: true});
            }
            var stories = data.stories;
            var tags = data.tags;
            var feed_id = data.feed_id;
            
            if (data.dupe_feed_id && this.active_feed == data.dupe_feed_id) {
                this.active_feed = data.feed_id;
            }
            
            this.flags['opening_feed'] = false;
            NEWSBLUR.app.story_titles_header.show_feed_hidden_story_title_indicator(first_load);
            // this.show_story_titles_above_intelligence_level({'animate': false});
            if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                this.show_next_unread_story(true);
            } else if (this.counts['find_last_unread_on_page_of_feed_stories_load']) {
                this.show_last_unread_story(true);
            } else if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                this.select_story_in_feed();
            }
            this.flags['story_titles_loaded'] = true;
            if (first_load) {
                this.make_story_titles_pane_counter();
                this.find_story_with_action_preference_on_open_feed();
                this.position_mouse_indicator();
                
                if (_.contains(['story', 'text'], this.story_view) &&
                    !this.active_story &&
                    _.contains(['split', 'full'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')) &&
                    !this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    if (this.story_view == 'text') {
                        NEWSBLUR.app.text_tab_view.show_explainer_single_story_mode();
                    } else if (this.story_view == 'story') {
                        NEWSBLUR.app.story_tab_view.show_explainer_single_story_mode();                        
                    }
                }
            }

            NEWSBLUR.app.taskbar_info.hide_stories_progress_bar();
            if (NEWSBLUR.Globals.is_anonymous) {
                this.show_tryout_signup_button();
            } else if (this.flags['showing_feed_in_tryfeed_view']) {
                this.show_tryfeed_add_button();
                this.correct_tryfeed_title();
            }
        },
        
        set_correct_story_view_for_feed: function(feed_id, view) {
            feed_id = feed_id || this.active_feed;
            var feed = NEWSBLUR.assets.get_feed(feed_id);
            var $original_tabs = $('.task_view_page, .task_view_story');
            var $page_tab = $('.task_view_page');
            view = view || NEWSBLUR.assets.view_setting(feed_id);

            $original_tabs.removeClass('NB-disabled-page')
                          .removeClass('NB-disabled')
                          .removeClass('NB-hidden')
                          .removeClass('NB-exception-page');
            $original_tabs.each(function() {
                $(this).tipsy('disable');
            });

            if (feed && 
                (feed.get('disabled_page') ||
                 NEWSBLUR.utils.is_url_iframe_buster(feed.get('feed_link')))) {
                view = 'feed';
                $original_tabs.addClass('NB-disabled-page')
                              .addClass('NB-disabled')
                              .attr('title', 'The original page has been disabled by the publisher.')
                              .tipsy({
                    gravity: 'n',
                    fade: true,
                    delayIn: 200
                });
                $original_tabs.each(function() {
                    $(this).tipsy('enable');
                });
            } else if (this.flags.river_view) {
                $page_tab.addClass('NB-disabled');
                $('.NB-taskbar-button.task_view_page').addClass('NB-hidden');
                $('.NB-taskbar-button.task_view_feed').addClass('NB-first');
            } else if (feed && feed.get('has_exception') && feed.get('exception_type') == 'page') {
                if (view == 'page') {
                    view = 'feed';
                }
                $('.task_view_page').addClass('NB-exception-page');
            }
            
            
            var $split = $(".NB-task-layout-split");
            var $list = $(".NB-task-layout-list");
            var $grid = $(".NB-task-layout-grid");
            var $full = $(".NB-task-layout-full");
            var story_layout = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
            this.$s.$story_titles[0].className = this.$s.$story_titles[0].className.replace(/ ?NB-layout-\w+/gi, '');
            this.$s.$story_titles.addClass('NB-layout-' + story_layout);
            
            if (story_layout == 'list') {
                $('.NB-taskbar-button.task_view_page').addClass('NB-hidden');
                $('.NB-taskbar-button.task_view_feed').addClass('NB-first');
                $('.NB-taskbar-button.task_view_story').addClass('NB-hidden');
                $('.NB-taskbar-button.task_view_text').addClass('NB-last');
                $full.removeClass('NB-active');
                $split.removeClass('NB-active');
                $list.addClass('NB-active');
                $grid.removeClass('NB-active');
            } else if (story_layout == 'grid') {
                $('.NB-taskbar-button.task_view_page').addClass('NB-hidden');
                $('.NB-taskbar-button.task_view_feed').addClass('NB-first');
                $('.NB-taskbar-button.task_view_story').addClass('NB-hidden');
                $('.NB-taskbar-button.task_view_text').addClass('NB-last');
                $full.removeClass('NB-active');
                $split.removeClass('NB-active');
                $list.removeClass('NB-active');
                $grid.addClass('NB-active');
            } else if (story_layout == 'split') {
                if (!this.flags.river_view) {               
                    $('.NB-taskbar-button.task_view_page').removeClass('NB-hidden');
                    $('.NB-taskbar-button.task_view_feed').removeClass('NB-first');
                }
                $('.NB-taskbar-button.task_view_story').removeClass('NB-hidden');
                $('.NB-taskbar-button.task_view_text').removeClass('NB-last');
                $full.removeClass('NB-active');
                $split.addClass('NB-active');
                $list.removeClass('NB-active');
                $grid.removeClass('NB-active');
            } else if (story_layout == 'full') {
                if (!this.flags.river_view) {               
                    $('.NB-taskbar-button.task_view_page').removeClass('NB-hidden');
                    $('.NB-taskbar-button.task_view_feed').removeClass('NB-first');
                }
                $('.NB-taskbar-button.task_view_story').removeClass('NB-hidden');
                $('.NB-taskbar-button.task_view_text').removeClass('NB-last');
                $full.addClass('NB-active');
                $split.removeClass('NB-active');
                $list.removeClass('NB-active');
                $grid.removeClass('NB-active');
            }

            if (_.contains(['starred', 'read'], feed_id)) {
                $page_tab.addClass('NB-disabled');
            }

            this.story_view = view;
        },
        
        // ================
        // = Story Layout =
        // ================
        
        switch_story_layout: function(story_layout) {
            var feed_layout = NEWSBLUR.assets.view_setting(this.active_feed, 'layout');
            var active_layout = this.story_layout;
            var original_layout = this.story_layout;
            story_layout = story_layout || feed_layout || active_layout;
            
            // console.log(['switch_story_layout', active_layout, feed_layout, story_layout, this.active_feed, story_layout == active_layout]);
            if (story_layout == active_layout) return;
            
            this.story_layout = story_layout;
            
            if (!this.active_feed) return;
            
            NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, {'layout': story_layout});

            this.set_correct_story_view_for_feed();
            this.apply_resizable_layout({right_side: true});
            
            if (original_layout == 'grid' || story_layout == 'grid') {
                NEWSBLUR.app.story_titles.render();
            }
            if (story_layout == 'list') {
                if (this.active_story) {
                    this.active_story.story_title_view.toggle_selected();
                }
                NEWSBLUR.app.story_list.clear();
            } else if (story_layout == 'grid') {
                if (this.active_story) {
                    this.active_story.story_title_view.toggle_selected();
                }
                NEWSBLUR.app.story_list.clear();
            } else if (story_layout == 'split') {
                NEWSBLUR.app.story_list.render();
                if (this.active_story) {
                    NEWSBLUR.app.story_list.show_only_selected_story();
                    this.active_story.story_title_view.toggle_selected();
                    this.active_story.story_view.toggle_selected();
                }
            } else if (story_layout == 'full') {
                NEWSBLUR.app.story_list.render();
                if (this.active_story) {
                    NEWSBLUR.app.story_list.show_only_selected_story();
                    this.active_story.story_title_view.toggle_selected();
                    this.active_story.story_view.toggle_selected();
                }
            }
            
            this.switch_to_correct_view();
            this.make_feed_title_in_stories();
            this.add_body_classes();
            
            _.defer(function() {
                NEWSBLUR.app.story_titles.scroll_to_selected_story();
                NEWSBLUR.app.story_list.scroll_to_selected_story();
                NEWSBLUR.app.feed_list.scroll_to_selected();
                if (_.contains(['split', 'list', 'grid'], 
                    NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    NEWSBLUR.app.story_titles.fill_out();
                } else {
                    NEWSBLUR.app.story_list.fill_out();
                }
            });
        },
        
        // ===================
        // = Starred Stories =
        // ===================
        
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
        
        open_starred_stories: function(options) {
            options = options || {};
            var $story_titles = this.$s.$story_titles;
            
            this.reset_feed(options);
            this.hide_splash_page();
            if (options.story_id) {
                this.flags['select_story_in_feed'] = options.story_id;
            }

            this.iframe_scroll = null;
            if (options.tag && !options.model) {
                var model = NEWSBLUR.assets.starred_feeds.detect(function(feed) {
                    return feed.tag_slug() == options.tag || feed.get('tag') == options.tag;
                });
                if (model) {
                    options.model = model;
                    options.tag = model.get('tag');
                }
            }
            if (options.tag) {
                this.active_feed = options.model.id;
                this.flags['starred_tag'] = options.model.get('tag');
                options.model.set('selected', true);
            } else {
                this.active_feed = 'starred';
                this.$s.$starred_header.addClass('NB-selected');
                this.flags['starred_tag'] = null;
            }
            this.flags['starred_view'] = true;
            this.$s.$body.addClass('NB-view-river');
            this.flags.river_view = true;
			
            $('.task_view_page', this.$s.$taskbar).addClass('NB-disabled');
            var explicit_view_setting = this.model.view_setting(this.active_feed, 'view');
            if (!explicit_view_setting || explicit_view_setting == 'page') {
				explicit_view_setting = 'feed';
            }
            this.set_correct_story_view_for_feed(this.active_feed, explicit_view_setting);
            this.switch_taskbar_view(this.story_view);
			this.switch_story_layout();            
            this.setup_mousemove_on_views();
            this.make_feed_title_in_stories();  
            NEWSBLUR.app.feed_list.scroll_to_show_selected_folder();

            if (!options.silent) {
                var url = "/saved";
                if (options.model) {
                    url += "/" + options.model.tag_slug();
                }
                if (window.location.pathname != url) {
                    NEWSBLUR.log(["Navigating to url", url]);
                    NEWSBLUR.router.navigate(url);
                }
            }

            if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                NEWSBLUR.app.story_list.show_loading(options);
            } else {
                NEWSBLUR.app.story_titles.show_loading(options);
            }
            NEWSBLUR.app.taskbar_info.hide_stories_error();
            
            this.model.fetch_starred_stories(1, this.flags['starred_tag'], _.bind(this.post_open_starred_stories, this), 
                                             NEWSBLUR.app.taskbar_info.show_stories_error, true);


        },
        
        post_open_starred_stories: function(data, first_load) {
            if (!this.flags['starred_view']) return;

            // NEWSBLUR.log(['post_open_starred_stories', data.stories.length, first_load]);
            this.flags['opening_feed'] = false;
            if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                this.select_story_in_feed();
            }
            if (first_load) {
                this.find_story_with_action_preference_on_open_feed();
            }
            this.make_story_titles_pane_counter();
            // this.show_story_titles_above_intelligence_level({'animate': false});
            this.flags['story_titles_loaded'] = true;
        },
        
        // =====================
        // = Read Stories Feed =
        // =====================
        
        open_read_stories: function(options) {
            options = options || {};
            var $story_titles = this.$s.$story_titles;
            
            this.reset_feed(options);
            this.hide_splash_page();
            this.active_feed = 'read';
            if (options.story_id) {
                this.flags['select_story_in_feed'] = options.story_id;
            }

            this.iframe_scroll = null;
            this.$s.$read_header.addClass('NB-selected');
            this.$s.$body.addClass('NB-view-river');
            this.flags.river_view = true;

            $('.task_view_page', this.$s.$taskbar).addClass('NB-disabled');
            var explicit_view_setting = this.model.view_setting(this.active_feed, 'view');
            if (!explicit_view_setting || explicit_view_setting == 'page') {
                explicit_view_setting = 'feed';
            }
            this.set_correct_story_view_for_feed(this.active_feed, explicit_view_setting);
            this.switch_taskbar_view(this.story_view);
            this.switch_story_layout();
            this.setup_mousemove_on_views();
            this.make_feed_title_in_stories();              

            if (!options.silent) {
                var url = "/read";
                if (window.location.pathname != url) {
                    NEWSBLUR.router.navigate(url);
                }
            }

            if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                NEWSBLUR.app.story_list.show_loading(options);
            } else {
                NEWSBLUR.app.story_titles.show_loading(options);
            }
            NEWSBLUR.app.taskbar_info.hide_stories_error();
            
            this.model.fetch_read_stories(1, _.bind(this.post_open_read_stories, this), 
                                          NEWSBLUR.app.taskbar_info.show_stories_error, true);                                          
        },
        
        post_open_read_stories: function(data, first_load) {
            if (this.active_feed == 'read') {
                // NEWSBLUR.log(['post_open_read_stories', data.stories.length, first_load]);
                this.flags['opening_feed'] = false;
                if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                    this.select_story_in_feed();
                }
                if (first_load) {
                    this.find_story_with_action_preference_on_open_feed();
                }
                // this.show_story_titles_above_intelligence_level({'animate': false});
                this.flags['story_titles_loaded'] = true;
            }
        },
        
        // =================
        // = River of News =
        // =================
        
        open_river_stories: function($folder, folder, options) {
            options = options || {};
            var $story_titles = this.$s.$story_titles;
            $folder = $folder || this.$s.$feed_list;
            var folder_view = NEWSBLUR.assets.folders.get_view($folder) ||
                              this.active_folder && this.active_folder.folder_view;
            var folder_title = folder && folder.get('folder_title') || "Everything";
            
            this.reset_feed(options);
            this.hide_splash_page();
            if (!folder || folder.get('fake') || !folder.get('folder_title')) {
                this.active_feed = 'river:';
                this.$s.$river_sites_header.addClass('NB-selected');
            } else {
                this.active_feed = 'river:' + folder_title;
                folder_view.model.set('selected', true);
            }
            this.active_folder = folder || NEWSBLUR.assets.folders;
            
            if (NEWSBLUR.app.story_unread_counter) {
                NEWSBLUR.app.story_unread_counter.remove();
            }
            this.iframe_scroll = null;
            this.flags['opening_feed'] = true;
            this.$s.$body.addClass('NB-view-river');
            this.flags.river_view = true;
            
            $('.task_view_page', this.$s.$taskbar).addClass('NB-disabled');
            var explicit_view_setting = this.model.view_setting(this.active_feed, 'view');
            if (!explicit_view_setting || explicit_view_setting == 'page') {
                explicit_view_setting = 'feed';
            }
            this.set_correct_story_view_for_feed(this.active_feed, explicit_view_setting);
            this.switch_taskbar_view(this.story_view);
            this.switch_story_layout();
            this.setup_mousemove_on_views();
            this.make_feed_title_in_stories();
            NEWSBLUR.app.feed_list.scroll_to_show_selected_folder();

            if (!options.silent) {
                var slug = folder_title.replace(/ /g, '-').toLowerCase();
                var url = "folder/" + slug;
                if (!_.string.include(window.location.pathname, url)) {
                    NEWSBLUR.log(["Navigating to url", url]);
                    NEWSBLUR.router.navigate(url);
                }
            }
            
            var visible_only = this.model.view_setting(this.active_feed, 'read_filter') == 'unread';
            if (NEWSBLUR.reader.flags.search) visible_only = false;
            if (NEWSBLUR.reader.flags.feed_list_showing_starred) visible_only = false;
            var feeds;
            if (visible_only) {
                feeds = _.pluck(this.active_folder.feeds_with_unreads(), 'id');
                if (!feeds.length) {
                    feeds = this.active_folder.feed_ids_in_folder();
                }
            } else {
                feeds = this.active_folder.feed_ids_in_folder();
            }
            this.cache['river_feeds_with_unreads'] = feeds;
            if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                NEWSBLUR.app.story_list.show_loading(options);
            } else {
                NEWSBLUR.app.story_titles.show_loading(options);
            }
            NEWSBLUR.app.taskbar_info.hide_stories_error();
            // NEWSBLUR.app.taskbar_info.show_stories_progress_bar(feeds.length);
            this.model.fetch_river_stories(this.active_feed, feeds, 1, 
                _.bind(this.post_open_river_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error, true);
        },
        
        post_open_river_stories: function(data, first_load) {
            // NEWSBLUR.log(['post_open_river_stories', data, this.active_feed]);
            if (!data) {
              return NEWSBLUR.app.taskbar_info.show_stories_error(data);
            }
            
            if (this.active_feed && _.isString(this.active_feed) &&
                this.active_feed.indexOf('river:') != -1) {
                this.flags['opening_feed'] = false;
                NEWSBLUR.app.story_titles_header.show_feed_hidden_story_title_indicator(first_load);
                // this.show_story_titles_above_intelligence_level({'animate': false});
                this.flags['story_titles_loaded'] = true;
                if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                } else if (this.counts['find_last_unread_on_page_of_feed_stories_load']) {
                    this.show_last_unread_story(true);
                } else if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                    this.select_story_in_feed();
                }
                // NEWSBLUR.app.taskbar_info.hide_stories_progress_bar(_.bind(function() {
                    if (first_load) {
                        this.position_mouse_indicator();
                        this.make_story_titles_pane_counter();
                    }
                // }, this));
                if (NEWSBLUR.Globals.is_anonymous) {
                    this.show_tryout_signup_button();
                } else if (first_load) {
                    this.find_story_with_action_preference_on_open_feed();
                    if (_.contains(['story', 'text'], this.story_view) &&
                        !this.active_story &&
                        _.contains(['split', 'full', 'grid'],
                                   NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')) &&
                        !this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                        this.show_next_story(1);
                    }

                }
            }
        },
        
        // ===================
        // = River Blurblogs =
        // ===================
        
        open_river_blurblogs_stories: function(options) {
            options = options || {};
            var $story_titles = this.$s.$story_titles;
            var folder_title = options.global ? "Global Blurblogs" : "Blurblogs";
            
            this.reset_feed(options);
            this.hide_splash_page();
            
            this.active_feed = options.global ? 'river:global' : 'river:blurblogs';
            this.active_folder = new Backbone.Model({
                id: this.active_feed,
                folder_title: options.global ? "Global Shared Stories" : "All Shared Stories",
                fake: true,
                show_options: true
            });
            
            if (options.global) {
                this.$s.$river_global_header.addClass('NB-selected');
            } else {
                this.$s.$river_blurblogs_header.addClass('NB-selected');
            }
            
            this.iframe_scroll = null;
            this.flags['opening_feed'] = true;
            this.$s.$body.addClass('NB-view-river');
            this.flags.river_view = true;
            this.flags.social_view = true;
            this.flags.global_blurblogs = options.global;
            
            $('.task_view_page', this.$s.$taskbar).addClass('NB-disabled');
            var explicit_view_setting = this.model.view_setting(this.active_feed, 'view');
            if (!explicit_view_setting || explicit_view_setting == 'page') {
              explicit_view_setting = 'feed';
            }
            this.set_correct_story_view_for_feed(this.active_feed, explicit_view_setting);
            this.switch_taskbar_view(this.story_view);
            this.switch_story_layout();
            this.setup_mousemove_on_views();
            this.make_feed_title_in_stories();
            NEWSBLUR.app.feed_list.scroll_to_show_selected_folder();

            if (!options.silent) {
                var slug = folder_title.replace(/ /g, '-').toLowerCase();
                var url = "folder/" + slug;
                if (!_.string.include(window.location.pathname, url)) {
                    NEWSBLUR.log(["Navigating to url", url]);
                    NEWSBLUR.router.navigate(url);
                }
            }

            if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                NEWSBLUR.app.story_list.show_loading(options);
            } else {
                NEWSBLUR.app.story_titles.show_loading(options);
            }
            NEWSBLUR.app.taskbar_info.hide_stories_error();
            NEWSBLUR.app.taskbar_info.show_stories_progress_bar(100); // Assume 100 followees for popular
            this.model.fetch_river_blurblogs_stories(this.active_feed, 1, 
                {'global': this.flags.global_blurblogs},
                _.bind(this.post_open_river_blurblogs_stories, this), 
                NEWSBLUR.app.taskbar_info.show_stories_error, true);
        },
        
        post_open_river_blurblogs_stories: function(data, first_load) {
            // NEWSBLUR.log(['post_open_river_stories', data, this.active_feed]);
            if (!data) {
              return NEWSBLUR.app.taskbar_info.show_stories_error(data);
            }
            
            if (this.active_feed && _.isString(this.active_feed) &&
                this.active_feed.indexOf('river:') != -1) {
                this.flags['opening_feed'] = false;
                NEWSBLUR.app.story_titles_header.show_feed_hidden_story_title_indicator(first_load);
                // this.show_story_titles_above_intelligence_level({'animate': false});
                this.flags['story_titles_loaded'] = true;
                if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                } else if (this.counts['find_last_unread_on_page_of_feed_stories_load']) {
                    this.show_last_unread_story(true);
                } else if (this.counts['select_story_in_feed'] ||
                           this.flags['select_story_in_feed']) {
                    this.select_story_in_feed();
                }
                if (first_load) {
                    this.find_story_with_action_preference_on_open_feed();
                    this.position_mouse_indicator();
                }
                NEWSBLUR.app.taskbar_info.hide_stories_progress_bar();
                if (NEWSBLUR.Globals.is_anonymous) {
                    this.show_tryout_signup_button();
                }
            }
        },
        
        // ==================
        // = Social Stories =
        // ==================
        
        open_social_stories: function(feed_id, options) {
            // NEWSBLUR.log(["open_social_stories", feed_id, options]);
            options = options || {};
            if (_.isNumber(feed_id)) feed_id = "social:" + feed_id;
            
            var feed = this.model.get_feed(feed_id);
            var $story_titles = this.$s.$story_titles;
            var $social_feed = this.find_social_feed_with_feed_id(feed_id);

            if (!feed && !options.try_feed) {
                // Setup tryfeed views first, then come back here.
                var socialsub = this.model.add_social_feed({
                    id: feed_id,
                    user_id: parseInt(feed_id.replace('social:', ''), 10)
                });
                return this.load_social_feed_in_tryfeed_view(socialsub, options);
            }
            
            this.reset_feed(options);
            this.hide_splash_page();
            
            this.active_feed = feed.id;
            this.next_feed = feed.id;
            this.flags.river_view = false;
            this.flags.social_view = true;
            if (options.story_id) {
                this.flags['select_story_in_feed'] = options.story_id;
            }
            
            this.iframe_scroll = null;
            this.flags['opening_feed'] = true;
            feed.set('selected', true, options);
            this.set_correct_story_view_for_feed(this.active_feed);
            this.make_feed_title_in_stories();
            this.$s.$body.addClass('NB-view-river');
            
            // TODO: Only make feed the default for blurblogs, not overriding an explicit pref.
            this.switch_taskbar_view(this.story_view);
            this.switch_story_layout();
            this.setup_mousemove_on_views();
            
            if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                NEWSBLUR.app.story_list.show_loading(options);
            } else {
                NEWSBLUR.app.story_titles.show_loading(options);
            }
            NEWSBLUR.app.taskbar_info.hide_stories_error();
            NEWSBLUR.app.taskbar_info.show_stories_progress_bar();
            this.model.fetch_social_stories(this.active_feed, 1, 
                _.bind(this.post_open_social_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error, true);
            
            if (this.story_view == 'page') {
                _.delay(_.bind(function() {
                    if (!options.delay || feed.id == this.next_feed) {
                        NEWSBLUR.app.original_tab_view.load_feed_iframe();
                    }
                }, this), options.delay || 0);
            } else {
                this.flags['iframe_prevented_from_loading'] = true;
            }

            if (!options.silent && feed.get('feed_title')) {
                var slug = _.string.words(_.string.clean(feed.get('feed_title').replace(/[^a-z0-9\. ]/ig, ''))).join('-').toLowerCase();
                var url = "social/" + feed.get('user_id') + "/" + slug;
                if (!_.string.include(window.location.pathname, url)) {
                    var params = {};
                    if (_.string.include(window.location.pathname, "social/" + feed.get('user_id'))) {
                        params['replace'] = true;
                    }
                    NEWSBLUR.log(["Navigating to social", url, window.location.pathname]);
                    NEWSBLUR.router.navigate(url, params);
                }
            } else if (!feed.get('feed_title')) {
                NEWSBLUR.log(["No feed title on social", feed]);
                NEWSBLUR.router.navigate('');
            }
        },
        
        post_open_social_stories: function(data, first_load) {
            // NEWSBLUR.log(['post_open_river_stories', data, this.active_feed, this.flags['select_story_in_feed']]);
            if (!data) {
              return NEWSBLUR.app.taskbar_info.show_stories_error(data);
            }
            
            if (this.active_feed && NEWSBLUR.utils.is_feed_social(this.active_feed)) {
                this.flags['opening_feed'] = false;
                // this.show_story_titles_above_intelligence_level({'animate': false});
                NEWSBLUR.app.story_titles_header.show_feed_hidden_story_title_indicator(first_load);
                this.flags['story_titles_loaded'] = true;
                if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                    this.select_story_in_feed();
                } else if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                } else if (this.counts['find_last_unread_on_page_of_feed_stories_load']) {
                    this.show_last_unread_story(true);
                }
                if (first_load) {
                    NEWSBLUR.app.taskbar_info.hide_stories_progress_bar(_.bind(function() {
                        this.make_story_titles_pane_counter();
                    }, this));
                    this.find_story_with_action_preference_on_open_feed();
                    this.position_mouse_indicator();
                }
                NEWSBLUR.app.taskbar_info.hide_stories_progress_bar();
                if (NEWSBLUR.Globals.is_anonymous) {
                    this.show_tryout_signup_button();
                } else if (this.flags['showing_social_feed_in_tryfeed_view']) {
                    this.show_tryfeed_follow_button();
                    this.correct_tryfeed_title();
                }
            }
        },
        
        find_social_feed_with_feed_id: function(feed_id) {
            if (_.contains(this.cache.$feed_in_social_feed_list, feed_id)) {
                return this.cache.$feed_in_social_feed_list[feed_id];
            }
            
            var $social_feeds = this.$s.$social_feeds;
            var $feeds = $([]);
            
            $('.feed', $social_feeds).each(function() {
                if ($(this).data('id') == feed_id) {
                    $feeds.push($(this).get(0));
                }
            });
            
            this.cache.$feed_in_social_feed_list[feed_id] = $feeds;
            
            return $feeds;
        },
        
        // ==========================
        // = Story Pane - All Views =
        // ==========================
        
        switch_to_correct_view: function(options) {
            options = options || {};
            // NEWSBLUR.log(['Found story', this.story_view, options.found_story_in_page, this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);

            if (options.story_not_found) {
                // Story not found, show in feed view with link to page view
                if (this.story_view == 'page' && !this.flags['page_view_showing_feed_view']) {
                    // NEWSBLUR.log(['turn on feed view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                    this.flags['page_view_showing_feed_view'] = true;
                    this.flags['feed_view_showing_story_view'] = false;
                    this.flags['temporary_story_view'] = false;
                    this.switch_taskbar_view('feed', {skip_save_type: 'page'});
                    NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
                }
            } else if (_.contains(['list', 'grid'], 
                NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')) && 
                (this.story_view == 'page' || this.story_view == 'story')) {
                this.switch_taskbar_view('feed', {skip_save_type: 'layout'});
            } else if (this.story_view == 'page' && this.flags['page_view_showing_feed_view']) {
                // NEWSBLUR.log(['turn off feed view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                this.flags['page_view_showing_feed_view'] = false;
                this.flags['feed_view_showing_story_view'] = false;
                this.flags['temporary_story_view'] = false;
                this.switch_taskbar_view('page');
            } else if (this.flags['feed_view_showing_story_view']) {
                // NEWSBLUR.log(['turn off story view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                this.flags['page_view_showing_feed_view'] = false;
                this.flags['feed_view_showing_story_view'] = false;
                this.flags['temporary_story_view'] = false;
                this.switch_taskbar_view(this.story_view, {skip_save_type: true});
            } else if (this.flags['temporary_story_view']) {
                // NEWSBLUR.log(['turn off story view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                this.flags['page_view_showing_feed_view'] = false;
                this.flags['feed_view_showing_story_view'] = false;
                this.flags['temporary_story_view'] = false;
                this.switch_taskbar_view(this.story_view, {skip_save_type: true});
            }
        },
        
        mark_active_story_read: function() {
            if (!this.active_story) return;
            var story_id = this.active_story.id;
            var story = this.model.get_story(story_id);
            if (this.active_story && !this.active_story.get('read_status')) {
                NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
            } else if (this.active_story && this.active_story.get('read_status')) {
                NEWSBLUR.assets.stories.mark_unread(story);
            }
        },
        
        maybe_mark_all_as_read: function() {
            if (_.contains(['river:blurblogs', 'river:global'], this.active_feed)) {
                return;
            } else if (this.flags.social_view) {
                this.mark_feed_as_read();
            } else if (this.flags.river_view) {
                if (this.active_feed == 'river:' && NEWSBLUR.assets.preference('mark_read_river_confirm')) {
                    this.open_mark_read_modal({days: 0});
                } else {
                    this.mark_folder_as_read();
                }
            } else if (!this.flags.river_view && !this.flags.social_view) {
                this.mark_feed_as_read();
            }
        },
        
        mark_feed_as_read: function(feed_id, days_back, direction) {
            feed_id = feed_id || this.active_feed;
            var cutoff_timestamp = NEWSBLUR.utils.days_back_to_timestamp(days_back);
            if (!days_back && this.model.stories.length && 
                this.model.stories.first().get('story_feed_id') == feed_id &&
                NEWSBLUR.assets.view_setting(feed_id, 'order') == 'newest') {
                cutoff_timestamp = this.model.stories.first().get('story_timestamp');
            }

            this.model.mark_feed_as_read([feed_id], cutoff_timestamp, direction, 
                                         feed_id == this.active_feed,  _.bind(function() {
                this.feeds_unread_count(feed_id);
            }, this));

            if (!direction && NEWSBLUR.assets.preference('markread_nextfeed') == 'nextfeed' && 
                NEWSBLUR.reader.active_feed == feed_id) {
                this.show_next_feed(1);
            }
        },
        
        mark_folder_as_read: function(folder, days_back, direction) {
            var folder = folder || this.active_folder;
            var feeds = folder.feed_ids_in_folder();
            var cutoff_timestamp = NEWSBLUR.utils.days_back_to_timestamp(days_back);
            if (!days_back && this.model.stories.length && 
                _.contains(feeds, this.model.stories.first().get('story_feed_id')) &&
                folder.view_setting('order') == 'newest') {
                cutoff_timestamp = this.model.stories.first().get('story_timestamp');
            }
            
            this.model.mark_feed_as_read(feeds, cutoff_timestamp, direction, 
                                         folder == this.active_folder, _.bind(function() {
                if (!this.socket || !this.socket.socket || !this.socket.socket.connected) {
                    this.force_feeds_refresh(null, false, feeds);
                }
            }, this));

            if (!direction && NEWSBLUR.assets.preference('markread_nextfeed') == 'nextfeed' &&
                NEWSBLUR.reader.active_folder == folder) {
                this.show_next_feed(1);
            }
        },
        
        open_story_trainer: function(story_id, feed_id, options) {
            options = options || {};
            story_id = story_id || this.active_story && this.active_story.id;
            feed_id = feed_id || (story_id && this.model.get_story(story_id).get('story_feed_id'));
            var story = this.model.get_story(story_id);
            // console.log(["open_story_trainer", story_id, feed_id, options]);
            
            if (story_id && feed_id) {
                options['feed_loaded'] = !this.flags['river_view'];
                if (this.flags['social_view']) {
                    options['feed_loaded'] = true;
                }
                if (this.flags['social_view'] && !_.string.contains(this.active_feed, 'river:')) {
                    options['social_feed_id'] = this.active_feed;
                } else if (this.flags['social_view'] && story.get('friend_user_ids')) {
                    options['social_feed_id'] = 'social:' + story.get('friend_user_ids')[0];
                }
                NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierStory(story_id, feed_id, options);
            }
        },

        // ===========
        // = Send To =
        // ===========
        
        send_story_to_instapaper: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.instapaper.com/edit';
            var instapaper_url = [
              url,
              '?url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title'))
            ].join('');
            window.open(instapaper_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_readitlater: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://getpocket.com/save';
            var readitlater_url = [
              url,
              '?url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title'))
            ].join('');
            window.open(readitlater_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_tumblr: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.tumblr.com/share';
            var tumblr_url = [
              url,
              '?v=3&u=',
              encodeURIComponent(story.get('story_permalink')),
              '&t=',
              encodeURIComponent(story.get('story_title'))
            ].join('');
            window.open(tumblr_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_blogger: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://www.blogger.com/blog-this.g';
            var blogger_url = [
              url,
              '?n=',
              encodeURIComponent(story.get('story_title')),
              '&source=newsblur&b=',
              encodeURIComponent(story.get('story_permalink'))
            ].join('');
            window.open(blogger_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_delicious: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.delicious.com/save';
            var delicious_url = [
              url,
              '?v=6&url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title'))
            ].join('');
            window.open(delicious_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_readability: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.readability.com/save';
            var readability_url = [
              url,
              '?url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title'))
            ].join('');
            window.open(readability_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_twitter: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://twitter.com/';
            var twitter_url = [
              url,
              '?status=',
              encodeURIComponent(story.get('story_title')),
              ': ',
              encodeURIComponent(story.get('story_permalink'))
            ].join('');
            window.open(twitter_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_facebook: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.facebook.com/sharer.php?src=newsblur&v=3.14159265&i=1.61803399';
            var facebook_url = [
              url,
              '&u=',
              encodeURIComponent(story.get('story_permalink')),
              '&t=',
              encodeURIComponent(story.get('story_title'))
            ].join('');
            window.open(facebook_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_pinboard: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://pinboard.in/add/?';
            var pinboard_url = [
              url,
              'url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title')),
              '&tags=',
              encodeURIComponent(story.get('story_tags').join(', '))
            ].join('');
            window.open(pinboard_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_pinterest: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.pinterest.com/pin/find/?';
            var pinterest_url = [
              url,
              'url=',
              encodeURIComponent(story.get('story_permalink'))
            ].join('');
            window.open(pinterest_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_buffer: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://bufferapp.com/add?source=newsblur&';
            var buffer_url = [
              url,
              'url=',
              encodeURIComponent(story.get('story_permalink')),
              '&text=',
              encodeURIComponent(story.get('story_title'))
            ].join('');
            window.open(buffer_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_diigo: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'http://www.diigo.com/post?';
            var url = [
              url,
              'url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title')),
              '&tags=',
              encodeURIComponent(story.get('story_tags').join(', '))
            ].join('');
            window.open(url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_kippt: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://kippt.com/extensions/new/?';
            var url = [
              url,
              'url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title')),
              '&tags=',
              encodeURIComponent(story.get('story_tags').join(', '))
            ].join('');
            window.open(url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_evernote: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://www.evernote.com/clip.action?';
            var url = [
              url,
              'url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title')),
              '&tags=',
              encodeURIComponent(story.get('story_tags').join(', '))
            ].join('');
            window.open(url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_googleplus: function(story_id) {
            var story = this.model.get_story(story_id);
            var url = 'https://plus.google.com/share';
            var googleplus_url = [
              url,
              '?url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title')),
              '&tags=',
              encodeURIComponent(story.get('story_tags').join(', '))
            ].join('');
            window.open(googleplus_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_email: function(story) {
            NEWSBLUR.reader_send_email = new NEWSBLUR.ReaderSendEmail(story);
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        // =====================
        // = Story Titles Pane =
        // =====================
        
        make_story_titles_pane_counter: function(options) {
            if (NEWSBLUR.app.story_unread_counter) {
                NEWSBLUR.app.story_unread_counter.remove();
                NEWSBLUR.app.story_unread_counter.destroy();
            }
            
            options = options || {
                'fade': true
            };
            var $content_pane = this.$s.$content_pane;
            feed_id = this.active_feed;
            if (!feed_id) return;
            if (this.flags['river_view']) {
                var folder = this.active_folder;
            } else {
                var feed = this.model.get_feed(feed_id);
            }
            if (!feed && !folder) return;
            if (this.active_feed == 'river:global') return;
            
            if (feed) {
                NEWSBLUR.app.story_unread_counter = new NEWSBLUR.Views.UnreadCount({
                    model: feed
                }).render();
            } else if (folder) {
                var collection;
                if (!folder.folder_view) {
                    // River blurblog gets a special collection
                    collection = NEWSBLUR.assets.folders;
                } else {
                    collection = folder.folder_view.collection;
                }
                NEWSBLUR.app.story_unread_counter = new NEWSBLUR.Views.UnreadCount({
                    collection: collection
                }).render();
            }
            
            if (options.fade && NEWSBLUR.app.story_unread_counter) {
                NEWSBLUR.app.story_unread_counter.$el.css({'opacity': 0});
                this.$s.$story_taskbar.append(NEWSBLUR.app.story_unread_counter.$el);
                _.delay(function() {
                    NEWSBLUR.app.story_unread_counter.center();
                    NEWSBLUR.app.story_unread_counter.$el.animate({
                        'opacity': .2
                    }, {'duration': 600, 'queue': false});
                }, 200);
            } else if (NEWSBLUR.app.story_unread_counter) {
                this.$s.$story_taskbar.append(NEWSBLUR.app.story_unread_counter.$el);
                _.delay(function() {
                    NEWSBLUR.app.story_unread_counter.center();
                    NEWSBLUR.app.story_unread_counter.$el.css({'opacity': .2});
                }, 200);
            }
        },
        
        // ===========
        // = Stories =
        // ===========
        
        load_page_of_feed_stories: function(options) {
            options = _.extend({}, {'scroll_to_loadbar': true}, options);
            var $story_titles = this.$s.$story_titles;
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);

            if (this.flags['opening_feed']) return;

            this.flags['opening_feed'] = true;
            this.counts['page'] += 1;
            if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'full') {
                NEWSBLUR.app.story_list.show_loading(options);
            } else {
                NEWSBLUR.app.story_titles.show_loading(options);
            }
            
            if (this.flags['starred_view']) {
                this.model.fetch_starred_stories(this.counts['page'], this.flags['starred_tag'], _.bind(this.post_open_starred_stories, this),
                                                 NEWSBLUR.app.taskbar_info.show_stories_error, false);
            } else if (this.active_feed == 'read') {
                this.model.fetch_read_stories(this.counts['page'], _.bind(this.post_open_read_stories, this),
                                                 NEWSBLUR.app.taskbar_info.show_stories_error, false);
            } else if (this.flags['social_view'] && _.contains(['river:blurblogs', 'river:global'], this.active_feed)) {
                this.model.fetch_river_blurblogs_stories(this.active_feed,
                                                         this.counts['page'],
                                                         {'global': this.flags.global_blurblogs},
                                                         _.bind(this.post_open_river_blurblogs_stories, this),
                                                         NEWSBLUR.app.taskbar_info.show_stories_error, false);
            } else if (this.flags['social_view']) {
                this.model.fetch_social_stories(this.active_feed,
                                                this.counts['page'], _.bind(this.post_open_social_stories, this),
                                                NEWSBLUR.app.taskbar_info.show_stories_error, false);
            } else if (this.flags['river_view']) {
                this.model.fetch_river_stories(this.active_feed, this.cache['river_feeds_with_unreads'],
                                               this.counts['page'], _.bind(this.post_open_river_stories, this),
                                               NEWSBLUR.app.taskbar_info.show_stories_error, false);
            } else {
                this.model.load_feed(feed_id, this.counts['page'], false, 
                                     $.rescope(this.post_open_feed, this), NEWSBLUR.app.taskbar_info.show_stories_error);                                 
            }
        },
        
        make_feed_title_in_stories: function(options) {
            if ((this.flags.search || this.flags.searching)
                && NEWSBLUR.app.story_titles_header.search_has_focus()) {
                console.log(["make_feed_title_in_stories not destroying", this.flags.search]);
                return;
            }
            
            if (NEWSBLUR.app.story_titles_header) {
                NEWSBLUR.app.story_titles_header.remove();
            }

            NEWSBLUR.app.story_titles_header.render({
                feed_id: this.active_feed,
                layout: NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')
            });
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
            
        open_friends_modal: function() {
            NEWSBLUR.assets.preference('has_found_friends', true);
            NEWSBLUR.reader.check_hide_getting_started();

            NEWSBLUR.reader_friends = new NEWSBLUR.ReaderFriends();
        },
        
        open_profile_editor_modal: function() {
            NEWSBLUR.reader_profile_editor = new NEWSBLUR.ReaderProfileEditor();
        },
        
        open_recommend_modal: function(feed_id) {
            NEWSBLUR.recommend_feed = new NEWSBLUR.ReaderRecommendFeed(feed_id);
        },
        
        open_tutorial_modal: function() {
            NEWSBLUR.tutorial = new NEWSBLUR.ReaderTutorial();
        },
        
        open_intro_modal: function(options) {
            NEWSBLUR.intro = new NEWSBLUR.ReaderIntro(options);
        },
        
        open_user_admin_modal: function(options) {
            $.modal.close(function() {
                NEWSBLUR.user_admin = new NEWSBLUR.ReaderUserAdmin(options);
            });
        },
        
        open_story_options_popover: function() {
            NEWSBLUR.StoryOptionsPopover.create({
                anchor: this.$s.$taskbar_options
            });
        },
        
        check_hide_getting_started: function(force) {
            var feeds = this.model.preference('has_setup_feeds');
            var friends = this.model.preference('has_found_friends');
            var trained = this.model.preference('has_trained_intelligence');
            
            if (force ||
                (friends && trained && feeds)) {
                var $gettingstarted = $('.NB-module-gettingstarted');
                $gettingstarted.animate({
                'opacity': 0
              }, {
                'duration': 380,
                'complete': function() {
                  $gettingstarted.slideUp(350);
                }
              });
              this.model.preference('hide_getting_started', true);
            } else {
                var $progress = $(".NB-intro-progress");
                var $sites = $('.NB-intro-goal-sites');
                var $findfriends = $('.NB-intro-goal-friends');
                var $trainer = $('.NB-intro-goal-train');

                $sites.toggleClass('NB-done', feeds);
                $findfriends.toggleClass('NB-done', friends);
                $trainer.toggleClass('NB-done', trained);
                
                $sites.toggleClass('NB-not-done', !feeds);
                $findfriends.toggleClass('NB-not-done', !friends);
                $trainer.toggleClass('NB-not-done', !trained);

                $(".bar-first", $progress).toggleClass('bar-striped', !feeds);
                $(".bar-second", $progress).toggleClass('bar-striped', !friends);
            }
        },
        
        // ==========================
        // = Story Pane - Feed View =
        // ==========================
        
        apply_story_styling: function(reset_stories) {
            var $body = this.$s.$body;
            $body.removeClass('NB-theme-sans-serif')
                 .removeClass('NB-theme-serif')
                 .removeClass('NB-theme-gotham')
                 .removeClass('NB-theme-sentinel')
                 .removeClass('NB-theme-whitney')
                 .removeClass('NB-theme-chronicle');
            $body.addClass('NB-theme-'+NEWSBLUR.Preferences['story_styling']);
            
            $body.removeClass('NB-theme-size-xs')
                 .removeClass('NB-theme-size-s')
                 .removeClass('NB-theme-size-m')
                 .removeClass('NB-theme-size-l')
                 .removeClass('NB-theme-size-xl');
            $body.addClass('NB-theme-size-' + NEWSBLUR.Preferences['story_size']);
            $body.removeClass('NB-theme-feed-size-xs')
                 .removeClass('NB-theme-feed-size-s')
                 .removeClass('NB-theme-feed-size-m')
                 .removeClass('NB-theme-feed-size-l')
                 .removeClass('NB-theme-feed-size-xl');
            $body.addClass('NB-theme-feed-size-' + NEWSBLUR.Preferences['feed_size']);
            
            $body.removeClass('NB-line-spacing-xs')
                 .removeClass('NB-line-spacing-s')
                 .removeClass('NB-line-spacing-m')
                 .removeClass('NB-line-spacing-l')
                 .removeClass('NB-line-spacing-xl');
            $body.addClass('NB-line-spacing-' + NEWSBLUR.Preferences['story_line_spacing']);
            
            if (reset_stories) {
                this.show_story_titles_above_intelligence_level({'animate': true, 'follow': true});
            }
        },
        
        // ===================
        // = Taskbar - Story =
        // ===================
        
        switch_taskbar_view: function(view, options) {
            options = options || {};
            // NEWSBLUR.log(['switch_taskbar_view', view, options.skip_save_type]);
            var self = this;
            var $story_pane = this.$s.$story_pane;
            var feed = this.model.get_feed(this.active_feed);
            
            if (view == 'page' && feed && feed.get('has_exception') && 
                feed.get('exception_type') == 'page') {
              this.open_feed_exception_modal();
              return;
            } else if (_.contains(['page', 'story'], view) && 
                       feed && (feed.get('disabled_page') ||
                                NEWSBLUR.utils.is_url_iframe_buster(feed.get('feed_link')))) {
                view = 'feed';
            } else if ($('.task_view_'+view).hasClass('NB-disabled') ||
                       $('.task_view_'+view).hasClass('NB-hidden')) {
                return;
            } else if (_.contains(['list', 'grid'],
                       NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')) &&
                       _.contains(['page', 'story'], view)) {
                view = 'feed';
            }
            
            var $taskbar_buttons = $('.NB-taskbar-view .NB-taskbar-button');
            var $feed_view = this.$s.$feed_view;
            var $feed_iframe = this.$s.$feed_iframe;
            var $to_feed_arrow = $('.NB-taskbar .NB-task-view-to-feed-arrow');
            var $to_story_arrow = $('.NB-taskbar .NB-task-view-to-story-arrow');
            var $to_text_arrow = $('.NB-taskbar .NB-task-view-to-text-arrow');
            
            if (!options.skip_save_type && this.story_view != view) {
                this.model.view_setting(this.active_feed, {'view': view});
            }
            
            NEWSBLUR.app.taskbar_info.hide_stories_error();
            $to_feed_arrow.hide();
            $to_story_arrow.hide();
            $to_text_arrow.hide();
            this.flags['page_view_showing_feed_view'] = false;
            this.flags['feed_view_showing_story_view'] = false;
            this.flags['temporary_story_view'] = false;
            if (options.skip_save_type == 'page') {
                $to_feed_arrow.show();
                this.flags['page_view_showing_feed_view'] = true;
            } else if (options.skip_save_type == 'story') {
                $to_story_arrow.show();
                this.flags['feed_view_showing_story_view'] = true;
            } else if (options.skip_save_type == 'text') {
                $to_text_arrow.show();
                this.flags['temporary_story_view'] = true;
            } else {
                $taskbar_buttons.removeClass('NB-active');
                $('.NB-taskbar-button.task_view_'+view).addClass('NB-active');
                this.story_view = view;
            }
            
            this.flags.scrolling_by_selecting_story_title = true;
            clearInterval(this.locks.scrolling);
            this.locks.scrolling = setTimeout(function() {
                self.flags.scrolling_by_selecting_story_title = false;
            }, 550);
            if (view == 'page') {
                // NEWSBLUR.log(["iframe_prevented_from_loading", this.flags['iframe_prevented_from_loading']]);
                if (this.flags['iframe_prevented_from_loading']) {
                    NEWSBLUR.app.original_tab_view.load_feed_iframe();
                }
                NEWSBLUR.app.original_tab_view.scroll_to_selected_story(this.active_story, {
                    immediate: true,
                    only_if_hidden: options.resize
                });
                
                $story_pane.animate({
                    'left': 0
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
            } else if (view == 'feed') {
                NEWSBLUR.app.story_list.scroll_to_selected_story(this.active_story, {
                    immediate: true,
                    only_if_hidden: options.resize
                });
                NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
                NEWSBLUR.app.story_titles.scroll_to_selected_story(this.active_story);
                
                $story_pane.animate({
                    'left': -1 * $feed_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
                
                NEWSBLUR.app.story_list.reset_story_positions();
                if (!options.resize && this.active_story && 
                    _.contains(['list', 'grid'], 
                               NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    NEWSBLUR.app.text_tab_view.unload();
                    if (this.active_story.get('selected')) {
                        this.active_story.story_title_view.render_inline_story_detail();
                    }
                }
            } else if (view == 'text') {
                NEWSBLUR.app.story_titles.scroll_to_selected_story(this.active_story);
                
                $story_pane.animate({
                    'left': -2 * $feed_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
                if (_.contains(['split', 'full'], 
                               NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    NEWSBLUR.app.text_tab_view.fetch_and_render();
                    if (!this.active_story) {
                        NEWSBLUR.app.text_tab_view.show_explainer_single_story_mode();
                    }
                } else if (!options.resize && this.active_story && 
                           this.active_story.get('selected') &&
                           _.contains(['list', 'grid'],
                                      NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    this.active_story.story_title_view.render_inline_story_detail();
                }
            } else if (view == 'story') {
                $story_pane.animate({
                    'left': -3 * $feed_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
                if (!this.active_story) {
                    NEWSBLUR.app.story_tab_view.show_explainer_single_story_mode();                        
                } else if (!options.resize) {
                    NEWSBLUR.app.story_tab_view.open_story();
                }
            }
            
            this.setup_mousemove_on_views();
        },
        
        switch_taskbar_view_direction: function(direction) {
            var $active = $('.NB-taskbar-view .NB-active');
            var view;
            
            if (_.contains(['list', 'grid'], 
                NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                if (direction == -1) {
                    if ($active.hasClass('task_view_feed')) {
                        // view = 'page';
                    } else if ($active.hasClass('task_view_text')) {
                        view = 'feed';
                    } 
                } else if (direction == 1) {
                    if ($active.hasClass('task_view_feed')) {
                        view = 'text';
                    } else if ($active.hasClass('task_view_text')) {
                        // view = 'story';
                    } 
                }                
            } else {
                if (direction == -1) {
                    if ($active.hasClass('task_view_page')) {
                        // view = 'page';
                    } else if ($active.hasClass('task_view_feed')) {
                        view = 'page';
                    } else if ($active.hasClass('task_view_text')) {
                        view = 'feed';
                    } else if ($active.hasClass('task_view_story')) {
                        view = 'text';
                    } 
                } else if (direction == 1) {
                    if ($active.hasClass('task_view_page')) {
                        view = 'feed';
                    } else if ($active.hasClass('task_view_feed')) {
                        view = 'text';
                    } else if ($active.hasClass('task_view_text')) {
                        view = 'story';
                    } else if ($active.hasClass('task_view_story')) {
                        // view = 'text';
                    } 
                }
            }
            
            if (view) {
                this.switch_taskbar_view(view);  
            }
        },
        
        // ===================
        // = Taskbar - Feeds =
        // ===================
        
        open_add_feed_modal: function(options) {
            clearInterval(this.flags['bouncing_callout']);
            $.modal.close();
            
            NEWSBLUR.add_feed = NEWSBLUR.ReaderAddFeed.create(options);
        },
        
        open_manage_feed_modal: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            NEWSBLUR.manage_feed = new NEWSBLUR.ReaderManageFeed(feed_id);
        },

        open_mark_read_modal: function(options) {
            NEWSBLUR.mark_read = new NEWSBLUR.ReaderMarkRead(options);
        },

        open_keyboard_shortcuts_modal: function() {
            NEWSBLUR.keyboard = new NEWSBLUR.ReaderKeyboard();
        },
                
        open_goodies_modal: function() {
            NEWSBLUR.goodies = new NEWSBLUR.ReaderGoodies();
        },
                        
        open_newsletters_modal: function() {
            NEWSBLUR.newsletters = new NEWSBLUR.ReaderNewsletters();
        },
                        
        open_preferences_modal: function() {
            NEWSBLUR.preferences = new NEWSBLUR.ReaderPreferences();
        },
                        
        open_account_modal: function(options) {
            NEWSBLUR.account = new NEWSBLUR.ReaderAccount(options);
        },
        
        open_feedchooser_modal: function(options) {
            NEWSBLUR.feedchooser = new NEWSBLUR.ReaderFeedchooser(options);
        },
        
        open_organizer_modal: function(options) {
            NEWSBLUR.organizer = new NEWSBLUR.ReaderOrganizer(options);
        },
        
        open_feed_exception_modal: function(feed_id, options) {
            feed_id = feed_id || this.active_feed;
            
            NEWSBLUR.feed_exception = new NEWSBLUR.ReaderFeedException(feed_id, options);
        },
        
        open_feed_statistics_modal: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            NEWSBLUR.statistics = new NEWSBLUR.ReaderStatistics(feed_id);
        },
        
        open_social_profile_modal: function(user_id) {
            if (!user_id) user_id = NEWSBLUR.Globals.user_id;
            if (_.string.contains(user_id, 'social:')) {
                user_id = parseInt(user_id.replace('social:', ''), 10);
            }
            NEWSBLUR.social_profile = new NEWSBLUR.ReaderSocialProfile(user_id);
        },
        
        close_social_profile: function() {
            if (NEWSBLUR.social_profile) {
                NEWSBLUR.social_profile.close();
            }
        },
        
        close_interactions_popover: function() {
            NEWSBLUR.InteractionsPopover.close();
        },
        
        toggle_sidebar: function() {
            if (this.flags['sidebar_closed']) {
                this.open_sidebar();
                return true;
            } else {
                this.close_sidebar();
                return false;
            }
        },
        
        close_sidebar: function() {
            this.$s.$layout.layout().hide('west');
            this.resize_window();
            this.flags['sidebar_closed'] = true;
        },
        
        open_sidebar: function() {
            this.$s.$layout.layout().open('west');
            this.resize_window();
            this.flags['sidebar_closed'] = false;
        },
        
        toggle_story_titles_pane: function(update_layout) {
            if (this.flags['story_titles_closed']) {
                this.open_story_titles_pane(update_layout === true);
            } else {
                this.close_story_titles_pane(update_layout === true);
            }
        },
        
        close_story_titles_pane: function(update_layout) {
            var story_anchor = this.model.preference('story_pane_anchor');
            if (update_layout) {
                NEWSBLUR.reader.layout.contentLayout.hide(story_anchor);
            }
            this.resize_window();
            this.flags['story_titles_closed'] = true;
        },
        
        open_story_titles_pane: function(update_layout) {
            var story_anchor = this.model.preference('story_pane_anchor');
            if (update_layout) {
                NEWSBLUR.reader.layout.contentLayout.open(story_anchor);
            }
            this.resize_window();
            this.flags['story_titles_closed'] = false;
            _.defer(function() {
                NEWSBLUR.app.story_titles.scroll_to_selected_story();
            });
        },
        
        // =======================
        // = Sidebar Manage Menu =
        // =======================

        make_manage_menu: function(type, feed_id, story_id, inverse, $item) {
            var $manage_menu;
            // NEWSBLUR.log(["make_manage_menu", type, feed_id, story_id, inverse, $item]);

            if (type == 'site') {
                var show_chooser = !NEWSBLUR.Globals.is_premium && NEWSBLUR.Globals.is_authenticated;
                $manage_menu = $.make('ul', { className: 'NB-menu-manage' }, [
                    $.make('li', { className: 'NB-menu-manage-site-info' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('span', { className: 'NB-menu-manage-title' }, "Manage NewsBlur")
                    ]).corner('top 8px').corner('bottom 0px'),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-mark-read NB-menu-manage-site-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark everything as read'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Choose how many days back')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-trainer' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence Trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Accurate filters are happy filters')
                    ]),
                    (show_chooser && $.make('li', { className: 'NB-menu-item NB-menu-manage-feedchooser' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Choose Your 64 sites'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Enable the sites you want')
                    ])),
                    (NEWSBLUR.Globals.is_premium && $.make('li', { className: 'NB-menu-item NB-menu-manage-feedchooser' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mute Sites'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Temporarily turn off feeds')
                    ])),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-organizer' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Organize Sites'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Cleanup and rearrange feeds')
                    ]),
                    (show_chooser && $.make('li', { className: 'NB-menu-item NB-menu-manage-premium' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Upgrade to premium')
                    ])),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-keyboard' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Keyboard shortcuts')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-tutorial' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Tips &amp; Tricks')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-goodies' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Goodies &amp; Mobile Apps')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-newsletters' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Email Newsletters')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-import' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Import or upload sites')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-account' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-logout NB-modal-submit-green NB-modal-submit-button' }, 'Logout'),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Account')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-profile-editor' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Profile &amp; Blurblog')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-friends' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Friends &amp; Followers')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-preferences' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Preferences')
                    ])
                ]);
                $manage_menu.addClass('NB-menu-manage-notop');
            } else if (type == 'feed') {
                var feed = this.model.get_feed(feed_id);
                if (!feed) return;
                var unread_count = this.get_total_unread_count(feed_id);
                var tab_unread_count = Math.min(25, unread_count);
                var muted = !feed.get('active');
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-feed' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-exception' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Fix this misbehaving site')
                    ])),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-separator-inverse' })),
                    (feed.get('exception_type') != 'feed' && $.make('li', { className: 'NB-menu-item NB-menu-manage-mark-read NB-menu-manage-feed-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as read')
                    ])),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-reload' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Insta-fetch stories')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-stats' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Statistics')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-settings' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Site settings')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    (NEWSBLUR.Globals.is_admin && $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-recommend' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Recommend this site')
                    ])),
                    (NEWSBLUR.Globals.is_admin && $.make('li', { className: 'NB-menu-separator' })),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-move NB-menu-manage-feed-move' }, [
                        $.make('div', { className: 'NB-menu-manage-move-save NB-menu-manage-feed-move-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Change folders')
                    ]),
                    $.make('li', { className: 'NB-menu-subitem NB-menu-manage-confirm NB-menu-manage-feed-move-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-change-folders' })
                        ])
                    ]),
                    (muted && $.make('li', { className: 'NB-menu-item NB-menu-manage-unmute NB-menu-manage-feed-unmute' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Un-mute this site')
                    ])),
                    (!muted && $.make('li', { className: 'NB-menu-item NB-menu-manage-mute NB-menu-manage-feed-mute' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mute this site')
                    ])),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-rename NB-menu-manage-feed-rename' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Rename this site')
                    ]),
                    $.make('li', { className: 'NB-menu-subitem NB-menu-manage-confirm NB-menu-manage-feed-rename-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-menu-manage-rename-save NB-menu-manage-feed-rename-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                            $.make('div', { className: 'NB-menu-manage-image' }),
                            $.make('input', { name: 'new_title', className: 'NB-menu-manage-title NB-input', value: feed.get('feed_title') })
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-delete NB-menu-manage-feed-delete' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Delete this site')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-delete-confirm NB-menu-manage-feed-delete-confirm' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Really delete?')
                    ])
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('$feed', $item);
                if (feed_id && unread_count == 0) {
                    $('.NB-menu-manage-feed-mark-read', $manage_menu).addClass('NB-disabled');
                }
            } else if (type == 'socialfeed') {
                var feed = this.model.get_feed(feed_id);
                if (!feed) return;
                var unread_count = this.get_total_unread_count(feed_id);
                var tab_unread_count = Math.min(25, unread_count);
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-feed' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-exception' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Fix this misbehaving site')
                    ])),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-separator-inverse' })),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-social-profile' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'View profile')
                    ]),
                    (feed.get('exception_type') != 'feed' && $.make('li', { className: 'NB-menu-separator' })),
                    (feed.get('exception_type') != 'feed' && $.make('li', { className: 'NB-menu-item NB-menu-manage-mark-read NB-menu-manage-feed-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as read')
                    ])),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-stats' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Statistics')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-settings' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Site settings')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    (feed.get('user_id') != NEWSBLUR.Globals.user_id && $.make('li', { className: 'NB-menu-item NB-menu-manage-delete NB-menu-manage-socialfeed-delete' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Unfollow')
                    ])),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-delete-confirm NB-menu-manage-socialfeed-delete-confirm' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Really unfollow?')
                    ])
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('$feed', $item);
                if (feed_id && unread_count == 0) {
                    $('.NB-menu-manage-feed-mark-read', $manage_menu).addClass('NB-disabled');
                }
            } else if (type == 'starred') {
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-feed' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-feed-settings' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Tag settings')
                    ])
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('$feed', $item);
            } else if (type == 'folder') {
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-folder' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-mark-read NB-menu-manage-folder-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark folder as read')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-folder-subscribe' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Add a site to this folder')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-folder-subfolder' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Create a new subfolder')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-folder-settings' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Folder settings')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-move NB-menu-manage-folder-move' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Move to folder')
                    ]),
                    $.make('li', { className: 'NB-menu-subitem NB-menu-manage-confirm NB-menu-manage-folder-move-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-menu-manage-move-save NB-menu-manage-folder-move-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                            $.make('div', { className: 'NB-menu-manage-image' }),
                            $.make('div', { className: 'NB-add-folders' }, NEWSBLUR.utils.make_folders())
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-rename NB-menu-manage-folder-rename' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Rename this folder')
                    ]),
                    $.make('li', { className: 'NB-menu-subitem NB-menu-manage-confirm NB-menu-manage-folder-rename-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position'}, [
                            $.make('div', { className: 'NB-menu-manage-rename-save NB-menu-manage-folder-rename-save NB-modal-submit-green NB-modal-submit-button' }, 'Save'),
                            $.make('div', { className: 'NB-menu-manage-image' }),
                            $.make('input', { name: 'new_title', className: 'NB-menu-manage-title NB-input', value: feed_id })
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-delete NB-menu-manage-folder-delete' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Delete this folder')
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-delete-confirm NB-menu-manage-folder-delete-confirm' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Really delete?')
                    ])
                ]);
                $manage_menu.data('folder_name', feed_id);
                $manage_menu.data('$folder', $item);
            } else if (type == 'story') {
                var feed          = this.model.get_feed(feed_id);
                var story         = this.model.get_story(story_id);
                var starred_class = story.get('starred') ? ' NB-story-starred ' : '';
                var starred_title = story.get('starred') ? 'Unsave this story' : 'Save this story';
                var shared_class = story.get('shared') ? ' NB-story-shared ' : '';
                var shared_title = story.get('shared') ? 'Shared' : 'Share to your Blurblog';
                var order        = NEWSBLUR.assets.view_setting(this.active_feed, 'order');
                story.story_share_menu_view = new NEWSBLUR.Views.StoryShareView({
                    model: story
                });
                
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-story ' + starred_class + shared_class }, [
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-story-open' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('input', { name: 'story_permalink', className: 'NB-menu-manage-open-input NB-input', value: story.get('story_permalink') }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Open')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    (story.get('read_status') && $.make('li', { className: 'NB-menu-item NB-menu-manage-story-unread' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as unread')
                    ])),
                    (!story.get('read_status') && $.make('li', { className: 'NB-menu-item NB-menu-manage-story-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as read')
                    ])),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-story-star' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, starred_title)
                    ]),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-story-thirdparty' }, [
                        (NEWSBLUR.Preferences['story_share_facebook'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-facebook'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Facebook').parent().addClass('NB-menu-manage-highlight-facebook');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-facebook');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_twitter'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-twitter'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Twitter').parent().addClass('NB-menu-manage-highlight-twitter');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-twitter');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_readitlater'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-readitlater'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Pocket (RIL)').parent().addClass('NB-menu-manage-highlight-readitlater');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-readitlater');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_tumblr'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-tumblr'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Tumblr').parent().addClass('NB-menu-manage-highlight-tumblr');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-tumblr');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_blogger'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-blogger'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Blogger').parent().addClass('NB-menu-manage-highlight-blogger');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-blogger');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_delicious'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-delicious'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Delicious').parent().addClass('NB-menu-manage-highlight-delicious');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-delicious');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_pinboard'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-pinboard'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Pinboard').parent().addClass('NB-menu-manage-highlight-pinboard');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-pinboard');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_pinterest'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-pinterest'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Pinterest').parent().addClass('NB-menu-manage-highlight-pinterest');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-pinterest');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_buffer'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-buffer'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Buffer').parent().addClass('NB-menu-manage-highlight-buffer');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-buffer');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_diigo'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-diigo'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Diigo').parent().addClass('NB-menu-manage-highlight-diigo');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-diigo');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_kippt'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-kippt'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Kippt').parent().addClass('NB-menu-manage-highlight-kippt');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-kippt');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_evernote'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-evernote'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Evernote').parent().addClass('NB-menu-manage-highlight-evernote');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-evernote');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_googleplus'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-googleplus'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Google+').parent().addClass('NB-menu-manage-highlight-googleplus');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-googleplus');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_instapaper'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-instapaper'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Instapaper').parent().addClass('NB-menu-manage-highlight-instapaper');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-instapaper');
                        }, this))),
                        (NEWSBLUR.Preferences['story_share_readability'] && $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-readability'}).bind('mouseenter', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Readability').parent().addClass('NB-menu-manage-highlight-readability');
                        }, this)).bind('mouseleave', _.bind(function(e) {
                            $(e.target).siblings('.NB-menu-manage-title').text('Email story').parent().removeClass('NB-menu-manage-highlight-readability');
                        }, this))),
                        $.make('div', { className: 'NB-menu-manage-thirdparty-icon NB-menu-manage-thirdparty-email'}),
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Email story')
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
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-tumblr')) {
                          this.send_story_to_tumblr(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-blogger')) {
                          this.send_story_to_blogger(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-delicious')) {
                          this.send_story_to_delicious(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-readability')) {
                          this.send_story_to_readability(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-pinboard')) {
                          this.send_story_to_pinboard(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-pinterest')) {
                          this.send_story_to_pinterest(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-buffer')) {
                          this.send_story_to_buffer(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-diigo')) {
                          this.send_story_to_diigo(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-kippt')) {
                          this.send_story_to_kippt(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-evernote')) {
                          this.send_story_to_evernote(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-googleplus')) {
                          this.send_story_to_googleplus(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-instapaper')) {
                          this.send_story_to_instapaper(story.id);
                      } else {
                          this.send_story_to_email(story);
                      }
                    }, this)),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-story NB-menu-manage-story-share' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, shared_title)
                    ]),
                    $.make('li', { className: 'NB-menu-subitem NB-menu-manage-story NB-menu-manage-confirm NB-menu-manage-story-share-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position' }, [
                            story.story_share_menu_view.render().el
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-story-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    (order == "newest" && $.make('li', { className: 'NB-menu-item NB-menu-manage-story-mark-read-newer NB-up' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark newer stories read')
                    ])),
                    $.make('li', { className: 'NB-menu-item NB-menu-manage-story-mark-read-older ' + (order == "oldest" ? "NB-up" : "NB-down") }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark older stories read')
                    ]),
                    (order == "oldest" && $.make('li', { className: 'NB-menu-item NB-menu-manage-story-mark-read-newer NB-down' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark newer stories read')
                    ]))
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('story_id', story_id);
                $manage_menu.data('$story', $item);
                
                // this.update_share_button_label($('.NB-sideoption-share-comments', $manage_menu));
            }
            
            return $manage_menu;
        },
        
        show_manage_menu: function(type, $item, options) {
            var self = this;
            var options = _.extend({
              'toplevel': false,
              'inverse':  false
            }, options);
            var $manage_menu_container = $('.NB-menu-manage-container');

            clearTimeout(this.flags.closed_manage_menu);
            this.flags['showing_confirm_input_on_manage_menu'] = false;
            
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
                feed_id = options.folder_title;
                inverse = options.inverse || $item.hasClass("NB-hover-inverse");
            } else if (type == 'feed') {
                feed_id = options.feed_id;
                inverse = options.inverse || $item.hasClass("NB-hover-inverse");
            } else if (type == 'socialfeed') {
                feed_id = options.feed_id;
                inverse = options.inverse || $item.hasClass("NB-hover-inverse");
            } else if (type == 'starred') {
                feed_id = options.feed_id;
                inverse = options.inverse || $item.hasClass("NB-hover-inverse");
            } else if (type == 'story') {
                story_id = options.story_id;
                if ($item.hasClass('NB-hover-inverse')) inverse = true; 
            } else if (type == 'site') {
                $('.NB-task-manage').tipsy('hide');
                $('.NB-task-manage').tipsy('disable');
                if (options.inverse) inverse = true;
            }
            var toplevel = options.toplevel || $item.hasClass("NB-toplevel") ||
                           $item.children('.folder_title').hasClass("NB-toplevel");
            var $manage_menu = this.make_manage_menu(type, feed_id, story_id, inverse, $item);
            $manage_menu_container.empty().append($manage_menu);
            $manage_menu_container.data('item', $item && $item[0]);
            $('.NB-task-manage').parents('.NB-taskbar').css('z-index', 2);
            if (type == 'site') {
                if (inverse) {
                    $('li', $manage_menu_container).each(function() {
                        $(this).prependTo($(this).parent());
                    });
                    $manage_menu_container.corner('bottom 8px').corner('top 0px');
                    $('.NB-menu-manage-site-info', $manage_menu_container).hide();
                } else {
                    $manage_menu_container.corner('top 8px').corner('bottom 0px');
                }

                if ($item.hasClass('NB-task-manage')) {
                    $manage_menu_container.align($item, 'top -left', {
                        'top': 0, 
                        'left': -2
                    });
                } else if (options.right) {
                    $manage_menu_container.align($item, '-top -left', {
                        'top': -34, 
                        'left': 0
                    });                    
                } else {
                    $manage_menu_container.align($item, '-top left', {
                        'top': -24, 
                        'left': 20
                    });
                }
                if (options.body) {
                    $manage_menu_container.appendTo(this.$s.$body);
                    $manage_menu_container.css('z-index', $("#simplemodal-container").css('z-index'));
                }
                $('.NB-task-manage').addClass('NB-hover');
            } else if (type == 'feed' || type == 'folder' || type == 'story' || 
                       type == 'socialfeed' || type == 'starred') {
                var left, top;
                // NEWSBLUR.log(['menu open', $item, inverse, toplevel, type]);
                if (inverse) {
                    var $align = $item;
                    if (type == 'feed') {
                        left = toplevel ? 2 : -22;
                        top = toplevel ? 1 : 3;
                    } else if (type == 'socialfeed' || type == 'starred') {
                        left = 2;
                        top = 2;
                    } else if (type == 'folder') {
                        left = toplevel ? 0 : -21;
                        top = toplevel ? 3 : 3;
                    } else if (type == 'story') {
                        left = 7;
                        top = 3;
                        $align = $('.NB-story-manage-icon,.NB-feed-story-manage-icon', $item);
                        if (!$align.is(':visible')) {
                            $align = $('.NB-storytitles-sentiment,.NB-feed-story-sentiment', $item);
                        }
                    }
                    
                    $manage_menu_container.align($align, 'top -left', {
                        'top': -1 * top, 
                        'left': left
                    });

                    $manage_menu_container.corner('br 8px').corner('bl top 0px');
                    $('li', $manage_menu_container).each(function() {
                        $(this).prependTo($(this).parent());
                    });
                } else {
                    var $align = $item;
                    if (type == 'feed') {
                        left = toplevel ? 0 : -2;
                        top = toplevel ? 20 : 19;
                        $align = $('.NB-feedlist-manage-icon', $item);
                    } else if (type == 'socialfeed' || type == 'starred') {
                        left = toplevel ? 0 : -18;
                        top = toplevel ? 20 : 21;
                        $align = $('.NB-feedlist-manage-icon', $item);
                    } else if (type == 'folder') {
                        left = toplevel ? 0 : -22;
                        top = toplevel ? 21 : 18;
                    } else if (type == 'story') {
                        left = 7;
                        top = 19;
                        $align = $('.NB-story-manage-icon,.NB-feed-story-manage-icon', $item);
                        if (!$align.is(':visible')) {
                            $align = $('.NB-storytitles-sentiment,.NB-feed-story-sentiment', $item);
                        }
                    }
                    $manage_menu_container.align($align, '-bottom -left', {
                        'top': top, 
                        'left': left
                    });
                    $manage_menu_container.corner('tr 8px').corner('tl bottom 0px');
                }
            }
            $manage_menu_container.stop().css({'display': 'block', 'opacity': 1});
            
            // Create and position the arrow tab
            if (type == 'feed' || type == 'folder' || type == 'story' || 
                type == 'socialfeed' || type == 'starred') {
                var $arrow = $.make('div', { className: 'NB-menu-manage-arrow' }, [
                    $.make('div', { className: 'NB-icon' })
                ]);
                if (inverse) {
                    $arrow.corner('bottom 5px').corner('top 0px');
                    $manage_menu_container.append($arrow);
                    $manage_menu_container.addClass('NB-inverse');
                } else {
                    $arrow.corner('top 5px').corner('bottom 0px');
                    $manage_menu_container.prepend($arrow);
                    $manage_menu_container.removeClass('NB-inverse');
                }
            }
            
            // Hide menu on click outside menu.
            _.defer(function() {
                var close_menu_handler = function(e) {
                    _.defer(function() {
                        $(document).bind('click.menu', function(e) {
                            self.hide_manage_menu(type, $item, false);
                        });
                    });
                };
                if (options.rightclick) {
                    $(document).one('mouseup.menu', close_menu_handler);
                } else {
                    close_menu_handler();
                }
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
            
            // Hide menu on esc.
            $(document).add($('input,textarea', $manage_menu_container))
                .unbind('keydown.manage_menu')
                .bind('keydown.manage_menu', 'esc', function(e) {
                e.preventDefault();
                self.flags['showing_confirm_input_on_manage_menu'] = false;
                self.hide_manage_menu(type, $item, true);
            });
            if (type == 'story') {
                var share = _.bind(function(e) {
                    e.preventDefault();
                    var story = NEWSBLUR.assets.get_story(story_id);
                    story.story_share_menu_view.mark_story_as_shared({'source': 'menu'});
                }, this);
                $('.NB-sideoption-share-comments', $manage_menu_container).bind('keydown', 'ctrl+return', share);
                $('.NB-sideoption-share-comments', $manage_menu_container).bind('keydown', 'meta+return', share);
            }
            
            // Hide menu on scroll.
            var $scroll;
            this.flags['feed_list_showing_manage_menu'] = true;
            if (type == 'feed' || type == 'socialfeed' || type == 'starred') {
                $scroll = this.$s.$feed_list.parent();
            } else if (type == 'story') {
                $scroll = this.$s.$story_titles.add(this.$s.$feed_scroll);
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
            $(document).unbind('mouseup.menu');
            $(document).add($('input,textarea', $manage_menu_container))
                       .unbind('keydown.manage_menu');

            if (this.model.preference('show_tooltips')) {
                $('.NB-task-manage').tipsy('enable');
            }
            
            if ($item) $item.removeClass('NB-showing-menu');
            
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
            
            this.blur_to_page({manage_menu: true});
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
        
        manage_menu_delete_feed: function(feed_id, $feed) {
            var self = this;
            feed_id = feed_id || this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var feed_view = feed.get_view($feed);
            feed.delete_feed({view: feed_view});
        },
        
        show_confirm_unfollow_menu_item: function() {
            var $unfollow = $('.NB-menu-manage-socialfeed-delete');
            var $confirm = $('.NB-menu-manage-socialfeed-delete-confirm');
            
            $unfollow.addClass('NB-menu-manage-socialfeed-delete-cancel');
            $('.NB-menu-manage-title', $unfollow).text('Cancel unfollow');
            $confirm.slideDown(500);
        },
        
        hide_confirm_unfollow_menu_item: function() {
            var $unfollow = $('.NB-menu-manage-socialfeed-delete,.NB-menu-manage-folder-delete');
            var $confirm = $('.NB-menu-manage-socialfeed-delete-confirm,.NB-menu-manage-folder-delete-confirm');
            
            $unfollow.removeClass('NB-menu-manage-socialfeed-delete-cancel');

            $('.NB-menu-manage-title', $unfollow).text('Unfollow');
            $confirm.slideUp(500);
        },
        
        manage_menu_unfollow_feed: function(feed, $feed) {
            var self = this;
            var feed_id = feed || this.active_feed;
            
            this.model.unfollow_user(feed_id, function() {
                NEWSBLUR.app.feed_list.make_social_feeds();
            });
        },
        
        
        manage_menu_delete_folder: function(folder_title, $folder) {
            var self = this;
            var folder_view = NEWSBLUR.assets.folders.get_view($folder) ||
                              this.active_folder.folder_view;
        
            folder_view.model.delete_folder();
        },
        
        // ========================
        // = Manage menu - Move =
        // ========================
        
        show_confirm_move_menu_item: function(feed_id, $feed) {
            var self = this;
            var $move = $('.NB-menu-manage-feed-move,.NB-menu-manage-folder-move');
            var $confirm = $('.NB-menu-manage-feed-move-confirm,.NB-menu-manage-folder-move-confirm');
            var $position = $('.NB-menu-manage-confirm-position', $confirm);
            var $add = $(".NB-add-folders,.NB-change-folders", $confirm);
            var $save = $(".NB-menu-manage-feed-move-save");
            var $select = $('select', $confirm);
            var isFeed = _.isNumber(feed_id);
            
            if (isFeed) {
                var feed      = this.model.get_feed(feed_id);
                var feed_view = feed.get_view($feed, true);
                var in_folder = feed_view.options.folder_title;
                feed.set('menu_folders', null, {silent: true});
                var $folders = this.make_folders_multiselect(feed);
                $add.html($folders);
                $save.addClass("NB-disabled").attr('disabled', "disabled").text('Select folders');
            } else {
                folder_view = NEWSBLUR.assets.folders.get_view($feed) ||
                              this.active_folder.folder_view;
                var in_folder = folder_view.collection.options.title;
            }
            
            $move.addClass('NB-menu-manage-feed-move-cancel');
            $('.NB-menu-manage-title', $move).text('Cancel');
            $position.css('position', 'relative');
            var height = $confirm.height();
            $position.css('position', 'absolute');
            $confirm.css({'height': 0, 'display': 'block'}).animate({'height': height}, {
                'duration': 380, 
                'easing': 'easeOutQuart'
            });
            if (isFeed) {
                $save.fadeIn(380);
            }
            this.flags['showing_confirm_input_on_manage_menu'] = true;
            
            if (!_.isNumber(feed_id)) {
                $('select', $confirm).focus().select();
                $('option', $select).each(function() {
                    if ($(this).attr('value') == in_folder) {
                        $(this).attr('selected', 'selected');
                        return false;
                    }
                });
            }
        },
        
        make_folders_multiselect: function(feed, in_folders) {
            var folders = NEWSBLUR.assets.get_folders();
            if (!in_folders) in_folders = feed.in_folders();
            in_folders = _.unique(in_folders.concat(feed.get('menu_folders') || []));
            feed.set('menu_folders', in_folders, {silent: true});
            var $options = $.make('div', { className: 'NB-folders' });
            var $option = this.make_folder_selectable('Top Level', '', 0, _.any(in_folders, function(folder) {
                return !folder;
            }));
            $options.append($option);
            
            $options = this.make_folders_multiselect_options($options, folders, 1, in_folders);

            return $options;
        },
        
        make_folders_multiselect_options: function($options, items, depth, in_folders) {
            var self = this;
            items.each(function(item) {
                if (item.is_folder()) {
                    var title = item.get('folder_title');
                    var $option = self.make_folder_selectable(title, title, depth, _.contains(in_folders, title));
                    $options.append($option);
                    $options = self.make_folders_multiselect_options($options, item.folders, depth+1, in_folders);
                }
            });
    
            return $options;
        },
        
        make_folder_selectable: function(folder_title, folder_value, depth, selected) {
            return $.make('div', { 
                className: "NB-folder-option " + (selected ? "NB-folder-option-active" : ""),
                style: 'padding-left: ' + depth*12 + 'px;'
            }, [
                $.make('div', { className: 'NB-icon-add' }),
                $.make('div', { className: 'NB-icon' }),
                $.make('div', { className: 'NB-folder-option-title' }, folder_title)
            ]).data('folder', folder_value);
        },
        
        switch_change_folder: function(feed_id, folder_value) {
            var feed       = this.model.get_feed(feed_id);
            var in_folders = feed.get('menu_folders');

            if (_.contains(in_folders, folder_value)) {
                in_folders = _.without(in_folders, folder_value);
            } else {
                in_folders = in_folders.concat(folder_value);
            }

            feed.set('menu_folders', in_folders, {silent: true});
            
            this.render_change_folders(feed, in_folders);
        },
        
        render_change_folders: function(feed, in_folders) {
            var $confirm = $('.NB-menu-manage-feed-move-confirm,.NB-menu-manage-folder-move-confirm');
            var $add = $(".NB-add-folders,.NB-change-folders", $confirm);
            var $save = $(".NB-menu-manage-feed-move-save");

            var $folders = this.make_folders_multiselect(feed, in_folders);
            $add.html($folders);
            
            if (_.isEqual(in_folders, feed.in_folders())) {
                $save.addClass("NB-disabled").attr('disabled', "disabled").text('Select folders');
            } else {
                $save.toggleClass("NB-disabled", !in_folders.length)
                     .attr('disabled', !in_folders.length ? "disabled" : false);
            }
            
            if (!in_folders.length) {
                $save.text('Select a folder');
            } else {
                $save.text("Save " + Inflector.pluralize(' folder', in_folders.length, true));
            }
        },
        
        show_add_folder_in_menu: function(feed_id, $folder, folder) {
            var self = this;
            
            if ($folder.siblings('.NB-add-folder-form').length) {
                var feed       = this.model.get_feed(feed_id);
                var in_folders = feed.get('menu_folders');
                this.render_change_folders(feed, in_folders);
                return;
            }
            
            var $add = $.make('div', { className: 'NB-add-folder-form' }, [
                $.make('div', { className: 'NB-icon' }),
                $.make('input', { className: 'NB-input', placeholder: "New folder name..." }),
                $.make('div', { className: 'NB-menu-manage-add-folder-save NB-modal-submit-green NB-modal-submit-button' }, 'Add')
            ]).data('in_folder', $folder.data('folder'));
            $add.css('paddingLeft', parseInt($folder.css('paddingLeft'), 10) + 12);
            $folder.after($add);
            
            $('input', $add).focus().bind('keyup', 'return', function(e) {
                self.add_folder_to_folder();
            }).bind('keyup', 'esc', function(e) {
                var feed       = self.model.get_feed(feed_id);
                var in_folders = feed.get('menu_folders');
                self.render_change_folders(feed, in_folders);                
            });
        },
        
        add_folder_to_folder: function() {
            var $form = $('.NB-add-folder-form');
            var folder_name = $('.NB-input', $form).val();
            var parent_folder = $form.data('in_folder');

            this.model.save_add_folder(folder_name, parent_folder,
                                       $.rescope(this.post_add_folder_to_folder, this));
        },
        
        post_add_folder_to_folder: function(e, data) {
            if (data.folders) {
                NEWSBLUR.assets.folders.reset(_.compact(data.folders), {parse: true});
            }
            
            var feed_id    = $('.NB-menu-manage').data('feed_id');
            var feed       = this.model.get_feed(feed_id);
            var in_folders = feed.get('menu_folders');

            NEWSBLUR.assets.feeds.trigger('reset');

            this.render_change_folders(feed, in_folders);
        },
        
        manage_menu_move_feed: function(feed_id, $feed) {
            var self       = this;
            var feed_id    = feed_id || this.active_feed;
            var feed       = this.model.get_feed(feed_id);
            var in_folders = feed.get('menu_folders');
            var feed_view  = feed.get_view($feed);

            var moved = feed.move_to_folders(in_folders, {view: feed_view});
            this.hide_confirm_move_menu_item(moved);
            if (moved) {
                _.delay(_.bind(function() {
                    this.hide_manage_menu('feed', $feed, true);
                }, this), 500);
            }
        },
        
        manage_menu_move_folder: function(folder, $folder) {
            var self        = this;
            var to_folder   = $('.NB-menu-manage-folder-move-confirm select').val();
            var folder_view = NEWSBLUR.assets.folders.get_view($folder) || 
                              this.active_folder.folder_view;
            var in_folder   = folder_view.collection.options.title;
            var folder_name = folder_view.options.folder_title;
            var child_folders = folder_view.collection.child_folder_names();
            
            if (to_folder == in_folder || 
                to_folder == folder_name ||
                 _.contains(child_folders, to_folder)) {
                return this.hide_confirm_move_menu_item();
            }
            
            var moved = folder_view.model.move_to_folder(to_folder, {view: folder_view});
            this.hide_confirm_move_menu_item(moved);
            if (moved) {
                _.delay(_.bind(function() {
                    this.hide_manage_menu('folder', $folder, true);
                }, this), 500);
            }
        },
        
        hide_confirm_move_menu_item: function(moved) {
            var $move_folder = $('.NB-menu-manage-folder-move');
            var $move_feed = $('.NB-menu-manage-feed-move');
            var $confirm_folder = $('.NB-menu-manage-folder-move-confirm');
            var $confirm_feed = $('.NB-menu-manage-feed-move-confirm');
            var $save = $(".NB-menu-manage-feed-move-save");

            $move_folder.removeClass('NB-menu-manage-feed-move-cancel');
            $move_feed.removeClass('NB-menu-manage-feed-move-cancel');
            var text_folder = 'Move to folder';
            var text_feed = 'Change folders';
            if (moved) {
                text_folder = 'Moved';
                text_feed = 'Moved';
                $move_folder.addClass('NB-active');
                $move_feed.addClass('NB-active');
            } else {
                $move_folder.removeClass('NB-active');
                $move_feed.removeClass('NB-active');
            }
            $('.NB-menu-manage-title', $move_folder).text(text_folder);
            $('.NB-menu-manage-title', $move_feed).text(text_feed);
            $confirm_feed.slideUp(500);
            $confirm_folder.slideUp(500);
            $save.hide();
            this.flags['showing_confirm_input_on_manage_menu'] = false;
        },
        
        manage_menu_mute_feed: function(feed_id, unmute) {
            var approve_list = _.pluck(NEWSBLUR.assets.feeds.filter(function(feed) {
                if (unmute) {
                    return feed.get('active') || feed.get('id') == feed_id;
                }
                return feed.get('active') && feed.get('id') != feed_id;
            }), 'id');

            console.log(["Saving", approve_list, feed_id]);

            NEWSBLUR.reader.flags['reloading_feeds'] = true;
            this.model.save_feed_chooser(approve_list, _.bind(function() {
                this.flags['has_saved'] = true;
                NEWSBLUR.reader.flags['reloading_feeds'] = false;
                NEWSBLUR.reader.hide_feed_chooser_button();
                NEWSBLUR.assets.load_feeds();
                this.hide_manage_menu();
            }, this));
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
                'duration': 380, 
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
        
        manage_menu_rename_feed: function(feed_id) {
            var feed_id   = feed_id || this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var new_title = $('.NB-menu-manage-feed-rename-confirm .NB-menu-manage-title').val();
            
            if (new_title.length > 0) feed.rename(new_title);
            this.hide_confirm_rename_menu_item(true);
        },
        
        manage_menu_rename_folder: function(folder, $folder) {
            var self      = this;
            var new_folder_name = $('.NB-menu-manage-folder-rename-confirm .NB-menu-manage-title').val();
            var folder_view = NEWSBLUR.assets.folders.get_view($folder) ||
                              this.active_folder.folder_view;
            
            if (new_folder_name.length > 0) folder_view.model.rename(new_folder_name);
            this.hide_confirm_rename_menu_item(true);
        },
        
        // =============================
        // = Manage Menu - Share Story =
        // =============================
        
        show_confirm_story_share_menu_item: function(story_id) {
            var self = this;
            if (!story_id) story_id = $('.NB-menu-manage').data('story_id');
            var story = NEWSBLUR.assets.get_story(story_id);
            var $share = $('.NB-menu-manage-story-share');
            var $confirm = $('.NB-menu-manage-story-share-confirm');
            var $story_share = story.story_share_menu_view.$el;
            var $position = $('.NB-menu-manage-confirm-position', $confirm);
            
            $share.addClass('NB-menu-manage-story-share-cancel');
            $('.NB-menu-manage-title', $share).text('Cancel share');
            $confirm.css({'height': 0, 'display': 'block'});
            story.story_share_menu_view.toggle_feed_story_share_dialog({immediate: true});
            $position.css('position', 'relative');
            var height = $story_share.height();
            $position.css('position', 'absolute');
            $confirm.css({'height': 0, 'display': 'block'}).animate({'height': height}, {
                'duration': 380, 
                'easing': 'easeOutQuart'
            });
            $('textarea', $confirm).focus().select();
            this.flags['showing_confirm_input_on_manage_menu'] = true;
        },
        
        hide_confirm_story_share_menu_item: function(shared) {
            var story_id = $('.NB-menu-manage-container .NB-menu-manage').data('story_id');
            var story = NEWSBLUR.assets.get_story(story_id);
            var $share = $('.NB-menu-manage-story-share');
            var $confirm = $('.NB-menu-manage-story-share-confirm');
            
            $share.removeClass('NB-menu-manage-story-share-cancel');
            var text = 'Share to your Blurblog';
            if (shared) {
                text = 'Shared';
                $share.addClass('NB-active');
            } else {
                $share.removeClass('NB-active');
            }
            $('.NB-menu-manage-title', $share).text(text);
            $confirm.slideUp(500, _.bind(function() {
                if (shared && story) {
                    this.hide_manage_menu('story', story.story_title_view.$el, true);
                }
            }, this));
            this.flags['showing_confirm_input_on_manage_menu'] = false;
            
        },
        
        // ==========================
        // = Taskbar - Intelligence =
        // ==========================
        
        load_intelligence_slider: function() {
            var self = this;
            var $slider = this.$s.$intelligence_slider;
            var unread_view = this.get_unread_view_score();
            
            if (unread_view == 0 && !NEWSBLUR.assets.preference('hide_read_feeds')) {
                unread_view = -1;
            }
            this.slide_intelligence_slider(unread_view, true);
        },
        
        toggle_focus_in_slider: function() {
            var $slider = this.$s.$intelligence_slider;
            var $focus = $(".NB-intelligence-slider-green", $slider);
            var $unread = $(".NB-intelligence-slider-yellow", $slider);
            var unread_view = this.get_unread_view_name();
            var all_mode = !NEWSBLUR.assets.preference('hide_read_feeds');
            var starred_mode = this.flags['feed_list_showing_starred'];
            if (!NEWSBLUR.assets.feeds.size()) return;
            
            var view_not_empty;
            if (unread_view == 'starred') {
                view_not_empty = NEWSBLUR.assets.starred_feeds.any(function(feed) { 
                    return feed.get('count');
                });
            } else if (unread_view == 'positive') {
                view_not_empty = NEWSBLUR.assets.feeds.any(function(feed) { 
                    return feed.get('ps');
                }) || NEWSBLUR.assets.social_feeds.any(function(feed) { 
                    return feed.get('ps');
                });
            } else {
                view_not_empty = NEWSBLUR.assets.feeds.any(function(feed) { 
                    return feed.get('ps') || feed.get('nt');
                }) || NEWSBLUR.assets.social_feeds.any(function(feed) { 
                    return feed.get('ps') || feed.get('nt');
                });                
            }
            $(".NB-feeds-list-empty").remove();
            // console.log(["toggle_focus_in_slider", unread_view, view_not_empty, starred_mode]);
            if (!view_not_empty && !all_mode && !starred_mode) {
                var $empty = $.make("div", { className: "NB-feeds-list-empty" }, [
                    'You have no unread stories',
                    unread_view == 'positive' ? " in Focus mode." : ".",
                    $.make('br'),
                    $.make('br'),
                    unread_view == 'positive' ? 'Switch to All or Unread.' : ""
                ]);
                this.$s.$feed_list.after($empty);
            } else if (!view_not_empty && starred_mode) {
                var $empty = $.make("div", { className: "NB-feeds-list-empty" }, [
                    'You have no saved stories.',
                    $.make('br'),
                    $.make('br'),
                    'Switch to All or Unread.'
                ]);
                this.$s.$feed_list.after($empty);
            }
            // $focus.css('display', show_focus ? 'block' : 'none');
            // if (!show_focus) {
            //     $unread.addClass("NB-last");
            //     if (NEWSBLUR.assets.preference('unread_view') > 0) {
            //         this.slide_intelligence_slider(0);
            //     }
            // } else {
            //     $unread.removeClass("NB-last");
            //     this.model.preference('lock_green_slider', true);
            // }
        },
        
        slide_intelligence_slider: function(value, initial_load) {
            var $slider = this.$s.$intelligence_slider;
            var real_value = value;
            
            var showing_starred = this.flags['feed_list_showing_starred'];
            this.flags['feed_list_showing_starred'] = value == 2;

            if (value <= -1) {
                value = 0;
                if (!initial_load) {
                    NEWSBLUR.assets.preference('hide_read_feeds', 0);
                }
                NEWSBLUR.assets.preference('unread_view', 0);
            } else if (value == 0) {
                if (!initial_load) {
                    NEWSBLUR.assets.preference('hide_read_feeds', 1);
                }
                NEWSBLUR.assets.preference('unread_view', 0);
            } else if (value >= 2) {
                if (!initial_load) {
                    NEWSBLUR.assets.preference('hide_read_feeds', 1);
                }
                NEWSBLUR.assets.preference('unread_view', 2);
            } else if (value > 0) {
                if (!initial_load) {
                    NEWSBLUR.assets.preference('hide_read_feeds', 1);
                }
                NEWSBLUR.assets.preference('unread_view', 1);
            }
            this.flags['unread_threshold_temporarily'] = null;
            this.switch_feed_view_unread_view(value);
            if (NEWSBLUR.app.story_titles_header) {
                NEWSBLUR.app.story_titles_header.show_feed_hidden_story_title_indicator(true);
            }
            this.show_story_titles_above_intelligence_level({'animate': true, 'follow': true});
            this.toggle_focus_in_slider();
            if (!initial_load && this.flags['feed_list_showing_starred'] != showing_starred) {
                this.reload_feed();
            }
            NEWSBLUR.app.sidebar_header.toggle_hide_read_preference();
            NEWSBLUR.app.sidebar_header.count();
            NEWSBLUR.assets.folders.update_all_folder_visibility();
            NEWSBLUR.app.feed_list.scroll_to_selected();
            
            $('.NB-active', $slider).removeClass('NB-active');
            if (this.flags['feed_list_showing_starred']) {
                $('.NB-intelligence-slider-blue', $slider).addClass('NB-active');
            } else if (real_value < 0) {
                $('.NB-intelligence-slider-red', $slider).addClass('NB-active');
            } else if (real_value > 0) {
                $('.NB-intelligence-slider-green', $slider).addClass('NB-active');
            } else {
                $('.NB-intelligence-slider-yellow', $slider).addClass('NB-active');
            }
        },
        
        move_intelligence_slider: function(direction) {
            var unread_view = this.model.preference('unread_view');
            if (!this.model.preference('hide_read_feeds')) unread_view = -1;
            var value = unread_view + direction;
            this.slide_intelligence_slider(value);
        },
        
        toggle_read_filter: function() {
            var read_filter = NEWSBLUR.assets.view_setting(this.active_feed, 'read_filter');
            var setting = {
                'read_filter': (read_filter == 'unread' ? 'all' : 'unread')
            };
            var changed = NEWSBLUR.assets.view_setting(this.active_feed, setting);
            if (!changed) return;
        
            NEWSBLUR.reader.reload_feed(setting);
        },
        
        switch_feed_view_unread_view: function(unread_view) {
            if (!_.isNumber(unread_view)) unread_view = this.get_unread_view_score();
            var $sidebar               = this.$s.$sidebar;
            var unread_view_name       = this.get_unread_view_name(unread_view);
            var $next_story_button     = $('.NB-task-story-next-unread');
            var $story_title_indicator = $('.NB-story-title-indicator', this.$story_titles);

            this.$s.$body.removeClass('NB-intelligence-positive')
                         .removeClass('NB-intelligence-neutral')
                         .removeClass('NB-intelligence-negative')
                         .removeClass('NB-intelligence-starred')
                         .addClass('NB-intelligence-'+unread_view_name);
                    
            $sidebar.removeClass('unread_view_positive')
                    .removeClass('unread_view_neutral')
                    .removeClass('unread_view_negative')
                    .removeClass('unread_view_starred')
                    .addClass('unread_view_'+unread_view_name);

            $next_story_button.removeClass('NB-task-story-next-positive')
                              .removeClass('NB-task-story-next-neutral')
                              .removeClass('NB-task-story-next-negative')
                              .removeClass('NB-task-story-next-starred')
                              .addClass('NB-task-story-next-'+unread_view_name);
                              
            $story_title_indicator.removeClass('unread_threshold_positive')
                                  .removeClass('unread_threshold_neutral')
                                  .removeClass('unread_threshold_negative')
                                  .removeClass('unread_threshold_starred')
                                  .addClass('unread_threshold_'+unread_view_name);
            
            NEWSBLUR.assets.stories.each(function(story){ 
                story.unset('visible'); 
            });
        },
        
        get_unread_view_score: function(ignore_temp) {
            if (this.flags['feed_list_showing_starred']) return -1;
            if (this.flags['unread_threshold_temporarily'] && !ignore_temp) {
                var score_name = this.flags['unread_threshold_temporarily'];
                if (score_name == 'neutral') {
                    return 0;
                } else if (score_name == 'negative') {
                    return -1;
                }
            }
            
            return this.model.preference('unread_view');
        },
        
        get_unread_view_name: function(unread_view, ignore_temp) {
            if (this.flags['unread_threshold_temporarily'] && !ignore_temp) {
                return this.flags['unread_threshold_temporarily'];
            }
            
            if (typeof unread_view == 'undefined' || unread_view === null) {
                unread_view = this.get_unread_view_score(ignore_temp);
            }
            
            if (this.flags['feed_list_showing_starred']) return 'starred';
            
            return (unread_view > 0
                    ? 'positive'
                    : unread_view < 0
                      ? 'negative'
                      : 'neutral');
        },
        
        get_unread_count: function(feed_id) {
            var total = 0;
            feed_id = feed_id || this.active_feed;
            var feed = this.model.get_feed(feed_id);
            
            if (_.contains(['starred', 'read'], feed_id)) {
                // Umm, no. Not yet.
            } else if (feed) {
                return feed.unread_counts();
            } else if (this.flags['river_view'] && !this.flags['social_view']) {
                var collection;
                if (!this.active_folder.folder_view) {
                    // River blurblog gets a special collection
                    collection = NEWSBLUR.assets.folders;
                } else {
                    collection = this.active_folder.folders;
                }
                return collection.unread_counts();
            } else if (this.flags['river_view'] && this.flags['social_view']) {
                return NEWSBLUR.assets.social_feeds.unread_counts();
            }
            
            return {};
        },
        
        get_total_unread_count: function(feed_id) {
            var counts = this.get_unread_count(feed_id);
            var unread_view_name = this.get_unread_view_name();

            if (unread_view_name == 'positive') {
                return counts['ps'];
            } else if (unread_view_name == 'neutral') {
                return counts['ps'] + counts['nt'];
            } else if (unread_view_name == 'negative') {
                return counts['ps'] + counts['nt'] + counts['ng'];
            } else if (unread_view_name == 'starred') {
                return counts['st'];
            }
        },
        
        show_story_titles_above_intelligence_level: function(opts) {
            var defaults = {
                'unread_view_name': null,
                'animate': true,
                'follow': false,
                'temporary': false
            };
            var options = $.extend({}, defaults, opts);
            var self = this;
            var $story_titles = this.$s.$story_titles;
            var unread_view_name = options['unread_view_name'] || this.get_unread_view_name();
            
            if (this.model.stories.length > 18) {
                options['animate'] = false;
            }
            
            if (this.flags['unread_threshold_temporarily']) {
                options['temporary'] = true;
            }
            
            NEWSBLUR.assets.stories.trigger('render:intelligence', options);
            
            if (!NEWSBLUR.assets.preference('feed_view_single_story')) {
                _.delay(function() {
                    NEWSBLUR.app.story_list.reset_story_positions();
                }, 500);
            }

            NEWSBLUR.app.story_list.show_correct_explainer();

            // NEWSBLUR.log(['Showing correct stories', this.story_view, unread_view_name, $stories_show.length, $stories_hide.length]);
            if (_.contains(['split', 'list', 'grid'],
                NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                NEWSBLUR.app.story_titles.fill_out();
            } else {
                NEWSBLUR.app.story_list.fill_out();
            }

            if (options.follow && this.active_story) {
                NEWSBLUR.app.story_list.scroll_to_selected_story(self.active_story);
                NEWSBLUR.app.story_titles.scroll_to_selected_story(self.active_story);
            }
        },
        
        // ===================
        // = Feed Refreshing =
        // ===================
        
        force_instafetch_stories: function(feed_id) {
            var self = this;
            feed_id = feed_id || this.active_feed;
            var feed = this.model.get_feed(feed_id);
            feed.set({
                fetched_once: false,
                has_exception: false
            });

            this.model.save_exception_retry(feed_id, _.bind(this.force_feed_refresh, this, feed_id),
                                            NEWSBLUR.app.taskbar_info.show_stories_error);
        },
        
        setup_socket_realtime_unread_counts: function(force) {
            if (!force && NEWSBLUR.Globals.is_anonymous) return;
            // if (!force && !NEWSBLUR.Globals.is_premium) return;
            if (this.socket && !this.socket.socket.connected) {
                this.socket.socket.connect();
            } else if (force || !this.socket || !this.socket.socket.connected) {
                var server = window.location.protocol + '//' + window.location.hostname;
                var https = _.string.startsWith(window.location.protocol, 'https');
                var local = NEWSBLUR.Globals.debug || _.any([], function(hostname) {
                    return _.string.contains(window.location.host, hostname);
                });
                var port = https ? 443 : 80;
                if (local) {
                    port = https ? 8889 : 8888;
                }
                this.socket = this.socket || io.connect(server, {
                    "reconnection delay": 2000,
                    "connect timeout": 2000,
                    "port": port
                });
                
                // this.socket.refresh_feeds = _.debounce(_.bind(this.force_feeds_refresh, this), 1000*10);
                this.socket.on('connect', _.bind(function() {
                    var active_feeds = this.send_socket_active_feeds();
                    // NEWSBLUR.log(["Connected to real-time pubsub with " + active_feeds.length + " feeds."]);
                    this.flags.feed_refreshing_in_realtime = true;
                    this.setup_feed_refresh();
                    
                    // $('.NB-module-content-account-realtime-subtitle').html($.make('b', 'Updating in real-time'));
                    $('.NB-module-content-account-realtime').attr('title', 'Updating sites in real-time...').removeClass('NB-error').addClass('NB-active');
                    this.apply_tipsy_titles();
                }, this));

                this.socket.removeAllListeners('feed:update');
                this.socket.on('feed:update', _.bind(function(feed_id, message) {
                    NEWSBLUR.log(['Real-time feed update', feed_id, message]);
                    this.feed_unread_count(feed_id, {realtime: true});
                }, this));
                
                this.socket.removeAllListeners(NEWSBLUR.Globals.username);
                this.socket.on('user:update', _.bind(function(username, message) {
                    if (this.flags.social_view) return;
                    if (_.string.startsWith(message, 'feed:')) {
                        feed_id = parseInt(message.replace('feed:', ''), 10);
                        var active_feed_ids = [];
                        if (this.active_folder && this.active_folder.length) {
                            active_feed_ids = this.active_folder.feed_ids_in_folder();
                        }
                        if (feed_id != this.active_feed && 
                            !_.contains(active_feed_ids, feed_id)) {
                            NEWSBLUR.log(['Real-time user update', username, feed_id]);
                            this.feed_unread_count(feed_id);
                        }
                    } else if (_.string.startsWith(message, 'social:')) {
                        if (message != this.active_feed) {
                            NEWSBLUR.log(['Real-time user update', username, message]);
                            this.feed_unread_count(message);
                        }
                    } else if (message == "interaction:new") {
                        this.update_interactions_count();
                    } else if (_.string.startsWith(message, "search_index_complete:")) {
                        message = message.replace('search_index_complete:', '');
                        if (NEWSBLUR.app.active_search) {
                            NEWSBLUR.app.active_search.update_indexing_progress(message);
                        }
                    } else if (_.string.startsWith(message, "refresh:")) {
                        var feeds = message.replace('refresh:', '').split(",");
                        this.force_feeds_refresh(null, false, feeds);
                    } else if (_.string.startsWith(message, "reload:")) {
                        if (!NEWSBLUR.reader.flags['reloading_feeds']) {
                            console.log(["Reloading feeds due to server reload", NEWSBLUR.reader.flags['reloading_feeds']]);
                            NEWSBLUR.assets.load_feeds();
                        }
                    }
                }, this));

                
                this.socket.on('disconnect', _.bind(function() {
                    NEWSBLUR.log(["Lost connection to real-time pubsub. Falling back to polling."]);
                    this.flags.feed_refreshing_in_realtime = false;
                    this.setup_feed_refresh();
                    // $('.NB-module-content-account-realtime-subtitle').html($.make('b', 'Updating every 60 sec'));
                    $('.NB-module-content-account-realtime').attr('title', 'Updating sites every ' + this.flags.refresh_interval + ' seconds...').addClass('NB-error').removeClass('NB-active');
                    this.apply_tipsy_titles();
                }, this));
                this.socket.on('error', _.bind(function() {
                    NEWSBLUR.log(["Can't connect to real-time pubsub."]);
                    this.flags.feed_refreshing_in_realtime = false;
                    this.setup_feed_refresh();
                    // $('.NB-module-content-account-realtime-subtitle').html($.make('b', 'Updating every 60 sec'));
                    $('.NB-module-content-account-realtime').attr('title', 'Updating sites every ' + this.flags.refresh_interval + ' seconds...').addClass('NB-error').removeClass('NB-active');
                    this.apply_tipsy_titles();
                    _.delay(_.bind(this.setup_socket_realtime_unread_counts, this), 60*1000);
                }, this));
                this.socket.on('reconnect_failed', _.bind(function() {
                    console.log(["Socket.io reconnect failed"]);
                }, this));
                this.socket.on('reconnect', _.bind(function() {
                    console.log(["Socket.io reconnected successfully!"]);
                }, this));
                this.socket.on('reconnecting', _.bind(function() {
                    console.log(["Socket.io reconnecting..."]);
                }, this));
            }
            
        },
        
        send_socket_active_feeds: function() {
            if (!this.socket) return;
            
            var active_feeds = _.compact(this.model.feeds.map(function(feed) { 
                return feed.get('active') && feed.id;
            }));
            active_feeds = active_feeds.concat(this.model.social_feeds.pluck('id'));
            
            if (active_feeds.length) {
                this.socket.emit('subscribe:feeds', active_feeds, NEWSBLUR.Globals.username);
            }

            return active_feeds;
        },
        
        setup_feed_refresh: function(new_feeds) {
            var self = this;
            var refresh_interval = this.constants.FEED_REFRESH_INTERVAL;
            var feed_count = this.model.feeds.size();
            
            if (!NEWSBLUR.Globals.is_premium) {
                refresh_interval *= 2;
            }
            if (feed_count > 250) {
                refresh_interval *= 2;
            }
            if (feed_count > 500) {
                refresh_interval *= 1.5;
            }
            if (this.flags['feed_refreshing_in_realtime'] && !this.flags['has_unfetched_feeds'] &&
                this.socket && this.socket.socket.connected) {
                refresh_interval *= 10;
            }

            if (new_feeds && feed_count < 250) {
                refresh_interval = (1000 * 60) * 1/6;
            } else if (new_feeds && feed_count < 500) {
                refresh_interval = (1000 * 60) * 1/4;
            }
            
            // 10 second minimum
            refresh_interval = Math.max(10*1000, refresh_interval);
            
            // Add 0-100% random delay
            refresh_interval = parseInt(refresh_interval * (1 + Math.random()), 10);
            
            clearInterval(this.flags.feed_refresh);
            
            this.flags.feed_refresh = setInterval(function() {
                if (!self.flags['pause_feed_refreshing']) {
                    self.force_feeds_refresh();
                }
            }, refresh_interval);
            this.flags.refresh_interval = parseInt(refresh_interval / 1000, 10);
            if (!this.socket || !this.socket.socket.connected) {
                $('.NB-module-content-account-realtime').attr('title', 'Updating sites every ' + this.flags.refresh_interval + ' seconds...').addClass('NB-error');
                this.apply_tipsy_titles();
            } 
            NEWSBLUR.log(["Setting refresh interval to every " + this.flags.refresh_interval + " seconds."]);
            if (this.socket && !this.socket.socket.connected && !this.socket.socket.connecting) {
                // force disconnected since it's probably in a bad reconnect state.
                console.log(["Forcing socket disconnection...", this.socket.socket]);
                this.socket.socket.disconnect();
            }
        },
        
        force_feed_refresh: function(feed_id, new_feed_id) {
            var self = this;
            feed_id  = feed_id || this.active_feed;
            new_feed_id = _.isNumber(new_feed_id) && new_feed_id || feed_id;
            console.log(["force_feed_refresh", feed_id, new_feed_id]);
            this.force_feeds_refresh(function() {
                // Open the feed back up if it is being refreshed and is still open.
                if (self.active_feed == feed_id || self.active_feed == new_feed_id) {
                    self.open_feed(new_feed_id, {force: true});
                }
                
                self.check_feed_fetch_progress();
            }, true, new_feed_id, NEWSBLUR.app.taskbar_info.show_stories_error);
        },
        
        force_feeds_refresh: function(callback, replace_active_feed, feed_id, error_callback) {
            if (callback) {
                this.cache.refresh_callback = callback;
            } else {
                delete this.cache.refresh_callback;
            }

            this.flags['pause_feed_refreshing'] = true;
            this.model.refresh_feeds(_.bind(function(data) {
                this.post_feed_refresh(data);
            }, this), this.flags['has_unfetched_feeds'], feed_id, error_callback);
        },
        
        post_feed_refresh: function(data) {
            var feeds = this.model.feeds;
            
            if (this.cache.refresh_callback && $.isFunction(this.cache.refresh_callback)) {
                this.cache.refresh_callback(feeds);
                delete this.cache.refresh_callback;
            }
            
            NEWSBLUR.app.sidebar_header.update_interactions_count(data.interactions_count);

            this.flags['refresh_inline_feed_delay'] = false;
            this.flags['pause_feed_refreshing'] = false;
            this.check_feed_fetch_progress();
            this.toggle_focus_in_slider();
        },
        
        feed_unread_count: function(feed_id, options) {
            options = options || {};
            feed_id = feed_id || this.active_feed;
            if (!feed_id) return;
            
            var feed = this.model.get_feed(feed_id);
            var subs = feed.get('num_subscribers');
            var delay = options.realtime ? subs * 2 : 0; // 1,000 subs = 2 seconds
            
            _.delay(_.bind(function() {
                this.model.feed_unread_count(feed_id, options.callback);
            }, this), Math.random() * delay);
        },
        
        feeds_unread_count: function(feed_ids, options) {
            options = options || {};
            
            this.model.feed_unread_count(feed_ids, options.callback);
        },
        
        update_interactions_count: function() {
            this.model.interactions_count(function(data) {
                NEWSBLUR.app.sidebar_header.update_interactions_count(data.interactions_count);
            }, $.noop);
        },
        
        // ===================
        // = Mouse Indicator =
        // ===================

        setup_mousemove_on_views: function() {
            this.hide_mouse_indicator();
            
            if (this.story_view == 'story' ||
                this.story_view == 'text' ||
                this.flags['feed_view_showing_story_view'] ||
                this.flags['temporary_story_view']) {
                this.hide_mouse_indicator();
            } else {
                _.delay(_.bind(this.show_mouse_indicator, this), 350);
            }
        },
        
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

            if (NEWSBLUR.assets.preference('feed_view_single_story')) return;

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
                if (self.model.preference('lock_mouse_indicator')) {
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
            
            if (self.model.preference('lock_mouse_indicator')) {
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
            if (!_.contains(['split', 'full'], 
                NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) return;
            
            var position = this.model.preference('lock_mouse_indicator');
            var container = this.layout.contentLayout.state.container.innerHeight - 30;

            if (position <= 0 || position > container) {
                position = 20; // Start with a 20 offset
            } else {
                position = position - 8; // Compensate for mouse indicator height.
            }

            this.$s.$mouse_indicator.css('top', position);
            // console.log(["position_mouse_indicator", NEWSBLUR.reader.cache.mouse_position_y, position]);
            this.cache.mouse_position_y = position;
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
            
            if (direction == -1 && this.counts['feature_page'] <= 0) {
                $module.removeClass('NB-loading');
                this.counts['feature_page'] = 0;
                return;
            }
            if (direction == 1 && this.flags['features_last_page']) {
                $module.removeClass('NB-loading');
                return;
            }
            
            this.model.get_features_page(this.counts['feature_page']+direction, function(features) {
                $module.removeClass('NB-loading');

                if (!features) return;
                
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
                
            }, function() {
                $module.removeClass('NB-loading');
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
        
        setup_ftux_add_feed_callout: function(message) {
            var self = this;
            if (this.flags['bouncing_callout']) return;
            
            $('.NB-callout-ftux .NB-callout-text').text(message || 'First things first...');
            $('.NB-callout-ftux').corner('5px');
            $('.NB-callout-ftux').css({
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
                }, 1000);
            });
        },
        
        setup_ftux_signup_callout: function() {
            var self = this;
            
            if (!this.flags['bouncing_callout']) {
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
        
        post_google_reader_connect: function(data) {
            if (NEWSBLUR.intro) {
                NEWSBLUR.intro.start_import_from_google_reader(data);
            } else {
                this.start_import_from_google_reader();
            }
        },
        
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
            
            this.animate_progress_bar($bar, 5);
            
            this.model.start_import_from_google_reader(
                $.rescope(this.finish_import_from_google_reader, this));
            this.show_progress_bar();
        },

        finish_import_from_google_reader: function(e, data) {
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            this.flags['import_from_google_reader_working'] = false;
            clearTimeout(this.locks['animate_progress_bar']);
            
            if (data.code >= 1) {
                $bar.progressbar({value: 100});
                NEWSBLUR.assets.load_feeds();
                $('.NB-progress-title', $progress).text('');
                $('.NB-progress-link', $progress).html('');
            } else {
                NEWSBLUR.log(['Import Error!', data]);
                this.$s.$feed_link_loader.fadeOut(250);
                $progress.addClass('NB-progress-error');
                $('.NB-progress-title', $progress).text('Error importing Google Reader');
                $('.NB-progress-link', $progress).html($.make('a', { 
                    className: 'NB-modal-submit-button NB-modal-submit-green',
                    href: NEWSBLUR.URLs['google-reader-authorize']
                }, ['Try importing again']));
                $('.left-center-footer').css('height', 'auto');
            }
        },

        start_count_unreads_after_import: function() {
            var self = this;
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            var percentage = 0;
            var feeds_count = _.keys(this.model.feeds).length;
            
            if (!this.flags['pause_feed_refreshing'] || this.flags['has_unfetched_feeds']) return;
            
            this.flags['count_unreads_after_import_working'] = true;
            
            $('.NB-progress-title', $progress).text('Counting is difficult');
            $('.NB-progress-counts', $progress).hide();
            $('.NB-progress-percentage', $progress).hide();
            $bar.progressbar({
                value: percentage
            });
            
            setTimeout(function() {
                if (self.flags['count_unreads_after_import_working']) {
                    self.animate_progress_bar($bar, feeds_count / 30);
                    self.show_progress_bar();
                }
            }, 500);
        },

        finish_count_unreads_after_import: function(data) {
            data = data || {};
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
          // Reload recommended feeds every 60 minutes.
          clearInterval(this.locks.load_recommended_feed);
          this.locks.load_recommended_feed = setInterval(_.bind(function() {
              this.load_recommended_feed(0, true);
          }, this), 60*60*1000);
        },
        
        load_feed_in_tryfeed_view: function(feed_id, options) {
            options = options || {};
            feed = _.extend({
                id           : feed_id,
                feed_id      : feed_id,
                feed_title   : options.feed && options.feed.feed_title,
                temp         : true
            }, options.feed && options.feed.attributes);
            var $tryfeed_container = this.$s.$tryfeed_header.closest('.NB-feeds-header-container');

            this.reset_feed(options);
            feed = this.model.set_feed(feed_id, feed);

            $('.NB-feeds-header-title', this.$s.$tryfeed_header).text(feed.get('feed_title'));
            $('.NB-feeds-header-icon',  this.$s.$tryfeed_header).attr('src', $.favicon(feed));

            $tryfeed_container.slideDown(350, _.bind(function() {
                options.force = true;
                options.try_feed = true;
                this.open_feed(feed_id, options);
                this.flags['showing_feed_in_tryfeed_view'] = true;
                this.$s.$tryfeed_header.addClass('NB-selected');
            }, this));
        },
        
        load_social_feed_in_tryfeed_view: function(social_feed, options) {
            options = options || {};
            if (_.isNumber(social_feed)) {
                social_feed = this.model.get_feed('social:' + social_feed);
            } else if (_.isString(social_feed)) {
                social_feed = this.model.get_feed(social_feed);
            }

            if (!social_feed) {
                social_feed = this.model.add_social_feed(options.feed);
            }
            
            var $tryfeed_container = this.$s.$tryfeed_header.closest('.NB-feeds-header-container');

            this.reset_feed();
            
            $('.NB-feeds-header-title', this.$s.$tryfeed_header).text(social_feed.get('username'));
            $('.NB-feeds-header-icon',  this.$s.$tryfeed_header).attr('src', $.favicon(social_feed));

            $tryfeed_container.slideDown(350, _.bind(function() {
                this.open_social_stories(social_feed.get('id'), options);
                this.switch_taskbar_view('feed');
                this.switch_story_layout();
                this.flags['showing_social_feed_in_tryfeed_view'] = true;
                this.$s.$tryfeed_header.addClass('NB-selected');
            }, this));
        },
        
        hide_tryfeed_view: function() {
            var $tryfeed_container = this.$s.$tryfeed_header.closest('.NB-feeds-header-container');
            $tryfeed_container.slideUp(350);
            this.$s.$story_taskbar.find('.NB-tryfeed-add').remove();
            this.$s.$story_taskbar.find('.NB-tryfeed-follow').remove();
            this.flags['showing_feed_in_tryfeed_view'] = false;
            this.flags['showing_social_feed_in_tryfeed_view'] = false;
        },
        
        show_tryfeed_add_button: function() {
            if (this.$s.$story_taskbar.find('.NB-tryfeed-add:visible').length) return;
            
            var $add = $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-tryfeed-add NB-modal-submit-green NB-modal-submit-button' }, 'Subscribe')
            ]).css({'opacity': 0});
            this.$s.$story_taskbar.append($add);
            $add.animate({'opacity': 1}, {'duration': 600});
        },
        
        correct_tryfeed_title: function() {
            var feed = this.model.get_feed(this.active_feed);
            $('.NB-feeds-header-title', this.$s.$tryfeed_header).text(feed.get('feed_title'));
            this.make_feed_title_in_stories();
        },
        
        show_tryfeed_follow_button: function() {
            if (this.$s.$story_taskbar.find('.NB-tryfeed-follow:visible').length) return;
            
            var $add = $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-tryfeed-follow NB-modal-submit-green NB-modal-submit-button' }, 'Follow')
            ]).css({'opacity': 0});
            this.$s.$story_taskbar.append($add);
            $add.animate({'opacity': 1}, {'duration': 600});
        },
        
        show_tryout_signup_button: function() {
            if (this.$s.$story_taskbar.find('.NB-tryout-signup:visible').length) return;
            
            var $add = $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-tryout-signup NB-modal-submit-green NB-modal-submit-button' }, 'Sign Up')
            ]).css({'opacity': 0});
            this.$s.$story_taskbar.append($add);
            $add.animate({'opacity': 1}, {'duration': 600});
        },
        
        hide_tryout_signup_button: function() {
            this.$s.$story_taskbar.find('.NB-tryout-signup:visible').remove();
        },
        
        add_recommended_feed: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            var feed_address = this.model.get_feed(feed_id).get('feed_address');
            
            this.open_add_feed_modal({url: feed_address});
        },
        
        follow_user_in_tryfeed: function(feed_id) {
            var self = this;
            var socialsub = this.model.get_feed(feed_id);
            this.model.follow_user(socialsub.get('user_id'), function(data) {
                NEWSBLUR.app.feed_list.make_social_feeds();
                self.open_social_stories(feed_id);
            });
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
            
            if (!refresh) {
                $module.addClass('NB-loading');
            }
            direction = direction || 0;
            
            this.model.load_recommended_feed(this.counts['recommended_feed_page']+direction, 
                                             !!refresh, unmoderated, function(resp) {
                $module.removeClass('NB-loading');
                if (!resp) return;
                $module.replaceWith(resp);
                self.counts['recommended_feed_page'] += direction;
                self.load_javascript_elements_on_page();
            }, function() {
                $module.removeClass('NB-loading');
            });
        },
        
        // ====================
        // = Dashboard Graphs =
        // ====================
        
        setup_dashboard_graphs: function() {
            if (NEWSBLUR.Globals.debug) return;
            
            // Reload dashboard graphs every 10 minutes.
            var reload_interval = NEWSBLUR.Globals.is_staff ? 60*1000 : 10*60*1000;

            clearInterval(this.locks.load_dashboard_graphs);
            this.locks.load_dashboard_graphs = setInterval(_.bind(function() {
                this.load_dashboard_graphs();
            }, this), reload_interval * (Math.random() * (1.25 - 0.75) + 0.75));
        },
        
        load_dashboard_graphs: function() {
            var self = this;
            var $module = $('.NB-module-site-stats');
            $module.addClass('NB-loading');
            
            this.model.load_dashboard_graphs(function(resp) {
                $module.removeClass('NB-loading');
                if (!resp) return;
                $module.replaceWith(resp);
                self.load_javascript_elements_on_page();
            }, function() {
                $module.removeClass('NB-loading');
            });
        },
        
        
        setup_feedback_table: function() {
            if (NEWSBLUR.Globals.debug) return;
            
            // Reload feedback module every 10 minutes.
            var reload_interval = NEWSBLUR.Globals.is_staff ? 30*1000 : 5*60*1000;
            clearInterval(this.locks.load_feedback_table);
            this.locks.load_feedback_table = setInterval(_.bind(function() {
                this.load_feedback_table();
                this.load_feature_page(0);
            }, this), reload_interval * (Math.random() * (1.25 - 0.75) + 0.75));
        },
        
        load_feedback_table: function() {
            var self = this;
            var $module = $('.NB-feedback-table');
            $module.addClass('NB-loading');
            
            this.model.load_feedback_table(function(resp) {
                $module.removeClass('NB-loading');
                if (!resp) return;
                $module.replaceWith(resp);
                self.load_javascript_elements_on_page();
            }, function() {
                $module.removeClass('NB-loading');
            });
        },
        
        // ===================
        // = Unfetched Feeds =
        // ===================
        
        setup_unfetched_feed_check: function() {
            this.locks.unfetched_feed_check = setInterval(_.bind(function() {
                var unfetched_feeds = NEWSBLUR.assets.unfetched_feeds();
                if (unfetched_feeds.length) {
                    this.force_instafetch_stories(unfetched_feeds[0].id);
                }
            }, this), 60*1*1000);
        },
        
        // ==========
        // = Events =
        // ==========

        handle_clicks: function(elem, e) {
            var self = this;
            var stopPropagation = false;
            
            // NEWSBLUR.log(['click', e, e.button]);            
            
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
            $.targetIs(e, { tagSelector: '.NB-module-account-settings' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.show_manage_menu('site', $t, {inverse: true});
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-modal-title' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var $item = $(".NB-icon", $t);
                    if ($item.length) {
                        self.show_manage_menu('site', $item, {inverse: true, right: true, body: true});
                    }
                }
            });  
            
            // = Context Menu ================================================
            
            $.targetIs(e, { tagSelector: '.NB-menu-manage-open-input' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                self.flags['showing_confirm_input_on_manage_menu'] = true;
                $t.select().blur(function() {
                    self.flags['showing_confirm_input_on_manage_menu'] = false;
                });
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-train' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                    self.open_feed_intelligence_modal(1, feed_id, false);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-train' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                    var story_id = $t.parents('.NB-menu-manage').data('story_id');
                    self.open_story_trainer(story_id, feed_id);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-recommend' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                self.open_recommend_modal(feed_id);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-mark-read-newer' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var story_id = $t.closest('.NB-menu-manage').data('story_id');
                    var story = NEWSBLUR.assets.get_story(story_id);
                    var timestamp = story.get('story_timestamp');
                    
                    if (self.flags.river_view && !self.flags.social_view) {
                        self.mark_folder_as_read(self.active_folder, timestamp, 'newer');
                    } else {
                        self.mark_feed_as_read(self.active_feed, timestamp, 'newer');
                    }
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-mark-read-older' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var story_id = $t.closest('.NB-menu-manage').data('story_id');
                    var story = NEWSBLUR.assets.get_story(story_id);
                    var timestamp = story.get('story_timestamp');
                    
                    if (self.flags.river_view && !self.flags.social_view) {
                        self.mark_folder_as_read(self.active_folder, timestamp, 'older');
                    } else {
                        self.mark_feed_as_read(self.active_feed, timestamp, 'older');
                    }
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-trainer' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_trainer_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-tutorial' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_tutorial_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-intro' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_intro_modal({page_number: 1});
                    });
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-settings' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.parents('.NB-menu-manage').data('feed_id');                    
                    self.open_feed_exception_modal(feed_id);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-settings' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var folder_title = $t.parents('.NB-menu-manage').data('folder_name');
                    var $folder = $t.parents('.NB-menu-manage').data('$folder');

                    self.open_feed_exception_modal(folder_title, {
                        folder_title: folder_title, 
                        $folder: $folder
                    });
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
                } else if ($t.hasClass('NB-menu-manage-feed-delete') ||
                           $t.hasClass('NB-menu-manage-folder-delete')) {
                    self.show_confirm_delete_menu_item();
                } else if ($t.hasClass('NB-menu-manage-socialfeed-delete-cancel')) {
                    self.hide_confirm_unfollow_menu_item();
                } else if ($t.hasClass('NB-menu-manage-socialfeed-delete')) {
                    self.show_confirm_unfollow_menu_item();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-delete-confirm' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                self.manage_menu_delete_feed(feed_id, $feed);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-socialfeed-delete-confirm' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                self.manage_menu_unfollow_feed(feed_id, $feed);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-delete-confirm' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.manage_menu_delete_folder(folder_name, $folder);
            });  
            var adding_icon = false;
            $.targetIs(e, { tagSelector: '.NB-icon-add', childOf: '.NB-menu-manage' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                adding_icon = true;
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $folder = $t.parents('.NB-folder-option');
                var folder = $folder.data('folder');
                self.show_add_folder_in_menu(feed_id, $folder, folder || '');
            });  
            $.targetIs(e, { tagSelector: '.NB-folder-option', childOf: '.NB-menu-manage' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                if (adding_icon) return;
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                self.switch_change_folder(feed_id, $t.data('folder') || '');
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-add-folder-save' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                
                self.add_folder_to_folder();
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-move-save' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.manage_menu_move_folder(folder_name, $folder);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-move-save' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                if ($t.hasClass('NB-disabled')) return;

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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-controls' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage-mute' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                self.manage_menu_mute_feed($t.parents('.NB-menu-manage').data('feed_id'), false);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-unmute' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                self.manage_menu_mute_feed($t.parents('.NB-menu-manage').data('feed_id'), true);
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-share' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                var story_id = $t.parents('.NB-menu-manage').data('story_id');
                if ($t.hasClass('NB-menu-manage-story-share-cancel')) {
                    self.hide_confirm_story_share_menu_item(story_id);
                } else {
                    self.show_confirm_story_share_menu_item(story_id);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-share-confirm' }, function($t, $p){
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
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                var folder_view = NEWSBLUR.assets.folders.get_view($folder) || 
                                  self.active_folder.folder_view;
                self.mark_folder_as_read(folder_view.model);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-subscribe' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.open_add_feed_modal({folder_title: folder_name});
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-subfolder' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.open_add_feed_modal({folder_title: folder_name, init_folder: true});
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-open' }, function($t, $p){
                e.preventDefault();
                if (!self.flags['showing_confirm_input_on_manage_menu']) {
                    var story_id = $t.closest('.NB-menu-manage-story').data('story_id');
                    var story = self.model.get_story(story_id);
                    story.open_story_in_new_tab(true);
                }
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-star' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-menu-manage-story').data('story_id');
                var story = NEWSBLUR.assets.get_story(story_id);
                story.toggle_starred();
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-exception' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');                    
                self.open_feed_exception_modal(feed_id);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-site-mark-read' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_mark_read_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-social-profile' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                $.modal.close(function() {
                    self.open_social_profile_modal(feed_id);
                });
            });  

            $.targetIs(e, { tagSelector: '.NB-menu-manage-keyboard' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_keyboard_shortcuts_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-goodies' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_goodies_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-newsletters' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_newsletters_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-import' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        NEWSBLUR.reader.open_intro_modal({
                            'page_number': 2,
                            'force_import': true
                        });
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-friends' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_friends_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-profile-editor' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_profile_editor_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-preferences' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_preferences_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-logout' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                
                if (!$t.hasClass('NB-disabled')) {
                    self.logout();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-account' }, function($t, $p){
                e.preventDefault();
                
                if (!$t.hasClass('NB-disabled') && !$($t.context).hasClass('NB-menu-manage-logout')) {
                    $.modal.close(function() {
                        self.open_account_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feedchooser' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_feedchooser_modal({
                            'chooser_only': NEWSBLUR.Globals.is_premium
                        });
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-organizer' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_organizer_modal();
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-premium' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    $.modal.close(function() {
                        self.open_feedchooser_modal({'premium_only': true});
                    });
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-account-upgrade' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_feedchooser_modal({'premium_only': true});
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-account-train' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_trainer_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-friends-button' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_friends_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-launch-tutorial' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_tutorial_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-launch-intro' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_intro_modal({page_number: 2});
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-premium-button' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_feedchooser_modal({'premium_only': true});
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-gettingstarted-hide' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.check_hide_getting_started(true);
                }
            });  
            
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-unread' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-menu-manage').data('story_id');
                var story = self.model.get_story(story_id);
                NEWSBLUR.assets.stories.mark_unread(story);
            });  
            
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-read' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-menu-manage').data('story_id');
                var story = self.model.get_story(story_id);
                NEWSBLUR.assets.stories.mark_read(story);
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
            $.targetIs(e, { tagSelector: '.task_view_text' }, function($t, $p){
                e.preventDefault();
                self.switch_taskbar_view('text');
            });
            $.targetIs(e, { tagSelector: '.NB-task-return' }, function($t, $p){
                e.preventDefault();
                NEWSBLUR.app.original_tab_view.load_feed_iframe();
            });         
            $.targetIs(e, { tagSelector: '.NB-taskbar-button.NB-task-story-next-unread' }, function($t, $p){
                e.preventDefault();
                self.open_next_unread_story_across_feeds();
            }); 
            $.targetIs(e, { tagSelector: '.NB-taskbar-button.NB-task-story-next' }, function($t, $p){
                e.preventDefault();
                self.show_next_story(1);
            }); 
            $.targetIs(e, { tagSelector: '.NB-taskbar-button.NB-task-story-previous' }, function($t, $p){
                e.preventDefault();
                self.show_next_story(-1);
            }); 
            $.targetIs(e, { tagSelector: '.NB-taskbar-button.NB-task-layout-full' }, function($t, $p){
                e.preventDefault();
                self.switch_story_layout('full');
            }); 
            $.targetIs(e, { tagSelector: '.NB-taskbar-button.NB-task-layout-split' }, function($t, $p){
                e.preventDefault();
                self.switch_story_layout('split');
            }); 
            $.targetIs(e, { tagSelector: '.NB-taskbar-button.NB-task-layout-list' }, function($t, $p){
                e.preventDefault();
                self.switch_story_layout('list');
            }); 
            $.targetIs(e, { tagSelector: '.NB-taskbar-button.NB-task-layout-grid' }, function($t, $p){
                e.preventDefault();
                self.switch_story_layout('grid');
            }); 
            $.targetIs(e, { tagSelector: '.NB-taskbar-options' }, function($t, $p){
                e.preventDefault();
                self.open_story_options_popover();
            }); 
            $.targetIs(e, { tagSelector: '.NB-intelligence-slider-control' }, function($t, $p){
                e.preventDefault();
                var unread_value;
                if ($t.hasClass('NB-intelligence-slider-red')) {
                    unread_value = -1;
                } else if ($t.hasClass('NB-intelligence-slider-yellow')) {
                    unread_value = 0;
                } else if ($t.hasClass('NB-intelligence-slider-green')) {
                    unread_value = 1;
                } else if ($t.hasClass('NB-intelligence-slider-blue')) {
                    unread_value = 2;
                }
                
                self.slide_intelligence_slider(unread_value);
            }); 
            
            // =====================
            // = Recommended Feeds =
            // =====================
            
            $.targetIs(e, { tagSelector: '.NB-recommended-statistics' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').data('feed-id');
                $('.NB-module-recommended').addClass('NB-loading');
                self.model.load_canonical_feed(feed_id, function() {
                    $('.NB-module-recommended').removeClass('NB-loading');
                    self.open_feed_statistics_modal(feed_id);
                });
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-intelligence' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').data('feed-id');
                $('.NB-module-recommended').addClass('NB-loading');
                self.model.load_canonical_feed(feed_id, function() {
                    $('.NB-module-recommended').removeClass('NB-loading');
                    self.open_feed_intelligence_modal(1, feed_id);
                });
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-try' }, function($t, $p){
                e.preventDefault();
                var $recommended_feeds = $('.NB-module-recommended');
                var feed_id = $t.closest('.NB-recommended').data('feed-id');
                self.open_feed(feed_id, {'feed': new NEWSBLUR.Models.Feed({
                    'feed_title': $('.NB-recommended-title', $recommended_feeds).text(),
                    'favicon_url': $('.NB-recommended-favicon', $recommended_feeds).attr('src'),
                    'temp': true
                })});
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-add' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').data('feed-id');
                $('.NB-module-recommended').addClass('NB-loading');
                self.model.load_canonical_feed(feed_id, function() {
                    $('.NB-module-recommended').removeClass('NB-loading');
                    self.add_recommended_feed(feed_id);
                });
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-decline' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').data('feed-id');
                self.decline_feed_in_moderation_queue(feed_id);
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-recommended-approve' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-recommended').data('feed-id');
                self.approve_feed_in_moderation_queue(feed_id);
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-module-recommended .NB-module-next-page' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var unmoderated = $t.closest('.NB-module-recommended').hasClass('NB-recommended-unmoderated');
                    self.load_recommended_feed(1, false, unmoderated);
                }
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-module-recommended .NB-module-previous-page' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var unmoderated = $t.closest('.NB-module-recommended').hasClass('NB-recommended-unmoderated');
                    self.load_recommended_feed(-1, false, unmoderated);
                }
            }); 
            
            $.targetIs(e, { tagSelector: '.NB-tryfeed-add' }, function($t, $p){
                e.preventDefault();
                var feed_id = self.active_feed;
                self.add_recommended_feed(feed_id);
            }); 
            $.targetIs(e, { tagSelector: '.NB-tryfeed-follow' }, function($t, $p){
                e.preventDefault();
                var feed_id = self.active_feed;
                self.follow_user_in_tryfeed(feed_id);
            }); 
            $.targetIs(e, { tagSelector: '.NB-tryout-signup' }, function($t, $p){
                e.preventDefault();
                self.show_splash_page();
                if (NEWSBLUR.welcome) {
                    NEWSBLUR.welcome.show_signin_form();
                }
            }); 
            
            // = Interactions Module ==========================================
            
            $.targetIs(e, { tagSelector: '.NB-interaction-follow, .NB-activity-follow' }, function($t, $p){
                e.preventDefault();
                var user_id = $t.data('userId');
                var username = $t.closest('.NB-interaction').find('.NB-interaction-username').text();
                
                self.close_interactions_popover();
                self.model.add_user_profiles([{user_id: user_id, username: username}]);
                self.open_social_profile_modal(user_id);
            }); 
            $.targetIs(e, { tagSelector: '.NB-interaction-comment_reply, .NB-interaction-reply_reply, .NB-interaction-story_reshare, .NB-interaction-comment_like, .NB-activity-comment_reply, .NB-activity-comment_like, .NB-activity-sharedstory' }, function($t, $p){
                e.preventDefault();
                var $interaction = $t.closest('.NB-interaction');
                var feed_id = $interaction.data('feedId');
                var story_id = $interaction.data('contentId');
                var user_id = $interaction.data('userId');
                var username = $interaction.data('username');

                self.close_interactions_popover();
                self.close_social_profile();
                if (self.model.get_feed(feed_id)) {
                    self.open_social_stories(feed_id, {'story_id': story_id});
                } else {
                    var comment_user_matches = feed_id.match(/social:(\d+)/, '$1');
                    if (comment_user_matches) user_id = parseInt(comment_user_matches[1], 10);
                    var socialsub = self.model.add_social_feed({
                        id: feed_id, 
                        user_id: user_id, 
                        username: username
                    });
                    self.load_social_feed_in_tryfeed_view(socialsub, {'story_id': story_id});
                }
            }); 
            
            // = Activities Module ==========================================
            
            $.targetIs(e, { tagSelector: '.NB-activity-star' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-interaction').data('contentId');
                
                self.close_interactions_popover();
                self.close_social_profile();
                self.open_starred_stories({'story_id': story_id});
            }); 
            $.targetIs(e, { tagSelector: '.NB-activity-feedsub' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-interaction').data('feedId');
                
                self.close_interactions_popover();
                self.close_social_profile();
                self.open_feed(feed_id);
            }); 
            
            // = One-offs =====================================================
            
            var clicked = false;
            $.targetIs(e, { tagSelector: '#mouse-indicator' }, function($t, $p){
                e.preventDefault();
                self.lock_mouse_indicator();
            }); 
            $.targetIs(e, { tagSelector: '.NB-load-user-profile img' }, function($t, $p){
                e.preventDefault();
                self.open_social_profile_modal();
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
            
        },
        
        handle_keyup: function(elem, e) {
            var self = this;
            
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
                if (NEWSBLUR.assets.preference('keyboard_verticalarrows') == 'scroll') {
                    var amount = NEWSBLUR.assets.preference('arrow_scroll_spacing');
                    self.scroll_in_story(amount, 1);
                } else {
                    self.show_next_story(1);
                }
            });
            $document.bind('keydown', 'up', function(e) {
                e.preventDefault();
                if (NEWSBLUR.assets.preference('keyboard_verticalarrows') == 'scroll') {
                    var amount = NEWSBLUR.assets.preference('arrow_scroll_spacing');
                    self.scroll_in_story(amount, -1);
                } else {
                    self.show_next_story(-1);
                }
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
            $document.bind('keydown', 'shift+n', function(e) {
                e.preventDefault();
                self.show_next_feed(1);
            });
            $document.bind('keydown', 'shift+p', function(e) {
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
                if (NEWSBLUR.assets.preference('keyboard_horizontalarrows') == 'site') {
                    self.show_next_feed(-1);
                } else {
                    self.switch_taskbar_view_direction(-1);
                }
            });
            $document.bind('keydown', 'right', function(e) {
                e.preventDefault();
                if (NEWSBLUR.assets.preference('keyboard_horizontalarrows') == 'site') {
                    self.show_next_feed(1);
                } else {
                    self.switch_taskbar_view_direction(1);
                }
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
                if (self.active_feed) {
                    self.reload_feed();
                }
            });
            $document.bind('keydown', 'enter', function(e) {
                e.preventDefault();
                if (self.flags['feed_view_showing_story_view']) {
                    self.switch_to_correct_view();
                } else {
                    NEWSBLUR.app.story_tab_view.prepare_story(null, true);
                    NEWSBLUR.app.story_tab_view.open_story();
                }
            });
            $document.bind('keydown', 'return', function(e) {
                e.preventDefault();
                if (self.flags['feed_view_showing_story_view']) {
                    self.switch_to_correct_view();
                } else {
                    NEWSBLUR.app.story_tab_view.prepare_story(null, true);
                    NEWSBLUR.app.story_tab_view.open_story();
                }
            });
            $document.bind('keydown', 'shift+enter', function(e) {
                e.preventDefault();
                if (_.contains(['list', 'grid'], 
                    NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    if (!self.active_story) NEWSBLUR.reader.show_next_story(1);
                    self.active_story.story_title_view.render_inline_story_detail(true);
                } else if (self.flags['temporary_story_view']) {
                    self.switch_to_correct_view();
                } else {
                    NEWSBLUR.app.text_tab_view.fetch_and_render(null, true);
                }
            });
            $document.bind('keydown', 'shift+return', function(e) {
                e.preventDefault();
                if (_.contains(['list', 'grid'], 
                    NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    if (!self.active_story) NEWSBLUR.reader.show_next_story(1);
                    self.active_story.story_title_view.render_inline_story_detail(true);
                } else if (self.flags['temporary_story_view']) {
                    self.switch_to_correct_view();
                } else {
                    NEWSBLUR.app.text_tab_view.fetch_and_render(null, true);
                }
            });
            $document.bind('keydown', 'space', function(e) {
                e.preventDefault();
                var amount = NEWSBLUR.assets.preference('space_scroll_spacing');
                self.page_in_story(amount, 1);
            });
            $document.bind('keydown', 'shift+space', function(e) {
                e.preventDefault();
                var amount = NEWSBLUR.assets.preference('space_scroll_spacing');
                self.page_in_story(amount, -1);
            });
            $document.bind('keydown', 'shift+u', function(e) {
                e.preventDefault();
                self.toggle_sidebar();
            });
            $document.bind('keydown', 'shift+f', function(e) {
                e.preventDefault();
                self.toggle_sidebar();
                self.toggle_story_titles_pane(true);
            });
            $document.bind('keydown', 'n', function(e) {
                e.preventDefault();
                self.open_next_unread_story_across_feeds();
            });
            $document.bind('keydown', 'p', function(e) {
                e.preventDefault();
                self.show_previous_story();
            });
            $document.bind('keydown', 'c', function(e) {
                e.preventDefault();
                NEWSBLUR.app.story_list.scroll_to_selected_story(self.active_story, {
                    scroll_to_comments: true,
                    scroll_offset: -50
                });
            });
            $document.bind('keydown', 'x', function(e) {
                e.preventDefault();
                var story = NEWSBLUR.reader.active_story;
                if (story && story.get('selected')) {
                    NEWSBLUR.reader.active_story.set('selected', false);
                } else if (story && !story.get('selected')) {
                    NEWSBLUR.reader.active_story.set('selected', true);
                }
            });
            $document.bind('keydown', 'shift+x', function(e) {
                e.preventDefault();
                NEWSBLUR.reader.active_story.story_view.expand_story();
            });
            $document.bind('keydown', 'shift+y', function(e) {
                e.preventDefault();
                if (!NEWSBLUR.reader.active_story) return;
                var story = NEWSBLUR.assets.get_story(NEWSBLUR.reader.active_story);
                var timestamp = story.get('story_timestamp');

                if (self.flags.river_view && !self.flags.social_view) {
                    self.mark_folder_as_read(self.active_folder, timestamp, 'newer');
                } else {
                    self.mark_feed_as_read(self.active_feed, timestamp, 'newer');
                }
            });
            $document.bind('keydown', 'shift+b', function(e) {
                e.preventDefault();
                if (!NEWSBLUR.reader.active_story) return;
                var story = NEWSBLUR.assets.get_story(NEWSBLUR.reader.active_story);
                var timestamp = story.get('story_timestamp');

                if (self.flags.river_view && !self.flags.social_view) {
                    self.mark_folder_as_read(self.active_folder, timestamp, 'older');
                } else {
                    self.mark_feed_as_read(self.active_feed, timestamp, 'older');
                }
            });
            $document.bind('keydown', 'm', function(e) {
                e.preventDefault();
                // self.show_last_unread_story();
                self.mark_active_story_read();
            });
            $document.bind('keydown', 'shift+m', function(e) {
                e.preventDefault();
                self.show_last_unread_story();
            });
            $document.bind('keydown', 'b', function(e) {
                e.preventDefault();
                self.show_previous_story();
            });
            $document.bind('keydown', 's', function(e) {
                e.preventDefault();
                if (self.active_story) {
                    var story_id = self.active_story.id;
                    var story = NEWSBLUR.assets.get_story(story_id);
                    story.toggle_starred();
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
            $document.bind('keypress', 'shift+l', function(e) {
                e.preventDefault();
                self.toggle_read_filter();
            });
            $document.bind('keypress', 'shift+d', function(e) {
                e.preventDefault();
                self.show_splash_page();
            });
            $document.bind('keydown', 'esc', function(e) {
                e.preventDefault();
                if (!_.keys($.modal.impl.d).length && 
                    !NEWSBLUR.ReaderPopover.is_open() && 
                    !self.flags['feed_list_showing_manage_menu']) {
                    self.show_splash_page();
                }
            });
            $document.bind('keypress', 't', function(e) {
                e.preventDefault();
                self.open_story_trainer();
            });
            $document.bind('keypress', 'shift+t', function(e) {
                e.preventDefault();
                self.open_feed_intelligence_modal(1);
            });
            $document.bind('keypress', 'a', function(e) {
                e.preventDefault();
                self.open_add_feed_modal();
            });
            $document.bind('keypress', 'o', function(e) {
                e.preventDefault();
                var story_id = self.active_story;
                if (!story_id) return;
                var story = self.model.get_story(story_id);
                story.open_story_in_new_tab(true);
            });
            $document.bind('keypress', 'v', function(e) {
                e.preventDefault();
                var story_id = self.active_story;
                if (!story_id) return;
                var story = self.model.get_story(story_id);
                story.open_story_in_new_tab(true);
            });
            $document.bind('keypress', 'shift+v', function(e) {
                e.preventDefault();
                var story_id = self.active_story;
                if (!story_id) return;
                var story = self.model.get_story(story_id);
                story.open_story_in_new_tab();
            });
            $document.bind('keypress', 'e', function(e) {
                e.preventDefault();
                var story = self.active_story;
                if (!story) return;
                self.send_story_to_email(story);
            });
            $document.bind('keydown', 'shift+a', function(e) {
                e.preventDefault();
                self.maybe_mark_all_as_read();
            });
            $document.bind('keydown', 'shift+e', function(e) {
                e.preventDefault();
                self.open_river_stories();
            });
            $document.bind('keydown', 'u', function(e) {
                e.preventDefault();
                self.mark_active_story_read();
            });
            $document.bind('keydown', 'g', function(e) {
                e.preventDefault();
                NEWSBLUR.app.feed_selector.toggle();
            });
            $document.bind('keydown', '/', function(e) {
                e.preventDefault();
                if (NEWSBLUR.app.story_titles_header.search_view) {
                    NEWSBLUR.app.story_titles_header.search_view.focus();
                }
            });
            $document.bind('keydown', 'shift+s', function(e) {
                e.preventDefault();
                if (self.active_story) {
                    var view = 'feed';
                    if (_.contains(['split', 'full'],
                        NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')) &&
                        _.contains(['page', 'story'], self.story_view)) {
                        view = 'title';
                    }
                    self.active_story.open_share_dialog(e, view);
                }
            });
        }
        
    });

})(jQuery);
