NEWSBLUR.Views.FeedTitleView = Backbone.View.extend({
    
    options: {
        depth: 0,
        selected: false
    },
    
    flags: {},
    
    events: {
        "dblclick .feed_counts"                     : "dblclick_mark_feed_as_read",
        "dblclick"                                  : "open_feed_link",
        "click .NB-feedbar-mark-feed-read"          : "mark_feed_as_read",
        "click .NB-feedbar-mark-feed-read-time"     : "mark_feed_as_read_days",
        "click .NB-feedbar-mark-feed-read-expand"   : "expand_mark_read",
        "click .NB-feedbar-train-feed"              : "open_trainer",
        "click .NB-feedbar-statistics"              : "open_statistics",
        "click .NB-feedlist-manage-icon"            : "show_manage_menu",
        "click .NB-feedbar-options"                 : "open_options_popover",
        "click"                                     : "open",
        "mousedown"                                 : "highlight_event",
        "mouseenter"                                : "add_hover_inverse",
        "mouseleave"                                : "remove_hover_inverse"
    },
    
    initialize: function() {
        _.bindAll(this, 'render', 'delete_feed', 'changed', 'render_updated_time');
        if (!this.options.feed_chooser) {
            this.listenTo(this.model, 'change', this.changed);
            this.listenTo(this.model, 'change:updated', this.render_updated_time);
        } else {
            this.listenTo(this.model, 'change:highlighted', this.render);
        }
        
        if (this.model.is_social() && !this.model.get('feed_title')) {
            var profile = NEWSBLUR.assets.user_profiles.get(this.model.get('user_id')) || {};
            this.model.set('feed_title', profile.feed_title);
        }
    },
    
    changed: function(model, options) {
        options = options || {};
        var changes = _.keys(this.model.changedAttributes());
        
        var counts_changed = _.any(changes, function(key) { 
            return _.contains(['ps', 'nt', 'ng'], key);
        });
        var only_counts_changed = !_.any(changes, function(key) { 
            return !_.contains(['ps', 'nt', 'ng'], key);
        });
        var only_selected_changed = !_.any(changes, function(key) { 
            return key != 'selected';
        });

        if (only_counts_changed) {
            this.add_extra_classes();
            if (!options.instant) this.flash_changes();
        } else if (only_selected_changed) {
            this.select_feed(options);
        } else {
            this.render();
            if (!options.instant && counts_changed) this.flash_changes();
        }
    },
    
    remove: function() {
        if (this.counts_view) {
            this.counts_view.destroy();
        }
        if (this.search_view) {
            this.search_view.remove();
        }

        this.stopListening(this.model);
        Backbone.View.prototype.remove.call(this);
    },
    
    render: function() {
        var feed = this.model;
        var extra_classes = this.extra_classes();
        var $feed = $(_.template('<<%= list_type %> class="feed <% if (selected) { %>selected<% } %> <%= extra_classes %> <% if (highlighted) { %>NB-highlighted<% } %> <% if (toplevel) { %>NB-toplevel<% } %> <% if (disable_hover) { %>NB-no-hover<% } %>" data-id="<%= feed.id %>">\
          <div class="feed_counts">\
          </div>\
          <% if (type == "story") { %>\
              <div class="NB-search-container"></div>\
              <div class="NB-feedbar-options-container">\
                  <span class="NB-feedbar-options">\
                      <div class="NB-icon"></div>\
                      <%= NEWSBLUR.assets.view_setting(feed.id, "read_filter") %>\
                      &middot;\
                      <%= NEWSBLUR.assets.view_setting(feed.id, "order") %>\
                  </span>\
              </div>\
              <div class="NB-feedbar-mark-feed-read-container">\
                   <div class="NB-feedbar-mark-feed-read"><div class="NB-icon"></div></div>\
                   <div class="NB-feedbar-mark-feed-read-time" data-days="1">1d</div>\
                   <div class="NB-feedbar-mark-feed-read-time" data-days="3">3d</div>\
                   <div class="NB-feedbar-mark-feed-read-time" data-days="7">7d</div>\
                   <div class="NB-feedbar-mark-feed-read-time" data-days="14">14d</div>\
                   <div class="NB-feedbar-mark-feed-read-expand"></div>\
              </div>\
              <div class="NB-story-title-indicator">\
                  <div class="NB-story-title-indicator-count"></div>\
                  <span class="NB-story-title-indicator-text">show hidden stories</span>\
              </div>\
          <% } %>\
          <img class="feed_favicon" src="<%= $.favicon(feed) %>">\
          <span class="feed_title">\
            <%= feed.get("feed_title") %>\
          </span>\
          <div class="NB-feed-exception-icon"></div>\
          <div class="NB-feed-unfetched-icon"></div>\
          <div class="NB-feedlist-manage-icon"></div>\
          <div class="NB-feed-highlight"></div>\
          <% if (organizer) { %>\
              <div class="NB-feed-organizer-sort NB-feed-organizer-subscribers">\
                <%= pluralize("subscriber", feed.get("num_subscribers"), true) %>\
              </div>\
              <div class="NB-feed-organizer-sort NB-feed-organizer-laststory">\
                <%= feed.relative_last_story_date() %>\
              </div>\
              <div class="NB-feed-organizer-sort NB-feed-organizer-monthlycount">\
                <%= pluralize("story", feed.get("average_stories_per_month"), true) %>/month\
              </div>\
              <div class="NB-feed-organizer-sort NB-feed-organizer-opens">\
                <%= pluralize("open", feed.get("feed_opens"), true) %>\
              </div>\
          <% } %>\
        </<%= list_type %>>\
        ', {
          feed                : feed,
          type                : this.options.type,
          disable_hover       : this.options.disable_hover,
          extra_classes       : extra_classes,
          toplevel            : this.options.depth == 0,
          list_type           : this.options.type == 'feed' ? 'li' : 'div',
          selected            : this.model.get('selected'),
          highlighted         : this.options.feed_chooser &&
                                this.model.highlighted_in_folder(this.options.folder_title),
          organizer           : this.options.organizer,
          pluralize           : Inflector.pluralize
        }));
        
        if (this.options.type == 'story') {
            this.search_view = new NEWSBLUR.Views.FeedSearchView({
                feedbar_view: this
            }).render();
            $(".NB-search-container", $feed).html(this.search_view.$el);
        }

        this.$el.replaceWith($feed);
        this.setElement($feed);
        this.render_counts();
        this.setup_tooltips();
        this.render_updated_time();
        
        if (NEWSBLUR.reader.flags.search || NEWSBLUR.reader.flags.searching) {
            var $search = this.$("input[name=feed_search]");
            $search.focus();
        }
        
        this.$el.unbind('contextmenu')
                .bind('contextmenu', _.bind(this.show_manage_menu_rightclick, this));
        
        return this;
    },
    
    extra_classes: function() {
        var feed = this.model;
        var extra_classes = '';
        var starred_feed = NEWSBLUR.assets.starred_feeds.get_feed(feed.id);

        if (feed.get('ps')) {
            extra_classes += ' unread_positive';
        }
        if (feed.get('nt')) {
            extra_classes += ' unread_neutral';
        }
        if (feed.get('ng')) {
            extra_classes += ' unread_negative';
        }
        if ((starred_feed && starred_feed.get('count')) || feed.is_starred()) {
            extra_classes += ' unread_starred';
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
        if (this.counts_view) {
            this.counts_view.destroy();
        }
        this.counts_view = new NEWSBLUR.Views.UnreadCount({
            model: this.model,
            include_starred: true,
            feed_chooser: this.options.feed_chooser
        }).render();
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
    
    select_feed: function(options) {
        this.$el.toggleClass('selected', this.model.get('selected'));
        this.$el.toggleClass('NB-selected', this.model.get('selected'));
        
        _.each(this.folders, function(folder) {
            folder.view.update_hidden();
        });
    },
    
    flash_changes: function() {
        var $highlight = this.$('.NB-feed-highlight');
        $highlight.stop();
        $highlight.css({
            'backgroundColor': '#FED54A',
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
        $(this.el).removeClass("unread_positive unread_neutral unread_negative unread_starred");
        $(this.el).addClass(extra_classes);
    },
    
    // ==========
    // = Events =
    // ==========
    
    click: function(e) {
        this.highlight();
        this.open(e);
    },
    
    open: function(e, options) {
        options = options || {};
        if (this.options.feed_chooser && !options.ignore_feed_selector) return;
        if (this.options.type != 'feed') return;
        if (e.which >= 2) return;
        if (e.which == 1 && $('.NB-menu-manage-container:visible').length) return;

        if (!options.ignore_double_click && $(e.target).closest('.feed_counts').length) {
            _.delay(_.bind(function() {
                if (!this.flags.double_click) {
                    this.open(e, {ignore_double_click: true});
                }
            }, this), 250);
            return;
        }

        e.preventDefault();
        e.stopPropagation();

        if (this.model.get('has_exception') && this.model.get('exception_type') == 'feed') {
            NEWSBLUR.reader.open_feed_exception_modal(this.model.id);
        } else if (this.model.is_social()) {
            NEWSBLUR.reader.open_social_stories(this.model.id, {force: true, $feed: this.$el});
        } else if (this.model.is_starred()) {
            NEWSBLUR.reader.open_starred_stories({
                tag: this.model.tag_slug(),
                model: this.model,
                $feed: this.$el
            });
        } else {
            NEWSBLUR.reader.open_feed(this.model.id, {$feed: this.$el});
        }
    },
    
    highlight_event: function(e) {
        if (this.$el.hasClass('NB-feed-selector-active')) {
            return this.open(e, {'ignore_feed_selector': true});
        }
        return this.highlight();
    },
    
    highlight: function(on, off) {
        if (!this.options.feed_chooser) return;
        var model = this.model;
        
        if (this.options.organizer && this.options.hierarchy != 'flat') {
            model.highlight_in_folder(this.options.folder_title, on, off);
        } else {
            // Highlight all folders
            model.highlight_in_all_folders(on, off);
        }
        
        // Feed chooser disables binding to changes, so need to manually render.
        this.render();
    },
    
    open_feed_link: function(e) {
        e.preventDefault();
        e.stopPropagation();
        var dblclick_pref = NEWSBLUR.assets.preference('doubleclick_feed');
        if (dblclick_pref == "ignore") return;
        if (this.options.type == "story") return;
        if (this.options.starred_tag) return;
        if (this.options.feed_chooser) return;
        if ($('.NB-modal-feedchooser').is(':visible')) return;
        
        this.flags.double_click = true;
        _.delay(_.bind(function() {
            this.flags.double_click = false;
        }, this), 500);

        if (dblclick_pref == "open_and_read") {
            NEWSBLUR.reader.mark_feed_as_read(this.model.id);
        }

        if (this.model.get('feed_link')) {
            window.open(this.model.get('feed_link'), '_blank');
            window.focus();
        }
        
        return false;
    },
    
    dblclick_mark_feed_as_read: function(e) {
        if (this.options.feed_chooser) return;
        if (NEWSBLUR.assets.preference('doubleclick_unread') == "ignore") return;
        
        return this.mark_feed_as_read(e);
    },
    
    mark_feed_as_read: function(e, days) {
        if (this.options.starred_tag) return;
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }

        this.flags.double_click = true;
        _.delay(_.bind(function() {
            this.flags.double_click = false;
        }, this), 500);
        NEWSBLUR.reader.mark_feed_as_read(this.model.id, days);
        this.$('.NB-feedbar-mark-feed-read-container').fadeOut(400);
        if (e) {
            return false;
        }
    },
    
    mark_feed_as_read_days: function(e) {
        var days = parseInt($(e.target).data('days'), 10);
        this.mark_feed_as_read(e, days, true);
    },
    
    expand_mark_read: function() {
        var $container = this.$(".NB-feedbar-mark-feed-read-container");
        var $markread = this.$(".NB-feedbar-mark-feed-read");
        var $hidden = this.$(".NB-story-title-indicator");
        var $expand = this.$(".NB-feedbar-mark-feed-read-expand");
        var $times = this.$(".NB-feedbar-mark-feed-read-time");
        var times_count = $times.length;
        
        $hidden.hide();
        $markread.css('z-index', times_count+1);
        $container.css('margin-left', $times.eq(0).outerWidth(true) * (times_count - 1) + 12);
        $expand.animate({
            right: 0,
            opacity: 0
        }, {
            queue: false,
            easing: 'easeInQuint',
            duration: 180,
            complete: function() {
                $times.each(function(i) {
                    $(this).css('z-index', times_count - i);
                    $(this).animate({
                        right: (32 * (i + 1)) + 6
                    }, {
                        queue: false,
                        easing: 'easeOutBack',
                        duration: 280 + 100 * (Math.pow(i, 0.5))
                    });
                });
            }
        });
    },
    
    show_manage_menu_rightclick: function(e) {
        if (!NEWSBLUR.assets.preference('show_contextmenus')) return;
        
        return this.show_manage_menu(e);
    },
    
    show_manage_menu: function(e) {
        if (this.options.feed_chooser) return;
        
        var feed_type = this.model.is_social() ? 'socialfeed' : 
                        this.model.is_starred() ? 'starred' : 
                        'feed';
        e.preventDefault();
        e.stopPropagation();

        NEWSBLUR.reader.show_manage_menu(feed_type, this.$el, {
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
    
    open_options_popover: function() {
        NEWSBLUR.FeedOptionsPopover.create({
            anchor: this.$(".NB-feedbar-options"),
            feed_id: this.model.id
        });
    }
    
});