NEWSBLUR.Views.FeedSearchView = Backbone.View.extend({
    
    className: "NB-story-title-search",
    
    events: {
        "focus .NB-story-title-search-input": "focus_search",
        "blur .NB-story-title-search-input" : "blur_search",
        "keyup input[name=feed_search]"     : "keyup",
        "keydown input[name=feed_search]"   : "keydown",
        "click .NB-search-close"            : "close_search",
        "mouseenter"                        : "mouseenter",
        "mouseleave"                        : "mouseleave"
    },
    
    initialize: function(options) {
        this.feedbar_view = options.feedbar_view;
        this.search_debounced = _.debounce(_.bind(this.perform_search, this), 350);
    },
    
    render: function() {
        if (NEWSBLUR.app.active_search) {
            NEWSBLUR.app.active_search.blur_search();
            NEWSBLUR.app.active_search.remove();
        }
        NEWSBLUR.app.active_search = this;
        var $view = $(_.template('\
            <input type="text" name="feed_search" class="NB-story-title-search-input NB-search-input" value="<%= search %>" />\
            <div class="NB-search-icon"></div>\
            <div class="NB-search-close"></div>\
        ', {
            search: NEWSBLUR.reader.flags['search']
        }));
        
        this.$el.html($view);
        
        return this;
    },
    
    remove: function() {
        var $icon = this.$('.NB-search-icon');
        var tipsy = $icon.data('tipsy');
        if (tipsy) {
            tipsy.disable();
            tipsy.hide();
        }
        NEWSBLUR.reader.$s.$story_titles_header.removeClass("NB-searching");
        Backbone.View.prototype.remove.call(this);
    },
    
    // ============
    // = Indexing =
    // ============
    
    update_indexing_progress: function(message) {
        var $input = this.$('input');
        var $icon = this.$('.NB-search-icon');

        if (message == "start") {
            this.show_indexing_tooltip(true);
        } else if (message == "done") {
            $input.attr('style', null);
            var tipsy = $icon.data('tipsy');
            _.defer(function() {
                if (!tipsy) return;
                tipsy.disable();
                tipsy.hide();
            });
            this.retry();
        } else if (_.string.startsWith(message, 'feeds:')) {
            var feed_ids = message.replace('feeds:', '').split(',');
            _.each(feed_ids, function(feed_id) {
                var feed = NEWSBLUR.assets.get_feed(parseInt(feed_id, 10));
                feed.set('search_indexed', true);
            });
            this.show_indexing_tooltip(false);
            var indexed = NEWSBLUR.assets.feeds.search_indexed();
            var total = NEWSBLUR.assets.feeds.length;
            progress = Math.ceil(indexed / total * 100);
            NEWSBLUR.utils.attach_loading_gradient($input, progress);
        }
    },
    
    show_indexing_tooltip: function(show) {
        var $icon = this.$('.NB-search-icon');
        var tipsy = $icon.data('tipsy');
        
        if (tipsy) return;
        
        $icon.tipsy({
            title: function() { return "Hang tight, indexing..."; },
            gravity: 'nw',
            fade: true,
            trigger: 'manual',
            offset: 4
        });
        var tipsy = $icon.data('tipsy');
        _.defer(function() {
            tipsy.enable();
            if (show) tipsy.show();
        });
        _.delay(function() {
            tipsy.hide();
        }, 3 * 1000);

    },
    
    // ==========
    // = Events =
    // ==========
    
    focus: function() {
        this.$("input").focus();
    },
    
    has_focus: function() {
        return this.$("input:focus").length;
    },

    blur: function() {
        this.$("input").blur();
    },
    
    focus_search: function() {
        if (!NEWSBLUR.reader.flags.searching || !NEWSBLUR.reader.flags.search) {
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = "";
        }
        NEWSBLUR.reader.$s.$story_titles_header.addClass("NB-searching");
    },
    
    blur_search: function() {
        var $search = this.$("input[name=feed_search]");
        var query = $search.val();
        
        if (query.length == 0) {
            NEWSBLUR.reader.flags.searching = false;
            NEWSBLUR.reader.$s.$story_titles_header.removeClass("NB-searching");
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
    
    retry: function() {
        if (!NEWSBLUR.reader.flags.search) return;
        
        NEWSBLUR.reader.flags.search = null;
        this.search();
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
        if (query && query.length) {
            window.history.pushState({}, "", $.updateQueryString('search', query, window.location.pathname));
        } else {
            window.history.pushState({}, "", $.updateQueryString('search', null, window.location.pathname));
        }
        NEWSBLUR.reader.reload_feed({
            search: query
        });
        NEWSBLUR.app.story_titles_header.show_hidden_story_titles();
    },
    
    close_search: function() {
        var $search = this.$("input[name=feed_search]");
        $search.val('');
        window.history.pushState({}, "", $.updateQueryString('search', null, window.location.pathname));
        NEWSBLUR.reader.flags.searching = false;
        
        NEWSBLUR.reader.reload_feed();
    },
    
    mouseenter: function(e) {
        var $icon = this.$('.NB-search-icon');
        var tipsy = $icon.data('tipsy');
        
        if (!tipsy) return;
        
        tipsy.show();
    },
    
    mouseleave: function(e) {
        var $icon = this.$('.NB-search-icon');
        var tipsy = $icon.data('tipsy');
        
        if (!tipsy) return;
        
        tipsy.hide();
    }
    
});