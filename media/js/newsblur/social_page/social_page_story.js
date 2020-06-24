NEWSBLUR.Views.SocialPageStory = Backbone.View.extend({
    
    FUDGE_CONTENT_HEIGHT_OVERAGE: 250,
    
    STORY_CONTENT_MAX_HEIGHT: 400, // ALSO CHANGE IN social_page.css
    
    flags: {},
    
    events: {
        "click .NB-story-content-expander"  : "expand_story",
        "focus .NB-story-comment-input"     : "focus_comment_input",
        // "blur .NB-story-comment-input"      : "blur_comment_input"
        "keyup .NB-story-comment-input"     : "keypress_comment_input",
        "click .NB-story-comment-save"      : "mark_story_as_shared",
        "click .NB-story-comment-crosspost-twitter"  : "toggle_twitter",
        "click .NB-story-comment-crosspost-facebook" : "toggle_facebook"
    },
    
    initialize: function() {
        var story_id = this.$el.data("storyId");
        var feed_id = this.$el.data("feedId");
        // attr because .data munges numeral guids (ex: 002597 vs. a05bd2)
        var story_guid = ""+this.$el.attr("data-guid"); 
        var user_comments = this.$el.data("userComments");
        var shared = this.$el.hasClass('NB-story-shared');
        var $sideoptions = this.$('.NB-feed-story-sideoptions-container');
        this.model = new Backbone.Model({
            story_feed_id: feed_id,
            id: story_id,
            shared_comments: user_comments,
            shared: shared
        });
        
        this.story_guid = story_guid;

        this.comments_view = new NEWSBLUR.Views.SocialPageComments({
            el: this.$('.NB-story-comments'),
            model: this.model,
            story_view: this,
            page_view: this.options.page_view
        });
        this.model.social_page_comments = this.comments_view;

        this.shares_view = new NEWSBLUR.Views.SocialPageSharesView({
            el: this.$('.NB-story-shares'),
            model: this.model,
            story_view: this
        });
        this.model.social_page_shares = this.shares_view;
        this.model.social_page_story = this;
        
        if (NEWSBLUR.Globals.is_authenticated) {
            _.delay(_.bind(function() {
                this.share_view = new NEWSBLUR.Views.StoryShareView({
                    el: this.el,
                    model: this.model,
                    on_social_page: true
                });
                $sideoptions.append($(this.share_view.template({
                    story: this.model,
                    social_services: NEWSBLUR.assets.social_services,
                    profile: NEWSBLUR.assets.user_profile
                })));
            }, this), 50);
        }
        
        this.$mark = this.$el.closest('.NB-mark');
        this.attach_tooltips();
        this.attach_keyboard();
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
    
    attach_keyboard: function() {
        var $input = this.$('.NB-story-comment-input');
        
        $input.bind('keydown', 'esc', _.bind(this.blur_comment_input, this));
        $input.bind('keydown', 'meta+return', _.bind(this.mark_story_as_shared, this));
        $input.bind('keydown', 'ctrl+return', _.bind(this.mark_story_as_shared, this));
    },
    
    truncate_story_height: function() {
        var $expander = this.$(".NB-story-content-expander");
        var $expander_cutoff = this.$(".NB-story-cutoff");
        var $wrapper = this.$(".NB-story-content-wrapper");
        var $content = this.$(".NB-story-content");
        
        var max_height = parseInt($wrapper.css('maxHeight'), 10) || this.STORY_CONTENT_MAX_HEIGHT;
        var content_height = $content.outerHeight(true);
        
        if (content_height > max_height && 
            content_height < max_height + this.FUDGE_CONTENT_HEIGHT_OVERAGE) {
            // console.log(["Height over but within fudge", content_height, max_height]);
            $wrapper.addClass('NB-story-content-wrapper-height-fudged');
        } else if (content_height > max_height) {
            $expander.css('display', 'block');
            $expander_cutoff.css('display', 'block');
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
        this.$('img').on('load', _.bind(function() {
            this.truncate_story_height();
        }, this));
    },
    
    story_url: function() {
        var guid = this.story_guid.substr(0, 6);
        var url = window.location.protocol + '//' + window.location.host + '/story/' + guid;

        return url;
    },
    
    // ===========
    // = Actions =
    // ===========
    
    replace_shares_and_comments: function(html) {
        var $new_story = $(html);
        var $new_comments = $('.NB-story-comments', $new_story);
        var $new_shares = $('.NB-story-shares', $new_story);

        this.comments_view.replace_comments($new_comments);
        this.shares_view.replace_shares($new_shares);
        this.attach_tooltips();
        this.attach_keyboard();
    },
    
    mark_story_as_shared: function(options) {
        options = options || {};
        var $input = this.$('.NB-story-comment-input');
        var $submit = this.$('.NB-story-comment-save');
        
        var comments = _.string.trim($input.val());
        var source_user_id = NEWSBLUR.Globals.blurblog_user_id;
        var relative_user_id = NEWSBLUR.Globals.blurblog_user_id;
        var post_to_services = _.compact([
            NEWSBLUR.assets.preference('post_to_twitter') && 'twitter',
            NEWSBLUR.assets.preference('post_to_facebook') && 'facebook'
        ]);
        
        $submit.addClass('NB-saving').addClass('NB-disabled').text('Sharing...');
        var data = {
            story_id: this.model.id, 
            story_feed_id: this.model.get('story_feed_id'), 
            comments: comments, 
            source_user_id: source_user_id,
            relative_user_id: relative_user_id,
            post_to_services: post_to_services
        };
        NEWSBLUR.assets.mark_story_as_shared(data, _.bind(this.post_share_story, this, true), _.bind(function(data) {
            this.post_share_error(data, true);
        }, this));
        
        if (NEWSBLUR.reader) {
            NEWSBLUR.reader.blur_to_page();
        }
    },
    
    post_share_story: function(shared, data) {
        this.model.set("shared", shared);
        
        this.$el.toggleClass('NB-story-shared', this.model.get('shared'));
        this.replace_shares_and_comments(data);
    },
    
    post_share_error: function(data, shared) {
        var $share_button = this.$('.NB-sideoption-share-save');
        var $unshare_button = this.$('.NB-sideoption-share-unshare');
        var $share_button_menu = $('.NB-menu-manage .NB-menu-manage-story-share-save');
        var message = data && data.message || ("Sorry, this story could not be " + (shared ? "" : "un") + "shared. Probably Adblock.");
        
        if (!NEWSBLUR.Globals.is_authenticated) {
            message = "You need to be logged in to share a story.";
        }
        var $error = $.make('div', { className: 'NB-error' }, message);
        
        $share_button.removeClass('NB-saving').removeClass('NB-disabled').text('Share');
        $unshare_button.removeClass('NB-saving').removeClass('NB-disabled').text('Delete Share');
        $share_button.siblings('.NB-error').remove();
        $share_button.after($error);
        
        if ($share_button_menu.length) {
            $share_button_menu.removeClass('NB-disabled').text('Share');
            $share_button_menu.siblings('.NB-error').remove();
            $share_button_menu.after($error.clone());
        }
        NEWSBLUR.log(["post_share_error", data, shared, message, $share_button, $unshare_button, $share_button_menu, $error]);
    },
    
    mark_story_as_unshared: function(options) {
        options = options || {};
        var $unshare_button = this.$('.NB-story-comment-delete');
        $unshare_button.addClass('NB-saving').addClass('NB-disabled').text('Deleting...');
        
        var params = {
            story_id: this.model.id, 
            story_feed_id: this.model.get('story_feed_id'),
            relative_user_id: NEWSBLUR.Globals.blurblog_user_id
        };
        NEWSBLUR.assets.mark_story_as_unshared(params, _.bind(this.post_share_story, this, false), _.bind(function(data) {
            this.post_share_error(data, false);
        }, this));
    },
    
    check_crosspost_buttons: function() {
        var $twitter = this.$('.NB-story-comment-crosspost-twitter');
        var $facebook = this.$('.NB-story-comment-crosspost-facebook');

        if (!NEWSBLUR.user_social_services) return;
        
        if (NEWSBLUR.user_social_services.twitter &&
            NEWSBLUR.user_social_services.twitter.twitter_uid) {
            $twitter.removeClass('NB-hidden');
        }
        if (NEWSBLUR.user_social_services.facebook &&
            NEWSBLUR.user_social_services.facebook.facebook_uid) {
            $facebook.removeClass('NB-hidden');
        }
        
        $twitter.toggleClass('NB-active', !!NEWSBLUR.assets.preference('post_to_twitter'));
        $facebook.toggleClass('NB-active', !!NEWSBLUR.assets.preference('post_to_facebook'));
    },
    
    // ==========
    // = Events =
    // ==========
     
    expand_story: function(options) {
        options = options || {};
        var $expander = this.$(".NB-story-content-expander");
        var $expander_cutoff = this.$(".NB-story-cutoff");
        var $wrapper = this.$(".NB-story-content-wrapper");
        var $content = this.$(".NB-story-content");
        var max_height = parseInt($wrapper.css('maxHeight'), 10) || this.STORY_CONTENT_MAX_HEIGHT;
        var content_height = $content.outerHeight(true);
        var height_ratio = content_height / max_height;
        
        if (content_height < max_height) return;
        $wrapper.removeClass('NB-story-content-wrapper-height-truncated');
        // console.log(["max height", max_height, content_height, content_height / max_height]);
        $wrapper.animate({
            maxHeight: content_height
        }, {
            duration: options.instant ? 0 : Math.min(2 * 1000, parseInt(200 * height_ratio, 10)),
            easing: 'easeInOutQuart'
        });
        
        $expander.add($expander_cutoff).animate({
            bottom: -1 * $expander.outerHeight() - 48
        }, {
            duration: options.instant ? 0 : Math.min(2 * 1000, parseInt(200 * height_ratio, 10)),
            easing: 'easeInOutQuart'
        });
        
    },
    
    focus_comment_input: function() {
        console.log("in focus_comment_input");
        var $form = this.$('.NB-story-comment-input-form');
        var $input = this.$('.NB-story-comment-input');
        var $buttons = this.$('.NB-story-comment-buttons');
        
        // $form.toggleClass('NB-active', $input.is(':focus'));
        $buttons.css('display', 'block');
        $form.addClass('NB-active');
        this.check_crosspost_buttons();
        this.keypress_comment_input();
        this.reset_posting_label();
    },
    
    blur_comment_input: function() {
        var $buttons = this.$('.NB-story-comment-buttons');
        var $form = this.$('.NB-story-comment-input-form');
        var $input = this.$('.NB-story-comment-input');

        $buttons.css('display', 'none');
        $form.removeClass('NB-active');
        $input.blur();
        
        if (this.model.get('shared')) {
            this.$('.NB-story-comment.NB-hidden').removeClass('NB-hidden');
            this.$('.NB-story-comment-edit').addClass('NB-hidden');
        }
    },
    
    keypress_comment_input: function() {
        var $input = this.$('.NB-story-comment-input');
        var $save = this.$('.NB-story-comment-save');
        
        if (!_.string.isBlank($input.val())) {
            $save.text('Share with comments');
        } else {
            $save.text("Share this story");
        }
        
        var input_width = $input.innerWidth();
        // Perform auto-height expansion
    },
    
    toggle_twitter: function() {
        var $twitter_button = this.$('.NB-story-comment-crosspost-twitter');
        
        if (NEWSBLUR.assets.preference('post_to_twitter')) {
            NEWSBLUR.assets.preference('post_to_twitter', false);
        } else {
            NEWSBLUR.assets.preference('post_to_twitter', true);
        }
        
        $twitter_button.toggleClass('NB-active', NEWSBLUR.assets.preference('post_to_twitter'));
        this.reset_posting_label();
    },
    
    toggle_facebook: function() {
        var $facebook_button = this.$('.NB-story-comment-crosspost-facebook');
        
        if (NEWSBLUR.assets.preference('post_to_facebook')) {
            NEWSBLUR.assets.preference('post_to_facebook', false);
        } else {
            NEWSBLUR.assets.preference('post_to_facebook', true);
        }
        
        $facebook_button.toggleClass('NB-active', NEWSBLUR.assets.preference('post_to_facebook'));
        this.reset_posting_label();
    },
    
    show_twitter_posting_label: function() {
        this.show_posting_label(true, false);
    },
    
    show_facebook_posting_label: function() {
        this.show_posting_label(false, true);
    },
    
    reset_posting_label: function() {
        this.show_posting_label();
    },
    
    show_posting_label: function(twitter, facebook) {
        var social_services = NEWSBLUR.user_social_services || {};
        var $text = this.$('.NB-story-comment-crosspost-text');
        twitter = twitter || (social_services.twitter && social_services.twitter.twitter_uid && NEWSBLUR.assets.preference('post_to_twitter'));
        facebook = facebook || (social_services.facebook && social_services.facebook.facebook_uid && NEWSBLUR.assets.preference('post_to_facebook'));
        
        if (twitter || facebook) {
            var message = "Post to ";
            if (twitter && !facebook) {
                message += "Twitter";
            } else if (!twitter && facebook) {
                message += "Facebook";
            } else {
                message += "Twitter & FB";
            }
            
            $text.text(message);
        } else {
            $text.text("");
        }
    }
    
});