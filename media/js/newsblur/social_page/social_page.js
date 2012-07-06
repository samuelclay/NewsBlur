NEWSBLUR.Views.SocialPage = Backbone.View.extend({
    
    el: 'body',
    
    page: 1,
    
    events: {
        "click .NB-page-controls-next:not(.NB-loaded):not(.NB-loading)" : "next_page"
    },
    
    initialize: function() {
        NEWSBLUR.assets = new NEWSBLUR.SocialPageAssets();
        this.initialize_stories();
    },
    
    initialize_stories: function($stories) {
        $stories = $stories || this.$el;
        
        $('.NB-story', $stories).each(function() {
            new NEWSBLUR.Views.SocialPageStory({el: $(this)});
        });
    },
    
    // ===========
    // = Actions =
    // ===========
    
    post_next_page: function(data) {
        var $controls = this.$('.NB-page-controls').last();
        var $button = $('.NB-page-controls-next', $controls);
        var $loading = $('.NB-page-controls-text-loading', $controls);
        var $loaded = $('.NB-page-controls-text-loaded', $controls);
        var height = $controls.height();
        var innerheight = $button.height();
        
        $button.removeClass('NB-loading').addClass('NB-loaded');
        
        $loaded.text('Page ' + this.page).css('bottom', height).animate({'bottom': innerheight}, {
            'duration': 500,
            'easing': 'easeInOutQuint',
            'queue': false
        });
        $loading.animate({'bottom': -1 * innerheight}, {
            'duration': 500,
            'easing': 'easeInOutQuint',
            'queue': false
        });
        
        clearInterval(this.feed_stories_loading);
        $button.stop().animate({'backgroundColor': '#86B86B'}, {'duration': 750, 'queue': false});
        
        $controls.after($(data));
    },
    
    // ==========
    // = Events =
    // ==========
    
    next_page: function(e) {
        var $button = $(e.currentTarget);
        var $next = $('.NB-page-controls-text-next', $button);
        var $loading = $('.NB-page-controls-text-loading', $button);
        var $loaded = $('.NB-page-controls-text-loaded', $button);
        var height = this.$('.NB-page-controls').height();
        var innerheight = $button.height();
        
        $loading.text('Loading...').css('bottom', height).animate({'bottom': innerheight}, {
            'duration': 500,
            'easing': 'easeInOutQuint',
            'queue': false
        });
        $next.animate({'bottom': -1 * innerheight}, {
            'duration': 500,
            'easing': 'easeInOutQuint',
            'queue': false
        });
        $button.addClass('NB-loading');
        
        $button.animate({'backgroundColor': '#5C89C9'}, 900);
        this.feed_stories_loading = setInterval(function() {
            if (!$button.hasClass('NB-loaded')) return;
            $button.animate({'backgroundColor': '#2B478C'}, {'duration': 650})
                    .animate({'backgroundColor': '#5C89C9'}, 900);
        }, 1500);
        
        this.page += 1;
        
        $.ajax({
            url: '/',
            method: 'GET',
            data: {
                'page': this.page,
                'format': 'html'
            },
            success: _.bind(this.post_next_page, this)
        });
    }
    
});

$(document).ready(function() {

    NEWSBLUR.app.social_page = new NEWSBLUR.Views.SocialPage();

});
