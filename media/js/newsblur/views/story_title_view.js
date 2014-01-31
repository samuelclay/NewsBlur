NEWSBLUR.Views.StoryTitleView = Backbone.View.extend({
    
    className: 'NB-story-title-container',
    
    events: {
        "dblclick .NB-story-title"      : "open_story_in_story_view",
        "click .NB-story-title"         : "select_story",
        "contextmenu .NB-story-title"   : "show_manage_menu_rightclick",
        "click .NB-story-manage-icon"   : "show_manage_menu",
        "click .NB-storytitles-shares"  : "select_story_shared",
        "mouseenter .NB-story-title"    : "mouseenter_manage_icon",
        "mouseleave .NB-story-title"    : "mouseleave_manage_icon"
    },
    
    initialize: function() {
        this.model.bind('change', this.toggle_classes, this);
        this.model.bind('change:read_status', this.toggle_read_status, this);
        this.model.bind('change:selected', this.toggle_selected, this);
        this.model.bind('change:starred', this.toggle_starred, this);
        this.model.bind('change:intelligence', this.toggle_intelligence, this);
        this.collection.bind('render:intelligence', this.render_intelligence, this);
        this.model.story_title_view = this;
    },
    
    render: function() {
        this.$el.html(this.template({
            story    : this.model,
            feed     : (NEWSBLUR.reader.flags.river_view || NEWSBLUR.reader.flags.social_view) &&
                        NEWSBLUR.assets.get_feed(this.model.get('story_feed_id')),
            options  : this.options
        }));
        this.$st = this.$(".NB-story-title");
        this.toggle_classes();
        this.toggle_read_status();
        this.color_feedbar();
        
        return this;
    },
    
    template: _.template('\
        <div class="NB-story-title">\
            <div class="NB-storytitles-feed-border-inner"></div>\
            <div class="NB-storytitles-feed-border-outer"></div>\
            <div class="NB-storytitles-sentiment"></div>\
            <a href="<%= story.get("story_permalink") %>" class="story_title NB-hidden-fade">\
                <% if (feed) { %>\
                    <div class="NB-story-feed">\
                        <img class="feed_favicon" src="<%= $.favicon(feed) %>">\
                        <span class="feed_title"><%= feed.get("feed_title") %></span>\
                    </div>\
                <% } %>\
                <div class="NB-storytitles-star"></div>\
                <div class="NB-storytitles-share"></div>\
                <span class="NB-storytitles-title"><%= story.get("story_title") %></span>\
                <span class="NB-storytitles-author"><%= story.get("story_authors") %></span>\
            </a>\
            <span class="story_date NB-hidden-fade"><%= story.formatted_short_date() %></span>\
            <% if (story.get("comment_count_friends")) { %>\
                <div class="NB-storytitles-shares">\
                    <% _.each(story.get("commented_by_friends"), function(user_id) { %>\
                        <img class="NB-user-avatar" src="<%= NEWSBLUR.assets.user_profiles.find(user_id).get("photo_url") %>">\
                    <% }) %>\
                </div>\
            <% } %>\
            <div class="NB-story-manage-icon"></div>\
        </div>\
        <div class="NB-story-detail"></div>\
    '),
    
    render_inline_story_detail: function(temporary_text) {
        if (NEWSBLUR.reader.story_view == 'text' || temporary_text) {
            this.text_view = new NEWSBLUR.Views.TextTabView({
                el: null,
                inline_story_title: true,
                temporary: !!temporary_text
            });
            this.text_view.fetch_and_render(this.model, temporary_text);
            this.$(".NB-story-detail").html(this.text_view.$el);
            this.text_view.story_detail.render_starred_tags();
        } else {
            this.story_detail = new NEWSBLUR.Views.StoryDetailView({
                model: this.model,
                collection: this.model.collection,
                tagName: 'div',
                inline_story_title: true
            }).render();
            this.$(".NB-story-detail").html(this.story_detail.$el);
            this.story_detail.attach_handlers();
        }
    },
    
    destroy: function() {
        // console.log(["destroy story title", this.model.get('story_title')]);
        if (this.text_view) {
            this.text_view.destroy();
        }
        if (this.story_detail) {
            this.story_detail.destroy();
        }
        this.model.unbind(null, null, this);
        this.collection.unbind(null, null, this);
        this.remove();
    },
    
    destroy_inline_story_detail: function() {
        if (this.story_detail) {
            this.story_detail.destroy();
        }
        if (this.text_view) {
            this.text_view.destroy();
        }
        // this.$(".NB-story-detail").empty();
    },
    
    collapse_story: function() {
        this.model.set('selected', false);
        NEWSBLUR.app.story_titles.fill_out();
    },
    
    render_intelligence: function(options) {
        options = options || {};
        var score = this.model.score();
        var unread_view = NEWSBLUR.reader.get_unread_view_score();
        
        if (score >= unread_view || this.model.get('visible')) {
            this.$st.removeClass('NB-hidden');
            this.model.set('visible', true);
        } else {
            this.$st.addClass('NB-hidden');
        }
    },
    
    // ============
    // = Bindings =
    // ============
    
    color_feedbar: function() {
        var $inner = this.$st.find(".NB-storytitles-feed-border-inner");
        var $outer = this.$st.find(".NB-storytitles-feed-border-outer");
        var feed = NEWSBLUR.assets.get_feed(this.model.get('story_feed_id'));
        if (!feed) return;
        
        $inner.css('background-color', '#' + feed.get('favicon_fade'));
        $outer.css('background-color', '#' + feed.get('favicon_color'));
    },
    
    toggle_classes: function() {
        var changes = this.model.changedAttributes();
        
        if (changes && _.all(_.keys(changes), function(change) { 
            return _.contains(['intelligence', 'read_status', 'selected'], change);
        })) return;
        
        var story = this.model;
        var unread_view = NEWSBLUR.reader.get_unread_view_score();

        this.$st.toggleClass('NB-story-starred', !!story.get('starred'));
        this.$st.toggleClass('NB-story-shared', !!story.get('shared'));
        this.toggle_intelligence();
        this.render_intelligence();
        
        if (NEWSBLUR.assets.preference('show_tooltips')) {
            this.$('.NB-story-sentiment').tipsy({
                delayIn: 375,
                gravity: 's'
            });
        }
    },
    
    toggle_intelligence: function() {
        var score = this.model.score();
        this.$st.removeClass('NB-story-negative NB-story-neutral NB-story-postiive')
                .addClass('NB-story-'+this.model.score_name(score));
    },
    
    toggle_read_status: function(model, read_status, options) {
        options = options || {};
        this.$st.toggleClass('read', !!this.model.get('read_status'));
        
        if (options.error_marking_unread) {
            var pane_alignment = NEWSBLUR.assets.preference('story_pane_anchor');
            var $star = this.$('.NB-storytitles-sentiment');

            $star.attr({'title': options.message || 'Failed to mark as unread'});
            $star.tipsy({
                gravity: pane_alignment == 'north' ? 'nw' : 'sw',
                fade: true,
                trigger: 'manual',
                offsetOpposite: -1
            });
            var tipsy = $star.data('tipsy');
            _.defer(function() {
                tipsy.enable();
                tipsy.show();
            });

            $star.animate({
                'opacity': 1
            }, {
                'duration': 1850,
                'queue': false,
                'complete': function() {
                    if (tipsy.enabled) {
                        tipsy.hide();
                        tipsy.disable();
                    }
                }
            });

        }
    },
    
    toggle_selected: function(model, selected, options) {
        this.$st.toggleClass('NB-selected', !!this.model.get('selected'));
        
        if (selected) {
            if (NEWSBLUR.assets.preference('story_layout') == 'list') {
                this.render_inline_story_detail();
            }
            NEWSBLUR.app.story_titles.scroll_to_selected_story(this.model, options);
        } else {
            this.destroy_inline_story_detail();
        }
    },
    
    toggle_starred: function() {
        var story_titles_visible = _.contains(['split', 'full'], NEWSBLUR.assets.preference('story_layout'));
        var pane_alignment = NEWSBLUR.assets.preference('story_pane_anchor');
        var $star = this.$('.NB-storytitles-star');
        
        if (story_titles_visible) {
            NEWSBLUR.app.story_titles.scroll_to_selected_story(this.model);
        }
        
        if (this.model.get('starred')) {
            $star.attr({'title': 'Saved!'});
            $star.tipsy({
                gravity: pane_alignment == 'north' ? 'nw' : 'sw',
                fade: true,
                trigger: 'manual',
                offsetOpposite: -1
            });
            var tipsy = $star.data('tipsy');
            _.defer(function() {
                tipsy.enable();
                tipsy.show();
            });

            $star.animate({
                'opacity': 1
            }, {
                'duration': 850,
                'queue': false,
                'complete': function() {
                    if (tipsy.enabled) {
                        tipsy.hide();
                        tipsy.disable();
                    }
                }
            });
        } else {
            this.$st.one('mouseout', _.bind(function() {
                this.$st.removeClass('NB-unstarred');
            }, this));
            $star.attr({'title': 'Removed'});
        
            $star.tipsy({
                gravity: pane_alignment == 'north' ? 'nw' : 'sw',
                fade: true,
                trigger: 'manual',
                offsetOpposite: -1
            });
            var tipsy = $star.data('tipsy');
            tipsy.enable();
            tipsy.show();

            _.delay(function() {
                if (tipsy.enabled) {
                    tipsy.hide();
                    tipsy.disable();
                }
            }, 850);
        
        }
    },
        
    // ==========
    // = Events =
    // ==========
    
    select_story: function(e) {
        if (NEWSBLUR.hotkeys.shift) return;
        
        e.preventDefault();
        e.stopPropagation();
        if (e.which == 1 && $('.NB-menu-manage-container:visible').length) return;
        
        if (NEWSBLUR.assets.preference('story_layout') == 'list' &&
            this.model.get('selected')) {
            this.collapse_story();
        } else {
            this.model.set('selected', true, {'click_on_story_title': true});
        }

        if (NEWSBLUR.hotkeys.command) {
            this.model.open_story_in_new_tab(true);
        }
    },
    
    select_story_shared: function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        this.model.set('selected', true, {'click_on_story_title': true});
        if (NEWSBLUR.reader.story_view == 'page') {
            NEWSBLUR.reader.switch_taskbar_view('feed', {skip_save_type: 'page'});
        }

        NEWSBLUR.app.story_list.scroll_to_selected_story(this.model, {
            scroll_to_comments: true,
            scroll_offset: -50
        });
    },
    
    show_manage_menu_rightclick: function(e) {
        if (!NEWSBLUR.assets.preference('show_contextmenus')) return;
        
        return this.show_manage_menu(e);
    },
    
    show_manage_menu: function(e) {
        e.preventDefault();
        e.stopPropagation();
        // NEWSBLUR.log(["showing manage menu", this.model.is_social() ? 'socialfeed' : 'feed', $(this.el), this]);
        NEWSBLUR.reader.show_manage_menu('story', this.$st, {
            story_id: this.model.id,
            feed_id: this.model.get('story_feed_id'),
            rightclick: e.which >= 2
        });
        return false;
    },
    
    mouseenter_manage_icon: function() {
        var menu_height = 270;
        // console.log(["mouseenter_manage_icon", this.$el.offset().top, $(window).height(), menu_height]);
        if (this.$el.offset().top > $(window).height() - menu_height) {
            this.$st.addClass('NB-hover-inverse');
        }
    },
    
    mouseleave_manage_icon: function() {
        this.$st.removeClass('NB-hover-inverse');
    },
    
    open_story_in_story_view: function(e) {
        e.preventDefault();
        e.stopPropagation();
        NEWSBLUR.app.story_tab_view.open_story(this.model, true);
        return false;
    }
        
});