NEWSBLUR.Views.FeedSearchHeader = Backbone.View.extend({

    el: ".NB-search-header",

    className: "NB-search-header",

    events: {
        "click .NB-search-header-save": "save_search",
        "click .NB-search-header-clear": "clear_date_filter"
    },

    unload: function () {
        this.$el.addClass("NB-hidden");
    },

    render: function () {
        this.showing_fake_folder = NEWSBLUR.reader.flags['river_view'] &&
            NEWSBLUR.reader.active_folder &&
            (NEWSBLUR.reader.active_folder.get('fake') || !NEWSBLUR.reader.active_folder.get('folder_title'));

        var date_filter_start = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'date_filter_start');
        var date_filter_end = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'date_filter_end');
        var has_date_filter = !!(date_filter_start || date_filter_end);

        if ((NEWSBLUR.reader.flags.search && NEWSBLUR.reader.flags.searching && NEWSBLUR.reader.flags.search.length) || has_date_filter) {
            this.$el.removeClass("NB-hidden");

            var $title = this.make_title();
            this.$(".NB-search-header-title").html($title);

            // Show "Save Search" button for searches, close icon for date filters
            if (NEWSBLUR.reader.flags.search && NEWSBLUR.reader.flags.searching && NEWSBLUR.reader.flags.search.length) {
                var saved = this.is_saved() ? 'Saved' : 'Save Search';
                this.$(".NB-search-header-save").text(saved).removeClass('NB-search-header-clear').show();
            } else if (has_date_filter) {
                this.$(".NB-search-header-save").html('').addClass('NB-search-header-clear').show();
            } else {
                this.$(".NB-search-header-save").hide();
            }
        } else {
            this.unload();
        }
    },

    make_title: function () {
        var feed_title = NEWSBLUR.reader.feed_title();
        var date_filter_start = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'date_filter_start');
        var date_filter_end = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'date_filter_end');

        // Check if we're showing search results or date filters
        if (NEWSBLUR.reader.flags.search && NEWSBLUR.reader.flags.searching && NEWSBLUR.reader.flags.search.length) {
            var $view = $(_.template('<div>\
                Searching \
                <b><%= feed_title %></b> for "<b><%= query %></b>"\
            </div>', {
                feed_title: feed_title,
                query: NEWSBLUR.reader.flags.search
            }));
            return $view;
        } else if (date_filter_start || date_filter_end) {
            // Format the date filter message
            var filter_text = '';
            if (date_filter_start && date_filter_end) {
                filter_text = 'between <b>' + date_filter_start + '</b> and <b>' + date_filter_end + '</b>';
            } else if (date_filter_start) {
                filter_text = 'newer than <b>' + date_filter_start + '</b>';
            } else if (date_filter_end) {
                filter_text = 'older than <b>' + date_filter_end + '</b>';
            }

            var $view = $(_.template('<div>\
                Showing stories <%= filter_text %>\
            </div>', {
                filter_text: filter_text
            }));
            return $view;
        }
    },

    is_saved: function () {
        return !!NEWSBLUR.assets.get_search_feeds(this.saved_feed_id(), NEWSBLUR.reader.flags.search);
    },

    saved_feed_id: function () {
        var feed_id = NEWSBLUR.reader.active_feed;
        if (_.isNumber(feed_id)) {
            feed_id = "feed:" + feed_id;
        }
        return feed_id;
    },

    // ==========
    // = Events =
    // ==========

    save_search: function (e) {
        var feed_id = this.saved_feed_id();
        if (this.is_saved()) {
            NEWSBLUR.assets.delete_saved_search(feed_id, NEWSBLUR.reader.flags.search, _.bind(function (e) {
                console.log(['Saved searches', e]);
                this.render();
            }, this));
        } else {
            NEWSBLUR.assets.save_search(feed_id, NEWSBLUR.reader.flags.search, _.bind(function (e) {
                console.log(['Saved searches', e]);
                this.render();
            }, this));
        }
    },

    clear_date_filter: function (e) {
        e.preventDefault();
        e.stopPropagation();

        // Clear the date filters on the current feed/folder
        var feed_id = NEWSBLUR.reader.active_feed;
        var obj;

        if (_.string.contains(feed_id, 'river:')) {
            // For river views, use the active folder
            obj = NEWSBLUR.reader.active_folder;
        } else {
            // For individual feeds, use the feed model
            obj = NEWSBLUR.assets.get_feed(feed_id);
        }

        if (obj) {
            obj.date_filter_start = null;
            obj.date_filter_end = null;
        }

        // Reload the feed to show all stories
        NEWSBLUR.reader.reload_feed();
    }

});
