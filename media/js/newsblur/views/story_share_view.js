NEWSBLUR.Views.StoryShareView = Backbone.View.extend({
    
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
                'complete': function() {
                    this.$('.NB-error').remove();
                }
            });
            $sideoption.removeClass('NB-active');
            if ($story_content.data('original_height')) {
                $story_content.animate({
                    'height': $story_content.data('original_height')
                }, {
                    'duration': 300,
                    'easing': 'easeInOutQuint',
                    'queue': false
                    // 'complete': _.bind(this.fetch_story_locations_in_feed_view, this, {'reset_timer': true})
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
                'duration': 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': function() {
                    $comment_input.focus();
                }
            });
        
            var sideoptions_height = this.$('.NB-feed-story-sideoptions-container').innerHeight() + 12;
            var content_height = $story_content.innerHeight() + $story_comments.innerHeight();
            // console.log(["heights", full_height + sideoptions_height, content_height]);
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
                    'queue': false
                    // 'complete': _.bind(this.fetch_story_locations_in_feed_view, this, {'reset_timer': true})
                }).data('original_height', original_height);
            }
            this.update_share_button_label($comment_input);
            var share = _.bind(function(e) {
                e.preventDefault();
                this.mark_story_as_shared({'source': 'sideoption'});
            }, this);
            $('.NB-sideoption-share-comments', $share).bind('keydown', 'ctrl+return', share);
            $('.NB-sideoption-share-comments', $share).bind('keydown', 'meta+return', share);

        }
    },
    
    mark_story_as_shared: function(options) {
        options = options || {};
        var $story_title = this.find_story_in_story_titles(this.model.id);
        var $feed_story = this.find_story_in_feed_view(this.model.id);
        var $share_star = $('.NB-storytitles-share', $story_title);
        var $share_button = $('.NB-sideoption-share-save', $feed_story);
        var $share_button_menu = $('.NB-menu-manage-story-share-save');
        var $share_menu = $share_button_menu.closest('.NB-sideoption-share');
        var $share_sideoption = $('.NB-feed-story-share .NB-sideoption-title', $feed_story);
        var $comments_sideoptions = $('.NB-sideoption-share-comments', $feed_story);
        var $comments_menu = $('.NB-sideoption-share-comments', $share_menu);
        var comments = _.string.trim((options.source == 'menu' ? $comments_menu : $comments_sideoptions).val());
        var feed = NEWSBLUR.reader.model.get_feed(NEWSBLUR.reader.active_feed);
        var source_user_id = feed && feed.get('user_id');
        
        $story_title.addClass('NB-story-shared');
        $share_button.addClass('NB-saving').addClass('NB-disabled').text('Sharing...');
        $share_button_menu.addClass('NB-saving').addClass('NB-disabled').text('Sharing...');
        this.model.mark_story_as_shared(story.get('story_feed_id'), comments, source_user_id, _.bind(function(data) {
            this.toggle_feed_story_share_dialog({'close': true});
            this.hide_confirm_story_share_menu_item(true);
            $share_button.removeClass('NB-saving').removeClass('NB-disabled').text('Share');
            $share_sideoption.text('Shared').closest('.NB-sideoption');
            $feed_story.addClass('NB-story-shared');
            $comments_menu.val(comments);
            $comments_sideoptions.val(comments);
            var $new_comments = $.make('div', { className: 'NB-feed-story-comments' }, new NEWSBLUR.Views.StoryComment({
                model: comment, 
                story: this.model
            }).el);
            var $old_comments = $('.NB-feed-story-comments', $feed_story);
            if (!$old_comments.length) {
                $old_comments = $.make('div', { className: 'NB-feed-story-comments' });
                $('.NB-feed-story-content', $feed_story).after($old_comments);
            }
            $old_comments.replaceWith($new_comments);
            
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

            $share_star.animate({
                'opacity': 1
            }, {
                'duration': 850,
                'queue': false,
                'complete': function() {
                    if (tipsy.enabled) {
                        tipsy.hide();
                        tipsy.disable();
                    }
                }
            });
            // this.fetch_story_locations_in_feed_view({'reset_timer': true});
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
                $share_button_text.removeClass('NB-disabled').text('Share');
                $share_button_text.siblings('.NB-error').remove();
                $share_button_text.after($error.clone());
            }
            this.toggle_feed_story_share_dialog({'resize_open': true});
        }, this));
        
        this.blur_to_page();
    },
    
    update_share_button_label: function($t) {
        if (!$t) $t = $('.NB-menu-manage-story-share-save');
        var $share = $t.closest('.NB-sideoption-share');
        var $comment_input = $('.NB-sideoption-share-comments', $share);
        var $share_button = $('.NB-sideoption-share-save,.NB-menu-manage-story-share-save', $share);

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