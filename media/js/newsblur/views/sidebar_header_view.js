NEWSBLUR.Views.SidebarHeader = Backbone.View.extend({

    options: {
        el: '.NB-feeds-header-dashboard'
    },
    
    events: {
        'click .NB-feeds-header-dashboard' : 'show_splash_page'
    },
    
    initialize: function() {
        _.bindAll(this, 'render', 'defer_render');
        this.collection.bind('reset', this.defer_render);
        this.collection.bind('add', this.defer_render);
        this.collection.bind('remove', this.defer_render);
        this.collection.bind('change:ps', this.defer_render);
        this.collection.bind('change:nt', this.defer_render);
        this.collection.bind('change:ng', this.defer_render);
    },
    
    defer_render: function() {
        _.defer(this.render);
    },
    
    render: function() {
        this.count();

        var hide_read_feeds = NEWSBLUR.assets.preference('hide_read_feeds');
        // NEWSBLUR.log(["render feed list header", this.collection.length, this.feeds_count, hide_read_feeds]);
        var $header = _.template('\
            <div class="NB-feeds-header-dashboard">\
                <div class="NB-feeds-header-right">\
                    <div class="NB-feeds-header-sites <%= hide_read_feeds ? "NB-feedlist-hide-read-feeds" : "" %>"><%= feeds_count %></div>\
                </div>\
                <div class="NB-feeds-header-left">\
                    <span class="NB-feeds-header-count NB-feeds-header-negative <% if (!negative_count) { %>NB-empty<% } %>"><%= negative_count %></span>\
                    <span class="NB-feeds-header-count NB-feeds-header-neutral <% if (!neutral_count) { %>NB-empty<% } %>"><%= neutral_count %></span>\
                    <span class="NB-feeds-header-count NB-feeds-header-positive <% if (!positive_count) { %>NB-empty<% } %>"><%= positive_count %></span>\
                </div>\
                <div class="NB-feeds-header-home">Dashboard</div>\
            </div>\
        ', {
            feeds_count     : (this.feeds_count ? Inflector.pluralize(' site', this.feeds_count, true) : '&nbsp;'),
            positive_count  : this.unread_counts['positive'],
            neutral_count   : this.unread_counts['neutral'],
            negative_count  : this.unread_counts['negative'],
            hide_read_feeds : !!hide_read_feeds
        });
            
        $(this.el).html($header);
        
        this.toggle_hide_read_preference();
        
        return this;
    },
    
    toggle_hide_read_preference: function() {
        var hide_read_feeds = NEWSBLUR.assets.preference('hide_read_feeds');
        this.$('.NB-feeds-header-sites').toggleClass('NB-feedlist-hide-read-feeds', !!hide_read_feeds);
        $("body").toggleClass("NB-feedlist-hide-read-feeds", !!hide_read_feeds);
    },
    
    count: function() {
        this.unread_counts = this.count_unreads_across_all_sites();
        this.feeds_count = this.count_feeds();
          
        if (NEWSBLUR.assets.preference('show_unread_counts_in_title')) {
            var title = '(';
            var counts = [];
            var unread_view = _.isNumber(this.options.unread_view) && this.options.unread_view || NEWSBLUR.assets.preference('unread_view');
            if (unread_view <= -1) {
                counts.push(this.unread_counts['negative']);
            }
            if (unread_view <= 0) {
                counts.push(this.unread_counts['neutral']);
            }
            if (unread_view <= 1) {
                counts.push(this.unread_counts['positive']);
            }
            if (!this.unread_counts['negative'] && !this.unread_counts['positive']) {
                counts = [this.unread_counts['neutral']];
            }
            title += counts.join('/') + ') NewsBlur';
            document.title = title;
        }
    },
    
    count_unreads_across_all_sites: function() {
        return this.collection.reduce(function(m, v) {
            if (v.get('active') && v.views && v.views.length) {
                m['positive'] += v.get('ps');
                m['neutral'] += v.get('nt');
                m['negative'] += v.get('ng');
            }
            return m;
        }, {'positive': 0, 'negative': 0, 'neutral': 0});
    },
    
    count_feeds: function() {
        return this.collection.select(function(f) {
            return f.get('active');
        }).length;
    },
    
    // ==========
    // = Events =
    // ==========
    
    show_splash_page: function() {
        NEWSBLUR.reader.show_splash_page();
    }

});