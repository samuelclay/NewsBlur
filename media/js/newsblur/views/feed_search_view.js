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
        this.search_debounced = _.debounce(function(query) {
            NEWSBLUR.reader.reload_feed({
                search: query
            });
        }, 250);
    },
    
    render: function() {
        if (!NEWSBLUR.Globals.is_staff) return this;
        
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
    
    focus_search: function() {
        this.feedbar_view.$el.addClass("NB-searching");
    },
    
    blur_search: function() {
        var $search = this.$("input[name=feed_search]");
        var query = $search.val();
        
        if (query.length == 0) {
            this.feedbar_view.$el.removeClass("NB-searching");
            if (NEWSBLUR.reader.flags.search) {
                NEWSBLUR.reader.reload_feed();
            }
        }
    },
    
    keyup: function(e) {
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
            NEWSBLUR.reader.flags.search = query;
            this.search_debounced(query);
        }
    },
    
    close_search: function() {
        var $search = this.$("input[name=feed_search]");
        $search.val('');
        $search.blur();
    }
});