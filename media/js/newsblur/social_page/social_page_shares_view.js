NEWSBLUR.Views.SocialPageSharesView = Backbone.View.extend({
    
    events: {},
    
    initialize: function() {
        this.story_view = this.options.story_view;
    },
    
    replace_shares: function($new_shares) {
        this.$el.replaceWith($new_shares);
        this.setElement($new_shares);
        this.initialize();
    }
        
});
