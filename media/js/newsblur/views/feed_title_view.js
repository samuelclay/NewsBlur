NEWSBLUR.Views.FeedTitleView = Backbone.View.extend({
    
    options: {
        depth: 0,
        selected: false
    },
    
    events: {
        "click .NB-feedbar-train-feed"      : "open_trainer",
        "click .NB-feedbar-statistics"      : "open_statistics",
        "click .NB-feedbar-settings"        : "open_settings",
        "click .NB-feedlist-manage-icon"    : "show_manage_menu",
        "dblclick"                          : "open_feed_link",
        "click"                             : "open",
        "mouseenter"                        : "add_hover_inverse",
        "mouseleave"                        : "remove_hover_inverse"
    },
    
    initialize: function() {
        _.bindAll(this, 'render', 'delete_feed');
        if (!this.options.feed_chooser) {
            this.model.bind('change', this.changed, this);
            this.model.bind('change:updated', this.render_updated_time, this);
        }
        
        if (this.model.is_social() && !this.model.get('feed_title')) {
            var profile = NEWSBLUR.assets.user_profiles.get(this.model.get('user_id')) || {};
            this.model.set('feed_title', profile.feed_title);
        }
    },
    
    destroy: function() {
        this.$el.empty();
        this.model.unbind(null, this);
    },
    
    changed: function(model, options) {
        var counts_changed = options.changes && _.any(_.keys(options.changes), function(key) { 
            return _.contains(['ps', 'nt', 'ng'], key);
        });
        var only_counts_changed = options.changes && !_.any(_.keys(options.changes), function(key) { 
            return !_.contains(['ps', 'nt', 'ng'], key);
        });
        var only_selected_changed = options.changes && !_.any(_.keys(options.changes), function(key) { 
            return key != 'selected';
        });
        
        if (only_counts_changed) {
            this.add_extra_classes();
            if (!options.instant) this.flash_changes();
        } else if (only_selected_changed) {
            this.select_feed();
        } else {
            this.render();
            if (!options.instant && counts_changed) this.flash_changes();
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
            <% if (type == "story") { %>\
                <div class="NB-story-title-indicator">\
                    <div class="NB-story-title-indicator-count"></div>\
                    <span class="NB-story-title-indicator-text">show hidden stories</span>\
                </div>\
            <% } %>\
            <%= feed.get("feed_title") %>\
            <% if (type == "story") { %>\
                <span class="NB-feedbar-settings" title="Site settings"></span>\
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
        this.setup_tooltips();
        this.render_updated_time();
        
        this.$el.bind('contextmenu', _.bind(this.show_manage_menu, this));
        
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

        if (feed.is_feed()) {
            if (feed.get('has_exception') && feed.get('exception_type') == 'feed') {
                extra_classes += ' NB-feed-exception';
            }
            if (!feed.get('fetched_once') && !feed.get('has_exception')) {
                extra_classes += ' NB-feed-unfetched';
            }
            if (!feed.get('active') && !feed.get('subscription_user_id')) {
                extra_classes += ' NB-feed-inactive';
            }
        }
        
        if (feed.is_social()) {
            extra_classes += ' NB-feed-social';
            if (feed.get('subscription_user_id') && !feed.get('shared_stories_count')) {
                extra_classes += ' NB-feed-inactive';
            }
            if (feed.get('subscription_user_id') == NEWSBLUR.Globals.user_id) {
                extra_classes += ' NB-feed-self-blurblog';
            }
        }
        
        return extra_classes;
    },
    
    render_counts: function() {
        this.counts_view = new NEWSBLUR.Views.FeedCount({model: this.model}).render();
        this.$('.feed_counts').html(this.counts_view.el);
        if (this.options.type == 'story') {
            this.$('.NB-story-title-indicator-count').html(this.counts_view.$el.clone());
        }
    },
    
    setup_tooltips: function() {
        if (this.options.type == 'story' && NEWSBLUR.assets.preference('show_tooltips')) {
            this.$('.NB-feedbar-train-feed, .NB-feedbar-statistics').tipsy({
                gravity: 's',
                delayIn: 375
            });
        }
    },
    
    render_updated_time: function() {
        if (this.options.type == 'story') {
            var updated_text = this.model.get('updated') ? 
                               this.model.get('updated') + ' ago' : 
                               'Loading...';
            this.$('.NB-feedbar-last-updated-date').text(updated_text);
        }
    },
    
    select_feed: function() {
        this.$el.toggleClass('selected', this.model.get('selected'));
        this.$el.toggleClass('NB-selected', this.model.get('selected'));
    },
    
    flash_changes: function() {
        var $highlight = this.$('.NB-feed-highlight');

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
    
    // ===========
    // = Actions =
    // ===========
    
    
    // ==========
    // = Events =
    // ==========
    
    open: function(e) {
        if (this.options.feed_chooser) return;
        if (this.options.type != 'feed') return;
        if (e.which >= 2) return;
        if (e.which == 1 && $('.NB-menu-manage-container:visible').length) return;
        
        if (this.model.get('has_exception') && this.model.get('exception_type') == 'feed') {
            NEWSBLUR.reader.open_feed_exception_modal(this.model.id);
        } else if (this.model.is_social()) {
            NEWSBLUR.reader.open_social_stories(this.model.id, {force: true, $feed: this.$el});
        } else {
            NEWSBLUR.reader.open_feed(this.model.id, {$feed: this.$el});
        }
    },
    
    open_feed_link: function() {
        if ($('.NB-modal-feedchooser').is(':visible')) return;
        
        NEWSBLUR.reader.mark_feed_as_read(this.model.id);
        window.open(this.model.get('feed_link'), '_blank');
        window.focus();
    },
    
    show_manage_menu: function(e) {
        if (this.options.feed_chooser) return;
        e.preventDefault();
        e.stopPropagation();
        NEWSBLUR.log(["showing manage menu", this.model.is_social() ? 'socialfeed' : 'feed', $(this.el), this, e.which, e.button]);
        NEWSBLUR.reader.show_manage_menu(this.model.is_social() ? 'socialfeed' : 'feed', this.$el, {
            feed_id: this.model.id,
            toplevel: this.options.depth == 0,
            rightclick: e.which >= 2
        });
        return false;
    },
    
    delete_feed: function() {
        this.$el.slideUp(500);
        
        if (this.model.get('selected')) {
            NEWSBLUR.reader.reset_feed();
            NEWSBLUR.reader.show_splash_page();
        }
    },
    
    add_hover_inverse: function() {
        if (NEWSBLUR.app.feed_list.is_sorting()) {
            return;
        }

        if (this.$el.offset().top > $(window).height() - 334) {
            this.$el.addClass('NB-hover-inverse');
        } 
    },
    
    remove_hover_inverse: function() {
        this.$el.removeClass('NB-hover-inverse');
    },
    
    open_trainer: function() {
        if (!$('.NB-task-manage').hasClass('NB-disabled')) {
            NEWSBLUR.reader.open_feed_intelligence_modal(1, null, !NEWSBLUR.reader.flags.social_view);
        }
    },
    
    open_statistics: function() {
        NEWSBLUR.reader.open_feed_statistics_modal();
    },
    
    open_settings: function(e) {
        this.show_manage_menu(e);
    }

});