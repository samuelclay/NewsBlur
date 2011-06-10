(function($) {
    
    NEWSBLUR.MobileReader = function() {
        
        // ===========
        // = Globals =
        // ===========
        
        this.model      = NEWSBLUR.AssetModel.reader();
        this.story_view = 'page';
        this.pages      = {
            'feeds' : $('#NB-page-feeds'),
            'stories' : $('#NB-page-stories')
        };
        this.$s         = {
            $body: $('body'),
            $feed_list: $('#NB-feed-list'),
            $story_list: $('#NB-story-list')
        };
        this.flags      = {
            'feeds_loaded'      : false
        };
        this.locks      = {};
        this.counts     = {};
        this.cache      = {};
        this.constants  = {};
        
        $(document).bind('mobileinit', function() {
            $.mobile.ajaxEnabled = false;
        });

        this.runner();
    };
    
    NEWSBLUR.MobileReader.prototype = {
        
        runner: function() {
            this.load_feeds();
            this.bind_clicks();
        },
        
        // =============
        // = Feed List =
        // =============
        
        load_feeds: function() {
            $.mobile.pageLoading();
            
            this.model.load_feeds_flat($.rescope(this.build_feed_list, this));
            this.pages.feeds.bind('pagebeforeshow', _.bind(function(e) {
                $('ul', this.$s.$feed_list).listview('refresh');
            }, this));
            this.pages.feeds.bind('pageshow', _.bind(function(e) {
                $('ul', this.$s.$story_list).remove();
            }, this));
        },
        
        build_feed_list: function() {
            var self       = this;
            var folders    = this.model.folders;
            var feeds      = this.model.feeds;
            var $feed_list = this.$s.$feed_list;
            var $feeds     = '';
            _.each(folders, function(items, folder_name) {
                $feeds += '<ul data-role="listview" data-inset="true" data-theme="c" data-dividertheme="b">';
                if (folder_name && folder_name != ' ') {
                    $feeds += _.template('\
                    <li data-role="list-divider"><%= folder_name %></li>', {
                        folder_name : folder_name
                    });
                }
                _.each(items, function(item) {
                    $feeds += self.make_feed_title(item);
                });
                $feeds += '</ul>';
            });
            
            this.flags.feeds_loaded = true;
            $feed_list.html($feeds);
            $('ul', $feed_list).listview();
            $.mobile.pageLoading(true);
        },
        
        make_feed_title: function(feed_id) {
            var feed = this.model.get_feed(feed_id);
            var unread_class    = '';
            var exception_class = '';
            if (feed.ps) unread_class += ' unread_positive';
            if (feed.nt) unread_class += ' unread_neutral';
            if (feed.ng) unread_class += ' unread_negative';
            if (!feed.active) exception_class += ' NB-feed-inactive';
            if (feed.has_exception && feed.exception_type == 'feed') {
                exception_class += ' NB-feed-exception';
            }
            if (feed.not_yet_fetched && !feed.has_exception) {
                exception_class += ' NB-feed-unfetched';
            }
            
            var $feed = _.template('\
            <li class="<%= unread_class %> <%= exception_class %>">\
                <a href="#stories" data-feed-id="<%= feed.id %>">\
                    <% if (feed.ps) { %>\
                        <span class="ui-li-count ui-li-count-positive"><%= feed.ps %></span>\
                    <% } %>\
                    <% if (feed.nt) { %>\
                        <span class="ui-li-count ui-li-count-neutral"><%= feed.nt %></span>\
                    <% } %>\
                    <% if (feed.ng) { %>\
                        <span class="ui-li-count ui-li-count-negative"><%= feed.ng %></span>\
                    <% } %>\
                    <img src="<%= $.favicon(feed.favicon) %>" class="ui-li-icon">\
                    <%= feed.feed_title %>\
                </a>\
            </li>', {
                feed            : feed,
                unread_class    : unread_class,
                exception_class : exception_class
            });
            return $feed;
        },
        
        // ===========
        // = Stories =
        // ===========
        
        load_stories: function(feed_id) {
            this.active_feed = feed_id;
            this.model.load_feed(feed_id, 1, true, _.bind(this.build_stories, this));
        },
        
        build_stories: function(data, first_load) {
            NEWSBLUR.log(['build_stories', data]);

            var self = this;
            var $story_list = this.$s.$story_list;
            var $stories = "";
            var feed_id = data.feed_id;
            
            if (this.active_feed != feed_id) return;
            
            $stories += '<ul data-role="listview" data-inset="false" data-theme="c" data-dividertheme="b">';
            _.each(data.stories, function(story) {
                $stories += self.make_story_title(story);
            });
            $stories += '</ul>';
            
            $story_list.html($stories);
            $('ul', $story_list).listview();
            $.mobile.pageLoading(true);
            NEWSBLUR.log(['stories', data]);
        },
        
        make_story_title: function(story) {
            var feed  = this.model.get_feed(this.active_feed);
            var score = NEWSBLUR.utils.compute_story_score(story);
            var score_color = 'neutral';
            if (score > 0) score_color = 'positive';
            if (score < 0) score_color = 'negative';
            
            return _.template('<li class="NB-story <%= story.read_status?"NB-read":"" %> NB-score-<%= score_color %>">\
                <div class="ui-li-icon NB-icon-score"></div>\
                <a href="#story">\
                    <div class="NB-story-date"><%= story.long_parsed_date %></div>\
                    <% if (story.story_authors) { %>\
                        <div class="NB-story-author"><%= story.story_authors %></div>\
                    <% } %>\
                    <% if (story.story_tags && story.story_tags.length) { %>\
                        <div class="NB-story-tags">\
                            <% _.each(story.story_tags, function(tag) { %>\
                                <div class="NB-story-tag"><%= tag %></div>\
                            <% }); %>\
                        </div>\
                    <% } %>\
                    <div class="NB-story-title"><%= story.story_title %></div>\
                    <div class="NB-story-feed">\
                        <div class="NB-story-feed-icon"><img src="<%= $.favicon(feed.favicon) %>"></div>\
                        <div class="NB-story-feed-title"><%= feed.feed_title %></div>\
                    </div>\
                </a>\
            </li>', {
                story : story,
                feed  : feed,
                score_color : score_color
            });
        },
        
        // ==========
        // = Events =
        // ==========
        
        bind_clicks: function() {
            var self = this;
            
            $('#NB-feed-list').delegate('li', 'tap', function(e) {
                var feed_id = $(e.target).jqmData('feed-id');
                $.mobile.pageLoading();
                $.mobile.changePage('stories');
                self.load_stories(feed_id);
            });
        }
    };
    
})(jQuery);