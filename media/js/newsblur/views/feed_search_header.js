NEWSBLUR.Views.FeedSearchHeader = Backbone.View.extend({

    el: ".NB-search-header",

    className: "NB-search-header",

    events: {
        "click .NB-search-header-save": "save_search"
    },

    unload: function () {
        this.$el.addClass("NB-hidden");
    },

    render: function () {
        this.showing_fake_folder = NEWSBLUR.reader.flags['river_view'] &&
            NEWSBLUR.reader.active_folder &&
            (NEWSBLUR.reader.active_folder.get('fake') || !NEWSBLUR.reader.active_folder.get('folder_title'));

        if (NEWSBLUR.reader.flags.search && NEWSBLUR.reader.flags.searching && NEWSBLUR.reader.flags.search.length) {
            this.$el.removeClass("NB-hidden");

            var $title = this.make_title();
            this.$(".NB-search-header-title").html($title);

            var saved = this.is_saved() ? 'Saved' : 'Save Search';
            this.$(".NB-search-header-save").text(saved);
        } else {
            this.unload();
        }
    },

    make_title: function () {
        var feed_title = NEWSBLUR.reader.feed_title();

        var $view = $(_.template('<div>\
            Searching \
            <b><%= feed_title %></b> for "<b><%= query %></b>"\
        </div>', {
            feed_title: feed_title,
            query: NEWSBLUR.reader.flags.search
        }));

        return $view;
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
    }

});
