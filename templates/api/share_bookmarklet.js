{% load bookmarklet_includes utils_tags %}

(function() {
    window.NEWSBLUR = window.NEWSBLUR || {};
    
    {% include_bookmarklet_js %}

    NEWSBLUR.Bookmarklet = function(options) {
        var defaults = {};
        
        this.token    = "{{ token }}";
        this.active   = true;
        this.username = '{{ user.username }}';
        this.profile  = {{ user_profile|safe }};
        this.folders  = {{ folders|safe }};
        this.domain   = "{% current_domain %}";
        this.flags    = {
            'new_folder': false
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
            this.get_page_content();
            this.pre_share_check_story();
        
            this.$modal.bind('click', $.rescope(this.handle_clicks, this));

            var $comment = $('textarea[name=newsblur_comment]', this.$modal);
            $comment.bind('keydown', $.rescope(this.update_share_button_title, this));
            $comment.bind('keyup', $.rescope(this.update_share_button_title, this));
            $comment.bind('keydown', 'ctrl+return', $.rescope(this.share_story, this));
            $comment.bind('keydown', 'meta+return', $.rescope(this.share_story, this));
        },
            
        make_modal: function() {
            var self = this;

            this.$modal = $.make('div', { className: 'NB-bookmarklet NB-modal' }, [
                $.make('div', { className: 'NB-modal-information' }, [
                    'Signed in as ',
                    $.make('b', { style: 'color: #505050' }, this.username)
                ]),
                $.make('div', { className: 'NB-modal-title' }, 'Sharing \"'+this.get_page_title()+'\"'),
                $.make('div', { className: 'NB-bookmarklet-main'}, [
                    $.make('div', { className: 'NB-bookmarklet-page' }, [
                        $.make('div', { className: 'NB-bookmarklet-page-title' }),
                        $.make('div', { className: 'NB-bookmarklet-page-content' }),
                        $.make('div', { className: 'NB-bookmarklet-page-comment' }, [
                            $.make('div', { className: 'NB-bookmarklet-comment-photo' }, [
                                $.make('img', { src: this.profile.photo_url })
                            ]),
                            $.make('div', { className: 'NB-bookmarklet-comment-input' }, [
                                $.make('textarea', { name: 'newsblur_comment', placeholder: "Comments..." })
                            ]),
                            $.make('div', { className: 'NB-bookmarklet-comment-submit NB-modal-submit-button NB-modal-submit-green' }, 'Share this story')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-bookmarklet-side' }, [
                    $.make('div', { className: 'NB-bookmarklet-folder-container' }, [
                        $.make('img', { className: 'NB-bookmarklet-folder-add-button', src: 'data:image/png;charset=utf-8;base64,{{ add_image }}', title: 'Add New Folder' }),
                        this.make_folders(),
                        $.make('div', { className: 'NB-bookmarklet-new-folder-container' }, [
                            $.make('img', { className: 'NB-bookmarklet-folder-new-label', src: 'data:image/png;charset=utf-8;base64,{{ new_folder_image }}' }),
                            $.make('input', { type: 'text', name: 'new_folder_name', className: 'NB-bookmarklet-folder-new' })
                        ])
                    ]),
                    $.make('div', { className: 'NB-modal-submit' }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green' }, 'Add this site')
                    ])
                ])
            ]);
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
                'minWidth': 800,
                'maxWidth': 800,
                'overlayClose': true,
                'onOpen': function (dialog) {
                    dialog.overlay.fadeIn(200, function () {
                        dialog.container.fadeIn(200);
                        dialog.data.fadeIn(200);
                        setTimeout(function() {
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

        save: function() {
            var self = this;
            var $submit = $('.NB-modal-submit-button');
            var folder = $('.NB-folders').val();
            var add_site_url = "http://"+this.domain+"{% url api-add-site token %}?callback=?";
            
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
                self.post_save(resp);
            });
        },
        
        post_save: function(resp) {
            var $submit = $('.NB-modal-submit-button');
            
            $submit.addClass('NB-close');
            
            if (resp.code == 1) {
                $submit.html($.make('div', { className: 'NB-bookmarklet-accept' }, [
                    $.make('img', { src: 'data:image/png;charset=utf-8;base64,{{ accept_image }}' }),
                    'Added!'
                ]));
                setTimeout(function() {
                    $.modal.close();
                }, 2000);
            } else {
                var $error = $.make('div', { className: 'NB-bookmarklet-error' }, [
                    $.make('img', { className: 'NB-bookmarklet-folder-label', src: 'data:image/png;charset=utf-8;base64,{{ error_image }}' }),
                    $.make('div', resp.message)
                ]);
                $('.NB-bookmarklet-folder-container').hide();
                $submit.replaceWith($error);
            }
        },
        
        // =============
        // = Pre-share =
        // =============
        
        pre_share_check_story: function() {
            var check_story_url = "http://"+this.domain+"{% url api-check-share-on-site token %}?callback=?";
            var data = {
                story_url: window.location.href,
                rss_url: $('link[type="application/rss+xml"]').attr('href')
            };
            
            $.getJSON(check_story_url, data, function(resp) {
                
            });
        },
        
        // ===============
        // = Share story =
        // ===============
        
        share_story: function() {
            $.ajax({
                url: 'http://'+this.domain+"{% url api-share-story token %}?callback=?",
                
            })
        },
        
        post_share_story: function(data) {
            
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
                var title = document.title;
                var content = selected;
                console.log(["content selected", title, content]);
            } else {
                var $readability = $(window.readability.init());
            
                var title = $readability.children("h1").text();
                var content = $("#readability-content", $readability).html();
            }

            $title.html(title);
            $content.html(content);
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
            var css = "{% include_bookmarklet_css %}";
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
        
        // ===========
        // = Actions =
        // ===========

        handle_clicks: function(elem, e) {
            var self = this;
                    
            $.targetIs(e, { tagSelector: '.NB-modal-submit-button' }, function($t, $p) {
                e.preventDefault();
                
                if (!$t.hasClass('NB-disabled')) {
                    self.save();
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

            $.targetIs(e, { tagSelector: '.NB-close' }, function($t, $p) {
                e.preventDefault();
                
                $.modal.close();
            });
        },
        
        update_share_button_title: function() {
            var $comment = $('textarea[name=newsblur_comment]', this.$modal);
            var $submit = $('.NB-bookmarklet-comment-submit', this.$modal);

            if ($comment.val().length) {
                $submit.text('Share with comments');
            } else {
                $submit.text('Share this story');
            }
        }
    
    };

    if (NEWSBLUR.bookmarklet && NEWSBLUR.bookmarklet.active) {
        NEWSBLUR.bookmarklet.fix_title();
        return;
    }
    NEWSBLUR.bookmarklet = new NEWSBLUR.Bookmarklet();
  
})();