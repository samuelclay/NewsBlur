NEWSBLUR.Views.StoryListView = Backbone.View.extend({
    
    el: '.NB-feed-stories',
    
    initialize: function() {
        this.collection.bind('reset', this.reset_flags, this);
        this.collection.bind('reset', this.render, this);
        this.collection.bind('reset', this.reset_story_positions, this);
        this.collection.bind('add', this.add, this);
        this.collection.bind('add', this.reset_story_positions, this);
        this.collection.bind('no_more_stories', this.show_no_more_stories, this);
        this.$el.bind('mousemove', _.bind(this.handle_mousemove_feed_view, this));
        this.$el.scroll(_.bind(this.handle_scroll_feed_view, this));
        this.reset_flags();
    },
    
    reset_flags: function() {
        this.cache = {
            story_pane_position: null,
            feed_title_floater_feed_id: null,
            feed_view_story_positions: {},
            feed_view_story_positions_keys: []
        };
        this.flags = {
            feed_view_images_loaded: {},
            mousemove_timeout: false
        };
        this.counts = {
            positions_timer: 0
        };
    },
    
    // ==========
    // = Render =
    // ==========
    
    render: function() {
        var collection = this.collection;
        var $stories = this.collection.map(function(story) {
            return new NEWSBLUR.Views.StoryDetailView({
                model: story,
                collection: collection
            }).render().el;
        });
        this.$el.html($stories);
        this.show_correct_feed_in_feed_title_floater();
    },
    
    add: function(options) {
        if (options.added) {
            var collection = this.collection;
            var $stories = _.map(this.collection.models.slice(-1 * options.added), function(story) {
                return new NEWSBLUR.Views.StoryDetailView({
                    model: story,
                    collection: collection
                }).render().el;
            });
            this.$el.append($stories);
        } else {
            this.show_no_more_stories();
        }
    },
    
    // ===========
    // = Actions =
    // ===========
    
    scroll_to_selected_story: function(story, options) {
        options = options || {};
        if (!story || !story.story_view) return;
        var $story = story.story_view.$el;

        if (NEWSBLUR.assets.preference('feed_view_single_story')) return;
        if (!NEWSBLUR.assets.preference('animations')) options.immediate = true;
        if (options.scroll_to_comments) {
            $story = $('.NB-feed-story-comments', $story);
        }
        
        clearTimeout(NEWSBLUR.reader.locks.scrolling);
        NEWSBLUR.reader.flags.scrolling_by_selecting_story_title = true;
        this.$el.scrollable().stop();
        this.$el.scrollTo($story, { 
            duration: options.immediate ? 0 : 340,
            axis: 'y', 
            easing: 'easeInOutQuint', 
            offset: options.scroll_offset || 0,
            queue: false, 
            onAfter: function() {
                NEWSBLUR.reader.locks.scrolling = setTimeout(function() {
                    NEWSBLUR.reader.flags.scrolling_by_selecting_story_title = false;
                }, 100);
            }
        });
    },
    
    show_no_more_stories: function() {
        this.$('.NB-feed-story-endbar').remove();
        var $end_stories_line = $.make('div', { 
            className: 'NB-feed-story-endbar'
        });

        this.$el.append($end_stories_line);
    },
    
    show_correct_feed_in_feed_title_floater: function(story) {
        var $story, $header;
        var $feed_floater = NEWSBLUR.reader.$s.$feed_floater;
        story = story || NEWSBLUR.reader.active_story;

        if (story && this.cache.feed_title_floater_feed_id != story.get('story_feed_id')) {
            var $story = story.story_view.$el;
            $header = $('.NB-feed-story-header-feed', $story);
            var $new_header = $header.clone();
            if (this.feed_title_floater) this.feed_title_floater.destroy();
            this.feed_title_floater = new NEWSBLUR.Views.StoryDetailView({
                feed_floater: true,
                model: story, 
                el: $new_header
            });

            $feed_floater.html($new_header);
            this.cache.feed_title_floater_feed_id = story.get('story_feed_id');
            var feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
            $feed_floater.toggleClass('NB-inverse', feed.is_light());
            $feed_floater.width($header.outerWidth());
        } else if (!story) {
            if (this.feed_title_floater) this.feed_title_floater.destroy();
            this.cache.feed_title_floater_feed_id = null;
        }
          
        if (story && this.cache.feed_title_floater_story_id != story.id) {
            $story = $story || story.story_view.$el;
            $header = $header || $('.NB-feed-story-header-feed', $story);
            $('.NB-floater').removeClass('NB-floater');
            $header.addClass('NB-floater');
            this.cache.feed_title_floater_story_id = story.id;
        } else if (!story) {
            this.cache.feed_title_floater_story_id = null;
        }
    },
    
    show_stories_preference_in_feed_view: function(is_creating) {
        if (NEWSBLUR.reader.active_story && 
            NEWSBLUR.assets.preference('feed_view_single_story')) {
            this.$el.removeClass('NB-feed-view-feed').addClass('NB-feed-view-story');
            NEWSBLUR.reader.$s.$feed_stories.scrollTop('0px');
            this.flags['feed_view_positions_calculated'] = false;
        } else {
            this.$el.removeClass('NB-feed-view-story').addClass('NB-feed-view-feed');
            NEWSBLUR.reader.show_story_titles_above_intelligence_level({'animate': false});
        }
        this.cache.story_pane_position = null;
    },

    // =============
    // = Positions =
    // =============
    
    is_feed_loaded_for_location_fetch: function() {
        var images_begun = _.keys(this.flags.feed_view_images_loaded).length;
        if (images_begun) {
            var images_loaded = _.keys(this.flags.feed_view_images_loaded).length && 
                                _.all(_.values(this.flags.feed_view_images_loaded), _.identity);
            return !!images_loaded;
        }

        return !!images_begun;
    },
    
    prefetch_story_locations_in_feed_view: function() {
        var self = this;
        var stories = NEWSBLUR.assets.stories;
        
        // NEWSBLUR.log(['Prefetching Feed', this.flags['feed_view_positions_calculated'], this.flags.feed_view_images_loaded, (_.keys(this.flags.feed_view_images_loaded).length > 0 || this.cache.feed_view_story_positions_keys.length > 0), _.keys(this.flags.feed_view_images_loaded).length, _.values(this.flags.feed_view_images_loaded), this.is_feed_loaded_for_location_fetch()]);

        if (!NEWSBLUR.assets.stories.size()) return;
        
        if (!this.flags['feed_view_positions_calculated']) {
            
            $.extend(this.cache, {
                'feed_view_story_positions': {},
                'feed_view_story_positions_keys': []
            });
        
            NEWSBLUR.assets.stories.any(_.bind(function(story) {
                this.determine_feed_view_story_position(story);
                var $story = story.story_view.$el;
                if (!$story || !$story.length || this.flags['feed_view_positions_calculated']) {
                    return true;
                }
            }, this));
            
            clearTimeout(this.flags['prefetch']);
            this.flags['prefetch'] = setTimeout(_.bind(function() {
                if (!this.flags['feed_view_positions_calculated']) {
                    this.prefetch_story_locations_in_feed_view();
                }
            }, this), 2000);
        } 
        
        if (this.is_feed_loaded_for_location_fetch()) {
            this.fetch_story_locations_in_feed_view({'reset_timer': true});
        } else {
            NEWSBLUR.log(['Still loading feed view...', _.keys(this.flags.feed_view_images_loaded).length, this.cache.feed_view_story_positions_keys.length, this.flags.feed_view_images_loaded]);
        }
    },
    
    fetch_story_locations_in_feed_view: function(options) {
        options = options || {};
        var stories = NEWSBLUR.assets.stories;
        if (!stories || !stories.length) return;
        if (options.reset_timer) this.counts['positions_timer'] = 0;

        $.extend(this.cache, {
            'feed_view_story_positions': {},
            'feed_view_story_positions_keys': []
        });

        NEWSBLUR.assets.stories.each(_.bind(function(story) {
            this.determine_feed_view_story_position(story);
        }, this));

        this.flags['feed_view_positions_calculated'] = true;
        // NEWSBLUR.log(['Feed view entirely loaded', NEWSBLUR.assets.stories.length + " stories", this.counts['positions_timer']/1000 + " sec delay"]);
        
        this.counts['positions_timer'] = Math.max(this.counts['positions_timer']*2, 1000);
        clearTimeout(this.flags['next_fetch']);
        this.flags['next_fetch'] = _.delay(_.bind(this.fetch_story_locations_in_feed_view, this),
                                           this.counts['positions_timer']);
    },
    
    determine_feed_view_story_position: function(story) {
        var $story = story.story_view.$el;
        if (story && $story.is(':visible')) {
            var position_original = parseInt($story.position().top, 10);
            var position_offset = parseInt($story.offsetParent().scrollTop(), 10);
            var position = position_original + position_offset;
            this.cache.feed_view_story_positions[position] = story;
            this.cache.feed_view_story_positions_keys.push(position);
            this.cache.feed_view_story_positions_keys.sort(function(a, b) { return a-b; });    
            // NEWSBLUR.log(['Positioning story', position, story.get('story_title')]);
        }
    },

    check_feed_view_scrolled_to_bottom: function() {
        if (!NEWSBLUR.assets.flags['no_more_stories']) {
            var last_story = NEWSBLUR.assets.stories.last();
            var $last_story = last_story.story_view.$el;
            var container_offset = this.$el.position().top;
            var full_height = ($last_story.offset() && $last_story.offset().top) + $last_story.height() - container_offset;
            var visible_height = this.$el.height();
            var scroll_y = this.$el.scrollTop();
        
            // Fudge factor is simply because it looks better at 13 pixels off.
            if ((visible_height + 26) >= full_height) {
                NEWSBLUR.log(['Feed view scroll', full_height, container_offset, visible_height, scroll_y]);
                NEWSBLUR.reader.load_page_of_feed_stories();
            }
        }
    },
    
    reset_story_positions: function(models) {
        if (!models || !models.length) {
            models = NEWSBLUR.assets.stories;
        }
        if (!models.length) return;
        
        this.flags['feed_view_positions_calculated'] = false;
        
        if (this.cache.story_pane_position == null) {
            this.cache.story_pane_position = this.$el.offsetParent().offset().top;
        }

        models.each(_.bind(function(story) {
            var image_count = story.story_view.$('.NB-feed-story-content img').length;
            if (!image_count) {
                // NEWSBLUR.log(["No images", story.get('story_title')]);
                this.flags.feed_view_images_loaded[story.id] = true;
            } else if (!this.flags.feed_view_images_loaded[story.id]) {
                // Progressively load the images in each story, so that when one story
                // loads, the position is calculated and the next story can calculate
                // its position (after its own images are loaded).
                this.flags.feed_view_images_loaded[story.id] = false;
                (function(story, image_count) {
                    story.story_view.$('.NB-feed-story-content img').load(function() {
                        // NEWSBLUR.log(['Loaded image', story.get('story_title'), image_count]);
                        if (image_count <= 1) {
                            NEWSBLUR.app.story_list.flags.feed_view_images_loaded[story.id] = true;
                        } else {
                            image_count--;
                        }
                        return true;
                    });
                })(story, image_count);
            }
        }, this));
        
        this.prefetch_story_locations_in_feed_view();
    },
    
    // ==========
    // = Events =
    // ==========
    
    handle_mousemove_feed_view: function(e) {
        var self = this;
        
        if (NEWSBLUR.assets.preference('feed_view_single_story')) {
            return NEWSBLUR.reader.hide_mouse_indicator();
        } else {
            NEWSBLUR.reader.show_mouse_indicator();
        }
        
        if (parseInt(NEWSBLUR.assets.preference('lock_mouse_indicator'), 10)) {
            return;
        }

        NEWSBLUR.reader.cache.mouse_position_y = e.pageY;
        NEWSBLUR.reader.$s.$mouse_indicator.css('top', NEWSBLUR.reader.cache.mouse_position_y - this.cache.story_pane_position - 8);
        
        if (this.flags['mousemove_timeout'] ||
            NEWSBLUR.reader.flags['scrolling_by_selecting_story_title']) {
            return;
        }
        
        var from_top = NEWSBLUR.reader.cache.mouse_position_y + this.$el.scrollTop();
        var offset = this.cache.story_pane_position;
        var position = from_top - offset;
        var positions = this.cache.feed_view_story_positions_keys;
        var closest = $.closest(position, positions);
        var story = this.cache.feed_view_story_positions[positions[closest]];

        if (!story) return;
        if (!story.get('selected')) {
            story.set('selected', true, {selected_by_scrolling: true, mouse: true, immediate: true});
        }
    },
    
    handle_scroll_feed_view: function(elem, e) {
        var self = this;
        var story_view = NEWSBLUR.reader.story_view;
        
        // NEWSBLUR.log(['handle_scroll_feed_view', story_view, NEWSBLUR.reader.flags['switching_to_feed_view'], NEWSBLUR.reader.flags['scrolling_by_selecting_story_title']]);
        if ((story_view == 'feed' ||
             (story_view == 'page' && NEWSBLUR.reader.flags['page_view_showing_feed_view'])) &&
            !NEWSBLUR.reader.flags['scrolling_by_selecting_story_title'] &&
            !NEWSBLUR.assets.preference('feed_view_single_story')) {
            var from_top = NEWSBLUR.reader.cache.mouse_position_y + this.$el.scrollTop();
            var offset = this.cache.story_pane_position;
            var position = from_top - offset;
            var positions = this.cache.feed_view_story_positions_keys;
            var closest = $.closest(position, positions);
            var story = this.cache.feed_view_story_positions[positions[closest]];

            if (!story) return;
            // NEWSBLUR.log(["Scroll Feed", from_top, offset, position, closest, story.get('story_title')]);
            if (!story.get('selected')) {
                story.set('selected', true, {selected_by_scrolling: true, mouse: true, immediate: true});
            }

            this.check_feed_view_scrolled_to_bottom();
        }
        
        if ((NEWSBLUR.reader.flags['river_view'] || NEWSBLUR.reader.flags['social_view']) &&
            !NEWSBLUR.assets.preference('feed_view_single_story')) {
            var story;
            if (NEWSBLUR.reader.flags['scrolling_by_selecting_story_title']) {
                story = this.active_story;
            } else {
                var from_top = Math.max(1, this.$el.scrollTop());
                var positions = this.cache.feed_view_story_positions_keys;
                var closest = $.closest(from_top, positions);
                story = this.cache.feed_view_story_positions[positions[closest]];
            }
            
            this.show_correct_feed_in_feed_title_floater(story);
        }
    }
    
});