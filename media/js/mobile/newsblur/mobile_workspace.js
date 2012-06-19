(function($) {
    
    NEWSBLUR.MobileReader = function() {
        
        // ===========
        // = Globals =
        // ===========
        
        this.model      = NEWSBLUR.assets;
        this.story_view = 'page';
        this.pages      = {
            'feeds' : $('#NB-page-feeds'),
            'stories' : $('#NB-page-stories'),
            'story' : $('#NB-page-story')
        };
        this.$s         = {
            $body: $('body'),
            $feed_list: $('#NB-feed-list'),
            $story_list: $('#NB-story-list'),
            $story_detail: $('#NB-story-detail')
        };
        this.flags      = {
            'feeds_loaded'      : false,
            'active_view'       : null
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
            this.bind_scroll();
        },
        
        // =============
        // = Feed List =
        // =============
        
        load_feeds: function() {
            this.flags.active_view = 'feeds';
            $.mobile.showPageLoadingMsg();
            
            this.pages.feeds.unbind('pagebeforeshow').bind('pagebeforeshow', _.bind(function(e) {
                $('ul', this.$s.$feed_list).listview('refresh');
            }, this));
            this.pages.feeds.unbind('pageshow').bind('pageshow', _.bind(function(e) {
                $('ul', this.$s.$story_list).remove();
            }, this));
            this.model.load_feeds_flat($.rescope(this.build_feed_list, this));
        },
        
        build_feed_list: function() {
            this.flags.active_view = 'feeds';
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
            $.mobile.hidePageLoadingMsg();
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
            if (!feed.fetched_once && !feed.has_exception) {
                exception_class += ' NB-feed-unfetched';
            }
            
            var $feed = _.template('\
            <li class="<%= unread_class %> <%= exception_class %>">\
                <a href="#" data-feed-id="<%= feed.id %>">\
                    <% if (feed.ps) { %>\
                        <span class="ui-li-count ui-li-count-positive"><%= feed.ps %></span>\
                    <% } %>\
                    <% if (feed.nt) { %>\
                        <span class="ui-li-count ui-li-count-neutral"><%= feed.nt %></span>\
                    <% } %>\
                    <% if (feed.ng) { %>\
                        <span class="ui-li-count ui-li-count-negative"><%= feed.ng %></span>\
                    <% } %>\
                    <img src="<%= $.favicon(feed) %>" class="ui-li-icon">\
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
        
        reset_feed: function() {
            this.page = 1;
        },
        
        load_stories: function(feed_id) {
            this.flags.active_view = 'stories';
            $.mobile.showPageLoadingMsg();
            this.active_feed = feed_id;
            this.model.load_feed(feed_id, this.page, this.page == 1, _.bind(this.build_stories, this), $.noop);
        },
        
        build_stories: function(data, first_load) {
            this.flags.active_view = 'stories';
            var self = this;
            var $story_list = this.$s.$story_list;
            var $stories = "";
            var feed_id = data.feed_id;
            
            if (this.active_feed != feed_id) return;
            
            _.each(data.stories, function(story) {
                $stories += self.make_story_title(story);
            });
            if (first_load) {
                $stories = '<ul data-role="listview" data-inset="false" data-theme="c" data-dividertheme="b">' +
                           $stories +
                           '</ul>';
                $story_list.html($stories);
            } else {
                $('ul', $story_list).append($stories);
                $('ul', $story_list).listview('refresh');
            }
            
            $('ul', $story_list).listview();
            $.mobile.hidePageLoadingMsg();
        },
        
        load_next_page_of_stories: function() {
            this.page += 1;
            this.load_stories(this.active_feed);
        },
        
        make_story_title: function(story) {
            var feed  = this.model.get_feed(this.active_feed);
            var score_color = this.story_color(story);
            
            return _.template('<li class="NB-story <%= story.read_status?"NB-read":"" %> NB-score-<%= score_color %>">\
                <div class="ui-li-icon NB-icon-score"></div>\
                <a href="#" data-story-id="<%= story.id %>">\
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
                        <div class="NB-story-feed-icon"><img src="<%= $.favicon(feed) %>"></div>\
                        <div class="NB-story-feed-title"><%= feed.feed_title %></div>\
                    </div>\
                </a>\
            </li>', {
                story : story,
                feed  : feed,
                score_color : score_color
            });
        },
        
        scroll_story_list: function() {
            var window_height     = $(window).height();
            var window_offset     = $(window).scrollTop();
            var story_list_height = this.pages.stories.height();
            var fudge_factor      = 18;

            if (window_height + window_offset > story_list_height - fudge_factor) {
                this.load_next_page_of_stories();
            }
        },
        
        // ================
        // = Story Detail =
        // ================
        
        load_story_detail: function(story_id) {
            this.flags.active_view = 'story_detail';
            $.mobile.showPageLoadingMsg();
            
            var $story_detail_view = this.$s.$story_detail;
            var story              = this.model.get_story(story_id);
            var score_color        = this.story_color(story);
            var $story             = this.make_story_detail(story);
            
            this.colorize_story_title(story);
            $('.ul-li-right', this.pages.story).jqmData('icon', 'NB-'+score_color);
            $story_detail_view.html($story);
            $.mobile.hidePageLoadingMsg();
            this.mark_story_as_read(story);
        },
        
        make_story_detail: function(story) {
            var feed  = this.model.get_feed(this.active_feed);
            var score_color = this.story_color(story);
            
            var $story = _.template('<div class="NB-story <%= story.read_status?"NB-read":"" %> NB-score-<%= score_color %>">\
                <div class="NB-story-header">\
                    <div class="NB-story-header-feed-gradient"></div>\
                    <div class="ui-li-icon NB-icon-score"></div>\
                    <div class="NB-story-date"><%= story.long_parsed_date %></div>\
                    <a href="<%= story.story_permalink %>" data-story-id="<%= story.id %>">\
                        <div class="NB-story-title"><%= story.story_title %></div>\
                    </a>\
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
                </div>\
                <div class="NB-story-content"><%= story.story_content %></div>\
            </div>', {
                story : story,
                feed : feed,
                score_color : score_color
            });

            return $story;
        },
        
        colorize_story_title: function() {
            var feed  = this.model.get_feed(this.active_feed);
            $('.ui-header', this.pages.story)
                .css('background-image',   NEWSBLUR.utils.generate_gradient(feed, 'webkit'))
                .css('background-image',   NEWSBLUR.utils.generate_gradient(feed, 'moz'))
                .css('borderBottom',       NEWSBLUR.utils.generate_gradient(feed, 'border'))
                .css('borderTop',          NEWSBLUR.utils.generate_gradient(feed, 'border'))
                .toggleClass('NB-inverse', NEWSBLUR.utils.is_feed_floater_gradient_light(feed));
                
            var $feed = _.template('<div class="NB-story-feed-header">\
                <img class="NB-favicon" src="<%= $.favicon(feed) %>" />\
                <span class="feed_title">\
                    <%= feed.feed_title %>\
                </span>\
            </div>', {
                feed : feed
            });
            
            $('.ui-title', this.pages.story).html($feed);
        },
        
        // =====================
        // = General Utilities =
        // =====================
        
        story_color: function(story) {
            var score = NEWSBLUR.utils.compute_story_score(story);
            var score_color = 'neutral';
            if (score > 0) score_color = 'positive';
            if (score < 0) score_color = 'negative';
            
            return score_color;
        },
        
        mark_story_as_read: function(story) {
            var story_id = story.id;
            var feed_id = story.story_feed_id;
          
            this.model.mark_story_as_read(story_id, feed_id, _.bind(function(read) {
                this.update_read_count(story_id, feed_id);
            }, this));
        },
        
        update_read_count: function(story_id, feed_id) {
            
        },
        
        // ==========
        // = Events =
        // ==========
        
        bind_clicks: function() {
            var self = this;
            
            this.$s.$feed_list.delegate('li a', 'tap', function(e) {
                e.preventDefault();
                var feed_id = $(e.currentTarget).jqmData('feed-id');
                $.mobile.changePage(self.pages.stories);
                self.reset_feed();
                self.load_stories(feed_id);
            });
            
            this.$s.$story_list.delegate('li a', 'tap', function(e) {
                e.preventDefault();
                var story_id = $(e.currentTarget).jqmData('story-id');
                $.mobile.showPageLoadingMsg();
                $.mobile.changePage(self.pages.story);
                self.load_story_detail(story_id);
            });
            
            this.$s.$story_detail.delegate('li a', 'tap', function(e) {
                e.preventDefault();
                var story_id = $(e.currentTarget).jqmData('story-id');
                $.mobile.showPageLoadingMsg();
                $.mobile.changePage(self.pages.story);
                self.load_story_detail(story_id);
            });
            
            this.pages.story.delegate('.NB-next', 'tap', function(e) {
                
            });
            
            this.pages.story.delegate('.NB-previous', 'tap', function(e) {
                
            });
        },
        
        bind_scroll: function() {
            $(window).bind('scroll', _.throttle(_.bind(function(e) {
                if (this.flags.active_view == 'stories') {
                    this.scroll_story_list();
                }
            }, this), 500));
        }
    };
    
})(jQuery);