NEWSBLUR.Views.StorySaveView = Backbone.View.extend({
    
    events: {
        "click .NB-sideoption-save-populate" : "populate_story_tags",
        "keypress .NB-sideoption-save-notes" : "autosize",
        "keyup .NB-sideoption-save-notes"   : "debounced_save_user_notes",
        "change .NB-sideoption-save-notes"   : "save_user_notes"
    },
    
    initialize: function() {
        this.debounced_save_user_notes = _.debounce(this.save_user_notes, 1000);
        _.bindAll(this, 'toggle_feed_story_save_dialog', 'save_user_notes', 'autosize', 'debounced_save_user_notes');
        this.sideoptions_view = this.options.sideoptions_view;
        this.model.story_save_view = this;
        this.model.bind('change:starred', this.toggle_feed_story_save_dialog);
    },
    
    render: function() {
        return this.template({
            story: this.model,
            tags: this.model.existing_tags(),
            story_tags: this.model.unused_story_tags(),
            social_services: NEWSBLUR.assets.social_services,
            profile: NEWSBLUR.assets.user_profile
        });
    },
    
    template: _.template('\
    <div class="NB-sideoption-save-wrapper <% if (story.get("starred")) { %>NB-active<% } %>">\
        <div class="NB-sideoption-save">\
            <% if (story_tags.length) { %>\
                <div class="NB-sideoption-save-populate">\
                    Add <%= Inflector.pluralize("story tag", story_tags.length, true) %>\
                </div>\
            <% } %>\
            <div class="NB-sideoption-save-icon"></div>\
            <div class="NB-sideoption-save-title">\
                Tags:\
            </div>\
            <ul class="NB-sideoption-save-tag">\
                <% _.each(tags, function(tag) { %>\
                    <li><%= tag %></li>\
                <% }) %>\
            </ul>\
            <div class="NB-sideoption-save-message">Saved</div>\
            <div class="NB-sideoption-save-title">Private notes:</div>\
            <textarea class="NB-sideoption-save-notes"><%= story.get("user_notes") %></textarea>\
        </div>\
    </div>\
    '),
    
    populate_story_tags: function() {
        var $populate = this.$('.NB-sideoption-save-populate');
        var $tag_input = this.$('.NB-sideoption-save-tag');
        var tags = this.model.get('story_tags');

        $populate.fadeOut(500);
        _.each(tags, function(tag) {
            $tag_input.tagit('createTag', tag, null, true);
        });
        
        this.toggle_feed_story_save_dialog({resize_open:true});
        this.save_tags();
    },
    
    toggle_feed_story_save_dialog: function(options) {
        options = options || {};
        var self = this;
        var feed_id = this.model.get('story_feed_id');
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-save');
        var $save_wrapper = this.$('.NB-sideoption-save-wrapper');
        var $tag_input = this.$('.NB-sideoption-save-tag');
        
        if (options.close || !this.model.get('starred')) {
            // Close
            this.is_open = false;
            this.resize({close: true});
        } else {
            // Open/resize
            this.is_open = true;
            if (!options.resize_open) {
                this.$('.NB-error').remove();
            }
            $tag_input.tagit({
                fieldName: "tags",
                availableTags: this.model.all_tags(),
                autocomplete: {delay: 0, minLength: 0},
                showAutocompleteOnFocus: true,
                createTagOnBlur: false,
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

                afterTagAdded: function(event, options) {
                    options = options || {};
                    if (!options.duringInitialization) {
                        self.resize({change_tag: true});
                        self.save_tags();
                    }
                },
                afterTagRemoved: function(event, duringInitialization) {
                    options = options || {};
                    if (!options.duringInitialization) {
                        self.resize({change_tag: true});
                        self.save_tags();
                    }
                }
            });
            $tag_input.tagit('addClassAutocomplete', 'NB-tagging-autocomplete');
            this.$('textarea').autosize();

            if (options.animate_scroll) {
                var $scroll_container = NEWSBLUR.reader.$s.$story_titles;
                if (_.contains(['split', 'full'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
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

    autosize: function() {
        this.resize({duration: 100, resize_open: true});
    },

    resize: function(options) {
        options = options || {};
        var $sideoption_container = this.$('.NB-feed-story-sideoptions-container');
        var $save_wrapper = this.$('.NB-sideoption-save-wrapper');
        var $save_content = this.$('.NB-sideoption-save');
        var $user_notes = this.$('.NB-sideoption-save-notes');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
        var $story_comments = this.$('.NB-feed-story-comments');
        var $sideoption = this.$('.NB-feed-story-save');
        var $tag_input = this.$('.NB-sideoption-save-tag');

        var $save_clone = $save_wrapper.clone();
        $save_wrapper.after($save_clone.css({
            'height': options.close ? 0 : 'auto',
            'position': 'absolute',
            'visibility': 'hidden',
            'display': 'block'
        }));
        var sideoption_content_height = $save_clone.height();
        $save_clone.remove();
        var new_sideoptions_height = $sideoption_container.height() - $save_wrapper.height() + sideoption_content_height;
        // console.log(['Save options height', new_sideoptions_height, $sideoption_container.height(), $save_wrapper.height(), sideoption_content_height])
        if (!options.close) {
            $sideoption.addClass('NB-active');
            $save_wrapper.addClass('NB-active');
        }

        if (!options.resize_open && !options.close && !options.change_tag) {
            $save_wrapper.css('height', '0px');
        }
        $save_wrapper.animate({
            'height': sideoption_content_height
        }, {
            'duration': options.immediate ? 0 : options.duration || 350,
            'easing': 'easeInOutQuint',
            'queue': false,
            'complete': _.bind(function() {
                if ($tag_input.length == 1) {
                    $tag_input.focus();
                }
                if (NEWSBLUR.app.story_list) {
                    NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                }
                if (options.close) {
                    $sideoption.removeClass('NB-active');
                    $save_wrapper.removeClass('NB-active');
                }
            }, this)
        });
        
        var sideoptions_height  = $sideoption_container.height();
        var content_height      = $story_content.height();
        var comments_height     = $story_comments.height();
        var left_height         = content_height + comments_height;
        var original_height     = $story_content.data('original_height') || content_height;
        if (!NEWSBLUR.reader.flags.narrow_content &&
            !options.close && !options.force && new_sideoptions_height >= original_height) {
            // Sideoptions too big, embiggen left side
            console.log(["Sideoption too big, embiggening", content_height, sideoptions_height, new_sideoptions_height]);
            $story_content.stop(true, true).animate({
                'min-height': new_sideoptions_height
            }, {
                'duration': 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': function() {
                    if (NEWSBLUR.app.story_list) {
                        NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                    }
                }
            });
            if (!$story_content.data('original_height')) {
                $story_content.data('original_height', content_height);
            }
        } else if (!NEWSBLUR.reader.flags.narrow_content) {
            // Content is bigger, move content back to normal
            if ($story_content.data('original_height') && !this.sideoptions_view.share_view.is_open) {
                $story_content.stop(true, true).animate({
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
            } else if (this.sideoptions_view.share_view.is_open && !options.from_share_view) {
                this.sideoptions_view.share_view.resize({from_save_view: true});
            }
        }
        
        if (NEWSBLUR.app.story_list) {
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }
    },
    
    reset_height: function() {
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');

        // Reset story content height to get an accurate height measurement.
        $story_content.stop(true, true).css('height', 'auto');
        $story_content.removeData('original_height');

        this.resize({change_tag: true});
    },
    
    save_tags: function() {
        var $tag_input = this.$('.NB-sideoption-save-tag');

        var user_tags = $tag_input.tagit('assignedTags');
        this.model.set('user_tags', user_tags);
    },

    save_user_notes: function(options) {
        var $notes = this.$('.NB-sideoption-save-notes');
        var $message = this.$('.NB-sideoption-save-message');
        var user_notes = $notes.val();
        
        if (this.model.get('user_notes') == user_notes) return;
        console.log('save_user_notes', user_notes);
        this.model.set('user_notes', user_notes, {silent: true});
        $message.removeClass('NB-active');
        if (this.saved_defer) {
            clearTimeout(this.saved_defer);
        }
        NEWSBLUR.assets.mark_story_as_starred(this.model.id, _.bind(function() {
            $message.addClass('NB-active');
            if (this.saved_defer) {
                clearTimeout(this.saved_defer);
            }
            this.saved_defer = _.delay(_.bind(function() {
                $message.removeClass('NB-active');
                this.saved_defer = null;
            }, this), 3000);                
        }, this));

    }

});
