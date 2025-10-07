{% load utils_tags %}

(function() {
    window.NEWSBLUR = window.NEWSBLUR || {};
    var exports = undefined;
    
    {% include_javascripts_raw "bookmarklet" %}
    
    var $ = window.NB_$;
    console.log('jquery', $, window.NB_$);
    NEWSBLUR.Bookmarklet = function(options) {
        var defaults = {};
        
        this.token    = "{{ token }}";
        this.active   = true;
        this.user_id  = '{{ user.pk }}';
        this.username = '{{ user.username }}';
        this.profile  = {{ user_profile|safe }};
        this.folders  = {{ folders|safe }};
        this.domain   = "{% current_domain %}";
        this.starred_counts = {{ starred_counts|safe }};
        this.flags    = {
            'new_folder': false,
            'in_transit': false
        };
        this.images   = {
            'accept_image': "{{ accept_image }}"
        };
        
        this.options  = $.extend({}, defaults, options);
        this.runner();

        {% if code < 0 %}
        this.show_error();
        {% endif %}
    };

    NEWSBLUR.Bookmarklet.prototype = {
        
        // ==================
        // = Initialization =
        // ==================
        
        fix_title: function() {
            var d = document;
            d.title = d.title.replace(/\(Sharing\.\.\.\)\s?/g, '');
            d.title = d.title.replace(/\(Adding\.\.\.\)\s?/g, '');
        },
        
        close: function() {
            this.active = false;
            $('body').css('overflow', 'scroll');
        },
        
        runner: function() {
            this.fix_title();
        
            if (this.check_if_on_newsblur()) {
                var message = "This bookmarklet is successfully installed.\nClick it while on a site you want to read in NewsBlur.";
                this.alert(message);
                return this.close();
            }
            
            this.attach_css();
            this.make_modal();
            this.open_modal();

            this.$modal.bind('click', $.rescope(this.handle_clicks, this));

            var $comment = $('textarea[name=newsblur_comment]', this.$modal);
            var $title = $('.NB-bookmarklet-page-title', this.$modal);
            var $content = $('.NB-bookmarklet-page-content', this.$modal);
            $comment.bind('keydown', $.rescope(this.update_share_button_title, this));
            $comment.bind('keyup', $.rescope(this.update_share_button_title, this));
            $title.bind('keyup', $.rescope(this.update_share_button_title, this));
            $content.bind('keyup', $.rescope(this.update_share_button_title, this));
            $comment.bind('keydown', 'ctrl+return', $.rescope(this.share_story, this));
            $comment.bind('keydown', 'meta+return', $.rescope(this.share_story, this));

            this.get_page_content();
        },
            
        make_modal: function() {
            var self = this;

            this.$modal = $.make('div', { className: 'NB-bookmarklet NB-modal' }, [
                $.make('div', { className: 'NB-modal-information' }, [
                    'Signed in as ',
                    $.make('b', { style: 'color: #505050' }, this.username)
                ]),
                $.make('div', { className: 'NB-modal-title' }, 'Send this story to NewsBlur'),
                $.make('div', { className: 'NB-bookmarklet-main'}, [
                    $.make('div', { className: 'NB-bookmarklet-page' }, [
                        $.make('div', { className: 'NB-bookmarklet-page-title', contenteditable: true }),
                        $.make('div', { className: 'NB-bookmarklet-page-content-wrapper' }, [
                            $.make('div', { className: 'NB-bookmarklet-page-content', contenteditable: true })
                        ]),
                        $.make('div', { className: 'NB-bookmarklet-page-comment NB-modal-submit' }, [
                            $.make('div', { className: 'NB-bookmarklet-comment-error NB-error' }),
                            $.make('div', { className: 'NB-bookmarklet-submit-left' }, [
                                $.make('div', { className: 'NB-bookmarklet-user-tags' }, [
                                    $.make('select', { multiple: "1", name: "user_tags" }, this.make_user_tags_options())
                                ]),
                                $.make('input', { className: 'NB-bookmarklet-add-tag', name: "add_user_tag", placeholder: "Add tags..." }),
                                $.make('div', { className: 'NB-bookmarklet-save-button NB-modal-submit-button NB-modal-submit-green' }, 'Save this story')
                            ]),                                
                            $.make('div', { className: 'NB-bookmarklet-submit-right' }, [
                                $.make('div', { className: 'NB-bookmarklet-comment-separator' }),
                                $.make('div', { className: 'NB-bookmarklet-comment-container' }, [
                                    $.make('div', { className: 'NB-bookmarklet-comment-photo' }, [
                                        $.make('img', { src: this.profile.photo_url })
                                    ]),
                                    $.make('div', { className: 'NB-bookmarklet-comment-input' }, [
                                        $.make('textarea', { name: 'newsblur_comment', placeholder: "Comments..." })
                                    ])
                                ]),
                                $.make('div', { className: 'NB-bookmarklet-comment-submit NB-modal-submit-button NB-modal-submit-green' }, 'Share this story')
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-bookmarklet-side' }, [
                    $.make('div', { className: 'NB-bookmarklet-side-half NB-bookmarklet-side-subscribe' }, [
                        $.make('div', { className: 'NB-subscribe-feed' }),
                        $.make('div', { className: 'NB-bookmarklet-folder-container' }, [
                            $.make('img', { className: 'NB-bookmarklet-folder-add-button', src: 'data:image/png;charset=utf-8;base64,{{ add_image }}', title: 'Add New Folder' }),
                            this.make_folders(),
                            $.make('div', { className: 'NB-bookmarklet-new-folder-container' }, [
                                $.make('img', { className: 'NB-bookmarklet-folder-new-label', src: 'data:image/png;charset=utf-8;base64,{{ new_folder_image }}' }),
                                $.make('input', { type: 'text', name: 'new_folder_name', className: 'NB-bookmarklet-folder-new' })
                            ])
                        ]),
                        $.make('div', { className: 'NB-modal-submit' }, [
                            $.make('div', { className: 'NB-bookmarklet-button-subscribe NB-modal-submit-button NB-modal-submit-green' }, 'Subscribe')
                        ]),
                        $.make('div', { className: 'NB-bookmarklet-stories-same NB-empty'}),
                        $.make('div', { className: 'NB-bookmarklet-stories-other NB-empty'}),
                        $.make('div', { className: 'NB-bookmarklet-stories-previous NB-empty'})
                    ]),
                    $.make('div', { className: 'NB-bookmarklet-side-half NB-bookmarklet-side-loading' }, [
                        $.make('img', { className: 'NB-subscribe-loader', src: 'data:image/png;charset=utf-8;base64,{{ add_image }}', title: 'Loading...' }),
                        $.make('div', { className: 'NB-subscribe-load-text' }, 'Shared stories are on their way...')
                    ])
                ])
            ]);
        },
        
        make_user_tags_options: function() {
            var options = __NB_.map(__NB_.filter(this.starred_counts, function(count) {
                return count.tag && count.tag.length
            }), function(count) {
                return $.make('option', { value: count.tag }, count.tag + " ("+ count.count + (count.count == 1 ? " story": " stories")+")");
            });
            
            return options;
        },
        
        make_folders: function() {
            var folders = this.folders;
            var $options = $.make('select', { className: 'NB-folders'});
        
            $options = this.make_folder_options($options, folders, '-');
            
            var $option = $.make('option', { value: '', selected: true }, "Top Level");
            $options.prepend($option);
    
            return $options;
        },

        make_folder_options: function($options, items, depth) {
            if (depth && depth.length > 5) {
                return $options;
            }
            
            for (var i in items) {
                if (!items.hasOwnProperty(i)) continue;
                var item = items[i];
                if (typeof item == "object") {
                    for (var o in item) {
                        if (!item.hasOwnProperty(o)) continue;
                        var folder = item[o];
                        var $option = $.make('option', { value: o }, depth + ' ' + o);
                        $options.append($option);
                        $options = this.make_folder_options($options, folder, depth+'-');
                    }
                }
            }
    
            return $options;
        },

        open_modal: function() {
            var self = this;
        
            this.$modal.modal({
                'minWidth': $(window).width() - 80,
                'maxWidth': 800,
                'overlayClose': true,
                'onOpen': function (dialog) {
                    dialog.overlay.fadeIn(200, function () {
                        dialog.container.fadeIn(200);
                        dialog.data.fadeIn(200);
                        setTimeout(function() {
                            self.pre_share_check_story();
                            $(window).resize();
                        }, 10);
                    });
                },
                'onShow': function(dialog) {
                    $('#simplemodal-container').corner('6px');
                },
                'onClose': function(dialog) {
                    dialog.data.hide().empty().remove();
                    dialog.container.hide().empty().remove();
                    dialog.overlay.fadeOut(200, function() {
                        dialog.overlay.empty().remove();
                        $.modal.close();
                        self.close();
                    });
                    $('.NB-modal-holder').empty().remove();
                }
            });
            
            $('body').css('overflow', 'hidden');
        },
        
        // ============
        // = Add site =
        // ============
        
        show_error: function() {
            $('.NB-bookmarklet-folder-container', this.$modal).hide();
            $('.NB-modal-submit', this.$modal).html($.make('div', { className: 'NB-error-invalid' }, [
                'This bookmarklet no longer matches an account. Re-create it in ',
                $.make('a', { href: 'http://www.newsblur.com/?next=goodies' }, 'Goodies on NewsBlur'),
                '.'
            ]));
        },

        subscribe: function() {
            var self = this;
            var $submit = $('.NB-bookmarklet-button-subscribe', this.$modal);
            var folder = $('.NB-folders').val();
            var add_site_url = "//"+this.domain+"{% url "api-add-site" token %}?callback=?";
            
            $submit.addClass('NB-disabled').text('Fetching and parsing...');
            
            var data = {
                url: window.location.href,
                folder: folder
            };
            
            if (this.flags['new_folder']) {
                var new_folder_name = $('input[name=new_folder_name]', this.$modal).val();
                if (new_folder_name) {
                    data['new_folder'] = new_folder_name;
                }
            }
            
            $.getJSON(add_site_url, data, function(resp) {
                self.confirm_subscription(resp.code > 0, resp.message);
            });
        },
        
        confirm_subscription: function(subscribed, message) {
            var $submit = $('.NB-bookmarklet-button-subscribe', this.$modal);
            
            $submit.addClass('NB-disabled');
            
            if (subscribed) {
                $submit.html($.make('div', { className: 'NB-bookmarklet-accept' }, [
                    $.make('img', { src: 'data:image/png;charset=utf-8;base64,' + this.images['accept_image'] }),
                    'Subscribed'
                ]));
                // setTimeout(function() {
                //     $.modal.close();
                // }, 2000);
            } else {
                var $error = $.make('div', { className: 'NB-bookmarklet-error' }, [
                    $.make('img', { className: 'NB-bookmarklet-folder-label', src: 'data:image/png;charset=utf-8;base64,{{ error_image }}' }),
                    $.make('div', message)
                ]);
                $('.NB-bookmarklet-folder-container').hide();
                $submit.replaceWith($error);
            }
        },
        
        // =============
        // = Pre-share =
        // =============
        
        pre_share_check_story: function() {
            var $main = $('.NB-bookmarklet-main', this.$modal);
            var $side = $('.NB-bookmarklet-side', this.$modal);
            var $side_loading = $('.NB-bookmarklet-side-loading', this.$modal);
            var $side_subscribe = $('.NB-bookmarklet-side-subscribe', this.$modal);
            var $share = $(".NB-bookmarklet-comment-submit", this.$modal);
            var $save = $(".NB-bookmarklet-save-button", this.$modal);
            var $comments = $('textarea[name=newsblur_comment]', this.$modal);
            var $content_wrapper = $('.NB-bookmarklet-page-content-wrapper', this.$modal);
            var $content = $('.NB-bookmarklet-page-content', this.$modal);
            var check_story_url = "//"+this.domain+"{% url "api-check-share-on-site" token %}?callback=?";
            var data = {
                story_url: window.location.href,
                rss_url: this.get_page_rss_url()
            };
            
            $.getJSON(check_story_url, data, __NB_.bind(function(data) {
                $side_loading.animate({'left': '-100%'}, {
                    'easing': 'easeInOutQuint',
                    'duration': 1650,
                    'queue': false
                });
                $side_subscribe.css('left', $side.outerWidth(true)+4).animate({'left': 0}, {
                    'easing': 'easeInOutQuint',
                    'duration': 1650,
                    'queue': false
                });
                this.feed = data.feed;
                this.make_feed_subscribe(data.feed);
                if (data.subscribed) {
                    $('.NB-bookmarklet-folder-container', this.$modal).hide();
                    this.confirm_subscription(data.subscribed);
                }
                if (data.your_story) {
                    $(".NB-bookmarklet-page-title", this.$modal).html(data.your_story['story_title']);
                    $(".NB-bookmarklet-page-content", this.$modal).html(data.your_story['story_content']);
                    $share.addClass('NB-disabled').html($.make('div', { className: 'NB-bookmarklet-accept' }, [
                        $.make('img', { src: 'data:image/png;charset=utf-8;base64,' + this.images['accept_image'] }),
                        'Shared'
                    ]));
                    $comments.val(data.your_story['comments']);
                }
                this.users = data.users;
                if (data.same_stories && data.same_stories.length) {
                    this.make_shared_stories_same(data.same_stories);
                }
                if (data.other_stories && data.other_stories.length) {
                    this.make_shared_stories_other(data.other_stories);
                }
                if (data.previous_stories && data.previous_stories.length) {
                    this.make_shared_stories_previous(data.previous_stories);
                }
                
                var modal_height = $(".NB-bookmarklet").parent().height();
                var total_height = $(".NB-bookmarklet").height();
                if (modal_height < total_height) {
                    var diff = total_height - modal_height;
                    $content_wrapper.css('max-height', parseInt($content_wrapper.css('max-height'), 10) - (diff + 24));
                    console.log(["heights", $main.height(), modal_height, total_height, diff, $content_wrapper.css('max-height'), $side.height()]);
                }
                $side.height($main.height());
            }, this));
        },
        
        make_feed_subscribe: function(feed) {
            if (feed) {
                var $feed = $.make('div', { className: 'NB-subscribe-feed' }, [
                    $.make('img', { src:  'data:image/png;charset=utf-8;base64,' + feed.favicon }),
                    $.make('div', { className: 'NB-subscribe-feed-title' }, feed.feed_title)
                ]);
                $('.NB-subscribe-feed', this.$modal).replaceWith($feed);
            }
        },
        
        make_shared_stories_same: function(stories) {
            var $stories = $(".NB-bookmarklet-stories-same", this.$modal);

            $stories.removeClass('NB-empty');
            $stories.empty().append($.make('div', { className: 'NB-bookmarklet-stories-title' }, [
                'Everybody sharing this story'
            ]));
            
            __NB_.each(stories, __NB_.bind(function(story) {
                var $story = this.make_shared_story(story);
                $stories.append($story);
            }, this));
        },
        
        make_shared_stories_other: function(stories) {
            var $stories = $(".NB-bookmarklet-stories-other", this.$modal);

            $stories.removeClass('NB-empty');
            $stories.empty().append($.make('div', { className: 'NB-bookmarklet-stories-title' }, [
                $.make('img', { src:  'data:image/png;charset=utf-8;base64,' + this.feed.favicon }),
                'Other stories from this site'
            ]));
            
            __NB_.each(stories, __NB_.bind(function(story) {
                var $story = this.make_shared_story(story);
                $stories.append($story);
            }, this));
        },
        
        make_shared_stories_previous: function(stories) {
            var $stories = $(".NB-bookmarklet-stories-previous", this.$modal);
            var user = this.users[this.user_id];
            
            $stories.removeClass('NB-empty');
            $stories.empty().append($.make('div', { className: 'NB-bookmarklet-stories-title' }, [
                $.make('img', { src: user.photo_url }),
                'Previously you shared'
            ]));
            
            __NB_.each(stories, __NB_.bind(function(story) {
                var $story = this.make_shared_story(story);
                $stories.append($story);
            }, this));
        },
        
        make_shared_story: function(story) {
            var user = this.users[story.user_id];
            var $story = $.make('a', { 
                className: 'NB-bookmarklet-shared-story NB-story',
                href: story.blurblog_permalink,
                target: '_blank'
            }, [
                $.make('img', { src: user.photo_url }),
                $.make('div', { className: 'NB-story-username' }, user.username),
                (story.story_title && story.story_title.length && ' shared '),
                (story.story_title && story.story_title.length && $.make('div', { className: 'NB-story-title' }, story.story_title)),
                (story.comments && story.comments.length && $.make('div', { className: 'NB-story-comments' }, story.comments)),
                $.make('div', { className: 'NB-story-date' }, story.relative_date + ' ago')
            ]);
            
            return $story;
        },
        
        
        // ==============
        // = Save story =
        // ==============
        
        save_story: function(disable_https) {
            var $save = $(".NB-bookmarklet-save-button", this.$modal);
            var $error = $(".NB-bookmarklet-comment-error", this.$modal);
            
            this.flags.in_transit = true;
            
            $error.html('');
            $save.addClass('NB-disabled').text('Saving...');
            this.feed = this.feed || {};
            
            // var scheme = {% if debug %}'http'{% else %}'https'{% endif %};
            var scheme = 'https';
            var url = scheme + '://' + this.domain + "{% url "api-save-story" token %}";
            
            $.ajax({
                url: url,
                type: 'POST',
                data: {
                    title: $(".NB-bookmarklet-page-title", this.$modal).html() || this.story_title,
                    content: $(".NB-bookmarklet-page-content", this.$modal).html() || this.story_content,
                    user_tags: $('select[name=user_tags]', this.$modal).val(),
                    add_user_tag: $('input[name=add_user_tag]', this.$modal).val(),
                    feed_id: this.feed.id,
                    story_url: window.location.href,
                    rss_url: this.get_page_rss_url()
                },
                success: __NB_.bind(this.post_save_story, this),
                error: __NB_.bind(this.error_save_story, this)
            });
        },
        
        post_save_story: function(data) {
            var $save = $(".NB-bookmarklet-save-button", this.$modal);
            this.flags.in_transit = false;
            
            if (data.code < 0) {
                return this.error_save_story(data);
            }
            
            $save.addClass('NB-disabled');
            $save.html($.make('div', { className: 'NB-bookmarklet-accept' }, [
                $.make('img', { src: 'data:image/png;charset=utf-8;base64,' + this.images['accept_image'] }),
                'Saved'
            ]));
            this.pre_share_check_story();
            setTimeout(function() {
                // $.modal.close();
            }, 2000);

        },
        
        error_save_story: function(data) {
            var $save = $(".NB-bookmarklet-save-button", this.$modal);
            var $error = $(".NB-bookmarklet-comment-error", this.$modal);
            this.flags.in_transit = false;
            
            $save.removeClass('NB-disabled');
            $error.show();
            console.log(["error sharing", data]);
            
            this.update_share_button_title();

            $error.text(data.message || "Sorry, but there was an error trying to save this story.")
        },
        
        // ===============
        // = Share story =
        // ===============
        
        share_story: function(disable_https) {
            var $share = $(".NB-bookmarklet-comment-submit", this.$modal);
            var $error = $(".NB-bookmarklet-comment-error", this.$modal);
            
            this.flags.in_transit = true;
            
            $error.html('');
            $share.addClass('NB-disabled').text('Sharing...');
            this.feed = this.feed || {};
            
            var scheme = '{% if debug %}http{% else %}https{% endif %}';
            var url = scheme + '://' + this.domain + '{% url "api-share-story" token %}';
            
            $.ajax({
                url: url,
                type: 'POST',
                data: {
                    title: $(".NB-bookmarklet-page-title", this.$modal).html() || this.story_title,
                    content: $(".NB-bookmarklet-page-content", this.$modal).html() || this.story_content,
                    comments: $('textarea[name=newsblur_comment]', this.$modal).val(),
                    feed_id: this.feed.id,
                    story_url: window.location.href,
                    rss_url: this.get_page_rss_url()
                },
                success: __NB_.bind(this.post_share_story, this),
                error: __NB_.bind(this.error_share_story, this)
            });
        },
        
        post_share_story: function(data) {
            var $share = $(".NB-bookmarklet-comment-submit", this.$modal);
            this.flags.in_transit = false;
            
            if (data.code < 0) {
                return this.error_share_story(data);
            }
            
            $share.addClass('NB-disabled');
            $share.html($.make('div', { className: 'NB-bookmarklet-accept' }, [
                $.make('img', { src: 'data:image/png;charset=utf-8;base64,' + this.images['accept_image'] }),
                'Shared'
            ]));
            setTimeout(function() {
                // $.modal.close();
            }, 2000);

        },
        
        error_share_story: function(data) {
            var $share = $(".NB-bookmarklet-comment-submit", this.$modal);
            var $error = $(".NB-bookmarklet-comment-error", this.$modal);
            this.flags.in_transit = false;
            
            $share.removeClass('NB-disabled');
            $error.show();
            console.log(["error sharing", data]);
            
            this.update_share_button_title();

            $error.text(data.message || "Sorry, but there was an error trying to share this story.")
        },
        
        open_add_folder: function() {
            var $new_folder = $('.NB-bookmarklet-new-folder-container', this.$modal);
            $new_folder.slideDown(500);
            this.flags['new_folder'] = true;
        },
        
        close_add_folder: function() {
            var $new_folder = $('.NB-bookmarklet-new-folder-container', this.$modal);
            $new_folder.slideUp(500);
            this.flags['new_folder'] = false;
        },
        
        // =========================
        // = Page-specific actions =
        // =========================
        
        get_page_content: function() {
            var selected = this.get_selected_html();
            var $title = $('.NB-bookmarklet-page-title', this.$modal);
            var $content = $('.NB-bookmarklet-page-content', this.$modal);

            if (selected) {
                this.story_title = document.title;
                this.story_content = selected;
                console.log(["content selected", this.story_title, this.story_content]);
            } else {
                var documentClone = document.cloneNode(true);
                var article = new window.NB_Readability(documentClone).parse();
                
                this.story_title = article.title;
                this.story_content = article.content;
            }
            
            this.find_video_embeds();

            $title.html(this.story_title);
            $content.html(this.story_content);
        },
        
        find_video_embeds: function() {
            var video_id, video_html;
            
            if (window.location.href.indexOf('youtube.com') != -1) {
                video_id = jQuery.url.param('v');
                video_html = '<iframe title="YouTube video player" class="youtube-player" type="text/html" width="640" height="390" src="http://www.youtube.com/embed/' + video_id + '" frameborder="0" allowFullScreen></iframe>';
            } else if (window.location.href.indexOf('vimeo.com') != -1) {
                video_id = jQuery.url.segment(0);
                video_html = '<iframe src="http://player.vimeo.com/video/'+ video_id +'" width="640" height="390" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe>';
                console.log(["vimeo", video_id, jQuery.url]);
            }

            if (video_id && video_id.length) {
                this.story_content = video_html + this.story_content;
            }
        },
        
        get_selected_html: function() {
            var html = "";
            if (typeof window.getSelection != "undefined") {
                var sel = window.getSelection();
                if (sel.rangeCount) {
                    var container = document.createElement("div");
                    for (var i = 0, len = sel.rangeCount; i < len; ++i) {
                        container.appendChild(sel.getRangeAt(i).cloneContents());
                    }
                    html = container.innerHTML;
                }
            } else if (typeof document.selection != "undefined") {
                if (document.selection.type == "Text") {
                    html = document.selection.createRange().htmlText;
                }
            }
            return html;
        },
        
        attach_css: function() {
            var css = "{% include_stylesheets_raw "bookmarklet" %}";
            var style = '<style id="newsblur_bookmarklet_css">' + css + '</style>';
            if ($('#newsblur_bookmarklet_css').length) {
                $('#newsblur_bookmarklet_css').replaceWith(style);
            } else if ($('head').length) {
                $('head').append(style);
            } else {
                $('body').append(style);
            }
        },
        
        alert: function(message) {
          alert(message);
        },
    
        check_if_on_newsblur: function() {
          if (window.location.href.indexOf(this.domain) != -1) {
            return true;
          }
        },
        
        get_page_title: function() {
            var title = document.title;
            
            if (title.length > 40) {
                title = title.substr(0, 40) + '...';
            }
            
            return title;
        },
        
        get_page_rss_url: function() {
            return $('link[type="application/rss+xml"]').attr('href');
        },
        
        // ===========
        // = Actions =
        // ===========

        handle_clicks: function(elem, e) {
            var self = this;
                    
            $.targetIs(e, { tagSelector: '.NB-bookmarklet-button-subscribe' }, function($t, $p) {
                e.preventDefault();
                
                if (!$t.hasClass('NB-disabled')) {
                    self.subscribe();
                }
            });
        
            $.targetIs(e, { tagSelector: '.NB-bookmarklet-folder-add-button' }, function($t, $p) {
                e.preventDefault();
                
                if ($t.hasClass('NB-active')) {
                    self.close_add_folder();
                } else {
                    self.open_add_folder();
                }
                $t.toggleClass('NB-active');
            });

            $.targetIs(e, { tagSelector: '.NB-bookmarklet-comment-submit' }, function($t, $p) {
                e.preventDefault();
                
                if (!$t.hasClass('NB-disabled')) {
                    self.share_story();
                }
            });

            $.targetIs(e, { tagSelector: '.NB-bookmarklet-save-button' }, function($t, $p) {
                e.preventDefault();
                
                if (!$t.hasClass('NB-disabled')) {
                    self.save_story();
                }
            });

            $.targetIs(e, { tagSelector: '.NB-close' }, function($t, $p) {
                e.preventDefault();
                
                $.modal.close();
            });
        },
        
        update_share_button_title: function() {
            if (this.flags.in_transit) return;
            
            var $comment = $('textarea[name=newsblur_comment]', this.$modal);
            var $submit = $('.NB-bookmarklet-comment-submit', this.$modal);
            var $error = $(".NB-bookmarklet-comment-error", this.$modal);
            var $save = $('.NB-bookmarklet-save-button', this.$modal);
            
            $error.html('');
            $submit.removeClass('NB-disabled');
            if ($comment.val().length) {
                $submit.text('Share with comments');
            } else {
                $submit.text('Share this story');
            }
            $save.text("Save this story");
        }
    
    };

    if (NEWSBLUR.bookmarklet && NEWSBLUR.bookmarklet.active) {
        NEWSBLUR.bookmarklet.fix_title();
        return;
    }
    NEWSBLUR.bookmarklet = new NEWSBLUR.Bookmarklet();
  
})();
