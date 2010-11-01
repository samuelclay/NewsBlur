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
            $story_pane: $('#story_pane .NB-story-pane-container'),
            $feed_view: $('.NB-feed-story-view'),
            $story_iframe: $('.NB-feed-frame'),
            $intelligence_slider: $('.NB-intelligence-slider'),
            $mouse_indicator: $('#mouse-indicator'),
            $feed_link_loader: $('#NB-feeds-list-loader'),
            $feeds_progress: $('#NB-progress')
        };
        this.flags = {
            'feed_view_images_loaded': {},
            'bouncing_callout': false,
            'has_unfetched_feeds': false
        };
        this.locks = {};
        this.counts = {
            'feature_page': 0,
            'unfetched_feeds': 0,
            'fetched_feeds': 0
        };
        this.cache = {
            'iframe_stories': {},
            'feed_view_stories': {},
            'iframe_story_positions': {},
            'feed_view_story_positions': {},
            'iframe_story_positions_keys': [],
            'feed_view_story_positions_keys': [],
            'mouse_position_y': parseInt(this.model.preference('lock_mouse_indicator'), 10)
        };
        this.FEED_REFRESH_INTERVAL = (1000 * 60) / 2; // 1/2 minutes
        
        // ==================
        // = Event Handlers =
        // ==================
        
        this.$s.$body.bind('dblclick.reader', $.rescope(this.handle_dblclicks, this));
        this.$s.$body.bind('click.reader', $.rescope(this.handle_clicks, this));
        this.$s.$story_titles.scroll($.rescope(this.handle_scroll_story_titles, this));
        this.$s.$feed_view.scroll($.rescope(this.handle_scroll_feed_view, this));
        this.$s.$feed_view.bind('mousemove', $.rescope(this.handle_mousemove_feed_view, this));
        this.handle_keystrokes();
        
        // ==================
        // = Initialization =
        // ==================
        
        
        this.unload_iframe();
        if (NEWSBLUR.Flags['start_import_from_google_reader']) {
          this.start_import_from_google_reader();
        } else {
          this.load_feeds();
        }
        this.apply_resizable_layout();
        this.cornerize_buttons();
        this.setup_feed_page_iframe_load();
        this.load_intelligence_slider();
        this.handle_mouse_indicator_hover();
        this.position_mouse_indicator();
        this.handle_login_and_signup_forms();
        this.iframe_buster_buster();
    };

    NEWSBLUR.Reader.prototype = {
       
        // ========
        // = Page =
        // ========
                
        apply_resizable_layout: function() {
            var outerLayout, rightLayout, contentLayout, leftLayout;
            
            outerLayout = this.$s.$body.layout({ 
                closable: true,
                center__paneSelector:   ".right-pane",
                west__paneSelector:     ".left-pane",
                west__size:             this.model.preference('feed_pane_size'),
                west__onresize_end:     $.rescope(this.save_feed_pane_size, this),
                spacing_open:           4,
                resizerDragOpacity:     0.6
            }); 
            
            leftLayout = $('.left-pane').layout({
                closable:               false,
                center__paneSelector:   ".left-center",
                center__resizable:      false,
                south__paneSelector:    ".left-south",
                south__size:            31,
                south__resizable:       false,
                south__spacing_open:    0
            });

            rightLayout = $('.right-pane').layout({ 
                south__paneSelector:    ".right-north",
                center__paneSelector:   ".content-pane",
                south__size:            this.model.preference('story_titles_pane_size'),
                south__onresize_end:    $.rescope(this.save_story_titles_pane_size, this),
                spacing_open:           10,
                resizerDragOpacity:     0.6
            }); 

            contentLayout = this.$s.$content_pane.layout({ 
                center__paneSelector:   ".content-center",
                south__paneSelector:    ".content-north",
                south__size:            30,
                spacing_open:           0,
                resizerDragOpacity:     0.6
            }); 
            
            $('.right-pane').hide();
        },
        
        save_feed_pane_size: function(w, pane, $pane, state, options, name) {
            this.model.preference('feed_pane_size', state.size);
        },
        
        save_story_titles_pane_size: function(w, pane, $pane, state, options, name) {
            this.model.preference('story_titles_pane_size', state.size);
        },
        
        cornerize_buttons: function() {
            $('.button').corner();
        },
        
        hide_splash_page: function() {
            var self = this;
            $('.right-pane').show();
            $('#NB-splash').hide();
            $('#NB-splash-overlay').hide();
            this.$s.$body.layout().resizeAll();
            
            if (NEWSBLUR.Globals.is_anonymous) {
                this.setup_ftux_signup_callout();
            }
        },
        
        show_splash_page: function() {
            $('.right-pane').hide();
            $('#NB-splash').show();
            $('#NB-splash-overlay').show();
        },
        
        iframe_buster_buster: function() {
            var self = this;
            var prevent_bust = 0;
            window.onbeforeunload = function() { 
              prevent_bust++;
            };
            setInterval(function() {
                if (prevent_bust > 0) {
                    prevent_bust -= 2;
                    if (!self.flags['iframe_view_loaded'] && self.story_view == 'page' && self.active_feed) {
                      $('.task_view_feed').click();
                      $('.NB-feed-frame').attr('src', '');
                      window.top.location = '/reader/buster';
                    }
                }
            }, 1);
        },
        
        // =======================
        // = Getters and Finders =
        // =======================
        
        get_current_story_from_story_titles: function() {
            var $feed_view = this.$s.$feed_view;
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
        
        find_feed_in_feed_list: function(feed_id) {
            var $feed_list = this.$s.$feed_list;
            var $feeds = $([]);
            
            $('.feed', $feed_list).each(function() {
                if ($(this).data('feed_id') == feed_id) {
                    $feeds.push($(this).get(0));
                }
            });
            
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
        
        find_story_in_story_titles: function(story) {
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
        
        find_story_in_story_iframe: function(story, $iframe) {
            if (!story) return $([]);
            
            if (!$iframe) $iframe = this.$s.$story_iframe.contents();
            var $stories = $([]);
            
            if (this.flags.iframe_story_locations_fetched || story.id in this.cache.iframe_stories) {
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
            
            if (!$stories.length) {
                // Still not found, so check Tumblr style .post's
                $('.entry,.post,.postProp,#postContent,.article', $iframe).filter(':visible').each(function() {
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
        
        get_feed_ids_in_folder: function($folder) {
            $folder = $folder || this.$s.$feed_list;
            
            var $feeds = $('.feed', $folder);
            var feeds = _.map($('.feed', $folder), function(o) {
                return $(o).data('feed_id');
            });
            
            return feeds;
        },
        
        // ==============
        // = Navigation =
        // ==============
        
        show_next_story: function(direction) {
            var $story_titles = this.$s.$story_titles;
            var $current_story = $('.selected', $story_titles);
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
        
        show_next_unread_story: function(second_pass) {
            var $story_titles = this.$s.$story_titles;
            var $current_story = $('.selected', $story_titles);
            var $next_story;
            var unread_count = this.get_unread_count(true);
            
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
                    var story_id = $next_story.data('story_id');
                    if (story_id) {
                        var story = this.model.get_story(story_id);
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
            var $current_feed = $current_feed || $('.selected', $feed_list);
            var $next_feed,
                scroll;
            var $feeds = $('.feed', $feed_list);
            
            if (!$current_feed.length) {
                $current_feed = $('.feed:first', $feed_list);
                $next_feed = $current_feed;
            } else {
                $feeds.each(function(i) {
                    if (this == $current_feed[0]) {
                        current_feed = i;
                        return false;
                    }
                });
                $next_feed = $feeds.eq(current_feed+direction);
            }
            
            var feed_id = $next_feed.data('feed_id');
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
                this.open_feed(feed_id, false, $next_feed);
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
            var page_height = this.$s.$story_pane.height();
            var scroll_height = parseInt(page_height * amount, 10);
            var dir = '+';
            if (direction == -1) {
                dir = '-';
            }
            // NEWSBLUR.log(['page_in_story', this.$s.$story_pane, direction, page_height, scroll_height]);
            if (this.story_view == 'page') {
                this.$s.$story_iframe.scrollTo({top:dir+'='+scroll_height, left:'+=0'}, 150);
            } else if (this.story_view == 'feed' || this.story_view == 'story') {
                this.$s.$feed_view.scrollTo({top:dir+'='+scroll_height, left:'+=0'}, 150);
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
                this.model.load_feeds($.rescope(this.make_feeds, this));
            }
        },
        
        make_feeds: function() {
            var self = this;
            var $feed_list = this.$s.$feed_list.empty();
            var folders = this.model.folders;
            var feeds = this.model.feeds;
            
            // NEWSBLUR.log(['Making feeds', {'folders': folders, 'feeds': feeds}]);
            
            $('#story_taskbar').css({'display': 'block'});
            
            this.flags['has_chosen_feeds'] = this.detect_all_inactive_feeds();
            this.make_feeds_folder($feed_list, folders, 0);
            this.$s.$feed_link_loader.fadeOut(250);

            if (folders.length) {
                $('.NB-task-manage').removeClass('NB-disabled');
                $('.NB-callout-ftux').fadeOut(500);
            }
            
            if (NEWSBLUR.Globals.is_authenticated && this.flags['has_chosen_feeds']) {
                this.start_count_unreads_after_import();
                this.force_feeds_refresh($.rescope(this.finish_count_unreads_after_import, this));
            } else if (!this.flags['has_chosen_feeds'] && folders.length) {
                _.defer(_.bind(this.open_feedchooser_modal, this), 100);
                return;
            } else if (NEWSBLUR.Globals.is_authenticated) {
                this.setup_ftux_add_feed_callout();
            }
            
            if (folders.length) {
                this.load_sortable_feeds();
                $('.feed', $feed_list).tsort('.feed_title');
                $('.folder', $feed_list).tsort('.folder_title_text');
            }
        },
        
        detect_all_inactive_feeds: function() {
          var feeds = this.model.feeds;
          var has_chosen_feeds = _.any(feeds, function(feed) {
            return feed.active;
          });
          return has_chosen_feeds;
        },
        
        make_feeds_folder: function($feeds, items, depth, collapsed_parent) {
            var self = this;
            
            for (var i in items) {
                var item = items[i];

                if (typeof item == "number") {
                    var feed = this.model.get_feed(item);
                    if (!feed) continue;
                    var $feed = this.make_feed_title_line(feed, true, 'feed');
                    $feeds.append($feed);
                    if (depth == 0) {
                        this.hover_over_feed_titles();
                        $feed.addClass('NB-toplevel');
                        if (feed.active) {
                            $feed.css({'display': 'none'}).fadeIn(500);
                        }
                    }
                    
                    if (feed.not_yet_fetched) {
                        // NEWSBLUR.log(['Feed not fetched', feed]);
                        if (!this.model.preference('hide_fetch_progress')) {
                            this.flags['has_unfetched_feeds'] = true;
                        }
                    }
                } else if (typeof item == "object") {
                    for (var o in item) {
                        var folder = item[o];
                        var $folder = $.make('li', { className: 'folder' }, [
                            $.make('div', { className: 'folder_title ' + (depth==0 ? 'NB-toplevel':'') }, [
                                $.make('span', { className: 'folder_title_text' }, o),
                                $.make('div', { className: 'NB-feedlist-manage-icon' })
                            ]),
                            $.make('ul', { className: 'folder' })
                        ]).css({'display': 'none'});
                        var is_collapsed = _.contains(NEWSBLUR.Preferences.collapsed_folders, o);

                        (function($feeds, $folder, is_collapsed, collapsed_parent) {
                            var continue_loading_next_feed = function() {
                                if (is_collapsed) {
                                    $('ul.folder', $folder).css({'display': 'none'});
                                    $feeds.append($folder);
                                    self.collapse_folder($('.folder_title', $folder).eq(0), true);
                                    if (collapsed_parent) {
                                        $folder.parents('li.folder').each(function() {
                                            self.collapse_folder($('.folder_title', this).eq(0), true);
                                        });
                                    }
                                } else {
                                    $feeds.append($folder);
                                }
                                if (self.flags['has_chosen_feeds']) {
                                  $folder.fadeIn(500);
                                }
                                self.hover_over_feed_titles($folder);
                            };
                            if (!self.flags['has_chosen_feeds']) {
                                continue_loading_next_feed();
                            } else {
                                setTimeout(continue_loading_next_feed, 50);
                            }
                        })($feeds, $folder, is_collapsed, collapsed_parent);
                        this.make_feeds_folder($('ul.folder', $folder), folder, depth+1, is_collapsed);
                    }
                }
            }
            
            $('.feed', $feeds).tsort('.feed_title');
            $('.folder', $feeds).tsort('.folder_title_text');
        },
        
        make_feed_title_line: function(feed, list_item, type) {
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
            
            var $feed = $.make((list_item?'li':'div'), { className: 'feed ' + unread_class + exception_class }, [
                $.make('div', { className: 'feed_counts' }, [
                    this.make_feed_counts_floater(feed.ps, feed.nt, feed.ng)
                ]),
                $.make('img', { className: 'feed_favicon', src: NEWSBLUR.Globals.google_favicon_url + feed.feed_link }),
                $.make('span', { className: 'feed_title' }, [
                  feed.feed_title,
                  $.make('span', { className: 'NB-feedbar-train-feed', title: 'Train Intelligence' }),
                  (type == 'story' && $.make('span', { className: 'NB-feedbar-statistics', title: 'Statistics' }))
                ]),
                (type == 'story' && $.make('div', { className: 'NB-feedbar-last-updated' }, [
                    $.make('span', { className: 'NB-feedbar-last-updated-label' }, 'Updated: '),
                    $.make('span', { className: 'NB-feedbar-last-updated-date' }, feed.updated + ' ago')
                ])),
                (type == 'story' && $.make('div', { className: 'NB-feedbar-mark-feed-read' }, 'Mark All as Read')),
                $.make('div', { className: 'NB-feed-exception-icon' }),
                $.make('div', { className: 'NB-feed-unfetched-icon' }),
                (type == 'feed' && $.make('div', { className: 'NB-feedlist-manage-icon' }))
            ]).data('feed_id', feed.id);  
            
            return $feed;  
        },
        
        make_feed_counts_floater: function(positive_count, neutral_count, negative_count) {
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
            
            return $.make('div', { className: 'feed_counts_floater ' + unread_class }, [
                $.make('span', { 
                    className: 'unread_count unread_count_positive '
                                + (positive_count
                                   ? "unread_count_full"
                                   : "unread_count_empty")
                }, ''+positive_count),
                $.make('span', { 
                    className: 'unread_count unread_count_neutral '
                                + (neutral_count
                                   ? "unread_count_full"
                                   : "unread_count_empty") 
                }, ''+neutral_count),
                $.make('span', { 
                    className: 'unread_count unread_count_negative '
                                + (negative_count
                                   ? "unread_count_full"
                                   : "unread_count_empty")
                }, ''+negative_count)
            ]);
        },
        
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
            
            if (!$progress.is(':visible')) {
                setTimeout(function() {
                    self.show_progress_bar();
                }, 1000);
            }
        },
        
        show_progress_bar: function($progress) {
            $progress = $progress || this.$s.$feeds_progress;
            
            if (!this.flags['showing_progress_bar']) {
                this.flags['showing_progress_bar'] = true;
                $progress.css({'display': 'block', 'opacity': 0}).animate({
                    'opacity': 1,
                    'bottom': 31
                }, {
                    'queue': false,
                    'duration': 750
                });
            
                this.$s.$feed_list.animate({'bottom': 73}, {'duration': 750, 'queue': false});
            }
        },

        hide_progress_bar: function(permanent) {
            var self = this;
            var $progress = this.$s.$feeds_progress;
          
            if (permanent) {
                this.model.preference('hide_fetch_progress', true);
            }
            
            this.flags['showing_progress_bar'] = false;
            
            $progress.animate({
                'opacity': 0,
                'bottom': 0
            }, {
                'duration': 750,
                'queue': false,
                'complete': function() {
                    if (!self.flags['showing_progress_bar']) {
                        $progress.css({'display': 'none'});
                    }
                }
            });
            this.$s.$feed_list.animate({'bottom': '30px'}, {'duration': 750, 'queue': false});
        },
        
        hide_unfetched_feed_progress: function(permanent) {
            if (permanent) {
                this.model.preference('hide_fetch_progress', true);
            }
            
            this.hide_progress_bar();
        },
        
        load_sortable_feeds: function() {
            var self = this;
            
            $('ul.folder').sortable({
                connectWith: 'ul.folder',
                items: '.feed, li.folder',
                placeholder: 'NB-feeds-list-highlight',
                axis: 'y',
                distance: 3,
                cursor: 'move',
                start: function(e, ui) {
                    self.flags['sorting_feed'] = true;
                    ui.placeholder.attr('class', ui.item.attr('class') + ' NB-feeds-list-highlight');
                    ui.item.addClass('NB-feed-sorting');
                    self.$s.$feed_list.addClass('NB-feed-sorting');
                    ui.placeholder.html(ui.item.children().clone());
                    if (ui.item.is('li.folder')) {
                        ui.item.data('previously_collapsed', ui.item.data('collapsed'));
                        self.collapse_folder($('.folder_title', ui.item).eq(0), true);
                        self.collapse_folder($('.folder_title', ui.placeholder).eq(0), true);
                        ui.item.css('height', $('.folder_title', ui.item.parent()).eq(0).outerHeight(true) + 'px');
                    }
                },
                change: function(e, ui) {
                    $('.feed', ui.placeholder.parents('.folder').eq(0)).tsort('.feed_title');
                    $('.folder', ui.placeholder.parents('.folder').eq(0)).tsort('.folder_title_text');
                },
                stop: function(e, ui) {
                    setTimeout(function() {
                        self.flags['sorting_feed'] = false;
                    }, 100);
                    ui.item.removeClass('NB-feed-sorting');
                    self.$s.$feed_list.removeClass('NB-feed-sorting');
                    $('.feed', e.target).tsort('.feed_title');
                    $('.folder', e.target).tsort('.folder_title_text');
                    self.save_feed_order();
                    ui.item.css({'backgroundColor': '#D7DDE6'})
                           .animate({'backgroundColor': '#F0F076'}, {'duration': 800})
                           .animate({'backgroundColor': '#D7DDE6'}, {'duration': 1000});
                    if (!ui.item.data('previously_collapsed')) {
                        self.collapse_folder($('.folder_title', ui.item).eq(0));
                        self.collapse_folder($('.folder_title', ui.placeholder).eq(0));
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
                        folders.push($item.data('feed_id'));
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
        
        collapse_folder: function($folder_title, force_collapse) {
            var self = this;
            var $feed_list = this.$s.$feed_list;
            var $folder = $folder_title.parent('.folder');
            var $children = $folder.children('.folder, .feed');
            
            // Hiding / Collapsing
            if (force_collapse || 
                ($children.length && 
                 $children.eq(0).is(':visible') && 
                 !$folder.data('collapsed'))) {
                this.model.collapsed_folders($('.folder_title_text', $folder_title).text(), true);
                $folder.data('collapsed', true);
                $children.animate({'opacity': 0}, {
                    'queue': false,
                    'duration': force_collapse ? 0 : 200,
                    'complete': function() {
                        self.show_collapsed_folder_count($folder_title, $children);
                        $children.slideUp({
                            'duration': 240,
                            'easing': 'easeOutQuint'
                        });
                    }
                });
            } 
            // Showing / Expanding
            else if ($children.length && 
                       ($folder.data('collapsed') || !$children.eq(0).is(':visible'))) {
                this.model.collapsed_folders($('.folder_title_text', $folder_title).text(), false);
                $folder.data('collapsed', false);
                this.hide_collapsed_folder_count($folder_title);
                $children.css({'opacity': 0}).slideDown({
                    'duration': 240,
                    'easing': 'easeOutQuint',
                    'complete': function() {
                        $children.animate({'opacity': 1}, {'queue': false, 'duration': 200});
                    }
                });
            }
        },
        
        show_collapsed_folder_count: function($folder_title, $children) {
            var $counts = $('.feed_counts_floater', $folder_title);
            $counts.remove();
            $children = $('li.feed', $children).not('.NB-feed-inactive');
            
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
            var $counts = this.make_feed_counts_floater(positive_count, neutral_count, negative_count);
            $folder_title.prepend($counts.css({
                'opacity': 0
            }));
            $counts.animate({'opacity': 1}, {'duration': 400});
        },
        
        hide_collapsed_folder_count: function($folder_title) {
            var $counts = $('.feed_counts_floater', $folder_title);
            $counts.animate({'opacity': 0}, {
                'duration': 300 
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

            $feeds.rightClick(function() {
                var $this = $(this);
                if ($this.is('.feed')) {
                    self.show_manage_menu('feed', $this);
                } else if ($this.is('.folder_title')) {
                    self.show_manage_menu('folder', $this.parents('li.folder').eq(0));
                }
            });
            
            // NEWSBLUR.log(['hover_over_feed_titles', $folder, $feeds]);
            
            $feeds.unbind('mouseenter').unbind('mouseleave');
            
            $feeds.hover(function() {
                if (!self.$s.$feed_list.hasClass('NB-feed-sorting')) {
                    var $this = $(this);
                    $('.NB-hover', $folder).removeClass('NB-hover');
                    $this.addClass("NB-hover");
                    // NEWSBLUR.log(['scroll', $this.scrollTop(), $this.offset(), $this.position()]);
                    if ($this.offset().top > $(window).height() - 181) {
                        $this.addClass('NB-hover-inverse');
                    } 
                }
            }, function() {
                var $this = $(this);
                $this.removeClass("NB-hover");
                $this.removeClass('NB-hover-inverse');
                $('.NB-hover', $folder).removeClass('NB-hover').removeClass('NB-hover-inverse');
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
        
        // ===============================
        // = Feed bar - Individual Feeds =
        // ===============================
        
        reset_feed: function() {
            $.extend(this.flags, {
                'iframe_story_locations_fetched': false,
                'iframe_view_loaded': false,
                'feed_view_images_loaded': {},
                'feed_view_positions_calculated': false,
                'scrolling_by_selecting_story_title': false,
                'switching_to_feed_view': false,
                'find_next_unread_on_page_of_feed_stories_load': false,
                'page_view_showing_feed_view': false,
                'iframe_fetching_story_locations': false,
                'story_titles_loaded': false,
                'iframe_prevented_from_loading': false,
                'pause_feed_refreshing': false,
                'feed_list_showing_manage_menu': false
            });
            
            $.extend(this.cache, {
                'iframe_stories': {},
                'feed_view_stories': {},
                'iframe_story_positions': {},
                'feed_view_story_positions': {},
                'iframe_story_positions_keys': [],
                'feed_view_story_positions_keys': [],
                'previous_stories_stack': [],
                'mouse_position_y': parseInt(this.model.preference('lock_mouse_indicator'), 10)
            });
            
            this.active_feed = null;
            this.$s.$story_titles.data('page', 0);
            this.$s.$story_titles.data('feed_id', null);
            this.$s.$feed_view.empty();
        },
        
        open_feed: function(feed_id, force, $feed_link) {
            var self = this;
            var $story_titles = this.$s.$story_titles;
            this.flags['opening_feed'] = true;
            
            
            if (feed_id != this.active_feed || force) {
                $story_titles.empty().scrollTop('0px');
                this.reset_feed();
                this.hide_splash_page();
            
                this.active_feed = feed_id;
                $story_titles.data('page', 0);
                $story_titles.data('feed_id', feed_id);
                this.iframe_scroll = null;
                this.set_correct_story_view_for_feed(feed_id);
                $feed_link = $feed_link || $('.feed.selected', this.$s.$feed_list).eq(0);
                this.mark_feed_as_selected(feed_id, $feed_link);
                this.show_feed_title_in_stories($story_titles, feed_id);
                this.show_feedbar_loading();
                this.make_content_pane_feed_counter(feed_id);
                this.switch_taskbar_view(this.story_view);
                // NEWSBLUR.log(['open_feed', this.flags, this.active_feed, feed_id]);
                
                _.defer(_.bind(function() {
                    this.model.load_feed(feed_id, 0, true, $.rescope(this.post_open_feed, this));
                }, this));
                var feed_view_setting = this.model.view_setting(feed_id);
                if (!feed_view_setting || feed_view_setting == 'page') {
                    _.defer(_.bind(function() {
                        this.load_iframe(feed_id);
                    }, this));
                } else {
                    this.unload_iframe();
                    this.flags['iframe_prevented_from_loading'] = true;
                }
                this.flags['opening_feed'] = false;
                var $iframe_contents = this.$s.$story_iframe.contents();
                $iframe_contents
                    .unbind('scroll')
                    .scroll($.rescope(this.handle_scroll_story_iframe, this));
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
            }
        },
        
        post_open_feed: function(e, data, first_load) {
            if (!data) {
                return this.open_feed(this.active_feed, true);
            }
            var stories = data.stories;
            var tags = data.tags;
            var feed_id = data.feed_id;
            
            if (this.active_feed == feed_id) {
                // NEWSBLUR.log(['post_open_feed', data.stories, this.flags]);
                this.flags['feed_view_positions_calculated'] = false;
                this.story_titles_clear_loading_endbar();
                this.create_story_titles(stories);
                this.hover_over_story_titles();
                this.make_story_feed_entries(stories, first_load);
                this.show_correct_stories_in_page_and_feed_view();
                $('.NB-feedbar-last-updated-date').text(data.last_update + ' ago');
                if (this.flags['find_next_unread_on_page_of_feed_stories_load']) {
                    this.show_next_unread_story(true);
                }
                if (!first_load) {
                    var stories_count = this.cache['iframe_story_positions_keys'].length;
                    this.flags.iframe_story_locations_fetched = false;
                    var $iframe = this.$s.$story_iframe.contents();
                    this.fetch_story_locations_in_story_frame(stories_count, false, $iframe);
                } else {
                    this.flags['story_titles_loaded'] = true;
                    if (this.flags['iframe_view_loaded']) {
                        // NEWSBLUR.log(['Titles loaded, iframe loaded']);
                        var $iframe = this.$s.$story_iframe.contents();
                        this.fetch_story_locations_in_story_frame(0, true, $iframe);
                    } else {
                        // NEWSBLUR.log(['Titles loaded, iframe NOT loaded -- prefetching now']);
                        this.prefetch_story_locations_in_story_frame();
                    }
                }
            }
        },
        
        set_correct_story_view_for_feed: function(feed_id) {
          var feed = this.model.get_feed(feed_id);
          var view = this.model.view_setting(feed_id);
          
          if (feed.has_exception && feed.exception_type == 'page') {
            if (view == 'page') {
              view = 'feed';
            }
            $('.task_view_page').addClass('NB-exception-page');
          } else {
            $('.task_view_page').removeClass('NB-exception-page');
          }
          
          this.story_view = view;
        },
        
        delete_feed: function(feed_id, $feed) {
            var self = this;
            $feed = $feed || this.find_feed_in_feed_list(feed_id);
            $feed.slideUp(500);
            
            if (this.active_feed == $feed.data('feed_id')) {
                this.reset_feed();
                this.show_splash_page();
            }
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
        },
        
        // ==========================
        // = Story Pane - All Views =
        // ==========================
        
        open_story: function(story, $st, skip_scrolls) {
            var self = this;
            var feed_position;
            var iframe_position;
            
            if (this.active_story != story) {
                
                this.active_story = story;
                // NEWSBLUR.log(['Story', story, this.flags.iframe_view_loaded, skip_scrolls, $feed_story, $iframe_story]);
            
                this.mark_story_title_as_selected($st);
                this.mark_story_as_read(story.id, $st);
            
                this.flags.scrolling_by_selecting_story_title = true;
                if (!skip_scrolls) {
                    // User clicks on story, scroll them to it.
                    var $feed_story = this.find_story_in_feed_view(story);
                    var $iframe_story = this.find_story_in_story_iframe(story);
                    
                    // if (!this.flags.iframe_view_loaded) {
                    if (!$iframe_story || !$iframe_story.length || !this.flags['story_titles_loaded']) {
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
                        // feed_position = this.scroll_to_story_in_story_feed(story, $feed_story);
                    } else if (this.story_view == 'page' && this.flags['page_view_showing_feed_view']) {
                        // iframe_position = this.scroll_to_story_in_iframe(story, $iframe_story);
                    } else if (this.story_view == 'feed' || this.story_view == 'story') {
                        // iframe_position = this.scroll_to_story_in_iframe(story, $iframe_story);
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
        
        scroll_to_story_in_story_feed: function(story, $story, skip_scroll) {
            var self = this;
            var $feed_view = this.$s.$feed_view;

            if (!story || !$story || !$story.length) {
                $story = $('.story:first', $feed_view);
                story = this.model.get_story($story.data('story'));
            }
            if (!story || !$story || !$story.length) {
                return;
            }
            
            // NEWSBLUR.log(['scroll_to_story_in_story_feed', story, $story]);

            if ($story && $story.length) {
                if (skip_scroll || (this.story_view == 'page'
                                    && !this.flags['page_view_showing_feed_view'])) {
                    $feed_view.scrollTo($story, 0, { axis: 'y', offset: 0 }); // Do this at view switch instead.
                    
                } else if (this.story_view == 'feed' || this.flags['page_view_showing_feed_view']) {
                    $feed_view.scrollable().stop();
                    $feed_view.scrollTo($story, 600, { axis: 'y', easing: 'easeInOutQuint', offset: 0, queue: false });
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
        
        scroll_to_story_in_iframe: function(story, $story, skip_scroll) {
            var $iframe = this.$s.$story_iframe;

            if ($story && $story.length) {
                if (skip_scroll
                    || this.story_view == 'feed'
                    || this.story_view == 'story'
                    || this.flags['page_view_showing_feed_view']) {
                    $iframe.scrollTo($story, 0, { axis: 'y', offset: -24 }); // Do this at story_view switch
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
        
        prefetch_story_locations_in_story_frame: function() {
            var self = this;
            var stories = this.model.stories;
            var $iframe = this.$s.$story_iframe.contents();
            
            // NEWSBLUR.log(['Prefetching', !this.flags['iframe_fetching_story_locations']]);
            if (!this.flags['iframe_fetching_story_locations'] 
                && !this.flags['iframe_story_locations_fetched']) {
                $iframe.unbind('scroll').scroll($.rescope(this.handle_scroll_story_iframe, this));
                $iframe
                    .unbind('mousemove.reader')
                    .bind('mousemove.reader', $.rescope(this.handle_mousemove_iframe_view, this));
                    
                $.extend(this.cache, {
                    'iframe_stories': {},
                    'iframe_story_positions': {},
                    'iframe_story_positions_keys': []
                });
            
                for (var s in stories) {
                    var story = stories[s];
                    var $story = this.find_story_in_story_iframe(story, $iframe);
                    // NEWSBLUR.log(['Pre-fetching', $story, $iframe, story.story_title]);
                    if (!$story || !$story.length || this.flags['iframe_fetching_story_locations']) break;
                }
            }
            
            if (!this.flags['iframe_fetching_story_locations']
                && !this.flags['iframe_story_locations_fetched']) {
                setTimeout(function() {
                    if (!self.flags['iframe_fetching_story_locations']) {
                        self.prefetch_story_locations_in_story_frame();
                    }
                }, 2000);
            }
        },
        
        fetch_story_locations_in_story_frame: function(s, clear_cache, $iframe) {
            var self = this;
            var stories = this.model.stories;
            if (!s) s = 0;
            var story = stories[s];
            if (!$iframe) $iframe = this.$s.$story_iframe.contents();
            
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
                        self.flags['iframe_story_locations_fetched'] = true;
                        self.flags['iframe_fetching_story_locations'] = false;
                        clearInterval(self.flags['iframe_scroll_snapback_check']);
                    }
                }, 50);
            } else if (story && story['story_feed_id'] != this.active_feed) {
                NEWSBLUR.log(['Switched off iframe early']);
            }
        },
        
        open_story_link: function(story, $st) {
            window.open(unescape(decodeURIComponent(story['story_permalink'])), '_blank');
            window.focus();
        },
        
        mark_story_title_as_selected: function($story_title) {
            var $story_titles = this.$s.$story_titles;
            $('.selected', $story_titles).removeClass('selected');
            $('.after_selected', $story_titles).removeClass('after_selected');
            $story_title.addClass('selected');
            $story_title.parent('.story').next('.story').children('a').addClass('after_selected');
        },
        
        mark_story_as_read: function(story_id, $story_title) {
            var self = this;
            var feed_id = this.active_feed;
            var feed = this.model.get_feed(feed_id);
            var $feed_list = this.$s.$feed_list;
            var $feed = $('.feed.selected', $feed_list);
            var $feed_counts = $('.feed_counts_floater', $feed);
            var $content_pane = this.$s.$content_pane;
            
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
                        $feed_counts.removeClass('unread_positive');
                    } else {
                        $feed.addClass('unread_positive');
                        $feed_counts.addClass('unread_positive');
                    }
                } else if ($story_title.is('.NB-story-neutral')) {
                    var count = Math.max(unread_count_neutral-1, 0);
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
                    var count = Math.max(unread_count_negative-1, 0);
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
                
                $('.feed', $content_pane).animate({'opacity': 1}, {'duration': 250, 'queue': false});
                    
                setTimeout(function() {
                    $('.feed', $content_pane).animate({'opacity': .1}, {'duration': 250, 'queue': false});
                }, 400);

                
                if (!$feed.is(':visible')) {
                    // NEWSBLUR.log(['Under collapsed folder', $feed, $feed.parents(':visible'),
                    //               $feed.parents(':visible').eq(0).children('.folder_title')]);
                    var $folder_title = $feed.parents(':visible').eq(0).children('.folder_title');
                    var $children = $folder_title.parent('.folder').children('.folder, .feed');
                    self.show_collapsed_folder_count($folder_title, $children);
                }
                
                return;
            };

            $story_title.addClass('read');
            
            this.model.mark_story_as_read(story_id, feed_id, callback);
        },
        
        mark_feed_as_read: function(feed_id) {
            var self = this;
            feed_id = feed_id || this.active_feed;
            
            this.mark_feed_as_read_update_counts(feed_id);

            this.model.mark_feed_as_read([feed_id]);
        },
        
        mark_folder_as_read: function(folder_name, $folder) {
            var self = this;
            var feeds = this.get_feed_ids_in_folder($folder);
            
            _.each(feeds, _.bind(function(feed_id) {
                this.mark_feed_as_read_update_counts(feed_id);
            }, this));
            this.mark_feed_as_read_update_counts(null, $folder);
            this.model.mark_feed_as_read(feeds);
        },
        
        mark_feed_as_read_update_counts: function(feed_id, $folder) {
            if (feed_id) {
                var feed = this.model.get_feed(feed_id);
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
        
        mark_story_as_like: function(story_id, $button) {
            var feed_id = this.active_feed;
            
            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierStory(story_id, feed_id, {'score': 1});
        },
        
        mark_story_as_dislike: function(story_id, $button) {
            var feed_id = this.active_feed;
            
            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierStory(story_id, feed_id, {'score': -1});
        },
        
        // =====================
        // = Story Titles Pane =
        // =====================
        
        make_content_pane_feed_counter: function(feed_id) {
            var $content_pane = this.$s.$content_pane;
            var feed = this.model.get_feed(feed_id);
            var $counter = this.make_feed_title_line(feed, false, 'counter');
            
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
            var $story_titles = this.$s.$story_titles;
            
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
        
        make_story_title: function(story) {
            var unread_view = this.model.preference('unread_view');
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
                $.make('a', { href: unescape(decodeURIComponent(story.story_permalink)), className: 'story_title' }, [
                    $.make('span', { className: 'NB-storytitles-title' }, story.story_title),
                    $.make('span', { className: 'NB-storytitles-author' }, story.story_authors),
                    $story_tags
                ]),
                $.make('span', { className: 'story_date' }, story.short_parsed_date),
                $.make('span', { className: 'story_id' }, ''+story.id),
                $.make('div', { className: 'NB-story-sentiment NB-story-like', title: 'What I like about this story...' }),
                $.make('div', { className: 'NB-story-sentiment NB-story-dislike', title: 'What I dislike about this story...' })
            ]).data('story_id', story.id);
            
            if (unread_view > score) {
                $story_title.css({'display': 'none'});
            }
            
            return $story_title;
        },
        
        story_titles_clear_loading_endbar: function() {
            var $story_titles = this.$s.$story_titles;
            
            var $endbar = $('.NB-story-titles-end-stories-line', $story_titles);
            if ($endbar.length) {
                $endbar.remove();
                clearInterval(this.feed_stories_loading);
            }
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
        
        // =================================
        // = Story Pane - iFrame/Page View =
        // =================================
        
        unload_iframe: function() {
            var $story_iframe = this.$s.$story_iframe;
            
            this.flags['iframe_view_loaded'] = false;
            this.flags['iframe_story_locations_fetched'] = false;
            this.flags['iframe_prevented_from_loading'] = false;
            
            $.extend(this.cache, {
                'iframe_stories': {},
                'iframe_story_positions': {},
                'iframe_story_positions_keys': []
            });
            
            $story_iframe.removeAttr('src');
        },
        
        load_iframe: function(feed_id) {
            var self = this;
            var $feed_view = this.$s.$story_pane;
            var $story_iframe = this.$s.$story_iframe;
            var $taskbar_view_page = $('.NB-taskbar .task_view_page');
            var $taskbar_return = $('.NB-taskbar .task_return');
            
            this.unload_iframe();
            
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

                setTimeout(function() {
                    $story_iframe.load(function() {
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
        
        return_to_snapback_position: function(iframe_loaded) {
            var $story_iframe = this.$s.$story_iframe;
            
            if (this.iframe_scroll
                && this.flags.iframe_scroll_snap_back_prepared 
                && $story_iframe.contents().scrollTop() == 0) {
                // NEWSBLUR.log(['Snap back, loaded, scroll', this.iframe_scroll]);
                $story_iframe.contents().scrollTop(this.iframe_scroll);
                if (iframe_loaded) {
                    this.flags.iframe_scroll_snap_back_prepared = false;
                    clearInterval(self.flags['iframe_scroll_snapback_check']);
                }
            }
        },
        
        setup_feed_page_iframe_load: function() {
            var self = this;
            var $story_pane = this.$s.$story_pane;
            var $story_iframe = this.$s.$story_iframe;
                
            $story_iframe.removeAttr('src').load(function() {
                self.flags.iframe_view_loaded = true;
                try {
                    var $iframe_contents = $story_iframe.contents();
                    $iframe_contents.find('a')
                        .unbind('click.NB-taskbar')
                        .bind('click.NB-taskbar', function(e) {
                        var href = $(this).attr('href');
                        if (href.indexOf('#') == 0) {
                            e.preventDefault();
                            var $footnote = $('a[name='+href.substr(1)+'], [id='+href.substr(1)+']',
                                              $iframe_contents);
                            // NEWSBLUR.log(['Footnote', $footnote, href, href.substr(1)]);
                            $iframe_contents.scrollTo($footnote, 600, { 
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
                        .scroll($.rescope(self.handle_scroll_story_iframe, self));
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
            var $story_iframe = $('.NB-feed-frame');

            setTimeout(function() {
                var $story_iframe = $('.NB-feed-frame');
                var $taskbar_return = $('.NB-taskbar .task_return');
                var $taskbar_view_page = $('.NB-taskbar .task_view_page');
        
                try {
                    var length = $story_iframe.contents().find('body').length;
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
            var $story_titles = this.$s.$story_titles;
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
        
        hover_over_story_titles: function() {
            var $story_titles = this.$s.$story_titles;
            
            $('.story', $story_titles).each(function() {
                $(this)
                    .unbind('mouseenter')
                    .unbind('mouseleave');
            });
            $('.story', $story_titles)
                .hover(function() {
                    $(this).siblings('.story.NB-hover').removeClass('NB-hover');
                    $(this).addClass("NB-hover");
                }, function() {
                    $(this).siblings('.story.NB-hover').removeClass('NB-hover');
                    $(this).removeClass("NB-hover");                
                });
        },
        
        show_feed_title_in_stories: function($story_titles, feed_id) {
            var feed = this.model.get_feed(feed_id);

            var $feedbar = $.make('div', { className: 'NB-feedbar' }, [
                this.make_feed_title_line(feed, false, 'story'),
                $.make('div', { className: 'NB-feedbar-intelligence' }, [
                    $.make('div', { className: 'NB-feed-sentiment NB-feed-like', title: 'What I like about this site...' }),
                    $.make('div', { className: 'NB-feed-sentiment NB-feed-dislike', title: 'What I dislike about this site...' })
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
            if (!feed_id) feed_id = this.active_feed;
            this.mark_feed_as_read(feed_id);
            var feed = this.model.get_feed(feed_id);
            window.open(feed['feed_link'], '_blank');
            window.focus();
        },
        
        mark_feed_as_selected: function(feed_id, $feed_link) {
            if (!$feed_link) {
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

            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierFeed(feed_id, {
                'score': score,
                'feed_loaded': feed_loaded
            });
        },
        
        open_trainer_modal: function(score) {
            var feed_id = this.active_feed;

            // NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierFeed(feed_id, {'score': score});
            NEWSBLUR.classifier = new NEWSBLUR.ReaderClassifierTrainer({'score': score});
        },
        
        // ==========================
        // = Story Pane - Feed View =
        // ==========================
        
        make_story_feed_entries: function(stories, first_load, refresh_load) {
            var $feed_view = this.$s.$feed_view;
            var self = this;
            var unread_view = this.model.preference('unread_view');
            var $stories;
            
            if (first_load) {
                $stories = $.make('ul', { className: 'NB-feed-stories' });
                $feed_view.empty();
                $feed_view.scrollTop('0px');
                $feed_view.append($stories);
            } else {
                $stories = $('.NB-feed-stories', $feed_view);
                if (!refresh_load) {
                    $('.NB-feed-story-endbar', $feed_view).remove();
                }
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
                            $.make('a', { className: 'NB-feed-story-title', href: unescape(decodeURIComponent(story.story_permalink)) }, story.story_title)
                        ]),
                        ( story.long_parsed_date &&
                            $.make('span', { className: 'NB-feed-story-date' }, story.long_parsed_date))
                    ]),
                    $.make('div', { className: 'NB-feed-story-content' }, story.story_content)                
                ]).data('story', story.id);
                
                if (NEWSBLUR.Preferences.new_window == 1) {
                    $('a', $story).attr('target', '_blank');
                }
                
                if (refresh_load) {
                    $stories.prepend($story);
                } else {
                    $stories.append($story);
                }
                
                this.cache.feed_view_stories[story.id] = $story;
                
                var image_count = $('img', $story).length;
                if (!image_count) {
                    this.flags.feed_view_images_loaded[story.id] = true;
                } else {
                    // Progressively load the images in each story, so that when one story
                    // loads, the position is calculated and the next story can calculate
                    // its position (atfer its own images are loaded).
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
                        }, 600);
                        
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
                var $feed_view = this.$s.$feed_view;
                var $stories = $('.NB-feed-stories', $feed_view);
                var $endbar = $.make('div', { className: 'NB-feed-story-endbar' });
                $stories.append($endbar);
            }
        },
        
        determine_feed_view_story_position: function($story, story) {
            if ($story && $story.is(':visible')) {
                var position_original = parseInt($story.offset().top, 10);
                var position_offset = parseInt($story.offsetParent().scrollTop(), 10);
                var position = position_original + position_offset;
                this.cache.feed_view_story_positions[position] = story;
                this.cache.feed_view_story_positions_keys.push(position);
                this.cache.feed_view_story_positions_keys.sort(function(a,b) {return a>b;});    
                // NEWSBLUR.log(['Positioning story', position, $story, story, this.cache.feed_view_story_positions_keys]);
            }
        },
        
        // ===================
        // = Taskbar - Story =
        // ===================
        
        switch_taskbar_view: function(view, story_not_found) {
            var self = this;
            var $story_pane = this.$s.$story_pane;
            var feed = this.model.get_feed(this.active_feed);
            
            if (view == 'page' && feed.has_exception && feed.exception_type == 'page') {
              this.open_feed_exception_modal(this.active_feed);
              return;
            }
            // NEWSBLUR.log(['$button', $button, this.flags['page_view_showing_feed_view'], $button.hasClass('NB-active'), story_not_found]);
            var $taskbar_buttons = $('.NB-taskbar .task_button_view');
            var $feed_view = this.$s.$feed_view;
            var $story_iframe = this.$s.$story_iframe;
            var $page_to_feed_arrow = $('.NB-taskbar .NB-task-view-page-to-feed-arrow');
            
            if (!story_not_found && this.story_view != view) {
                this.model.view_setting(this.active_feed, view);
            }
            
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
            
            this.flags.scrolling_by_selecting_story_title = true;
            clearInterval(this.locks.scrolling);
            this.locks.scrolling = setTimeout(function() {
                self.flags.scrolling_by_selecting_story_title = false;
            }, 1000);
            
            if (view == 'page') {
                if (this.flags['iframe_prevented_from_loading']) {
                    this.load_iframe(this.active_feed);
                }
                var $iframe_story = this.find_story_in_story_iframe(this.active_story);
                this.scroll_to_story_in_iframe(this.active_story, $iframe_story, true);
                
                $story_pane.animate({
                    'left': 0
                }, {
                    'easing': 'easeInOutQuint',
                    'duration': 750,
                    'queue': false
                });
            } else if (view == 'feed') {
                var $feed_story = this.find_story_in_feed_view(this.active_story);
                if (this.active_story) {
                    this.scroll_to_story_in_story_feed(this.active_story, $feed_story, true);
                }
                
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
            var $feed_view = this.$s.$feed_view;
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
        
        // ===================
        // = Taskbar - Feeds =
        // ===================
        
        open_add_feed_modal: function() {
            clearInterval(this.flags['bouncing_callout']);
            $.modal.close();
            
            NEWSBLUR.add_feed = new NEWSBLUR.ReaderAddFeed();
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
                
        open_preferences_modal: function() {
            NEWSBLUR.preferences = new NEWSBLUR.ReaderPreferences();
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
        
        force_feed_refresh: function(feed_id) {
            var self = this;
            var $feed = this.find_feed_in_feed_list(feed_id);
            $feed.addClass('NB-feed-unfetched').removeClass('NB-feed-exception');
            
            this.model.save_exception_retry(feed_id, function() {
                self.force_feeds_refresh(function(feeds) {
                    var $new_feed = self.make_feed_title_line(feeds[feed_id], true, 'feed');
                    $feed.replaceWith($new_feed);
                    self.hover_over_feed_titles($new_feed);
                    if (self.active_feed == feed_id) {
                        self.open_feed(feed_id, true, $new_feed);
                    }
                }, true);
            });
        },

        make_manage_menu: function(type, feed_id, inverse, $item) {
            var $manage_menu;
            
            if (type == 'site') {
                var show_chooser = !NEWSBLUR.Globals.is_premium && NEWSBLUR.Globals.is_authenticated;
                $manage_menu = $.make('ul', { className: 'NB-menu-manage' }, [
                    $.make('li', { className: 'NB-menu-manage-site-info' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('span', { className: 'NB-menu-manage-title' }, "Manage NewsBlur")
                    ]).corner('tl tr 8px'),
                    $.make('li', { className: 'NB-menu-separator' }), 
                    $.make('li', { className: 'NB-menu-manage-keyboard' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Keyboard shortcuts')
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
                    $.make('li', { className: 'NB-menu-manage-preferences' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Preferences'),
                        $.make('div', { className: 'NB-menu-manage-subtitle' }, 'Defaults and options.')
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
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Intelligence trainer')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
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
                if (feed_id && this.get_unread_count(true, feed_id) == 0) {
                    $('.NB-menu-manage-feed-mark-read', $manage_menu).addClass('NB-disabled');
                }
            } else if (type == 'folder') {
                $manage_menu = $.make('ul', { className: 'NB-menu-manage' }, [
                    $.make('li', { className: 'NB-menu-separator-inverse' }),
                    $.make('li', { className: 'NB-menu-manage-feed NB-menu-manage-mark-read NB-menu-manage-folder-mark-read' }, [
                        $.make('div', { className: 'NB-menu-manage-image' }),
                        $.make('div', { className: 'NB-menu-manage-title' }, 'Mark folder as read')
                    ]),
                    $.make('li', { className: 'NB-menu-separator' }),
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
            }
            
            if (inverse) $manage_menu.addClass('NB-inverse');
            return $manage_menu;
        },
        
        show_manage_menu: function(type, $item) {
            var self = this;
            var $manage_menu_container = $('.NB-menu-manage-container');
            // NEWSBLUR.log(['show_manage_menu', type, $item, $manage_menu_container.data('item'), $item && $item[0] == $manage_menu_container.data('item')]);
            clearTimeout(this.flags.closed_manage_menu);
            
            // If another menu is open, hide it first.
            // If this menu is already open, then hide it instead.
            if (($item && $item[0] == $manage_menu_container.data('item')) && 
                parseInt($manage_menu_container.css('opacity'), 10) == 1) {
                this.hide_manage_menu(type);
                return;
            } else {
                this.hide_manage_menu(type);
            }
            
            // Create menu, size and position it, then attach to the right place.
            var feed_id = $item && $item.data('feed_id');
            var inverse = type == 'folder' ?
                          $('.folder_title', $item).hasClass("NB-hover-inverse") :
                          $item.hasClass("NB-hover-inverse");
            var toplevel = $item.hasClass("NB-toplevel");
            if (type == 'folder') {
                feed_id = $('.folder_title_text', $item).eq(0).text();
            }
            var $manage_menu = this.make_manage_menu(type, feed_id, inverse, $item);
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
            } else if (type == 'feed' || type == 'folder') {
                if (inverse) {
                    var left = toplevel ? 0 : -20;
                    var top = toplevel ? 24 : 21;
                    var $align;
                    if (type == 'feed') $align = $item;
                    else $align = $('.folder_title', $item);
                    $manage_menu_container.align($align, '-bottom -left', {
                        'top': -1 * top, 
                        'left': left
                    });
                    $manage_menu_container.corner('br 8px');
                    $('li', $manage_menu_container).each(function() {
                        $(this).prependTo($(this).parent());
                    });
                } else {
                    var left = toplevel ? 2 : -20;
                    var top = 21;
                    $manage_menu_container.align($item, '-top -left', {
                        'top': top, 
                        'left': left
                    });
                    $manage_menu_container.corner('tr 8px');
                }
            }
            $manage_menu_container.stop().css({'display': 'block', 'opacity': 1});
            
            // Create and position the arrow tab
            if (type == 'feed' || type == 'folder') {
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
            this.flags['feed_list_showing_manage_menu'] = true;
            this.$s.$feed_list.unbind('scroll.manage_menu').bind('scroll.manage_menu', function(e) {
                if (self.flags['feed_list_showing_manage_menu']) {
                    self.hide_manage_menu(type, $item, true);
                } else {
                    self.$s.$feed_list.unbind('scroll.manage_menu');
                }
            });
        },
        
        hide_manage_menu: function(type, $item, animate) {
            var $manage_menu_container = $('.NB-menu-manage-container');
            var height = $manage_menu_container.outerHeight();
            
            // NEWSBLUR.log(['hide_manage_menu', type, $item, animate, $manage_menu_container.css('opacity')]);
            
            clearTimeout(this.flags.closed_manage_menu);
            this.flags['feed_list_showing_manage_menu'] = false;
            $(document).unbind('click.menu');
            $manage_menu_container.uncorner();

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
            var text = 'Delete this site';
            if ($delete.hasClass('NB-menu-manage-folder-delete')) {
                text = "Delete this folder";
            }
            $('.NB-menu-manage-title', $delete).text(text);
            $confirm.slideUp(500);
        },
        
        manage_menu_delete_feed: function(feed, $feed) {
            var self = this;
            var feed_id = feed || this.active_feed;
            $feed = $feed || this.find_feed_in_feed_list(feed_id);
            
            var in_folder = $feed.parents('li.folder').eq(0).find('.folder_title_text').eq(0).text();
            
            this.model.delete_feed(feed_id, in_folder, function() {
                self.delete_feed(feed_id, $feed);
            });
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
                    self.switch_feed_view_unread_view(ui.value);
                    if (self.model.preference('unread_view') != ui.value) {
                        self.model.preference('unread_view', ui.value);
                    }
                    self.flags['feed_view_positions_calculated'] = false;
                    self.show_correct_story_titles_in_unread_view({'animate': true, 'follow': true});
                }
            });
        },
        
        switch_feed_view_unread_view: function(unread_view) {
            var $feed_list = this.$s.$feed_list;
            var unread_view_name = this.get_unread_view_name(unread_view);
            var $next_story_button = $('.task_story_next_unread');
                        
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
            feed_id = feed_id || this.active_feed;
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
        },
        
        show_correct_story_titles_in_unread_view: function(options) {
            var self = this;
            var $story_titles = this.$s.$story_titles;
            var unread_view_name = this.get_unread_view_name();
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
            if (options['animate'] && options['follow']) {
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
                    } else if (name == 'feed') {
                        self.model.classifiers.feeds[feed_id] = score;
                    }
                } else {
                    if (name == 'tag' && self.model.classifiers.tags[value] == score) {
                        delete self.model.classifiers.tags[value];
                    } else if (name == 'title' && self.model.classifiers.titles[value] == score) {
                        delete self.model.classifiers.titles[value];
                    } else if (name == 'author' && self.model.classifiers.authors[value] == score) {
                        delete self.model.classifiers.authors[value];
                    } else if (name == 'feed' && self.model.classifiers.feeds[feed_id] == score) {
                        delete self.model.classifiers.feeds[feed_id];
                    }
                }
            });
            
        },
        
        // ===================
        // = Feed Refreshing =
        // ===================
        
        setup_feed_refresh: function() {
            var self = this;
            
            clearInterval(this.flags.feed_refresh);
            
            this.flags.feed_refresh = setInterval(function() {
                if (!self.flags['pause_feed_refreshing']) {
                  self.model.refresh_feeds(_.bind(function(updated_feeds) {
                      self.post_feed_refresh(updated_feeds);
                  }, self), self.flags['has_unfetched_feeds']);
                }
            }, this.FEED_REFRESH_INTERVAL);
        },
        
        force_feeds_refresh: function(callback, update_all) {
            if (callback) {
                this.cache.refresh_callback = callback;
            } else {
                delete this.cache.refresh_callback;
            }

            this.flags['pause_feed_refreshing'] = true;

            this.model.refresh_feeds(_.bind(function(updated_feeds) {
              this.post_feed_refresh(updated_feeds, update_all);
            }, this), this.flags['has_unfetched_feeds']);
        },
        
        post_feed_refresh: function(updated_feeds, update_all) {
            var feeds = this.model.feeds;
            
            if (this.cache.refresh_callback && $.isFunction(this.cache.refresh_callback)) {
                this.cache.refresh_callback(feeds);
                delete this.cache.refresh_callback;
            }
            
            for (var f in updated_feeds) {
                var feed_id = updated_feeds[f];
                var feed = this.model.get_feed(feed_id);
                if (!feed) continue;
                var $feed = this.make_feed_title_line(feed, true, 'feed');
                var $feed_on_page = this.find_feed_in_feed_list(feed_id);
                
                if (feed_id == this.active_feed) {
                    NEWSBLUR.log(['UPDATING INLINE', feed.feed_title, $feed, $feed_on_page]);
                    var limit = $('.story', this.$s.$story_titles).length;
                    // this.model.refresh_feed(feed_id, $.rescope(this.post_refresh_active_feed, this), limit);
                    $feed_on_page.replaceWith($feed);
                    this.mark_feed_as_selected(this.active_feed, $feed);
                } else {
                    if (!this.flags['has_unfetched_feeds']) {
                        NEWSBLUR.log(['UPDATING', feed.feed_title, $feed, $feed_on_page]);
                    }
                    $feed_on_page.replaceWith($feed);
                }
                this.hover_over_feed_titles($feed);
            }
            
            this.check_feed_fetch_progress();

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
                    var $story = this.find_story_in_story_titles(story);
                    var $feed_story = this.find_story_in_feed_view(story);
                    
                    if ($story && $story.length) {
                        // Just update intelligence
                        var score = this.compute_story_score(story);
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
                    this.make_story_feed_entries(new_stories, false, true);
                    this.hover_over_story_titles();
                    this.flags['feed_view_positions_calculated'] = false;
                }
                this.show_correct_story_titles_in_unread_view({'animate': true, 'follow': false});
            }
        },
        
        // ===================
        // = Mouse Indicator =
        // ===================
        
        handle_mousemove_feed_view: function(elem, e) {
            var self = this;
            
            this.show_mouse_indicator();
            
            if (parseInt(this.model.preference('lock_mouse_indicator'), 10)) {
                return;
            }

            this.cache.mouse_position_y = e.pageY ;
            this.$s.$mouse_indicator.css('top', this.cache.mouse_position_y - 8);
            
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
                var from_top = this.cache.mouse_position_y + this.$s.$feed_view.scrollTop();
                var positions = this.cache.feed_view_story_positions_keys;
                var closest = $.closest(from_top, positions);
                var story = this.cache.feed_view_story_positions[positions[closest]];
                this.flags['mousemove_timeout'] = true;
                // NEWSBLUR.log(['Mousemove feed view', from_top, closest, positions[closest]]);
                this.navigate_story_titles_to_story(story);
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
            var $signup_username = $('input[name=signup-signup_username]');
            
            $signup_username.bind('focus', function() {
                $hidden_inputs.slideDown(300);
            }).bind('blur', function() {
                if ($signup_username.val().length < 2) {
                    $hidden_inputs.slideUp(300);
                }
            });
        },
        
        // ==================
        // = Features Board =
        // ==================
        
        load_feature_page: function(direction) {
            var self = this;
            var $next = $('.NB-module-features .NB-module-next-page');
            var $previous = $('.NB-module-features .NB-module-previous-page');
            
            if (direction == -1 && !this.counts['feature_page']) {
                return;
            }
            if (direction == 1 && this.flags['features_last_page']) {
                return;
            }
            
            this.model.get_features_page(this.counts['feature_page']+direction, function(features) {
                self.counts['feature_page'] += direction;
                
                var $table = $.make('table', { cellSpacing: 0, cellPadding: 0 });
                for (var f in features) {
                    if (f == 3) break;
                    var feature = features[f];
                    var $tr = $.make('tr', { className: 'NB-module-feature' }, [
                        $.make('td', { className: 'NB-module-feature-date' }, feature.date),
                        $.make('td', { className: 'NB-module-feature-description' }, feature.description)
                    ]);
                    $table.append($tr);
                }
                
                $('.NB-module-features table').replaceWith($table);
                
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
            
            $('.NB-progress-title', $progress).text('Importing from Google Reader');
            $('.NB-progress-counts', $progress).hide();
            $('.NB-progress-percentage', $progress).hide();
            $bar.progressbar({
                value: percentage
            });
            
            var animate = function() {
                var time = 50;
                if (percentage > 90) {
                    time = 500;
                } else if (percentage > 80) {
                    time = 400;
                } else if (percentage > 70) {
                    time = 300;
                } else if (percentage > 60) {
                    time = 200;
                } else if (percentage > 50) {
                    time = 100;
                }
                setTimeout(function() {
                    if (!self.flags['import_from_google_reader_finished']) {
                        percentage += 1;
                        $bar.progressbar({value: percentage});
                        animate();
                    }
                }, time);
            };
            animate();
            
            this.show_progress_bar();
            
            this.model.start_import_from_google_reader($.rescope(this.finish_import_from_google_reader, this));
        },

        finish_import_from_google_reader: function(e, data) {
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            this.flags['import_from_google_reader_finished'] = true;
            
            if (data.code >= 1) {
                $bar.progressbar({value: 100});
                this.load_feeds();
            } else {
                NEWSBLUR.log(['Import Error!', data]);
                this.$s.$feed_link_loader.fadeOut(250);
                $progress.addClass('NB-progress-error');
                $('.NB-progress-title', $progress).text('Error importing Google Reader');
                $('.NB-progress-link', $progress).html($.make('a', { href: NEWSBLUR.URLs['google-reader-authorize'], className: 'NB-splash-link' }, 'Try importing again'));
            }
        },

        start_count_unreads_after_import: function() {
            var self = this;
            var $progress = this.$s.$feeds_progress;
            var $bar = $('.NB-progress-bar', $progress);
            var percentage = 0;
            var factor = 17500 * _.keys(this.model.feeds).length / 40000;
            
            this.flags['count_unreads_after_import_finished'] = false;
            
            $('.NB-progress-title', $progress).text('Counting is difficult');
            $('.NB-progress-counts', $progress).hide();
            $('.NB-progress-percentage', $progress).hide();
            $bar.progressbar({
                value: percentage
            });
            
            var animate = function() {
                // 17,500 ticks
                var time = factor;
                if (percentage > 90) {
                    time = factor * 100;
                } else if (percentage > 80) {
                    time = factor * 50;
                } else if (percentage > 70) {
                    time = factor * 20;
                } else if (percentage > 60) {
                    time = factor * 8;
                } else if (percentage > 50) {
                    time = factor * 2;
                }
                setTimeout(function() {
                    if (!self.flags['count_unreads_after_import_finished']) {
                        percentage += 1;
                        $bar.progressbar({value: percentage});
                        animate();
                    }
                }, time);
            };
            animate();
            
            setTimeout(function() {
                if (!self.flags['count_unreads_after_import_finished']) {
                    self.show_progress_bar();
                }
            }, 500);
        },

        finish_count_unreads_after_import: function(e, data) {
            $('.NB-progress-bar', this.$s.$feeds_progress).progressbar({
                value: 100
            });
            this.flags['count_unreads_after_import_finished'] = true;
            this.$s.$feed_link_loader.fadeOut(250);
            this.setup_feed_refresh();
            if (!this.flags['has_unfetched_feeds']) {
                this.hide_progress_bar();
            }
        },
        
        // ==========
        // = Events =
        // ==========

        handle_clicks: function(elem, e) {
            var self = this;
            var stopPropagation = false;
            // var start = (new Date().getMilliseconds());
            
            // Feeds ==========================================================
            
            $.targetIs(e, { tagSelector: '#feed_list .NB-feedlist-manage-icon' }, function($t, $p) {
                e.preventDefault();
                e.stopPropagation();
                if (!self.flags['sorting_feed']) {
                    stopPropagation = true;
                    if ($t.parent().hasClass('feed')) {
                        self.show_manage_menu('feed', $t.parents('.feed').eq(0));
                    } else {
                        self.show_manage_menu('folder', $t.parents('.folder').eq(0));
                    }
                }
            });
            if (stopPropagation) return;
            $.targetIs(e, { tagSelector: '#feed_list .feed.NB-feed-exception' }, function($t, $p){
                e.preventDefault();
                e.stopPropagation();
                if (!self.flags['sorting_feed']) {
                    var feed_id = $t.data('feed_id');
                    stopPropagation = true;
                    self.open_feed_exception_modal(feed_id, $t);
                }
            });
            if (stopPropagation) return;
            
            $.targetIs(e, { tagSelector: '#feed_list .feed' }, function($t, $p){
                e.preventDefault();
                if (!self.flags['sorting_feed']) {
                    var feed_id = $t.data('feed_id');
                    self.open_feed(feed_id, false, $t);
                }
            });
            $.targetIs(e, { tagSelector: '#feed_list .folder_title' }, function($folder, $p){
                e.preventDefault();
                if (!self.flags['sorting_feed']) {
                    self.collapse_folder($folder);
                }
            });
            $.targetIs(e, { tagSelector: '.NB-feedbar-mark-feed-read' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.parents('.feed').data('feed_id');
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
                var story_id = self.$s.$story_pane.data('story_id');
                self.mark_story_as_like(story_id, $t);
                story_prevent_bubbling = true;
            });
            $.targetIs(e, { tagSelector: 'a.button.dislike' }, function($t, $p){
                e.preventDefault();
                var story_id = self.$s.$story_pane.data('story_id');
                self.mark_story_as_dislike(story_id, $t);
                story_prevent_bubbling = true;
            });
            
            if (story_prevent_bubbling) return false;
            
            $.targetIs(e, { tagSelector: '.story' }, function($t, $p){
                e.preventDefault();
                var story_id = $('.story_id', $t).text();
                var story = self.model.get_story(story_id);
                self.push_current_story_on_history();
                self.open_story(story, $t);
            });
            $.targetIs(e, { tagSelector: 'a.mark_story_as_read' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.attr('href').slice(1).split('/');
                self.mark_story_as_read(story_id, $t);
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-feed-train' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    var feed_id = $t.parents('.NB-menu-manage').data('feed_id');
                    self.open_feed_intelligence_modal(1, feed_id, false);
                }
            });  
            $.targetIs(e, { tagSelector: '.NB-menu-manage-trainer' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_trainer_modal();
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
                    self.force_feed_refresh(feed_id);
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
            $.targetIs(e, { tagSelector: '.NB-menu-manage-preferences' }, function($t, $p){
                e.preventDefault();
                if (!$t.hasClass('NB-disabled')) {
                    self.open_preferences_modal();
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
            $.targetIs(e, { tagSelector: '.task_button_story.task_story_next_unread' }, function($t, $p){
                e.preventDefault();
                self.show_next_unread_story();
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
            var $story_titles = this.$s.$story_titles;

            if (!($('.NB-story-titles-end-stories-line', $story_titles).length)) {
                var $last_story = $('#story_titles .story').last();
                var container_offset = $story_titles.position().top;
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
            if (this.story_view == 'page'
                && !this.flags['page_view_showing_feed_view']
                && !this.flags['scrolling_by_selecting_story_title']) {
                var from_top = this.cache.mouse_position_y + this.$s.$story_iframe.contents().scrollTop();
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
        
        hide_mouse_indicator: function() {
            var self = this;

            this.flags['mouse_indicator_hidden'] = true;
            this.$s.$mouse_indicator.animate({'opacity': 0, 'left': -10}, {
                'duration': 200, 
                'queue': false, 
                'complete': function() {
                    self.flags['mouse_indicator_hidden'] = true;
                }
            });
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
        
        handle_mousemove_iframe_view: function(elem, e) {
            var self = this;   
                     
            this.show_mouse_indicator();

            if (parseInt(this.model.preference('lock_mouse_indicator'), 10)) {
                return;
            }

            var scroll_top = this.$s.$story_iframe.contents().scrollTop();
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
                // NEWSBLUR.log(['Mousemove iframe', from_top, closest, positions[closest], this.cache.iframe_story_positions[positions[closest]]]);
                this.navigate_story_titles_to_story(story);
                // NEWSBLUR.log(['Setting snap back', this.iframe_scroll]);
            }
        },
        
        handle_scroll_feed_view: function(elem, e) {
            var self = this;
            
            if ((this.story_view == 'feed' 
                 || (this.story_view == 'page' && this.flags['page_view_showing_feed_view']))
                && !this.flags['switching_to_feed_view']
                && !this.flags.scrolling_by_selecting_story_title 
                && this.story_view != 'story') {
                var from_top = this.cache.mouse_position_y + this.$s.$feed_view.scrollTop();
                var positions = this.cache.feed_view_story_positions_keys;
                var closest = $.closest(from_top, positions);
                var story = this.cache.feed_view_story_positions[positions[closest]];
                // NEWSBLUR.log(['Scroll feed view', from_top, e, closest, positions[closest], this.cache.feed_view_story_positions_keys, positions, self.cache]);
                this.navigate_story_titles_to_story(story);
            }
        },
        
        handle_keystrokes: function() {      
            var self = this;
            var $document = $(document);
            
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
            $document.bind('keydown', 'enter', function(e) {
                e.preventDefault();
                self.open_feed_link();
            });
            $document.bind('keydown', 'return', function(e) {
                e.preventDefault();
                self.open_feed_link();
            });
            $document.bind('keydown', 'space', function(e) {
                e.preventDefault();
                self.page_in_story(0.4, 1);
            });
            $document.bind('keydown', 'shift+space', function(e) {
                e.preventDefault();
                self.page_in_story(0.4, -1);
            });
        }
        
    };

})(jQuery);