(function($) {
    
    NEWSBLUR.Reader = function() {
        var self = this;
        this.$feed_list = $('#feed_list');
        this.$story_titles = $('#story_titles');
        this.$story_pane = $('#story_pane .NB-story-pane-container');
        this.$account_menu = $('.menu_button');
        this.$feed_view = $('.NB-feed-story-view');
        this.$story_iframe = $('.NB-feed-frame');
        this.$intelligence_slider = $('.NB-intelligence-slider');

        this.model = NEWSBLUR.AssetModel.reader();
        this.options = {};
        this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
        this.story_view = 'page';
        
        this.flags = {
            'feed_view_images_loaded': {},
            'bouncing_callout': false
        };
        this.locks = {};
        this.cache = {
            'iframe_stories': {},
            'feed_view_stories': {},
            'iframe_story_positions': {},
            'feed_view_story_positions': {},
            'iframe_story_positions_keys': [],
            'feed_view_story_positions_keys': []
        };
        
        $('body').bind('dblclick.reader', $.rescope(this.handle_dblclicks, this));
        $('body').bind('click.reader', $.rescope(this.handle_clicks, this));
        $('#story_titles').scroll($.rescope(this.handle_scroll_story_titles, this));
        this.$feed_view.scroll($.rescope(this.handle_scroll_feed_view, this));
                
        this.load_feeds();
        this.apply_resizable_layout();
        this.cornerize_buttons();
        this.handle_keystrokes();
        this.setup_feed_page_iframe_load();
        this.load_intelligence_slider();
        this.setup_feed_refresh();
    };

    NEWSBLUR.Reader.prototype = {
        
        // =================
        // = Node Creation =
        // =================
        
        make_story_title: function(story) {
            var unread_view = NEWSBLUR.Globals.unread_view;
            var read = story.read_status
                ? 'read'
                : '';
            var score = this.compute_story_score(story);
            var score_color = 'neutral';
            if (score > 0) score_color = 'positive';
            if (score < 0) score_color = 'negative';
            var $story_tags = $.make('span', { className: 'NB-storytitles-tags'});
            
            for (var t in story.story_tags) {
                var tag = story.story_tags[t];
                var $tag = $.make('span', { className: 'NB-storytitles-tag'}, tag).corner('4px');
                $story_tags.append($tag);
                break;
            }
            var $story_title = $.make('div', { className: 'story ' + read + ' NB-story-' + score_color }, [
                $.make('a', { href: story.story_permalink, className: 'story_title' }, [
                    $.make('span', { className: 'NB-storytitles-title' }, story.story_title),
                    $.make('span', { className: 'NB-storytitles-author' }, story.story_authors),
                    $story_tags
                ]),
                $.make('span', { className: 'story_date' }, story.short_parsed_date),
                $.make('span', { className: 'story_id' }, ''+story.id),
                $.make('div', { className: 'NB-story-sentiment NB-story-like' }),
                $.make('div', { className: 'NB-story-sentiment NB-story-dislike' })
            ]).data('story_id', story.id);
            
            if (unread_view > score) {
                $story_title.css({'display': 'none'});
            }
            
            return $story_title;
        },
        
        compute_story_score: function(story) {
            var score = 0;
            var score_max = Math.max(story.intelligence['title'],
                                     story.intelligence['author'],
                                     story.intelligence['tags']);
            var score_min = Math.min(story.intelligence['title'],
                                     story.intelligence['author'],
                                     story.intelligence['tags']);
            if (score_max > 0) score = score_max;
            else if (score_min < 0) score = score_min;
            
            if (score == 0) score = story.intelligence['feed'];
            
            return score;
        },
        
        // ========
        // = Page =
        // ========
                
        apply_resizable_layout: function() {
            var outerLayout, rightLayout, contentLayout, leftLayout;
            
        	outerLayout = $('body').layout({ 
        	    closable: true,
    			center__paneSelector:	".right-pane",
    			west__paneSelector:		".left-pane",
    			west__size:				240,
    			west__onresize:         "leftLayout.resizeAll",
    			center__onresize:       "rightLayout.resizeAll",
    			spacing_open:			4,
    			resizerDragOpacity:     0.6,
    			findNestedContent:      true
    		}); 
    		
    		leftLayout = $('.left-pane').layout({
        	    closable:               false,
    		    center__paneSelector:   ".left-center",
    		    center__resizable:      false,
    			south__paneSelector:	".left-south",
    			south__size:            30,
    			south__resizable:       false,
    			south__spacing_open:    0
    		});

    		rightLayout = $('.right-pane').layout({ 
    			south__paneSelector:	".right-north",
    			center__paneSelector:	".content-pane",
    			center__onresize:       "contentLayout.resizeAll",
    			south__onresize:        "contentLayout.resizeAll",
    			south__size:			168,
    			spacing_open:			10,
    			resizerDragOpacity:     0.6
    		}); 

    		contentLayout = $('.content-pane').layout({ 
    			center__paneSelector:	".content-center",
    			south__paneSelector:	".content-north",
    			south__size:            30,
    			spacing_open:           0,
    			resizerDragOpacity:     0.6
    		}); 
    		
    		$('.right-pane').hide();
        },
        
        resize_story_content_pane: function() {
            var doc_height = $(document).height();
            var stories_pane_height = this.$story_titles.height();
            var story_content_top = parseInt(this.$story_titles.css('top'), 10);
            
            var new_story_pane_height = doc_height - (stories_pane_height + story_content_top);
            this.$story_pane.css('height', new_story_pane_height);
        },
        
        resize_feed_list_pane: function() {
            var doc_height = $(document).height();
            var feed_list_top = parseInt($('#feed_list').css('top'), 10);
            
            var new_feed_list_height = doc_height - feed_list_top;
            $('#feed_list').css('height', new_feed_list_height);
        },
        
        capture_window_resize: function() {
            var self = this,
                resizeTimer;
                
            $(window).bind('resize', function() {
                if (resizeTimer) clearTimeout(resizeTimer);
                resizeTimer = setTimeout(function() {
                    self.resize_story_content_pane();
                    self.resize_feed_list_pane();
                }, 10);
            });    
        },
        
        cornerize_buttons: function() {
            $('.button').corner();
        },
        
        handle_keystrokes: function() {      
            var self = this;                                                           
            $(document).bind('keydown', 'down', function(e) {
                e.preventDefault();
                self.show_next_story(1);
            });
            $(document).bind('keydown', 'up', function(e) {
                e.preventDefault();
                self.show_next_story(-1);
            });                                                           
            $(document).bind('keydown', 'j', function(e) {
                e.preventDefault();
                self.show_next_story(-1);
            });
            $(document).bind('keydown', 'k', function(e) {
                e.preventDefault();
                self.show_next_story(1);
            });
            $(document).bind('keydown', 'left', function(e) {
                e.preventDefault();
                self.switch_taskbar_view_direction(-1);
            });
            $(document).bind('keydown', 'right', function(e) {
                e.preventDefault();
                self.switch_taskbar_view_direction(1);
            });
            $(document).bind('keydown', 'space', function(e) {
                e.preventDefault();
                self.page_in_story(0.4, 1);
            });
            $(document).bind('keydown', 'shift+space', function(e) {
                e.preventDefault();
                self.page_in_story(0.4, -1);
            });
        },
        
        hide_splash_page: function() {
            $('.right-pane').show();
            $('#NB-splash').hide();
            $('#NB-splash-overlay').hide();
        },
        
        show_splash_page: function() {
            $('.right-pane').hide();
            $('#NB-splash').show();
            $('#NB-splash-overlay').show();
        },
        
        // ==============
        // = Navigation =
        // ==============
        
        show_next_story: function(direction) {
            var $current_story = $('.selected', this.$story_titles);
            var $next_story;
            
            if (!$current_story.length) {
                $current_story = $('.story:first', this.$story_titles);
                $next_story = $current_story;
            } else if (direction == 1) {
                $next_story = $current_story.nextAll('.story:visible').eq(0);
            } else if (direction == -1) {
                $next_story = $current_story.prevAll('.story:visible').eq(0);
            }

            var story_id = $next_story.data('story_id');
            if (story_id) {
                var story = this.find_story_in_stories(story_id);
                this.open_story(story, $next_story);
                this.scroll_story_titles_to_show_selected_story_title($next_story);
            }
            
        },
        
        show_next_unread_story: function(second_pass) {
            var $current_story = $('.selected', this.$story_titles);
            var $next_story;
            var unread_count = this.get_unread_count(true);
            
            if (unread_count) {
                if (!$current_story.length) {
                    // Nothing selected, choose first unread.
                    $next_story = $('.story:not(.read):visible:first', this.$story_titles);
                } else {
                    // Start searching below, then search above current story.
                    $next_story = $current_story.nextAll('.story:not(.read):visible').eq(0);
                    if (!$next_story.length) {
                        $next_story = $current_story.prevAll('.story:not(.read):visible').eq(0);
                    }
                }
                
                if ($next_story && $next_story.length) {
                    var story_id = $next_story.data('story_id');
                    if (story_id) {
                        var story = this.find_story_in_stories(story_id);
                        this.push_current_story_on_history();
                        this.open_story(story, $next_story);
                        this.scroll_story_titles_to_show_selected_story_title($next_story);
                    }
                } else if (!second_pass) {
                    // Nothing up, nothing down, but still unread. Load 1 page then find it.
                    this.flags['find_next_unread_on_page_of_feed_stories_load'] = true;
                    this.load_page_of_feed_stories();
                }
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
                    var story = this.find_story_in_stories(story_id);
                    this.open_story(story, $previous_story);
                    this.scroll_story_titles_to_show_selected_story_title($previous_story);
                }
            }
        },
        
        scroll_story_titles_to_show_selected_story_title: function($story) {
            var story_title_visisble = this.$story_titles.isScrollVisible($story);
            if (!story_title_visisble) {
                var container_offset = this.$story_titles.position().top;
                var scroll = $story.position().top;
                var container = this.$story_titles.scrollTop();
                var height = this.$story_titles.outerHeight();
                this.$story_titles.scrollTop(scroll+container-height/5);
            }    
        },
        
        show_next_feed: function(direction) {
            var $current_feed = $('.selected', this.$feed_list);
            var $next_feed,
                scroll;
            
            if (!$current_feed.length) {
                $current_feed = $('.feed:first', this.$feed_list);
                $next_feed = $current_feed;
            } else if (direction == 1) {
                $next_feed = $current_feed.next('.feed');
            } else if (direction == -1) {
                $next_feed = $current_feed.prev('.feed');
            }
            
            if (!$next_feed.length) {
                if (direction == 1) {
                    $next_feed = $current_feed.parents('.folder').next('.folder').find('.feed:first');
                } else if (direction == -1) {
                    $next_feed = $current_feed.parents('.folder').prev('.folder').find('.feed:last');
                }
            }
            
            var feed_id = $next_feed.data('feed_id');
            if (feed_id) {
                var position = this.$feed_list.scrollTop() + $next_feed.offset().top - $next_feed.outerHeight();
                var showing = this.$feed_list.height();
                if (position > showing) {
                    scroll = position;
                } else {
                    scroll = 0;
                }
                this.$feed_list.scrollTop(scroll);
                this.open_feed(feed_id, $next_feed);
            }
        },
        
        navigate_story_titles_to_story: function(story) {
            var $next_story = this.find_story_in_story_titles(story);
            if ($next_story && $next_story.length && $next_story.is(':visible') && !$next_story.hasClass('selected')) {
                // NEWSBLUR.log(['navigate_story_titles_to_story', story, $next_story]);
                
                this.push_current_story_on_history();
                this.scroll_story_titles_to_show_selected_story_title($next_story);
                this.open_story(story, $next_story, true);
            }
        },
        
        page_in_story: function(amount, direction) {
            var page_height = this.$story_pane.height();
            var scroll_height = parseInt(page_height * amount, 10);
            var dir = '+';
            if (direction == -1) {
                dir = '-';
            }
            // NEWSBLUR.log(['page_in_story', this.$story_pane, direction, page_height, scroll_height]);
            if (this.story_view == 'page') {
                this.$story_iframe.scrollTo({top:dir+'='+scroll_height, left:'+=0'}, 150);
            } else if (this.story_view == 'feed' || this.story_view == 'story') {
                this.$feed_view.scrollTo({top:dir+'='+scroll_height, left:'+=0'}, 150);
            }
        },
        
        push_current_story_on_history: function() {
            var $current_story = $('.selected', this.$story_titles);
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
                this.model.load_feeds($.rescope(this.make_feeds, this));
            }
        },
        
        make_feeds: function() {
            var $feed_list = this.$feed_list.empty();
            var folders = this.model.folders;
            var feeds = this.model.feeds;
            // NEWSBLUR.log(['Making feeds', {'folders': folders, 'feeds': feeds}]);
            
            $('#story_taskbar').css({'display': 'block'});

            var $folder = this.make_feeds_folder(folders);
            $feed_list.append($folder);
            $('.unread_count', $feed_list).corner('4px');
            
            if (!$folder.length) {
                this.load_feed_browser();
                this.setup_ftux_add_feed_callout();
            } else {
                $('.NB-task-manage').removeClass('NB-disabled');
                $('.NB-callout-ftux').fadeOut(500);
            }
        },
        
        make_feeds_folder: function(items) {
            var $feeds = $.make('div');
            
            for (var i in items) {
                var item = items[i];

                if (typeof item == "number") {
                    var feed = this.model.feeds[item];
                    var $feed = this.make_feed_title_line(feed, true);
                    $feeds.append($feed);
                } else if (typeof item == "object") {
                    for (var o in item) {
                        var folder = item[o];
                        var $folder = $.make('li', { className: 'folder' }, [
                            $.make('ul', { className: 'folder' }, [
                                $.make('li', { className: 'folder_title' }, o),
                                this.make_feeds_folder(folder)
                            ])
                        ]);
                        $feeds.append($folder);
                    }
                }
            }
            
            $('.feed', $feeds).tsort('.feed_title');
            $('.folder', $feeds).tsort('.folder_title');
            
            return $feeds.children();
        },
        
        make_feed_title_line: function(feed, list_item) {
            var unread_class = '';
            if (feed.ps) {
                unread_class += ' unread_positive';
            }
            if (feed.nt) {
                unread_class += ' unread_neutral';
            }
            if (feed.ng) {
                unread_class += ' unread_negative';
            }
            var $feed = $.make((list_item?'li':'div'), { className: 'feed ' + unread_class }, [
                $.make('div', { className: 'feed_counts' }, [
                    $.make('div', { className: 'feed_counts_floater' }, [
                        $.make('span', { 
                            className: 'unread_count unread_count_positive '
                                        + (feed.ps
                                           ? "unread_count_full"
                                           : "unread_count_empty")
                        }, ''+feed.ps),
                        $.make('span', { 
                            className: 'unread_count unread_count_neutral '
                                        + (feed.nt
                                           ? "unread_count_full"
                                           : "unread_count_empty") 
                        }, ''+feed.nt),
                        $.make('span', { 
                            className: 'unread_count unread_count_negative '
                                        + (feed.ng
                                           ? "unread_count_full"
                                           : "unread_count_empty")
                        }, ''+feed.ng)
                    ])
                ]),
                $.make('img', { className: 'feed_favicon', src: this.google_favicon_url + feed.feed_link }),
                $.make('span', { className: 'feed_title' }, feed.feed_title),
                $.make('div', { className: 'NB-feedbar-manage-feed' }),
                $.make('div', { className: 'NB-feedbar-mark-feed-read' }, 'Mark All as Read')
            ]).data('feed_id', feed.id);  
            
            return $feed;  
        },
        
        delete_feed: function(feed_id) {
            var self = this;
            var $feeds = this.find_feed_in_feed_list(feed_id);
            
            if ($feeds.length) {
                $feeds.slideUp(500);
            }
            
            var feed_active = false;
            $feeds.each(function() {
                if (self.active_feed == $(this).data('feed_id')) {
                    feed_active = true;
                    return false;
                }
            });
            
            if (feed_active) {
                this.reset_feed();
                this.show_splash_page();
            }
        },
        
        find_feed_in_feed_list: function(feed_id) {
            var $feed_list = this.$feed_list;
            var $feeds = $([]);
            
            $('.feed', $feed_list).each(function() {
                if ($(this).data('feed_id') == feed_id) {
                    $feeds.push($(this).get(0));
                }
            });
            
            return $feeds;
        },
        
        // =====================
        // = Story Titles Pane =
        // =====================
        
        reset_feed: function() {
            this.flags.iframe_story_locations_fetched = false;
            this.flags.iframe_view_loaded = false;
            this.flags.feed_view_images_loaded = {};
            this.flags.feed_view_positions_calculated = false;
            this.flags.scrolling_by_selecting_story_title = false;
            this.flags.switching_to_feed_view = false;
            this.flags.find_next_unread_on_page_of_feed_stories_load = false;
            this.flags.page_view_showing_feed_view = false;
            this.flags.iframe_fetching_story_locations = false;
            
            
            this.cache = {
                'iframe_stories': {},
                'feed_view_stories': {},
                'iframe_story_positions': {},
                'feed_view_story_positions': {},
                'iframe_story_positions_keys': [],
                'feed_view_story_positions_keys': [],
                'previous_stories_stack': []
            };
            
            this.active_feed = null;
            this.$story_titles.data('page', 0);
            this.$story_titles.data('feed_id', null);
        },
        
        open_feed: function(feed_id, $feed_link) {
            var self = this;
            var $story_titles = this.$story_titles;
            this.flags['opening_feed'] = true;
            
            if (feed_id != this.active_feed) {
                $story_titles.empty().scrollTop('0px');
                this.reset_feed();
                this.hide_splash_page();
            
                this.active_feed = feed_id;
                this.$story_titles.data('page', 0);
                this.$story_titles.data('feed_id', feed_id);
                this.iframe_scroll = null;
                this.story_view = 'page'; // TODO: Grab from preferences.
            
                this.show_feed_title_in_stories($story_titles, feed_id);
                this.mark_feed_as_selected(feed_id, $feed_link);
                this.show_feedbar_loading();
                this.make_content_pane_feed_counter(feed_id);
                this.switch_taskbar_view(this.story_view);
                // NEWSBLUR.log(['open_feed', this.flags, this.active_feed, feed_id]);
                this.model.load_feed(feed_id, 0, true, $.rescope(this.post_open_feed, this));
                this.load_iframe(feed_id);
                this.flags['opening_feed'] = false;
            }
        },
        
        post_open_feed: function(e, data, first_load) {
            var stories = data.stories;
            var tags = data.tags;
            var feed_id = this.active_feed;
            var $iframe = this.$story_iframe.contents();
            
            for (var s in stories) {
                feed_id = stories[s].story_feed_id;
                break;
            }
            
            if (this.active_feed == feed_id) {
                // NEWSBLUR.log(['post_open_feed', data.stories, this.flags]);
                this.flags['feed_view_positions_calculated'] = false;
                this.story_titles_clear_loading_endbar();
                this.create_story_titles(stories);
                this.hover_over_story_titles();
                this.make_story_feed_entries(stories, first_load);
                this.show_correct_stories_in_page_and_feed_view();
                if (this.flags['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                }
                if (!first_load) {
                    var stories_count = this.cache['iframe_story_positions_keys'].length;
                    this.flags.iframe_story_locations_fetched = false;
                    this.fetch_story_locations_in_story_frame(stories_count, true, $iframe);
                } else {
                    this.prefetch_story_locations_in_story_frame($iframe);
                }
            }
        },
        
        make_content_pane_feed_counter: function(feed_id) {
            var $content_pane = $('.content-pane');
            var feed = this.model.get_feed(feed_id);
            var $counter = this.make_feed_title_line(feed);
            
            $('.feed', $content_pane).remove();
            $('#story_taskbar', $content_pane).append($counter);
            
            $('.unread_count', $content_pane).corner('4px');
            
            // Center the counter
            var i_width = $('.feed', $content_pane).width();
            var o_width = $content_pane.width();
            var left = (o_width / 2.0) - (i_width / 2.0);
            $('.feed', $content_pane).css({'left': left});
        },
        
        create_story_titles: function(stories) {
            var $story_titles = this.$story_titles;
            
            for (s in stories) {
                var story = stories[s];
                var $story_title = this.make_story_title(story);
                if (!stories[s].read_status) {
                    var $mark_read = $.make('a', { className: 'mark_story_as_read', href: '#'+stories[s].id }, '[Mark Read]');
                    $story_title.find('.title').append($mark_read);
                }
                $story_titles.append($story_title);
            }
            // NEWSBLUR.log(['create_story_titles', stories]);
            if (!stories || stories.length == 0) {
                var $end_stories_line = $.make('div', { 
                    className: 'NB-story-titles-end-stories-line'
                });
                
                if (!($('.NB-story-titles-end-stories-line', $story_titles).length)) {
                    $story_titles.append($end_stories_line);
                }
            }
        },
        
        story_titles_clear_loading_endbar: function() {
            var $story_titles = this.$story_titles;
            
            var $endbar = $('.NB-story-titles-end-stories-line', $story_titles);
            if ($endbar.length) {
                $endbar.remove();
                clearInterval(this.feed_stories_loading);
            }
        },
        
        make_story_feed_entries: function(stories, first_load) {
            var $feed_view = this.$feed_view;
            var self = this;
            var unread_view = NEWSBLUR.Globals.unread_view;
            var $stories;
            
            if (first_load) {
                $stories = $.make('ul', { className: 'NB-feed-stories' });
                $feed_view.empty();
                $feed_view.scrollTop('0px');
                $feed_view.append($stories);
            } else {
                $stories = $('.NB-feed-stories', $feed_view);
                $('.NB-feed-story-endbar', $feed_view).remove();
            }

            for (var s in stories) {
                var story = stories[s];
                var read = story.read_status
                    ? 'read'
                    : '';
                var score = this.compute_story_score(story);
                var score_color = 'neutral';
                if (score > 0) score_color = 'positive';
                if (score < 0) score_color = 'negative';

                var $story = $.make('li', { className: 'NB-feed-story ' + read + ' NB-story-' + score_color }, [
                    $.make('div', { className: 'NB-feed-story-header' }, [
                        $.make('div', { className: 'NB-feed-story-sentiment' }),
                        ( story.story_authors &&
                            $.make('div', { className: 'NB-feed-story-author' }, story.story_authors)),
                        $.make('div', { className: 'NB-feed-story-title-container' }, [
                            $.make('div', { className: 'NB-feed-story-sentiment' }),
                            $.make('a', { className: 'NB-feed-story-title', href: unescape(story.story_permalink) }, story.story_title)
                        ]),
                        ( story.long_parsed_date &&
                            $.make('span', { className: 'NB-feed-story-date' }, story.long_parsed_date))
                    ]),
                    $.make('div', { className: 'NB-feed-story-content' }, story.story_content)                
                ]).data('story', story.id);
                $stories.append($story);
                
                this.cache.feed_view_stories[story.id] = $story;
                
                var image_count = $('img', $story).length;
                if (!image_count) {
                    this.flags.feed_view_images_loaded[story.id] = true;
                } else {
                    (function($story, story, image_count) {
                        $('img', $story).load(function() {
                            // NEWSBLUR.log(['Loaded image', $story, story, image_count]);
                            if (image_count == 1) {
                                self.flags.feed_view_images_loaded[story.id] = true;
                            } else {
                                image_count--;
                            }
                        });
                    })($story, story, image_count);
                }
            }
        },
        
        process_stories_location_in_feed_view: function(story_index, clear_cache) {
            var self = this;
            var stories = this.model.stories;
            
            if (clear_cache) {
                $.extend(this.cache, {
                    'feed_view_story_positions': {},
                    'feed_view_story_positions_keys': []
                });
            }
            
            if (!story_index) story_index = 0;

            if (stories[story_index] && stories[story_index]['story_feed_id'] == this.active_feed) {
                var story = stories[story_index];
                var $story = self.cache.feed_view_stories[story.id];
                
                // NEWSBLUR.log(['Appending $story', $story, self.flags.feed_view_images_loaded[story.id]]);
                if (self.flags.feed_view_images_loaded[story.id]) {
                    // NEWSBLUR.log(['Feed view story pre-loaded', $('img', $story).length + " images", $story, story_index]);
                    self.determine_feed_view_story_position($story, story);
                    self.process_stories_location_in_feed_view(story_index+1);
                } else {
                    // Images not all loaded yet, so wait until they do or timeout
                    (function($story, story, story_index) {
                        // In case the images don't load, move on to the next story
                        var story_load = setTimeout(function() {
                            // NEWSBLUR.log(['Feed view story did not load in time', $('img', $story).length + " images", $story, story_index]);
                            story_load = false;
                            self.determine_feed_view_story_position($story, story);
                            self.process_stories_location_in_feed_view(story_index+1);
                        }, 2000);
                        
                        // NEWSBLUR.log(['Feed view story not loaded', $('img', $story).length + " images", $story, story_index]);
                        // Load each image, loading next story on last image
                        var recheck = function() {
                            if (self.flags.feed_view_images_loaded[story.id] && story_load) {
                                // NEWSBLUR.log(['Feed view story finally loaded', $('img', $story).length + " images", $story, story_index]);
                                clearTimeout(story_load);
                                self.determine_feed_view_story_position($story, story);
                                self.process_stories_location_in_feed_view(story_index+1);
                            } else if (story_load) {
                                // NEWSBLUR.log(['Feed view story loading...', $('img', $story).length + " images", $story, story_index]);
                                setTimeout(recheck, 200);
                            }
                        };
                        
                        setTimeout(recheck, 200);
                        
                    })($story, story, story_index);
                }
            } else if (stories[story_index] 
                       && stories[story_index]['story_feed_id'] != this.active_feed) {
                NEWSBLUR.log(['Switched off feed early']);
            } else {
                self.flags['feed_view_positions_calculated'] = true;
                NEWSBLUR.log(['Feed view entirely loaded', stories.length + " stories"]);
                var $feed_view = this.$feed_view;
                var $stories = $('.NB-feed-stories', $feed_view);
                var $endbar = $.make('div', { className: 'NB-feed-story-endbar' });
                $stories.append($endbar);
            }
        },
        
        determine_feed_view_story_position: function($story, story) {
            if ($story.is(':visible')) {
                var position_original = parseInt($story.offset().top, 10);
                var position_offset = parseInt($story.offsetParent().scrollTop(), 10);
                var position = position_original + position_offset;
                this.cache.feed_view_story_positions[position] = story;
                this.cache.feed_view_story_positions_keys.push(position);
                this.cache.feed_view_story_positions_keys.sort(function(a,b) {return a>b;});    
                // NEWSBLUR.log(['Positioning story', position, $story, story, this.cache.feed_view_story_positions_keys]);
            }
        },
        
        // =======================
        // = iFrame -- Page View =
        // =======================
        
        load_iframe: function(feed_id) {
            var self = this;
            var $feed_view = this.$story_pane;
            var $story_iframe = this.$story_iframe;
            var $taskbar_view_page = $('.NB-taskbar .task_view_page');
            var $taskbar_return = $('.NB-taskbar .task_return');
            this.flags.iframe_view_loaded = false;
            this.flags.iframe_story_locations_fetched = false;
            
            $.extend(this.cache, {
                'iframe_stories': {},
                'iframe_story_positions': {},
                'iframe_story_positions_keys': []
            });
            
            if (!feed_id) {
                feed_id = $story_iframe.data('feed_id');
            } else {
                $story_iframe.data('feed_id', feed_id);
            }
            
            $taskbar_view_page.removeClass('NB-disabled');
            $taskbar_return.css({'display': 'none'});
            this.flags.iframe_scroll_snap_back_prepared = true;
            this.iframe_link_attacher_num_links = 0;
            
            $story_iframe.removeAttr('src').attr({src: '/reader/load_feed_page?feed_id='+feed_id});

            $story_iframe.ready(function() {
                self.flags.iframe_view_loaded = true;

                setTimeout(function() {
                    $story_iframe.load(function() {
                        if (self.iframe_scroll
                            && self.flags.iframe_scroll_snap_back_prepared 
                            && $story_iframe.contents().scrollTop() == 0) {
                            NEWSBLUR.log(['Snap back, loaded, scroll', self.iframe_scroll]);
                            $story_iframe.contents().scrollTop(self.iframe_scroll);
                            self.flags.iframe_scroll_snap_back_prepared = false;
                        }
                    });
                }, 50);
                
                // NEWSBLUR.log(['iFrame domain', $story_iframe.attr('src').indexOf('/reader/load_feed_page?feed_id='+feed_id), $story_iframe.attr('src')]);
                if ($story_iframe.attr('src').indexOf('/reader/load_feed_page?feed_id='+feed_id) != -1) {
                    var iframe_link_attacher = function() {
                        var num_links = $story_iframe.contents().find('a').length;
                        // NEWSBLUR.log(['Finding links', self.iframe_link_attacher_num_links, num_links]);
                        if (self.iframe_link_attacher_num_links != num_links) {
                            // NEWSBLUR.log(['Found new links', num_links, self.iframe_link_attacher_num_links]);
                            self.iframe_link_attacher_num_links = num_links;
                            $story_iframe.contents().find('a')
                                .unbind('click.NB-taskbar')
                                .bind('click.NB-taskbar', function() {
                                self.taskbar_show_return_to_page();
                            });
                        }
                    };
                    clearInterval(self.iframe_link_attacher);
                    self.iframe_link_attacher = setInterval(iframe_link_attacher, 2000);
                    iframe_link_attacher();
                    $story_iframe.load(function() {
                        clearInterval(self.iframe_link_attacher);
                    });
                }
            });
        },
        
        setup_feed_page_iframe_load: function() {
            var self = this;
            var $story_pane = this.$story_pane;
            var $story_iframe = this.$story_iframe;
                
            $story_iframe.removeAttr('src').load(function() {
                try {
                    $story_iframe.contents().find('a')
                        .unbind('click.NB-taskbar')
                        .bind('click.NB-taskbar', function(e) {
                        var href = $(this).attr('href');
                        if (href.indexOf('#') == 0) {
                            e.preventDefault();
                            var $footnote = $('a[name='+href.substr(1)+'], [id='+href.substr(1)+']',
                                              $story_iframe.contents());
                            // NEWSBLUR.log(['Footnote', $footnote, href, href.substr(1)]);
                            $story_iframe.contents().scrollTo($footnote, 600, { 
                                axis: 'y', 
                                easing: 'easeInOutQuint', 
                                offset: 0, 
                                queue: false 
                            });
                            return false;
                        }
                        self.taskbar_show_return_to_page();
                    });
                    self.$story_iframe.contents()
                        .unbind('scroll')
                        .scroll($.rescope(self.handle_scroll_story_iframe, self));
                    var $iframe = self.$story_iframe.contents();
                    self.fetch_story_locations_in_story_frame(0, true, $iframe);
                } catch(e) {
                    // Not on local domain. Ignore.
                }
            });
        },
        
        taskbar_show_return_to_page: function() {
            var self = this;
            var $story_iframe = $('.NB-feed-frame');

            setTimeout(function() {
                var $story_iframe = $('.NB-feed-frame');
                var $taskbar_return = $('.NB-taskbar .task_return');
                var $taskbar_view_page = $('.NB-taskbar .task_view_page');
        
                try {
                    var length = $story_iframe.contents().find('div').length;
                    if (length) {
                        return false;
                    }
                } catch(e) {
                    $taskbar_return.css({'display': 'block'});
                    $taskbar_view_page.addClass('NB-disabled');    
                } finally {
                    $taskbar_return.css({'display': 'block'});
                    $taskbar_view_page.addClass('NB-disabled');   
                }
            }, 500);
        },
        
        load_page_of_feed_stories: function() {
            var $feedbar;
            var $story_titles = this.$story_titles;
            var feed_id = $story_titles.data('feed_id');
            var page = $story_titles.data('page');
            
            if (!this.flags['opening_feed']) {
                this.show_feedbar_loading();
                $story_titles.data('page', page+1);
                this.model.load_feed(feed_id, page+1, false, 
                                     $.rescope(this.post_open_feed, this));                                 
            }
        },
        
        show_feedbar_loading: function() {
            var $story_titles = this.$story_titles;
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
        
        hover_over_story_titles: function() {
            var $story_titles = this.$story_titles;
            
            $('.story', $story_titles).each(function() {
                $(this)
                    .unbind('mouseenter')
                    .unbind('mouseleave');
            });
            $('.story', $story_titles)
                .hover(function() {
                    $(this).siblings('.story.NB-story-hover').removeClass('NB-story-hover');
                    $(this).addClass("NB-story-hover");
                }, function() {
                    $(this).siblings('.story.NB-story-hover').removeClass('NB-story-hover');
                    $(this).removeClass("NB-story-hover");                
                });
        },
        
        show_feed_title_in_stories: function($story_titles, feed_id) {
            var feed = this.model.get_feed(feed_id);

            var $feedbar = $.make('div', { className: 'NB-feedbar' }, [
                this.make_feed_title_line(feed),
                $.make('div', { className: 'NB-feedbar-intelligence' }, [
                    $.make('div', { className: 'NB-feed-sentiment NB-feed-like' }),
                    $.make('div', { className: 'NB-feed-sentiment NB-feed-dislike' })
                ]),
                $.make('span', { className: 'feed_id' }, ''+feed.id)
            ]).hover(function() {
                $(this).addClass('NB-feedbar-hover');
            },function() {
                $(this).removeClass('NB-feedbar-hover');
            });
            
            $story_titles.prepend($feedbar);
            $('.unread_count', $feedbar).corner('4px');
        },
        
        open_feed_link: function(feed_id, $fd) {
            this.mark_feed_as_read(feed_id);
            var feed = this.model.get_feed(feed_id);
            window.open(feed['feed_link'], '_blank');
            window.focus();
        },
        
        mark_feed_as_selected: function(feed_id, $feed_link) {
            $('#feed_list .selected').removeClass('selected');
            $('#feed_list .after_selected').removeClass('after_selected');
            $feed_link.addClass('selected');
            $feed_link.parent('.feed').next('.feed').children('a').addClass('after_selected');
        },
        
        open_feed_intelligence_modal: function(score) {
            var feed_id = this.active_feed;

            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierFeed(feed_id, score);
        },
        
        // ===================
        // = Taskbar - Story =
        // ===================
        
        switch_taskbar_view: function(view, story_not_found) {
            var self = this;
            var $story_pane = this.$story_pane;
            
            // NEWSBLUR.log(['$button', $button, this.flags['page_view_showing_feed_view'], $button.hasClass('NB-active'), story_not_found]);
            var $taskbar_buttons = $('.NB-taskbar .task_button_view');
            var $feed_view = this.$feed_view;
            var $story_iframe = this.$story_iframe;
            var $page_to_feed_arrow = $('.NB-taskbar .NB-task-view-page-to-feed-arrow');
            
            if (story_not_found) {
                $page_to_feed_arrow.show();
                this.flags['page_view_showing_feed_view'] = true;
            } else {
                $taskbar_buttons.removeClass('NB-active');
                $('.task_button_view.task_view_'+view).addClass('NB-active');
                $page_to_feed_arrow.hide();
                this.flags['page_view_showing_feed_view'] = false;
                this.story_view = view;
            }
            
            if (view == 'page') {
                $story_pane.animate({
                    'left': 0
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': 750,
                    'queue': false
                });
            } else if (view == 'feed') {
                $story_pane.animate({
                    'left': -1 * $story_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': 750,
                    'queue': false
                });
                
                this.flags['switching_to_feed_view'] = true;
                setTimeout(function() {
                    self.flags['switching_to_feed_view'] = false;
                }, 100);
                
                this.show_correct_stories_in_page_and_feed_view();

                var $current_story = this.get_current_story_from_story_titles();
                if ($current_story && $current_story.length) {
                    $feed_view.scrollTo($current_story, {'offset': 0, 'axis': 'y'});
                }
            } else if (view == 'story') {
                $story_pane.animate({
                    'left': -1 * $story_iframe.width()
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': 750,
                    'queue': false
                });
                
                this.show_correct_stories_in_page_and_feed_view();
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
        
        show_correct_stories_in_page_and_feed_view: function() {
            var $feed_view = this.$feed_view;
            var $feed_view_stories = $(".NB-feed-story", $feed_view);
            var $stories = $('.NB-feed-stories', $feed_view);
            var story = this.active_story;

            // NEWSBLUR.log(['Showing feed view', this.story_view, this.flags['page_view_showing_feed_view']]);
            if (this.story_view == 'page' && this.flags['page_view_showing_feed_view']) {
                this.show_correct_story_titles_in_unread_view({'animate': false});
            } else if (this.story_view == 'feed') {
                $stories.removeClass('NB-feed-view-story').addClass('NB-feed-view-feed');
                this.show_correct_story_titles_in_unread_view({'animate': false});
            } else if (this.story_view == 'story') {
                $stories.removeClass('NB-feed-view-feed').addClass('NB-feed-view-story');
                var $current_story = this.get_current_story_from_story_titles();
                $feed_view_stories.css({'display': 'none'});
                $feed_view.scrollTop('0px');
                if ($current_story && $current_story.length) {
                    $current_story.css({'display': 'block'});
                }
            }
        },
        
        get_current_story_from_story_titles: function() {
            var $feed_view = this.$feed_view;
            var $feed_view_stories = $(".NB-feed-story", $feed_view);
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
        
        // ==============
        // = Story Pane =
        // ==============
        
        open_story: function(story, $st, skip_scrolls) {
            var self = this;
            var feed_position;
            var iframe_position;
            
            if (this.active_story != story) {
                var $feed_story = this.find_story_in_feed_view(story);
                var $iframe_story = this.find_story_in_story_iframe(story);
                
                this.active_story = story;
                // NEWSBLUR.log(['Story', story, this.flags.iframe_view_loaded, skip_scrolls]);
            
                this.mark_story_title_as_selected($st);
                this.mark_story_as_read(story.id, $st);
            
                this.flags.scrolling_by_selecting_story_title = true;
                if (!skip_scrolls) {
                    // User clicks on story, scroll them to it.
                    if (!this.flags.iframe_view_loaded) {
                        // If the iframe has not yet loaded, we can't touch it.
                        // So just assume story not found.
                        this.switch_to_correct_view(false);
                        feed_position = this.scroll_to_story_in_story_feed(story, $feed_story);
                    } else {
                        iframe_position = this.scroll_to_story_in_iframe(story, $iframe_story);
                        this.switch_to_correct_view(iframe_position);
                        feed_position = this.scroll_to_story_in_story_feed(story, $feed_story);
                    }
                } else {
                    // User is scrolling the page. Just select in story titles.
                    if (this.story_view == 'page' && !this.flags['page_view_showing_feed_view']) {
                        feed_position = this.scroll_to_story_in_story_feed(story, $feed_story);
                    } else if (this.story_view == 'page' && this.flags['page_view_showing_feed_view']) {
                    
                    } else if (this.story_view == 'feed' || this.story_view == 'story') {
                        iframe_position = this.scroll_to_story_in_iframe(story, $iframe_story);
                    }
                    this.flags.scrolling_by_selecting_story_title = false;
                }
            }
            
            if (this.story_view == 'story') {
                // Show the correct story in the feed view. But other views don't need this.
                this.show_correct_stories_in_page_and_feed_view();
            }
            
            // NEWSBLUR.log(['Opening story', feed_position, iframe_position, feed_position in this.cache.feed_view_story_positions_keys, iframe_position in this.cache.iframe_story_positions_keys]);
            // if (feed_position && !(feed_position in this.cache.feed_view_story_positions_keys)) {
            //      this.process_stories_location_in_feed_view(0, true);
            // }
            // if (iframe_position && !(iframe_position in this.cache.iframe_story_positions_keys)) {
            //     this.fetch_story_locations_in_story_frame(0, true);
            // }
        },
        
        switch_to_correct_view: function(found_story_in_page) {
            // NEWSBLUR.log(['Found story', found_story_in_page, this.story_view, this.flags.iframe_view_loaded, this.flags['page_view_showing_feed_view']]);
            if (found_story_in_page === false) {
                // Story not found, show in feed view with link to page view
                if (this.story_view == 'page' && !this.flags['page_view_showing_feed_view']) {
                    this.flags['page_view_showing_feed_view'] = true;
                    this.switch_taskbar_view('feed', true);
                    this.show_correct_stories_in_page_and_feed_view();
                }
            } else {
                if (this.story_view == 'page' && this.flags['page_view_showing_feed_view']) {
                    this.flags['page_view_showing_feed_view'] = false;
                    this.switch_taskbar_view('page', false);
                }
            }

        },
        
        scroll_to_story_in_story_feed: function(story, $story) {
            var self = this;
            var $feed_view = this.$feed_view;

            // NEWSBLUR.log(['scroll_to_story_in_story_feed', story, $story]);

            if ($story && $story.length) {
                if (this.story_view == 'feed' || this.flags['page_view_showing_feed_view']) {
                    $feed_view.scrollable().stop();
                    $feed_view.scrollTo($story, 600, { axis: 'y', easing: 'easeInOutQuint', offset: 0, queue: false });
                } else if (this.story_view == 'page') {
                    $feed_view.scrollTo($story, 0, { axis: 'y', offset: 0 });
                }
            }
            clearInterval(this.locks.scrolling);
            this.locks.scrolling = setTimeout(function() {
                self.flags.scrolling_by_selecting_story_title = false;
            }, 1000);
            
            var parent_scroll = $story.parents('.NB-feed-story-view').scrollTop();
            var story_offset = $story.offset().top;
            return story_offset + parent_scroll;
        },
        
        find_story_in_feed_view: function(story) {
            var $feed_view = this.$feed_view;
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
        
        scroll_to_story_in_iframe: function(story, $story) {
            var $iframe = this.$story_iframe;

            if ($story && $story.length) {
                if (this.story_view == 'feed'
                    || this.story_view == 'story'
                    || this.flags['page_view_showing_feed_view']) {
                    $iframe.scrollTo($story, 0, { axis: 'y', offset: -24 });
                } else if (this.story_view == 'page') {
                    $iframe.scrollable().stop();
                    $iframe.scrollTo($story, 800, { axis: 'y', easing: 'easeInOutQuint', offset: -24, queue: false });
                }
                var parent_scroll = $story.parents('.NB-feed-story-view').scrollTop();
                var story_offset = $story.offset().top;
                return story_offset + parent_scroll;
            }

            return false;
        },
        
        prefetch_story_locations_in_story_frame: function($iframe) {
            var self = this;
            var stories = this.model.stories;
            if (!$iframe) $iframe = this.$story_iframe.contents();
            
            for (var s in stories) {
                var story = stories[s];
                var $story = this.find_story_in_story_iframe(story, $iframe);
                // NEWSBLUR.log(['Pre-fetching', $story, $iframe, story.story_title]);
                if (!$story || !$story.length || this.flags['iframe_fetching_story_locations']) break;
            }
            
            if (!this.flags['iframe_fetching_story_locations']) {
                setTimeout(function() {
                    self.prefetch_story_locations_in_story_frame($iframe);
                }, 1000);
            }
        },
        
        fetch_story_locations_in_story_frame: function(s, clear_cache, $iframe) {
            var self = this;
            var stories = this.model.stories;
            if (!s) s = 0;
            var story = stories[s];
            if (!$iframe) $iframe = this.$story_iframe.contents();
            
            this.flags['iframe_fetching_story_locations'] = true;
            
            if (clear_cache) {
                $.extend(this.cache, {
                    'iframe_stories': {},
                    'iframe_story_positions': {},
                    'iframe_story_positions_keys': []
                });
            }
            
            if (story && story['story_feed_id'] == this.active_feed) {
                var $story = this.find_story_in_story_iframe(story, $iframe);
                // NEWSBLUR.log(['Prefetching story', s, story.story_title, $story]);
                
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
                        self.flags.iframe_story_locations_fetched = false;
                    } else {
                        NEWSBLUR.log(['iFrame view entirely loaded', (s-2) + ' stories', self.cache.iframe_stories]);
                        self.flags.iframe_story_locations_fetched = true;
                    }
                }, 50);
            } else if (story && story['story_feed_id'] != this.active_feed) {
                NEWSBLUR.log(['Switched off iframe early']);
            }
        },
        
        find_story_in_story_iframe: function(story, $iframe) {
            if (!$iframe) $iframe = this.$story_iframe.contents();
            var $stories = $([]);
            
            if (this.flags.iframe_story_locations_fetched || story.id in this.cache.iframe_stories) {
                return this.cache.iframe_stories[story.id];
            }
            
            var title = story.story_title.replace(/&nbsp;|[^a-z0-9-,]/gi, '');
                            
            var search_document = function(node, title) {
                var skip = 0;
                
                if (node && node.nodeType == 3) {
                    // if (node.data.indexOf(story.story_title.substr(0, 20)) >= 0) {
                    //     NEWSBLUR.log(['found', {
                    //         node: node.data.replace(/&nbsp;|[^a-z0-9-]/gi, ''),
                    //         title: title
                    //     }]);
                    // }
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
                $('h1,h2,h3,h4,h5,h6', $iframe).filter(':visible').each(function() {
                    pos = $(this).text().replace(/&nbsp;|[^a-z0-9-,]/gi, '')
                                 .indexOf(title);
                    // NEWSBLUR.log(['Search headers', title, pos, $(this), $(this).text()]);
                    if (pos >= 0) {
                        $stories.push($(this));
                        return false;
                    }
                });
            }
            // NEWSBLUR.log(['Found stories', $stories, story.story_title]);
            
            var max_size = 0;
            var $story;
            $stories.each(function() {
                var size = parseInt($(this).css('font-size'), 10);
                if (size > max_size) {
                    max_size = size;
                    $story = $(this);
                }
            });
            
            if ($story && $story.length) {
                this.cache.iframe_stories[story.id] = $story;
                var position_original = parseInt($story.offset().top, 10);
                // var position_offset = parseInt($story.offsetParent().scrollTop(), 10);
                var position = position_original; // + position_offset;
                this.cache.iframe_story_positions[position] = story;
                this.cache.iframe_story_positions_keys.push(position);
            }
            
            // NEWSBLUR.log(['Found story', $story]);
            return $story;
        },
        
        open_story_link: function(story, $st) {
            window.open(unescape(story['story_permalink']), '_blank');
            window.focus();
        },
        
        mark_story_title_as_selected: function($story_title) {
            $('.selected', this.$story_titles).removeClass('selected');
            $('.after_selected', this.$story_titles).removeClass('after_selected');
            $story_title.addClass('selected');
            $story_title.parent('.story').next('.story').children('a').addClass('after_selected');
        },
        
        find_story_in_stories: function(story_id) {
            var stories = this.model.stories;

            for (s in stories) {
                if (stories[s].id == story_id) {
                    return stories[s];
                }
            }

            return null;
        },
        
        find_story_in_story_titles: function(story) {
            var $stories = $('.story', this.$story_titles);
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
        
        mark_story_as_read: function(story_id, $story_title) {
            var self = this;
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var $feed_list = this.$feed_list;
            var $feed = $('.feed.selected', $feed_list);
            var $content_pane = $('.content-pane');
            
            var callback = function(read) {
                if (read) return;
                
                var unread_count_positive = feed.ps;
                var unread_count_neutral = feed.nt;
                var unread_count_negative = feed.ng;
                // NEWSBLUR.log(['marked read', unread_count_positive, unread_count_neutral, unread_count_negative, $story_title.is('.NB-story-positive'), $story_title.is('.NB-story-neutral'), $story_title.is('.NB-story-negative')]);
                
                if ($story_title.is('.NB-story-positive')) {
                    var count = Math.max(unread_count_positive-1, 0);
                    feed.ps = count;
                    $('.unread_count_positive', $feed).text(count);
                    $('.unread_count_positive', $content_pane).text(count);
                    if (count == 0) {
                        $feed.removeClass('unread_positive');
                    } else {
                        $feed.addClass('unread_positive');
                    }
                } else if ($story_title.is('.NB-story-neutral')) {
                    var count = Math.max(unread_count_neutral-1, 0);
                    feed.nt = count;
                    $('.unread_count_neutral', $feed).text(count);
                    $('.unread_count_neutral', $content_pane).text(count);
                    if (count == 0) {
                        $feed.removeClass('unread_neutral');
                    } else {
                        $feed.addClass('unread_neutral');
                    }
                } else if ($story_title.is('.NB-story-negative')) {
                    var count = Math.max(unread_count_negative-1, 0);
                    feed.ng = count;
                    $('.unread_count_negative', $feed).text(count);
                    $('.unread_count_negative', $content_pane).text(count);
                    if (count == 0) {
                        $feed.removeClass('unread_negative');
                    } else {
                        $feed.addClass('unread_negative');
                    }
                }
                
                $('.feed', $content_pane).animate({'opacity': 1}, {'duration': 250, 'queue': false});
                    
                setTimeout(function() {
                    $('.feed', $content_pane).animate({'opacity': .1}, {'duration': 250, 'queue': false});
                }, 400);

                return;
            };

            $story_title.addClass('read');
            
            this.model.mark_story_as_read(story_id, feed_id, callback);
        },
        
        mark_feed_as_read: function(feed_id) {
            var self = this;
            var feed = this.model.get_feed(feed_id);
            var $feed = this.find_feed_in_feed_list(feed_id);
            var $content_pane = $('.content-pane');
            var $story_titles = this.$story_titles;
            
            var callback = function() {
                return;
            };
            
            feed.ps = 0;
            feed.nt = 0;
            feed.ng = 0;
            $('.unread_count_neutral', $feed).text(0);
            $('.unread_count_positive', $feed).text(0);
            $('.unread_count_negative', $feed).text(0);
            $('.unread_count_neutral', $content_pane).text(0);
            $('.unread_count_positive', $content_pane).text(0);
            $('.unread_count_negative', $content_pane).text(0);
            $('.story:not(.read)', $story_titles).addClass('read');
            $feed.removeClass('unread_neutral');
            $feed.removeClass('unread_positive');
            $feed.removeClass('unread_negative');

            this.model.mark_feed_as_read(feed_id, callback);
        },
        
        mark_story_as_like: function(story_id, $button) {
            var feed_id = this.active_feed;
            
            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierStory(story_id, feed_id, 1);
        },
        
        mark_story_as_dislike: function(story_id, $button) {
            var feed_id = this.active_feed;
            
            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierStory(story_id, feed_id, -1);
        },
        
        // ==========
        // = Events =
        // ==========
        
        handle_clicks: function(elem, e) {
            var self = this;

            // =========
            // = Feeds =
            // =========
            
            $.targetIs(e, { tagSelector: '#feed_list .feed' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.data('feed_id');
                self.open_feed(feed_id, $t);
            });
            $.targetIs(e, { tagSelector: '.NB-feedbar-mark-feed-read' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.feed').data('feed_id');
                self.mark_feed_as_read(feed_id, $t);
                $t.fadeOut(400);
            });
            $.targetIs(e, { tagSelector: '.NB-feedbar-manage-feed' }, function($t, $p){
                e.preventDefault();
                if (!$('.NB-task-manage').hasClass('NB-disabled')) {
                    self.open_manage_feed_modal();
                }
            }); 
            
            // ============
            // = Feed Bar =
            // ============
            
            $.targetIs(e, { tagSelector: '.NB-feed-like' }, function($t, $p){
                e.preventDefault();
                self.open_feed_intelligence_modal(1);
            });
            $.targetIs(e, { tagSelector: '.NB-feed-dislike' }, function($t, $p){
                e.preventDefault();
                self.open_feed_intelligence_modal(-1);
            });
            
            // ===========
            // = Stories =
            // ===========
            
            var story_prevent_bubbling = false;
            $.targetIs(e, { tagSelector: '.NB-story-like' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.parents('.story').data('story_id');
                self.mark_story_as_like(story_id, $t);
                story_prevent_bubbling = true;
            });
            $.targetIs(e, { tagSelector: '.NB-story-dislike' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.parents('.story').data('story_id');
                self.mark_story_as_dislike(story_id, $t);
                story_prevent_bubbling = true;
            });
            $.targetIs(e, { tagSelector: 'a.button.like' }, function($t, $p){
                e.preventDefault();
                var story_id = self.$story_pane.data('story_id');
                self.mark_story_as_like(story_id, $t);
                story_prevent_bubbling = true;
            });
            $.targetIs(e, { tagSelector: 'a.button.dislike' }, function($t, $p){
                e.preventDefault();
                var story_id = self.$story_pane.data('story_id');
                self.mark_story_as_dislike(story_id, $t);
                story_prevent_bubbling = true;
            });
            
            if (story_prevent_bubbling) return false;
            
            $.targetIs(e, { tagSelector: '.story' }, function($t, $p){
                e.preventDefault();
                var story_id = $('.story_id', $t).text();
                var story = self.find_story_in_stories(story_id);
                self.push_current_story_on_history();
                self.open_story(story, $t);
            });
            $.targetIs(e, { tagSelector: 'a.mark_story_as_read' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.attr('href').slice(1).split('/');
                self.mark_story_as_read(story_id, $t);
            });
            
            // ===========
            // = Taskbar =
            // ===========
            
            $.targetIs(e, { tagSelector: '.NB-task-add' }, function($t, $p){
                e.preventDefault();
                self.open_add_feed_modal();
            });  
            $.targetIs(e, { tagSelector: '.NB-task-manage' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_manage_feed_modal();
                }
            });  
            $.targetIs(e, { tagSelector: '.task_button_view' }, function($t, $p){
                e.preventDefault();
                var view;
                
                if ($t.hasClass('task_view_page')) {
                    view = 'page';
                } else if ($t.hasClass('task_view_feed')) {
                    view = 'feed';
                } else if ($t.hasClass('task_view_story')) {
                    view = 'story';
                } 
                self.switch_taskbar_view(view);
            });
            $.targetIs(e, { tagSelector: '.task_return', childOf: '.taskbar_nav_return' }, function($t, $p){
                e.preventDefault();
                self.load_iframe();
            });         
            $.targetIs(e, { tagSelector: '.task_button_story.task_story_next' }, function($t, $p){
                e.preventDefault();
                self.show_next_unread_story();
            }); 
            $.targetIs(e, { tagSelector: '.task_button_story.task_story_previous' }, function($t, $p){
                e.preventDefault();
                self.show_previous_story();
            }); 
            
        },
        
        handle_dblclicks: function(elem, e) {
            var self = this;
            
            $.targetIs(e, { tagSelector: '#story_titles .story' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                // NEWSBLUR.log(['Story dblclick', $t]);
                var story_id = $('.story_id', $t).text();
                var story = self.find_story_in_stories(story_id); 
                self.open_story_link(story, $t);
            });
            $.targetIs(e, { tagSelector: '#feed_list .feed' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                // NEWSBLUR.log(['Feed dblclick', $('.feed_id', $t), $t]);
                var feed_id = $t.data('feed_id');
                self.open_feed_link(feed_id, $t);
            });
        },
        
        handle_scroll_story_titles: function(elem, e) {
            var self = this;

            if (!($('.NB-story-titles-end-stories-line', this.$story_titles).length)) {
                var $last_story = $('#story_titles .story').last();
                var container_offset = this.$story_titles.position().top;
                var full_height = ($last_story.offset() && $last_story.offset().top) + $last_story.height() - container_offset;
                var visible_height = $('#story_titles').height();
                var scroll_y = $('#story_titles').scrollTop();
                // NEWSBLUR.log(['Story_titles Scroll', full_height, container_offset, visible_height, scroll_y]);
            
                if (full_height <= visible_height) {
                    this.load_page_of_feed_stories();
                }
            }
        },
        
        handle_scroll_story_iframe: function(elem, e) {
            var self = this;
            if (!this.flags.scrolling_by_selecting_story_title && !this.flags.handled_scroll_story_iframe) {
                var from_top = this.$story_iframe.contents().scrollTop();
                var positions = this.cache.iframe_story_positions_keys;
                var closest = this.closest(from_top, positions);
                var story = this.cache.iframe_story_positions[positions[closest]];
                // NEWSBLUR.log(['Scroll iframe', from_top, closest, positions[closest], this.cache.iframe_story_positions[positions[closest]]]);
                this.navigate_story_titles_to_story(story);
                this.flags.handled_scroll_story_iframe = false;
                setTimeout(function() {
                    self.flags.handled_scroll_story_iframe = false;
                }, 50);
                this.iframe_scroll = from_top;
                this.flags.iframe_scroll_snap_back_prepared = false;
                // NEWSBLUR.log(['Setting snap back', this.iframe_scroll]);
            }
        },
        
        closest: function(value, array) {
            var index = 0;
            var closest = Math.abs(array[index] - value);
            for (var i in array) {
                var next_value = array[i] - value;
                if (50 >= next_value && Math.abs(next_value) < closest) {
                    index = i;
                    closest = Math.abs(array[index] - value);
                }
            }
            return index;
        },
        
        handle_scroll_feed_view: function(elem, e) {
            var self = this;
            
            if (!this.flags['switching_to_feed_view']
                && !this.flags.scrolling_by_selecting_story_title 
                && this.story_view != 'story') {
                var from_top = this.$feed_view.scrollTop();
                var positions = this.cache.feed_view_story_positions_keys;
                var closest = parseInt(this.closest(from_top, positions), 10);
                var story = this.cache.feed_view_story_positions[positions[closest]];
                // NEWSBLUR.log(['Scroll feed view', from_top, closest, positions[closest], this.cache.feed_view_story_positions_keys, positions, self.cache]);
                this.navigate_story_titles_to_story(story);
            }
        },
        
        // ================
        // = Feed Browser =
        // ================
        
        load_feed_browser: function() {
            
        },
        
        // ===================
        // = Bottom Task Bar =
        // ===================
        
        open_add_feed_modal: function() {
            var feed_id = this.active_feed;
            
            clearInterval(this.flags['bouncing_callout']);
            
            NEWSBLUR.add_feed = new NEWSBLUR.ReaderAddFeed();
        },
        
        open_manage_feed_modal: function() {
            var feed_id = this.active_feed;
            
            NEWSBLUR.manage_feed = new NEWSBLUR.ReaderManageFeed(feed_id);
        },
        
        // ================
        // = Intelligence =
        // ================
        
        load_intelligence_slider: function() {
            var self = this;
            var $slider = this.$intelligence_slider;
            var unread_view = NEWSBLUR.Globals.unread_view;
            
            this.switch_feed_view_unread_view(unread_view);
            
            $slider.slider({
                range: 'max',
                min: -1,
                max: 1,
                step: 1,
                value: NEWSBLUR.Globals.unread_view,
                slide: function(e, ui) {
                    self.switch_feed_view_unread_view(ui.value);
                },
                stop: function(e, ui) {
                    self.save_profile('unread_view', ui.value);
                    self.flags['feed_view_positions_calculated'] = false;
                    self.show_correct_story_titles_in_unread_view({'animate': true});
                }
            });
        },
        
        switch_feed_view_unread_view: function(unread_view) {
            var $feed_list = this.$feed_list;
            var unread_view_name = this.get_unread_view_name(unread_view);
            var $next_story_button = $('.task_story_next');
            
            NEWSBLUR.Globals.unread_view = unread_view;
            
            $feed_list.removeClass('unread_view_positive')
                      .removeClass('unread_view_neutral')
                      .removeClass('unread_view_negative')
                      .addClass('unread_view_'+unread_view_name);
                      
            $next_story_button.removeClass('task_story_next_positive')
                              .removeClass('task_story_next_neutral')
                              .removeClass('task_story_next_negative')
                              .addClass('task_story_next_'+unread_view_name);
        },
        
        get_unread_view_name: function(unread_view) {
            return (unread_view > 0
                    ? 'positive'
                    : unread_view < 0
                      ? 'negative'
                      : 'neutral');
        },
        
        get_unread_count: function(visible_only) {
            var total = 0;
            var feed = this.model.get_feed(this.active_feed);
            
            if (!visible_only) {
                total = feed.ng + feed.nt + feed.ps;
            } else {
                var unread_view = NEWSBLUR.Globals.unread_view;
                var unread_view_name = this.get_unread_view_name(unread_view);
                if (unread_view_name == 'positive') {
                    total = feed.ps;
                } else if (unread_view_name == 'neutral') {
                    total = feed.ps + feed.nt;
                } else if (unread_view_name == 'negative') {
                    total = feed.ps + feed.nt + feed.ng;
                }
            }
            return total;
        },
        
        show_correct_story_titles_in_unread_view: function(options) {
            var self = this;
            var unread_view = NEWSBLUR.Globals.unread_view;
            var $story_titles = this.$story_titles;
            var unread_view_name = this.get_unread_view_name(unread_view);
            var $stories_show, $stories_hide;
            
            if (unread_view_name == 'positive') {
                $stories_show = $('.story,.NB-feed-story').filter('.NB-story-positive');
                $stories_hide = $('.story,.NB-feed-story')
                                .filter('.NB-story-neutral,.NB-story-negative');
            } else if (unread_view_name == 'neutral') {
                $stories_show = $('.story,.NB-feed-story')
                                .filter('.NB-story-positive,.NB-story-neutral');
                $stories_hide = $('.story,.NB-feed-story').filter('.NB-story-negative');
            } else if (unread_view_name == 'negative') {
                $stories_show = $('.story,.NB-feed-story')
                                .filter('.NB-story-positive,.NB-story-neutral,.NB-story-negative');
                $stories_hide = $();
            }
            
            if (this.story_view == 'story') {
                // No need to show/hide feed view stories. If the user switches to feed/page, 
                // then no animation is happening and this will work anyway.
                $stories_show = $stories_show.not('.NB-feed-story');
                $stories_hide = $stories_hide.not('.NB-feed-story');
            }
            
            if (!options['animate']) {
                $stories_hide.css({'display': 'none'});
                $stories_show.css({'display': 'block'});
            }
            
            if (this.story_view != 'story') {
                if (!this.flags['feed_view_positions_calculated']
                    || $stories_show.filter(':visible').length != $stories_show.length
                    || $stories_hide.filter(':visible').length != 0) {
                        // NEWSBLUR.log(['Show/Hide stories', $stories_show.filter(':visible').length, $stories_show.length, $stories_hide.filter(':visible').length, $stories_hide.length]);
                    setTimeout(function() {
                        if (!self.flags['feed_view_positions_calculated']) {
                            self.process_stories_location_in_feed_view(0, true);
                        }
                    }, 750);
                }
            }
            
            // NEWSBLUR.log(['Showing correct stories', this.story_view, this.flags['feed_view_positions_calculated'], unread_view_name, $stories_show.length, $stories_hide.length]);
            if (options['animate']) {
                $stories_hide.slideUp(500);
                $stories_show.slideDown(500);
                setTimeout(function() {
                    var $story = self.find_story_in_story_titles(self.active_story);
                    // NEWSBLUR.log(['$story', $story]);
                    if ($story && $story.length && $story.is(':visible')) {
                        var story = self.active_story;
                        self.active_story = null; // Set is in open_story(), which allows it to scroll.
                        self.open_story(story, $story);
                        self.scroll_story_titles_to_show_selected_story_title($story);
                    }
                }, 550);
            }
        },
    
        update_opinions: function($modal, feed_id) {
            var self = this;
            var feed = this.model.get_feed(feed_id);
            
            if (feed_id != this.model.feed_id) return;
            
            $('input[type=checkbox]', $modal).each(function() {
                var $this = $(this);
                var name = $this.attr('name').replace(/^(dis)?like_/, '');
                var score = /^dislike/.test($this.attr('name')) ? -1 : 1;
                var value = $this.val();
                var checked = $this.attr('checked');
            
                if (checked) {
                    if (name == 'tag') {
                        self.model.classifiers.tags[value] = score;
                    } else if (name == 'title') {
                        self.model.classifiers.titles[value] = score;
                    } else if (name == 'author') {
                        self.model.classifiers.authors[value] = score;
                    } else if (name == 'publisher') {
                        self.model.classifiers.feeds[feed.feed_link] = {
                            'feed_link': feed.feed_link,
                            'feed_title': feed.feed_title,
                            'score': score
                        };
                    }
                } else {
                    if (name == 'tag' && self.model.classifiers.tags[value] == score) {
                        delete self.model.classifiers.tags[value];
                    } else if (name == 'title' && self.model.classifiers.titles[value] == score) {
                        delete self.model.classifiers.titles[value];
                    } else if (name == 'author' && self.model.classifiers.authors[value] == score) {
                        delete self.model.classifiers.authors[value];
                    } else if (name == 'publisher' 
                               && self.model.classifiers.feeds[feed.feed_link] 
                               && self.model.classifiers.feeds[feed.feed_link].score == score) {
                        delete self.model.classifiers.feeds[feed.feed_link];
                    }
                }
            });
            
        },
        
        // ===================
        // = Feed Refreshing =
        // ===================
        
        setup_feed_refresh: function() {
            var self = this;
            var FEED_REFRESH_INTERVAL = 1000 * 60; // 1 minute
            
            this.flags.feed_refresh = setInterval(function() {
                self.model.refresh_feeds($.rescope(self.post_feed_refresh, self));
            }, FEED_REFRESH_INTERVAL);
        },
        
        force_feed_refresh: function() {
            this.model.refresh_feeds($.rescope(this.post_feed_refresh, this));
        },
        
        post_feed_refresh: function(e, updated_feeds) {
            var feeds = this.model.feeds;
            
            for (var f in updated_feeds) {
                var feed_id = updated_feeds[f];
                if (feed_id != this.active_feed) {
                    var feed = this.model.get_feed(feed_id);
                    var $feed = this.make_feed_title_line(feed, true);
                    var $feed_on_page = this.find_feed_in_feed_list(feed_id);
                    var selected = $feed_on_page.hasClass('selected');
                    if (selected) {
                        $feed.addClass('selected');
                    }
                    NEWSBLUR.log(['UPDATING', feed.feed_title, $feed, $feed_on_page]);
                    $feed_on_page.replaceWith($feed);
                    $('.unread_count', $feed).corner('4px');
                }
            }
        },
        
        // ===========
        // = Profile =
        // ===========
        
        save_profile: function(key, value) {
            NEWSBLUR.Globals[key] = value;
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
        }
        
    };

})(jQuery);

$(document).ready(function() {

    NEWSBLUR.reader = new NEWSBLUR.Reader();
    

});