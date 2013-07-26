NEWSBLUR.Views.StoryTitlesView = Backbone.View.extend({
    
    el: '.NB-story-titles',
    
    events: {
        "click .NB-feed-story-premium-only a" : function(e) {
            e.preventDefault();
            NEWSBLUR.reader.open_feedchooser_modal();
        }
    },
    
    initialize: function() {
        _.bindAll(this, 'scroll');
        this.collection.bind('reset', this.render, this);
        this.collection.bind('add', this.add, this);
        this.collection.bind('no_more_stories', this.check_premium_river, this);
        this.collection.bind('no_more_stories', this.check_premium_search, this);
        NEWSBLUR.reader.$s.$story_titles.scroll(this.scroll);
    },
    
    // ==========
    // = Render =
    // ==========
    
    render: function() {
        NEWSBLUR.reader.$s.$story_titles.scrollTop(0);
        var collection = this.collection;
        var $stories = this.collection.map(function(story) {
            return new NEWSBLUR.Views.StoryTitleView({
                model: story,
                collection: collection
            }).render().el;
        });
        this.$el.html($stories);
        this.end_loading();
        this.fill_out();
    },
    
    add: function(options) {
        var collection = this.collection;
        if (options.added) {
            var $stories = _.compact(_.map(this.collection.models.slice(-1 * options.added), function(story) {
                if (story.story_title_view) return;
                return new NEWSBLUR.Views.StoryTitleView({
                    model: story,
                    collection: collection
                }).render().el;
            }));
            this.$el.append($stories);
        }
        this.end_loading();
        this.fill_out();
    },
    
    append_river_premium_only_notification: function() {
        var $notice = $.make('div', { className: 'NB-feed-story-premium-only' }, [
            $.make('div', { className: 'NB-feed-story-premium-only-text'}, [
                'The full River of News is a ',
                $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
                '.'
            ])
        ]);
        this.$('.NB-feed-story-premium-only').remove();
        this.$(".NB-end-line").append($notice);
    },
    
    append_search_premium_only_notification: function() {
        var $notice = $.make('div', { className: 'NB-feed-story-premium-only' }, [
            $.make('div', { className: 'NB-feed-story-premium-only-text'}, [
                'Search is a ',
                $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
                '.'
            ])
        ]);
        this.$('.NB-feed-story-premium-only').remove();
        this.$(".NB-end-line").append($notice);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    fill_out: function(options) {
        this.snap_back_scroll_position();
        
        if (NEWSBLUR.assets.flags['no_more_stories'] || 
            !NEWSBLUR.assets.stories.length ||
            NEWSBLUR.reader.flags.story_titles_closed) {
            return;
        }
        
        options = options || {};
        
        if (NEWSBLUR.reader.counts['page_fill_outs'] < NEWSBLUR.reader.constants.FILL_OUT_PAGES && 
            !NEWSBLUR.assets.flags['no_more_stories']) {
            // var $last = this.$('.NB-story-title:visible:last');
            // var container_height = NEWSBLUR.reader.$s.$story_titles.height();
            // NEWSBLUR.log(["fill out", $last.length && $last.position().top, container_height, $last.length, NEWSBLUR.reader.$s.$story_titles.scrollTop()]);
            NEWSBLUR.reader.counts['page_fill_outs'] += 1;
            _.delay(_.bind(function() {
                this.scroll();
            }, this), 10);
        } else {
            this.show_no_more_stories();
        }
    },
    
    show_loading: function(options) {
        options = options || {};
        if (NEWSBLUR.assets.flags['no_more_stories']) return;
        
        var $story_titles = NEWSBLUR.reader.$s.$story_titles;
        this.$('.NB-end-line').remove();
        var $endline = $.make('div', { className: "NB-end-line NB-short" });
        $endline.css({'background': '#E1EBFF'});
        $story_titles.append($endline);
        
        $endline.animate({'backgroundColor': '#5C89C9'}, {'duration': 650})
                .animate({'backgroundColor': '#E1EBFF'}, 1050);
        this.feed_stories_loading = setInterval(function() {
            $endline.animate({'backgroundColor': '#5C89C9'}, {'duration': 650})
                    .animate({'backgroundColor': '#E1EBFF'}, 1050);
        }, 1700);
        
        if (options.scroll_to_loadbar) {
            this.pre_load_page_scroll_position = $('#story_titles').scrollTop();
            if (this.pre_load_page_scroll_position > 0) {
                this.pre_load_page_scroll_position += $endline.outerHeight();
            }
            $story_titles.stop().scrollTo($endline, { 
                duration: 0,
                axis: 'y', 
                easing: 'easeInOutQuint', 
                offset: 0, 
                queue: false
            });
            this.post_load_page_scroll_position = $('#story_titles').scrollTop();
        } else {
            this.pre_load_page_scroll_position = null;
            this.post_load_page_scroll_position = null;
        }
    },
    
    check_premium_river: function() {
        if (!NEWSBLUR.Globals.is_premium &&
            NEWSBLUR.Globals.is_authenticated &&
            NEWSBLUR.reader.flags['river_view']) {
            this.show_no_more_stories();
            this.append_river_premium_only_notification();
        } else if (NEWSBLUR.assets.flags['no_more_stories']) {
            this.show_no_more_stories();
        }
    },
    
    check_premium_search: function() {
        if (!NEWSBLUR.Globals.is_premium &&
            NEWSBLUR.reader.flags.search) {
            this.show_no_more_stories();
            this.append_search_premium_only_notification();
        }
    },
    
    end_loading: function() {
        var $endbar = NEWSBLUR.reader.$s.$story_titles.find('.NB-end-line');
        $endbar.remove();
        clearInterval(this.feed_stories_loading);

        if (NEWSBLUR.assets.flags['no_more_stories']) {
            this.show_no_more_stories();
        }
    },
    
    show_no_more_stories: function() {
        this.$('.NB-end-line').remove();
        var $end_stories_line = $.make('div', { className: "NB-end-line" }, [
            $.make('div', { className: 'NB-fleuron' })
        ]);
        
        if (NEWSBLUR.assets.preference('story_layout') == 'list') {
            var pane_height = NEWSBLUR.reader.$s.$story_titles.height();
            var endbar_height = 20;
            var last_story_height = 100;
            endbar_height = pane_height - last_story_height;
            if (endbar_height <= 20) endbar_height = 20;

            var empty_space = pane_height - last_story_height - endbar_height;
            if (empty_space > 0) endbar_height += empty_space + 1;

            $end_stories_line.css('paddingBottom', endbar_height);
        }

        this.$el.append($end_stories_line);
    },
    
    snap_back_scroll_position: function() {
        var $story_titles = NEWSBLUR.reader.$s.$story_titles;
        if (this.post_load_page_scroll_position == $story_titles.scrollTop() &&
            this.pre_load_page_scroll_position != null &&
            !NEWSBLUR.reader.flags['select_story_in_feed']) {
            $story_titles.stop().scrollTo(this.pre_load_page_scroll_position, { 
                duration: 0,
                axis: 'y', 
                offset: 0, 
                queue: false
            });
        }
    },
    
    // ============
    // = Bindings =
    // ============
    
    scroll_to_selected_story: function(story, options) {
        options = options || {};
        var story_title_view = (story && story.story_title_view) ||
                                (this.collection.active_story && this.collection.active_story.story_title_view);
        if (!story_title_view) return;
        
        var story_title_visisble = NEWSBLUR.reader.$s.$story_titles.isScrollVisible(story_title_view.$el);
        if (!story_title_visisble || options.force || 
            NEWSBLUR.assets.preference('story_layout') == 'list') {
            var container_offset = NEWSBLUR.reader.$s.$story_titles.position().top;
            var scroll = story_title_view.$el.position().top;
            var container = NEWSBLUR.reader.$s.$story_titles.scrollTop();
            var height = NEWSBLUR.reader.$s.$story_titles.outerHeight();
            var position = scroll+container-height/5;
            
            if (NEWSBLUR.assets.preference('story_layout') == 'list') {
                position = scroll+container;
            }

            NEWSBLUR.reader.$s.$story_titles.stop().scrollTo(position, {
                duration: NEWSBLUR.assets.preference('animations') ? 260 : 0,
                queue: false
            });
        }    
    },
    
    // ==========
    // = Events =
    // ==========
    
    scroll: function() {
        if (NEWSBLUR.assets.flags['no_more_stories'] || NEWSBLUR.reader.flags['opening_feed']) {
            return;
        }
        
        var $story_titles = NEWSBLUR.reader.$s.$story_titles;
        var container_offset = $story_titles.position().top;
        var visible_height = $story_titles.height() * 2;
        var scroll_y = $story_titles.scrollTop();
        var total_height = this.$el.outerHeight() + NEWSBLUR.reader.$s.$feedbar.innerHeight();
        
        // console.log(["scroll titles", container_offset, visible_height, scroll_y, total_height]);
        if (visible_height + scroll_y >= total_height) {
            NEWSBLUR.reader.load_page_of_feed_stories({scroll_to_loadbar: false});
        }
    }
    
});