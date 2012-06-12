NEWSBLUR.Views.StoryListView = Backbone.View.extend({
    
    el: '.NB-feed-stories',
    
    initialize: function() {
        this.collection.bind('reset', this.reset_flags, this);
        this.collection.bind('reset', this.render, this);
        this.collection.bind('add', this.add, this);
        this.collection.bind('change:selected', this.show_correct_feed_in_feed_title_floater, this);
        this.$el.bind('mousemove', _.bind(this.handle_mousemove_feed_view, this));
        // this.$el.scroll(_.bind(this.handle_scroll_feed_view, this));
    },
    
    reset_flags: function() {
        this.cache = {
            story_pane_position: null,
            feed_title_floater_feed_id: null
        };
        this.flags = {
            mousemove_timeout: false
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

        // console.log(["Scroll in Feed", story.get('story_title'), options]);

        if (!options.immediate) {
            clearTimeout(NEWSBLUR.reader.locks.scrolling);
            NEWSBLUR.reader.flags.scrolling_by_selecting_story_title = true;
        }

        this.$el.scrollable().stop();
        this.$el.scrollTo(story.story_view.$el, { 
            duration: options.immediate ? 0 : 340,
            axis: 'y', 
            easing: 'easeInOutQuint', 
            offset: 0, // scroll_offset, 
            queue: false, 
            onAfter: function() {
                if (options.immediate) return;

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
            
            $feed_floater.html($new_header);
            this.cache.feed_title_floater_feed_id = story.get('story_feed_id');
            var feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
            $feed_floater.toggleClass('NB-inverse', feed.is_light());
            $feed_floater.width($header.outerWidth());
        } else if (!story) {
            $feed_floater.empty();
            this.cache.feed_title_floater_feed_id = null;
        }
          
        if (story && this.cache.feed_title_floater_story_id != story.id) {
            $story = $story || this.find_story_in_feed_view(story.id);
            $header = $header || $('.NB-feed-story-header-feed', $story);
            $('.NB-floater').removeClass('NB-floater');
            $header.addClass('NB-floater');
            this.cache.feed_title_floater_story_id = story.id;
        } else if (!story) {
            this.cache.feed_title_floater_story_id = null;
        }
    },

    // =============
    // = Positions =
    // =============
    
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
                // var $story = self.cache.feed_view_stories[story.id];
                // this.determine_feed_view_story_position($story, story);
                // NEWSBLUR.log(['Pre-fetching', $story, story.get('story_title'), this.flags.feed_view_images_loaded[story.id]]);
                // if (!$story || !$story.length || this.flags['feed_view_positions_calculated']) break;
            }
        }
        if ((_.keys(this.flags.feed_view_images_loaded).length > 0 ||
             this.cache.feed_view_story_positions_keys.length > 0) &&
            (this.flags.feed_view_images_loaded.length &&
             _.all(_.values(this.flags.feed_view_images_loaded)))) {
            this.fetch_story_locations_in_feed_view({'reset_timer': true});
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
    
    fetch_story_locations_in_feed_view: function(options) {
        options = options || {};
        var stories = this.model.stories;
        if (!stories || !stories.length) return;
        if (options.reset_timer) this.counts['feed_view_positions_timer'] = 0;

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
        // NEWSBLUR.log(['Feed view entirely loaded', this.model.stories.length + " stories", this.counts['feed_view_positions_timer']/1000 + " sec delay"]);
        
        this.counts['feed_view_positions_timer'] = Math.max(this.counts['feed_view_positions_timer']*2, 1000);
        clearTimeout(this.flags['next_fetch']);
        this.flags['next_fetch'] = _.delay(_.bind(this.fetch_story_locations_in_feed_view, this),
                                           this.counts['feed_view_positions_timer']);
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
        if (this.cache.story_pane_position == null) {
            this.cache.story_pane_position = NEWSBLUR.reader.$s.$feed_stories.offsetParent().offset().top;
        }
        NEWSBLUR.reader.$s.$mouse_indicator.css('top', NEWSBLUR.reader.cache.mouse_position_y - this.cache.story_pane_position - 8);
        
        if (this.flags['mousemove_timeout']) {
            return;
        }
        
        setTimeout(function() {
            self.flags['mousemove_timeout'] = false;
        }, 30);
        
        // if (!this.flags['mousemove_timeout']
        //     && !this.flags['switching_to_feed_view']
        //     && !this.flags.scrolling_by_selecting_story_title 
        //     && this.story_view != 'story') {
        //     var from_top = this.cache.mouse_position_y + this.$s.$feed_stories.scrollTop();
        //     var offset = this.cache.story_pane_position;
        //     var position = from_top - offset;
        //     var positions = this.cache.feed_view_story_positions_keys;
        //     var closest = $.closest(position, positions);
        //     var story = this.cache.feed_view_story_positions[positions[closest]];
        //     this.flags['mousemove_timeout'] = true;
        //     if (story == this.active_story) return;
        //     // NEWSBLUR.log(['Mousemove feed view', from_top, closest, positions[closest]]);
        //     this.navigate_story_titles_to_story(story);
        // }
    },
    
    handle_scroll_feed_view: function(elem, e) {
        var self = this;
        
        // NEWSBLUR.log(['handle_scroll_feed_view', this.story_view, this.flags['switching_to_feed_view'], this.flags['scrolling_by_selecting_story_title']]);
        if ((this.story_view == 'feed' ||
             (this.story_view == 'page' && this.flags['page_view_showing_feed_view'])) &&
            !this.flags['scrolling_by_selecting_story_title'] &&
            !NEWSBLUR.assets.preference('feed_view_single_story')) {
            var from_top = this.cache.mouse_position_y + this.$s.$feed_stories.scrollTop();
            var offset = this.cache.story_pane_position;
            var position = from_top - offset;
            var positions = this.cache.feed_view_story_positions_keys;
            var closest = $.closest(position, positions);
            var story = this.cache.feed_view_story_positions[positions[closest]];
            // NEWSBLUR.log(['Scroll feed view', from_top, e, closest, positions[closest], this.cache.feed_view_story_positions_keys, positions, self.cache]);
            this.navigate_story_titles_to_story(story);
            this.check_feed_view_scrolled_to_bottom();
        }
        
        if ((this.flags.river_view || this.flags.social_view) &&
            !NEWSBLUR.assets.preference('feed_view_single_story')) {
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
    }
    
});