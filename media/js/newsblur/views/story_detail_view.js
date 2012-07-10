NEWSBLUR.Views.StoryDetailView = Backbone.View.extend({
    
    tagName: 'li',
    
    className: 'NB-feed-story',
    
    events: {
        "click .NB-feed-story-content a"        : "click_link_in_story",
        "click .NB-feed-story-title"            : "click_link_in_story",
        "mouseenter .NB-feed-story-manage-icon" : "mouseenter_manage_icon",
        "mouseleave .NB-feed-story-manage-icon" : "mouseleave_manage_icon",
        "contextmenu .NB-feed-story-header"     : "show_manage_menu",
        "click .NB-feed-story-manage-icon"      : "show_manage_menu",
        "click .NB-feed-story-hide-changes"     : "hide_story_changes",
        "click .NB-feed-story-header-title"     : "open_feed",
        "click .NB-feed-story-tag"              : "save_classifier",
        "click .NB-feed-story-author"           : "save_classifier",
        "click .NB-feed-story-train"            : "open_story_trainer",
        "click .NB-feed-story-save"             : "star_story"
    },
    
    initialize: function() {
        _.bindAll(this, 'mouseleave', 'mouseenter');
        this.model.bind('change', this.toggle_classes, this);
        this.model.bind('change:read_status', this.toggle_read_status, this);
        this.model.bind('change:selected', this.toggle_selected, this);
        this.model.bind('change:starred', this.toggle_starred, this);
        this.model.bind('change:intelligence', this.render_header, this);
        this.model.bind('change:intelligence', this.toggle_score, this);
        
        // Binding directly instead of using event delegation. Need for speed.
        // this.$el.bind('mouseenter', this.mouseenter);
        // this.$el.bind('mouseleave', this.mouseleave);
        
        if (!this.options.feed_floater) {
            this.model.story_view = this;
        }
    },
    
    // =============
    // = Rendering =
    // =============
    
    render: function() {
        var params = this.get_render_params();
        params['story_header'] = this.story_header_template(params);
        params['story_share_view'] = new NEWSBLUR.Views.StoryShareView({
            model: this.model, 
            el: this.el
        }).template({
            story: this.model,
            social_services: NEWSBLUR.assets.social_services
        });
        this.$el.html(this.template(params));
        this.toggle_classes();
        this.toggle_read_status();
        this.toggle_score();
        this.generate_gradients();
        this.render_comments();

        return this;
    },
    
    render_header: function(model, value, options) {
        var params = this.get_render_params();
        this.$('.NB-feed-story-header').replaceWith($(this.story_header_template(params)));
        this.generate_gradients();
    },
    
    get_render_params: function() {
        this.feed = NEWSBLUR.assets.get_feed(this.model.get('story_feed_id'));
        this.classifiers = NEWSBLUR.assets.classifiers[this.model.get('story_feed_id')];
        
        return {
            story            : this.model,
            feed             : NEWSBLUR.reader.flags.river_view && this.feed,
            tag              : _.first(this.model.get("story_tags")),
            title            : this.make_story_title(),
            authors_score    : this.classifiers && this.classifiers.authors[this.model.get('story_authors')],
            tags_score       : this.classifiers && this.classifiers.tags,
            options          : this.options
        };
    },
    
    story_header_template: _.template('\
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
                            <div class="NB-feed-story-tag <% if (tags_score && tags_score[tag]) { %>NB-score-<%= tags_score[tag] %><% } %>">\
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
                    <% if (story.get("starred_date")) { %>\
                        <span class="NB-feed-story-starred-date"><%= story.get("starred_date") %></span>\
                    <% } %>\
                <% } %>\
            </div>\
        </div>\
    '),
    
    template: _.template('\
        <%= story_header %>\
        <div class="NB-feed-story-content">\
            <%= story.get("story_content") %>\
        </div>\
        <div class="NB-feed-story-share-container"></div>\
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
                <div class="NB-sideoption-title"><%= story.get("shared") ? "Shared" : "Post to Blurblog" %></div>\
            </div>\
            <%= story_share_view %>\
        </div>\
    '),
    
    generate_gradients: function() {
        var $header = this.$('.NB-feed-story-header-feed');
        
        if (!this.feed) return;
        
        $header.css('background-image', NEWSBLUR.utils.generate_gradient(this.feed, 'webkit'));
        $header.css('background-image', NEWSBLUR.utils.generate_gradient(this.feed, 'moz'));
        $header.css('borderTop',        NEWSBLUR.utils.generate_gradient(this.feed, 'border'));
        $header.css('borderBottom',     NEWSBLUR.utils.generate_gradient(this.feed, 'border'));
        $header.css('textShadow',       NEWSBLUR.utils.generate_shadow(this.feed));
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
    
    render_comments: function() {
        var $original_comments = this.$('.NB-feed-story-share-container,.NB-feed-story-comments');
        if (this.model.get("comment_count") || this.model.get("share_count")) {
            var $comments = new NEWSBLUR.Views.StoryCommentsView({model: this.model}).render().el;
            $original_comments.replaceWith($comments);
        } else if ($original_comments.length) {
            $original_comments.replaceWith($.make('div', { className: 'NB-feed-story-share-container' }));
        }
    },
    
    destroy: function() {
        this.model.unbind(null, null, this);
        this.remove();
    },
    
    // ============
    // = Bindings =
    // ============
    
    toggle_classes: function() {
        var changes = this.model.changedAttributes();
        var onlySelected = changes && _.all(_.keys(changes), function(change) {
            return _.contains(['selected', 'read', 'intelligence', 'visible'], change);
        });
        
        if (onlySelected) return;
        
        // if (this.model.changedAttributes()) {
        //     NEWSBLUR.log(["Story changed", this.model.changedAttributes(), this.model.previousAttributes()]);
        // }
        
        var story = this.model;
        var unread_view = NEWSBLUR.assets.preference('unread_view');
        var score = story.score();
        
        if (this.feed) {
            this.$el.toggleClass('NB-inverse', this.feed.is_light());
        }
        this.$el.toggleClass('NB-river-story', NEWSBLUR.reader.flags.river_view);
        this.$el.toggleClass('NB-story-starred', !!story.get('starred'));
        this.$el.toggleClass('NB-story-shared', !!story.get('shared'));
                
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
    
    toggle_score: function() {
        var story = this.model;
        
        this.$el.removeClass('NB-story-negative NB-story-neutral NB-story-postiive')
                .addClass('NB-story-'+story.score_name(story.score()));
    },
    
    toggle_selected: function(model, selected, options) {
        this.$el.toggleClass('NB-selected', !!this.model.get('selected'));
        
        if (selected && options.scroll_to_comments) {
            NEWSBLUR.app.story_list.scroll_to_selected_story(model, {
                scroll_offset: -50,
                scroll_to_comments: true
            });
        } else if (selected && 
            !options.selected_by_scrolling &&
            (NEWSBLUR.reader.story_view == 'feed' ||
             (NEWSBLUR.reader.story_view == 'page' &&
              NEWSBLUR.reader.flags['page_view_showing_feed_view']))) {
            NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
            NEWSBLUR.app.story_list.scroll_to_selected_story(model, options);
        }
        
        if (NEWSBLUR.reader.flags['feed_view_showing_story_view']) {
            NEWSBLUR.reader.switch_to_correct_view();
        }
    },
    
    // ===========
    // = Actions =
    // ===========
    
    select_story: function() {
    },
    
    preserve_classifier_color: function(classifier_type, value, score) {
        var $tag;
        this.$('.NB-feed-story-'+classifier_type).each(function() {
            if (_.string.trim($(this).text()) == value) {
                $tag = $(this);
                return false;
            }
        });
        $tag.removeClass('NB-score-now-1')
            .removeClass('NB-score-now--1')
            .removeClass('NB-score-now-0')
            .addClass('NB-score-now-'+score)
            .one('mouseleave', function() {
                $tag.removeClass('NB-score-now-'+score);
            });
        _.delay(function() {
            $tag.one('mouseenter', function() {
                $tag.removeClass('NB-score-now-'+score);
            });
        }, 100);
    },

    toggle_starred: function() {
        var story = this.model;
        var $sideoption_title = this.$('.NB-feed-story-save .NB-sideoption-title');
        
        if (story.get('starred')) {
            $sideoption_title.text('Saved');
        } else {
            $sideoption_title.text('Removed');
            $sideoption_title.one('mouseleave', function() {
                _.delay(function() {
                    if (!story.get('starred')) {
                        $sideoption_title.text('Save this story');
                    }
                }, 200);
            });        
        }
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
        
        if (NEWSBLUR.reader.flags['scrolling_by_selecting_story_title'] ||
            NEWSBLUR.assets.preference('feed_view_single_story')) {
            return;
        }
        
        this.model.set('selected', true, {selected_by_scrolling: true});
    },
    
    mouseleave: function() {
        
    },

    show_manage_menu: function(e) {
        e.preventDefault();
        e.stopPropagation();
        NEWSBLUR.reader.show_manage_menu('story', this.$el, {
            story_id: this.model.id,
            feed_id: this.model.get('story_feed_id')
        });
        return false;
    },
    
    hide_story_changes: function() {
        var $button = this.$('.NB-feed-story-hide-changes');
        
        if (NEWSBLUR.assets.preference('hide_story_changes')) {
            this.$('ins').css({'text-decoration': 'underline'});
            this.$('del').css({'display': 'inline'});
        } else {
            this.$('ins').css({'text-decoration': 'none'});
            this.$('del').css({'display': 'none'});
        }
        $button.css('opacity', 1).fadeOut(400);
        $button.tipsy('hide').tipsy('disable');
        NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
    },
    
    open_feed: function() {
        NEWSBLUR.reader.open_feed(this.model.get('story_feed_id'));
    },
    
    save_classifier: function(e) {
        var $tag = $(e.currentTarget);
        var classifier_type = $tag.hasClass('NB-feed-story-author') ? 'author' : 'tag';
        var value = _.string.trim($tag.text());
        var score = $tag.hasClass('NB-score-1') ? -1 : $tag.hasClass('NB-score--1') ? 0 : 1;
        var feed_id = this.model.get('story_feed_id');
        var data = {
            'feed_id': feed_id
        };
        
        if (score == 0) {
            data['remove_like_'+classifier_type] = value;
        } else if (score == 1) {
            data['like_'+classifier_type] = value;
        } else if (score == -1) {
            data['dislike_'+classifier_type] = value;
        }
        this.model.set('visible', true, {silent: true});
        NEWSBLUR.assets.classifiers[feed_id][classifier_type+'s'][value] = score;
        NEWSBLUR.assets.recalculate_story_scores(feed_id, {story_view: this});
        NEWSBLUR.assets.save_classifier(data, function(resp) {
            NEWSBLUR.reader.force_feeds_refresh(null, true, feed_id);
        });
        
        this.preserve_classifier_color(classifier_type, value, score);
    },
    
    open_story_trainer: function() {
        NEWSBLUR.reader.open_story_trainer(this.model.id, this.model.get('story_feed_id'));
    },
    
    star_story: function() {
        this.model.set('starred', !this.model.get('starred'));
        if (this.model.get('starred')) {
            NEWSBLUR.assets.mark_story_as_starred(this.model.id);
        } else {
            NEWSBLUR.assets.mark_story_as_unstarred(this.model.id);
        }
        NEWSBLUR.reader.update_starred_count();
    },
    
    open_story_in_new_tab: function() {
        window.open(this.model.get('story_permalink'), '_blank');
        window.focus();
    }
    

});
