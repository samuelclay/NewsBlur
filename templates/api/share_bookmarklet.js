{% load bookmarklet_includes utils_tags %}

(function() {
    window.NEWSBLUR = window.NEWSBLUR || {};
    
    {% include_bookmarklet_js %}

    NEWSBLUR.Bookmarklet = function(options) {
        var defaults = {};
        
        this.token    = "{{ token }}";
        this.active   = true;
        this.username = '{{ user.username }}';
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
        
            this.$modal.bind('click', $.rescope(this.handle_clicks, this));
        },
        
        show_error: function() {
            $('.NB-bookmarklet-folder-container', this.$modal).hide();
            $('.NB-modal-submit', this.$modal).html($.make('div', { className: 'NB-error-invalid' }, [
                'This bookmarklet no longer matches an account. Re-create it in ',
                $.make('a', { href: 'http://www.newsblur.com/?next=goodies' }, 'Goodies on NewsBlur'),
                '.'
            ]));
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
                        $.make('div', { className: 'NB-bookmarklet-page-content' })
                    ])
                ]),
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
            ]);
        },
        
        get_page_title: function() {
            var title = document.title;
            
            if (title.length > 40) {
                title = title.substr(0, 40) + '...';
            }
            
            return title;
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
            var $title = $('.NB-modal-title', this.$modal);
            var $content = $('.NB-bookmarklet-page-content', this.$modal);
            var $readability = $(window.readability.init());
            
            var title = $readability.children("h1").text();
            $title.html(title);
            
            var content = $("#readability-content", $readability).html();
            $content.html(content);
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
        }
    
    };

    if (NEWSBLUR.bookmarklet && NEWSBLUR.bookmarklet.active) {
        NEWSBLUR.bookmarklet.fix_title();
        return;
    }
    NEWSBLUR.bookmarklet = new NEWSBLUR.Bookmarklet();
  
})();