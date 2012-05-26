NEWSBLUR.Views.StoryView = Backbone.View.extend({
    
    className: 'NB-feed-story',
    
    events: {
        "click .NB-feed-story-content a"        : "click_link_in_story",
        "click .NB-feed-story-title"            : "click_link_in_story",
        "mouseenter .NB-feed-story-manage-icon" : "mouseenter_manage_icon",
        "mouseleave .NB-feed-story-manage-icon" : "mouseleave_manage_icon",
        "contextmenu .NB-feed-story-header"     : "show_manage_menu",
        "click .NB-feed-story-manage-icon"      : "show_manage_menu"
    },
    
    initialize: function() {
        _.bindAll(this, 'mouseleave', 'mouseenter');
        this.model.bind('change', this.toggle_classes, this);
        this.model.bind('change:read_status', this.toggle_read_status, this);
        this.model.bind('change:selected', this.toggle_selected, this);
        
        // Binding directly instead of using event delegation. Need for speed.
        this.$el.bind('mouseenter', this.mouseenter);
        this.$el.bind('mouseleave', this.mouseleave);

        this.model.story_view = this;
    },
    
    // =============
    // = Rendering =
    // =============
    
    render: function() {
        this.feed = NEWSBLUR.assets.get_feed(this.model.get('story_feed_id'));
        this.classifiers = NEWSBLUR.assets.classifiers[this.model.get('story_feed_id')];
        
        this.$el.html(this.render_to_string());
        this.toggle_classes();
        this.toggle_read_status();
        this.generate_gradients();
        
        return this;
    },
    
    render_to_string: function() {
        var $story_title = _.template('\
            <div class="NB-feed-story-header">\
                <div class="NB-feed-story-header-feed">\
                    <% if (feed) { %>\
                        <div class="NB-feed-story-feed">\
                            <img class="feed_favicon" src="<%= $.favicon(feed) %>">\
                            <span class="NB-feed-story-header-title"><%= feed.get("feed_title") %></span>\
                        </div>\
                    <% } %>\
                </div>\
                <div class="NB-feed-story-header-info">\
                    <% if (story.get("story_authors")) { %>\
                        <div class="NB-feed-story-author <% if (authors_score) { %>NB-score-<%= authors_score %><% } %>">\
                            <%= story.get("story_authors") %>\
                        </div>\
                    <% } %>\
                    <% if (story.get("story_tags", []).length) { %>\
                        <div class="NB-feed-story-tags">\
                            <% _.each(story.get("story_tags"), function(tag) { %>\
                                <div class="NB-feed-story-tag <% if (tags_score[tag]) { %>NB-score-<%= tags_score[tag] %><% } %>">\
                                    <%= tag %>\
                                </div>\
                            <% }) %>\
                        </div>\
                    <% } %>\
                    <div class="NB-feed-story-title-container">\
                        <div class="NB-feed-story-sentiment"></div>\
                        <div class="NB-feed-story-manage-icon"></div>\
                        <a class="NB-feed-story-title" href="<%= story.get("story_permalink") %>"><%= title %></a>\
                    </div>\
                    <% if (story.get("long_parsed_date")) { %>\
                        <span class="NB-feed-story-date">\
                            <% if (story.has_modifications()) { %>\
                                <div class="NB-feed-story-hide-changes" \
                                     title="<%= NEWSBLUR.assets.preference("hide_story_changes") ? "Show" : "Hide" %>\
                                            story modifications">\
                                </div>\
                            <% } %>\
                            <%= story.get("long_parsed_date") %>\
                        </span>\
                    <% } %>\
                </div>\
            </div>\
            <div class="NB-feed-story-content">\
                <%= story.get("story_content") %>\
            </div>\
            <% if (story.get("comment_count") || story.get("share_count")) { %>\
                <div class="NB-feed-story-comments">\
                    this.make_story_share_comments(story)\
                </div>\
            <% } %>\
            <div class="NB-feed-story-sideoptions-container">\
                <div class="NB-sideoption NB-feed-story-train">\
                    <div class="NB-sideoption-icon">&nbsp;</div>\
                    <div class="NB-sideoption-title">Train this story</div>\
                </div>\
                <div class="NB-sideoption NB-feed-story-save">\
                    <div class="NB-sideoption-icon">&nbsp;</div>\
                    <div class="NB-sideoption-title"><%= story.get("starred") ? "Saved" : "Save this story" %></div>\
                </div>\
                <div class="NB-sideoption NB-feed-story-share">\
                    <div class="NB-sideoption-icon">&nbsp;</div>\
                    <div class="NB-sideoption-title"><%= story.get("shared") ? "Shared" : "Share this story" %></div>\
                </div>\
                <div class="NB-sideoption-share-wrapper">\
                    <div class="NB-sideoption-share">\
                        <div class="NB-sideoption-share-wordcount"></div>\
                        <div class="NB-sideoption-share-optional">Optional</div>\
                        <div class="NB-sideoption-share-title">Comments:</div>\
                        <textarea class="NB-sideoption-share-comments"><%= story.get("shared_comments") %></textarea>\
                        <div class="NB-sideoption-share-save NB-modal-submit-button">Share</div>\
                    </div>\
                </div>\
            </div>\
        ', {
            story   : this.model,
            feed    : this.options.river_stories && this.feed,
            tag     : _.first(this.model.get("story_tags")),
            title   : this.make_story_title(),
            authors_score  : this.classifiers.authors[this.model.get('story_authors')],
            tags_score : this.classifiers.tags,
            options : this.options
        });
        
        return $story_title;
    },
    
    generate_gradients: function() {
        var $header = this.$('.NB-feed-story-header-feed');
        
        $header.css('background-image', NEWSBLUR.utils.generate_gradient(this.feed, 'webkit'));
        $header.css('background-image', NEWSBLUR.utils.generate_gradient(this.feed, 'moz'));
        $header.css('borderTop',        NEWSBLUR.utils.generate_gradient(this.feed, 'border'));
        $header.css('borderBottom',     NEWSBLUR.utils.generate_gradient(this.feed, 'border'));
        $header.css('textShadow',       '0 1px 0 ' + NEWSBLUR.utils.generate_gradient(this.feed, 'shadow'));
    },
    
    make_story_title: function() {
        var title = this.model.get('story_title');
        var classifiers = NEWSBLUR.assets.classifiers[this.model.get('story_feed_id')];
        var feed_titles = classifiers && classifiers.titles || [];
        
        _.each(feed_titles, function(score, title_classifier) {
            if (title.indexOf(title_classifier) != -1) {
                title = title.replace(title_classifier, '<span class="NB-score-'+score+'">'+title_classifier+'</span>');
            }
        });
        
        return title;
    },
    
    // ============
    // = Bindings =
    // ============
    
    toggle_classes: function() {
        var story = this.model;
        var unread_view = NEWSBLUR.assets.preference('unread_view');
        var score = story.score();
        
        this.$el.toggleClass('NB-inverse', this.feed.is_light());
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
            this.$('.NB-feed-story-hide-changes').tipsy({
                delayIn: 375
            });
        }
    },
    
    toggle_read_status: function() {
        this.$el.toggleClass('read', !!this.model.get('read_status'));
    },
    
    toggle_selected: function(model, selected, options) {
        this.$el.toggleClass('NB-selected', !!this.model.get('selected'));

        if (selected && options.click_on_story_title) {
            NEWSBLUR.app.story_list.scroll_to_selected_story(this);
        }
    },
    
    // ===========
    // = Actions =
    // ===========
    
    select_story: function() {
    },
    
    // ==========
    // = Events =
    // ==========
    
    click_link_in_story: function(e) {
        e.preventDefault();
        var href = $(e.currentTarget).attr('href');
        
        if (NEWSBLUR.assets.preference('new_window') == 1) {
            window.open(href, '_blank');
        } else {
            window.open(href);
        }
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
    
    mouseenter: function() {
        if (this.model.get('selected')) return;
        
        if (NEWSBLUR.reader.flags['switching_to_feed_view'] ||
            NEWSBLUR.reader.flags['scrolling_by_selecting_story_title'] ||
            NEWSBLUR.assets.preference('feed_view_single_story')) {
            return;
        }
        
        this.collection.deselect();
        this.model.set('selected', true, {'scroll_story_list': true});
    },
    
    mouseleave: function() {
        
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
    }

});
