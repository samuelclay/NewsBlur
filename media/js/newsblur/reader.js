(function($) {
    
    NEWSBLUR.reader = function() {
        var self = this;
        this.$feed_list = $('#feed_list');
        this.$story_titles = $('#story_titles');
        this.$story_pane = $('#story_pane');
        this.$account_menu = $('.menu_button');
        this.$feed_view = $('.NB-feed-story-view');
        this.$page_view = $('.NB-feed-frame');

        this.model = NEWSBLUR.AssetModel.reader();
        this.options = {};
        this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
        this.story_view = 'page';
        
        $('body').live('click', $.rescope(this.handle_clicks, this));
        $('body').live('dblclick', $.rescope(this.handle_dblclicks, this));
        $('#story_titles').scroll($.rescope(this.handle_scroll, this));
        
        this.load_page();
        this.load_feeds();
        this.apply_resizable_layout();
        this.cornerize_buttons();
        this.handle_keystrokes();
        this.setup_taskbar_nav_left();
        this.setup_feed_page_iframe_load();
    };

    NEWSBLUR.reader.prototype = {
        
        // =================
        // = Node Creation =
        // =================
        
        make_story_title: function(story) {
            var read = story.read_status
                ? ' read'
                : '';
            var $story_title = $.make('div', { className: 'story' + read }, [
                $.make('a', { href: story.story_permalink, className: 'story_title' }, [
                    story.story_title,
                    $.make('span', { className: 'NB-storytitles-author'}, story.story_author)
                ]),
                $.make('span', { className: 'story_date' }, story.short_parsed_date),
                $.make('span', { className: 'story_id' }, ''+story.id)
            ]);
            
            return $story_title;
        },
        
        // ========
        // = Page =
        // ========
        
        load_page: function() {
            this.resize_story_content_pane();
            this.resize_feed_list_pane();
        },
        
        apply_resizable_layout: function() {
            var outerLayout, rightLayout, contentLayout, leftLayout;
            
        	outerLayout = $('body').layout({ 
        	    closable: true,
    			center__paneSelector:	".right-pane",
    			west__paneSelector:		".left-pane",
    			west__size:				240,
    			center__onresize:       "rightLayout.resizeAll",
    			spacing_open:			4,
    			resizerDragOpacity:     0.6
    		}); 
    		
    		leftLayout = $('.left-pane').layout({
        	    closable: false,
    			center__onresize:		"middleLayout.resizeAll",
    		    center__paneSelector:   ".left-center",
    			south__paneSelector:	".left-south",
    			south__size:            30,
    			south__resizable:       false,
    			south__spacing_open:    0
    		});

    		rightLayout = $('.right-pane').layout({ 
    			south__paneSelector:	".right-north",
    			center__paneSelector:	".content-pane",
    			south__size:			168,
    			spacing_open:			10,
    			resizerDragOpacity:     0.6
    		}); 

    		contentLayout = $('.content-pane').layout({ 
    			center__paneSelector:	".content-center",
    			south__paneSelector:	".content-north",
    			south__size:            30,
    			spacing_open:           0,
    			resizerDragOpacity:     0.6
    		}); 
        },
        
        resize_story_content_pane: function() {
            var doc_height = $(document).height();
            var stories_pane_height = this.$story_titles.height();
            var story_content_top = parseInt(this.$story_titles.css('top'), 10);
            
            var new_story_pane_height = doc_height - (stories_pane_height + story_content_top);
            this.$story_pane.css('height', new_story_pane_height);
        },
        
        resize_feed_list_pane: function() {
            var doc_height = $(document).height();
            var feed_list_top = parseInt($('#feed_list').css('top'), 10);
            
            var new_feed_list_height = doc_height - feed_list_top;
            $('#feed_list').css('height', new_feed_list_height);
        },
        
        capture_window_resize: function() {
            var self = this,
                resizeTimer;
                
            $(window).bind('resize', function() {
                if (resizeTimer) clearTimeout(resizeTimer);
                resizeTimer = setTimeout(function() {
                    self.resize_story_content_pane();
                    self.resize_feed_list_pane();
                }, 10);
            });    
        },
        
        cornerize_buttons: function() {
            $('.button').corners();
        },
        
        handle_keystrokes: function() {      
            var self = this;                                                           
            $(document).bind('keydown', { combi: 'down', disableInInput: true }, function(e) {
                e.preventDefault();
                self.show_next_story(1);
            });
            $(document).bind('keydown', { combi: 'up', disableInInput: true }, function(e) {
                e.preventDefault();
                self.show_next_story(-1);
            });                                                           
            $(document).bind('keydown', { combi: 'j', disableInInput: true }, function(e) {
                e.preventDefault();
                self.show_next_story(-1);
            });
            $(document).bind('keydown', { combi: 'k', disableInInput: true }, function(e) {
                e.preventDefault();
                self.show_next_story(1);
            });
            $(document).bind('keydown', { combi: 'left', disableInInput: true }, function(e) {
                e.preventDefault();
                self.show_next_feed(-1);
            });
            $(document).bind('keydown', { combi: 'right', disableInInput: true }, function(e) {
                e.preventDefault();
                self.show_next_feed(1);
            });
            $(document).bind('keydown', { combi: 'space', disableInInput: true }, function(e) {
                e.preventDefault();
                self.page_in_story(0.4, 1);
            });
            $(document).bind('keydown', { combi: 'shift+space', disableInInput: true }, function(e) {
                e.preventDefault();
                self.page_in_story(0.4, -1);
            });
        },
        
        hide_splash_page: function() {
            $('#NB-splash').hide();
        },
        
        // ==============
        // = Navigation =
        // ==============
        
        show_next_story: function(direction) {
            var $current_story = $('.selected', this.$story_titles);
            var $next_story;
            
            if (!$current_story.length) {
                $current_story = $('.story:first', this.$story_titles);
                $next_story = $current_story;
            } else if (direction == 1) {
                $next_story = $current_story.next('.story');
            } else if (direction == -1) {
                $next_story = $current_story.prev('.story');
            }
            
            var story_id = $('.story_id', $next_story).text();
            if (story_id) {
                var story_title_visisble = this.$story_titles.isScrollVisible($next_story);
                if (!story_title_visisble) {
                    var container_offset = this.$story_titles.position().top;
                    var scroll = $next_story.position().top;
                    var container = this.$story_titles.scrollTop();
                    var height = this.$story_titles.outerHeight();
                    this.$story_titles.scrollTop(scroll+container-height/5);
                }
                this.open_story(story_id, $next_story);
            }
            
        },
        
        show_next_feed: function(direction) {
            var $current_feed = $('.selected', this.$feed_list);
            var $next_feed,
                scroll;
            
            if (!$current_feed.length) {
                $current_feed = $('.feed:first', this.$feed_list);
                $next_feed = $current_feed;
            } else if (direction == 1) {
                $next_feed = $current_feed.next('.feed');
            } else if (direction == -1) {
                $next_feed = $current_feed.prev('.feed');
            }
            
            if (!$next_feed.length) {
                if (direction == 1) {
                    $next_feed = $current_feed.parents('.folder').next('.folder').find('.feed:first');
                } else if (direction == -1) {
                    $next_feed = $current_feed.parents('.folder').prev('.folder').find('.feed:last');
                }
            }
            
            var feed_id = $('.feed_id', $next_feed).text();
            if (feed_id) {
                var position = this.$feed_list.scrollTop() + $next_feed.offset().top - $next_feed.outerHeight();
                var showing = this.$feed_list.height();
                if (position > showing) {
                    scroll = position;
                } else {
                    scroll = 0;
                }
                this.$feed_list.scrollTop(scroll);
                this.open_feed(feed_id, $next_feed);
            }
        },
        
        page_in_story: function(amount, direction) {
            var page_height = this.$story_pane.height();
            var scroll_height = parseInt(page_height * amount, 10);
            var dir = '+';
            if (direction == -1) {
                dir = '-';
            }
            this.$story_pane.scrollTo({top:dir+'='+scroll_height, left:'+=0'}, 150);
        },
        
        // =============
        // = Feed Pane =
        // =============
        
        load_feeds: function() {
            var self = this;
            
            var callback = function() {
                var $feed_list = self.$feed_list.empty();
                var folders = self.model.folders;
                NEWSBLUR.log(['Subscriptions', {'folders':folders}]);
                for (fo in folders) {
                    var feeds = folders[fo].feeds;
                    var $folder = $.make('div', { className: 'folder' }, [
                        $.make('span', { className: 'folder_title' }, folders[fo].folder),
                        $.make('div', { className: 'feeds' })
                    ]);
                    for (f in feeds) {
                        var $feed = $.make('div', { className: 'feed' }, [
                            $.make('span', { className: 'unread_count' }, ''+feeds[f].unread_count),
                            $.make('img', { className: 'feed_favicon', src: self.google_favicon_url + feeds[f].feed_link }),
                            $.make('span', { className: 'feed_title' }, feeds[f].feed_title),
                            $.make('span', { className: 'feed_id' }, ''+feeds[f].id)
                        ]);
                        if (feeds[f].unread_count <= 0) {
                            $('.unread_count', $feed).css('display', 'none');
                            $feed.addClass('no_unread_items');
                        }
                        $('.feeds', $folder).append($feed);
                    }
                    $feed_list.append($folder);
                }
                $('.unread_count', $feed_list).corners('4px');
            };
            
            if ($('#feed_list').length) {
                this.model.load_feeds(callback);
            }
        },
        
        // =====================
        // = Story Titles Pane =
        // =====================
        
        open_feed: function(feed_id, $feed_link) {
            var self = this;
            var $story_titles = this.$story_titles;
            $story_titles.empty().scrollTop('0px');
            
            this.active_feed = feed_id;
            this.hide_splash_page();
            this.$story_titles.data('page', 0);
            this.$story_titles.data('feed_id', feed_id);
            
            this.show_feed_title_in_stories($story_titles, feed_id);
            this.mark_feed_as_selected(feed_id, $feed_link);
            this.model.load_feed(feed_id, 0, $.rescope(this.create_story_titles, this));
            // this.model.load_feed_page(feed_id, 0, $.rescope(this.show_feed_page_contents, this));
            this.show_feed_page_contents(feed_id);
            this.show_correct_story_view(feed_id);
            
        },
        
        show_correct_story_view: function(feed_id) {
            var $feed_view = this.$feed_view;
            var $page_view = this.$page_view;
            var $taskbar_view_button;
            
            // TODO: Assume page view until user prefs override
            if (this.story_view == 'feed') {
                $page_view.css({
                    'left': -1 * $page_view.width()
                });
                $taskbar_view_button = $('.NB-taskbar .task_view_feed');
            } else if (this.story_view == 'page') {
                $feed_view.css({
                    'left': $feed_view.width()
                });
                $taskbar_view_button = $('.NB-taskbar .task_view_page');
            }
            
            this.switch_taskbar_view($taskbar_view_button);
        },
        
        create_story_titles: function(e, stories) {
            var $story_titles = this.$story_titles;
            
            var first_load = this.story_titles_clear_loading_endbar();
            
            NEWSBLUR.log(['Sample story: ', stories[0], stories.length]);
            for (s in stories) {
                var story = stories[s];
                var $story_title = this.make_story_title(story);
                if (!stories[s].read_status) {
                    var $mark_read = $.make('a', { className: 'mark_story_as_read', href: '#'+stories[s].id }, '[Mark Read]');
                    $story_title.find('.title').append($mark_read);
                }
                $story_titles.append($story_title);
            }
            if (!stories || stories.length == 0) {
                var $end_stories_line = $.make('div', { 
                    className: 'NB-story-titles-end-stories-line'
                });
                
                if (!($('.NB-story-titles-end-stories-line', $story_titles).length)) {
                    $story_titles.append($end_stories_line);
                }
            }
            this.hover_over_story_titles($story_titles);
            
            this.make_story_feed_entries(stories, first_load);
        },
        
        story_titles_clear_loading_endbar: function() {
            var $story_titles = this.$story_titles;
            var first_load = true;
            
            var $endbar = $('.NB-story-titles-end-stories-line', $story_titles);
            if ($endbar.length) {
                first_load = false;
                $endbar.remove();
                clearInterval(this.feed_stories_loading);
            }
            
            return first_load;
        },
        
        make_story_feed_entries: function(stories, first_load) {
            var $feed_view = this.$feed_view;
            
            var $stories = $.make('ul', { className: 'NB-feed-stories' });
            for (s in stories) {
                var story = stories[s];
                
                var $story = $.make('li', { className: 'NB-feed-story' }, [
                    $.make('div', { className: 'NB-feed-story-header' }, [
                        ( story.story_author &&
                            $.make('div', { className: 'NB-feed-story-author' }, story.story_author)),
                        $.make('a', { className: 'NB-feed-story-title', href: unescape(story.story_permalink) }, story.story_title),
                        ( story.long_parsed_date &&
                            $.make('span', { className: 'NB-feed-story-date' }, story.long_parsed_date))
                    ]),
                    $.make('div', { className: 'NB-feed-story-content' }, story.story_content)                
                ]).data('story', story.id);
                $stories.append($story);
            }
            
            $('.NB-feed-story-endbar', $feed_view).remove();
            var $endbar = $.make('div', { className: 'NB-feed-story-endbar' });
            $stories.append($endbar);
            
            if (first_load) {
                $feed_view.empty();
            }
            $feed_view.scrollTop('0px');
            $feed_view.append($stories);
        },
        
        show_feed_page_contents: function(feed_id) {
            var self = this;
            var $feed_view = this.$story_pane;
            var $story_iframe = $('.NB-feed-frame', $feed_view);
            var $taskbar_view_page = $('.NB-taskbar .task_view_page');
            var $taskbar_return = $('.NB-taskbar .task_return');
            
            if (!feed_id) {
                feed_id = $story_iframe.data('feed_id');
            } else {
                $story_iframe.data('feed_id', feed_id);
            }
            
            $taskbar_view_page.removeClass('NB-inactive');
            $taskbar_return.css({'display': 'none'});
            
            $story_iframe.removeAttr('src').attr({src: '/reader/load_feed_page?feed_id='+feed_id});
            $story_iframe.ready(function() {
                if ($story_iframe.attr('src').indexOf('/reader/load_feed_page?feed_id='+feed_id) != -1) {
                    self.iframe_link_attacher = setInterval(function() {
                        var num_links = $story_iframe.contents().find('a').length;
                        // NEWSBLUR.log(['Finding links', num_links]);
                        if (self.iframe_link_attacher_num_links != num_links) {
                            // NEWSBLUR.log(['Found new links', num_links, self.iframe_link_attacher_num_links]);
                            self.iframe_link_attacher_num_links = num_links;
                            $story_iframe.contents().find('a')
                                .unbind('click.NB-taskbar')
                                .bind('click.NB-taskbar', function() {
                                self.taskbar_show_return_to_page();
                            });
                        }
                    }, 2000);
                }
            });
        },
        
        setup_feed_page_iframe_load: function() {
            var self = this;
            var $story_pane = this.$story_pane;
            var $story_iframe = $('.NB-feed-frame', $story_pane);
            
            $story_iframe.removeAttr('src').load(function() {
                clearInterval(self.iframe_link_attacher);
                $story_iframe.contents().find('a')
                    .unbind('click.NB-taskbar')
                    .bind('click.NB-taskbar', function() {
                    self.taskbar_show_return_to_page();
                });
            });
        },
        
        taskbar_show_return_to_page: function() {
            var $taskbar_return = $('.NB-taskbar .task_return');
            var $taskbar_view_page = $('.NB-taskbar .task_view_page');
            
            $taskbar_return.css({'display': 'block'});
            $taskbar_view_page.addClass('NB-inactive');
        },
        
        load_page_of_feed_stories: function() {
            var $story_titles = this.$story_titles;
            var feed_id = $story_titles.data('feed_id');
            var page = $story_titles.data('page');
            
            var $feed_bar = $.make('div', { className: 'NB-story-titles-end-stories-line' });
            $feed_bar.css({'background': '#E1EBFF'});
            $story_titles.append($feed_bar);
            this.feed_stories_loading = setInterval(function() {
                $feed_bar.animate({'backgroundColor': '#5C89C9'}, {'duration': 750})
                         .animate({'backgroundColor': '#E1EBFF'}, 750);
            }, 1500);
    
            $story_titles.data('page', page+1);
            this.model.load_feed(feed_id, page+1, $.rescope(this.create_story_titles, this));
        },
        
        hover_over_story_titles: function($story_titles) {
            $('.story', $story_titles).each(function() {
                $(this)
                    .unbind('mouseenter')
                    .unbind('mouseleave');
            });
            $('.story', $story_titles)
                .hover(function() {
                    $(this).siblings('.story.NB-story-hover').removeClass('NB-story-hover');
                    $(this).addClass("NB-story-hover");
                }, function() {
                    $(this).siblings('.story.NB-story-hover').removeClass('NB-story-hover');
                    $(this).removeClass("NB-story-hover");                
                });
        },
        
        show_feed_title_in_stories: function($story_titles, feed_id) {
            var feed = this.model.get_feed(feed_id);

            var $feed_bar = $.make('div', { className: 'feed_bar' }, [
                $.make('span', { className: 'unread_count' }, ''+feed.unread_count),
                $.make('span', { className: 'feed_heading' }, [
                    $.make('img', { className: 'feed_favicon', src: this.google_favicon_url + feed.feed_link }),
                    $.make('span', { className: 'feed_title' }, feed.feed_title)
                ]),
                $.make('span', { className: 'feed_id' }, ''+feed.id)
                
            ]);
            
            $story_titles.prepend($feed_bar);
        },
        
        open_feed_link: function(feed_id, $fd) {
            this.mark_feed_as_read(feed_id);
            var feed = this.model.get_feed(feed_id);
            window.open(feed['feed_link'], '_blank');
            window.focus();
        },
        
        mark_feed_as_selected: function(feed_id, $feed_link) {
            $('#feed_list .selected').removeClass('selected');
            $('#feed_list .after_selected').removeClass('after_selected');
            $feed_link.addClass('selected');
            $feed_link.parent('.feed').next('.feed').children('a').addClass('after_selected');
        },
        
        // ===================
        // = Taskbar - Story =
        // ===================
        
        switch_taskbar_view: function($button, story_not_found, story_found) {
            if (!($button.hasClass('NB-active')) || story_not_found || story_found) {
                // NEWSBLUR.log(['$button', $button, this.page_view_showing_feed_view, $button.hasClass('NB-active'), story_not_found]);
                var $taskbar_buttons = $('.NB-taskbar .task_button_view');
                var $feed_view = this.$feed_view;
                var $page_view = this.$page_view;
                var $page_to_feed_arrow = $('.NB-taskbar .NB-task-view-page-to-feed-arrow');
                
                if (story_not_found) {
                    $page_to_feed_arrow.show();
                } else {
                    $taskbar_buttons.removeClass('NB-active');
                    $button.addClass('NB-active');
                    $page_to_feed_arrow.hide();
                    this.page_view_showing_feed_view = false;
                }
                
                if ($button.hasClass('task_view_page')) {
                    $feed_view.animate({
                        'left': $feed_view.width()
                    }, {
                        'easing': 'easeInOutQuint',
                        'duration': 750,
                        'queue': false
                    });
                    $page_view.animate({
                        'left': 0
                    }, {
                        'easing': 'easeInOutQuint',
                        'duration': 750,
                        'queue': false
                    });
                    if (!story_not_found) {
                        this.story_view = 'page';
                    }
                } else if ($button.hasClass('task_view_feed')) {
                    $page_view.animate({
                        'left': -1 * $page_view.width()
                    }, {
                        'easing': 'easeInOutQuint',
                        'duration': 750,
                        'queue': false
                    });
                    $feed_view.animate({
                        'left': 0
                    }, {
                        'easing': 'easeInOutQuint',
                        'duration': 750,
                        'queue': false
                    });
                    if (!story_not_found) {
                        this.story_view = 'feed';
                    }
                }
            }
        },
        
        // ==============
        // = Story Pane =
        // ==============
        
        open_story: function(story_id, $st) {
            var self = this;
            var story = this.find_story_in_stories(story_id);
            NEWSBLUR.log(['Story', story]);
            
            this.mark_story_title_as_selected(story_id, $st);
            this.mark_story_as_read(story_id, $st);
            
            var found_in_page = this.scroll_to_story_in_story_frame(story.story_title, story.story_content);
            this.scroll_to_story_in_story_feed(story, found_in_page);
        },
        
        scroll_to_story_in_story_feed: function(story, found_in_page) {
            var $story;
            var $feed_view = this.$feed_view;
            
            var $stories = $('.NB-feed-story', $feed_view);
            for (var s=0, s_count = $stories.length; s < s_count; s++) {
                if ($stories.eq(s).data('story') == story.id) {
                    $story = $stories.eq(s);
                    break;
                }
            }
            
            if ($story) {
                if (found_in_page) {
                    this.page_view_showing_feed_view = false;
                }
                if (this.story_view == 'feed' || this.page_view_showing_feed_view) {
                    $feed_view.scrollable().stop();
                    $feed_view.scrollTo($story, 600, { axis: 'y', easing: 'easeInOutQuint', offset: 0, queue: false });
                } else if (this.story_view == 'page') {
                    $feed_view.scrollTo($story, 0, { axis: 'y', offset: 0 });
                }
                if (!found_in_page) {
                    this.page_view_showing_feed_view = true;
                }
            }
        },
        
        scroll_to_story_in_story_frame: function(story_title, story_content) {
            var $iframe = $('.NB-feed-frame');
            var title = story_title.replace('^\s+|\s+$', '');
            var $story, $stories = [], title_words, shortened_title, $reduced_stories = [];
            
            $stories = $iframe.contents()
                            .find(':contains("'+title+'")')
                            .filter(function() {
                                return !$(this).find(':contains("'+title+'")').length && $(this).is(':visible');
                            })
                            .not('script')
                            .each(function() {
                                NEWSBLUR.log(['Accepted 1 $elem', $(this), $(this).is(':visible')]);
                            });
            // NEWSBLUR.log(['SS 1:', $stories, $stories.eq(0), $stories.length]);
            
            if (!$stories.length) {
                // Try slicing words off the title, from the end.
                title_words = title.match(/[^ ]+/g);
                if (title_words.length > 2) {
                    shortened_title = title_words.slice(0,-1).join(' ');
                    $iframe.contents().find(':contains('+shortened_title+')')
                        .filter(function() {
                            return !$(this).find(':contains("'+shortened_title+'")').length;
                        })
                        .not('script')
                        .each(function(){
                            if ($(this).is(':visible')) {
                                $stories.push(this);
                            }
                            NEWSBLUR.log(['Accepted 2 $elem', $(this)]);
                        });  
                }
            }
            
            if (!$stories.length) {
                // Try slicing words off the title, from the beginning.
                title_words = title.match(/[^ ]+/g);
                // NEWSBLUR.log(['Words', title_words.length, title_words, title_words.slice(1).join(' '), title_words.slice(0, -1).join(' '), title_words.slice(1, -1).join(' ')])
                if (title_words.length > 2) {
                    for (i in [true, true, true]) {
                        if (i==0) shortened_title = title_words.slice(1).join(' ');
                        if (i==1) shortened_title = title_words.slice(0, -1).join(' ');
                        if (i==2) shortened_title = title_words.slice(1, -1).join(' ');
                        if (!shortened_title) break;
                    
                        $iframe.contents().find(':contains("'+shortened_title+'")')
                            .filter(function() {
                                return !$(this).find(':contains("'+shortened_title+'")').length;
                            })
                            .not('script')
                            .each(function(){
                                if ($(this).is(':visible')) {
                                    $stories.push(this);
                                }
                                NEWSBLUR.log(['Accepted 3 $elem', $(this)]);
                            });  
                        // NEWSBLUR.log(['Cutting words off title', $stories.length, $stories]);
                        if ($stories.length) break;
                    }
                }
            }
            
            if (!$stories.length) {
                // Try using story content instead of title.
                content_words = story_content.replace(/<([^<>\s]*)(\s[^<>]*)?>/, '')
                                             .replace(/\(.*?\)/, '')
                                             .match(/[^ ]+/g);
                // NEWSBLUR.log(['content_words', content_words]);
                if (content_words.length > 2) {
                    var shortened_content = content_words.slice(0, 6).join(' ');
                    $iframe.contents().find(':contains('+shortened_content+')')
                        .filter(function() {
                            return !$(this).find(':contains("'+shortened_content+'")').length;
                        })
                        .not('script')
                        .each(function(){
                            if ($(this).is(':visible')) {
                                $stories.push(this);
                            }
                            NEWSBLUR.log(['Accepted 4 $elem', $(this)]);
                        });  
                }
            }
            
            // If multiple $story's, find one under a <h#>
            $stories.each(function() {
                if (!$story && $(this).parents('h1,h2,h3').length) {
                    $story = $(this);
                    return;
                } else if (!$story && $(this).parents('h4, h5, h6').length) {
                    $story = $(this);
                    return;
                }
            });
            if (!$story) $story = $stories.eq(0);
            
            NEWSBLUR.log(['Found story', $story, this.story_view, this.page_view_showing_feed_view]);
            if ($story && $story.length) {
                if (this.story_view == 'feed' || this.page_view_showing_feed_view) {
                    $iframe.scrollTo($story, 0, { axis: 'y', offset: -24 });
                } else if (this.story_view == 'page') {
                    $iframe.scrollable().stop();
                    $iframe.scrollTo($story, 800, { axis: 'y', easing: 'easeInOutQuint', offset: -24, queue: false });
                }
                if (this.story_view == 'page' && this.page_view_showing_feed_view) {
                    var $button = $('.NB-taskbar .task_view_page');
                    this.switch_taskbar_view($button, false, true);
                }
            } else {
                // Story not found, show in feed view with link to page view
                if (this.story_view == 'feed') {
                    // Nowhere to scroll to
                } else if (this.story_view == 'page') {
                    var $button = $('.NB-taskbar .task_view_feed');
                    this.switch_taskbar_view($button, true);
                }
            }
            
            return $story && $story.length > 0;
        },
        
        open_story_link: function(story_id, $st) {
            var story = this.model.get_story(story_id);
            window.open(unescape(story['story_permalink']), '_blank');
            window.focus();
        },
        
        mark_story_title_as_selected: function(story_id, $story_title) {
            $('.selected', this.$story_titles).removeClass('selected');
            $('.after_selected', this.$story_titles).removeClass('after_selected');
            $story_title.addClass('selected');
            $story_title.parent('.story').next('.story').children('a').addClass('after_selected');
        },
        
        find_story_in_stories: function(story_id) {
            var stories = this.model.stories;
            for (s in stories) {
                if (stories[s].id == story_id) {
                    return stories[s];
                }
            }
            return null;
        },
        
        mark_story_as_read: function(story_id, $story_title) {
            var self = this;
            var feed_id = this.active_feed;

            var callback = function() {
                return;
            };

            $story_title.addClass('read');
            if (NEWSBLUR.Globals.is_authenticated) {
                this.model.mark_story_as_read(story_id, feed_id, callback);
            }
        },
        
        mark_feed_as_read: function(feed_id) {
            var self = this;

            var callback = function() {
                return;
            };

            this.model.mark_feed_as_read(feed_id, callback);
        },
        
        mark_story_as_like: function(story_id, $button) {
            var self = this;

            var callback = function() {
                return;
            };

            $button.addClass('liked');
            if (NEWSBLUR.Globals.is_authenticated) {
                this.model.mark_story_as_like(story_id, callback);
            }
        },
        
        mark_story_as_dislike: function(story_id, $button) {
            var self = this;

            var callback = function() {
                return;
            };

            $button.addClass('disliked');
            if (NEWSBLUR.Globals.is_authenticated) {
                this.model.mark_story_as_dislike(story_id, callback);
            }            
        },
        
        
        // ========
        // = OPML =
        // ========
        
        open_opml_import_modal_form: function() {
            var self = this;
            
            var $opml = $.make('div', { className: 'NB-opml-upload' }, [
                $.make('form', { enctype: 'multipart/form-data', method: 'post' }, [
                    $.make('input', { type: 'file', name: 'file', id: 'opml_file_input' }),
                    $.make('input', { type: 'submit', value: 'Upload OPML File' })
                ]).bind('submit', function(e) {
                    e.preventDefault();
                    self.handle_opml_upload();
                    return false;
                })
            ]);
            
            $opml.modal({
                'overlayClose': true,
                'onShow': function() {
                    $('#simplemodal-container').corners('8px');
                }
            });
        },
        
        handle_opml_upload: function() {
            var self = this;
            
            NEWSBLUR.log(['Uploading']);
            $.ajaxFileUpload({
				url: '/opml/opml_upload', 
				secureuri: false,
				fileElementId: 'opml_file_input',
				dataType: 'json',
				success: function (data, status)
				{
					if (typeof data.code != 'undefined') {
						if (data.code <= 0) {
							NEWSBLUR.log(['Success - Error', data.code]);
						} else {
							NEWSBLUR.log(['Success', data]);
							self.load_feeds();
						}
					}
				},
				error: function (data, status, e)
				{
					NEWSBLUR.log(['Error', data, status, e]);
				}
			});
			
			return false;
        },
        
        handle_opml_form: function() {
            var self = this;
            var $form = $('form.opml_import_form');
            
            NEWSBLUR.log(['OPML Form:', $form]);
            
            var callback = function(e) {
                NEWSBLUR.log(['OPML Callback', e]);
            };
            
            $form.submit(function() {
                
                self.model.process_opml_import($form.serialize(), callback);
                return false;
            });
        },
        
        handle_clicks: function(elem, e) {
            var self = this;

            // =========
            // = Feeds =
            // =========
            
            $.targetIs(e, { tagSelector: '#feed_list .feed' }, function($t, $p){
                e.preventDefault();
                var feed_id = $('.feed_id', $t).text();
                self.open_feed(feed_id, $t);
            });
            $.targetIs(e, { tagSelector: 'a.mark_feed_as_read' }, function($t, $p){
                e.preventDefault();
                var feed_id = $t.attr('href').slice(1).split('/');
                self.mark_feed_as_read(feed_id, $t);
            });
            
            // ===========
            // = Stories =
            // ===========
            
            $.targetIs(e, { tagSelector: '.story' }, function($t, $p){
                e.preventDefault();
                var story_id = $('.story_id', $t).text();
                self.open_story(story_id, $t);
            });
            $.targetIs(e, { tagSelector: 'a.mark_story_as_read' }, function($t, $p){
                e.preventDefault();
                var story_id = $t.attr('href').slice(1).split('/');
                self.mark_story_as_read(story_id, $t);
            });
            $.targetIs(e, { tagSelector: 'a.button.like' }, function($t, $p){
                e.preventDefault();
                var story_id = self.$story_pane.data('story_id');
                self.mark_story_as_like(story_id, $t);
            });
            $.targetIs(e, { tagSelector: 'a.button.dislike' }, function($t, $p){
                e.preventDefault();
                var story_id = self.$story_pane.data('story_id');
                self.mark_story_as_dislike(story_id, $t);
            });
            
            // ===========
            // = Taskbar =
            // ===========
            
            $.targetIs(e, { tagSelector: '.task_button_menu' }, function($t, $p){
                e.preventDefault();
                self.open_taskbar_menu($t);
            });
            $.targetIs(e, { tagSelector: '.task_button_view' }, function($t, $p){
                e.preventDefault();
                self.switch_taskbar_view($t);
            });
            $.targetIs(e, { tagSelector: '.task_return', childOf: '.NB-taskbar' }, function($t, $p){
                e.preventDefault();
                self.show_feed_page_contents();
            });
            $.targetIs(e, { tagSelector: '.NB-task-import-upload-opml' }, function($t, $p){
                e.preventDefault();
                self.open_opml_import_modal_form($t);
            });
            
            
        },
        
        handle_dblclicks: function(elem, e) {
            var self = this;
            
            $.targetIs(e, { tagSelector: '#story_titles .story' }, function($t, $p){
                e.preventDefault();
                NEWSBLUR.log(['Story dblclick', $t]);
                var story_id = $('.story_id', $t).text();
                self.open_story_link(story_id, $t);
            });
            $.targetIs(e, { tagSelector: '#feed_list .feed' }, function($t, $p){
                e.preventDefault();
                NEWSBLUR.log(['Feed dblclick', $('.feed_id', $t), $t]);
                self.open_feed_link(feed_id, $t);
            });
        },
        
        handle_scroll: function(elem, e) {
            var self = this;

            if (!($('.NB-story-titles-end-stories-line', this.$story_titles).length)) {
                var container_offset = this.$story_titles.position().top;
                var full_height = $('#story_titles .story:last').offset().top + $('#story_titles .story:last').height() - container_offset;
                var visible_height = $('#story_titles').height();
                var scroll_y = $('#story_titles').scrollTop();
                // NEWSBLUR.log(['Story_titles Scroll', full_height, container_offset, visible_height, scroll_y]);
            
                if (full_height <= visible_height) {
                    this.load_page_of_feed_stories();
                }
            }
        },
        
        // ===================
        // = Bottom Task Bar =
        // ===================

        setup_taskbar_nav_left: function() {
            var self = this;
            var $task_buttons = $('.NB-taskbar .taskbar_nav_left .task_button');
            var $taskbar_menu = $('.NB-taskbar .taskbar_nav_left .taskbar_menu li span').corners('2px');
            
            $task_buttons.each(function() {
                var $this = $(this);
                var $menu = $('.taskbar_menu', $this);
                
                $this.hover(function() {
                    if ($this.hasClass('active')) {
                        $this.stopTime('task');
                        if ($menu.shadowId()) {
                            $menu.showShadow();
                        } else {
                            $menu.dropShadow();
                        }
                        $menu
                            .stop()
                            .css({ opacity: 1 });
                    }
                }, function() {
                    if ($this.hasClass('active')) {
                        $menu.hideShadow();
                        
                        $this.stopTime('task')
                        .oneTime(750, 'task', function() {
                            $('.taskbar_menu', $this).animate({ opacity: 0 }, 1500, 'easeInQuad', function() {
                                self.close_taskbar_menu($this);
                                $menu.removeShadow();
                            });
                        });
                    }
                });
            });
        },
        
        open_taskbar_menu: function($taskbar_button, e) {
            var self = this;
            var $task_buttons = $('.NB-taskbar .taskbar_nav_left .task_button');
            
            if ($taskbar_button.hasClass('active')) {
                // Close
                this.close_taskbar_menu($taskbar_button);
            } else {
                // Open
                $taskbar_button.addClass('active');
                $('.taskbar_menu', $taskbar_button).stop().css({ opacity: 1 }).dropShadow();
                
                $task_buttons.each(function() {
                    if (this != $taskbar_button[0]) {
                        self.close_taskbar_menu($(this));
                    }
                });
                
                $(document).bind('click.taskbar_menu', function() {
                    self.close_taskbar_menu($taskbar_button);
                });
                $('.taskbar_menu', $taskbar_button).bind('click.taskbar_menu', function(e) {
                    // e.stopPropagation();
                });
            }
        },
        
        close_taskbar_menu: function($taskbar_button) {
            $taskbar_button.stopTime('task');
            $taskbar_button.removeClass('active');
            $('.taskbar_menu', $taskbar_button).removeShadow();
            $(document).unbind('click.taskbar_menu');
        }
    };

})(jQuery);

$(document).ready(function() {

    var _Reader = new NEWSBLUR.reader();
    

});