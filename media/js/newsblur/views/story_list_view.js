NEWSBLUR.Views.StoryListView = Backbone.View.extend({
    
    el: '.NB-feed-stories',
    
    initialize: function() {
        _.bindAll(this, 'render');
        this.collection.bind('reset', this.render);
        this.collection.bind('add', this.add);
    },
    
    render: function() {
        var $stories = this.collection.map(function(story) {
            return new NEWSBLUR.Views.StoryView({model: story}).render().el;
        });
        this.$el.html($stories);
    },
    
    add: function() {
        console.log(["story list add", arguments]);
        var $stories = this.collection.map(function(story) {
            return new NEWSBLUR.Views.StoryView({model: story}).render().el;
        });
        this.$el.append($stories);
    }
    
});