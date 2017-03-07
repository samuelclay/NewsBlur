NEWSBLUR.Views.FeedSearchHeader = Backbone.View.extend({
    
    el: ".NB-search-header",
    
    className: "NB-search-header",
    
    events: {
        "click .NB-search-header-save": "save_search"
    },
    
    unload: function() {
        this.$el.addClass("NB-hidden");
    },
    
    render: function() {
        this.showing_fake_folder = NEWSBLUR.reader.flags['river_view'] && 
            NEWSBLUR.reader.active_folder && 
            (NEWSBLUR.reader.active_folder.get('fake') || !NEWSBLUR.reader.active_folder.get('folder_title'));
        
        if (NEWSBLUR.reader.flags.search || NEWSBLUR.reader.flags.searching) {
            this.$el.removeClass("NB-hidden");
            var $title = this.make_title();
            this.$(".NB-search-header-title").html($title);
        } else {
            this.unload();
        }
    },
    
    make_title: function() {
        var feed_title;
        if (NEWSBLUR.reader.flags['starred_view'] ||
            NEWSBLUR.reader.active_feed == "read" || 
            this.showing_fake_folder) {
            feed_title = NEWSBLUR.reader.active_fake_folder_title();
        } else if (NEWSBLUR.reader.active_folder) {
            feed_title = NEWSBLUR.reader.active_folder.get('folder_title');
        } else if (NEWSBLUR.reader.active_feed) {
            feed_title = NEWSBLUR.assets.get_feed(NEWSBLUR.reader.active_feed).get('feed_title');
        }
        var $view = $(_.template('<div>\
            Searching \
            <b><%= feed_title %></b> for "<b><%= query %></b>"\
        </div>', {
            feed_title: feed_title,
            query: NEWSBLUR.reader.flags.search
        }));
        
        return $view;
    },
    
    // ==========
    // = Events =
    // ==========
    
    save_search: function(e) {
        var feed_id = NEWSBLUR.reader.active_feed;
        if (_.isNumber(feed_id)) {
            feed_id = "feed:" + feed_id;
        }
        NEWSBLUR.assets.save_search(feed_id, NEWSBLUR.reader.flags.search, function(e) {
            console.log(['Saved searches', e]);
        });
    }
    
});