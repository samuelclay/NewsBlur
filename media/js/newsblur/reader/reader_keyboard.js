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
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-general' }, '一般'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-feeds' }, '站点'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-stories' }, '文章')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                '键盘快捷键',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            
            // General
            
            $.make('div', { className: 'NB-tab NB-tab-general NB-active' }, [
                $.make('div', { className: 'NB-keyboard-group' }, [              
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '切换视图'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '&#x2190;'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '&#x2192;'
                    ])
                  ]),        
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '快速检索站点'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'g'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '回到控制面板'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'esc'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'd'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '打开所有文章页面'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'e'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '隐藏站点列表'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'u'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '全屏'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'f'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '在“专注”和“未读”之间切换'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '+'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '-'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '查看键盘快捷键'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '?'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '添加站点或文件夹'),
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
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '下一个站点'),
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
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '上一个站点'),
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
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '打开站点训练页面'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        't'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '打开站点训练页面'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        't'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '标记所有为已读'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'a'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '最旧的未读文章'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'm'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '重新载入站点或文件夹'),
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
                ])
            ]),
            
            // Stories
            
            $.make('div', { className: 'NB-tab NB-tab-stories' }, [
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '下一篇文章'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        '&#x2193;'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'j'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '上一篇文章'),
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
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '以原文视图打开'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'enter'
                    ])
                  ]),        
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '以全文视图打开'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'enter'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '向下翻页'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'space'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '向上翻页'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'space'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '下一篇未读文章'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'n'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '切换“已读”/“未读”'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'u'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Mark older stories read'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'b'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Mark newer stories read'),
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
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '通过邮件发送文章'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'e'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '在后台标签页打开'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'o'
                    ]),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'v'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '在新窗口打开'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        'v'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '展开文章'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span','+'),
                        'x'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '收起文章'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'x'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '分享此文章'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'shift',
                        $.make('span', '+'),
                        's'
                    ])
                  ]),
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '保存评论'),
                    $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                        'ctrl',
                        $.make('span', '+'),
                        'enter'
                    ])
                  ])
                ]),
                $.make('div', { className: 'NB-keyboard-group' }, [
                  $.make('div', { className: 'NB-keyboard-shortcut' }, [
                    $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, '滚动至评论'),
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
