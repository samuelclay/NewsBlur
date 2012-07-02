NEWSBLUR.Views.SocialPage = Backbone.View.extend({
    
    el: 'body',
    
    initialize: function() {
        NEWSBLUR.assets = new NEWSBLUR.SocialPageAssets();
        this.initialize_stories();
    },
    
    initialize_stories: function($stories) {
        $stories = $stories || this.$el;
        
        $('.NB-story', $stories).each(function() {
            new NEWSBLUR.Views.SocialPageStory({el: $(this)});
        });
    }
    
});

$(document).ready(function() {

    NEWSBLUR.app.social_page = new NEWSBLUR.Views.SocialPage();

});
