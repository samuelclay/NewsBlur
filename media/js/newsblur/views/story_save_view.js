NEWSBLUR.Views.StorySaveView = Backbone.View.extend({
    
    events: {
        "click .NB-feed-story-save"            : "toggle_feed_story_save_dialog"
    },
    
    initialize: function() {
        this.model.story_save_view = this;
    },
    
    render: function() {
        this.$el.html(this.template({
            story: this.model,
            social_services: NEWSBLUR.assets.social_services,
            profile: NEWSBLUR.assets.user_profile
        }));
        
        return this;
    },
    
    template: _.template('\
    <div class="NB-sideoption-save-wrapper">\
        <div class="NB-sideoption-save">\
            Tags\
            <input class="NB-sideoption-save-tag" type="text" />\
        </div>\
    </div>\
    '),
    
    toggle_feed_story_save_dialog: function(options) {
        options = options || {};
        var feed_id = this.model.get('story_feed_id');
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-save');
        var $sideoption_container = this.$('.NB-feed-story-sideoptions-container');
        var $save_wrapper = this.$('.NB-sideoption-save-wrapper');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
        var $story_wrapper = this.$('.NB-story-content-container');
        var $story_comments = this.$('.NB-feed-story-comments');
        var $tag_input = this.$('.NB-sideoption-save-tag');
        
        if (options.close ||
            ($sideoption.hasClass('NB-active') && !options.resize_open)) {
            // Close
            $save_wrapper.animate({
                'height': 0
            }, {
                'duration': 300,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    this.$('.NB-error').remove();
                    if (NEWSBLUR.app.story_list) {
                        NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                    }
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
                        if (NEWSBLUR.app.story_list) {
                            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                        }
                    }
                });
                $story_content.removeData('original_height');
            }
        } else {
            // Open/resize
            if (!options.resize_open) {
                this.$('.NB-error').remove();
            }
            $sideoption.addClass('NB-active');
            
            var $save_clone = $save_wrapper.clone();
            var dialog_height = $save_clone.css({
                'height': 'auto',
                'position': 'absolute',
                'visibility': 'hidden'
            }).appendTo($save_wrapper.parent()).height();
            $save_clone.remove();

            if (options.animate_scroll) {
                var $scroll_container = NEWSBLUR.reader.$s.$story_titles;
                if (_.contains(['split', 'full'], NEWSBLUR.assets.preference('story_layout'))) {
                    $scroll_container = this.model.latest_story_detail_view.$el.parent();
                }
                $scroll_container.stop().scrollTo(this.$el, {
                    duration: 600,
                    queue: false,
                    easing: 'easeInOutQuint',
                    offset: this.model.latest_story_detail_view.$el.height() -
                            $scroll_container.height()
                });
            }
            $save_wrapper.animate({
                'height': dialog_height
            }, {
                'duration': options.immediate ? 0 : 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    if ($tag_input.length == 1) {
                        $tag_input.focus();
                    }
                    if (NEWSBLUR.app.story_list) {
                        NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                    }

                }, this)
            });
            
            var sideoptions_height  = $sideoption_container.outerHeight(true);
            var wrapper_height      = $story_wrapper.height();
            var content_height      = $story_content.height();
            var content_outerheight = $story_content.outerHeight(true);
            var comments_height     = $story_comments.outerHeight(true);
            var container_offset    = $sideoption_container.length &&
                                      ($sideoption_container.position().top - 32);
            
            if (content_outerheight + comments_height < sideoptions_height) {
                $story_content.css('height', $sideoption_container.height());
                $story_content.animate({
                    'height': sideoptions_height + dialog_height - comments_height
                }, {
                    'duration': 350,
                    'easing': 'easeInOutQuint',
                    'queue': false,
                    'complete': function() {
                        if (NEWSBLUR.app.story_list) {
                            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                        }
                    }
                }).data('original_height', content_height);
            } else if (sideoptions_height + dialog_height > wrapper_height) {
                $story_content.animate({
                    'height': content_height + dialog_height - container_offset
                }, {
                    'duration': 350,
                    'easing': 'easeInOutQuint',
                    'queue': false,
                    'complete': function() {
                        if (NEWSBLUR.app.story_list) {
                            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                        }
                    }
                }).data('original_height', content_height);
            } else if (NEWSBLUR.app.story_list) {
                NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
            }
        }
    }
    
});