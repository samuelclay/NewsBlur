NEWSBLUR.Views.StoryTitleView = Backbone.View.extend({
    
    className: 'story NB-story-title',
    
    events: {
        "click"                             : "select_story",
        "contextmenu"                       : "show_manage_menu",
        "click .NB-story-manage-icon"       : "show_manage_menu",
        "mouseenter .NB-story-manage-icon"  : "mouseenter_manage_icon",
        "mouseleave .NB-story-manage-icon"  : "mouseleave_manage_icon"
    },
    
    initialize: function() {
        this.model.bind('change', this.toggle_classes, this);
        this.model.bind('change:read_status', this.toggle_read_status, this);
        this.model.bind('change:selected', this.toggle_selected, this);
        this.model.bind('change:starred', this.toggle_starred, this);
        this.model.bind('change:intelligence', this.render, this);
        this.model.story_title_view = this;
    },
    
    render: function() {
        this.$el.html(this.render_to_string());
        this.toggle_classes();
        this.toggle_read_status();
        
        return this;
    },
    
    render_to_string: function() {
        var $story_title = _.template('\
            <div class="NB-storytitles-sentiment"></div>\
            <a href="<%= story.get("story_permalink") %>" class="story_title">\
                <% if (options.river_stories && feed) { %>\
                    <div class="NB-story-feed">\
                        <img class="feed_favicon" src="<%= $.favicon(feed) %>">\
                        <span class="feed_title"><%= feed.get("feed_title") %></span>\
                    </div>\
                <% } %>\
                <div class="NB-storytitles-star"></div>\
                <div class="NB-storytitles-share"></div>\
                <span class="NB-storytitles-title"><%= story.get("story_title") %></span>\
                <span class="NB-storytitles-author"><%= story.get("story_authors") %></span>\
                <% if (tag) { %>\
                    <span class="NB-storytitles-tags">\
                        <span class="NB-storytitles-tag"><%= tag %></span>\
                    </span>\
                <% } %>\
            </a>\
            <span class="story_date"><%= story.get("short_parsed_date") %></span>\
            <div class="NB-story-manage-icon"></div>\
        ', {
            story : this.model,
            feed  : this.options.river_stories && NEWSBLUR.assets.get_feed(this.model.get('story_feed_id')),
            tag   : _.first(this.model.get("story_tags")),
            options : this.options
        });
        
        return $story_title;
    },
    
    // ============
    // = Bindings =
    // ============

    toggle_classes: function() {
        var story = this.model;
        var unread_view = NEWSBLUR.assets.preference('unread_view');
        var score = story.score();

        this.$el.toggleClass('NB-story-starred', !!story.get('starred'));
        this.$el.toggleClass('NB-story-shared', !!story.get('shared'));
        this.$el.removeClass('NB-story-negative NB-story-neutral NB-story-postiive')
                .addClass('NB-story-'+story.score_name(score));

        if (unread_view > score) {
            this.$el.css('display', 'none');
        }

        if (NEWSBLUR.assets.preference('show_tooltips')) {
            this.$('.NB-story-sentiment').tipsy({
                delayIn: 375,
                gravity: 's'
            });
        }
    },
    
    toggle_read_status: function() {
        this.$el.toggleClass('read', !!this.model.get('read_status'));
    },
    
    toggle_selected: function(model, selected, options) {
        this.$el.toggleClass('NB-selected', !!this.model.get('selected'));
        
        if (this.model.get('selected')) {
            NEWSBLUR.app.story_titles.scroll_to_selected_story(this);
        }
    },
    
    toggle_starred: function() {
        var $star = this.$('.NB-storytitles-star');
        NEWSBLUR.app.story_titles.scroll_to_selected_story(this);
        
        if (this.model.get('starred')) {
            $star.attr({'title': 'Saved!'});
            $star.tipsy({
                gravity: 'sw',
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
            this.$el.one('mouseout', _.bind(function() {
                this.$el.removeClass('NB-unstarred');
            }, this));
            $star.attr({'title': 'Removed'});
        
            $star.tipsy({
                gravity: 'sw',
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
        e.preventDefault();
        this.model.set('selected', true, {'click_on_story_title': true});
        NEWSBLUR.reader.push_current_story_on_history();

        if (NEWSBLUR.hotkeys.command) {
            this.model.story_view.open_story_in_new_tab();
        }
    },

    show_manage_menu: function(e) {
        e.preventDefault();
        e.stopPropagation();
        // console.log(["showing manage menu", this.model.is_social() ? 'socialfeed' : 'feed', $(this.el), this]);
        NEWSBLUR.reader.show_manage_menu('story', this.$el, {
            story_id: this.model.id,
            feed_id: this.model.get('story_feed_id')
        });
        return false;
    },
    
    mouseenter_manage_icon: function() {
        var menu_height = 270;
        if (this.$el.offset().top > $(window).height() - menu_height) {
            this.$el.addClass('NB-hover-inverse');
        }
    },
    
    mouseleave_manage_icon: function() {
        this.$el.removeClass('NB-hover-inverse');
    }
        
});