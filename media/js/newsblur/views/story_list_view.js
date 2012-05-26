NEWSBLUR.Views.StoryListView = Backbone.View.extend({
    
    el: '.NB-feed-stories',
    
    initialize: function() {
        this.collection.bind('reset', this.render, this);
        this.collection.bind('add', this.add, this);
    },
    
    // ==========
    // = Render =
    // ==========
    
    render: function() {
        var collection = this.collection;
        var $stories = this.collection.map(function(story) {
            return new NEWSBLUR.Views.StoryView({
                model: story,
                collection: collection
            }).render().el;
        });
        this.$el.html($stories);
    },
    
    add: function(options) {
        if (options.added) {
            var collection = this.collection;
            var $stories = _.map(this.collection.models.slice(-1 * options.added), function(story) {
                return new NEWSBLUR.Views.StoryView({
                    model: story,
                    collection: collection
                }).render().el;
            });
            this.$el.append($stories);
        } else {
            this.show_no_more_stories();
        }
    },
    
    // ===========
    // = Actions =
    // ===========
    
    scroll_to_selected_story: function(story_view, options) {
        options = options || {};
        NEWSBLUR.reader.flags.scrolling_by_selecting_story_title = true;
        this.$el.scrollable().stop();
        this.$el.scrollTo(story_view.$el, { 
            duration: options.immediate ? 0 : 340,
            axis: 'y', 
            easing: 'easeInOutQuint', 
            offset: 0, // scroll_offset, 
            queue: false, 
            onAfter: function() {
                NEWSBLUR.reader.locks.scrolling = setTimeout(function() {
                    NEWSBLUR.reader.flags.scrolling_by_selecting_story_title = false;
                }, 100);
            }
        });
    },
    
    show_no_more_stories: function() {
        this.$('.NB-feed-story-endbar').remove();
        var $end_stories_line = $.make('div', { 
            className: 'NB-feed-story-endbar'
        });

        this.$el.append($end_stories_line);
    }
 
});