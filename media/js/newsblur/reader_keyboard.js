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
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Next story'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '&#x2193;'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'j'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-image' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/keyboard_down.png', width: 268, height: 65 })
                ])
              ]),
              $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Previous story'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '&#x2191;'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'k'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-image' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/keyboard_up.png', width: 268, height: 65 })
                ])
              ])
            ]),
            $.make('div', { className: 'NB-keyboard-group' }, [
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Next site'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'shift',
                    $.make('span', '+'),
                    '&#x2193;'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'shift',
                    $.make('span', '+'),
                    'j'
                ])
              ]),
              $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Prev. site'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'shift',
                    $.make('span', '+'),
                    '&#x2191;'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'shift',
                    $.make('span', '+'),
                    'k'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-keyboard-group' }, [              
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Switch views'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '&#x2190;'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '&#x2192;'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-image' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/keyboard_leftright.png', width: 268, height: 29 })
                ])
              ]),        
              $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open Site'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'enter'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-image' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/keyboard_enter.png', width: 268, height: 29 })
                ])
              ])
            ]),
            $.make('div', { className: 'NB-keyboard-group' }, [
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Page down'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'space'
                ])
              ]),
              $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Page up'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'shift',
                    $.make('span', '+'),
                    'space'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-keyboard-group' }, [
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Next Unread Story'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'n'
                ])
              ]),
              $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Hide Sidebar'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'u'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-keyboard-group' }, [
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Save/Unsave Story'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    's'
                ])
              ]),
              $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Change Intelligence'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '+'
                ]),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    '-'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-keyboard-group' }, [
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open site/feed trainer'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'f'
                ])
              ]),
              $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open story trainer'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    't'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-keyboard-group' }, [
              $.make('div', { className: 'NB-keyboard-shortcut' }, [
                $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open story in new window'),
                $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                    'o'
                ])
              ])
            ])
        ]);
    },
    
    open_modal: function() {
        var self = this;
        
        this.$modal.modal({
            'minWidth': 620,
            'maxWidth': 620,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                    $(window).resize();
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