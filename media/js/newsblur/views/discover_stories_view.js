NEWSBLUR.Views.DiscoverStoriesView = Backbone.View.extend({

    is_open: false,

    events: {
        "click .NB-sideoption-discover-control-item": "switch_discover_section",
        "click .NB-discover-load-more": "load_more_stories",
        "click .NB-discover-retry": "retry_load_stories",
        "click .NB-discover-upgrade.NB-modal-submit-button": "show_premium_upgrade_modal"
    },

    initialize: function () {
        _.bindAll(this, 'switch_discover_section', 'load_discover_stories');
        this.model.story_discover_view = this;
        this.page = 1;
        this.has_more_results = true;
        this.is_loading = false;
        this.current_request = null;
        NEWSBLUR.reader.current_discover_stories_view = this;

        // Initialize discover stories collection
        this.discover_stories = new NEWSBLUR.Collections.DiscoverStories();
    },

    switch_discover_section: function (e) {
        e.preventDefault();

        // Abort any pending request
        if (this.current_request) {
            this.current_request.abort();
            this.current_request = null;
            this.is_loading = false;
        }

        var $section = $(e.currentTarget);

        // Update active state
        this.$('.NB-sideoption-discover-control-item').removeClass('NB-active');
        $section.addClass('NB-active');

        var section = $section.data('selected-feed');
        NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, { 'stories_discover': section });
        console.log(["Setting discover stories section", NEWSBLUR.reader.active_feed, section]);
        this.page = 1;
        this.has_more_results = true;
        this.discover_stories.reset();
        this.load_discover_stories();
    },

    load_discover_stories: function () {
        if (!NEWSBLUR.Globals.is_premium) return;

        if (this.is_loading || !this.has_more_results) return;

        // Abort any pending request
        if (this.current_request) {
            this.current_request.abort();
            this.current_request = null;
        }

        this.is_loading = true;
        this.show_loading();
        this.$(".NB-sideoption-discover-control-item").removeClass('NB-active');

        var feed_ids = [];
        var section = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'stories_discover');
        if (section === 'all') {
            feed_ids = NEWSBLUR.assets.feeds.pluck('id');
            this.$(".NB-sideoption-discover-control-item[data-selected-feed='all']").addClass('NB-active');
        } else if (_.string.startsWith(section, 'feed')) {
            feed_ids = [this.model.get('story_feed_id')];
            this.$(".NB-sideoption-discover-control-item[data-selected-feed='feed:" + this.model.get('story_feed_id') + "']").addClass('NB-active');
        } else if (section === 'global') {
            feed_ids = [];
            this.$(".NB-sideoption-discover-control-item[data-selected-feed='global']").addClass('NB-active');
        } else {
            // Use the selected folder feed ids
            var folder_title = section.split(':')[1];
            feed_ids = NEWSBLUR.assets.get_folder(folder_title).feed_ids_in_folder();
            this.$(".NB-sideoption-discover-control-item[data-selected-feed='river:" + folder_title + "']").addClass('NB-active');
        }
        console.log(["Discover stories section", NEWSBLUR.reader.active_feed, section, feed_ids]);

        // Configure collection for current view
        this.discover_stories.similar_to_story_hash = this.model.get('story_hash');

        var self = this;
        this.current_request = this.discover_stories.fetch({
            remove: this.page == 1,
            type: 'POST',
            data: {
                feed_ids: feed_ids,
                page: this.page
            },
            success: function (collection, response) {
                self.current_request = null;
                self.is_loading = false;
                if (!collection.length || !response.discover_stories.length) {
                    self.has_more_results = false;
                }
                self.hide_loading();
                self.render();
                self.resize();
                self.page += 1;
                if (self.page > 20) {
                    self.has_more_results = false;
                }
            },
            error: function (collection, response) {
                // Only handle the error if it's not an abort
                console.log(["Discover stories error", collection, response]);
                if (!response.statusText || response.statusText !== "abort") {
                    self.is_loading = false;
                    self.hide_loading();
                    self.show_error();
                }
                self.current_request = null;
            }
        });
    },

    show_loading: function (options) {
        options = options || {};

        this.$('.NB-end-line').remove();
        this.$('.NB-discover-error').remove();
        var $endline = $.make('div', { className: "NB-end-line NB-load-line NB-short" });
        $endline.css({ 'background': '#FFF' });
        this.$(".NB-sideoption-discover-content").append($endline);
        this.$(".NB-discover-load-more-container").hide();
        this.$(".NB-discover-empty").hide();
    },

    hide_loading: function () {
        this.$('.NB-load-line').remove();
    },

    render: function () {
        var self = this;

        if (this.page === 1) {
            this.$('.NB-sideoption-discover-content').empty();
        }

        var $el = $.make('div', [
            $.make('div', { className: 'NB-story-content-discover ' + (this.is_open ? 'NB-active' : '') }, [
                $.make('div', { className: 'NB-sideoption-discover' }, [
                    // Controls section
                    $.make('div', { className: 'NB-sideoption-discover-controls' }, [
                        $.make('ul', { className: 'segmented-control NB-sideoption-discover-control' }, [
                            $.make('li', {
                                className: 'segmented-control-item NB-sideoption-discover-control-item',
                                'data-selected-feed': 'feed:' + this.model.get("story_feed_id")
                            }, [
                                $.make('a', { href: '#' }, 'This site')
                            ]),
                            // Folder options
                            _.map(NEWSBLUR.assets.get_feed(this.model.get('story_feed_id')).in_folders(), function (folder) {
                                if (folder && folder.length) {
                                    return $.make('li', {
                                        className: 'segmented-control-item NB-sideoption-discover-control-item',
                                        'data-selected-feed': 'river:' + folder
                                    }, [
                                        $.make('a', { href: '#' }, folder)
                                    ]);
                                }
                            }),
                            $.make('li', {
                                className: 'segmented-control-item NB-sideoption-discover-control-item',
                                'data-selected-feed': 'all'
                            }, [
                                $.make('a', { href: '#' }, 'All sites')
                            ]),
                            $.make('li', {
                                className: 'segmented-control-item NB-sideoption-discover-control-item',
                                'data-selected-feed': 'global'
                            }, [
                                $.make('a', { href: '#' }, 'Global')
                            ])
                        ])
                    ]),
                    // Content section
                    $.make('div', { className: 'NB-sideoption-discover-content NB-story-pane-west' }, [
                        !NEWSBLUR.Globals.is_premium ?
                            this.render_premium_only_message() :
                            !this.discover_stories.length ?
                                $.make('div', { className: 'NB-discover-empty' }, 'No similar stories found') :
                                (function () {
                                    var $story_titles = $.make('div', {
                                        className: 'NB-story-titles NB-discover-story-titles'
                                    });

                                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                                        el: $story_titles,
                                        collection: self.discover_stories,
                                        $story_titles: $story_titles,
                                        override_layout: 'split',
                                        on_discover_story: self.discover_stories
                                    });

                                    story_titles_view.render();
                                    return $story_titles;
                                })()
                    ]),
                    (this.discover_stories.length && !this.is_loading && $.make('div', { className: 'NB-discover-load-more-container' }, [
                        this.has_more_results ?
                            $.make('div', { className: 'NB-discover-load-more NB-modal-submit-button NB-modal-submit-green' }, [
                                $.make('div', { className: 'NB-discover-load-more-text' }, 'Show more related stories')
                            ]) :
                            (this.page > 1 ? $.make('div', { className: 'NB-end-line' }, [
                                $.make('div', { className: 'NB-fleuron' })
                            ]) : '')
                    ])),
                    (NEWSBLUR.Globals.is_premium && !NEWSBLUR.Globals.is_archive &&
                        $.make('div', { className: 'NB-discover-empty' }, [
                            this.render_discover_indexed_non_premium_message(),
                            $.make('br'),
                            'All related stories are available to Premium Archive subscribers.',
                            $.make('div', {
                                className: 'NB-discover-upgrade NB-modal-submit-button NB-modal-submit-green',
                            }, [
                                'Upgrade to Premium Archive'
                            ])
                        ])
                    )
                ])
            ])
        ]);

        console.log(["Discover stories render", this.discover_stories, this.$el]);
        this.$(".NB-story-content-discover-wrapper").html($el);

        // Update active section indicator
        var section = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'stories_discover');
        this.$(".NB-sideoption-discover-control-item").removeClass('NB-active');

        var $active_section = null;
        if (section === 'all') {
            $active_section = this.$(".NB-sideoption-discover-control-item[data-selected-feed='all']");
        } else if (_.string.startsWith(section, 'feed')) {
            $active_section = this.$(".NB-sideoption-discover-control-item[data-selected-feed='feed:" + this.model.get('story_feed_id') + "']");
        } else if (section === 'global') {
            $active_section = this.$(".NB-sideoption-discover-control-item[data-selected-feed='global']");
        } else {
            var folder_title = section.split(':')[1];
            $active_section = this.$(".NB-sideoption-discover-control-item[data-selected-feed='river:" + folder_title + "']");
        }

        if (!$active_section || !$active_section.length) {
            $active_section = this.$(".NB-sideoption-discover-control-item[data-selected-feed='all']");
        }

        $active_section.addClass('NB-active');

        return this;
    },

    render_discover_indexed_non_premium_message: function () {
        var discover_indexed_count = NEWSBLUR.assets.feeds.reduce(function (sum, feed) {
            return sum + (feed.get('discover_indexed') ? 1 : 0);
        }, 0);
        var feed_count = NEWSBLUR.assets.feeds.length;
        var feed_discover_indexed = NEWSBLUR.assets.feeds.get(this.model.get('story_feed_id')).get('discover_indexed');
        var view_setting = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'stories_discover');
        var is_this_site = _.string.startsWith(view_setting, 'feed');
        var is_global = view_setting === 'global';
        var is_folder = _.string.startsWith(view_setting, 'river:');
        var is_all = view_setting === 'all';

        if (is_this_site) {
            if (!feed_discover_indexed) {
                return 'This site has not yet been indexed for related stories.';
            } else {
                return 'Only recent stories shown from this site are available.';
            }
        } else if (is_folder) {
            var folder_title = view_setting.split(':')[1];
            var feed_ids = NEWSBLUR.assets.get_folder(folder_title).feed_ids_in_folder();
            feed_count = feed_ids.length;
            discover_indexed_count = NEWSBLUR.assets.feeds.filter(function (feed) {
                return _.contains(feed_ids, feed.get('id'));
            }).reduce(function (sum, feed) {
                return sum + (feed.get('discover_indexed') ? 1 : 0);
            }, 0);
            if (discover_indexed_count == 0) {
                return 'No stories from ' + folder_title + ' have yet been indexed for related stories.';
            } else if (discover_indexed_count < feed_count) {
                return 'Only recent stories shown from ' + discover_indexed_count + ' of ' + feed_count + ' sites.';
            } else {
                return 'Only recent stories shown from ' + feed_count + ' sites.';
            }
        } else if (is_all) {
            if (discover_indexed_count == 0) {
                return 'No stories from your ' + feed_count + ' sites have yet been indexed for related stories.';
            } else if (discover_indexed_count < feed_count) {
                return 'Only recent stories shown from ' + discover_indexed_count + ' of ' + feed_count + ' sites.';
            } else {
                return 'Only recent stories shown from ' + feed_count + ' sites.';
            }
        } else if (is_global) {
            return 'Only ' + discover_indexed_count + ' of ' + feed_count + ' of your sites have been indexed for related stories.';
        }

        return 'Only recent stories shown from ' + feed_count + ' sites.';
    },

    render_premium_only_message: function () {
        return $.make('div', { className: 'NB-discover-empty' }, [
            'Related stories are only available for premium subscribers.',
            $.make('div', {
                className: 'NB-discover-upgrade NB-modal-submit-button NB-modal-submit-green',
            }, [
                'Upgrade to Premium'
            ])
        ]);
    },

    toggle_feed_story_discover_dialog: function (options) {
        options = options || {};
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-discover');
        var $discover = this.$('.NB-story-content-discover-wrapper');

        console.log(["Discover stories toggle", this.is_open, options]);

        if (options.close || (this.is_open && !options.resize_open)) {
            // Close
            this.is_open = false;
            this.resize({ close: true });
            NEWSBLUR.reader.blur_to_page();
        } else {
            // Move discover view based on narrow_content flag
            this.position_discover_view();

            // Open/resize
            this.is_open = true;
            if (!options.resize_open) {
                this.$('.NB-error').remove();
            }
            $sideoption.addClass('NB-active');
            $discover.addClass('NB-active');

            // Load initial stories
            this.page = 1;
            this.has_more_results = true;
            this.load_discover_stories();

            if (options.animate_scroll) {
                var $scroll_container = NEWSBLUR.reader.$s.$story_titles;
                if (_.contains(['split', 'full'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    $scroll_container = this.model.latest_story_detail_view.$el.parent();
                }
                $scroll_container.stop().scrollTo(this.$el, {
                    duration: 600,
                    queue: false,
                    easing: 'easeInOutQuint',
                    offset: this.model.latest_story_detail_view.$el.height() -
                        $scroll_container.height()
                });
            }

            this.resize(options);
        }
    },

    position_discover_view: function () {
        var $discover = this.$('.NB-story-content-discover-wrapper');
        if (NEWSBLUR.reader.flags.narrow_content) {
            // Move to below the sideoptions
            this.$('.NB-feed-story-sideoptions-container').append($discover);
        } else {
            // Move to below the story content 
            this.$el.append($discover);
        }
    },

    autosize: function () {
        this.position_discover_view();
        this.resize({ duration: 100, resize_open: true });
    },

    resize: function (options) {
        options = options || {};
        var $sideoption_container = this.$('.NB-feed-story-sideoptions-container');
        var $discover_wrapper = this.$('.NB-story-content-discover-wrapper');
        var $discover_content = this.$('.NB-sideoption-discover');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
        var $story_comments = this.$('.NB-feed-story-comments');
        var $sideoption = this.$('.NB-feed-story-discover');
        var $tag_input = this.$('.NB-sideoption-discover-tag');

        var new_sideoptions_height = $sideoption_container.height() - $discover_wrapper.height() + 200;

        if (!options.close) {
            $sideoption.addClass('NB-active');
            $discover_wrapper.addClass('NB-active');
        }

        if (!options.resize_open && !options.close) {
            $discover_wrapper.css('height', 'auto');
        }

        $discover_wrapper.animate({
            'height': options.close ? 0 : 'auto'
        }, {
            'duration': options.immediate ? 0 : options.duration || 350,
            'easing': 'easeInOutQuint',
            'queue': false,
            'complete': _.bind(function () {
                if ($tag_input.length == 1) {
                    $tag_input.focus();
                }
                if (NEWSBLUR.app.story_list) {
                    NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                }
                if (options.close) {
                    $sideoption.removeClass('NB-active');
                    $discover_wrapper.removeClass('NB-active');
                }
            }, this)
        });

        if (NEWSBLUR.app.story_list) {
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }
    },

    load_more_stories: function (e) {
        if (e) {
            e.preventDefault();
        }
        if (this.is_loading || !this.has_more_results) return;

        this.load_discover_stories();
    },

    retry_load_stories: function (e) {
        if (e) e.preventDefault();
        this.page = 1;
        this.has_more_results = true;
        this.discover_stories.reset();
        this.$('.NB-discover-error').remove();
        this.load_discover_stories();
    },

    show_premium_upgrade_modal: function (e) {
        e.preventDefault();
        NEWSBLUR.reader.open_feedchooser_modal({ premium_only: true });
    },

    show_error: function () {
        this.$('.NB-discover-empty').remove();
        this.$('.NB-discover-error').remove();

        var $error = $.make('div', { className: 'NB-discover-error NB-discover-empty' }, [
            $.make('div', 'Failed to load stories'),
            $.make('div', { className: 'NB-discover-retry NB-modal-submit-button NB-modal-submit-green' }, [
                'Try again'
            ])
        ]);

        this.$(".NB-sideoption-discover-content").append($error);
    }

});
