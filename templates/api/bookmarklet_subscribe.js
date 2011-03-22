{% load bookmarklet_includes utils_tags %}

(function() {
    
    {% include_bookmarklet_js %}

    NEWSBLUR.BookmarkletModal = function(options) {
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
    };

    NEWSBLUR.BookmarkletModal.prototype = {
        
        fix_title: function() {
            var d = document;
            d.title = d.title.replace(/\(Adding\.\.\.\)\s?/g, '');
        },
        
        close: function() {
            this.active = false;
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
        },
        
        attach_css: function() {
            var css = "{% include_bookmarklet_css %}";
            var style = '<style>' + css + '</style>';
            if ($('head').length) $('head').append(style);
            else $('body').append(style);
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
                $.make('div', { className: 'NB-modal-title' }, 'Adding \"'+this.get_page_title()+'\"'),
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
            
            if (title.length > 20) {
                title = title.substr(0, 20) + '...';
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
            for (var i in items) {
                var item = items[i];
                if (typeof item == "object") {
                    for (var o in item) {
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
                'minWidth': 600,
                'maxWidth': 600,
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

    if (NEWSBLUR.bookmarklet_modal && NEWSBLUR.bookmarklet_modal.active) {
        NEWSBLUR.bookmarklet_modal.fix_title();
        return;
    }
    NEWSBLUR.bookmarklet_modal = new NEWSBLUR.BookmarkletModal();
  
})();