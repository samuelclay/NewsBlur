NEWSBLUR.Views.FeedSearchHeader = Backbone.View.extend({

    el: ".NB-search-header",

    className: "NB-search-header",

    events: {
        "click .NB-search-header-save": "save_search",
        "click .NB-search-header-clear": "clear_date_filter",
        "click .NB-feed-exception-button": "open_feed_exception_modal",
        "click .NB-webfeed-paused-button": "open_premium_upgrade_modal"
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
        this.is_paused_webfeed = feed && feed.get('is_webfeed') && !NEWSBLUR.Globals.is_archive && !this.showing_fake_folder;

        if (searching || has_date_filter || has_exception || this.is_paused_webfeed) {
            this.$el.removeClass("NB-hidden");

            // Add appropriate class for styling the icon
            this.$el.toggleClass("NB-exception", has_exception && !searching && !has_date_filter);
            this.$el.toggleClass("NB-searching", searching);
            this.$el.toggleClass("NB-date-filter", has_date_filter && !searching);
            this.$el.toggleClass("NB-webfeed-paused", this.is_paused_webfeed && !searching && !has_date_filter && !has_exception);

            var $title = this.make_title();
            this.$(".NB-search-header-title").html($title);

            // Show "Save Search" button for searches, close icon for date filters, hide for exceptions
            if (searching) {
                var saved = this.is_saved() ? gettext('Saved') : gettext('Save Search');
                this.$(".NB-search-header-save").text(saved).removeClass('NB-search-header-clear').show();
            } else if (has_date_filter) {
                this.$(".NB-search-header-save").html('').addClass('NB-search-header-clear').show();
            } else {
                this.$(".NB-search-header-save").hide();
            }
        } else {
            this.$el.removeClass("NB-exception NB-searching NB-date-filter NB-webfeed-paused");
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

        // Check if we're showing exception, paused webfeed, search results, or date filters
        if (has_exception && !searching && !date_filter_start && !date_filter_end) {
            var $view = $('<div class="NB-feed-exception-header">\
                <div class="NB-feed-exception-icon-large"></div>\
                <div class="NB-feed-exception-message">\
                    ' + interpolate(gettext("This site has not been fetched in <b>%(time)s</b> and is throwing errors."), { time: feed.get("updated") }, true) + '\
                </div>\
                <div class="NB-feed-exception-button" role="button">\
                    ' + _.escape(gettext("Fix misbehaving site")) + '\
                </div>\
            </div>');
            return $view;
        } else if (this.is_paused_webfeed && !searching && !date_filter_start && !date_filter_end) {
            var $view = $('<div class="NB-webfeed-paused-header">\
                <div class="NB-webfeed-paused-icon"></div>\
                <div class="NB-webfeed-paused-message">\
                    ' + gettext("This web feed is <b>paused</b>. Upgrade to Premium Archive to resume fetching new stories.") + '\
                </div>\
                <div class="NB-webfeed-paused-button" role="button">\
                    ' + _.escape(gettext("Upgrade to Premium Archive")) + '\
                </div>\
            </div>');
            return $view;
        } else if (searching) {
            var $view = $(_.template('<div>\
                <%= search_text %>\
            </div>', {
                search_text: interpolate(gettext('Searching <b>%(feed_title)s</b> for "<b>%(query)s</b>"'), {
                    feed_title: feed_title,
                    query: NEWSBLUR.reader.flags.search
                }, true)
            }));
            return $view;
        } else if (date_filter_start || date_filter_end) {
            // Format dates to be more readable, using the interface language's date conventions
            var format_date = function (date_string) {
                if (!date_string) return '';
                var date = new Date(date_string + 'T00:00:00');

                return date.toLocaleDateString(document.documentElement.lang || undefined, {
                    weekday: 'long',
                    month: 'long',
                    day: 'numeric',
                    year: 'numeric'
                });
            };

            // Format the date filter message
            var filter_text = '';
            var formatted_start = format_date(date_filter_start);
            var formatted_end = format_date(date_filter_end);

            if (date_filter_start && date_filter_end) {
                if (date_filter_start === date_filter_end) {
                    filter_text = interpolate(gettext("Showing stories on <b>%(date)s</b>"), { date: formatted_start }, true);
                } else {
                    filter_text = interpolate(gettext("Showing stories between <b>%(start_date)s</b> and <b>%(end_date)s</b>"), { start_date: formatted_start, end_date: formatted_end }, true);
                }
            } else if (date_filter_start) {
                filter_text = interpolate(gettext("Showing stories newer than <b>%(date)s</b>"), { date: formatted_start }, true);
            } else if (date_filter_end) {
                filter_text = interpolate(gettext("Showing stories older than <b>%(date)s</b>"), { date: formatted_end }, true);
            }

            var $view = $(_.template('<div>\
                <%= filter_text %>\
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
    },

    open_premium_upgrade_modal: function (e) {
        e.preventDefault();
        e.stopPropagation();

        NEWSBLUR.reader.open_premium_upgrade_modal({ highlight_feature: 'webfeeds' });
    }

});
