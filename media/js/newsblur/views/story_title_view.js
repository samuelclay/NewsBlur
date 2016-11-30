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
        var template_name = !this.model.get('selected') && this.options.is_grid ? 
                            'grid_template' : 'template';
        // console.log(['render story title', template_name, this.$el[0], this.options.is_grid, this.show_image_preview()]);
        this.$el.html(this[template_name]({
            story    : this.model,
            feed     : (NEWSBLUR.reader.flags.river_view || NEWSBLUR.reader.flags.social_view) &&
                        NEWSBLUR.assets.get_feed(this.model.get('story_feed_id')),
            options  : this.options,
            show_content_preview : this.show_content_preview(),
            show_image_preview : this.show_image_preview()
        }));
        this.$st = this.$(".NB-story-title");
        this.toggle_classes();
        this.toggle_read_status();
        this.color_feedbar();
        this.load_youtube_embeds();
        var story_layout = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
        if (this.options.is_grid) this.watch_grid_image();
        if (_.contains(['list'], story_layout) && this.show_image_preview()) this.watch_grid_image();
        if (_.contains(['split'], story_layout) && this.show_image_preview() && NEWSBLUR.assets.preference('feed_view_single_story')) this.watch_grid_image();
        
        return this;
    },
                            
    template: _.template('\
        <div class="NB-story-title <% if (!show_content_preview) { %>NB-story-title-hide-preview<% } %> <% if (show_image_preview) { %>NB-has-image<% } %> ">\
            <div class="NB-storytitles-feed-border-inner"></div>\
            <div class="NB-storytitles-feed-border-outer"></div>\
            <div class="NB-storytitles-sentiment"></div>\
            <% if (show_image_preview) { %>\
                <div class="NB-storytitles-story-image-container">\
                    <div class="NB-storytitles-story-image"></div>\
                </div>\
            <% } %>\
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
                <span class="NB-storytitles-author"><%= story.story_authors() %></span>\
                <% if (show_content_preview) { %>\
                    <div class="NB-storytitles-content-preview"><%= show_content_preview %></div>\
                <% } %>\
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
    
    grid_template: _.template('\
        <div class="NB-story-title NB-story-grid <% if (!show_content_preview) { %>NB-story-title-hide-preview<% } %>">\
            <div class="NB-storytitles-feed-border-inner"></div>\
            <div class="NB-storytitles-feed-border-outer"></div>\
            <% if (story.image_url()) { %>\
                <div class="NB-storytitles-story-image-container">\
                    <div class="NB-storytitles-story-image"></div>\
                </div>\
            <% } %>\
            <div class="NB-storytitles-content">\
                <% if (feed) { %>\
                    <div class="NB-story-feed">\
                        <img class="feed_favicon" src="<%= $.favicon(feed) %>">\
                        <span class="feed_title"><%= feed.get("feed_title") %></span>\
                    </div>\
                <% } %>\
                <a href="<%= story.get("story_permalink") %>" class="story_title NB-hidden-fade">\
                    <div class="NB-storytitles-star"></div>\
                    <div class="NB-storytitles-share"></div>\
                    <div class="NB-storytitles-sentiment"></div>\
                    <div class="NB-story-manage-icon"></div>\
                    <span class="NB-storytitles-title"><%= story.get("story_title") %></span>\
                    <% if (show_content_preview) { %>\
                        <div class="NB-storytitles-content-preview"><%= show_content_preview %></div>\
                    <% } %>\
                </a>\
            </div>\
            <div class="NB-storytitles-grid-bottom">\
                <span class="NB-storytitles-author"><%= story.story_authors() %></span>\
                <span class="story_date NB-hidden-fade"><%= story.formatted_short_date() %></span>\
            </div>\
            <% if (story.get("comment_count_friends")) { %>\
                <div class="NB-storytitles-shares">\
                    <% _.each(story.get("commented_by_friends"), function(user_id) { %>\
                        <img class="NB-user-avatar" src="<%= NEWSBLUR.assets.user_profiles.find(user_id).get("photo_url") %>">\
                    <% }) %>\
                </div>\
            <% } %>\
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
            // console.log(['render_inline_story_detail', this.$(".NB-story-detail")]);
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
        // console.log(['render_intelligence', score, unread_view, this.model.get('visible'), this.model.get('story_title')]);
        
        if (score >= unread_view) {
            this.$st.removeClass('NB-hidden');
            this.model.set('visible', true);
        } else {
            this.$st.addClass('NB-hidden');
            this.model.set('visible', false);
        }
    },
    
    show_content_preview: function() {
        var preference = NEWSBLUR.assets.preference('show_content_preview');
        if (!preference) return preference;

        if (NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'grid') {
            return this.model.content_preview('story_content', 500) || " ";
        }
        var pruned_description = this.model.content_preview();
        var pruned_title = this.model.content_preview('story_title');
        
        if (pruned_title.substr(0, 30) == pruned_description.substr(0, 30)) return false;
        if (pruned_description.length < 30) return false;

        return pruned_description;
    },
    
    show_image_preview: function() {
        if (!NEWSBLUR.assets.preference('show_image_preview')) {
            return false;
        }

        var story_layout = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout');
        var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
        if (_.contains(['list', 'grid'], story_layout)) return true;
        if (story_layout == 'split' && _.contains(['north', 'south'], pane_anchor)) return true;

        return this.model.image_url();
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
    
    found_largest_image: function(image_url) {
        if (this.load_youtube_embeds()) {
            return;
        }

        this.$(".NB-storytitles-story-image").css({
            'background-image': "none, url(\'" + image_url + "\')",
            'display': 'block'
        });
    },
    
    watch_grid_image: function(index) {
        if (!index) index = 0;
        var self = this;
        if (!index && this.load_youtube_embeds()) {
            return;
        }
        if (!this.model.image_url(index)) {
            // console.log(["no more image urls", index, this.model.get('story_title').substr(0, 30)]);
            return;
        }
        // console.log(["watch_grid_image", index, this.model.image_url(index), this.model.get('story_title').substr(0, 30)]);
        // this.model == NEWSBLUR.assets.stories.at(5) && console.log(["Watching images", index, this.model.image_url(index), this.model.get('story_title').substr(0, 30)]);
        var $img = $("<img>");
        $img.imagesLoaded(function() {
            // console.log(["Loaded", index, $img[0].width, $img.attr('src'), self.model.get('story_title').substr(0, 30)]);
            if ($img[0].width > 60 && $img[0].height > 60) {
                self.$(".NB-storytitles-story-image").css({
                    'background-image': "none, url(\'" + $img.attr('src') + "\')",
                    'display': 'block'
                });
            } else {
                self.watch_grid_image(index+1);
            }
        }).attr('src', this.model.image_url(index)).each(function() {
            // fail-safe for cached images which sometimes don't trigger "load" events
            if (this.complete) $(this).load();
        });
    },
    
    select_regex: function(query, url) {
        if (url == null) {
            return;
        }
        var results = query.exec(url);
        if (results && results.length) {
            return results[1];
        } else {
            return;
        }
    },
    
    load_youtube_embeds: function() {
        var text = this.model.get('story_content');
        var g = /youtube\.com\/embed\/([A-Za-z0-9\-_]+)/gi;
        var f = /youtube\.com\/v\/([A-Za-z0-9\-_]+)/gi;
        var e = /ytimg\.com\/vi\/([A-Za-z0-9\-_]+)/gi;
        var d = /youtube\.com\/watch\?v=([A-Za-z0-9\-_]+)/gi;
        var i = this.select_regex(g, text) || 
                this.select_regex(f, text) || 
                this.select_regex(e, text) || 
                this.select_regex(d, text);
        if (i) {
            this.$(".NB-storytitles-story-image").css({
                'display': 'block',
                'background-image': "url("+NEWSBLUR.Globals.MEDIA_URL+"img/reader/youtube_play.png), url(" + "http://img.youtube.com/vi/" + i + "/0.jpg" + ")"
            });
            return true;
        }
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
            $star.stop().css('opacity', null);
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
                _.delay(function() {
                    if (tipsy.enabled) {
                        tipsy.hide();
                        tipsy.disable();
                    }
                }, 1800);
            });
        }
    },
    
    toggle_selected: function(model, selected, options) {
        if (this.options.is_grid) this.render();
        
        this.$st.toggleClass('NB-selected', !!this.model.get('selected'));
        this.$el.toggleClass('NB-selected', !!this.model.get('selected'));
        
        if (!!this.model.get('selected')) {
            if (_.contains(['list', 'grid'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                this.render_inline_story_detail();
            } else {
                this.destroy_inline_story_detail();
            }
            // NEWSBLUR.app.story_titles.scroll_to_selected_story(this.model, options);
        } else {
            this.destroy_inline_story_detail();
        }
    },
    
    toggle_starred: function() {
        var story_titles_visible = _.contains(['split', 'full'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'));
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
        
        if (_.contains(['list', 'grid'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout')) &&
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
        NEWSBLUR.app.story_tab_view.prepare_story(this.model, true);
        NEWSBLUR.app.story_tab_view.open_story(this.model);
        return false;
    }
        
});
