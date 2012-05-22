NEWSBLUR.Views.Feed = Backbone.View.extend({
    
    options: {
        depth: 0,
        selected: false
    },
    
    events: {
        "contextmenu"                    : "show_manage_menu",
        "click .NB-feedlist-manage-icon" : "show_manage_menu",
        "click"                          : "open",
        "mouseenter"                     : "add_hover_inverse_to_feed",
        "mouseleave"                     : "remove_hover_inverse_from_feed"
    },
    
    initialize: function() {
        _.bindAll(this, 'render', 'changed');
        this.model.bind('change', this.changed);
        
        if (this.model.is_social() && !this.model.get('feed_title')) {
            var profile = NEWSBLUR.assets.user_profiles.get(this.model.get('user_id')) || {};
            this.model.set('feed_title', profile.feed_title);
        }
    },
    
    destroy: function() {
        this.remove();
        this.model.unbind('change', this.changed);
    },
    
    changed: function(model, options) {
        var only_counts_changed = options.changes && !_.any(_.keys(options.changes), function(key) { 
            return !_.contains(['ps', 'nt', 'ng'], key);
        });
        
        if (only_counts_changed && !options.instant) {
            this.flash_changes();
            this.add_extra_classes();
        } else if (!only_counts_changed) {
            this.render();
        }
    },
    
    render: function() {
        var feed = this.model;
        var extra_classes = this.extra_classes();
        var $feed = $(_.template('\
        <<%= list_type %> class="feed <% if (selected) { %>selected<% } %> <%= extra_classes %> <% if (toplevel) { %>NB-toplevel<% } %>" data-id="<%= feed.id %>">\
          <div class="feed_counts">\
          </div>\
          <img class="feed_favicon" src="<%= $.favicon(feed) %>">\
          <span class="feed_title">\
            <%= feed.get("feed_title") %>\
            <% if (type == "story") { %>\
              <span class="NB-feedbar-train-feed" title="Train Intelligence"></span>\
              <span class="NB-feedbar-statistics" title="Statistics"></span>\
            <% } %>\
          </span>\
          <% if (type == "story") { %>\
            <div class="NB-feedbar-last-updated">\
              <span class="NB-feedbar-last-updated-label">Updated:</span>\
              <span class="NB-feedbar-last-updated-date">\
                <% if (feed.get("updated")) { %>\
                  <%= feed.get("updated") %> ago\
                <% } else { %>\
                  Loading...\
                <% } %>\
              </span>\
            </div>\
            <div class="NB-feedbar-mark-feed-read">Mark All as Read</div>\
          <% } %>\
          <div class="NB-feed-exception-icon"></div>\
          <div class="NB-feed-unfetched-icon"></div>\
          <div class="NB-feedlist-manage-icon"></div>\
          <div class="NB-feed-highlight"></div>\
        </<%= list_type %>>\
        ', {
          feed                : feed,
          type                : this.options.type,
          extra_classes       : extra_classes,
          toplevel            : this.options.depth == 0,
          list_type           : this.options.type == 'feed' ? 'li' : 'div',
          selected            : this.model.get('selected') || NEWSBLUR.reader.active_feed == this.model.id
        }));
        
        this.$el.replaceWith($feed);
        this.setElement($feed);
        this.render_counts();
        
        return this;
    },
    
    extra_classes: function() {
        var feed = this.model;
        var extra_classes = '';
        if (feed.get('ps')) {
            extra_classes += ' unread_positive';
        }
        if (feed.get('nt')) {
            extra_classes += ' unread_neutral';
        }
        if (feed.get('ng')) {
            extra_classes += ' unread_negative';
        }
        if (feed.get('has_exception') && feed.get('exception_type') == 'feed') {
            extra_classes += ' NB-feed-exception';
        }
        if (feed.get('not_yet_fetched') && !feed.get('has_exception')) {
            extra_classes += ' NB-feed-unfetched';
        }
        if (!feed.get('active') && !feed.get('subscription_user_id')) {
            extra_classes += ' NB-feed-inactive';
        }
        if (feed.get('subscription_user_id') && !feed.get('shared_stories_count')) {
            extra_classes += ' NB-feed-inactive';
        }
        return extra_classes;
    },
    
    render_counts: function() {
        this.counts_view = new NEWSBLUR.Views.FeedCount({model: this.model}).render();
        this.$('.feed_counts').html(this.counts_view.el);
    },
    
    flash_changes: function() {
        var $highlight = this.$('.NB-feed-highlight');
        console.log(["flash_changes", $highlight, this.el]);
        $highlight.css({
            'backgroundColor': '#F0F076',
            'display': 'block'
        });
        $highlight.animate({
            'opacity': .7
        }, {
            'duration': 800, 
            'queue': false, 
            'complete': function() {
                $highlight.animate({'opacity': 0}, {
                    'duration': 1000, 
                    'queue': false,
                    'complete': function() {
                        $highlight.css('display', 'none');
                    }
                });
            }
        });
    },
    
    add_extra_classes: function() {
        var extra_classes = this.extra_classes();
        $(this.el).removeClass("unread_positive unread_neutral unread_negative");
        $(this.el).addClass(extra_classes);
    },
    
    add_hover_inverse_to_feed: function() {
        if (NEWSBLUR.app.feed_list.is_sorting()) {
            return;
        }

        if (this.$el.offset().top > $(window).height() - 314) {
            this.$el.addClass('NB-hover-inverse');
        } 
    },
    
    remove_hover_inverse_from_feed: function() {
        this.$el.removeClass('NB-hover-inverse');
    },
    
    // ==========
    // = Events =
    // ==========
    
    open: function(e) {
        if (NEWSBLUR.hotkeys.command) {
            NEWSBLUR.reader.open_unread_stories_in_tabs(this.id);
        } else if (this.model.is_social()) {
            NEWSBLUR.reader.open_social_stories(this.model.id, {force: true, $feed_link: this.$el});
        } else {
            NEWSBLUR.reader.open_feed(this.model.id, {$feed_link: this.$el});
        }
    },
    
    show_manage_menu: function(e) {
        e.preventDefault();
        e.stopPropagation();
        // console.log(["showing manage menu", this.model.is_social() ? 'socialfeed' : 'feed', $(this.el), this]);
        NEWSBLUR.reader.show_manage_menu(this.model.is_social() ? 'socialfeed' : 'feed', $(this.el), {
            feed_id: this.model.id,
            toplevel: this.options.depth == 0
        });
        return false;
    }

});