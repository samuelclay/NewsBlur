NEWSBLUR.Views.SocialPageStory = Backbone.View.extend({
    
    FUDGE_CONTENT_HEIGHT_OVERAGE: 250,
    
    STORY_CONTENT_MAX_HEIGHT: 500, // ALSO CHANGE IN social_page.css
    
    flags: {},
    
    events: {
        "click .NB-story-content-expander": "expand_story"
    },
    
    initialize: function() {
        var story_id = this.$el.data("storyId");
        var feed_id = this.$el.data("feedId");
        var story_guid = this.$el.data("guid");
        var user_comments = this.$el.data("userComments");
        var shared = this.$el.hasClass('NB-story-shared');
        var $sideoptions = this.$('.NB-feed-story-sideoptions-container');
        var story = new Backbone.Model({
            story_feed_id: feed_id,
            id: story_id,
            shared_comments: user_comments,
            shared: shared
        });
        
        this.story_guid = story_guid;
        this.comments_view = new NEWSBLUR.Views.SocialPageComments({
            el: this.$('.NB-story-comments-container'),
            model: story,
            story_view: this
        });
        story.social_page_comments = this.comments_view;
        story.social_page_story = this;
        
        if (NEWSBLUR.Globals.is_authenticated) {
            _.delay(_.bind(function() {
                this.share_view = new NEWSBLUR.Views.StoryShareView({
                    el: this.el,
                    model: story,
                    on_social_page: true
                });
                $sideoptions.append($(this.share_view.template({
                    story: story,
                    social_services: NEWSBLUR.assets.social_services
                })));
            }, this), 50);
        } else {
            _.delay(_.bind(function() {
                this.login_view = new NEWSBLUR.Views.SocialPageLoginView({
                    el: this.el,
                    model: story,
                    story_url: this.story_url()
                });
                $sideoptions.append($(this.login_view.template({
                    story: story
                })));

            }, this), 50);
        }
        
        this.$mark = this.$el.closest('.NB-mark');
        this.attach_tooltips();
        this.truncate_story_height();
        this.watch_images_for_story_height();
    },
    
    attach_tooltips: function() {
        this.$('.NB-user-avatar').tipsy({
            delayIn: 50,
            gravity: 's',
            fade: true,
            offset: 3
        });
    },
    
    truncate_story_height: function() {
        var $expander = this.$(".NB-story-content-expander");
        var $wrapper = this.$(".NB-story-content-wrapper");
        var $content = this.$(".NB-story-content");
        
        var max_height = parseInt($wrapper.css('maxHeight'), 10) || this.STORY_CONTENT_MAX_HEIGHT;
        var content_height = this.$(".NB-story-content").outerHeight();
        
        if (content_height > max_height && 
            content_height < max_height + this.FUDGE_CONTENT_HEIGHT_OVERAGE) {
            // console.log(["Height over but within fudge", content_height, max_height]);
            $wrapper.addClass('NB-story-content-wrapper-height-fudged');
        } else if (content_height > max_height) {
            $expander.css('display', 'block');
            $wrapper.removeClass('NB-story-content-wrapper-height-fudged');
            $wrapper.addClass('NB-story-content-wrapper-height-truncated');
            var pages = Math.round(content_height / max_height, true);
            var dots = _.map(_.range(pages), function() { return '&middot;'; }).join(' ');
            
            // console.log(["Height over, truncating...", content_height, max_height, pages]);
            this.$(".NB-story-content-expander-pages").html(dots);
        } else {
            // console.log(["Height under.", content_height, max_height]);
        }
    },
    
    watch_images_for_story_height: function() {
        this.$('img').load(_.bind(function() {
            this.truncate_story_height();
        }, this));
    },
    
    story_url: function() {
        var guid = this.story_guid.substr(0, 6);
        var url = window.location.protocol + '//' + window.location.host + '/story/' + guid;

        return url;
    },
    
    // ==========
    // = Events =
    // ==========
    
    expand_story: function() {
        var $expander = this.$(".NB-story-content-expander");
        var $wrapper = this.$(".NB-story-content-wrapper");
        var $content = this.$(".NB-story-content");
        var max_height = parseInt($wrapper.css('maxHeight'), 10) || this.STORY_CONTENT_MAX_HEIGHT;
        var content_height = this.$(".NB-story-content").height();
        var height_ratio = content_height / max_height;
        
        $wrapper.removeClass('NB-story-content-wrapper-height-truncated');
        // console.log(["max height", max_height, content_height, content_height / max_height]);
        $wrapper.animate({
            maxHeight: content_height
        }, {
            duration: parseInt(350 * height_ratio, 10),
            easing: 'easeOutQuart'
        });
        
        $expander.animate({
            bottom: -1 * $expander.outerHeight()
        }, {
            duration: parseInt(350 * height_ratio, 10),
            easing: 'easeOutQuart'
        });
    }
    
});