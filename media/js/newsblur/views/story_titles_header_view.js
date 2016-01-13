NEWSBLUR.Views.StoryTitlesHeader = Backbone.View.extend({
    
    el: ".NB-story-titles-header",
    
    options: {
        'layout': 'split'
    },
    
    events: {
        "click .NB-feedbar-options"                 : "open_options_popover",
        "click .NB-feedbar-mark-feed-read"          : "mark_folder_as_read",
        "click .NB-feedbar-mark-feed-read-expand"   : "expand_mark_read",
        "click .NB-feedbar-mark-feed-read-time"     : "mark_folder_as_read_days",
        "click .NB-story-title-indicator"           : "show_hidden_story_titles"
    },
    
    initialize: function() {
        this.$story_titles_feedbar = $(".NB-story-titles-header");
        this.$feed_view_feedbar = $(".NB-feed-story-view-header");
        
        // if (this.options.layout == 'split' || this.options.layout == 'list') {
            this.$story_titles_feedbar.show();
            this.$feed_view_feedbar.hide();
        // } else if (this.options.layout == 'full') {
        //     this.$story_titles_feedbar.hide();
        //     this.$feed_view_feedbar.show();
        //     this.setElement(this.$feed_view_feedbar);
        // }
    },
    
    render: function(options) {
        var $view;
        this.options = _.extend({}, this.options, options);
        this.showing_fake_folder = NEWSBLUR.reader.flags['river_view'] && 
            NEWSBLUR.reader.active_folder && 
            (NEWSBLUR.reader.active_folder.get('fake') || !NEWSBLUR.reader.active_folder.get('folder_title'));
        
        if (NEWSBLUR.reader.flags['starred_view']) {
            $view = $(_.template('\
                <div class="NB-folder NB-no-hover">\
                    <div class="NB-search-container"></div>\
                    <div class="NB-feedbar-options-container">\
                        <span class="NB-feedbar-options">\
                            <div class="NB-icon"></div>\
                            <%= NEWSBLUR.assets.view_setting("starred", "order") %>\
                        </span>\
                    </div>\
                    <div class="NB-starred-icon"></div>\
                    <div class="NB-feedlist-manage-icon"></div>\
                    <span class="folder_title_text">Saved Stories<% if (tag) { %> - <%= tag %><% } %></span>\
                </div>\
            ', {
                tag: NEWSBLUR.reader.flags['starred_tag']
            }));
            this.search_view = new NEWSBLUR.Views.FeedSearchView({
                feedbar_view: this
            }).render();
            this.search_view.blur_search();
            $(".NB-search-container", $view).html(this.search_view.$el);
        } else if (NEWSBLUR.reader.active_feed == "read") {
            $view = $(_.template('\
                <div class="NB-folder NB-no-hover">\
                    <div class="NB-feedbar-options-container">\
                        <span class="NB-feedbar-options">\
                            <div class="NB-icon"></div>\
                            <%= NEWSBLUR.assets.view_setting("read", "order") %>\
                        </span>\
                    </div>\
                    <div class="NB-read-icon"></div>\
                    <div class="NB-feedlist-manage-icon"></div>\
                    <div class="folder_title_text">Read Stories</div>\
                </div>\
            ', {}));
        } else if (this.showing_fake_folder) {
            $view = $(_.template('\
                <div class="NB-folder NB-no-hover NB-folder-<%= all_stories ? "river" : "fake" %>">\
                    <div class="NB-search-container"></div>\
                    <% if (show_options) { %>\
                        <div class="NB-feedbar-options-container">\
                            <span class="NB-feedbar-options">\
                                <div class="NB-icon"></div>\
                                <%= NEWSBLUR.assets.view_setting(folder_id, "read_filter") %>\
                                &middot;\
                                <%= NEWSBLUR.assets.view_setting(folder_id, "order") %>\
                            </span>\
                        </div>\
                    <% } %>\
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
                    <div class="NB-folder-icon"></div>\
                    <div class="NB-feedlist-manage-icon"></div>\
                    <span class="folder_title_text"><%= folder_title %></span>\
                </div>\
            ', {
                folder_title: this.fake_folder_title(),
                folder_id: NEWSBLUR.reader.active_feed,
                all_stories: NEWSBLUR.reader.active_feed == "river:",
                show_options: !NEWSBLUR.reader.active_folder.get('fake') ||
                              NEWSBLUR.reader.active_folder.get('show_options')
            }));
            this.search_view = new NEWSBLUR.Views.FeedSearchView({
                feedbar_view: this
            }).render();
            this.search_view.blur_search();
            $(".NB-search-container", $view).html(this.search_view.$el);
        } else if (NEWSBLUR.reader.flags['river_view'] && 
                   NEWSBLUR.reader.active_folder &&
                   NEWSBLUR.reader.active_folder.get('folder_title')) {
            this.view = new NEWSBLUR.Views.Folder({
                model: NEWSBLUR.reader.active_folder,
                collection: NEWSBLUR.reader.active_folder.folder_view.collection,
                feedbar: true,
                only_title: true
            }).render();    
            $view = this.view.$el;    
            this.search_view = this.view.search_view;
        } else {
            this.view = new NEWSBLUR.Views.FeedTitleView({
                model: NEWSBLUR.assets.get_feed(this.options.feed_id), 
                type: 'story'
            }).render();
            $view = this.view.$el;
            this.search_view = this.view.search_view;
        }
        
        this.$el.html($view);
        
        if (NEWSBLUR.reader.flags.searching) {
            this.focus_search();
        }
        
        return this;
    },
    
    fake_folder_title: function() {
        var title = "All Site Stories";
        if (NEWSBLUR.reader.flags['social_view']) {
            if (NEWSBLUR.reader.flags['global_blurblogs']) {
                title = "Global Shared Stories";
            } else {
                title = "All Shared Stories";
            }
        }
        
        return title;
    },
    
    remove: function() {
        if (this.view) {
            this.view.remove();
            delete this.view;
        }
        // Backbone.View.prototype.remove.call(this);
    },
    
    search_has_focus: function() {
        return this.search_view && this.search_view.has_focus();
    },
    
    focus_search: function() {
        if (!this.search_view) return;
        
        this.search_view.focus_search();
    },
    
    // ===========
    // = Actions =
    // ===========
    
    show_feed_hidden_story_title_indicator: function(is_feed_load) {
        if (!is_feed_load) return;
        if (!NEWSBLUR.reader.active_feed) return;
        if (NEWSBLUR.reader.flags.search) return;
        if (NEWSBLUR.reader.flags['feed_list_showing_starred']) return;
        NEWSBLUR.reader.flags['unread_threshold_temporarily'] = null;
        
        var unread_view_name = NEWSBLUR.reader.get_unread_view_name();
        var $indicator = this.$('.NB-story-title-indicator');
        var unread_hidden_stories;
        if (NEWSBLUR.reader.flags['river_view']) {
            unread_hidden_stories = NEWSBLUR.reader.active_folder &&
                                    NEWSBLUR.reader.active_folder.folders &&
                                    NEWSBLUR.reader.active_folder.folders.unread_counts &&
                                    NEWSBLUR.reader.active_folder.folders.unread_counts().ng;
        } else {
            unread_hidden_stories = NEWSBLUR.assets.active_feed.unread_counts().ng;
        }
        var hidden_stories = unread_hidden_stories || !!NEWSBLUR.assets.stories.hidden().length;
        if (!hidden_stories) {
            $indicator.hide();
            return;
        }
        
        if (is_feed_load) {
            $indicator.css({'display': 'block', 'opacity': 0});
            _.delay(function() {
                $indicator.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeOutCubic'});
            }, 500);
        }
        $indicator.removeClass('unread_threshold_positive')
                  .removeClass('unread_threshold_neutral')
                  .removeClass('unread_threshold_negative')
                  .addClass('unread_threshold_'+unread_view_name);
    },
    
    show_hidden_story_titles: function() {
        var $indicator = this.$('.NB-story-title-indicator');
        var temp_unread_view_name = NEWSBLUR.reader.get_unread_view_name();
        var unread_view_name = NEWSBLUR.reader.get_unread_view_name(null, true);
        var hidden_stories_at_threshold = NEWSBLUR.assets.stories.any(function(story) {
            var score = story.score();
            if (temp_unread_view_name == 'positive') return score == 0;
            else if (temp_unread_view_name == 'neutral') return score < 0;
        });
        var hidden_stories_below_threshold = temp_unread_view_name == 'positive' && 
                                             NEWSBLUR.assets.stories.any(function(story) {
            return story.score() < 0;
        });
        
        NEWSBLUR.log(['show_hidden_story_titles', hidden_stories_at_threshold, hidden_stories_below_threshold, unread_view_name, temp_unread_view_name, NEWSBLUR.reader.flags['unread_threshold_temporarily']]);
        
        // First click, open neutral. Second click, open negative.
        if (temp_unread_view_name == 'positive' && 
            hidden_stories_at_threshold && 
            hidden_stories_below_threshold) {
            NEWSBLUR.reader.flags['unread_threshold_temporarily'] = 'neutral';
            NEWSBLUR.reader.show_story_titles_above_intelligence_level({
                'unread_view_name': 'neutral',
                'animate': true,
                'follow': true
            });
            $indicator.removeClass('unread_threshold_positive')
                      .removeClass('unread_threshold_negative');
            $indicator.addClass('unread_threshold_neutral');
            $(".NB-story-title-indicator-text", $indicator).text("show hidden stories");
        } else if (NEWSBLUR.reader.flags['unread_threshold_temporarily'] != 'negative') {
            NEWSBLUR.reader.flags['unread_threshold_temporarily'] = 'negative';
            NEWSBLUR.reader.show_story_titles_above_intelligence_level({
                'unread_view_name': 'negative',
                'animate': true,
                'follow': true
            });
            $indicator.removeClass('unread_threshold_positive')
                      .removeClass('unread_threshold_neutral');
            $indicator.addClass('unread_threshold_negative');
            // $indicator.animate({'opacity': 0}, {'duration': 500}).css('display', 'none');
            $(".NB-story-title-indicator-text", $indicator).text("hide hidden stories");
        } else {
            NEWSBLUR.reader.flags['unread_threshold_temporarily'] = null;
            NEWSBLUR.reader.show_story_titles_above_intelligence_level({
                'unread_view_name': unread_view_name,
                'animate': true,
                'follow': true
            });
            $indicator.removeClass('unread_threshold_positive')
                      .removeClass('unread_threshold_neutral') 
                      .removeClass('unread_threshold_negative'); 
            $indicator.addClass('unread_threshold_'+unread_view_name);
            $(".NB-story-title-indicator-text", $indicator).text("show hidden stories");
        }
    },
    
    open_options_popover: function(e) {
        if (!(this.showing_fake_folder ||
              NEWSBLUR.reader.active_feed == "read" ||
              NEWSBLUR.reader.flags['starred_view'])) return;
        
        NEWSBLUR.FeedOptionsPopover.create({
            anchor: this.$(".NB-feedbar-options"),
            feed_id: NEWSBLUR.reader.active_feed
        });
    },
    
    mark_folder_as_read: function(e, days_back) {
        if (!this.showing_fake_folder) return;
        if (NEWSBLUR.assets.preference('mark_read_river_confirm')) {
            NEWSBLUR.reader.open_mark_read_modal({days: days_back || 0});
        } else {
            NEWSBLUR.reader.mark_folder_as_read();
        }
        this.$('.NB-feedbar-mark-feed-read-container').fadeOut(400);
    },
    
    mark_folder_as_read_days: function(e) {
        if (!this.showing_fake_folder) return;
        var days = parseInt($(e.target).data('days'), 10);
        this.mark_folder_as_read(e, days);
    },
    
    expand_mark_read: function() {
        if (!this.showing_fake_folder) return;
        NEWSBLUR.Views.FeedTitleView.prototype.expand_mark_read.call(this);
    }

    
});