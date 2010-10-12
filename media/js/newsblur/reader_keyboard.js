NEWSBLUR.ReaderKeyboard = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.runner();
};

NEWSBLUR.ReaderKeyboard.prototype = {
    
    runner: function() {
        this.make_modal();
        this.handle_cancel();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-keyboard NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Keyboard shortcuts'),
            $.make('div', { className: 'NB-keyboard-group' }, [
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Next/Preview story'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'u',
                    $.make('span', 'or'),
                    'j'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'd',
                    $.make('span', 'or'),
                    'k'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-image' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/keyboard_updown.png' })
                ])
              ]),
              
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Switch views'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '&lt;'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '>'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-image' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/keyboard_leftright.png' })
                ])
              ])
            ])
        ]);
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
                });
                $('.NB-modal-holder').empty().remove();
            }
        });
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
            
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-add-url-submit' }, function($t, $p) {
            e.preventDefault();
            
            self.save_add_url();
        });
    }
    
};