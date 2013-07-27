NEWSBLUR.Views.FeedSearchView = Backbone.View.extend({
    
    className: "NB-story-title-search",
    
    events: {
        "focus .NB-story-title-search-input": "focus_search",
        "blur .NB-story-title-search-input" : "blur_search",
        "keyup input[name=feed_search]"     : "keyup",
        "keydown input[name=feed_search]"   : "keydown",
        "click .NB-search-close"            : "close_search"
    },
    
    initialize: function(options) {
        this.feedbar_view = options.feedbar_view;
        this.search_debounced = _.debounce(_.bind(this.perform_search, this), 350);
    },
    
    render: function() {
        // if (!NEWSBLUR.Globals.is_staff) return this;
        
        var $view = $(_.template('\
            <input type="text" name="feed_search" class="NB-story-title-search-input NB-search-input" value="<%= search %>" />\
            <div class="NB-search-close"></div>\
        ', {
            search: NEWSBLUR.reader.flags['search']
        }));
        
        this.$el.html($view);
        
        return this;
    },
    
    // ==========
    // = Events =
    // ==========
    
    focus: function() {
        this.$("input").focus();
    },

    blur: function() {
        this.$("input").blur();
    },
    
    focus_search: function() {
        if (!NEWSBLUR.reader.flags.searching || !NEWSBLUR.reader.flags.search) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = "";
        }
        this.feedbar_view.$el.addClass("NB-searching");
    },
    
    blur_search: function() {
        var $search = this.$("input[name=feed_search]");
        var query = $search.val();
        
        if (query.length == 0) {
            NEWSBLUR.reader.flags.searching = false;
            this.feedbar_view.$el.removeClass("NB-searching");
            if (NEWSBLUR.reader.flags.search) {
                this.close_search();
            }
        }
    },
    
    keyup: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40, enter: 13, esc: 27};
        
        if (e.which == arrow.up || e.which == arrow.down) {
            this.blur();

            var event = $.Event('keydown');
            event.which = e.which;
            $(document).trigger(event);

            return false;
        }
        
        this.search();
    },
    
    keydown: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40, enter: 13, esc: 27};
        
        if (e.which == arrow.esc) {
            this.close_search();
            e.preventDefault();
            e.stopPropagation();
            return false;
        }
    },
    
    search: function() {
        var $search = this.$("input[name=feed_search]");
        var query = $search.val();
        
        if (query != NEWSBLUR.reader.flags.search) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = query;
            this.search_debounced(query);
        }
    },
    
    perform_search: function(query) {
        NEWSBLUR.reader.reload_feed({
            search: query
        });
    },
    
    close_search: function() {
        var $search = this.$("input[name=feed_search]");
        $search.val('');
        NEWSBLUR.reader.flags.searching = false;
        
        NEWSBLUR.reader.reload_feed();
    }
    
});