NEWSBLUR.Views.FeedSearchHeader = Backbone.View.extend({

    el: ".NB-search-header",

    className: "NB-search-header",

    events: {
        "click .NB-search-header-save": "save_search",
        "click .NB-search-header-clear": "clear_date_filter",
        "click .NB-feed-exception-button": "open_feed_exception_modal"
    },

    unload: function () {
        this.$el.addClass("NB-hidden");
    },

    render: function () {
        this.showing_fake_folder = NEWSBLUR.reader.flags['river_view'] &&
            NEWSBLUR.reader.active_folder &&
            (NEWSBLUR.reader.active_folder.get('fake') || !NEWSBLUR.reader.active_folder.get('folder_title'));
        console.log(['showing fake folder', this.showing_fake_folder, NEWSBLUR.reader.active_folder, NEWSBLUR.reader.flags]);
        var searching = NEWSBLUR.reader.flags.search && NEWSBLUR.reader.flags.searching && NEWSBLUR.reader.flags.search.length;
        var date_filter_start = NEWSBLUR.reader.flags.date_filter_start;
        var date_filter_end = NEWSBLUR.reader.flags.date_filter_end;
        var has_date_filter = !!(date_filter_start || date_filter_end);
        var feed = NEWSBLUR.assets.get_feed(NEWSBLUR.reader.active_feed);
        var has_exception = feed && feed.get('has_exception') && feed.get('exception_type') == 'feed' && !this.showing_fake_folder;

        if (searching || has_date_filter || has_exception) {
            this.$el.removeClass("NB-hidden");

            // Add appropriate class for styling the icon
            this.$el.toggleClass("NB-exception", has_exception && !searching && !has_date_filter);
            this.$el.toggleClass("NB-searching", searching);
            this.$el.toggleClass("NB-date-filter", has_date_filter && !searching);

            var $title = this.make_title();
            this.$(".NB-search-header-title").html($title);

            // Show "Save Search" button for searches, close icon for date filters, hide for exceptions
            if (searching) {
                var saved = this.is_saved() ? 'Saved' : 'Save Search';
                this.$(".NB-search-header-save").text(saved).removeClass('NB-search-header-clear').show();
            } else if (has_date_filter) {
                this.$(".NB-search-header-save").html('').addClass('NB-search-header-clear').show();
            } else {
                this.$(".NB-search-header-save").hide();
            }
        } else {
            this.$el.removeClass("NB-exception NB-searching NB-date-filter");
            this.unload();
        }
    },

    make_title: function () {
        var feed_title = NEWSBLUR.reader.feed_title();
        var date_filter_start = NEWSBLUR.reader.flags.date_filter_start;
        var date_filter_end = NEWSBLUR.reader.flags.date_filter_end;
        var searching = NEWSBLUR.reader.flags.search && NEWSBLUR.reader.flags.searching && NEWSBLUR.reader.flags.search.length;
        var feed = NEWSBLUR.assets.get_feed(NEWSBLUR.reader.active_feed);
        var has_exception = feed && feed.get('has_exception') && feed.get('exception_type') == 'feed' && !this.showing_fake_folder;

        // Check if we're showing exception, search results, or date filters
        if (has_exception && !searching && !date_filter_start && !date_filter_end) {
            var $view = $('<div class="NB-feed-exception-header">\
                <div class="NB-feed-exception-icon-large"></div>\
                <div class="NB-feed-exception-message">\
                    This site has not been fetched in <b>' + feed.get("updated") + '</b> and is throwing errors.\
                </div>\
                <div class="NB-feed-exception-button" role="button">\
                    Fix misbehaving site\
                </div>\
            </div>');
            return $view;
        } else if (searching) {
            var $view = $(_.template('<div>\
                Searching \
                <b><%= feed_title %></b> for "<b><%= query %></b>"\
            </div>', {
                feed_title: feed_title,
                query: NEWSBLUR.reader.flags.search
            }));
            return $view;
        } else if (date_filter_start || date_filter_end) {
            // Format dates to be more readable
            var format_date = function (date_string) {
                if (!date_string) return '';
                var date = new Date(date_string + 'T00:00:00');
                var days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                var months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

                var day_name = days[date.getDay()];
                var month_name = months[date.getMonth()];
                var day = date.getDate();
                var year = date.getFullYear();

                // Add ordinal suffix (st, nd, rd, th)
                var suffix = 'th';
                if (day % 10 === 1 && day !== 11) suffix = 'st';
                else if (day % 10 === 2 && day !== 12) suffix = 'nd';
                else if (day % 10 === 3 && day !== 13) suffix = 'rd';

                return day_name + ', ' + month_name + ' ' + day + suffix + ', ' + year;
            };

            // Format the date filter message
            var filter_text = '';
            var formatted_start = format_date(date_filter_start);
            var formatted_end = format_date(date_filter_end);

            if (date_filter_start && date_filter_end) {
                if (date_filter_start === date_filter_end) {
                    filter_text = 'on <b>' + formatted_start + '</b>';
                } else {
                    filter_text = 'between <b>' + formatted_start + '</b> and <b>' + formatted_end + '</b>';
                }
            } else if (date_filter_start) {
                filter_text = 'newer than <b>' + formatted_start + '</b>';
            } else if (date_filter_end) {
                filter_text = 'older than <b>' + formatted_end + '</b>';
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

        NEWSBLUR.reader.clear_active_feed_date_filters();
        NEWSBLUR.reader.reload_feed();
    },

    open_feed_exception_modal: function (e) {
        e.preventDefault();
        e.stopPropagation();

        NEWSBLUR.reader.open_feed_exception_modal(NEWSBLUR.reader.active_feed);
    }

});
