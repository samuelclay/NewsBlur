NEWSBLUR.Views.StoryTitleView = Backbone.View.extend({
    
    className: 'story NB-story-title',
    
    events: {
        "dblclick"                      : "open_story_in_story_view",
        "click"                         : "select_story",
        "contextmenu"                   : "show_manage_menu",
        "click .NB-story-manage-icon"   : "show_manage_menu",
        "mouseenter"                    : "mouseenter_manage_icon",
        "mouseleave"                    : "mouseleave_manage_icon"
    },
    
    initialize: function() {
        this.model.bind('change', this.toggle_classes, this);
        this.model.bind('change:read_status', this.toggle_read_status, this);
        this.model.bind('change:selected', this.toggle_selected, this);
        this.model.bind('change:starred', this.toggle_starred, this);
        this.model.bind('change:intelligence', this.toggle_intelligence, this);
        this.model.story_title_view = this;
    },
    
    render: function() {
        this.$el.html(this.template({
            story    : this.model,
            feed     : NEWSBLUR.reader.flags.river_view && NEWSBLUR.assets.get_feed(this.model.get('story_feed_id')),
            tag      : _.first(this.model.get("story_tags")),
            options  : this.options
        }));
        this.toggle_classes();
        this.toggle_read_status();
        
        return this;
    },
    
    template: _.template('\
        <div class="NB-storytitles-sentiment"></div>\
        <a href="<%= story.get("story_permalink") %>" class="story_title">\
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
            <% if (tag) { %>\
                <span class="NB-storytitles-tags">\
                    <span class="NB-storytitles-tag"><%= tag %></span>\
                </span>\
            <% } %>\
        </a>\
        <span class="story_date"><%= story.get("short_parsed_date") %></span>\
        <div class="NB-story-manage-icon"></div>\
    '),
    
    // ============
    // = Bindings =
    // ============

    toggle_classes: function() {
        var changes = this.model.changedAttributes();
        
        if (changes && _.all(_.keys(changes), function(change) { 
            return _.contains(['intelligence', 'read_status', 'selected'], change);
        })) return;
        
        var story = this.model;
        var unread_view = NEWSBLUR.reader.get_unread_view_score();
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
    
    toggle_intelligence: function() {
        var score = this.model.score();
        this.$el.removeClass('NB-story-negative NB-story-neutral NB-story-postiive')
                .addClass('NB-story-'+this.model.score_name(score));
    },
    
    toggle_read_status: function() {
        this.$el.toggleClass('read', !!this.model.get('read_status'));
    },
    
    toggle_selected: function(model, selected, options) {
        this.$el.toggleClass('NB-selected', !!this.model.get('selected'));
        
        if (this.model.get('selected')) {
            NEWSBLUR.app.story_titles.scroll_to_selected_story(this.model);
        }
    },
    
    toggle_starred: function() {
        var pane_alignment = NEWSBLUR.assets.preference('story_pane_anchor');
        var $star = this.$('.NB-storytitles-star');
        NEWSBLUR.app.story_titles.scroll_to_selected_story(this.model);
        
        
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
            this.$el.one('mouseout', _.bind(function() {
                this.$el.removeClass('NB-unstarred');
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
        e.preventDefault();
        e.stopPropagation();
        if (e.which == 1 && $('.NB-menu-manage-container:visible').length) return;

        this.model.set('selected', true, {'click_on_story_title': true});

        if (NEWSBLUR.hotkeys.command) {
            this.model.story_view.open_story_in_new_tab();
        }
    },

    show_manage_menu: function(e) {
        e.preventDefault();
        e.stopPropagation();
        // NEWSBLUR.log(["showing manage menu", this.model.is_social() ? 'socialfeed' : 'feed', $(this.el), this]);
        NEWSBLUR.reader.show_manage_menu('story', this.$el, {
            story_id: this.model.id,
            feed_id: this.model.get('story_feed_id'),
            rightclick: e.which >= 2
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
    },
    
    open_story_in_story_view: function(e) {
        e.preventDefault();
        e.stopPropagation();
        NEWSBLUR.app.story_tab_view.open_story(this.model, true);
        return false;
    }
        
});