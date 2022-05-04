NEWSBLUR.Views.SidebarHeader = Backbone.View.extend({

    options: {
        el: '.left-north'
    },
    
    events: {
        'click .NB-feeds-header-user-interactions' : 'show_interactions_popover',
        'click .NB-feeds-header-collapse-sidebar'  : 'collapse_sidebar'
    },
    
    initialize: function() {
        _.bindAll(this, 'render', 'defer_render');
        this.feed_collection = this.options.feed_collection;
        this.socialfeed_collection = this.options.socialfeed_collection;
        
        this.feed_collection.bind('reset', this.defer_render);
        this.feed_collection.bind('add', this.defer_render);
        this.feed_collection.bind('remove', this.defer_render);
        this.feed_collection.bind('change:ps', this.defer_render);
        this.feed_collection.bind('change:nt', this.defer_render);
        this.feed_collection.bind('change:ng', this.defer_render);
        this.socialfeed_collection.bind('reset', this.defer_render);
        this.socialfeed_collection.bind('add', this.defer_render);
        this.socialfeed_collection.bind('remove', this.defer_render);
        this.socialfeed_collection.bind('change:ps', this.defer_render);
        this.socialfeed_collection.bind('change:nt', this.defer_render);
        this.socialfeed_collection.bind('change:ng', this.defer_render);
    },
    
    defer_render: function() {
        _.defer(this.render);
    },
    
    render: function() {
        this.count();

        var hide_read_feeds = NEWSBLUR.assets.preference('hide_read_feeds');
        // NEWSBLUR.log(["render feed list header", this.feed_collection.length, this.feeds_count, hide_read_feeds]);
        var $header = _.template('\
            <div class="NB-feeds-header-left">\
                <span class="NB-feeds-header-count NB-feeds-header-negative <% if (!negative_count) { %>NB-empty<% } %>"><%= negative_count %></span>\
                <span class="NB-feeds-header-count NB-feeds-header-neutral <% if (!neutral_count) { %>NB-empty<% } %>"><%= neutral_count %></span>\
                <span class="NB-feeds-header-count NB-feeds-header-positive <% if (!positive_count) { %>NB-empty<% } %>"><%= positive_count %></span>\
            </div>\
        ', {
            positive_count  : Inflector.commas(this.unread_counts['ps']),
            neutral_count   : Inflector.commas(this.unread_counts['nt']),
            negative_count  : Inflector.commas(this.unread_counts['ng']),
            hide_read_feeds : !!hide_read_feeds
        });
            
        this.$('.NB-feeds-header-dashboard').html($header);
        
        this.toggle_hide_read_preference();
        NEWSBLUR.reader.toggle_focus_in_slider();
        
        return this;
    },
    
    toggle_hide_read_preference: function() {
        var hide_read_feeds = NEWSBLUR.assets.preference('hide_read_feeds');
        if (NEWSBLUR.reader.flags['feed_list_showing_starred']) hide_read_feeds = true;
        this.$('.NB-feeds-header-sites').toggleClass('NB-feedlist-hide-read-feeds', !!hide_read_feeds);
        $("body").toggleClass("NB-feedlist-hide-read-feeds", !!hide_read_feeds);
    },
    
    count: function() {
        this.unread_counts = NEWSBLUR.assets.folders.unread_counts();
        this.unread_counts = NEWSBLUR.assets.social_feeds.unread_counts(this.unread_counts);
        
        if (!NEWSBLUR.Globals.is_authenticated) return;
        if (!NEWSBLUR.assets.preference('title_counts')) return;
        
        var counts = [];
        var unread_view = _.isNumber(this.options.unread_view) && this.options.unread_view || NEWSBLUR.assets.preference('unread_view');
        if (unread_view <= -1) {
            counts.push(Inflector.commas(this.unread_counts['ng']));
        }
        if (unread_view <= 0) {
            counts.push(Inflector.commas(this.unread_counts['nt']));
        }
        if (unread_view <= 1) {
            counts.push(Inflector.commas(this.unread_counts['ps']));
        }
        if (!this.unread_counts['ps']) {
            counts = [Inflector.commas(this.unread_counts['nt'])];
        }
        var title = "NewsBlur";
        if (_.any(counts)) {
            title = '(' + counts.join('/') + ') ' + title;
        }
        document.title = title;
    },
    
    count_feeds: function() {
        return this.feed_collection.select(function(f) {
            return f.get('active');
        }).length;
    },
    
    update_interactions_count: function(interactions_count) {
        var $badge = this.$(".NB-feeds-header-user-interactions-badge");
        
        if (!interactions_count) {
            $badge.addClass('NB-hidden').text('');
        } else {
            $badge.removeClass('NB-hidden').text('' + interactions_count);
        }
    },
    
    // ==========
    // = Events =
    // ==========
    
    show_interactions_popover: function() {
        NEWSBLUR.InteractionsPopover.create({});
    },
    
    collapse_sidebar: function() {
        if (!NEWSBLUR.reader.flags['splash_page_frontmost']) {
            NEWSBLUR.reader.close_sidebar();
        }
    }

});
