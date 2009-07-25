(function($) {
    
    var middleLayout, outerLayout;

    NEWSBLUR.reader = function() {
        var self = this;
        this.$feed_list = $('#feed_list');
        this.$story_titles = $('#story_titles');
        this.$story_pane = $('#story_pane');
        this.$account_menu = $('.menu_button');

        this.model = NEWSBLUR.AssetModel.reader();
        this.options = {};
        this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
        
        $('body').live('click', $.rescope(this.handle_clicks, this));
        $('body').live('dblclick', $.rescope(this.handle_dblclicks, this));
        $('#story_titles').scroll($.rescope(this.handle_scroll, this));
        
        this.load_page();
        this.load_feeds();
        this.apply_resizable_layout();
        this.cornerize_buttons();
        this.handle_keystrokes();
        this.setup_taskbar_leftnav();
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
            var outerLayout, middleLayout;
            
        	outerLayout = $('body').layout({ 
        	    closable: false,
    			center__paneSelector:	".center-pane",
    			south__paneSelector:	"#taskbar",
    			south__size:            29,
    			south__resizable:       false,
    			south__spacing_open:    0,
    			west__paneSelector:		"#feed_list",
    			west__size:				300,
    			spacing_open:			4,
    			center__onresize:		"middleLayout.resizeAll",
    			resizerDragOpacity:     0.6
    		}); 

    		middleLayout = $('.center-pane').layout({ 
    			center__paneSelector:	".middle-center",
    			north__paneSelector:	".middle-north",
    			north__size:			208,
    			spacing_open:			10,
    			center__onresize:		"middleLayout.resizeAll",
    			resizerDragOpacity:     0.6
    		}); 
        },
        
        resize_story_content_pane: function() {
            var doc_height = $(document).height();
            var stories_pane_height = this.$story_titles.height();
            var story_content_top = parseInt(this.$story_titles.css('top'), 10);
            
            var new_story_pane_height = doc_height - (stories_pane_height + story_content_top);
            // NEWSBLUR.log(['Height', doc_height, stories_pane_height, story_content_top]);
            this.$story_pane.css('height', new_story_pane_height);
        },
        
        resize_feed_list_pane: function() {
            var doc_height = $(document).height();
            var feed_list_top = parseInt($('#feed_list').css('top'), 10);
            
            var new_feed_list_height = doc_height - feed_list_top;
            // NEWSBLUR.log(['Height', doc_height, feed_list_top, new_feed_list_height]);
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
                var next_offset = this.$story_titles.scrollTop() + $next_story.offset().top - $next_story.outerHeight();
                var scroll = Math.max(0, next_offset);
                this.$story_titles.scrollTop(scroll);
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
            NEWSBLUR.log(['page', page_height, scroll_height, this.$story_pane]);
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
                var $feed_list = self.$feed_list;
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
            this.$story_titles.data('page', 0);
            this.$story_titles.data('feed_id', feed_id);
            
            this.show_feed_title_in_stories($story_titles, feed_id);
            this.mark_feed_as_selected(feed_id, $feed_link);
            this.model.load_feed(feed_id, 0, $.rescope(this.create_story_titles, this));
        },
        
        create_story_titles: function(e, stories) {
            var $story_titles = this.$story_titles;
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
        },
        
        load_page_of_feed_stories: function() {
            var feed_id = this.$story_titles.data('feed_id');
            var page = this.$story_titles.data('page');
            this.$story_titles.data('page', page+1);
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
        
        // ==============
        // = Story Pane =
        // ==============
        
        open_story: function(story_id, $st) {
            var self = this;
            var story = this.find_story_in_stories(story_id);
            NEWSBLUR.log(['Story', story]);
            if (story) {                
                var $story_title = $.make('a', { href: unescape(story.story_permalink) }, story.story_title);
                $('.story_title', this.$story_pane).html($story_title);
                if (story.story_author) {
                    $('.story_author').show();
                    $('.story_author .data').html(story.story_author);
                } else {
                    $('.story_author').hide();
                }
                if (story.long_parsed_date) {
                    $('.story_date').show();
                    $('.story_date .data', this.$story_pane).html(story.long_parsed_date);                    
                } else {
                    $('.story_date').hide();
                }
                $('.story_content', this.$story_pane).html(story.story_content);
                
                var $story_feed__list = $.make('span', [
                    $.make('img', { 
                        className: 'feed_favicon', 
                        src: this.google_favicon_url + story.story_feed_link
                    }),
                    story.story_feed_title
                ]);
                $('.story_feed .data', this.$story_pane)
                                  .empty()
                                  .append($story_feed__list);
                                  
                this.$story_pane.scrollTop('0px');
                this.$story_pane.data('story_id', story_id);
            }
            this.mark_story_title_as_selected(story_id, $st);
            this.mark_story_as_read(story_id, $st);
        },
        
        open_story_link: function(story_id, $st) {
            var story = this.model.get_story(story_id);
            window.open(story['story_permalink'], '_blank');
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

            var callback = function() {
                return;
            };

            $story_title.addClass('read');
            if (NEWSBLUR.Globals.is_authenticated) {
                this.model.mark_story_as_read(story_id, callback);
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
                NEWSBLUR.log(['Feed click', $('.feed_id', $t), $t]);
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
            
            $.targetIs(e, { tagSelector: '.task_button' }, function($t, $p){
                e.preventDefault();
                self.open_taskbar_menu($t, e);
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
                var full_height = $('#story_titles .story:last').offset().top + $('#story_titles .story:last').height();
                var visible_height = $('#story_titles').height();
                // var scroll_y = $('#story_titles').scrollTop();
                // NEWSBLUR.log(['Story_titles Scroll', full_height, visible_height, scroll_y]);
            
                if (full_height <= visible_height) {
                    this.load_page_of_feed_stories();
                }
            }
        },
        
        // ===================
        // = Bottom Task Bar =
        // ===================

        setup_taskbar_leftnav: function() {
            var self = this;
            var $task_buttons = $('#taskbar .taskbar_leftnav .task_button');
            var $taskbar_menu = $('#taskbar .taskbar_leftnav .taskbar_menu li span').corners('2px');
            
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
            var $task_buttons = $('#taskbar .taskbar_leftnav .task_button');
            
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