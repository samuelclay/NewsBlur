NEWSBLUR.Views.StoryTitlesView = Backbone.View.extend({
    
    el: '.NB-story-titles',
    
    initialize: function() {
        _.bindAll(this, 'render');
        this.collection.bind('reset', this.render);
        this.collection.bind('add', this.add);
    },
    
    render: function() {
        var $stories = this.collection.map(function(story) {
            return new NEWSBLUR.Views.StoryTitleView({model: story}).render().el;
        });
        this.$el.html($stories);
    },
    
    add: function() {
        console.log(["add titles", arguments]);
        var $stories = this.collection.map(function(story) {
            return new NEWSBLUR.Views.StoryTitleView({model: story}).render().el;
        });
        this.$el.append($stories);
    }
    
});