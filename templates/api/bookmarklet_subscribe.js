{% load bookmarklet_includes %}
(function() {
  
    {% include_bookmarklet_js %}
    
    NEWSBLUR.BookmarkletModal = function(options) {
        var defaults = {};

        this.active = true;
        this.username = '{{ user.username }}';
        this.folders = {{ folders|safe }};
        
        this.options = $.extend({}, defaults, options);
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
                var message = "Drag this button to your bookmark toolbar.";
                this.alert(message);
                return this.close();
            }
            
            this.attach_css();
            this.make_modal();
            this.open_modal();
        
            this.$modal.bind('click', $.rescope(this.handle_click, this));
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
          if (window.location.href.indexOf('newsblur.com/') != -1 ||
              window.location.href.indexOf('nb.local.host:8000/') != -1) {
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
                    $.make('img', { className: 'NB-bookmarklet-folder-label', src: 'data:image/png;charset=utf-8;base64,{{ folder_image }}' }),
                    this.make_folders(),
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
            
            $('option', $options).tsort();
        
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
    
        // ===========
        // = Actions =
        // ===========

        handle_click: function(elem, e) {
            var self = this;
        
            $.targetIs(e, { tagSelector: '.NB-add-url-submit' }, function($t, $p) {
                e.preventDefault();
            
                self.save_preferences();
            });
        }
    
    };

    if (NEWSBLUR.bookmarklet_modal && NEWSBLUR.bookmarklet_modal.active) {
        NEWSBLUR.bookmarklet_modal.fix_title();
        return;
    }
    NEWSBLUR.bookmarklet_modal = new NEWSBLUR.BookmarkletModal();
  
})();