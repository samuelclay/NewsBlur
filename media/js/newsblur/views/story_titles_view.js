NEWSBLUR.Views.StoryTitlesView = Backbone.View.extend({

    el: '.NB-story-titles',

    events: {
        "click .NB-feed-story-premium-only a": function (e) {
            e.preventDefault();
            NEWSBLUR.reader.open_feedchooser_modal({ premium_only: true });
        },
        "click .NB-briefing-generate-btn": function (e) {
            e.preventDefault();
            NEWSBLUR.reader.generate_daily_briefing();
        }
    },

    initialize: function () {
        _.bindAll(this, 'scroll');
        // console.log(['initialize story titles view', this.collection]);
        this.collection.bind('reset', this.render, this);
        this.collection.bind('add', this.add, this);
        this.collection.bind('no_more_stories', this.check_premium_river, this);
        this.collection.bind('no_more_stories', this.check_premium_search, this);
        this.collection.bind('change:selected', this.scroll_to_selected_story, this);
        this.$story_titles = this.options.$story_titles || NEWSBLUR.reader.$s.$story_titles;
        this.$story_titles.scroll(this.scroll);
        this.stories = [];
    },

    // ==========
    // = Render =
    // ==========

    render: function (options) {
        if (NEWSBLUR.reader.flags.briefing_view && NEWSBLUR.assets.briefing_data) {
            // story_titles_view.js: When triggered by a collection reset event
            // (Backbone passes the collection as first arg), skip re-rendering
            // briefing to avoid resetting the scroll position while reading.
            // Only re-render on explicit calls (options is undefined or a plain object).
            if (options && options.models) {
                return;
            }
            return this.render_briefing(options);
        }
        // console.log(['render story_titles', this.options.override_layout, this.collection.length, this.$story_titles[0]]);
        this.clear();
        this.$story_titles.scrollTop(0);
        var collection = this.collection;
        var story_layout = this.options.override_layout ||
            NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
        var on_dashboard = this.options.on_dashboard;
        var on_discover_feed = this.options.on_discover_feed;
        var on_discover_story = this.options.on_discover_story;
        var on_trending_feed = this.options.on_trending_feed;
        var in_trending_view = this.options.in_trending_view;
        var in_popover = this.options.in_popover;
        var override_layout = this.options.override_layout;
        var pane_anchor = this.options.pane_anchor;
        var stories = this.collection.map(function (story) {
            return new NEWSBLUR.Views.StoryTitleView({
                model: story,
                collection: collection,
                is_list: story_layout == 'list',
                is_grid: story_layout == 'grid',
                is_magazine: story_layout == 'magazine',
                override_layout: override_layout,
                pane_anchor: pane_anchor,
                on_dashboard: on_dashboard,
                on_discover_feed: on_discover_feed,
                on_discover_story: on_discover_story,
                on_trending_feed: on_trending_feed,
                in_trending_view: in_trending_view,
                in_popover: in_popover
            }).render();
        });
        this.stories = stories;
        var $stories = _.map(stories, function (story) {
            return story.el;
        });
        this.$el.html($stories);
        // console.log(['Rendered story titles', this.$el, $stories]);
        this.end_loading();
        this.fill_out();
        this.override_grid();

        this.scroll_to_selected_story(null, options);

        return this;
    },

    render_briefing: function (options) {
        this.clear();
        this.$story_titles.scrollTop(0);

        var data = NEWSBLUR.assets.briefing_data;
        var briefings = data.briefings || [];
        var $groups = [];

        // story_titles_view.js: Collect summary + curated stories and load them into the
        // main stories collection so split view, selection, and story detail all work.
        // When a section filter is active, only include stories in that section.
        var active_section = NEWSBLUR.reader.flags.briefing_section;
        var all_stories = [];
        _.each(briefings, function (briefing) {
            if (active_section) {
                var section_hashes = (briefing.curated_sections || {})[active_section] || [];
                var section_hash_set = {};
                _.each(section_hashes, function (h) { section_hash_set[h] = true; });
                // story_titles_view.js: Include section summary as first story if available
                var section_html = (briefing.section_summaries || {})[active_section];
                if (section_html && briefing.summary_story) {
                    all_stories.push(_.extend({}, briefing.summary_story, {
                        story_content: section_html
                    }));
                }
                _.each(briefing.curated_stories || [], function (story_data) {
                    if (section_hash_set[story_data.story_hash]) {
                        all_stories.push(story_data);
                    }
                });
            } else {
                if (briefing.summary_story) {
                    all_stories.push(briefing.summary_story);
                }
                _.each(briefing.curated_stories || [], function (story_data) {
                    all_stories.push(story_data);
                });
            }
        });
        if (all_stories.length) {
            this.collection.reset(all_stories, { added: all_stories.length, silent: true });
            // story_titles_view.js: Manually trigger the story list view to create
            // StoryDetailView instances for split view. We use silent reset above to
            // avoid an infinite loop (this view also listens for reset).
            if (NEWSBLUR.app.story_list) {
                NEWSBLUR.app.story_list.reset_flags();
                NEWSBLUR.app.story_list.render();
                NEWSBLUR.app.story_list.reset_story_positions();
            }
        }
        // story_titles_view.js: Set no_more_stories AFTER reset_flags, because
        // reset_flags->clear() resets it to false.
        this.collection.no_more_stories = true;

        _.each(briefings, function (briefing) {
            briefing.is_preview = data.is_preview;
            // story_titles_view.js: When filtering by section, pass a modified briefing
            // with only the matching curated stories to the group view.
            var display_briefing = briefing;
            if (active_section) {
                var section_hashes = (briefing.curated_sections || {})[active_section] || [];
                var section_hash_set = {};
                _.each(section_hashes, function (h) { section_hash_set[h] = true; });
                // story_titles_view.js: Show section-specific summary if available
                var section_html = (briefing.section_summaries || {})[active_section];
                var section_summary = null;
                if (section_html && briefing.summary_story) {
                    section_summary = _.extend({}, briefing.summary_story, {
                        story_content: section_html
                    });
                }
                display_briefing = _.extend({}, briefing, {
                    summary_story: section_summary,
                    curated_stories: _.filter(briefing.curated_stories || [], function (s) {
                        return section_hash_set[s.story_hash];
                    })
                });
                if (!display_briefing.curated_stories.length && !section_summary) return;
            }
            var group = new NEWSBLUR.Views.BriefingGroupView({
                briefing: display_briefing,
                collection: this.collection
            }).render();
            $groups.push(group.el);
        }, this);

        if (!briefings.length) {
            var $empty = $.make('div', { className: 'NB-briefing-empty' }, [
                $.make('div', { className: 'NB-briefing-empty-icon' }),
                $.make('div', { className: 'NB-briefing-empty-text' },
                    'No briefings yet.'),
                $.make('div', { className: 'NB-briefing-generate-btn NB-briefing-generate-btn-large' }, 'Generate Briefing')
            ]);
            $groups.push($empty);
        } else {
            // story_titles_view.js: Regenerate button at the bottom of existing briefings
            var $regenerate = $.make('div', { className: 'NB-briefing-regenerate' }, [
                $.make('div', { className: 'NB-briefing-generate-btn NB-briefing-regenerate-btn' }, 'Regenerate Briefing')
            ]);
            $groups.push($regenerate);
        }

        this.$el.html($groups);
        this.end_loading();

        // story_titles_view.js: If generation is in progress, restore progress UI
        if (NEWSBLUR.reader.flags.briefing_generating) {
            this.show_briefing_progress("Generating...");
        }

        return this;
    },

    _briefing_target: function () {
        var $target = this.$el.find('.NB-briefing-empty');
        if (!$target.length) {
            $target = this.$el.find('.NB-briefing-regenerate');
        }
        return $target;
    },

    show_briefing_progress: function (message) {
        this.$el.find('.NB-briefing-generate-btn').hide();
        this.$el.find('.NB-briefing-progress').remove();
        this.$el.find('.NB-briefing-error').remove();

        var $progress = $.make('div', { className: 'NB-briefing-progress' }, [
            $.make('div', { className: 'NB-briefing-progress-spinner' }),
            $.make('div', { className: 'NB-briefing-progress-message' }, message)
        ]);

        var $target = this._briefing_target();
        if ($target.length) {
            $target.append($progress);
        }
    },

    hide_briefing_progress: function () {
        this.$el.find('.NB-briefing-progress').remove();
        this.$el.find('.NB-briefing-generate-btn').show();
    },

    show_briefing_error: function (error_message) {
        this.$el.find('.NB-briefing-progress').remove();
        this.$el.find('.NB-briefing-error').remove();

        var $error = $.make('div', { className: 'NB-briefing-error' }, [
            $.make('div', { className: 'NB-briefing-error-message' }, error_message),
            $.make('div', { className: 'NB-briefing-generate-btn NB-briefing-generate-btn-small' }, 'Try Again')
        ]);

        var $target = this._briefing_target();
        if ($target.length) {
            $target.append($error);
        }
    },

    add: function (options) {
        // console.log(['add story_titles', options]);
        var collection = this.collection;
        if (options.added) {
            var on_dashboard = this.options.on_dashboard;
            var on_discover_feed = this.options.on_discover_feed;
            var on_discover_story = this.options.on_discover_story;
            var on_trending_feed = this.options.on_trending_feed;
            var in_trending_view = this.options.in_trending_view;
            var in_popover = this.options.in_popover;
            var override_layout = this.options.override_layout;
            var pane_anchor = this.options.pane_anchor;
            var story_layout = this.options.override_layout ||
                NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
            var stories = _.compact(_.map(this.collection.models.slice(-1 * options.added), function (story) {
                if (story.story_title_view) return;
                return new NEWSBLUR.Views.StoryTitleView({
                    model: story,
                    collection: collection,
                    is_list: story_layout == 'list',
                    is_grid: story_layout == 'grid',
                    is_magazine: story_layout == 'magazine',
                    override_layout: override_layout,
                    pane_anchor: pane_anchor,
                    on_dashboard: on_dashboard,
                    on_discover_feed: on_discover_feed,
                    on_discover_story: on_discover_story,
                    on_trending_feed: on_trending_feed,
                    in_trending_view: in_trending_view,
                    in_popover: in_popover
                }).render();
            }));
            this.stories = this.stories.concat(stories);
            var $stories = _.map(stories, function (story) {
                return story.el;
            });
            this.$el.append($stories);
            if (this.options.on_dashboard || this.options.on_discover_feed || this.options.on_discover_story || this.options.on_trending_feed) {
                var $extras = this.$el.find('.NB-story-title-container .NB-story-title:not(.NB-hidden)').slice(5);
                $extras.addClass('NB-hidden');
            }
        }
        this.end_loading();
        this.fill_out();
    },

    clear: function () {
        // console.log(['clear story titles', this.stories.length, this.$el]);
        _.invoke(this.stories, 'destroy');
        this.cache = {};
        this.collection.page_fill_outs = 0;
        this.collection.no_more_stories = false;
    },

    override_grid: function () {
        if (!NEWSBLUR.reader.active_feed) return;

        var story_layout = this.options.override_layout ||
            NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
        if (story_layout != 'grid') return;

        var columns = NEWSBLUR.assets.preference('grid_columns');
        var height = NEWSBLUR.assets.preference('grid_height');
        var $layout = this.$story_titles;
        $layout.removeClass('NB-grid-columns-1')
            .removeClass('NB-grid-columns-2')
            .removeClass('NB-grid-columns-3')
            .removeClass('NB-grid-columns-4');

        $layout.removeClass('NB-grid-height-xs')
            .removeClass('NB-grid-height-s')
            .removeClass('NB-grid-height-m')
            .removeClass('NB-grid-height-l')
            .removeClass('NB-grid-height-xl');

        if (columns > 0) {
            $layout.addClass('NB-grid-columns-' + columns);
        }
        $layout.addClass('NB-grid-height-' + height);
    },

    append_river_premium_only_notification: function () {
        var message = [
            'The full River of News is a ',
            $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
            '.'
        ];
        if (NEWSBLUR.reader.flags['starred_view']) {
            message = [
                'Reading saved stories by tag is a ',
                $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
                '.'
            ];
        }
        if (NEWSBLUR.reader.active_feed == "read") {
            message = [
                'This read stories list is a ',
                $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
                '.'
            ];
        }
        var $notice = $.make('div', { className: 'NB-feed-story-premium-only' }, [
            $.make('div', { className: 'NB-feed-story-premium-only-text' }, message)
        ]);
        this.$('.NB-feed-story-premium-only').remove();
        this.$(".NB-end-line").append($notice);
    },

    append_search_premium_only_notification: function () {
        var $notice = $.make('div', { className: 'NB-feed-story-premium-only' }, [
            $.make('div', { className: 'NB-feed-story-premium-only-text' }, [
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

    fill_out: function (options) {
        this.snap_back_scroll_position();
        if (this.collection.no_more_stories ||
            !this.collection.length ||
            NEWSBLUR.reader.flags.story_titles_closed) {
            return;
        }

        options = options || {};
        // console.log(['fill out story titles', this.options.on_dashboard ? "dashboard" : "stories", options, NEWSBLUR.assets.flags['no_more_stories'], NEWSBLUR.assets.stories.length, NEWSBLUR.reader.flags.story_titles_closed]);

        if (this.collection.page_fill_outs < NEWSBLUR.reader.constants.FILL_OUT_PAGES &&
            !this.collection.no_more_stories) {
            var $last = this.$('.NB-story-title:visible:last');
            var container_height = this.$story_titles.height();
            // NEWSBLUR.log(["fill out", $last.length && $last.position().top, container_height, $last.length, this.$story_titles.scrollTop()]);
            this.collection.page_fill_outs += 1;
            _.delay(_.bind(function () {
                this.scroll();
            }, this), 10);
        }
    },

    show_loading: function (options) {
        options = options || {};
        if (this.collection.no_more_stories) return;

        var $story_titles = this.$story_titles;
        this.$('.NB-end-line').remove();
        var $endline = $.make('div', { className: "NB-end-line NB-load-line NB-short" });
        $endline.css({ 'background': '#FFF' });
        this.$el.append($endline);

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

    check_premium_river: function () {
        if (!NEWSBLUR.Globals.is_premium &&
            NEWSBLUR.Globals.is_authenticated &&
            (this.options.on_dashboard || this.options.on_discover_feed || this.options.on_discover_story || NEWSBLUR.reader.flags['river_view'])) {
            this.show_no_more_stories();
            this.append_river_premium_only_notification();
        } else if (this.collection.no_more_stories) {
            this.show_no_more_stories();
        }
    },

    check_premium_search: function () {
        if (!NEWSBLUR.Globals.is_premium &&
            NEWSBLUR.reader.flags.search) {
            this.show_no_more_stories();
            this.append_search_premium_only_notification();
        }
    },

    end_loading: function () {
        var $endbar = this.$story_titles.find('.NB-end-line');
        $endbar.remove();

        if (this.collection.no_more_stories) {
            this.show_no_more_stories();
        }
    },

    show_no_more_stories: function () {
        this.$('.NB-end-line').remove();
        var $end_stories_line = $.make('div', { className: "NB-end-line" }, [
            $.make('div', { className: 'NB-fleuron' })
        ]);
        var story_layout = this.options.override_layout ||
            NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
        if (_.contains(['list', 'grid', 'magazine'], story_layout) || NEWSBLUR.assets.preference('mark_read_on_scroll_titles')) {
            var pane_height = this.$story_titles.height();
            var endbar_height = 20;
            var last_story_height = 80;
            endbar_height = pane_height - last_story_height;
            if (endbar_height <= 20) endbar_height = 20;

            var empty_space = pane_height - last_story_height - endbar_height;
            if (empty_space > 0) endbar_height += empty_space + 1;

            // endbar_height /= 2; // Splitting padding between top and bottom
            $end_stories_line.css('paddingBottom', endbar_height);
            // $end_stories_line.css('paddingTop', endbar_height);
            // console.log(["endbar height list", endbar_height, empty_space, pane_height, last_story_height]);
        }

        this.$el.append($end_stories_line);
    },

    snap_back_scroll_position: function () {
        var $story_titles = this.$story_titles;
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

    scroll_to_selected_story: function (story, options) {
        options = options || {};
        var story_title_view = (story && story.story_title_view) ||
            (this.collection.active_story && this.collection.active_story.story_title_view);
        var story_layout = this.options.override_layout ||
            NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
        if (!story_title_view) return;
        if (story &&
            !story.get('selected') &&
            !options.force &&
            story_layout != 'grid') return;

        // console.log(["scroll_to_selected_story 1", story, options]);
        var story_title_visisble = this.$story_titles.isScrollVisible(story_title_view.$el);
        if (!story_title_visisble || options.force ||
            _.contains(['list', 'grid', 'magazine'], story_layout)) {
            var container_offset = this.$story_titles.position().top;
            var scroll = story_title_view.$el.find('.NB-story-title').position().top;
            if (options.scroll_to_comments) {
                scroll = story_title_view.$el.find('.NB-feed-story-comments').position().top;
            }
            var container = this.$story_titles.scrollTop();
            var height = this.$story_titles.outerHeight();
            var position = scroll + container - height / 5;
            // console.log(["scroll_to_selected_story 2", container_offset, scroll, container, height, position]);
            if (_.contains(['list', 'grid', 'magazine'], story_layout)) {
                position = scroll + container;
            }
            if (story_layout == 'grid') {
                // position -= 21;
            }

            // console.log(["scroll_to_selected_story 3", position]);
            NEWSBLUR.reader.flags['opening_story'] = true;
            this.$story_titles.stop().scrollTo(position, {
                duration: !options.immediate && NEWSBLUR.assets.preference('animations') ? 260 : 0,
                queue: false,
                onAfter: function () {
                    NEWSBLUR.reader.flags['opening_story'] = false;
                }
            });
        }
    },

    // ==========
    // = Events =
    // ==========

    scroll: function () {
        var $story_titles = this.$story_titles;
        var scroll_y = $story_titles.scrollTop();

        if (this.options.on_discover_feed || this.options.on_discover_story) {
            return;
        }

        if (!this.options.on_dashboard) {
            if (NEWSBLUR.reader.flags['opening_feed']) return;
            // if (NEWSBLUR.reader.flags['opening_story']) return;
            if (NEWSBLUR.assets.preference('mark_read_on_scroll_titles')) {
                this.mark_read_stories_above_scroll(scroll_y);
            }
            if (this.collection.no_more_stories) return;
        }

        var position = $story_titles.position();
        if (!position) return;

        var container_offset = position.top;
        var visible_height = $story_titles.height() * 2;
        var total_height = this.$el.outerHeight() + NEWSBLUR.reader.$s.$feedbar.innerHeight();

        // console.log(["scroll titles", this.options.on_dashboard ? "dashboard" : "stories", visible_height, scroll_y, ">", total_height, this.$el, container_offset]);
        if (visible_height + scroll_y >= total_height) {
            NEWSBLUR.reader.load_page_of_feed_stories({ scroll_to_loadbar: false });
        }
    },

    mark_read_stories_above_scroll: function (scroll_y) {
        var $story_titles = this.$story_titles;
        var score = NEWSBLUR.reader.get_unread_view_score();
        var unread_stories = [];
        var story_layout = this.options.override_layout ||
            NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
        var grid = story_layout == 'grid';
        var point = this.$story_titles.offset();
        var offset = grid ? { top: 100, left: 100 } : { top: 30, left: 30 };
        var $story_title = $(document.elementFromPoint(point.left + offset.left,
            point.top + offset.top
        )).closest('.' + NEWSBLUR.Views.StoryTitleView.prototype.className);
        var reached_bottom = this.collection.no_more_stories &&
            this.$el.height() - $story_titles.height() - scroll_y <= 0;
        var topstory = _.detect(this.stories, function (view) {
            if (!reached_bottom && view.el == $story_title[0]) return true;
            if (view.model.get('read_status') == 0 && view.model.score() >= score) {
                unread_stories.push(view.model);
            }
        });
        if (!topstory && !reached_bottom) {
            // console.log(['no closest', topstory, $story_title[0], document.elementFromPoint(offset.left + 20, offset.top + 20)]);
            return;
        }
        // console.log(['closest', $story_title[0], topstory && topstory.model.get('story_title'), unread_stories]);
        if (NEWSBLUR.reader.flags['opening_story']) {
            console.log(['opening story, not marking read', unread_stories]);
            return;
        }
        _.invoke(unread_stories, 'mark_read');
    }

});
