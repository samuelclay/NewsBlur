NEWSBLUR.Views.StoryView = Backbone.View.extend({
    
    className: 'NB-feed-story',
    
    initialize: function() {
        _.bindAll(this, 'toggle_read_status', 'toggle_classes');
        this.model.bind('change', this.toggle_classes);
        this.model.bind('change:read_status', this.toggle_read_status);
    },
    
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
                </div>\
            </div>\
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
        }
    },
    
    toggle_read_status: function() {
        this.$el.toggleClass('read', !!this.model.get('read_status'));
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
    }

    
});