NEWSBLUR.Views.FeedSelector = Backbone.View.extend({
    
    el: '.NB-feeds-selector',
    
    flags: {},
    
    events: {
        "keyup .NB-feeds-selector-input" : "keyup",
        "keydown .NB-feeds-selector-input" : "keydown"
    },
    
    selected_index: 0,
    
    initialize: function() {
        this.selected_feeds = new NEWSBLUR.Collections.Feeds();
    },
    
    toggle: function() {
        if (this.flags.showing_feed_selector) {
            this.hide_feed_selector();
        } else {
            this.show_feed_selector();
        }
    },
    
    show_feed_selector: function() {
        var $input = this.$(".NB-feeds-selector-input");
        var $feed_list    = NEWSBLUR.reader.$s.$feed_list;
        var $social_feeds = NEWSBLUR.reader.$s.$social_feeds;
        var $body = NEWSBLUR.reader.$s.$body;

        this.$el.show();
        $input.val('');
        $input.focus();
        NEWSBLUR.app.feed_list.options.feed_chooser = true;
        NEWSBLUR.assets.feeds.trigger('reset');
        $feed_list.addClass('NB-selector-active');
        $social_feeds.addClass('NB-selector-active');
        $body.addClass('NB-selector-active');
        
        this.flags.showing_feed_selector = true;
        NEWSBLUR.reader.layout.leftLayout.sizePane('north');
        
        if (NEWSBLUR.reader.flags['sidebar_closed']) {
            NEWSBLUR.reader.layout.outerLayout.show('west', true);
        }
    },
    
    hide_feed_selector: function() {
        if (!this.flags.showing_feed_selector) return;

        var $input = this.$(".NB-feeds-selector-input");
        var $feed_list    = NEWSBLUR.reader.$s.$feed_list;
        var $social_feeds = NEWSBLUR.reader.$s.$social_feeds;
        var $body = NEWSBLUR.reader.$s.$body;
        
        $input.blur();
        this.$el.hide();
        this.$next_feed = null;
        NEWSBLUR.app.feed_list.options.feed_chooser = false;
        NEWSBLUR.assets.feeds.trigger('reset');
        $feed_list.removeClass('NB-selector-active');
        $social_feeds.removeClass('NB-selector-active');
        $body.removeClass('NB-selector-active');
        $('.NB-feed-selector-selected').removeClass('NB-feed-selector-selected');
                    
        this.flags.showing_feed_selector = false;
        NEWSBLUR.reader.layout.leftLayout.sizePane('north');

        if (NEWSBLUR.reader.flags['sidebar_closed']) {
            NEWSBLUR.reader.layout.outerLayout.hide('west');
        }
    },
    
    filter_feed_selector: function(e) {
        var $input = this.$(".NB-feeds-selector-input");
        var input = $input.val().toLowerCase();
        if (input == this.last_input && input.length) return;
        this.last_input = input;
        
        this.selected_feeds.each(function(feed) {
            _.each(feed.views, function(view) {
                view.$el.removeClass('NB-feed-selector-active');
            });
        });
        
        var feeds = NEWSBLUR.assets.feeds.filter(function(feed){ 
            return _.string.contains(feed.get('feed_title') && feed.get('feed_title').toLowerCase(), input) || feed.id == input;
        });
        var socialsubs = NEWSBLUR.assets.social_feeds.filter(function(feed){ 
            return _.string.contains(feed.get('feed_title').toLowerCase(), input) ||
                   _.string.contains(feed.get('username').toLowerCase(), input);
        });
        feeds = socialsubs.concat(feeds);
        
        // Clear out shown feeds on empty input
        if (input.length == 0) {
            this.selected_feeds.reset();
        }
        
        if (feeds.length) {
            this.selected_feeds.reset(feeds);
        }
        
        this.selected_feeds.each(function(feed) {
            _.each(feed.views, function(view) {
                view.$el.addClass('NB-feed-selector-active');
            });
        });
        
        this.select(0);
    },
    
    // ==============
    // = Navigation =
    // ==============
    
    keyup: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40, enter: 13};
        
        if (e.which == arrow.up || e.which == arrow.down) {
            // return this.navigate(e);
        } else if (e.which == arrow.enter) {
            // return this.open(e);
        }
        
        return this.filter_feed_selector(e);
    },
    
    keydown: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40, enter: 13, esc: 27};
        
        if (e.which == arrow.esc) {
            e.preventDefault();
            e.stopPropagation();
            this.hide_feed_selector();
            return false;
        } else if (e.which == arrow.up || e.which == arrow.down) {
            return this.navigate(e);
        } else if (e.which == arrow.enter) {
            return this.open(e);
        }
        
        // return this.filter_feed_selector(e);
    },
    
    navigate: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40, esc: 27};
        
        if (e.which == arrow.down) {
            this.select(1);
        } else if (e.which == arrow.up) {
            this.select(-1);
        }
        
        e.preventDefault();
        return false;
    },
    
    select: function(direction) {
        var off, on;
        
        var $current_feed = $('.NB-feed-selector-selected.NB-feed-selector-active');
        this.$next_feed = NEWSBLUR.reader.get_next_feed(direction, $current_feed);
        
        $('.NB-feed-selector-selected').removeClass('NB-feed-selector-selected');
        this.$next_feed.addClass('NB-feed-selector-selected');
        NEWSBLUR.app.feed_list.scroll_to_show_highlighted_feed();
    },
    
    open: function(e) {
        var feed_id = this.$next_feed.data('id');
        if (_.string.include(feed_id, 'social:')) {
            NEWSBLUR.reader.open_social_stories(this.$next_feed.data('id'), {
                $feed: this.$next_feed
            });
        } else {
            NEWSBLUR.reader.open_feed(this.$next_feed.data('id'), {$feed: this.$next_feed});
        }
        
        e.preventDefault();
        return false;
    }
    
});