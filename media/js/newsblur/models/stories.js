NEWSBLUR.Models.Story = Backbone.Model.extend({
    
    initialize: function() {
        this.bind('change:selected', this.change_selected);
        this.bind('change:shared_comments', this.populate_comments);
        this.bind('change:comments', this.populate_comments);
        this.bind('change:comment_count', this.populate_comments);
        this.bind('change:starred', this.change_starred);
        this.bind('change:user_tags', this.change_user_tags);
        this.populate_comments();
        this.story_permalink = this.get('story_permalink');
        this.story_title = this.get('story_title');
    },
    
    populate_comments: function(story, collection) {
        this.friend_comments = new NEWSBLUR.Collections.Comments(this.get('friend_comments'));
        this.friend_shares = new NEWSBLUR.Collections.Comments(this.get('friend_shares'));
        this.public_comments = new NEWSBLUR.Collections.Comments(this.get('public_comments'));
    },
    
    score: function() {
        if (NEWSBLUR.reader.flags['starred_view']) {
            return 2;
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
    
    content_preview: function(attribute, length) {
        var content = this.get(attribute || 'story_content');
        content = content && Inflector.stripTags(content);
        
        return _.string.prune(_.string.trim(content), length || 150, "...");
    },
    
    image_url: function(index) {
        if (!index) index = 0;
        if (this.get('image_urls').length >= index+1) {
            return this.get('image_urls')[index];
        }
    },
    
    story_authors: function() {
        return this.get('story_authors').replace(/</g, '&lt;')
                                        .replace(/>/g, '&gt;');
    },
    
    formatted_short_date: function() {
        var timestamp = this.get('story_timestamp');
        var dateformat = NEWSBLUR.assets.preference('dateformat');
        var date = new Date(parseInt(timestamp, 10) * 1000);
        var midnight_today = function() {
            var midnight = new Date();
            midnight.setHours(0);
            midnight.setMinutes(0);
            midnight.setSeconds(0);
            return midnight;
        };
        var midnight_yesterday = function(midnight) {
            return new Date(midnight - 60*60*24*1000);
        };
        var midnight = midnight_today();
        var time = date.format(dateformat == "24" ? "H:i" : "g:ia");

        if (date > midnight) {
            return time;
        } else if (date > midnight_yesterday(midnight)) {
            return "Yesterday, " + time;
        } else {
            return date.format("d M Y, ") + time;
        }
    },
    
    formatted_long_date: function() {
        var timestamp = this.get('story_timestamp');
        var dateformat = NEWSBLUR.assets.preference('dateformat');
        var date = new Date(parseInt(timestamp, 10) * 1000);
        var midnight_today = function() {
            var midnight = new Date();
            midnight.setHours(0);
            midnight.setMinutes(0);
            midnight.setSeconds(0);
            return midnight;
        };
        var midnight_yesterday = function(midnight) {
            return new Date(midnight - 60*60*24*1000);
        };
        var beginning_of_month = function() {
            var month = new Date();
            month.setHours(0);
            month.setMinutes(0);
            month.setSeconds(0);
            month.setDate(1);
            return month;
        };
        var midnight = midnight_today();
        var time = date.format(dateformat == "24" ? "H:i" : "g:ia");
        if (date > midnight) {
            return "Today, " + date.format("F jS ") + time;
        } else if (date > midnight_yesterday(midnight)) {
            return "Yesterday, " + date.format("F jS ") + time;
        } else if (date > beginning_of_month()) {
            return date.format("l, F jS ") + time;
        } else {
            return date.format("l, F jS Y ") + time;
        }
    },

    mark_read: function(options) {
        return NEWSBLUR.assets.stories.mark_read(this, options);
    },
    
    open_story_in_new_tab: function(background) {
        this.mark_read({skip_delay: true});

        // Safari browser on Linux is an impossibility, and thus we're actually
        // on a WebKit-based browser (WebKitGTK or QTWebKit). These can't handle
        // background tabs. Work around it by disabling backgrounding if we
        // think we're on Safari and we're also on X11 or Linux
        if ($.browser.safari && /(\(X11|Linux)/.test(navigator.userAgent)) {
            background = false;
        }

        if (background && !$.browser.mozilla) {
            var anchor, event;

            anchor = document.createElement("a");
            anchor.href = this.get('story_permalink');
            event = document.createEvent("MouseEvents");
            event.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, true, false, false, true, 0, null);
            return anchor.dispatchEvent(event);
        } else {
            window.open(this.get('story_permalink'), '_blank');
            window.focus();
        }
    },
    
    open_share_dialog: function(e, view) {
        if (view == 'title') {
            var $story_title = this.story_title_view.$st;
            this.story_title_view.mouseenter_manage_icon();
            NEWSBLUR.reader.show_manage_menu('story', $story_title, {story_id: this.id});
            NEWSBLUR.reader.show_confirm_story_share_menu_item(this.id);
        } else {
            var $story = this.latest_story_detail_view.$el;
            this.latest_story_detail_view.share_view.toggle_feed_story_share_dialog({
                animate_scroll: true
            });
        }
    },
    
    change_selected: function(model, selected) {
        if (model.collection) {
            model.collection.detect_selected_story(model, selected);
        }
    },
    
    // =================
    // = Saved Stories =
    // =================
    
    toggle_starred: function() {
        this.set('user_tags', this.existing_tags(), {silent: true});
        
        if (!this.get('starred')) {
            NEWSBLUR.assets.starred_count += 1;
            this.set('starred', true);
        } else {
            NEWSBLUR.assets.starred_count -= 1;
            this.set('starred', false);
        }
        NEWSBLUR.reader.update_starred_count();
    },
    
    change_starred: function() {
        if (this.get('starred')) {
            NEWSBLUR.assets.mark_story_as_starred(this.id);
        } else {
            NEWSBLUR.assets.mark_story_as_unstarred(this.id);
        }
    },
    
    change_user_tags: function(tags, options, etc) {
        NEWSBLUR.assets.mark_story_as_starred(this.id);
    },
    
    existing_tags: function() {
        var tags = this.get('user_tags');
        
        if (!tags) {
            tags = this.folder_tags();
        }
        
        return tags || [];
    },
    
    unused_story_tags: function() {
        var tags = _.reduce(this.get('user_tags') || [], function(m, t) {
            return _.without(m, t);
        }, this.get('story_tags'));
        return tags;
    },
    
    folder_tags: function() {
        var folder_tags = [];
        var feed_id = this.get('story_feed_id');
        var feed = NEWSBLUR.assets.get_feed(feed_id);
        if (feed) {
            folder_tags = feed.parent_folder_names();
        }
        return folder_tags;
    },
    
    all_tags: function() {
        var tags = [];
        var story_tags = this.get('story_tags') || [];
        var user_tags = this.get('user_tags') || [];
        var folder_tags = this.folder_tags();
        var existing_tags = NEWSBLUR.assets.starred_feeds.all_tags();
        var all_tags = _.unique(_.compact(_.reduce([
            story_tags, user_tags, folder_tags, existing_tags
        ], function(x, m) { 
            return m.concat(x); 
        }, [])));
        
        return all_tags;
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
        } else if (options.force) {
            delay = 0;
        } else if (delay == -1) {
            return;
        }

        clearTimeout(this.read_story_delay);
        
        var _mark_read = _.bind(function() {
            if (!delay || (delay && this.active_story.id == story.id)) {
                var feed = NEWSBLUR.assets.get_feed(NEWSBLUR.reader.active_feed);
                if (!feed) {
                    feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
                }
                NEWSBLUR.assets.mark_story_hash_as_read(story, _.bind(function(read) {
                    this.update_read_count(story, {previously_read: read});
                }, this));
            }
        }, this);
        
        if (delay) {
            this.read_story_delay = _.delay(_mark_read, delay * 1000);
        } else {
            _mark_read();
        }
    },
    
    mark_unread: function(story, options) {
        options = options || {};
        NEWSBLUR.assets.mark_story_as_unread(story.id, story.get('story_feed_id'), _.bind(function(read) {
            this.update_read_count(story, {unread: true});
        }, this), _.bind(function(data) {
            story.set('read_status', 1, {'error_marking_unread': true, 'message': data.message});
            this.update_read_count(story, {unread: false});
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
            var active_count = active_feed && Math.max(active_feed.get('ps') + (options.unread?1:-1), 0);
            var story_count = story_feed && Math.max(story_feed.get('ps') + (options.unread?1:-1), 0);
            if (active_feed) active_feed.set('ps', active_count, {instant: true});
            if (story_feed) story_feed.set('ps', story_count, {instant: true});
            _.each(friend_feeds, function(socialsub) { 
                var socialsub_count = Math.max(socialsub.get('ps') + (options.unread?1:-1), 0);
                socialsub.set('ps', socialsub_count, {instant: true});
            });
        } else if (story.score() == 0) {
            var active_count = active_feed && Math.max(active_feed.get('nt') + (options.unread?1:-1), 0);
            var story_count = story_feed && Math.max(story_feed.get('nt') + (options.unread?1:-1), 0);
            if (active_feed) active_feed.set('nt', active_count, {instant: true});
            if (story_feed) story_feed.set('nt', story_count, {instant: true});
            _.each(friend_feeds, function(socialsub) { 
                var socialsub_count = Math.max(socialsub.get('nt') + (options.unread?1:-1), 0);
                socialsub.set('nt', socialsub_count, {instant: true});
            });
        } else if (story.score() < 0) {
            var active_count = active_feed && Math.max(active_feed.get('ng') + (options.unread?1:-1), 0);
            var story_count = story_feed && Math.max(story_feed.get('ng') + (options.unread?1:-1), 0);
            if (active_feed) active_feed.set('ng', active_count, {instant: true});
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
        this.active_story = null;
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
    
    last_visible: function(score) {
        score = _.isUndefined(score) ? NEWSBLUR.reader.get_unread_view_score() : score;
        
        for (var i=this.size(); i >= 0; i--) {
            var story = this.at(i);
            if (story.score() >= score || story.get('visible')) {
                return story;
            }
        }
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
