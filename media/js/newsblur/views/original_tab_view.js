NEWSBLUR.Views.OriginalTabView = Backbone.View.extend({
    
    initialize: function() {
        _.bindAll(this, 'handle_scroll_feed_iframe', 'handle_mousemove_iframe_view', 'setup_events');
        this.reset_flags();
        this.unload_feed_iframe();
        this.setElement(NEWSBLUR.reader.$s.$feed_iframe);
        
        this.setup_events();
        this.collection.bind('change:selected', this.toggle_selected_story, this);
        this.collection.bind('reset', this.reset_story_positions, this);
        this.collection.bind('add', this.reset_story_positions, this);

    },
    
    reset_flags: function() {
        this.cache = {
            iframe: {},
            prefetch_iteration: 0
        };
        this.flags = {
            iframe_fetching_story_locations: false,
            iframe_story_locations_fetched: false
        };
        this.counts = {
            positions_timer: 0
        };
        this.locks = {
            iframe_buster_buster: false
        };
    },
    
    setup_events: function() {
        var $iframe_contents = this.$el.contents();
        $iframe_contents.unbind('scroll').scroll(this.handle_scroll_feed_iframe);
        $iframe_contents.unbind('mousemove.reader').bind('mousemove.reader', this.handle_mousemove_iframe_view);
    },
    
    // ===================
    // = Story Locations =
    // ===================

    find_story_in_feed_iframe: function(story) {
        if (!story) return $([]);
        
        var $iframe = this.$el.contents();
        var $stories = $([]);
        
        if (this.flags['iframe_story_locations_fetched'] || story.id in this.cache.iframe_stories) {
            return this.cache.iframe_stories[story.id];
        }
        
        var title = story.get('story_title', '').replace(/&nbsp;|[^a-z0-9-,]/gi, '');
                        
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
                var pos = $(this).text().replace(/&nbsp;|[^a-z0-9-,]/gi, '')
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
        
        // NEWSBLUR.log(['Found stories', $stories.length, $same_size_stories.length, $same_size_stories, story.get('story_title')]);
        
        // Multiple stories at the same big font size? Determine story title overlap,
        // and choose the smallest difference in title length.
        var $story = $([]);
        if ($same_size_stories.length > 1) {
            var story_similarity = 100;
            $same_size_stories.each(function() {
                var $this = $(this);
                var story_text = $this.text();
                var overlap = Math.abs(story_text.length - story.get('story_title').length);
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
            // Check for NB-mark above and use that.
            if ($story.closest('.NB-mark').length) {
                $story = $story.closest('.NB-mark');
            }
            
            this.cache.iframe_stories[story.id] = $story;
            var position_original = parseInt($story.offset().top, 10);
            // var position_offset = parseInt($story.offsetParent().scrollTop(), 10);
            var position = position_original; // + position_offset;
            this.cache.iframe_story_positions[position] = story;
            this.cache.iframe_story_positions_keys.push(position);
            
            
            if (!this.flags['iframe_view_not_busting']) {
                var feed_id = NEWSBLUR.reader.active_feed;
                _.delay(_.bind(function() {
                    if (feed_id == NEWSBLUR.reader.active_feed) {
                        this.flags['iframe_view_not_busting'] = true;
                    }
                }, this), 200);
            }
        } else {
            this.cache['story_misses'] += 1;
        }
        
        // NEWSBLUR.log(['Found story', $story]);
        return $story;
    },
    
    scroll_to_selected_story: function(story, options) {
        var $iframe = this.$el;
        var $story = this.find_story_in_feed_iframe(story);
        options = options || {};
        
        if (!story) return;
        
        if (options.only_if_hidden && this.$el.isScrollVisible($story, true)) {
            return;
        }
        
        if (!NEWSBLUR.assets.preference('animations') ||
            NEWSBLUR.reader.story_view == 'feed' ||
            NEWSBLUR.reader.story_view == 'story' ||
            NEWSBLUR.reader.flags['page_view_showing_feed_view']) options.immediate = true;

        // NEWSBLUR.log(["Scroll in Original", story.get('story_title'), options]);
        
        if ($story && $story.length) {
            if (!options.immediate) {
                clearTimeout(NEWSBLUR.reader.locks.scrolling);
                NEWSBLUR.reader.flags['scrolling_by_selecting_story_title'] = true;
            }
            
            $iframe.stop().scrollTo($story, { 
                duration: options.immediate ? 0 : 380,
                axis: 'y', 
                easing: 'easeInOutQuint', 
                offset: -24, 
                queue: false, 
                onAfter: function() {
                    if (options.immediate) return;
                    
                    NEWSBLUR.reader.locks.scrolling = setTimeout(function() {
                        NEWSBLUR.reader.flags['scrolling_by_selecting_story_title'] = false;
                    }, 100);
                }
            });

            var parent_scroll = $story.parents('.NB-feed-story-view').scrollTop();
            var story_offset = $story.offset().top;

            return story_offset + parent_scroll;
        }

        return false;
    },
    
    prefetch_story_locations_in_story_frame: function() {
        var stories = NEWSBLUR.assets.stories;
        var $iframe = this.$el.contents();
        var prefetch_tries_left = 3;
        
        if (!this.flags['iframe_loaded']) return;
        
        this.cache['prefetch_iteration'] += 1;
        NEWSBLUR.log(['Prefetching Original', !this.flags['iframe_fetching_story_locations'], !this.flags['iframe_story_locations_fetched']]);
        if (!this.flags['iframe_fetching_story_locations'] 
            && !this.flags['iframe_story_locations_fetched']) {
            this.setup_events();
            
            var last_story_index = this.cache.iframe_story_positions_keys.length;
            var last_story_position = _.last(this.cache.iframe_story_positions_keys);
            var last_story = this.cache.iframe_story_positions[last_story_position];
            var $last_story;
            if (last_story) {
                $last_story = this.find_story_in_feed_iframe(last_story);
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
            
            NEWSBLUR.assets.stories.any(_.bind(function(story, i) {
                if (last_story_same_position && i < last_story_index) return true; 
                
                var $story = this.find_story_in_feed_iframe(story);
                // NEWSBLUR.log(['Pre-fetching', i, last_story_index, last_story_same_position, $story, story.get('story_title')]);
                if (!$story || 
                    !$story.length || 
                    this.flags['iframe_fetching_story_locations'] ||
                    this.flags['iframe_story_locations_fetched'] ||
                    parseInt($story.offset().top, 10) > this.cache['prefetch_iteration']*2000) {
                    if ($story && $story.length) {
                        NEWSBLUR.log(['Prefetch break on position too far', parseInt($story.offset().top, 10), this.cache['prefetch_iteration']*4000]);
                        return true;
                    }
                    if (!prefetch_tries_left) {
                        return true;
                    } else {
                        prefetch_tries_left -= 1;
                    }
                }
            }, this));
        }
        
        if (!this.flags['iframe_fetching_story_locations']
            && !this.flags['iframe_story_locations_fetched']) {
            setTimeout(_.bind(function() {
                if (!this.flags['iframe_fetching_story_locations']
                    && !this.flags['iframe_story_locations_fetched']) {
                    this.prefetch_story_locations_in_story_frame();
                }
            }, this), 1000);
        } else {
            this.fetch_story_locations_in_story_frame();
        }
    },
    
    fetch_story_locations_in_story_frame: function($iframe, options) {
        var self = this;
        options = options || {};
        if (!$iframe) $iframe = this.$el.contents();
        if (options.reset_timer) this.counts['positions_timer'] = 0;
        
        this.flags['iframe_fetching_story_locations'] = true;
        this.flags['iframe_story_locations_fetched'] = false;

        $.extend(this.cache, {
            'story_misses': 0,
            'iframe_stories': {},
            'iframe_story_positions': {},
            'iframe_story_positions_keys': []
        });
        
        NEWSBLUR.assets.stories.any(_.bind(function(story, i) {
            if ((story.get('story_feed_id') == NEWSBLUR.reader.active_feed || 
                "social:" + story.get('social_user_id') == NEWSBLUR.reader.active_feed)) {
                var $story = this.find_story_in_feed_iframe(story);
                // NEWSBLUR.log(['Fetching story', i, story.get('story_title'), $story]);
            
                if (self.cache['story_misses'] > 5) {
                    // NEWSBLUR.log(['iFrame view entirely loaded', self.cache['story_misses'], self.cache.iframe_stories]);
                    self.flags['iframe_story_locations_fetched'] = true;
                    self.flags['iframe_fetching_story_locations'] = false;
                    clearInterval(self.flags['iframe_scroll_snapback_check']);
                    return true;
                }
            } else if (story && story.get('story_feed_id') != NEWSBLUR.reader.active_feed &&
                       "social:" + story.get('social_user_id') != NEWSBLUR.reader.active_feed) {
                NEWSBLUR.log(['Switched off iframe early', NEWSBLUR.reader.active_feed, story.get('story_feed_id'), story.get('social_user_id')]);
                return true;
            }
        }, this));
        
        NEWSBLUR.log(['Original view entirely loaded', _.keys(self.cache.iframe_stories).length + " stories", this.counts['positions_timer']/1000 + " sec delay"]);
        
        this.counts['positions_timer'] = Math.min(60*1000, Math.max(this.counts['positions_timer']*2, 1*1000));
        clearTimeout(this.flags['next_fetch']);
        this.flags['next_fetch'] = _.delay(_.bind(this.fetch_story_locations_in_story_frame, this),
                                           this.counts['positions_timer']);
    },
    
    reset_story_positions: function(models) {
        if (!models || !models.length) {
            models = NEWSBLUR.assets.stories;
        }
        if (!models.length) return;
        if (NEWSBLUR.reader.story_view != 'page') return;
        
        this.flags['iframe_fetching_story_locations'] = false;
        this.flags['iframe_story_locations_fetched'] = false;
        
        if (NEWSBLUR.reader.flags['story_titles_loaded']) {
            this.fetch_story_locations_in_story_frame({reset_timer: true});
        } else {
            this.prefetch_story_locations_in_story_frame();
        }
    },
    
    // ===========
    // = Actions =
    // ===========
    
    iframe_not_busting: function() {
        this.flags['iframe_not_busting'] = true;
    },
    
    unload_feed_iframe: function() {
        var $taskbar_view_page = $('.NB-taskbar .task_view_page');
        $taskbar_view_page.removeClass('NB-task-return');
        
        clearInterval(this.flags['iframe_scroll_snapback_check']);
        
        this.flags['iframe_story_locations_fetched'] = false;
        NEWSBLUR.reader.flags['iframe_prevented_from_loading'] = false;
        
        $.extend(this.cache, {
            'iframe_stories': {},
            'iframe_story_positions': {},
            'iframe_story_positions_keys': [],
            'prefetch_iteration': 0,
            'iframe_scroll': 0,
            'iframe_feed_id': null
        });
        
        $.extend(this.flags, {
            'iframe_loaded': false,
            'iframe_scroll_snapback_check': false,
            'iframe_view_not_busting': false,
            'iframe_fetching_story_locations': false,
            'iframe_story_locations_fetched': false,
            'iframe_scroll_snap_back_prepared': false
        });
        
        this.$el.removeAttr('src');
        this.$el.empty();
        
        clearInterval(this.iframe_link_attacher);
    },
    
    load_feed_iframe: function(feed_id) {
        feed_id = feed_id || NEWSBLUR.reader.active_feed;
        var self = this;

        this.flags['iframe_loaded'] = true;
        
        var page_url = '/reader/page/'+feed_id;
        if (NEWSBLUR.reader.flags['social_view']) {
            var feed = NEWSBLUR.assets.get_feed(feed_id);
            page_url = feed.get('page_url');
        }
        
        NEWSBLUR.reader.flags.iframe_scroll_snap_back_prepared = true;
        this.iframe_link_attacher_num_links = 0;

        this.setup_feed_page_iframe_load();
        
        this.$el.attr('src', page_url);
        this.enable_iframe_buster_buster();
        _.delay(_.bind(function() {
            this.prefetch_story_locations_in_story_frame();
        }, this), 500);

        this.setup_events();
        this.$el.ready(function() {
            
            if (feed_id != NEWSBLUR.reader.active_feed) {
                NEWSBLUR.log(["Switched feed, unloading iframe"]);
                self.unload_feed_iframe();
                return;
            }
            
            setTimeout(function() {
                self.$el.on('load', function() {
                    self.flags.iframe_scroll_snap_back_prepared = true;
                    self.return_to_snapback_position(true);
                    self.cache.iframe_feed_id = NEWSBLUR.reader.active_feed;
                });
            }, 50);
            self.flags['iframe_scroll_snapback_check'] = setInterval(function() {
                // NEWSBLUR.log(['Checking scroll', self.cache.iframe_scroll, self.flags.iframe_scroll_snap_back_prepared, self.flags['iframe_scroll_snapback_check']]);
                if (self.cache.iframe_scroll && 
                    self.flags.iframe_scroll_snap_back_prepared &&
                    self.cache.iframe_feed_id == NEWSBLUR.reader.active_feed) {
                    self.return_to_snapback_position();
                } else {
                    clearInterval(self.flags['iframe_scroll_snapback_check']);
                }
            }, 500);
            
            var feed_iframe_src = self.$el.attr('src');
            if (feed_iframe_src && feed_iframe_src.indexOf('/reader/page/'+feed_id) != -1) {
                var iframe_link_attacher = function() {
                    var contents = self.$el.contents();
                    var num_links = contents.find('a').length;
                    // NEWSBLUR.log(['Finding links', self.iframe_link_attacher_num_links, num_links]);
                    if (self.iframe_link_attacher_num_links != num_links) {
                        // NEWSBLUR.log(['Found new links', num_links, self.iframe_link_attacher_num_links]);
                        self.iframe_link_attacher_num_links = num_links;
                        contents.find('a')
                            .unbind('click.NB-taskbar')
                            .bind('click.NB-taskbar', function() {
                            self.taskbar_show_return_to_page();
                        });
                    }
                };
                clearInterval(self.iframe_link_attacher);
                self.iframe_link_attacher = setInterval(iframe_link_attacher, 1000);
                iframe_link_attacher();
                self.$el.on('load', function() {
                    clearInterval(self.iframe_link_attacher);
                });
            }
            self.setup_events();
        });
    },
    
    return_to_snapback_position: function(iframe_loaded) {
        // console.log(["return_to_snapback_position", iframe_loaded, this.flags.iframe_scroll_snap_back_prepared, this.cache.iframe_scroll, this.cache.iframe_feed_id]);
        if (this.cache.iframe_scroll
            && this.$el.contents().scrollTop() == 0
            && this.flags.iframe_scroll_snap_back_prepared) {
            NEWSBLUR.log(['Snap back, loaded, scroll', this.cache.iframe_scroll]);
            this.$el.contents().scrollTop(this.cache.iframe_scroll);
            if (iframe_loaded) {
                this.flags.iframe_scroll_snap_back_prepared = false;
                clearInterval(this.flags['iframe_scroll_snapback_check']);
            }
        }
    },
    
    setup_feed_page_iframe_load: function() {
        this.$el.on('load', _.bind(function() {
            this.disable_iframe_buster_buster();
            this.setup_events();
            if (NEWSBLUR.reader.flags['story_titles_loaded']) {
                NEWSBLUR.log(['iframe loaded, titles loaded']);
                this.fetch_story_locations_in_story_frame();
            }
            // try {
                var $iframe_contents = this.$el.contents();
                $iframe_contents.find('a')
                    .unbind('click.NB-taskbar')
                    .bind('click.NB-taskbar', _.bind(function(e) {
                    var href = $(this).attr('href');
                    if (href && href.indexOf('#') == 0) {
                        e.preventDefault();
                        var $footnote = $('a[name='+href.substr(1)+'], [id='+href.substr(1)+']',
                                          $iframe_contents);
                        NEWSBLUR.log(['Footnote', $footnote, href, href.substr(1)]);
                        $iframe_contents.scrollTo($footnote, { 
                            duration: 600,
                            axis: 'y', 
                            easing: 'easeInOutQuint', 
                            offset: 0, 
                            queue: false 
                        });
                        return false;
                    }
                    this.taskbar_show_return_to_page();
                }, this));
            // } catch(e) {
            //     // Not on local domain. Ignore.
            // }
        }, this));

        // If the page is already loaded, just run with it, since it won't 
        // fire another load event.
        if (NEWSBLUR.reader.flags['story_titles_loaded']) {
            NEWSBLUR.log(['iframe loaded, titles loaded (early)']);
            this.fetch_story_locations_in_story_frame();
        }

    },
    
    taskbar_show_return_to_page: function() {
        _.delay(_.bind(function() {
            var $taskbar_view_page = $('.NB-taskbar .task_view_page');
    
            try {
                NEWSBLUR.log(['return', this.$el.contents().find('body')]);
                var length = this.$el.contents().find('body').length;
                if (length) {
                    return false;
                }
            } catch(e) {
                $taskbar_view_page.addClass('NB-task-return');    
            } finally {
                $taskbar_view_page.addClass('NB-task-return');    
            }
        }, this), 1000);
    },
    
    // ========================
    // = iFrame Buster Buster =
    // ========================
    
    enable_iframe_buster_buster: function() {
        var self = this;
        var prevent_bust = 0;
        window.onbeforeunload = function() { 
          prevent_bust++;
        };
        clearInterval(this.locks.iframe_buster_buster);
        this.locks.iframe_buster_buster = setInterval(function() {
            if (prevent_bust > 0) {
                prevent_bust -= 2;
                if (self.flags['iframe_story_locations_fetched'] && 
                    !self.flags['iframe_view_not_busting'] && 
                    _.contains(['page', 'story'], self.story_view) && 
                    NEWSBLUR.reader.active_feed) {
                  $('.NB-feed-frame').attr('src', '');
                  window.top.location = '/reader/buster';
                  NEWSBLUR.reader.switch_taskbar_view('feed');
                }
            }
        }, 1);
    },
    
    disable_iframe_buster_buster: function() {
        clearInterval(this.locks.iframe_buster_buster);
    },
    
    // ==========
    // = Events =
    // ==========
    
    handle_scroll_feed_iframe: function(e) {
        if (NEWSBLUR.reader.story_view == 'page'
            && !NEWSBLUR.reader.flags['page_view_showing_feed_view']
            && !NEWSBLUR.reader.flags['scrolling_by_selecting_story_title']) {
            var from_top = NEWSBLUR.reader.cache.mouse_position_y + this.$el.contents().scrollTop();
            var positions = this.cache.iframe_story_positions_keys;
            var closest = $.closest(from_top, positions);
            var story = this.cache.iframe_story_positions[positions[closest]];
            if (!story) return;
            if (story.score() < NEWSBLUR.reader.get_unread_view_score()) return;
            // NEWSBLUR.log(['Scroll iframe', from_top, closest, positions[closest], this.cache.iframe_story_positions[positions[closest]]]);
            
            if (!story.get('selected')) {
                story.set('selected', true, {selected_in_original: true, scroll: true, immediate: true});
            }
            if (!this.flags.iframe_scroll_snap_back_prepared) {
                this.cache.iframe_scroll = from_top - NEWSBLUR.reader.cache.mouse_position_y;
            }
            this.flags.iframe_scroll_snap_back_prepared = false;
        }
    },
    
    handle_mousemove_iframe_view: function(e) {
        var self = this;   
        NEWSBLUR.reader.show_mouse_indicator();

        if (parseInt(NEWSBLUR.assets.preference('lock_mouse_indicator'), 10)) {
            return;
        }

        var scroll_top = this.$el.contents().scrollTop();
        // NEWSBLUR.log(["mousemove", e, scroll_top, e.pageY]);
        NEWSBLUR.reader.cache.mouse_position_y = e.pageY - scroll_top;
        NEWSBLUR.reader.$s.$mouse_indicator.css('top', NEWSBLUR.reader.cache.mouse_position_y - 8);
        
        // setTimeout(_.bind(function() {
        //     this.flags['mousemove_timeout'] = false;
        // }, this), 40);
        
        if (this.flags['mousemove_timeout'] ||
            NEWSBLUR.reader.flags['scrolling_by_selecting_story_title']) {
            return;
        }

        var from_top = NEWSBLUR.reader.cache.mouse_position_y + scroll_top;
        var positions = this.cache.iframe_story_positions_keys;
        var closest = $.closest(from_top, positions);
        var story = this.cache.iframe_story_positions[positions[closest]];
        // NEWSBLUR.log(["mousemove", story, from_top, positions[closest], this.cache.iframe_story_positions]);
        // this.flags['mousemove_timeout'] = true;
        if (!story) return;
        if (story.score() < NEWSBLUR.reader.get_unread_view_score()) {
            if (!story.get('read_status')) {
                story.mark_read();
            }
            return;
        }
        
        if (!story.get('selected')) {
            story.set('selected', true, {selected_in_original: true, mouse: true, immediate: true});
            // this.flags['mousemove_timeout'] = false;
        }
    },
    
    toggle_selected_story: function(model, selected, options) {
        options = options || {};
        
        if (selected && 
            NEWSBLUR.reader.story_view == 'page' && 
            !options.selected_in_original &&
            !options.selected_by_scrolling) {
            var found = this.scroll_to_selected_story(model);
            NEWSBLUR.reader.switch_to_correct_view({
                story_not_found: !found
            });
            if (!found) {
                NEWSBLUR.app.story_list.scroll_to_selected_story(model);
            }
        }
    }
    
});
