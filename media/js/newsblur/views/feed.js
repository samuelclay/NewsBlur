NEWSBLUR.Views.Feed = Backbone.View.extend({
    
    className: 'NB-feed',
    
    render: function() {
        $(this.el).html(this.make('div', {}, this.model.get('feed_title')));
        return this;
    }

});