NEWSBLUR.Views.Folder = Backbone.View.extend({

    className: 'folder',
    
    tagName: 'li',
    
    options: {
        depth: 0,
        collapsed: false,
        title: '',
        root: false
    },
    
    events: {
        "click .NB-feedlist-manage-icon"            : "show_manage_menu",
        "click .folder_title"                       : "open",
        "click .NB-feedlist-collapse-icon"          : "collapse_folder",
        "click .NB-feedbar-mark-feed-read"          : "mark_folder_as_read",
        "click .NB-feedbar-mark-feed-read-expand"   : "expand_mark_read",
        "click .NB-feedbar-mark-feed-read-time"     : "mark_folder_as_read_days",
        "click .NB-feedbar-options"                 : "open_options_popover",
        "click .NB-story-title-indicator"           : "show_hidden_story_titles",
        "mousedown .folder_title"                   : "highlight_feeds",
        "mouseenter"                                : "add_hover_inverse",
        "mouseleave"                                : "remove_hover_inverse"
    },
    
    initialize: function() {
        _.bindAll(this, 'update_title', 'update_selected', 'delete_folder', 'check_collapsed',
                  'update_hidden');

        this.options.folder_title = this.options.folder_title || 
                                    (this.model && this.model.get('folder_title')) || "";

        if (this.model && !this.options.feed_chooser) {
            // Root folder does not have a model.
            this.model.bind('change:folder_title', this.update_title, this);
            this.model.bind('change:selected', this.update_selected, this);
            this.model.bind('change:selected', this.update_hidden, this);
            this.collection.bind('change:feed_selected', this.update_hidden, this);
            this.collection.bind('change:counts', this.update_hidden, this);
            this.model.bind('delete', this.delete_folder, this);
            if (!this.options.feedbar) {
                this.model.folder_view = this;
            }
        } else if (this.options.feed_chooser) {
            this.collection.sort();
        }
    },
    
    remove: function() {
        this.destroy();
    },
    
    destroy: function() {
        if (this.folder_count) {
            this.folder_count.destroy();
        }
        if (this.search_view) {
            this.search_view.remove();
        }
        if (this.model) {
            this.model.unbind(null, null, this);
            if (!this.options.feedbar) {
                this.model.folder_view = null;
            }
        }
        this.$el.empty().remove();
    },
    
    render: function() {
        var depth = this.options.depth;
        var folder_title = this.options.folder_title || "";
        var feed_chooser = this.options.feed_chooser;
        var organizer = this.options.organizer;
        var hierarchy = this.options.hierarchy;
        var sorting = this.options.sorting;
        var folder_collection = this.collection;
        this.options.collapsed =  folder_title && _.contains(NEWSBLUR.Preferences.collapsed_folders, folder_title);
        var $folder = this.render_folder();
        
        if (!this.options.only_title) {
            var $feeds = _.compact(this.collection.map(function(item) {
                if (item.is_feed()) {
                    if (!feed_chooser && !item.feed.get('active')) return;
                    var feed_title_view = _.detect(item.feed.views, function(view) {
                        if (view.options.feed_chooser == feed_chooser &&
                            view.options.folder_title == folder_title) {
                            return view;
                        }
                    });
                    if (!feed_title_view) {
                        feed_title_view = new NEWSBLUR.Views.FeedTitleView({
                            model: item.feed, 
                            type: 'feed',
                            depth: depth,
                            folder_title: folder_title,
                            folder: folder_collection,
                            feed_chooser: feed_chooser,
                            organizer: organizer,
                            hierarchy: hierarchy,
                            sorting: sorting
                        }).render();
                        item.feed.views.push(feed_title_view);
                        item.feed.folders.push(folder_collection);
                    } else {
                        // Reusing feed titles in chooser needs re-rendering to attach events
                        feed_title_view.render();
                    }
                    return feed_title_view.el; 
                } else if (item.is_folder()) {
                    // Reuse old feed views from previous choosers
                    var folder_view = _.detect(item.folder_views, function(view) {
                        if (view.options.feed_chooser == feed_chooser) {
                            return view;
                        }
                    });
                    if (!folder_view) {
                        folder_view = new NEWSBLUR.Views.Folder({
                            model: item,
                            collection: item.folders,
                            depth: depth + 1,
                            feed_chooser: feed_chooser,
                            organizer: organizer,
                            sorting: sorting
                        }).render();
                        item.folder_views.push(folder_view);
                    } else {
                        // Reusing folders need to be re-sorted
                        folder_view.collection.sort();
                        folder_view.render();
                    }
                    return folder_view.el;
                } else {
                    // console.log(["Not a feed or folder", item]);
                }
            }));
            $feeds.push($.make('li', { className: 'feed NB-empty' }));
            this.$('.folder').append($feeds);
        }
        
        this.check_collapsed({skip_animation: true});
        this.update_hidden();
        if (this.options.depth > 0) {
            // Only attach to visible folders. Top level has no folder, so wrongly attaches to first child.
            this.$('.folder_title').eq(0).bind('contextmenu', _.bind(this.show_manage_menu_rightclick, this));
        }
        
        return this;
    },
    
    render_folder: function($feeds) {
        var $folder = _.template('<<%= list_type %> class="folder NB-folder">\
        <% if (!root) { %>\
            <div class="folder_title <% if (depth <= 1) { %>NB-toplevel<% } %>">\
                <% if (feedbar) { %>\
                    <div class="NB-search-container"></div>\
                    <div class="NB-feedbar-options-container">\
                        <span class="NB-feedbar-options">\
                            <div class="NB-icon"></div>\
                            <%= NEWSBLUR.assets.view_setting("river:"+folder_title, "read_filter") %>\
                            &middot;\
                            <%= NEWSBLUR.assets.view_setting("river:"+folder_title, "order") %>\
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
                <div class="NB-folder-icon"></div>\
                <div class="NB-feedlist-collapse-icon" title="<% if (is_collapsed) { %>Expand Folder<% } else {%>Collapse Folder<% } %>"></div>\
                <div class="NB-feedlist-manage-icon"></div>\
                <span class="folder_title_text">\
                    <span><%= folder_title %></span>\
                </span>\
            </div>\
        <% } %>\
        <% if (!feedbar) { %>\
            <ul class="folder <% if (root) { %>NB-root<% } %>" <% if (is_collapsed) { %>style="display: none"<% } %>>\
            </ul>\
        <% } %>\
        </<%= list_type %>>\
        ', {
          depth         : this.options.depth,
          folder_title  : this.options.folder_title,
          is_collapsed  : this.options.collapsed && !this.options.feed_chooser,
          root          : this.options.root,
          feedbar       : this.options.feedbar,
          list_type     : this.options.feedbar ? 'div' : 'li'
        });

        this.$el.replaceWith($folder);
        this.setElement($folder);
        
        if (this.options.feedbar) {
            this.show_collapsed_folder_count();
            this.search_view = new NEWSBLUR.Views.FeedSearchView({
                feedbar_view: this
            }).render();
            this.$(".NB-search-container").html(this.search_view.$el);
            if (NEWSBLUR.reader.flags.searching) {
                this.search_view.focus_search();
                var $search = this.$("input[name=feed_search]");
                $search.focus();
            }
        }
        return $folder;
    },
    
    update_title: function() {
        this.$('.folder_title_text span').eq(0).html(this.model.get('folder_title'));
    },
    
    update_selected: function() {
        this.$el.toggleClass('NB-selected', this.model.get('selected'));
    },
    
    update_hidden: function() {
        if (!this.model) return;
        
        var has_unreads = this.model.has_unreads({include_selected: true});
        if (!has_unreads && NEWSBLUR.assets.preference('hide_read_feeds')) {
            this.$el.addClass('NB-hidden');
        } else {
            this.$el.removeClass('NB-hidden');
        }
    },
    
    // ===========
    // = Actions =
    // ===========
    
    check_collapsed: function(options) {
        options = options || {};
        var self = this;
        if (!this.options.folder_title || !this.options.folder_title.length) return;
        
        var show_folder_counts = NEWSBLUR.assets.preference('folder_counts');
        var collapsed = _.contains(NEWSBLUR.Preferences.collapsed_folders, this.options.folder_title);
        if (collapsed || show_folder_counts) {
            this.show_collapsed_folder_count(options);
        }
    },
    
    show_collapsed_folder_count: function(options) {
        options = options || {};
        var $folder_title = this.$('.folder_title').eq(0);
        var $counts = $('.feed_counts_floater', $folder_title);
        var $river = $('.NB-feedlist-collapse-icon', $folder_title);
        
        this.$el.addClass('NB-folder-collapsed');
        $counts.remove();

        if ($folder_title.hasClass('NB-hover')) {
            $river.animate({'opacity': 0}, {'duration': options.skip_animation ? 0 : 100});
            $folder_title.addClass('NB-feedlist-folder-title-recently-collapsed');
            $folder_title.one('mouseover', function() {
                $river.css({'opacity': ''});
                $folder_title.removeClass('NB-feedlist-folder-title-recently-collapsed');
            });
        }
        
        if (this.folder_count) {
            this.folder_count.destroy();
        }
        this.folder_count = new NEWSBLUR.Views.UnreadCount({
            collection: this.collection
        }).render();
        var $counts = this.folder_count.$el;
        if (this.options.feedbar) {
            this.$('.NB-story-title-indicator-count').html($counts.clone());
        } else {
            $folder_title.prepend($counts.css({
                'opacity': 0
            }));
        }
        $counts.animate({'opacity': 1}, {'duration': options.skip_animation ? 0 : 400});
    },
    
    hide_collapsed_folder_count: function() {
        var $folder_title = this.$('.folder_title').eq(0);
        var $counts = $('.feed_counts_floater', $folder_title);
        var $river = $('.NB-feedlist-collapse-icon', $folder_title);
        
        $counts.animate({'opacity': 0}, {
            'duration': 300 
        });
        
        $river.animate({'opacity': .6}, {'duration': 400});
        $folder_title.removeClass('NB-feedlist-folder-title-recently-collapsed');
        $folder_title.one('mouseover', function() {
            $river.css({'opacity': ''});
            $folder_title.removeClass('NB-feedlist-folder-title-recently-collapsed');
        });
    },
    
    // ==========
    // = Events =
    // ==========
   
    open: function(e) {
        if (this.options.feed_chooser) return;
        e.preventDefault();
        e.stopPropagation();
        var $folder = $(e.currentTarget).closest('li.folder');
        if ($folder[0] != this.el) return;
        if ($(e.currentTarget)[0] != this.$('.folder_title')[0]) return;
        if (e.which >= 2) return;
        if (e.which == 1 && $('.NB-menu-manage-container:visible').length) return;

        NEWSBLUR.reader.open_river_stories(this.$el, this.model);
    },
    
    show_manage_menu_rightclick: function(e) {
        if (!NEWSBLUR.assets.preference('show_contextmenus')) return;
        
        return this.show_manage_menu(e);
    },
    
    show_manage_menu: function(e) {
        if (this.options.feed_chooser) return;
        e.preventDefault();
        e.stopPropagation();

        NEWSBLUR.reader.show_manage_menu('folder', this.$el, {
            toplevel: this.options.depth == 0,
            folder_title: this.options.folder_title,
            rightclick: e.which >= 2
        });

        return false;
    },
    
    add_hover_inverse: function() {
        if (this.$el.offset().top > $(window).height() - 246) {
            this.$el.addClass('NB-hover-inverse');
        } 
    },
    
    remove_hover_inverse: function() {
        this.$el.removeClass('NB-hover-inverse');
    },
    
    delete_folder: function() {
        this.$el.slideUp(500);
        
        var feed_ids_in_folder = this.model.feed_ids_in_folder();
        if (_.contains(feed_ids_in_folder, NEWSBLUR.reader.active_feed)) {
            NEWSBLUR.reader.reset_feed();
            NEWSBLUR.reader.show_splash_page();
        }
    },
    
    collapse_folder: function(e, options) {
        e.preventDefault();
        e.stopPropagation();
        options = options || {};
        var self = this;
        var $children = this.$el.children('ul.folder');
        var $folder = $(e.currentTarget).closest('li.folder');
        if ($folder[0] != this.el) return;
        
        // Hiding / Collapsing
        if (options.force_collapse || 
            ($children.length && 
             $children.eq(0).is(':visible') && 
             !this.collection.collapsed)) {
            NEWSBLUR.log(["hiding folder", $children, this.collection, this.options.folder_title]);
            NEWSBLUR.assets.collapsed_folders(this.options.folder_title, true);
            this.collection.collapsed = true;
            this.$el.addClass('NB-folder-collapsed');
            $children.animate({'opacity': 0}, {
                'queue': false,
                'duration': options.force_collapse ? 0 : 200,
                'complete': function() {
                    self.show_collapsed_folder_count();
                    $children.slideUp({
                        'duration': 270,
                        'easing': 'easeOutQuart'
                    });
                }
            });
        } 
        // Showing / Expanding
        else if ($children.length && 
                   (this.collection.collapsed || !$children.eq(0).is(':visible'))) {
            NEWSBLUR.log(["showing folder", this.collection, this.options.folder_title]);
            NEWSBLUR.assets.collapsed_folders(this.options.folder_title, false);
            this.collection.collapsed = false;
            this.$el.removeClass('NB-folder-collapsed');
            if (!NEWSBLUR.assets.preference('folder_counts')) {
                this.hide_collapsed_folder_count();
            }
            $children.css({'opacity': 0}).slideDown({
                'duration': 240,
                'easing': 'easeInOutCubic',
                'complete': function() {
                    $children.animate({'opacity': 1}, {'queue': false, 'duration': 200});
                }
            });
        }
    },
    
    all_children_highlighted: function() {
        var folder_title = this.options.folder_title;
        var all_children_highlighted = this.collection.all(function(item) {
            if (item.is_feed()) {
                var view = _.any(item.feed.views, function(view) {
                    return view.options.feed_chooser &&
                           view.options.folder_title == folder_title;
                });
                
                if (!view) return true;

                return item.feed.highlighted_in_folder(folder_title);
            } else if (item.is_folder()) {
                return _.all(item.folder_views, function(view) { 
                    if (!view.options.feed_chooser) return true;
                    return view.all_children_highlighted(); 
                });
            }
            return true;
        });
        
        return all_children_highlighted;
    },
    
    highlighted_count_unique_folders: function() {
        var folder_title = this.options.folder_title;
        var count = this.collection.reduce(function(memo, item) {
            if (item.is_feed()) {
                var view = _.detect(item.feed.views, function(view) {
                    return view.options.feed_chooser &&
                           view.options.folder_title == folder_title;
                });
                
                if (!view) return memo;
                
                return item.feed.highlighted_in_folder(folder_title) ? memo + 1 : memo;
            } else {
                return memo + _.reduce(item.folder_views, function(m, view) {
                    if (!view.options.feed_chooser) return m;
                    return m + view.highlighted_count_unique_folders();
                }, 0);
            }
        }, 0);
        
        return count;
    },
    
    highlighted_count: function() {
        var count = NEWSBLUR.assets.feeds.reduce(function(memo, item) {
            var view = _.detect(item.views, function(view) {
                return view.options.feed_chooser;
            });
            
            if (!view) return memo;
            
            var folders = item.get('highlighted_in_folders');
            return (folders && folders.length) ? memo + 1 : memo;
        }, 0);
        
        return count;
    },
    
    highlight_feeds: function(options) {
        options = options || {};
        if (!this.options.feed_chooser) return;
        var $folder = options.currentTarget && $(options.currentTarget).closest('li.folder');
        if ($folder && $folder[0] != this.el) return;
        var all_children_highlighted = this.all_children_highlighted();
        if (options.force_highlight) all_children_highlighted = false;
        if (options.force_deselect) all_children_highlighted = true;
        var folder_title = this.options.folder_title;

        this.collection.each(function(item) {
            if (item.is_feed()) {
                var view = _.detect(item.feed.views, function(view) {
                    if (view.options.feed_chooser &&
                        view.options.folder_title == folder_title) {
                        return view;
                    }
                });
                
                if (!view) return;
                
                if (all_children_highlighted) {
                    view.highlight(false, true);
                } else {
                    view.highlight(true, false);
                }
            } else if (item.is_folder()) {
                _.each(item.folder_views, function(view) {
                    if (!all_children_highlighted) {
                        view.highlight_feeds({force_highlight: true});
                    } else {
                        view.highlight_feeds({force_deselect: options.force_deselect});
                    }
                });
            }
        });
    },
    
    highlighted_feeds: function(options, feeds) {
        if (!this.options.feed_chooser) return feeds;
        options = options || {};
        feeds = feeds || [];
        
        var folder_title = this.options.folder_title;
        var collection = options.collection || this.collection;
        
        // If using overridden collection, only use for root level. Used for organizer.
        if (options.collection) delete options.collection;
        
        collection.each(function(item) {
            if (item.is_feed() && item.feed.get('highlighted')) {
                if (_.contains(item.feed.get('highlighted_in_folders'), folder_title)) {
                    feeds.push([item.feed.id, folder_title]);
                }
            } else if (item.is_folder()) {
                _.each(item.folder_views, function(view) {
                    feeds = view.highlighted_feeds(options, feeds);
                });
            }
        });

        return feeds;
    },
    
    mark_folder_as_read: function(e, days_back) {
        NEWSBLUR.reader.mark_folder_as_read(this.model, days_back);
        this.$('.NB-feedbar-mark-feed-read-container').fadeOut(400);
    },

    mark_folder_as_read_days: function(e) {
        var days = parseInt($(e.target).data('days'), 10);
        this.mark_folder_as_read(e, days);
    },
    
    expand_mark_read: function() {
        NEWSBLUR.Views.FeedTitleView.prototype.expand_mark_read.call(this);
    },
    
    open_options_popover: function() {
        NEWSBLUR.FeedOptionsPopover.create({
            anchor: this.$(".NB-feedbar-options"),
            feed_id: "river:" + this.options.folder_title
        });
    },
    
    show_hidden_story_titles: function() {
        NEWSBLUR.app.story_titles_header.show_hidden_story_titles();
    }
    
});