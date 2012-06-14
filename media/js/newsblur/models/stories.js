NEWSBLUR.Models.Story = Backbone.Model.extend({
    
    initialize: function() {
        this.bind('change:comments', this.populate_comments);
        this.bind('change:comment_count', this.populate_comments);
        this.populate_comments();
    },
    
    populate_comments: function(story, collection, changes) {
        var comments = this.get('comments');

        if (!this.get('comment_count')) {
            delete this.comments;
        } else if (comments && comments.length) {
            this.comments = new NEWSBLUR.Collections.Comments(this.get('comments'));
        }
    },
    
    score: function() {
        if (NEWSBLUR.reader.active_feed == 'starred') {
            return 1;
        } else {
            return NEWSBLUR.utils.compute_story_score(this);
        }
    },
    
    score_name: function(score) {
        score = !_.isUndefined(score) ? score : this.score();
        var score_name = 'neutral';
        if (score > 0) score_name = 'positive';
        if (score < 0) score_name = 'negative';
        return score_name;
    },
    
    has_modifications: function() {
        if (this.get('story_content').indexOf('<ins') != -1) {
            return true;
        } else if (NEWSBLUR.assets.preference('hide_story_changes') && 
                   this.get('story_content').indexOf('<del') != -1) {
            return true;
        }
        return false;
    }
    
});

NEWSBLUR.Collections.Stories = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.Story,
   
    read_stories: [],
    
    active_story: null,
    
    initialize: function() {
        this.bind('change:selected', this.detect_selected_story);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    deselect: function(selected_story) {
        this.any(function(story) {
            if (story.get('selected') && story != selected_story) {
                story.set('selected', false);
                return true;
            }
        });
    },
    
    mark_read: function(story, options) {
        options = options || {};
        var delay = NEWSBLUR.assets.preference('read_story_delay');

        if (options.skip_delay) {
            delay = 0;
        } else if (delay == -1) {
            return;
        }

        this.last_read_story_id = story.id;
        clearTimeout(this.read_story_delay);
        
        this.read_story_delay = _.delay(_.bind(function() {
            if (delay || this.last_read_story_id == story.id || delay == 0) {
                var mark_read_fn = NEWSBLUR.assets.mark_story_as_read;
                var feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
                if (feed.is_social()) {
                    mark_read_fn = NEWSBLUR.assets.mark_social_story_as_read;
                }
                mark_read_fn.call(NEWSBLUR.assets, story.id, story.get('story_feed_id'), _.bind(function(read) {
                    this.update_read_count(story, {previously_read: read});
                }, this));
                story.set('read_status', 1);
            }
        }, this), delay * 1000);
    },
    
    mark_unread: function(story, options) {
        options = options || {};
        NEWSBLUR.assets.mark_story_as_unread(story.id, story.get('story_feed_id'), _.bind(function(read) {
            this.update_read_count(story, {unread: true});
        }, this));
        story.set('read_status', 0);
    },
    
    update_read_count: function(story, options) {
        options = options || {};
        
        if (options.previously_read) return;

        var story_unread_counter  = NEWSBLUR.app.story_unread_counter;
        var unread_view           = NEWSBLUR.reader.get_unread_view_name();
        var feed                  = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
        
        if (story.score() > 0) {
            var count = Math.max(feed.get('ps') + (options.unread?1:-1), 0);
            feed.set('ps', count, {instant: true});
        } else if (story.score() == 0) {
            var count = Math.max(feed.get('nt') + (options.unread?1:-1), 0);
            feed.set('nt', count, {instant: true});
        } else if (story.score() < 0) {
            var count = Math.max(feed.get('ng') + (options.unread?1:-1), 0);
            feed.set('ng', count, {instant: true});
        }
        
        if (story_unread_counter) {
            story_unread_counter.flash();
        }
        
        // if ((unread_view == 'positive' && feed.get('ps') == 0) ||
        //     (unread_view == 'neutral' && feed.get('ps') == 0 && feed.get('nt') == 0) ||
        //     (unread_view == 'negative' && feed.get('ps') == 0 && feed.get('nt') == 0 && feed.get('ng') == 0)) {
        //     story_unread_counter.fall();
        // }
    },
    
    // ==================
    // = Model Managers =
    // ==================
    
    visible: function(score) {
        score = _.isUndefined(score) ? NEWSBLUR.reader.get_unread_view_score() : score;
        
        return this.select(function(story) {
            return story.score() >= score;
        });
    },
    
    visible_and_unread: function(score, include_active_story) {
        var active_story_id = this.active_story && this.active_story.id;
        score = _.isUndefined(score) ? NEWSBLUR.reader.get_unread_view_score() : score;
        
        return this.select(function(story) {
            var visible = story.score() >= score;
            var same_story = include_active_story && story.id == active_story_id;
            var read = !!story.get('read_status');
            
            return visible && (!read || same_story);
        });
    },
    
    hidden: function() {
        var unread_score = NEWSBLUR.assets.preference('unread_view');
        
        return this.select(function(story) {
            return story.score() < unread_view;
        });
    },
    
    // ===========
    // = Getters =
    // ===========
    
    get_next_story: function(direction, options) {
        options = options || {};
        if (direction == -1) return this.get_previous_story(options);

        var visible_stories = this.visible(options.score);

        if (!this.active_story) {
            return visible_stories[0];
        }

        var current_index = _.indexOf(visible_stories, this.active_story);

        if (current_index+1 <= visible_stories.length) {
            return visible_stories[current_index+1];
        }
    },
    
    get_previous_story: function(options) {
        options = options || {};
        var visible_stories = this.visible(options.score);

        if (!this.active_story) {
            return visible_stories[0];
        }

        var current_index = _.indexOf(visible_stories, this.active_story);

        if (current_index-1 >= 0) {
            return visible_stories[current_index-1];
        }
    },
    
    get_next_unread_story: function(options) {
        options = options || {};
        var visible_stories = this.visible_and_unread(options.score, true);
        if (!visible_stories.length) return;
        
        if (!this.active_story) {
            return visible_stories[0];
        }

        var current_index = _.indexOf(visible_stories, this.active_story);
        
        // The +1+1 is because the currently selected story is included, so it
        // counts for more than what is available.
        if (current_index+1+1 <= visible_stories.length) {
            return visible_stories[current_index+1];
        } else if (current_index-1 >= 0) {
            return visible_stories[current_index-1];
        }
    },
    
    get_last_unread_story: function(unread_count, options) {
        options = options || {};
        var visible_stories = this.visible_and_unread(options.score);
        if (!visible_stories.length || visible_stories.length < unread_count) return;
        
        return _.last(visible_stories);
    },
    
    // ==========
    // = Events =
    // ==========
    
    detect_selected_story: function(selected_story, selected) {
        if (selected) {
            this.deselect(selected_story);
            this.active_story = selected_story;
            NEWSBLUR.reader.active_story = selected_story;
            if (!selected_story.get('read_status')) {
                this.mark_read(selected_story);
            }
        }
    }
    
});