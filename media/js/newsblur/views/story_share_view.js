NEWSBLUR.Views.StoryShareView = Backbone.View.extend({
    
    events: {
        "click .NB-feed-story-share"            : "toggle_feed_story_share_dialog",
        "click .NB-sideoption-share-save"       : "mark_story_as_shared",
        "keyup .NB-sideoption-share-comments"   : "update_share_button_label"
    },
    
    initialize: function() {
        this.model.story_share_view = this;
    },
    
    render: function() {
        this.$el.html(this.template({
            story: this.model
        }));
        
        return this;
    },
    
    template: _.template('\
    <div class="NB-sideoption-share-wrapper">\
        <div class="NB-sideoption-share">\
            <div class="NB-sideoption-share-wordcount"></div>\
            <div class="NB-sideoption-share-optional">Optional</div>\
            <div class="NB-sideoption-share-title">Comments:</div>\
            <textarea class="NB-sideoption-share-comments"><%= story.get("shared_comments") %></textarea>\
            <div class="NB-menu-manage-story-share-save NB-modal-submit-green NB-sideoption-share-save NB-modal-submit-button">Share</div>\
        </div>\
    </div>\
    '),
    
    toggle_feed_story_share_dialog: function(options) {
        options = options || {};
        var feed_id = this.model.get('story_feed_id');
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-share');
        var $share = this.$('.NB-sideoption-share-wrapper');
        var $story_content = this.$('.NB-feed-story-content');
        var $comment_input = this.$('.NB-sideoption-share-comments');
        var $story_comments = this.$('.NB-feed-story-comments');
        
        if (options.close ||
            ($sideoption.hasClass('NB-active') && !options.resize_open)) {
            // Close
            $share.animate({
                'height': 0
            }, {
                'duration': 300,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    this.$('.NB-error').remove();
                }, this)
            });
            $sideoption.removeClass('NB-active');
            if ($story_content.data('original_height')) {
                $story_content.animate({
                    'height': $story_content.data('original_height')
                }, {
                    'duration': 300,
                    'easing': 'easeInOutQuint',
                    'queue': false,
                    'complete': function() {
                        NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                    }
                });
                $story_content.removeData('original_height');
            }
        } else {
            // Open/resize
            $sideoption.addClass('NB-active');
            var $share_clone = $share.clone();
            var full_height = $share_clone.css({
                'height': 'auto',
                'position': 'absolute',
                'visibility': 'hidden'
            }).appendTo($share.parent()).height();
            $share_clone.remove();
            $share.animate({
                'height': full_height
            }, {
                'duration': options.immediate ? 0 : 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': function() {
                    $comment_input.focus();
                }
            });
        
            var sideoptions_height = this.$('.NB-feed-story-sideoptions-container').innerHeight() + 12;
            var content_height = $story_content.innerHeight() + $story_comments.innerHeight();

            if (sideoptions_height + full_height > content_height) {
                // this.$s.$feed_stories.scrollTo(this.$s.$feed_stories.scrollTop() + sideoptions_height, {
                //     'duration': 350,
                //     'queue': false,
                //     'easing': 'easeInOutQuint'
                // });
                var original_height = $story_content.height();
                $story_content.animate({
                    'height': original_height + ((full_height + sideoptions_height) - content_height)
                }, {
                    'duration': 350,
                    'easing': 'easeInOutQuint',
                    'queue': false,
                    'complete': function() {
                        NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                    }
                }).data('original_height', original_height);
            }
            this.update_share_button_label();
            var share = _.bind(function(e) {
                e.preventDefault();
                this.mark_story_as_shared({'source': 'sideoption'});
            }, this);
            var $comments = $('.NB-sideoption-share-comments', $share);
            $comments.unbind('keydown')
                     .bind('keydown', 'ctrl+return', share)
                     .bind('keydown', 'meta+return', share);

        }
    },
    
    mark_story_as_shared: function(options) {
        options = options || {};
        var $share_star = this.model.story_title_view.$('.NB-storytitles-share');
        var $share_button = this.$('.NB-sideoption-share-save');
        var $share_button_menu = $('.NB-menu-manage-story-share-save');
        var $share_menu = $share_button_menu.closest('.NB-sideoption-share');
        var $share_sideoption = this.model.story_view.$('.NB-feed-story-share .NB-sideoption-title');
        var $comments_sideoptions = this.$('.NB-sideoption-share-comments');
        var $comments_menu = $('.NB-sideoption-share-comments', $share_menu);
        var comments = _.string.trim((options.source == 'menu' ? $comments_menu : $comments_sideoptions).val());
        var feed = NEWSBLUR.reader.model.get_feed(NEWSBLUR.reader.active_feed);
        var source_user_id = feed && feed.get('user_id');
        
        this.model.set("shared", true);
        $share_button.addClass('NB-saving').addClass('NB-disabled').text('Sharing...');
        $share_button_menu.addClass('NB-saving').addClass('NB-disabled').text('Sharing...');
        NEWSBLUR.assets.mark_story_as_shared(this.model.id, this.model.get('story_feed_id'), comments, source_user_id, _.bind(function() {
            this.toggle_feed_story_share_dialog({'close': true});
            NEWSBLUR.reader.hide_confirm_story_share_menu_item(true);
            $share_button.removeClass('NB-saving').removeClass('NB-disabled').text('Share');
            $share_sideoption.text('Shared').closest('.NB-sideoption');
            this.model.story_view.$el.addClass('NB-story-shared');
            $comments_menu.val(comments);
            $comments_sideoptions.val(comments);
            this.model.story_view.render_comments();
            
            $share_star.attr({'title': 'Shared!'});
            $share_star.tipsy({
                gravity: 'sw',
                fade: true,
                trigger: 'manual',
                offsetOpposite: -1
            });
            var tipsy = $share_star.data('tipsy');
            tipsy.enable();
            tipsy.show();

            _.delay(function() {
                if (tipsy.enabled) {
                    tipsy.hide();
                    tipsy.disable();
                }
            }, 850);
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }, this), _.bind(function(data) {
            var message = data && data.message || "Sorry, this story could not be shared. Probably a bug.";
            if (!NEWSBLUR.Globals.is_authenticated) {
                message = "You need to be logged in to share a story.";
            }
            var $error = $.make('div', { className: 'NB-error' }, message);
            $share_button.removeClass('NB-saving').removeClass('NB-disabled').text('Share');
            $share_button.siblings('.NB-error').remove();
            $share_button.after($error);
            if ($share_button_menu.length) {
                $share_button_menu.removeClass('NB-disabled').text('Share');
                $share_button_menu.siblings('.NB-error').remove();
                $share_button_menu.after($error.clone());
            }
            this.toggle_feed_story_share_dialog({'resize_open': true});
        }, this));
        
        NEWSBLUR.reader.blur_to_page();
    },
    
    update_share_button_label: function() {
        var $share = this.$('.NB-sideoption-share');
        var $comment_input = this.$('.NB-sideoption-share-comments');
        var $share_button = this.$('.NB-sideoption-share-save,.NB-menu-manage-story-share-save');
        
        $share_button.removeClass('NB-saving').removeClass('NB-disabled');
        
        if (!_.string.isBlank($comment_input.val())) {
            $share_button.text('Share with comment');
        } else {
            $share_button.text('Share');
        }
    },
    
    count_selected_words_when_sharing_story: function($feed_story) {
        var $wordcount = $('.NB-sideoption-share-wordcount', $feed_story);
        
    }
        
});