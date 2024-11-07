NEWSBLUR.Views.StoryDiscoverView = Backbone.View.extend({

    events: {
        "click .NB-feed-story-discover": "toggle_feed_story_discover_dialog",
    },

    initialize: function () {
        _.bindAll(this, 'toggle_feed_story_discover_dialog');
        this.sideoptions_view = this.options.sideoptions_view;
        this.model.story_discover_view = this;
    },

    render: function () {
        return this.template({
            story: this.model
        });
    },

    template: _.template('\
    <div class="NB-sideoption-discover-wrapper">\
        <div class="NB-sideoption-discover">\
            <div class="NB-sideoption-discover-controls">\
                <ul class="segmented-control NB-sideoption-discover-control">\
                    <li class="segmented-control-item NB-sideoption-discover-control-item NB-active">\
                        <a href="#">This site</a>\
                    </li>\
                    <li class="segmented-control-item NB-sideoption-discover-control-item">\
                        <a href="#">All sites</a>\
                    </li>\
                    <li class="segmented-control-item NB-sideoption-discover-control-item">\
                        <a href="#">Global</a>\
                    </li>\
                </ul>\
            </div>\
            <div class="NB-sideoption-discover-content">\
                <? if (loading) %>\
                    <div class="NB-discover-loading">\
                        <div class="NB-loading NB-active"></div>\
                    </div >\
                <? } else { %>\
                    <div class="NB-discover-content">\
                        <div class="NB-discover-content-item">\
                            <div class="NB-discover-content-item-title">\
                                <a href="#">Title</a>\
                            </div>\
                        </div>\
                    </div>\
                <? } %>\
            </div>\
        </div>\
    </div>\
    '),

    toggle_feed_story_discover_dialog: function (options) {
        options = options || {};
        var feed_id = this.model.get('story_feed_id');
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-discover');
        var $sideoption_container = this.$('.NB-feed-story-sideoptions-container');
        var $discover = this.$('.NB-sideoption-discover-wrapper');

        if (options.close ||
            ($sideoption.hasClass('NB-active') && !options.resize_open)) {
            // Close
            this.is_open = false;
            this.resize({ close: true });
            NEWSBLUR.reader.blur_to_page();
        } else {
            // Open/resize
            this.is_open = true;
            if (!options.resize_open) {
                this.$('.NB-error').remove();
            }
            $sideoption.addClass('NB-active');

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

    autosize: function () {
        this.resize({ duration: 100, resize_open: true });
    },

    resize: function (options) {
        options = options || {};
        var $sideoption_container = this.$('.NB-feed-story-sideoptions-container');
        var $discover_wrapper = this.$('.NB-sideoption-discover-wrapper');
        var $discover_content = this.$('.NB-sideoption-discover');
        var $user_notes = this.$('.NB-sideoption-discover-notes');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
        var $story_comments = this.$('.NB-feed-story-comments');
        var $sideoption = this.$('.NB-feed-story-discover');
        var $tag_input = this.$('.NB-sideoption-discover-tag');

        var $discover_clone = $discover_wrapper.clone();
        $discover_wrapper.after($discover_clone.css({
            'height': options.close ? 0 : 'auto',
            'position': 'absolute',
            'visibility': 'hidden',
            'display': 'block'
        }));
        var sideoption_content_height = $discover_clone.height();
        $discover_clone.remove();
        var new_sideoptions_height = $sideoption_container.height() - $discover_wrapper.height() + sideoption_content_height;
        if (!options.close) {
            $sideoption.addClass('NB-active');
            $discover_wrapper.addClass('NB-active');
        }

        if (!options.resize_open && !options.close && !options.change_tag) {
            $discover_wrapper.css('height', '0px');
        }
        $discover_wrapper.animate({
            'height': sideoption_content_height
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

        var sideoptions_height = $sideoption_container.height();
        var content_height = $story_content.height();
        var comments_height = $story_comments.height();
        var left_height = content_height + comments_height;
        var original_height = $story_content.data('original_height') || content_height;
        if (!NEWSBLUR.reader.flags.narrow_content &&
            !options.close && !options.force && new_sideoptions_height >= original_height) {
            // Sideoptions too big, embiggen left side
            console.log(["Sideoption too big, embiggening", content_height, sideoptions_height, new_sideoptions_height]);
            $story_content.stop(true, true).animate({
                'min-height': new_sideoptions_height
            }, {
                'duration': 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': function () {
                    if (NEWSBLUR.app.story_list) {
                        NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                    }
                }
            });
            if (!$story_content.data('original_height')) {
                $story_content.data('original_height', content_height);
            }
        } else if (!NEWSBLUR.reader.flags.narrow_content) {
            // Content is bigger, move content back to normal
            if ($story_content.data('original_height') && !this.sideoptions_view.discover_view.is_open) {
                $story_content.stop(true, true).animate({
                    'height': $story_content.data('original_height')
                }, {
                    'duration': 300,
                    'easing': 'easeInOutQuint',
                    'queue': false,
                    'complete': function () {
                        if (NEWSBLUR.app.story_list) {
                            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                        }
                    }
                });
            } else if (this.sideoptions_view.discover_view.is_open && !options.from_discover_view) {
                this.sideoptions_view.discover_view.resize({ from_discover_view: true });
            }
        }

        if (NEWSBLUR.app.story_list) {
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }
    },

    reset_height: function () {
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');

        // Reset story content height to get an accurate height measurement.
        $story_content.stop(true, true).css('height', 'auto');
        $story_content.removeData('original_height');

        this.resize({ change_tag: true });
    }

});
