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
            $.make('div', { className: 'NB-feed-story-premium-only-divider'}),
            $.make('div', { className: 'NB-feed-story-premium-only-text'}, [
                'The full River of News is a ',
                $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
                '.'
            ])
        ]);
        this.$('.NB-feed-story-premium-only').remove();
        this.$el.append($notice);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    fill_out: function(options) {
        this.snap_back_scroll_position();
        
        if (NEWSBLUR.assets.flags['no_more_stories'] || !NEWSBLUR.assets.stories.length) {
            return;
        }
        
        options = options || {};
        var $last = this.$('.NB-story-title:visible:last');
        var container_height = NEWSBLUR.reader.$s.$story_titles.height();

        if (($last.length == 0 ||
             (NEWSBLUR.reader.$s.$story_titles.scrollTop() == 0 && 
              $last.position().top + $last.height() - 13 < container_height))) {
            if (NEWSBLUR.reader.counts['page_fill_outs'] < NEWSBLUR.reader.constants.FILL_OUT_PAGES && 
                !NEWSBLUR.assets.flags['no_more_stories']) {
                // NEWSBLUR.log(["fill out", $last.length && $last.position().top, container_height, $last.length, NEWSBLUR.reader.$s.$story_titles.scrollTop()]);
                NEWSBLUR.reader.counts['page_fill_outs'] += 1;
                _.delay(function() {
                    NEWSBLUR.reader.load_page_of_feed_stories({show_loading: false});
                }, 50);
            } else {
                this.show_no_more_stories();
            }
        }
    },
    
    show_loading: function(options) {
        if (NEWSBLUR.assets.flags['no_more_stories']) return;
        
        var $story_titles = NEWSBLUR.reader.$s.$story_titles;
        var $endline = $('.NB-story-titles-end-stories-line', $story_titles);
        
        if (!$endline.length) {
            $endline = $.make('div', { className: 'NB-story-titles-end-stories-line' });
            $story_titles.append($endline);
        }
        $endline.css({'background': '#E1EBFF'});
        
        $endline.animate({'backgroundColor': '#5C89C9'}, {'duration': 650})
                .animate({'backgroundColor': '#E1EBFF'}, 1050);
        this.feed_stories_loading = setInterval(function() {
            $endline.animate({'backgroundColor': '#5C89C9'}, {'duration': 650})
                    .animate({'backgroundColor': '#E1EBFF'}, 1050);
        }, 1500);
        
        if (options.show_loading) {
            this.pre_load_page_scroll_position = $('#story_titles').scrollTop();
            if (this.pre_load_page_scroll_position > 0) {
                this.pre_load_page_scroll_position += $endline.outerHeight();
            }
            $story_titles.scrollTo($endline, { 
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
        this.show_no_more_stories();
        this.append_river_premium_only_notification();
    },
    
    end_loading: function() {
        var $endbar = NEWSBLUR.reader.$s.$story_titles.find('.NB-story-titles-end-stories-line');
        $endbar.remove();
        clearInterval(this.feed_stories_loading);

        if (NEWSBLUR.assets.flags['no_more_stories']) {
            this.show_no_more_stories();
        }
    },
    
    show_no_more_stories: function() {
        var $story_titles = NEWSBLUR.reader.$s.$story_titles;
        $('.NB-story-titles-end-stories-line', $story_titles).remove();
        var $end_stories_line = $.make('div', { 
            className: 'NB-story-titles-end-stories-line'
        });

        $story_titles.append($end_stories_line);
    },
    
    snap_back_scroll_position: function() {
        var $story_titles = NEWSBLUR.reader.$s.$story_titles;
        if (this.post_load_page_scroll_position == $story_titles.scrollTop() &&
            this.pre_load_page_scroll_position != null &&
            !NEWSBLUR.reader.flags['select_story_in_feed']) {
            $story_titles.scrollTo(this.pre_load_page_scroll_position, { 
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
    
    scroll_to_selected_story: function(story) {
        var story_title_view = (story && story.story_title_view) ||
                                (this.collection.active_story && this.collection.active_story.story_title_view);
        if (!story_title_view) return;
        
        var story_title_visisble = NEWSBLUR.reader.$s.$story_titles.isScrollVisible(story_title_view.$el);
        if (!story_title_visisble) {
            var container_offset = NEWSBLUR.reader.$s.$story_titles.position().top;
            var scroll = story_title_view.$el.position().top;
            var container = NEWSBLUR.reader.$s.$story_titles.scrollTop();
            var height = NEWSBLUR.reader.$s.$story_titles.outerHeight();
            NEWSBLUR.reader.$s.$story_titles.scrollTop(scroll+container-height/5);
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
        var $last_story = this.$('.story').last();
        var container_offset = $story_titles.position().top;
        var full_height = ($last_story.offset() && $last_story.offset().top) + $last_story.height() - container_offset;
        var visible_height = $story_titles.height();
        var scroll_y = $story_titles.scrollTop();
    
        // Fudge factor is simply because it looks better at 13 pixels off.
        if ((visible_height + 13) >= full_height) {
            NEWSBLUR.reader.load_page_of_feed_stories();
        }
    }
    
});