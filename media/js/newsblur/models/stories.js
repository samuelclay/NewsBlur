NEWSBLUR.Models.Story = Backbone.Model.extend({
    
    initialize: function() {
        this.bind('change:selected', this.change_selected);
        this.bind('change:shared_comments', this.populate_comments);
        this.bind('change:comments', this.populate_comments);
        this.bind('change:comment_count', this.populate_comments);
        this.populate_comments();
        this.story_permalink = this.get('story_permalink');
        this.story_title = this.get('story_title');
    },
    
    populate_comments: function(story, collection, changes) {
        this.friend_comments = new NEWSBLUR.Collections.Comments(this.get('friend_comments'));
        this.public_comments = new NEWSBLUR.Collections.Comments(this.get('public_comments'));
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
        if (this.get('story_content').indexOf('<ins') != -1 ||
            this.get('story_content').indexOf('<del') != -1) {
            return true;
        }
        return false;
    },
    
    mark_read: function(options) {
        return NEWSBLUR.assets.stories.mark_read(this, options);
    },
    
    change_selected: function(model, selected, changes) {
        if (model.collection) {
            model.collection.detect_selected_story(model, selected);
        }
    }
    
});

NEWSBLUR.Collections.Stories = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.Story,
   
    read_stories: [],
    
    previous_stories_stack: [],
    
    active_story: null,
    
    initialize: function() {
        // this.bind('change:selected', this.detect_selected_story, this);
        this.bind('reset', this.clear_previous_stories_stack, this);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    deselect_other_stories: function(selected_story) {
        this.any(function(story) {
            if (story.get('selected') && story.id != selected_story.id) {
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

        clearTimeout(this.read_story_delay);
        
        this.read_story_delay = _.delay(_.bind(function() {
            if (!delay || (delay && this.active_story.id == story.id)) {
                var mark_read_fn = NEWSBLUR.assets.mark_story_as_read;
                var feed = NEWSBLUR.assets.get_feed(NEWSBLUR.reader.active_feed);
                if (!feed) {
                    feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
                }
                if ((feed && feed.is_social()) ||
                    NEWSBLUR.reader.active_feed == 'river:blurblogs') {
                    mark_read_fn = NEWSBLUR.assets.mark_social_story_as_read;
                }
                mark_read_fn.call(NEWSBLUR.assets, story, feed, _.bind(function(read) {
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
        var active_feed           = NEWSBLUR.assets.get_feed(NEWSBLUR.reader.active_feed);
        var story_feed            = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
        var friend_feeds          = NEWSBLUR.assets.get_friend_feeds(story);

        if (!active_feed) {
            // River of News does not have an active feed.
            active_feed = story_feed;
        } else if (active_feed && active_feed.is_social()) {
            friend_feeds = _.without(friend_feeds, active_feed);
        }
        
        if (story.score() > 0) {
            var active_count = Math.max(active_feed.get('ps') + (options.unread?1:-1), 0);
            var story_count = story_feed && Math.max(story_feed.get('ps') + (options.unread?1:-1), 0);
            active_feed.set('ps', active_count, {instant: true});
            if (story_feed) story_feed.set('ps', story_count, {instant: true});
            _.each(friend_feeds, function(socialsub) { 
                var socialsub_count = Math.max(socialsub.get('ps') + (options.unread?1:-1), 0);
                socialsub.set('ps', socialsub_count, {instant: true});
            });
        } else if (story.score() == 0) {
            var active_count = Math.max(active_feed.get('nt') + (options.unread?1:-1), 0);
            var story_count = story_feed && Math.max(story_feed.get('nt') + (options.unread?1:-1), 0);
            active_feed.set('nt', active_count, {instant: true});
            if (story_feed) story_feed.set('nt', story_count, {instant: true});
            _.each(friend_feeds, function(socialsub) { 
                var socialsub_count = Math.max(socialsub.get('nt') + (options.unread?1:-1), 0);
                socialsub.set('nt', socialsub_count, {instant: true});
            });
        } else if (story.score() < 0) {
            var active_count = Math.max(active_feed.get('ng') + (options.unread?1:-1), 0);
            var story_count = story_feed && Math.max(story_feed.get('ng') + (options.unread?1:-1), 0);
            active_feed.set('ng', active_count, {instant: true});
            if (story_feed) story_feed.set('ng', story_count, {instant: true});
            _.each(friend_feeds, function(socialsub) { 
                var socialsub_count = Math.max(socialsub.get('ng') + (options.unread?1:-1), 0);
                socialsub.set('ng', socialsub_count, {instant: true});
            });
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
    
    clear_previous_stories_stack: function() {
        this.previous_stories_stack = [];
    },
    
    select_previous_story: function() {
        if (this.previous_stories_stack.length) {
            var previous_story = this.previous_stories_stack.pop();
            if (previous_story.get('selected') ||
                previous_story.score() < NEWSBLUR.reader.get_unread_view_score()) {
                this.select_previous_story();
                return;
            }
            
            previous_story.set('selected', true);
        }
    },
    
    // ==================
    // = Model Managers =
    // ==================
    
    visible: function(score) {
        score = _.isUndefined(score) ? NEWSBLUR.reader.get_unread_view_score() : score;
        
        return this.select(function(story) {
            return story.score() >= score || story.get('visible');
        });
    },
    
    visible_and_unread: function(score, include_active_story) {
        var active_story_id = this.active_story && this.active_story.id;
        score = _.isUndefined(score) ? NEWSBLUR.reader.get_unread_view_score() : score;
        
        return this.select(function(story) {
            var visible = story.score() >= score || story.get('visible');
            var same_story = include_active_story && story.id == active_story_id;
            var read = !!story.get('read_status');
            
            return visible && (!read || same_story);
        });
    },
    
    hidden: function(score) {
        score = _.isUndefined(score) ? NEWSBLUR.reader.get_unread_view_score() : score;

        return this.select(function(story) {
            return story.score() < score && !story.get('visible');
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
            if (visible_stories[current_index+1])
            return visible_stories[current_index+1];
        } else if (current_index-1 >= 0) {
            return visible_stories[current_index-1];
        } else if (visible_stories.length == 1 && visible_stories[0] == this.active_story && !this.active_story.get('read_status')) {
            // If the current story is unread yet selected, switch it back.
            visible_stories[current_index].set('selected', false);
            return visible_stories[current_index];
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
            this.deselect_other_stories(selected_story);
            this.active_story = selected_story;
            NEWSBLUR.reader.active_story = selected_story;
            this.previous_stories_stack.push(selected_story);
            if (!selected_story.get('read_status')) {
                this.mark_read(selected_story);
            }
        }
    }
    
});