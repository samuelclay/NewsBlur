NEWSBLUR.Views.StoryTitleView = Backbone.View.extend({
    
    className: 'story NB-story-title',
    
    initialize: function() {
        _.bindAll(this, 'toggle_read_status', 'toggle_classes');
        this.model.bind('change', this.toggle_classes);
        this.model.bind('change:read_status', this.toggle_read_status);
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
    }
        
});