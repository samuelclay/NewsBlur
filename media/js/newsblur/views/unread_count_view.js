NEWSBLUR.Views.UnreadCount = Backbone.View.extend({
    
    className: 'feed_counts_floater',
    
    initialize: function() {
        _.bindAll(this, 'render');
        if (!this.options.stale && !this.options.feed_chooser) {
            if (this.model) {
                var starred_feed = NEWSBLUR.assets.starred_feeds.get_feed(this.model.id);
                if (starred_feed) {
                    starred_feed.bind('change:count', this.render, this);
                }
                this.model.bind('change:ps', this.render, this);
                this.model.bind('change:nt', this.render, this);
                this.model.bind('change:ng', this.render, this);
                this.model.bind('change:active', this.render, this);
            } else if (this.collection) {
                this.collection.bind('change:counts', this.render, this);
            }
        }
    },
    
    // ==========
    // = Render =
    // ==========
    
    render: function() {
        var unread_class = "";
        var counts;
        var muted = false;
        if (this.model) {
            counts = this.model.unread_counts();
            if (!this.model.get('active')) muted = true;
        } else if (this.collection) {
            counts = this.collection.unread_counts();
        }

        if (counts['ps']) {
            unread_class += ' unread_positive';
        }
        if (counts['nt']) {
            unread_class += ' unread_neutral';
        }
        if (counts['ng']) {
            unread_class += ' unread_negative';
        }
        if ((counts['st'] && this.options.include_starred) || (this.model && this.model.is_starred())) {
            unread_class += ' unread_starred';
        }
        if (muted) {
            unread_class += ' NB-muted-count';
        }
        
        this.$el.html(this.template({
          ps           : this.options.feed_chooser ? "On" : counts['ps'],
          nt           : counts['nt'],
          ng           : this.options.feed_chooser ? "Off" : counts['ng'],
          muted        : muted,
          st           : this.options.include_starred && counts['st'],
          unread_class : unread_class
        }));
        
        return this;
    },
    
    destroy: function() {
        if (this.model) {
            this.model.unbind(null, null, this);
        } else if (this.collection) {
            this.collection.unbind(null, null, this);
        }
        this.remove();
    },
    
    template: _.template('\
        <div class="<%= unread_class %>">\
          <span class="unread_count unread_count_positive <% if (ps) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= ps %>\
          </span>\
          <span class="unread_count unread_count_neutral <% if (nt) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= nt %>\
          </span>\
          <span class="unread_count unread_count_negative <% if (ng) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= ng %>\
          </span>\
          <% if (muted) { %>\
              <span class="NB-muted-icon"></span>\
          <% } %>\
          <% if (st) { %>\
              <span class="unread_count unread_count_starred <% if (st) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
                <%= st %>\
              </span>\
          <% } %>\
        </div>\
    '),
    
    // ===========
    // = Actions =
    // ===========
    
    center: function() {
        var count_width = this.$el.width();
        var left_buttons_offset = $('.NB-taskbar-view').outerWidth(true);
        var right_buttons_offset = $(".NB-taskbar-options-container").position().left;
        var usable_space = right_buttons_offset - left_buttons_offset;
        var left = (usable_space / 2) - (count_width / 2) + left_buttons_offset;
        
        // console.log(["Unread count offset", count_width, left, left_buttons_offset, right_buttons_offset]);
        
        if (count_width + 12 > usable_space) {
            this.$el.hide();
        }
        
        this.$el.css({'left': left});
    },
    
    flash: function() {
        var $floater = this.$el;
        
        if (!NEWSBLUR.assets.preference('animations')) return;
        
        _.defer(function() {
            $floater.animate({'opacity': 1}, {'duration': 250, 'queue': false});
            _.delay(function() {
                $floater.animate({'opacity': .2}, {'duration': 250, 'queue': false});
            }, 400);
        });        
    }
    
});