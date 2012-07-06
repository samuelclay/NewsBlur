NEWSBLUR.Views.SocialPage = Backbone.View.extend({
    
    el: 'body',
    
    page: 1,
    
    events: {
        "click .NB-page-controls-next:not(.NB-loaded):not(.NB-loading)" : "next_page"
    },
    
    next_animation_options: {
        'duration': 500,
        'easing': 'easeInOutQuint',
        'queue': false
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
        
        $loaded.animate({'bottom': height}, this.next_animation_options);
        $loading.text('Loading...').css('bottom', height).animate({'bottom': innerheight}, this.next_animation_options);
        $next.animate({'bottom': -1 * innerheight}, this.next_animation_options);
        $button.addClass('NB-loading');
        
        $button.animate({'backgroundColor': '#5C89C9'}, 650)
               .animate({'backgroundColor': '#2B478C'}, 900);
        this.feed_stories_loading = setInterval(function() {
            $button.animate({'backgroundColor': '#5C89C9'}, {'duration': 650})
                   .animate({'backgroundColor': '#2B478C'}, 900);
        }, 1550);
        
        this.page += 1;
        
        $.ajax({
            url: '/',
            method: 'GET',
            data: {
                'page': this.page,
                'format': 'html'
            },
            success: _.bind(this.post_next_page, this),
            error: _.bind(this.error_next_page, this)
        });
    },
    
    post_next_page: function(data) {
        var $controls = this.$('.NB-page-controls').last();
        var $button = $('.NB-page-controls-next', $controls);
        var $loading = $('.NB-page-controls-text-loading', $controls);
        var $loaded = $('.NB-page-controls-text-loaded', $controls);
        var height = $controls.height();
        var innerheight = $button.height();
        
        $button.removeClass('NB-loading').addClass('NB-loaded');
        $button.stop(true).animate({'backgroundColor': '#86B86B'}, {'duration': 750, 'easing': 'easeOutExpo', 'queue': false});
        
        $loaded.text('Page ' + this.page).css('bottom', height).animate({'bottom': innerheight}, this.next_animation_options);
        $loading.animate({'bottom': -1 * innerheight}, this.next_animation_options);
        
        clearInterval(this.feed_stories_loading);
        
        $controls.after($(data));
    },
    
    error_next_page: function() {
        var $controls = this.$('.NB-page-controls').last();
        var $button = $('.NB-page-controls-next', $controls);
        var $loading = $('.NB-page-controls-text-loading', $controls);
        var $next = $('.NB-page-controls-text-next', $controls);
        var height = $controls.height();
        var innerheight = $button.height();
        
        $button.removeClass('NB-loading').removeClass('NB-loaded');
        $button.stop(true).animate({'backgroundColor': '#B6686B'}, {
            'duration': 750, 
            'easing': 'easeOutExpo', 
            'queue': false
        });
        
        this.page -= 1;
        
        $next.text('Whoops! Something went wrong. Try again.')
             .animate({'bottom': innerheight}, this.next_animation_options);
        $loading.animate({'bottom': height}, this.next_animation_options);
        
        clearInterval(this.feed_stories_loading);
    }
    
});

$(document).ready(function() {

    NEWSBLUR.app.social_page = new NEWSBLUR.Views.SocialPage();

});
