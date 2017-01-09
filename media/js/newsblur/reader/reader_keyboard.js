NEWSBLUR.ReaderKeyboard = function(options) {
    var defaults = {
        width: 700
    };
    
    this.options = $.extend({}, defaults, options);
    this.runner();
};

NEWSBLUR.ReaderKeyboard.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderKeyboard.prototype.constructor = NEWSBLUR.ReaderKeyboard;

_.extend(NEWSBLUR.ReaderKeyboard.prototype, {
    
    runner: function() {
        this.make_modal();
        this.handle_cancel();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-keyboard NB-modal' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-general' }, 'General'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-feeds' }, 'Feeds'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-stories' }, 'Stories')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Keyboard shortcuts',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            
            // General
            
            $.make('div', { className: 'NB-tab NB-tab-general NB-active' }, [
                $.make('div', { className: 'NB-keyboard-group' }, [              
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Switch views'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '&#x2190;'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '&#x2192;'
                    ])
                  ]),        
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Quick search for a site'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'g'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Dashboard'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'esc'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'd'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open Everything'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'e'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Hide sites'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'u'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Full screen'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'f'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Switch focus/unread'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '+'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '-'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'View keyboard shortcuts'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '?'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Add site/folder'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'a'
                    ])
                  ])
                ])
            ]),

            // Feeds

            $.make('div', { className: 'NB-tab NB-tab-feeds' }, [
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
                    // TODO: Mention "shift + n" here? It will be too wide.
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
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
                    // TODO: Mention "shift + p" here? It will be too wide.
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open site/feed trainer'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        't'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open story trainer'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        't'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Mark all as read'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'a'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Oldest unread story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'm'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Reload feed/folder'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'r'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Search feed'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '/'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Toggle unread/all'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'L'
                    ])
                  ])
                ])
            ]),
            
            // Stories
            
            $.make('div', { className: 'NB-tab NB-tab-stories' }, [
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Next story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '&#x2193;'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'j'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Previous story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '&#x2191;'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'k'
                    ])
                  ])
                ]),

                $.make('div', { className: 'NB-keyboard-group' }, [              
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open in Story view'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'enter'
                    ])
                  ]),        
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open in Text view'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'enter'
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
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
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
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Toggle read/unread'),
                      $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                          'u'
                      ]),
                      $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                          'm'
                      ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Mark below stories read'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'b'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Mark above stories read'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'y'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Save/Unsave story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        's'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Email story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'e'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open in background tab'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'o'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'v'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open in new window'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'v'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Expand story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span','+'),
                        'x'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Collapse story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'x'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Share this story'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        's'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Save comments'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'ctrl',
                        $.make('span', '+'),
                        'enter'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Scroll to comments'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'c'
                    ])
                  ])
                ])
            ])
        ]);
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
        
        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function($t, $p) {
            e.preventDefault();
            var newtab;
            if ($t.hasClass('NB-modal-tab-general')) {
                newtab = 'general';
            } else if ($t.hasClass('NB-modal-tab-feeds')) {
                newtab = 'feeds';
            } else if ($t.hasClass('NB-modal-tab-stories')) {
                newtab = 'stories';
            }
            self.switch_tab(newtab);
        });        
    }
    
});
