NEWSBLUR.Views.SocialPage = Backbone.View.extend({
    
    el: 'body',
    
    page: 1,

    auto_advance_pages: 0,
    
    MAX_AUTO_ADVANCED_PAGES: 15,
        
    events: {
        "click .NB-page-controls-next:not(.NB-loaded):not(.NB-loading)" : "next_page",
        "click .NB-button-follow" : "follow_user",
        "click .NB-button-following" : "unfollow_user"
    },
    
    stories: {},
    
    next_animation_options: {
        'duration': 500,
        'easing': 'easeInOutQuint',
        'queue': false
    },
    
    flags: {
        loading_page: false
    },
    
    initialize: function() {
        NEWSBLUR.assets = new NEWSBLUR.SocialPageAssets();
        NEWSBLUR.router = new NEWSBLUR.Router;
        this.cached_page_control_y = 0;
        
        Backbone.history.start({pushState: true});

        _.bindAll(this, 'detect_scroll');
        $(window).scroll(this.detect_scroll);
        
        this.login_view = new NEWSBLUR.Views.SocialPageLoginSignupView({
            el: this.el
        });

        this.initialize_stories();
    },
    
    initialize_stories: function($stories) {
        var self = this;
        $stories = $stories || this.$el;
        $('.NB-shared-story', $stories).each(function() {
            var $story = $(this);
            var guid = $story.data('guid');
            if (!self.stories[guid]) {
                var story_view = new NEWSBLUR.Views.SocialPageStory({
                    el: $(this),
                    page_view: self
                });
                self.stories[story_view.story_guid] = story_view;
            }
        });
        
        this.find_story();
    },
    
    detect_scroll: function(){
        if (this.flags.loading_page) {
            return;
        }
        
        var viewport_y = $(window).height() + $(window).scrollTop();

        // this prevents calculating when we are scrolling in previously loaded content        
        if (viewport_y < this.cached_page_control_y) {
            return;
        }
        
        var $controls = this.$('.NB-page-controls');
        if ($controls.length) {
            var page_control_y = $controls.last().offset().top + 25;
            if (viewport_y > page_control_y) {
                this.cached_page_control_y = page_control_y;
                this.flags.loading_page = true;
                this.next_page();
            }
        }
    },
    
    find_story: function() {
        var search_story_guid = NEWSBLUR.router.story_guid;
        if (search_story_guid && this.auto_advance_pages < this.MAX_AUTO_ADVANCED_PAGES) {
            var found_story = _.detect(this.stories, function(story) {
                var hash = story.model.get('story_feed_id') + ":" + story.story_guid;
                return hash.indexOf(search_story_guid) >= 0;
            });
            if (found_story) {
                var found_guid = found_story.story_guid;
                var story_view = this.stories[found_guid];
                _.delay(_.bind(this.scroll_to_story, this, story_view, 1), 0);
                _.delay(_.bind(this.scroll_to_story, this, story_view, 3), 800);
                NEWSBLUR.router.story_guid = null;
            } else {
                this.auto_advance_pages += 1;
                this.next_page();
            }
        }
    },
    
    scroll_to_story: function(story_view, run) {
        var offset = navigator.platform.indexOf("iPhone") != -1 ? 12 : 12 + 48;
        
        $('html,body').stop().animate({
            scrollTop: story_view.$mark.offset().top - offset
        }, {
            duration: run == 1 ? 1000 : 500,
            easing: run == 1 ? 'easeInQuint' : 'easeOutQuint',
            queue: false
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    next_page: function(e) {
        if ($('.NB-page-controls-end').length) return;
        
        var $button = e && $(e.currentTarget) || $('.NB-page-controls-next').last();
        var $next = $('.NB-page-controls-text-next', $button);
        var $loading = $('.NB-page-controls-text-loading', $button);
        var $loaded = $('.NB-page-controls-text-loaded', $button);
        var height = this.$('.NB-page-controls').height();
        var innerheight = $button.height();
        
        $loaded.animate({'bottom': height}, this.next_animation_options);
        $loading.text('Loading...').css('bottom', height).animate({'bottom': innerheight}, this.next_animation_options);
        $next.animate({'bottom': -1 * innerheight}, this.next_animation_options);
        $button.addClass('NB-loading');
        
        clearInterval(this.feed_stories_loading);
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
                'format': 'html',
                'feed_id': NEWSBLUR.router.feed_id
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
        this.flags.loading_page = false;
        
        $button.removeClass('NB-loading').addClass('NB-loaded');
        $button.stop(true).animate({'backgroundColor': '#86B86B'}, {'duration': 750, 'easing': 'easeOutExpo', 'queue': false});
        
        $loaded.text('Page ' + this.page).css('bottom', height).animate({'bottom': innerheight}, this.next_animation_options);
        $loading.animate({'bottom': -1 * innerheight}, this.next_animation_options);
        
        clearInterval(this.feed_stories_loading);
        
        var $stories = $(data);
        $controls.after($stories);
        this.initialize_stories();
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
        this.flags.loading_page = false;
        
        $next.text('Whoops! Something went wrong. Try again.')
             .animate({'bottom': innerheight}, this.next_animation_options);
        $loading.animate({'bottom': height}, this.next_animation_options);
        
        clearInterval(this.feed_stories_loading);
    },
    
    follow_user: function() {
        var $button = this.$(".NB-button-follow");
        $button.html('Following...');
        NEWSBLUR.assets.follow_user(NEWSBLUR.Globals.blurblog_user_id, _.bind(function(data) {
            var message = 'You are now following ' + NEWSBLUR.Globals.blurblog_username;
            if (data.follow_profile.requested_follow) {
                message = 'Your request to follow ' + NEWSBLUR.Globals.blurblog_username + ' has been sent';
            }
            $button.html('Following').removeClass('NB-button-follow')
                                     .removeClass('NB-blue-button')
                                     .addClass('NB-grey-button')
                                     .addClass('NB-button-following');
            this.$('.NB-stat-followers').html("<b>" + data.follow_profile.follower_count + "</b> " + Inflector.pluralize('follower', data.follow_profile.follower_count));
        }, this));
    },
    
    unfollow_user: function() {
        var $button = this.$(".NB-button-following");
        $button.html('Unfollowing...');
        NEWSBLUR.assets.unfollow_user(NEWSBLUR.Globals.blurblog_user_id, _.bind(function(data) {
            $button.html('Follow ' + NEWSBLUR.Globals.blurblog_username).removeClass('NB-button-following')
                                  .removeClass('NB-grey-button')
                                  .addClass('NB-button-follow')
                                  .addClass('NB-blue-button');
            this.$('.NB-stat-followers').html("<b>" + data.unfollow_profile.follower_count + "</b> " + Inflector.pluralize('follower', data.unfollow_profile.follower_count));
        }, this));
    }
    
});

$(document).ready(function() {

    NEWSBLUR.app.social_page = new NEWSBLUR.Views.SocialPage();

});
