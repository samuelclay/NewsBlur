NEWSBLUR.Views.StorySaveView = Backbone.View.extend({
    
    events: {
        "click .NB-feed-story-save" : "toggle_feed_story_save_dialog",
        "click .NB-sideoption-save-populate" : "populate_story_tags"
    },
    
    initialize: function() {
        this.model.story_save_view = this;
    },
    
    render: function() {
        return this.template({
            story: this.model,
            tags: this.existing_tags(),
            story_tags: this.unused_story_tags(),
            social_services: NEWSBLUR.assets.social_services,
            profile: NEWSBLUR.assets.user_profile
        });
    },
    
    existing_tags: function() {
        var tags = this.model.get('user_tags');

        if (!tags) {
            tags = this.folder_tags();
        }
        
        return tags || [];
    },
    
    template: _.template('\
    <div class="NB-sideoption-save-wrapper">\
        <div class="NB-sideoption-save">\
            <div class="NB-sideoption-save-populate">\
                Add <%= Inflector.pluralize("story tag", story_tags.length, true) %>\
            </div>\
            <div class="NB-sideoption-title">Tags</div>\
            <ul class="NB-sideoption-save-tag">\
                <% _.each(tags, function(tag) { %>\
                    <li><%= tag %></li>\
                <% }) %>\
            </ul>\
        </div>\
    </div>\
    '),
    
    populate_story_tags: function() {
        var $populate = this.$('.NB-sideoption-save-populate');
        var $tag_input = this.$('.NB-sideoption-save-tag');
        var tags = this.model.get('story_tags');

        $populate.fadeOut(500);
        _.each(tags, function(tag) {
            $tag_input.tagit('createTag', tag);
        });
        
        this.toggle_feed_story_save_dialog({resize_open:true});
    },
    
    unused_story_tags: function() {
        var tags = _.reduce(this.model.get('user_tags') || [], function(m, t) {
            return _.without(m, t);
        }, this.model.get('story_tags'));
        return tags;
    },
    
    folder_tags: function() {
        var folder_tags = [];
        var feed_id = this.model.get('story_feed_id');
        var feed = NEWSBLUR.assets.get_feed(feed_id);
        if (feed) {
            folder_tags = feed.parent_folder_names();
        }
        return folder_tags;
    },
    
    all_tags: function() {
        var tags = [];
        var story_tags = this.model.get('story_tags') || [];
        var user_tags = this.model.get('user_tags') || [];
        var folder_tags = this.folder_tags();
        var all_tags = story_tags.concat(user_tags).concat(folder_tags);
        
        console.log(["all_tags", all_tags]);
        return all_tags;
    },
    
    toggle_feed_story_save_dialog: function(options) {
        options = options || {};
        var self = this;
        var feed_id = this.model.get('story_feed_id');
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-save');
        var $save_wrapper = this.$('.NB-sideoption-save-wrapper');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
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
            $tag_input.tagit({
                fieldName: "tags",
                availableTags: this.all_tags(),
                autocomplete: {delay: 0, minLength: 0},
                showAutocompleteOnFocus: false,
                removeConfirmation: true,
                caseSensitive: false,
                allowDuplicates: false,
                allowSpaces: true,
                readOnly: false,
                tagLimit: null,
                singleField: false,
                singleFieldDelimiter: ',',
                singleFieldNode: null,
                tabIndex: null,

                // Events
                afterTagAdded: function(event, ui) {
                    self.resize();
                },
                afterTagRemoved: function(event, ui) {
                    self.resize();
                }
            });
            $tag_input.tagit('addClassAutocomplete', 'NB-tagging-autocomplete');
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
            
            this.resize(options);
        }
    },
    
    resize: function(options) {
        options = options || {};
        var $sideoption_container = this.$('.NB-feed-story-sideoptions-container');
        var $save_wrapper = this.$('.NB-sideoption-save-wrapper');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
        var $story_wrapper = this.$('.NB-story-content-container');
        var $story_comments = this.$('.NB-feed-story-comments');
        var $tag_input = this.$('.NB-sideoption-save-tag');
        
        var $save_clone = $save_wrapper.clone();
        var dialog_height = $save_clone.css({
            'height': 'auto',
            'position': 'absolute',
            'visibility': 'hidden'
        }).appendTo($save_wrapper.parent()).height();
        $save_clone.remove();

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
        var left_height         = content_outerheight + comments_height;
        var container_offset    = $sideoption_container.length &&
                                  ($sideoption_container.position().top - 32);
        
        console.log(["heights", dialog_height, sideoptions_height, wrapper_height, content_height, content_outerheight, comments_height, left_height, container_offset]);
        if (left_height < sideoptions_height) {
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
    
});