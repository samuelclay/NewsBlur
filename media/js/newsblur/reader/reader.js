(function($) {

    NEWSBLUR.Reader = Backbone.Router.extend({
    
        init: function() {
            
            // ===========
            // = Globals =
            // ===========
            
            NEWSBLUR.assets = new NEWSBLUR.AssetModel();
            this.model = NEWSBLUR.assets;
            this.story_view = 'page';
            this.$s = {
                $body: $('body'),
                $feed_lists: $('.NB-feedlists'),
                $feed_list: $('#feed_list'),
                $social_feeds: $('.NB-socialfeeds'),
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
                $feed_floater: $('.NB-feed-story-view-floater'),
                $feedbar: $('.NB-feedbar')
            };
            this.flags = {
                'bouncing_callout': false,
                'has_unfetched_feeds': false,
                'count_unreads_after_import_working': false,
                'import_from_google_reader_working': false
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
                'activities_page': 1
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
              FILL_OUT_PAGES: 50,
              RIVER_STORIES_FOR_STANDARD_ACCOUNT: 5
            };
    
            // ==================
            // = Event Handlers =
            // ==================
    
            $(window).bind('resize.reader', _.throttle($.rescope(this.resize_window, this), 1000));
            this.$s.$body.bind('click.reader', $.rescope(this.handle_clicks, this));
            this.$s.$body.bind('keyup.reader', $.rescope(this.handle_keyup, this));
            this.handle_keystrokes();
    
            // ============
            // = Bindings =
            // ============
    
            _.bindAll(this, 'show_stories_error');
    
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
            NEWSBLUR.app.feed_list_header = new NEWSBLUR.Views.FeedListHeader({collection: NEWSBLUR.assets.feeds});
            NEWSBLUR.app.feed_list = new NEWSBLUR.Views.FeedList({el: this.$s.$feed_list[0]});
            NEWSBLUR.app.story_titles = new NEWSBLUR.Views.StoryTitlesView({collection: NEWSBLUR.assets.stories});
            NEWSBLUR.app.story_list = new NEWSBLUR.Views.StoryListView({collection: NEWSBLUR.assets.stories});
            NEWSBLUR.app.original_tab_view = new NEWSBLUR.Views.OriginalTabView({collection: NEWSBLUR.assets.stories});
            NEWSBLUR.app.story_tab_view = new NEWSBLUR.Views.StoryTabView({collection: NEWSBLUR.assets.stories});
            
            this.load_intelligence_slider();
            this.handle_mouse_indicator_hover();
            this.position_mouse_indicator();
            this.handle_login_and_signup_forms();
            this.apply_story_styling();
            this.apply_tipsy_titles();
            this.load_recommended_feeds();
            this.setup_dashboard_graphs();
            this.setup_feedback_table();
            this.setup_howitworks_hovers();
            this.setup_interactions_module();
            this.setup_activities_module();
            this.setup_unfetched_feed_check();
        },

        // ========
        // = Page =
        // ========
        
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
            }
            
            this.flags.scrolling_by_selecting_story_title = true;
            clearTimeout(this.locks.scrolling);
            this.locks.scrolling = _.delay(_.bind(function() {
                this.flags.scrolling_by_selecting_story_title = false;
            }, this), 1000);
            this.make_content_pane_feed_counter();
            this.position_mouse_indicator();
            
            this.switch_taskbar_view(view, {
                skip_save_type: flag,
                resize: true
            });
            NEWSBLUR.app.story_titles.fill_out();
            this.flags.fetch_story_locations_in_feed_view = this.flags.fetch_story_locations_in_feed_view ||
                                                            _.throttle(function() {
                                                                NEWSBLUR.app.story_list.reset_story_positions();
                                                            }, 2000);
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
                west__minSize:          240,
                west__onresize_end:     $.rescope(this.save_feed_pane_size, this),
                spacing_open:           4,
                resizerDragOpacity:     0.6,
                resizeWhileDragging:    true,
                enableCursorHotkey:     false
            }); 
            
            if (this.model.preference('feed_pane_size') < 240) {
                this.layout.outerLayout.resizeAll();
            }
            
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
            $('.NB-module-content-account-realtime').tipsy({
                gravity: 's',
                delayIn: 0
            });
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
        
        add_body_classes: function() {
            this.$s.$body.toggleClass('NB-is-premium',        NEWSBLUR.Globals.is_premium);
            this.$s.$body.toggleClass('NB-is-anonymous',      NEWSBLUR.Globals.is_anonymous);
            this.$s.$body.toggleClass('NB-is-authenticated',  NEWSBLUR.Globals.is_authenticated);
            this.$s.$body.toggleClass('NB-pref-hide-changes', !!this.model.preference('hide_story_changes'));
        },
        
        hide_splash_page: function() {
            var self = this;
            var resize = false;
            if (!$('.right-pane').is(':visible')) {
                resize = true;
            }
            $('.right-pane').show();
            $('#NB-splash').hide();
            $('.NB-splash-info').hide();
            $('#NB-splash-overlay').hide();
            this.$s.$dashboard.addClass('NB-active');

            if (resize) {
                this.$s.$body.layout().resizeAll();
            }
            if (NEWSBLUR.Globals.is_anonymous) {
                this.setup_ftux_signup_callout();
            }
        },
        
        show_splash_page: function(skip_router) {
            this.reset_feed();
            NEWSBLUR.app.original_tab_view.unload_feed_iframe();
            NEWSBLUR.app.story_tab_view.unload_story_iframe();
            $('.right-pane').hide();
            $('.NB-splash-info').show();
            $('#NB-splash').show();
            $('#NB-splash-overlay').show();
            this.$s.$dashboard.removeClass('NB-active');
            if (!skip_router) {
                NEWSBLUR.router.navigate('');
            }
            this.model.preference('dashboard_date', new Date);
        },
        
        add_url_from_querystring: function() {
            if (this.flags['added_url_from_querystring']) return;
            
            var url = $.getQueryString('url');
            this.flags['added_url_from_querystring'] = true;

            if (url) {
                this.open_add_feed_modal({url: url});
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
        
        blur_to_page: function(options) {
            options = options || {};
            
            if (options.manage_menu) {
                $('.NB-menu-manage :focus').blur();
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
        },
        
        show_next_unread_story: function() {
            var unread_count = this.get_unread_count(true);
            
            if (unread_count) {
                var next_story = NEWSBLUR.assets.stories.get_next_unread_story();
                
                if (next_story) {
                    this.counts['find_next_unread_on_page_of_feed_stories_load'] = 0;
                    next_story.set('selected', true);
                } else if (this.counts['find_next_unread_on_page_of_feed_stories_load'] <
                           this.constants.FILL_OUT_PAGES && 
                           !this.model.flags['no_more_stories']) {
                    // Nothing up, nothing down, but still unread. Load 1 page then find it.
                    this.counts['find_next_unread_on_page_of_feed_stories_load'] += 1;
                    this.load_page_of_feed_stories();
                }
            }
        },
        
        open_next_unread_story_across_feeds: function() {
            var unread_count = this.active_feed && this.get_unread_count(true);
            
            if (!unread_count) {
                if (this.flags.river_view && false) {
                    // TODO: Make this work
                    // var $next_folder = this.get_next_unread_folder(1);
                    // var $folder = $next_folder.closest('li.folder');
                    // var folder_title = $folder.find('.folder_title_text').text();
                    // this.open_river_stories($folder, folder_title);
                } else {
                    // Find next feed with unreads
                    var $next_feed = this.get_next_unread_feed(1);
                    var next_feed_id = $next_feed.data('id');
                    if (NEWSBLUR.utils.is_feed_social(next_feed_id)) {
                        this.open_social_stories(next_feed_id, {force: true, $feed_link: $next_feed});
                    } else {
                        next_feed_id = parseInt(next_feed_id, 10);
                        this.open_feed(next_feed_id, {force: true, $feed_link: $next_feed});
                    }
                }
            }

            this.show_next_unread_story();
        },
        
        show_last_unread_story: function() {
            var unread_count = this.get_unread_count(true);
            
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
            var $next_feed = this.get_next_feed(direction, $current_feed);

            var next_feed_id = $next_feed.data('id');
            if (next_feed_id && next_feed_id == this.active_feed) {
                this.show_next_feed(direction, $next_feed);
            } else if (NEWSBLUR.utils.is_feed_social(next_feed_id)) {
                this.open_social_stories(next_feed_id, {force: true, $feed_link: $next_feed});
            } else {
                next_feed_id = parseInt(next_feed_id, 10);
                this.open_feed(next_feed_id, {force: true, $feed_link: $next_feed});
            }
        },
        
        get_next_feed: function(direction, $current_feed) {
            var self = this;
            var $feed_list = this.$s.$feed_list.add(this.$s.$social_feeds);
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
            var $feed_list = this.$s.$feed_list.add(this.$s.$social_feeds);
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
        
        page_in_story: function(amount, direction) {
            var page_height = this.$s.$story_pane.height();
            var scroll_height = parseInt(page_height * amount, 10);
            var dir = '+';
            if (direction == -1) {
                dir = '-';
            }
            // NEWSBLUR.log(['page_in_story', this.$s.$story_pane, direction, page_height, scroll_height]);
            if (this.story_view == 'page' && !this.flags['page_view_showing_feed_view']) {
                this.$s.$feed_iframe.scrollTo({
                    top: dir+'='+scroll_height, 
                    left:'+=0'
                }, 230, {queue: false});
            } else if (this.story_view == 'feed' || this.flags['page_view_showing_feed_view']) {
                this.$s.$feed_stories.scrollTo({
                    top: dir+'='+scroll_height, 
                    left:'+=0'
                }, 230, {queue: false});
            }
            
            this.show_mouse_indicator();
            // _.delay(_.bind(this.hide_mouse_indicator, this), 350);
        },
        
        find_story_with_action_preference_on_open_feed: function() {
            var open_feed_action = this.model.preference('open_feed_action');

            if (this.counts['page'] != 1) return;
            
            if (open_feed_action == 'newest') {
                this.show_next_unread_story();
            } else if (open_feed_action == 'oldest') {
                this.show_last_unread_story();
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
            
            if (!NEWSBLUR.assets.folders.length || !NEWSBLUR.assets.preference('has_setup_feeds')) {
                if (options.delayed_import || this.flags.delayed_import) {
                    this.setup_ftux_add_feed_callout("Check your email...");
                } else if (NEWSBLUR.assets.preference('has_setup_feeds')) {
                    this.setup_ftux_add_feed_callout();
                } else if (!NEWSBLUR.intro || !NEWSBLUR.intro.flags.open) {
                    _.defer(_.bind(this.open_intro_modal, this), 100);
                }
            } else if (!NEWSBLUR.assets.flags['has_chosen_feeds'] && NEWSBLUR.assets.folders.length) {
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
            
            this.flags['has_unfetched_feeds'] = NEWSBLUR.assets.feeds.has_unfetched_feeds();
            
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
        
        // ===============================
        // = Feed bar - Individual Feeds =
        // ===============================
        
        reset_feed: function() {
            $.extend(this.flags, {
                'scrolling_by_selecting_story_title': false,
                'page_view_showing_feed_view': false,
                'feed_view_showing_story_view': false,
                'story_titles_loaded': false,
                'iframe_prevented_from_loading': false,
                'pause_feed_refreshing': false,
                'feed_list_showing_manage_menu': false,
                'unread_threshold_temporarily': null,
                'river_view': false,
                'social_view': false,
                'non_premium_river_view': false,
                'select_story_in_feed': null
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
            
            this.model.flags['no_more_stories'] = false;
            this.$s.$feed_stories.scrollTop(0);
            this.$s.$starred_header.removeClass('NB-selected');
            this.$s.$river_header.removeClass('NB-selected');
            this.$s.$tryfeed_header.removeClass('NB-selected');
            this.model.feeds.deselect();
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
            
            if (this.flags['showing_feed_in_tryfeed_view'] || this.flags['showing_social_feed_in_tryfeed_view']) {
                this.hide_tryfeed_view();
            }
            
            this.active_folder = null;
            this.active_feed = null;
            this.active_story = null;
            
            NEWSBLUR.assets.stories.reset();
        },
        
        open_feed: function(feed_id, options) {
            options = options || {};
            var self = this;
            var $story_titles = this.$s.$story_titles;
            var feed = this.model.get_feed(feed_id) || options.feed;
            var temp = feed && (feed.get('temp') || !feed.get('subscribed'));
            
            if (!feed || (temp && !options.try_feed)) {
                // Setup tryfeed views first, then come back here.
                options.feed = options.feed && options.feed.attributes;
                return this.load_feed_in_tryfeed_view(feed_id, options);
            }

            this.flags['opening_feed'] = true;
            
            if (options.try_feed || feed) {
                this.reset_feed();
                this.hide_splash_page();
                if (options.story_id) {
                    this.flags['select_story_in_feed'] = options.story_id;
                }
            
                this.active_feed = feed.id;
                this.next_feed = feed.id;
                
                feed.set('selected', true, options);
                if (NEWSBLUR.app.story_unread_counter) {
                    NEWSBLUR.app.story_unread_counter.remove();
                }
                
                NEWSBLUR.app.story_titles.show_loading(options);
                this.hide_stories_error();
                // this.show_stories_progress_bar();
                this.iframe_scroll = null;
                this.set_correct_story_view_for_feed(feed.id);
                this.make_feed_title_in_stories(feed.id);
                this.switch_taskbar_view(this.story_view);

                _.delay(_.bind(function() {
                    if (!options.delay || feed.id == self.next_feed) {
                        this.model.load_feed(feed.id, 1, true, $.rescope(this.post_open_feed, this), 
                                             this.show_stories_error);
                    }
                }, this), options.delay || 0);

                if (!this.story_view || this.story_view == 'page') {
                    _.delay(_.bind(function() {
                        if (!options.delay || feed.id == this.next_feed) {
                            NEWSBLUR.app.original_tab_view.load_feed_iframe(feed.id);
                        }
                    }, this), options.delay || 0);
                } else {
                    NEWSBLUR.app.original_tab_view.unload_feed_iframe();
                    this.flags['iframe_prevented_from_loading'] = true;
                }
                this.setup_mousemove_on_views();
                
                if (!options.silent) {
                    var feed_title = feed.get('feed_title') || '';
                    var slug = _.string.words(_.string.clean(feed_title.replace(/[^a-z0-9\. ]/ig, ''))).join('-').toLowerCase();
                    var url = "site/" + feed.id + "/" + slug;
                    if (!_.string.include(window.location.pathname, url)) {
                        // NEWSBLUR.log(["Navigating to url", url]);
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
            
            // NEWSBLUR.log(['post_open_feed', data.stories, this.flags]);
            this.flags['opening_feed'] = false;
            this.find_story_with_action_preference_on_open_feed();
            this.show_feed_hidden_story_title_indicator(true);
            this.show_story_titles_above_intelligence_level({'animate': false});
            if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                this.show_next_unread_story(true);
            } else if (this.counts['find_last_unread_on_page_of_feed_stories_load']) {
                this.show_last_unread_story(true);
            } else if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                this.select_story_in_feed();
            }
            this.flags['story_titles_loaded'] = true;
            if (first_load) {
                if (this.story_view == 'story' &&
                    !this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_story(1);
                }
                
                this.make_content_pane_feed_counter(feed_id);
            }
            this.hide_stories_progress_bar();
            if (this.flags['showing_feed_in_tryfeed_view']) {
                this.show_tryfeed_add_button();
                this.correct_tryfeed_title();
            }
        },
        
        set_correct_story_view_for_feed: function(feed_id, view) {
            var feed = NEWSBLUR.assets.get_feed(feed_id || this.active_feed);
            var $original_tabs = $('.task_view_page, .task_view_story');
            var $page_tab = $('.task_view_page');
            view = view || NEWSBLUR.assets.view_setting(feed_id);

            if (feed && feed.get('disabled_page')) {
                view = 'feed';
                $original_tabs.addClass('NB-disabled-page')
                              .addClass('NB-disabled')
                              .attr('title', 'The original page has been disabled by the publisher.')
                              .tipsy({
                    gravity: 's',
                    fade: true,
                    delayIn: 200
                });
                $original_tabs.each(function() {
                    $(this).tipsy('enable');
                });
            } else if (feed && feed.get('has_exception') && feed.get('exception_type') == 'page') {
                if (view == 'page') {
                    view = 'feed';
                }
                $('.task_view_page').addClass('NB-exception-page');
            } else {
                $original_tabs.removeClass('NB-disabled-page')
                              .removeClass('NB-disabled')
                              .removeClass('NB-exception-page');
                $original_tabs.each(function() {
                    $(this).tipsy('disable');
                });
            }

            if (feed_id == 'starred') {
                $page_tab.addClass('NB-disabled-page').addClass('NB-disabled');
            }

            this.story_view = view;
        },
        
        change_view_setting: function(feed_id, setting, $feed) {
            var changed = NEWSBLUR.assets.view_setting(feed_id, setting);
            
            if (!changed) return;
            
            if (feed_id == this.active_feed && this.flags.social_view) {
                this.open_social_stories(feed_id, {$feed: $feed});
            } else if (feed_id == this.active_feed && this.flags.river_view) {
                var folder = NEWSBLUR.assets.folders.get_view($feed).model;
                this.open_river_stories($feed, folder);
            } else if (feed_id == this.active_feed) {
                this.open_feed(feed_id, {$feed: $feed});
            }
            
            this.show_correct_feed_view_options_in_menu();
        },
        
        // ===============
        // = Feed Header =
        // ===============
        
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
            
            this.reset_feed();
            this.hide_splash_page();
            this.active_feed = 'starred';
            if (options.story_id) {
                this.flags['select_story_in_feed'] = options.story_id;
            }

            this.iframe_scroll = null;
            this.$s.$starred_header.addClass('NB-selected');
            this.$s.$body.addClass('NB-view-river');
            this.flags.river_view = true;
            $('.task_view_page', this.$s.$taskbar).addClass('NB-disabled');
            var explicit_view_setting = this.model.view_setting(this.active_feed, 'view');
            if (!explicit_view_setting || explicit_view_setting == 'page') {
              explicit_view_setting = 'feed';
            }
            this.set_correct_story_view_for_feed(this.active_feed, explicit_view_setting);
            this.switch_taskbar_view(this.story_view);
            this.setup_mousemove_on_views();
            
            this.model.fetch_starred_stories(1, _.bind(this.post_open_starred_stories, this), 
                                             this.show_stories_error, true);
        },
        
        post_open_starred_stories: function(data, first_load) {
            if (this.active_feed == 'starred') {
                // NEWSBLUR.log(['post_open_starred_stories', data.stories.length, first_load]);
                this.flags['opening_feed'] = false;
                this.find_story_with_action_preference_on_open_feed();
                if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                    this.select_story_in_feed();
                }
                this.show_story_titles_above_intelligence_level({'animate': false});
                this.flags['story_titles_loaded'] = true;
            }
        },
        
        // =================
        // = River of News =
        // =================
        
        open_river_stories: function($folder, folder) {
            var $story_titles = this.$s.$story_titles;
            $folder = $folder || this.$s.$feed_list;
            var folder_view = NEWSBLUR.assets.folders.get_view($folder);
            var folder_title = folder && folder.get('folder_title');
            
            this.reset_feed();
            this.hide_splash_page();
            this.active_folder = folder;
            if (!folder_title) {
                this.active_feed = 'river:';
                this.$s.$river_header.addClass('NB-selected');
            } else {
                this.active_feed = 'river:' + folder_title;
                folder_view.model.set('selected', true);
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
            this.setup_mousemove_on_views();
            this.make_feed_title_in_stories();
            
            NEWSBLUR.router.navigate('');
            var feeds = this.list_feeds_with_unreads_in_folder($folder, false, true);
            this.cache['river_feeds_with_unreads'] = feeds;
            this.hide_stories_error();
            this.show_stories_progress_bar(feeds.length);
            this.model.fetch_river_stories(this.active_feed, feeds, 1, 
                _.bind(this.post_open_river_stories, this), this.show_stories_error, true);
        },
        
        post_open_river_stories: function(data, first_load) {
            // NEWSBLUR.log(['post_open_river_stories', data, this.active_feed]);
            if (!data) {
              return this.show_stories_error(data);
            }
            
            if (this.active_feed && this.active_feed.indexOf('river:') != -1) {
                if (!NEWSBLUR.Globals.is_premium &&
                    NEWSBLUR.Globals.is_authenticated &&
                    this.flags['river_view'] &&
                    this.active_feed.indexOf('river:') != -1) {
                    this.flags['non_premium_river_view'] = true;
                }
                this.flags['opening_feed'] = false;
                this.show_feed_hidden_story_title_indicator(true);
                this.find_story_with_action_preference_on_open_feed();
                this.show_story_titles_above_intelligence_level({'animate': false});
                this.flags['story_titles_loaded'] = true;
                if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                } else if (this.counts['find_last_unread_on_page_of_feed_stories_load']) {
                    this.show_last_unread_story(true);
                } else if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                    this.select_story_in_feed();
                }
                this.hide_stories_progress_bar();
            }
        },
        
        list_feeds_with_unreads_in_folder: function($folder, counts_only, visible_only) {
            var model = this.model;
            var unread_view = this.get_unread_view_name();
            $folder = $folder || this.$s.$feed_list;
            
            var $feeds = $('.feed:not(.NB-empty)', $folder);
            var feeds = _.compact(_.map($('.feed:not(.NB-empty)', $folder), function(o) {
                var feed_id = parseInt($(o).data('id'), 10);
                var feed = model.get_feed(feed_id);
                if (!feed) {
                    return;
                } else if (counts_only && !visible_only) {
                    return feed.get('ps') + feed.get('nt') + feed.get('ng');
                } else if (counts_only && visible_only) {
                    if (unread_view == 'positive') return feed.get('ps');
                    if (unread_view == 'neutral')  return feed.get('ps') + feed.get('nt');
                    if (unread_view == 'negative') return feed.get('ps') + feed.get('nt') + feed.get('ng');
                } else if (!counts_only && visible_only) {
                    if (unread_view == 'positive') return feed.get('ps') && feed_id;
                    if (unread_view == 'neutral')  return (feed.get('ps') || feed.get('nt')) && feed_id;
                    if (unread_view == 'negative') return (feed.get('ps') || feed.get('nt') || feed.get('ng')) && feed_id;
                } else {
                    return (feed.get('ps') || feed.get('nt') || feed.get('ng')) && feed_id;
                }
            }));
            
            return feeds;
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
            
            this.reset_feed();
            this.hide_splash_page();
            
            this.active_feed = feed.id;
            this.next_feed = feed.id;
            this.flags.river_view = true;
            if (options.story_id) {
                this.flags['select_story_in_feed'] = options.story_id;
            }
            
            this.iframe_scroll = null;
            this.flags['opening_feed'] = true;
            feed.set('selected', true, options);
            this.make_feed_title_in_stories(feed.id);
            this.$s.$body.addClass('NB-view-river');
            this.flags.social_view = true;
            
            this.set_correct_story_view_for_feed(this.active_feed);
            
            // TODO: Only make feed the default for blurblogs, not overriding an explicit pref.
            this.switch_taskbar_view('feed');
            this.setup_mousemove_on_views();
            
            this.hide_stories_error();
            this.show_stories_progress_bar();
            this.model.fetch_social_stories(this.active_feed, 1, 
                _.bind(this.post_open_social_stories, this), this.show_stories_error, true);
            
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
                    // NEWSBLUR.log(["Navigating to social", url, window.location.pathname]);
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
              return this.show_stories_error(data);
            }
            
            if (this.active_feed && NEWSBLUR.utils.is_feed_social(this.active_feed)) {
                this.flags['opening_feed'] = false;
                this.find_story_with_action_preference_on_open_feed();
                this.show_story_titles_above_intelligence_level({'animate': false});
                this.show_feed_hidden_story_title_indicator(true);
                this.flags['story_titles_loaded'] = true;
                if (this.counts['select_story_in_feed'] || this.flags['select_story_in_feed']) {
                    this.select_story_in_feed();
                } else if (this.counts['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                } else if (this.counts['find_last_unread_on_page_of_feed_stories_load']) {
                    this.show_last_unread_story(true);
                }
                this.hide_stories_progress_bar();
                
                if (this.flags['showing_social_feed_in_tryfeed_view']) {
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
        
        // =================
        // = Story loading =
        // =================
        
        show_stories_progress_bar: function(feeds_loading) {
            if (NEWSBLUR.app.story_unread_counter) {
                NEWSBLUR.app.story_unread_counter.remove();
            }
            
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
        
        show_stories_error: function(data) {
            NEWSBLUR.log(["show_stories_error", data]);
            this.hide_stories_progress_bar();
            
            NEWSBLUR.app.original_tab_view.iframe_not_busting();
            this.model.flags['no_more_stories'] = true;
            
            var message = "Oh no! <br> There was an error!";
            if (data && data.status) {
                if (data.status == 502) {
                    message = "NewsBlur is down right now. <br> Try again soon.";
                } else if (data.status == 503) {
                    message = "NewsBlur is in maintenace mode. <br> Try again soon.";
                }
            }
            var $error = $.make('div', { className: 'NB-feed-error' }, [
                $.make('div', { className: 'NB-feed-error-icon' }),
                $.make('div', { className: 'NB-feed-error-text' }, message)
            ]).css({'opacity': 0});
            
            this.$s.$story_taskbar.append($error);
            if (NEWSBLUR.app.story_unread_counter) {
                NEWSBLUR.app.story_unread_counter.remove();
            }
            
            $error.animate({'opacity': 1}, {'duration': 500, 'queue': false});
            // Center the progress bar
            var i_width = $error.width();
            var o_width = this.$s.$story_taskbar.width();
            var left = (o_width / 2.0) - (i_width / 2.0);
            $error.css({'left': left});
            
            NEWSBLUR.app.story_titles.end_loading();
        },
        
        hide_stories_error: function() {
            var $error = $('.NB-feed-error', this.$s.$story_taskbar);
            $error.animate({'opacity': 0}, {
              'duration': 250, 
              'queue': false, 
              'complete': function() {
                $error.remove();
              }
            });
        },
        
        // ==========================
        // = Story Pane - All Views =
        // ==========================
        
        switch_to_correct_view: function(found_story_in_page) {
            // NEWSBLUR.log(['Found story', this.story_view, found_story_in_page, this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
            if (found_story_in_page === false) {
                // Story not found, show in feed view with link to page view
                if (this.story_view == 'page' && !this.flags['page_view_showing_feed_view']) {
                    // NEWSBLUR.log(['turn on feed view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                    this.flags['page_view_showing_feed_view'] = true;
                    this.flags['feed_view_showing_story_view'] = false;
                    this.switch_taskbar_view('feed', {skip_save_type: 'page'});
                    NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
                }
            } else {
              if (this.story_view == 'page' && this.flags['page_view_showing_feed_view']) {
                  // NEWSBLUR.log(['turn off feed view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                  this.flags['page_view_showing_feed_view'] = false;
                  this.flags['feed_view_showing_story_view'] = false;
                  this.switch_taskbar_view('page');
              } else if (this.flags['feed_view_showing_story_view']) {
                  // NEWSBLUR.log(['turn off story view', this.flags['page_view_showing_feed_view'], this.flags['feed_view_showing_story_view']]);
                  this.flags['page_view_showing_feed_view'] = false;
                  this.flags['feed_view_showing_story_view'] = false;
                  this.switch_taskbar_view(this.story_view, {skip_save_type: true});
              }
            }
        },
        
        mark_feed_as_read: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            this.mark_feed_as_read_update_counts(feed_id);
            this.model.mark_feed_as_read([feed_id]);
            
            if (feed_id == this.active_feed) {
                this.model.stories.each(function(story) {
                    story.set('read_status', true);
                });
            }
        },
        
        mark_folder_as_read: function(folder) {
            var folder = folder || this.active_folder;
            var folder_view = folder.folder_view;
            var feeds = folder.feed_ids_in_folder();

            _.each(feeds, _.bind(function(feed_id) {
                this.mark_feed_as_read_update_counts(feed_id);
            }, this));
            this.model.mark_feed_as_read(feeds);
            
            if (folder == this.active_folder) {
                this.model.stories.each(function(story) {
                    story.set('read_status', true);
                });
            }
        },
        
        mark_feed_as_read_update_counts: function(feed_id) {
            if (feed_id) {
                var feed = this.model.get_feed(feed_id);
                if (!feed) return;

                feed.set('ps', 0);
                feed.set('nt', 0);
                feed.set('ng', 0);
            }
        },
        
        open_story_trainer: function(story_id, feed_id) {
            story_id = story_id || this.active_story && this.active_story.id;
            feed_id = feed_id || (story_id && this.model.get_story(story_id).get('story_feed_id'));
            
            if (story_id && feed_id) {
                NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierStory(story_id, feed_id, {
                    'feed_loaded': !this.flags['river_view']
                });
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
            var url = 'https://plusone.google.com/_/+1/confirm'; //?hl=en&url=${url}
            var googleplus_url = [
              url,
              '?hl=en&url=',
              encodeURIComponent(story.get('story_permalink')),
              '&title=',
              encodeURIComponent(story.get('story_title')),
              '&tags=',
              encodeURIComponent(story.get('story_tags').join(', '))
            ].join('');
            window.open(googleplus_url, '_blank');
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        send_story_to_email: function(story_id) {
            NEWSBLUR.reader_send_email = new NEWSBLUR.ReaderSendEmail(story_id);
            var story = this.model.get_story(story_id);
            NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
        },
        
        // =====================
        // = Story Titles Pane =
        // =====================
        
        make_content_pane_feed_counter: function(feed_id) {
            var $content_pane = this.$s.$content_pane;
            feed_id = feed_id || this.active_feed;
            if (!feed_id) return;
            var feed = this.model.get_feed(feed_id);
            if (!feed) return;
            
            if (NEWSBLUR.app.story_unread_counter) {
                NEWSBLUR.app.story_unread_counter.remove();
            }
            NEWSBLUR.app.story_unread_counter = new NEWSBLUR.Views.FeedCount({model: feed}).render();

            NEWSBLUR.app.story_unread_counter.$el.css({'opacity': 0});
            this.$s.$story_taskbar.append(NEWSBLUR.app.story_unread_counter.$el);
            _.delay(function() {
                NEWSBLUR.app.story_unread_counter.center();
                NEWSBLUR.app.story_unread_counter.$el.animate({'opacity': .2}, {'duration': 1000, 'queue': false});
            }, 500);
            
        },
        
        // ===========
        // = Stories =
        // ===========
        
        load_page_of_feed_stories: function(options) {
            options = _.extend({}, {'show_loading': true}, options);
            var $story_titles = this.$s.$story_titles;
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);

            if (!this.flags['opening_feed']) {
                this.flags['opening_feed'] = true;
                this.counts['page'] += 1;
                NEWSBLUR.app.story_titles.show_loading(options);
                
                if (this.active_feed == 'starred') {
                    this.model.fetch_starred_stories(this.counts['page'], _.bind(this.post_open_starred_stories, this),
                                                     this.show_stories_error, false);
                } else if (this.flags['social_view']) {
                    this.model.fetch_social_stories(this.active_feed,
                                                    this.counts['page'], _.bind(this.post_open_social_stories, this),
                                                    this.show_stories_error, false);
                } else if (this.flags['river_view']) {
                    this.model.fetch_river_stories(this.active_feed, this.cache['river_feeds_with_unreads'],
                                                   this.counts['page'], _.bind(this.post_open_river_stories, this),
                                                   this.show_stories_error, false);
                } else {
                    this.model.load_feed(feed_id, this.counts['page'], false, 
                                         $.rescope(this.post_open_feed, this), this.show_stories_error);                                 
                }
            }
        },
        
        make_feed_title_in_stories: function(feed_id, options) {
            var feed = this.model.get_feed(feed_id);
            
            if (NEWSBLUR.app.feed_title_view) {
                if (NEWSBLUR.app.feed_title_view.destroy) {
                    NEWSBLUR.app.feed_title_view.destroy();
                } else {
                    NEWSBLUR.app.feed_title_view.remove();
                }
            }
            
            if (feed) {
                NEWSBLUR.app.feed_title_view = new NEWSBLUR.Views.FeedTitleView({
                    model: feed, 
                    type: 'story'
                }).render();
                this.$s.$feedbar.html(NEWSBLUR.app.feed_title_view.$el);
            } else if (this.active_folder && this.active_folder.get('folder_title')) {
                NEWSBLUR.app.feed_title_view = $(_.template('\
                    <div class="NB-folder">\
                        <div class="NB-story-title-indicator">\
                            <div class="NB-story-title-indicator-count"></div>\
                            <span class="NB-story-title-indicator-text">show hidden stories</span>\
                        </div>\
                        <div class="NB-folder-icon"></div>\
                        <div class="NB-feedlist-manage-icon"></div>\
                        <div class="NB-folder-title"><%= folder_title %></div>\
                    </div>\
                ', {
                    folder_title: this.active_folder.get('folder_title')
                }));
                this.$s.$feedbar.html(NEWSBLUR.app.feed_title_view);
            }
            
            this.show_feed_hidden_story_title_indicator();
        },
        
        show_feed_hidden_story_title_indicator: function(is_feed_load) {
            if (is_feed_load && this.flags['unread_threshold_temporarily']) return;
            else this.flags['unread_threshold_temporarily'] = null;
            if (!this.active_feed) return;
            
            var $story_titles = this.$s.$story_titles;
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var unread_view_name = this.get_unread_view_name();
            var $indicator = $('.NB-story-title-indicator', $story_titles);
            var hidden_stories = false;
            if (this.flags['river_view']) {
                hidden_stories = !!NEWSBLUR.assets.stories.hidden().length;
            } else {
                if (unread_view_name == 'positive') {
                    hidden_stories = !!(feed.get('nt') | feed.get('ng'));
                } else if (unread_view_name == 'neutral') {
                    hidden_stories = !!feed.get('ng');
                }
            }
            
            if (!hidden_stories) {
                $indicator.hide();
                return;
            }
            
            $indicator.css({'display': 'block', 'opacity': 0});
            if (is_feed_load) {
                _.delay(function() {
                    $indicator.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeOutCubic'});
                }, 500);
            }
            $indicator.removeClass('unread_threshold_positive')
                      .removeClass('unread_threshold_neutral')
                      .removeClass('unread_threshold_negative')
                      .addClass('unread_threshold_'+unread_view_name);
        },
                
        show_hidden_story_titles: function() {
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var $indicator = $('.NB-story-title-indicator', this.$s.$story_titles);
            var unread_view_name = $indicator.hasClass('unread_threshold_positive') ?
                                   'positive' :
                                   'neutral';
            var hidden_stories_at_threshold = this.model.stories.any(_.bind(function(story) {
                var score = story.score();
                if (unread_view_name == 'positive') return score == 0;
                else if (unread_view_name == 'neutral') return score < 0;
            }, this));
            var hidden_stories_below_threshold = unread_view_name == 'positive' && 
                                                 this.model.stories.any(_.bind(function(story) {
                return story.score() < 0;
            }, this));
            
            // NEWSBLUR.log(['show_hidden_story_titles', hidden_stories_at_threshold, hidden_stories_below_threshold, unread_view_name]);
            
            // First click, open neutral. Second click, open negative.
            if (unread_view_name == 'positive' && hidden_stories_at_threshold && hidden_stories_below_threshold) {
                this.flags['unread_threshold_temporarily'] = 'neutral';
                this.show_story_titles_above_intelligence_level({
                    'unread_view_name': 'neutral',
                    'animate': true,
                    'follow': true
                });
                $indicator.removeClass('unread_threshold_positive').addClass('unread_threshold_neutral');
            } else {
                this.flags['unread_threshold_temporarily'] = 'negative';
                this.show_story_titles_above_intelligence_level({
                    'unread_view_name': 'negative',
                    'animate': true,
                    'follow': true
                });
                $indicator.removeClass('unread_threshold_positive')
                          .removeClass('unread_threshold_neutral')
                          .addClass('unread_threshold_negative');
                $indicator.animate({'opacity': 0}, {'duration': 500}).css('display', 'none');
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
            
        open_friends_modal: function() {
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
        
        hide_intelligence_trainer: function() {
          var $trainer = $('.NB-module-account-trainer');
          
          $trainer.addClass('NB-done');
        },
        
        hide_find_friends: function() {
          var $findfriends = $('.NB-module-find-friends');
          
          $findfriends.addClass('NB-done');
        },
        
        check_hide_getting_started: function(force) {
            var friends = this.model.preference('has_found_friends');
            var trained = this.model.preference('has_trained_intelligence');
            var feeds = this.model.preference('has_setup_feeds');
            
            if (force ||
                friends && trained && feeds) {
                var $gettingstarted = $('.NB-module-gettingstarted');
                $gettingstarted.animate({
                'opacity': 0
              }, {
                'duration': 500,
                'complete': function() {
                  $gettingstarted.slideUp(350);
                }
              });
              this.model.preference('hide_getting_started', true);
            } else {
              var $intro = $('.NB-module-item-intro');
              var $findfriends = $('.NB-module-find-friends');
              var $trainer = $('.NB-module-account-trainer');
          
              $intro.toggleClass('NB-done', feeds);
              $findfriends.toggleClass('NB-done', friends);
              $findfriends.toggleClass('NB-hidden', !feeds);
              $trainer.toggleClass('NB-done', trained);
              $trainer.toggleClass('NB-hidden', !feeds);
            }
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
        
        // ===================
        // = Taskbar - Story =
        // ===================
        
        switch_taskbar_view: function(view, options) {
            options = options || {};
            // NEWSBLUR.log(['switch_taskbar_view', view, options.skip_save_type]);
            var self = this;
            var $story_pane = this.$s.$story_pane;
            var feed = this.model.get_feed(this.active_feed);
            
            if (view == 'page' && feed && feed.get('has_exception') && feed.get('exception_type') == 'page') {
              this.open_feed_exception_modal();
              return;
            } else if (_.contains(['page', 'story'], view) && feed && feed.get('disabled_page')) {
                view = 'feed';
            } else if ($('.task_button_view.task_view_'+view).hasClass('NB-disabled')) {
                return;
            }

            var $taskbar_buttons = $('.NB-taskbar .task_button_view');
            var $feed_view = this.$s.$feed_view;
            var $feed_iframe = this.$s.$feed_iframe;
            var $page_to_feed_arrow = $('.NB-taskbar .NB-task-view-page-to-feed-arrow');
            var $feed_to_story_arrow = $('.NB-taskbar .NB-task-view-feed-to-story-arrow');
            
            if (!options.skip_save_type && this.story_view != view) {
                this.model.view_setting(this.active_feed, {'view': view});
            }
            
            $page_to_feed_arrow.hide();
            $feed_to_story_arrow.hide();
            this.flags['page_view_showing_feed_view'] = false;
            if (options.skip_save_type == 'page') {
                $page_to_feed_arrow.show();
                this.flags['page_view_showing_feed_view'] = true;
            } else if (options.skip_save_type == 'story') {
                $feed_to_story_arrow.show();
                this.flags['feed_view_showing_story_view'] = true;
            } else {
                $taskbar_buttons.removeClass('NB-active');
                $('.task_button_view.task_view_'+view).addClass('NB-active');
                this.story_view = view;
            }
            
            this.flags.scrolling_by_selecting_story_title = true;
            clearInterval(this.locks.scrolling);
            this.locks.scrolling = setTimeout(function() {
                self.flags.scrolling_by_selecting_story_title = false;
            }, 550);
            if (view == 'page') {
                NEWSBLUR.log(["iframe_prevented_from_loading", this.flags['iframe_prevented_from_loading']]);
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
                
                $story_pane.animate({
                    'left': -1 * $feed_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
                
                NEWSBLUR.app.story_list.reset_story_positions();
            } else if (view == 'story') {
                $story_pane.animate({
                    'left': -2 * $feed_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': this.model.preference('animations') ? 550 : 0,
                    'queue': false
                });
                NEWSBLUR.app.story_tab_view.load_story_iframe();
                if (!this.active_story) {
                    this.show_next_story(1);
                }
            }
            
            this.setup_mousemove_on_views();
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
            feed_id = feed_id || this.active_feed;
            
            NEWSBLUR.feed_exception = new NEWSBLUR.ReaderFeedException(feed_id);
        },
        
        open_feed_statistics_modal: function(feed_id) {
            feed_id = feed_id || this.active_feed;
            
            NEWSBLUR.statistics = new NEWSBLUR.ReaderStatistics(feed_id);
        },
        
        open_social_profile_modal: function(user_id) {
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
            // NEWSBLUR.log(["make_manage_menu", type, feed_id, story_id, inverse, $item]);

            if (type == 'site') {
                var show_chooser = !NEWSBLUR.Globals.is_premium && NEWSBLUR.Globals.is_authenticated;
                $manage_menu = $.make('ul', { className: 'NB-menu-manage' }, [
                    $.make('li', { className: 'NB-menu-manage-site-info' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('span', { className: 'NB-menu-manage-title' }, "Manage NewsBlur")
                    ]).corner('tl tr 8px'),
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
                    (show_chooser && $.make('li', { className: 'NB-menu-manage-feedchooser' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Choose Your 64 sites'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Enable the sites you want.')
                    ])),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-manage-keyboard' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Keyboard shortcuts')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-tutorial' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Tips &amp; Tricks')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-goodies' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Goodies')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-manage-account' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Account')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-profile-editor' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Profile')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-friends' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Friends')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-preferences' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Preferences')
                    ])
                ]);
                $manage_menu.addClass('NB-menu-manage-notop');
            } else if (type == 'feed') {
                var feed = this.model.get_feed(feed_id);
                if (!feed) return;
                var unread_count = this.get_unread_count(true, feed_id);
                var tab_unread_count = Math.min(25, unread_count);
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-feed' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-exception' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Fix this misbehaving site')
                    ])),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-separator-inverse' })),
                    (feed.get('exception_type') != 'feed' && $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-mark-read NB-menu-manage-feed-mark-read' }, [
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
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-controls NB-menu-manage-controls-feed' }, [
                        $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-order' }, [
                            $.make('li', { className: 'NB-view-setting-order-oldest' }, 'Oldest'),
                            $.make('li', { className: 'NB-view-setting-order-newest NB-active' }, 'Newest first')
                        ]),
                        $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-readfilter' }, [
                            $.make('li', { className: 'NB-view-setting-readfilter-all  NB-active' }, 'All stories'),
                            $.make('li', { className: 'NB-view-setting-readfilter-unread' }, 'Unread only')
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    // $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-recommend' }, [
                    //     $.make('div', { className: 'NB-menu-manage-image' }),
                    //     $.make('div', { className: 'NB-menu-manage-title' }, 'Recommend this site')
                    // ]),
                    // $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-settings' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Site settings')
                    ]),
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
                            $.make('input', { name: 'new_title', className: 'NB-menu-manage-title', value: feed.get('feed_title') })
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
            } else if (type == 'socialfeed') {
                var feed = this.model.get_feed(feed_id);
                if (!feed) return;
                var unread_count = this.get_unread_count(true, feed_id);
                var tab_unread_count = Math.min(25, unread_count);
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-feed' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-exception' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Fix this misbehaving site')
                    ])),
                    (feed.get('has_exception') && $.make('li', { className: 'NB-menu-separator-inverse' })),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-social-profile' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'View profile')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    (feed.get('exception_type') != 'feed' && $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-mark-read NB-menu-manage-feed-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as read')
                    ])),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-stats' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Statistics')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-controls NB-menu-manage-controls-feed' }, [
                        $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-order' }, [
                            $.make('li', { className: 'NB-view-setting-order-oldest' }, 'Oldest'),
                            $.make('li', { className: 'NB-view-setting-order-newest NB-active' }, 'Newest first')
                        ]),
                        $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-readfilter' }, [
                            $.make('li', { className: 'NB-view-setting-readfilter-all  NB-active' }, 'All stories'),
                            $.make('li', { className: 'NB-view-setting-readfilter-unread' }, 'Unread only')
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-feed-settings' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Site settings')
                    ]),
                    (feed.get('user_id') != NEWSBLUR.Globals.user_id && $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-delete NB-menu-manage-socialfeed-delete' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Unfollow')
                    ])),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-delete-confirm NB-menu-manage-socialfeed-delete-confirm' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Really unfollow?')
                    ])
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('$feed', $item);
                if (feed_id && unread_count == 0) {
                    $('.NB-menu-manage-feed-mark-read', $manage_menu).addClass('NB-disabled');
                    $('.NB-menu-manage-feed-unreadtabs', $manage_menu).addClass('NB-disabled');
                }
            } else if (type == 'folder') {
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-folder' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-mark-read NB-menu-manage-folder-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark folder as read')
                    ]),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-folder-subscribe' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Add a site to this folder')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-controls NB-menu-manage-controls-folder' }, [
                        $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-order' }, [
                            $.make('li', { className: 'NB-view-setting-order-oldest' }, 'Oldest'),
                            $.make('li', { className: 'NB-view-setting-order-newest NB-active' }, 'Newest first')
                        ])
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
                var starred_class = story.get('starred') ? ' NB-story-starred ' : '';
                var starred_title = story.get('starred') ? 'Remove bookmark' : 'Save This Story';
                var shared_class = story.get('shared') ? ' NB-story-shared ' : '';
                var shared_title = story.get('shared') ? 'Shared' : 'Post to blurblog';
                story.story_share_menu_view = new NEWSBLUR.Views.StoryShareView({
                    model: story
                });
                
                $manage_menu = $.make('ul', { className: 'NB-menu-manage NB-menu-manage-story ' + starred_class + shared_class }, [
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-story-open' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('input', { name: 'story_permalink', className: 'NB-menu-manage-open-input', value: story.get('story_permalink') }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Open')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-story-star' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, starred_title)
                    ]),
                    (story.get('read_status') && $.make('li', { className: 'NB-menu-manage-story-unread' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark as unread')
                    ])),
                    $.make('li', { className: 'NB-menu-manage-story-thirdparty' }, [
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
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-delicious')) {
                          this.send_story_to_delicious(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-readability')) {
                          this.send_story_to_readability(story.id);
                      } else if ($target.hasClass('NB-menu-manage-thirdparty-pinboard')) {
                          this.send_story_to_pinboard(story.id);
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
                          this.send_story_to_email(story.id);
                      }
                    }, this)),
                    $.make('li', { className: 'NB-menu-manage-story NB-menu-manage-story-share' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, shared_title)
                    ]),
                    $.make('li', { className: 'NB-menu-manage-story NB-menu-manage-confirm NB-menu-manage-story-share-confirm NB-modal-submit' }, [
                        $.make('div', { className: 'NB-menu-manage-confirm-position' }, [
                            story.story_share_menu_view.render().el
                        ])
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
                    $.make('li', { className: 'NB-menu-manage-story-train' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'What you like and dislike.')
                    ])
                ]);
                $manage_menu.data('feed_id', feed_id);
                $manage_menu.data('story_id', story_id);
                $manage_menu.data('$story', $item);
                
                // this.update_share_button_label($('.NB-sideoption-share-comments', $manage_menu));
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
            } else if (type == 'story') {
                story_id = options.story_id;
                if ($item.hasClass('NB-hover-inverse')) inverse = true; 
            } else if (type == 'site') {
                $('.NB-task-manage').tipsy('hide');
                $('.NB-task-manage').tipsy('disable');
            }
            var toplevel = options.toplevel || $item.hasClass("NB-toplevel") ||
                           $item.children('.folder_title').hasClass("NB-toplevel");
            var $manage_menu = this.make_manage_menu(type, feed_id, story_id, inverse, $item);
            this.show_correct_feed_view_options_in_menu($manage_menu);
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
            } else if (type == 'feed' || type == 'folder' || type == 'story' || type == 'socialfeed') {
                var left, top;
                // NEWSBLUR.log(['menu open', $item, inverse, toplevel, type]);
                if (inverse) {
                    var $align = $item;
                    if (type == 'feed') {
                        left = toplevel ? 0 : -20;
                        top = toplevel ? 21 : 21;
                    } else if (type == 'socialfeed') {
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
                        if (!$align.is(':visible')) {
                            $align = $('.NB-storytitles-sentiment', $item);
                        }
                    }
                    
                    $manage_menu_container.align($align, '-bottom -left', {
                        'top': -1 * top, 
                        'left': left
                    });

                    $manage_menu_container.corner('br 8px');
                    $manage_menu_container.find('.NB-menu-manage > li').each(function() {
                        $(this).prependTo($(this).parent());
                    });
                } else {
                    var $align = $item;
                    if (type == 'feed') {
                        left = toplevel ? 2 : -18;
                        top = toplevel ? 21 : 21;
                        $align = $('.NB-feedlist-manage-icon', $item);
                    } else if (type == 'socialfeed') {
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
                        if (!$align.is(':visible')) {
                            $align = $('.NB-storytitles-sentiment', $item);
                        }
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
            if (type == 'feed' || type == 'folder' || type == 'story' || type == 'socialfeed') {
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
            
            // Hide menu on esc.
            $('input,textarea', $manage_menu_container).bind('keydown.manage_menu', 'esc', function(e) {
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
            if (type == 'feed' || type == 'socialfeed') {
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
        
        show_correct_feed_view_options_in_menu: function($manage_menu) {
            $manage_menu = $manage_menu || $('.NB-menu-manage');
            
            if ($manage_menu.hasClass("NB-menu-manage-feed")) {
                var feed_id = $manage_menu.data('feed_id');
            } else {
                var feed_id = 'river:' + $manage_menu.data('folder_name');
            }

            var order = NEWSBLUR.assets.view_setting(feed_id, 'order');
            var read_filter = NEWSBLUR.assets.view_setting(feed_id, 'read_filter');
            var $oldest = $('.NB-view-setting-order-oldest', $manage_menu);
            var $newest = $('.NB-view-setting-order-newest', $manage_menu);
            var $unread = $('.NB-view-setting-readfilter-unread', $manage_menu);
            var $all = $('.NB-view-setting-readfilter-all', $manage_menu);
            $oldest.toggleClass('NB-active', order == 'oldest');
            $newest.toggleClass('NB-active', order != 'oldest');
            $oldest.text('Oldest' + (order == 'oldest' ? ' first' : ''));
            $newest.text('Newest' + (order != 'oldest' ? ' first' : ''));
            $unread.toggleClass('NB-active', read_filter == 'unread');
            $all.toggleClass('NB-active', read_filter != 'unread');
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
            var folder_view = NEWSBLUR.assets.folders.get_view($folder);
        
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
            var $select = $('select', $confirm);
            if (_.isNumber(feed_id)) {
                var feed      = this.model.get_feed(feed_id);
                var feed_view = feed.get_view($feed, true);
                var in_folder = feed_view.options.folder_title;
            } else {
                folder_view = NEWSBLUR.assets.folders.get_view($feed);
                var in_folder = folder_view.collection.options.title;
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

            $('option', $select).each(function() {
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
        
        manage_menu_move_feed: function(feed_id, $feed) {
            var self      = this;
            var feed_id   = feed_id || this.active_feed;
            var to_folder = $('.NB-menu-manage-feed-move-confirm select').val();
            var feed      = this.model.get_feed(feed_id);
            var feed_view = feed.get_view($feed);

            var moved = feed.move_to_folder(to_folder, {view: feed_view});
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
            var folder_view = NEWSBLUR.assets.folders.get_view($folder);
            var in_folder   = folder_view.collection.options.title;
            var folder_name = folder_view.options.title;
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
            var folder_view = NEWSBLUR.assets.folders.get_view($folder);
            
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
                'duration': 500, 
                'easing': 'easeOutQuart'
            });
            $('textarea', $confirm).focus().select();
            this.flags['showing_confirm_input_on_manage_menu'] = true;
        },
        
        hide_confirm_story_share_menu_item: function(shared) {
            var story_id = $('.NB-menu-manage').data('story_id');
            var story = NEWSBLUR.assets.get_story(story_id);
            var $share = $('.NB-menu-manage-story-share');
            var $confirm = $('.NB-menu-manage-story-share-confirm');
            
            $share.removeClass('NB-menu-manage-story-share-cancel');
            var text = 'Post to blurblog';
            if (shared) {
                text = 'Shared';
                $share.addClass('NB-active');
            } else {
                $share.removeClass('NB-active');
            }
            $('.NB-menu-manage-title', $share).text(text);
            $confirm.slideUp(500, _.bind(function() {
                if (shared) {
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
            
            this.slide_intelligence_slider(unread_view);
        },
        
        slide_intelligence_slider: function(value) {
            var $slider = this.$s.$intelligence_slider;
            if (this.model.preference('unread_view') != value) {
                this.model.preference('unread_view', value);
            }
            this.flags['unread_threshold_temporarily'] = null;
            this.switch_feed_view_unread_view(value);
            this.show_feed_hidden_story_title_indicator(true);
            this.show_story_titles_above_intelligence_level({'animate': true, 'follow': true});
            
            $('.NB-active', $slider).removeClass('NB-active');
            if (value < 0) {
                $('.NB-intelligence-slider-red', $slider).addClass('NB-active');
            } else if (value > 0) {
                $('.NB-intelligence-slider-green', $slider).addClass('NB-active');
            } else {
                $('.NB-intelligence-slider-yellow', $slider).addClass('NB-active');
            }
        },
        
        move_intelligence_slider: function(direction) {
            var value = this.model.preference('unread_view') + direction;
            this.slide_intelligence_slider(value);
        },
        
        switch_feed_view_unread_view: function(unread_view) {
            if (!_.isNumber(unread_view)) unread_view = this.get_unread_view_score();
            var $feed_list             = this.$s.$feed_list;
            var $social_feeds          = this.$s.$social_feeds;
            var unread_view_name       = this.get_unread_view_name(unread_view);
            var $next_story_button     = $('.task_story_next_unread');
            var $story_title_indicator = $('.NB-story-title-indicator', this.$story_titles);

            $feed_list.removeClass('unread_view_positive')
                      .removeClass('unread_view_neutral')
                      .removeClass('unread_view_negative')
                      .addClass('unread_view_'+unread_view_name);
            $social_feeds.removeClass('unread_view_positive')
                         .removeClass('unread_view_neutral')
                         .removeClass('unread_view_negative')
                         .addClass('unread_view_'+unread_view_name);

            $next_story_button.removeClass('task_story_next_positive')
                              .removeClass('task_story_next_neutral')
                              .removeClass('task_story_next_negative')
                              .addClass('task_story_next_'+unread_view_name);
                              
            $story_title_indicator.removeClass('unread_threshold_positive')
                                  .removeClass('unread_threshold_neutral')
                                  .removeClass('unread_threshold_negative')
                                  .addClass('unread_threshold_'+unread_view_name);
        },
        
        get_unread_view_score: function() {
            if (this.flags['unread_threshold_temporarily']) {
                var score_name = this.flags['unread_threshold_temporarily'];
                if (score_name == 'neutral') {
                    return 0;
                } else if (score_name == 'negative') {
                    return -1;
                }
            }
            
            return this.model.preference('unread_view');
        },
        
        get_unread_view_name: function(unread_view) {
            if (this.flags['unread_threshold_temporarily']) {
                return this.flags['unread_threshold_temporarily'];
            }
            
            if (typeof unread_view == 'undefined') {
                unread_view = this.get_unread_view_score();
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
            var feed = this.model.get_feed(feed_id);
            
            if (feed_id == 'starred') {
                // Umm, no. Not yet.
            } else if (feed) {
                if (!visible_only) {
                    total = feed.get('ng') + feed.get('nt') + feed.get('ps');
                } else {
                    var unread_view_name = this.get_unread_view_name();
                    if (unread_view_name == 'positive') {
                        total = feed.get('ps');
                    } else if (unread_view_name == 'neutral') {
                        total = feed.get('ps') + feed.get('nt');
                    } else if (unread_view_name == 'negative') {
                        total = feed.get('ps') + feed.get('nt') + feed.get('ng');
                    }
                }
                return total;
            } else if (this.flags['river_view']) {
                if (feed_id == 'river:') {
                    $folder = this.$s.$feed_list;
                } else {
                    $folder = $('li.folder.NB-selected');
                }
                var counts = this.list_feeds_with_unreads_in_folder($folder, true, visible_only);
                return _.reduce(counts, function(m, c) { return m + c; }, 0);
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
            
            if (this.model.stories.length > 18) {
                options['animate'] = false;
            }
            
            if (this.flags['unread_threshold_temporarily']) {
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
            
            if ((this.story_view == 'feed' || this.flags['page_view_showing_feed_view']) && 
                NEWSBLUR.assets.preference('feed_view_single_story')) {
                // No need to show/hide feed view stories under single_story preference. 
                // If the user switches to feed/page, then no animation is happening 
                // and this will work anyway.
                var active_story = this.active_story;
                var $active_story = this.active_story && this.active_story.story_view.$el;
                if ($active_story && $active_story.length || true) {
                  $stories_show = $stories_show.not('.NB-feed-story');
                  $stories_hide = $stories_hide.not('.NB-feed-story');
                }
                NEWSBLUR.log(["single story", $stories_show.length, $stories_hide.length, this.active_story, active_story && active_story.id]);
            }
            
            if (!options['animate']) {
                $stories_hide.css({'display': 'none'});
                $stories_show.css({'display': 'block'});
                NEWSBLUR.app.story_titles.fill_out();
            }
            
            if (!NEWSBLUR.assets.preference('feed_view_single_story')) {
                _.delay(function() {
                    NEWSBLUR.app.story_list.reset_story_positions();
                }, 500);
            }
            
            if (options['animate'] && options['follow'] && 
                ($stories_hide.length || $stories_show.length)) {
                // NEWSBLUR.log(['Showing correct stories', this.story_view, unread_view_name, $stories_show.length, $stories_hide.length]);
                if (this.model.preference('animations')) {
                    $stories_hide.slideUp(500, function() {
                        NEWSBLUR.app.story_titles.fill_out();
                    });
                    $stories_show.slideDown(500);
                } else {
                    $stories_hide.css({'display': 'none'});
                    $stories_show.css({'display': 'block'});
                    NEWSBLUR.app.story_titles.fill_out();
                }
                setTimeout(function() {
                    if (!self.active_story) return;
                    NEWSBLUR.app.story_list.scroll_to_selected_story(self.active_story);
                    NEWSBLUR.app.story_titles.scroll_to_selected_story(self.active_story);
                }, this.model.preference('animations') ? 550 : 0);
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
                                            this.show_stories_error);
        },
        
        setup_socket_realtime_unread_counts: function(force) {
            if (!force && NEWSBLUR.Globals.is_anonymous) return;
            // if (!force && !NEWSBLUR.Globals.is_premium) return;
            if (this.socket && !this.socket.socket.connected) {
                this.socket.socket.connect();
            } else if (force || !this.socket || !this.socket.socket.connected) {
                var server = window.location.protocol + '//' + window.location.hostname + ':8888';
                this.socket = this.socket || io.connect(server);
                
                // this.socket.refresh_feeds = _.debounce(_.bind(this.force_feeds_refresh, this), 1000*10);
                this.socket.on('connect', _.bind(function() {
                    var active_feeds = this.send_socket_active_feeds();
                    // NEWSBLUR.log(["Connected to real-time pubsub with " + active_feeds.length + " feeds."]);
                    this.socket.on('feed:update', _.bind(function(feed_id, message) {
                        NEWSBLUR.log(['Real-time feed update', feed_id, message]);
                        this.force_feeds_refresh(false, false, feed_id);
                    }, this));
                
                    this.flags.feed_refreshing_in_realtime = true;
                    this.setup_feed_refresh();
                    
                    $('.NB-module-content-account-realtime-subtitle').html($.make('b', 'Updating in real-time'));
                    $('.NB-module-content-account-realtime').attr('title', 'Reticulating splines').removeClass('NB-error');
                }, this));
                this.socket.on('disconnect', _.bind(function() {
                    NEWSBLUR.log(["Lost connection to real-time pubsub. Falling back to polling."]);
                    this.flags.feed_refreshing_in_realtime = false;
                    this.setup_feed_refresh();
                    $('.NB-module-content-account-realtime-subtitle').html($.make('b', 'Updating every 60 sec'));
                    $('.NB-module-content-account-realtime').attr('title', 'Polling for updates...').addClass('NB-error');
                }, this));
                this.socket.on('error', _.bind(function() {
                    NEWSBLUR.log(["Can't connect to real-time pubsub."]);
                    this.flags.feed_refreshing_in_realtime = false;
                    $('.NB-module-content-account-realtime-subtitle').html($.make('b', 'Updating every 60 sec'));
                    $('.NB-module-content-account-realtime').attr('title', 'Polling for updates...').addClass('NB-error');
                    _.delay(_.bind(this.setup_socket_realtime_unread_counts, this), 60*1000);
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
            
            clearInterval(this.flags.feed_refresh);
            
            this.flags.feed_refresh = setInterval(function() {
                if (!self.flags['pause_feed_refreshing']) {
                    self.force_feeds_refresh();
                }
            }, refresh_interval);
            NEWSBLUR.log(["Setting refresh interval to every " + refresh_interval/1000 + " seconds."]);
        },
        
        force_feed_refresh: function(feed_id, new_feed_id) {
            var self = this;
            feed_id  = feed_id || this.active_feed;
            new_feed_id = new_feed_id || feed_id;

            this.force_feeds_refresh(function() {
                // Open the feed back up if it is being refreshed and is still open.
                if (self.active_feed == feed_id || self.active_feed == new_feed_id) {
                    self.open_feed(new_feed_id, {force: true});
                }
            }, true, new_feed_id, this.show_stories_error);
        },
        
        force_feeds_refresh: function(callback, replace_active_feed, feed_id, error_callback) {
            if (callback) {
                this.cache.refresh_callback = callback;
            } else {
                delete this.cache.refresh_callback;
            }

            this.flags['pause_feed_refreshing'] = true;
            this.model.refresh_feeds(_.bind(function(updated_feeds) {
              this.post_feed_refresh(updated_feeds, replace_active_feed, feed_id);
            }, this), this.flags['has_unfetched_feeds'], feed_id, error_callback);
        },
        
        post_feed_refresh: function(updated_feeds, replace_active_feed, single_feed_id) {
            var feeds = this.model.feeds;
            
            if (this.cache.refresh_callback && $.isFunction(this.cache.refresh_callback)) {
                this.cache.refresh_callback(feeds);
                delete this.cache.refresh_callback;
            }

            this.flags['refresh_inline_feed_delay'] = false;
            this.flags['pause_feed_refreshing'] = false;
            this.check_feed_fetch_progress();
        },
        
        // ===================
        // = Mouse Indicator =
        // ===================

        setup_mousemove_on_views: function() {
            this.hide_mouse_indicator();
            
            if (this.story_view == 'story' ||
                this.flags['feed_view_showing_story_view']) {
                // this.hide_mouse_indicator();
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
                
                self.model.preference('lock_mouse_indicator', this.cache.mouse_position_y - NEWSBLUR.app.story_list.cache.story_pane_position);
                $('.NB-callout-text', $callout).text('Locked');
            }
            
            setTimeout(function() {
                self.flags['still_hovering_on_mouse_indicator'] = true;
                $callout.fadeOut(200);
            }, 500);
        },
        
        position_mouse_indicator: function() {
            var position = this.model.preference('lock_mouse_indicator');
            var container = this.layout.contentLayout.state.container.innerHeight - 30;

            if (position <= 0 || position > container) {
                position = 50; // Start with a 50 offset
            } else {
                position = position - 8; // Compensate for mouse indicator height.
            }

            this.$s.$mouse_indicator.css('top', position);
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
        
        // ===============================
        // = Interactions and Activities =
        // ===============================
        
        load_interactions_page: function(direction) {
            var self = this;
            var $module = $('.NB-module-interactions');
            
            $module.addClass('NB-loading');
            direction = direction || 0;

            this.model.load_interactions_page(this.counts['interactions_page']+direction, 
                                              function(resp) {
                $module.removeClass('NB-loading');
                if (!resp) return;
                $module.replaceWith(resp);
                $module = $('.NB-module-interactions');
                var page = $module[0].className.match(/NB-page-(\d+)/)[1];
                self.counts['interactions_page'] = parseInt(page, 10);
                self.load_javascript_elements_on_page();
            }, function() {
                $module.removeClass('NB-loading');
            });
        },
        
        load_activities_page: function(direction) {
            var self = this;
            var $module = $('.NB-module-activities');

            $module.addClass('NB-loading');
            direction = direction || 0;
            
            this.model.load_activities_page(this.counts['activities_page']+direction, 
                                              function(resp) {
                $module.removeClass('NB-loading');
                if (!resp) return;
                $module.replaceWith(resp);
                $module = $('.NB-module-activities');
                var page = $module[0].className.match(/NB-page-(\d+)/)[1];
                self.counts['activities_page'] = parseInt(page, 10);
                self.load_javascript_elements_on_page();
            }, function() {
                $module.removeClass('NB-loading');
            });
        },
        
        setup_interactions_module: function() {
            clearInterval(this.locks.load_interactions_module);
            if (!NEWSBLUR.Globals.debug) {
                this.locks.load_interactions_module = setInterval(_.bind(function() {
                    this.load_interactions_page();
                }, this), 5*60*1000);
            }
        },
        
        setup_activities_module: function() {
            clearInterval(this.locks.load_activities_module);
            if (!NEWSBLUR.Globals.debug) {
                this.locks.load_activities_module = setInterval(_.bind(function() {
                    this.load_activities_page();
                }, this), 5*60*1000);
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
                NEWSBLUR.assets.load_feeds();
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

            this.reset_feed();
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
            NEWSBLUR.log(["show_tryfeed_add_button", this.$s.$story_taskbar.find('.NB-tryfeed-add:visible').length]);
            if (this.$s.$story_taskbar.find('.NB-tryfeed-add:visible').length) return;
            
            var $add = $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-tryfeed-add NB-modal-submit-green NB-modal-submit-button' }, 'Add')
            ]).css({'opacity': 0});
            this.$s.$story_taskbar.find('.NB-taskbar').append($add);
            $add.animate({'opacity': 1}, {'duration': 600});
        },
        
        correct_tryfeed_title: function() {
            var feed = this.model.get_feed(this.active_feed);
            $('.NB-feeds-header-title', this.$s.$tryfeed_header).text(feed.get('feed_title'));
            this.make_feed_title_in_stories(this.active_feed);
        },
        
        show_tryfeed_follow_button: function() {
            if (this.$s.$story_taskbar.find('.NB-tryfeed-follow:visible').length) return;
            
            var $add = $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-tryfeed-follow NB-modal-submit-green NB-modal-submit-button' }, 'Follow')
            ]).css({'opacity': 0});
            this.$s.$story_taskbar.find('.NB-taskbar').append($add);
            $add.animate({'opacity': 1}, {'duration': 600});
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
            
            $module.addClass('NB-loading');
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
          clearInterval(this.locks.load_dashboard_graphs);
          if (!NEWSBLUR.Globals.debug) {
              this.locks.load_dashboard_graphs = setInterval(_.bind(function() {
                  this.load_dashboard_graphs();
              }, this), NEWSBLUR.Globals.is_staff ? 60*1000 : 10*60*1000);
          }
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
          clearInterval(this.locks.load_feedback_table);
          if (!NEWSBLUR.Globals.debug) {
              this.locks.load_feedback_table = setInterval(_.bind(function() {
                  this.load_feedback_table();
              }, this), NEWSBLUR.Globals.is_staff ? 60*1000 : 10*60*1000);
          }
        },
        
        load_feedback_table: function() {
            var self = this;
            var $module = $('.NB-feedback-table');
            $module.addClass('NB-loading');
            
            this.model.load_feedback_table(function(resp) {
                if (!resp) return;
                $module.removeClass('NB-loading');
                $module.replaceWith(resp);
                self.load_javascript_elements_on_page();
            }, $.noop);
        },
        
        // ===================
        // = Unfetched Feeds =
        // ===================
        
        setup_unfetched_feed_check: function() {
            this.locks.unfetched_feed_check = setInterval(_.bind(function() {
                var unfetched_feeds = NEWSBLUR.assets.unfetched_feeds();
                if (unfetched_feeds.length) {
                    _.each(unfetched_feeds, _.bind(function(feed) {
                        this.force_instafetch_stories(feed.id);
                    }, this));
                }
            }, this), 60*10*1000);
        },
        
        // ==========
        // = Events =
        // ==========

        handle_clicks: function(elem, e) {
            var self = this;
            var stopPropagation = false;
            
            // NEWSBLUR.log(['click', e, e.button]);

            // Feeds ==========================================================
                        
            // ============
            // = Feed Bar =
            // ============
            
            $.targetIs(e, { tagSelector: '.NB-feedbar-mark-feed-read' }, function($t, $p){
                e.preventDefault();
                var feed_id = parseInt($t.closest('.feed').data('id'), 10);
                self.mark_feed_as_read(feed_id, $t);
                $t.fadeOut(400);
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
            
            // = Stories ======================================================
            
            
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-intro' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_intro_modal();
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
                self.manage_menu_move_folder(folder_name, $folder);
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-controls' }, function($t, $p){
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-share' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                if ($t.hasClass('NB-menu-manage-story-share-cancel')) {
                    self.hide_confirm_story_share_menu_item();
                } else {
                    self.show_confirm_story_share_menu_item();
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
                var folder = NEWSBLUR.assets.folders.get_view($folder).model;
                self.mark_folder_as_read(folder);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-folder-subscribe' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                self.open_add_feed_modal({folder_title: folder_name});
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-open' }, function($t, $p){
                e.preventDefault();
                if (!self.flags['showing_confirm_input_on_manage_menu']) {
                    var story_id = $t.closest('.NB-menu-manage-story').data('story_id');
                    var story = self.model.get_story(story_id);
                    story.story_view.open_story_in_new_tab();
                }
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage-story-star' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-menu-manage-story').data('story_id');
                var story_view = NEWSBLUR.assets.get_story(story_id).story_view;
                story_view.star_story();
            });
            $.targetIs(e, { tagSelector: '.NB-menu-manage-site-mark-read' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_mark_read_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-social-profile' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                self.open_social_profile_modal(feed_id);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-controls-feed .NB-menu-manage-view-setting-order li' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                if ($t.hasClass('NB-view-setting-order-oldest')) {
                    self.change_view_setting(feed_id, {order: 'oldest'}, $feed);
                } else {
                    self.change_view_setting(feed_id, {order: 'newest'}, $feed);
                }
            }); 
            $.targetIs(e, { tagSelector: '.NB-menu-manage-controls-folder .NB-menu-manage-view-setting-order li' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                if ($t.hasClass('NB-view-setting-order-oldest')) {
                    self.change_view_setting('river:'+folder_name, {order: 'oldest'}, $folder);
                } else {
                    self.change_view_setting('river:'+folder_name, {order: 'newest'}, $folder);
                }
            }); 
            $.targetIs(e, { tagSelector: '.NB-menu-manage-controls-feed .NB-menu-manage-view-setting-readfilter li' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                var $feed = $t.parents('.NB-menu-manage').data('$feed');
                if ($t.hasClass('NB-view-setting-readfilter-unread')) {
                    self.change_view_setting(feed_id, {read_filter: 'unread'}, $feed);
                } else {
                    self.change_view_setting(feed_id, {read_filter: 'all'}, $feed);
                }
            }); 
            $.targetIs(e, { tagSelector: '.NB-menu-manage-controls-folder .NB-menu-manage-view-setting-readfilter li' }, function($t, $p){
                e.preventDefault();
                var folder_name = $t.parents('.NB-menu-manage').data('folder_name');
                var $folder = $t.parents('.NB-menu-manage').data('$folder');
                if ($t.hasClass('NB-view-setting-readfilter-unread')) {
                    self.change_view_setting('river:'+folder_name, {read_filter: 'unread'}, $folder);
                } else {
                    self.change_view_setting('river:'+folder_name, {read_filter: 'all'}, $folder);
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
                self.open_feed_exception_modal(feed_id);
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-goodies' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_goodies_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-friends' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_friends_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-profile-editor' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_profile_editor_modal();
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
                    self.open_intro_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-module-gettingstarted-hide' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.check_hide_getting_started(true);
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
                var story_id = $t.closest('.NB-menu-manage').data('story_id');
                var story = self.model.get_story(story_id);
                NEWSBLUR.assets.stories.mark_unread(story);
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
                NEWSBLUR.app.original_tab_view.load_feed_iframe();
            });         
            $.targetIs(e, { tagSelector: '.NB-task-feed-settings' }, function($t, $p){
                e.preventDefault();
                self.open_feed_exception_modal();
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
            $.targetIs(e, { tagSelector: '.NB-intelligence-slider-control' }, function($t, $p){
                e.preventDefault();
                var unread_value;
                if ($t.hasClass('NB-intelligence-slider-red')) {
                    unread_value = -1;
                } else if ($t.hasClass('NB-intelligence-slider-yellow')) {
                    unread_value = 0;
                } else if ($t.hasClass('NB-intelligence-slider-green')) {
                    unread_value = 1;
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
            
            // = Interactions Module ==========================================
            
            $.targetIs(e, { tagSelector: '.NB-interaction-username, .NB-interaction-follow .NB-interaction-photo' }, function($t, $p){
                e.preventDefault();
                var user_id = $t.data('userId');
                var username = $t.closest('.NB-interaction').find('.NB-interaction-username').text();
                self.model.add_user_profiles([{user_id: user_id, username: username}]);
                self.open_social_profile_modal(user_id);
            }); 
            $.targetIs(e, { tagSelector: '.NB-interaction-comment_reply .NB-interaction-reply-content, .NB-interaction-reply_reply .NB-interaction-reply-content, .NB-interaction-comment_reply .NB-interaction-photo' }, function($t, $p){
                e.preventDefault();
                var $interaction = $t.closest('.NB-interaction');
                var feed_id = $interaction.data('feedId');
                var story_id = $interaction.data('contentId');
                var user_id = $interaction.data('userId');
                var username = $interaction.data('username');
                
                self.close_social_profile();
                if (self.model.get_feed(feed_id)) {
                    self.open_social_stories(feed_id, {'story_id': story_id});
                } else {
                    var socialsub = self.model.add_social_feed({
                        id: feed_id, 
                        user_id: user_id, 
                        username: username
                    });
                    self.load_social_feed_in_tryfeed_view(socialsub, {'story_id': story_id});
                }
            }); 
            
            // = Activities Module ==========================================
            
            $.targetIs(e, { tagSelector: '.NB-interaction-starred-story-title,.NB-activity-star .NB-interaction-photo' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.closest('.NB-interaction').data('contentId');
                
                self.close_social_profile();
                self.open_starred_stories({'story_id': story_id});
            }); 
            $.targetIs(e, { tagSelector: '.NB-interaction-feed-title,.NB-activity-feedsub .NB-interaction-photo' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.closest('.NB-interaction').data('feedId');
                
                self.close_social_profile();
                self.open_feed(feed_id);
            }); 
            $.targetIs(e, { tagSelector: '.NB-interaction-sharedstory .NB-interaction-sharedstory-title, .NB-interaction-sharedstory .NB-interaction-sharedstory-content, .NB-interaction-sharedstory .NB-interaction-photo, .NB-activity-sharedstory .NB-interaction-sharedstory-title, .NB-activity-sharedstory .NB-interaction-sharedstory-content, .NB-activity-sharedstory .NB-interaction-photo, .NB-interaction-comment_like .NB-interaction-sharedstory-title, .NB-activity-comment_like .NB-interaction-sharedstory-title' }, function($t, $p){
                e.preventDefault();
                var $interaction = $t.closest('.NB-interaction');
                var feed_id = $interaction.data('feedId');
                var story_id = $interaction.data('contentId');
                var user_id = $interaction.data('userId');
                
                self.close_social_profile();
                if ($t.hasClass('NB-interaction-sharedstory-content')) {
                    self.open_social_stories('social:'+user_id, {'story_id': story_id});
                } else {
                    self.open_feed(feed_id, {
                        'story_id': story_id, 
                        'scroll_to_comments': true,
                        'feed': new NEWSBLUR.Models.Feed({
                            'feed_title': $('.NB-interaction-sharedstory-title', $interaction).text(),
                            'favicon_url': $('.NB-interaction-photo', $interaction).attr('src')
                        })
                    });
                }
            }); 
            $.targetIs(e, { tagSelector: '.NB-activity-comment_reply .NB-interaction-reply-content, .NB-activity-comment_reply .NB-interaction-photo, .NB-interaction-comment_like .NB-interaction-content, .NB-interaction-comment_like .NB-interaction-photo, .NB-activity-comment_like .NB-interaction-content, .NB-activity-comment_like .NB-interaction-photo' }, function($t, $p){
                e.preventDefault();
                var $interaction = $t.closest('.NB-interaction');
                var user_id = $interaction.hasClass('NB-interaction-comment_like') ?
                                NEWSBLUR.Globals.user_id : 
                                $interaction.data('userId');
                var feed_id = 'social:' + user_id;
                var story_id = $interaction.data('contentId');
                var username = $interaction.data('username');
                
                self.close_social_profile();
                if (self.model.get_feed(feed_id)) {
                    self.open_social_stories(feed_id, {
                        'story_id': story_id,
                        'scroll_to_comments': true
                    });
                } else {
                    var socialsub = self.model.add_social_feed({
                        id: feed_id, 
                        user_id: user_id, 
                        username: username
                    });
                    self.load_social_feed_in_tryfeed_view(socialsub, {'story_id': story_id});
                }
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
            $.targetIs(e, { tagSelector: '.NB-module-next-page', childOf: '.NB-module-interactions' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.load_interactions_page(1);
                }
            }); 
            $.targetIs(e, { tagSelector: '.NB-module-previous-page', childOf: '.NB-module-interactions' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.load_interactions_page(-1);
                }
            });
            $.targetIs(e, { tagSelector: '.NB-module-next-page', childOf: '.NB-module-activities' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.load_activities_page(1);
                }
            }); 
            $.targetIs(e, { tagSelector: '.NB-module-previous-page', childOf: '.NB-module-activities' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.load_activities_page(-1);
                }
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
            $document.bind('keydown', '/', function(e) {
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
                NEWSBLUR.app.story_tab_view.open_story(null, true);
            });
            $document.bind('keydown', 'return', function(e) {
                e.preventDefault();
                NEWSBLUR.app.story_tab_view.open_story(null, true);
            });
            $document.bind('keydown', 'space', function(e) {
                e.preventDefault();
                self.page_in_story(0.4, 1);
            });
            $document.bind('keydown', 'shift+space', function(e) {
                e.preventDefault();
                self.page_in_story(0.65, -1);
            });
            $document.bind('keydown', 'shift+u', function(e) {
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
            $document.bind('keydown', 'c', function(e) {
                e.preventDefault();
                NEWSBLUR.app.story_list.scroll_to_selected_story(self.active_story, {
                    scroll_to_comments: true,
                    scroll_offset: -50
                });
            });
            $document.bind('keydown', 'm', function(e) {
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
                    var story_view = NEWSBLUR.assets.get_story(story_id).story_view;
                    story_view.star_story();
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
            $document.bind('keypress', 'a', function(e) {
                e.preventDefault();
                self.open_add_feed_modal();
            });
            $document.bind('keypress', 'f', function(e) {
                e.preventDefault();
                self.open_feed_intelligence_modal(1);
            });
            $document.bind('keypress', 'o', function(e) {
                e.preventDefault();
                var story_id = self.active_story;
                if (!story_id) return;
                var story = self.model.get_story(story_id);
                story.story_view.open_story_in_new_tab();
            });
            $document.bind('keypress', 'e', function(e) {
                e.preventDefault();
                var story_id = self.active_story;
                if (!story_id) return;
                self.send_story_to_email(story_id);
            });
            $document.bind('keydown', 'shift+a', function(e) {
                e.preventDefault();
                if (self.flags.social_view) {
                    self.mark_feed_as_read();
                } else if (self.flags.river_view) {
                    self.mark_folder_as_read();
                } else {
                    self.mark_feed_as_read();
                }
            });
            $document.bind('keydown', 'shift+e', function(e) {
                e.preventDefault();
                self.open_river_stories();
            });
            $document.bind('keydown', 'u', function(e) {
                e.preventDefault();
                if (!self.active_story) return;
                var story_id = self.active_story.id;
                var story = self.model.get_story(story_id);
                if (self.active_story && !self.active_story.get('read_status')) {
                    NEWSBLUR.assets.stories.mark_read(story, {skip_delay: true});
                } else if (self.active_story && self.active_story.get('read_status')) {
                    NEWSBLUR.assets.stories.mark_unread(story);
                }
            });
            $document.bind('keydown', 'shift+s', function(e) {
                e.preventDefault();
                if (self.active_story) {
                    var $story_title = self.active_story.story_title_view.$el;
                    self.active_story.story_title_view.mouseenter_manage_icon();
                    self.show_manage_menu('story', $story_title, {story_id: self.active_story.id});
                    self.show_confirm_story_share_menu_item(self.active_story.id);
                }
            });
        }
        
    });

})(jQuery);