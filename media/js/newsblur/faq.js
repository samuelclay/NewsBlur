NEWSBLUR.Faq = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.runner();
};

NEWSBLUR.Faq.prototype = {
    
    runner: function() {
        $.modal.close();
        this.make_modal();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-about NB-modal-exception NB-modal' }, [
            $.make('a', { href: '#faq', className: 'NB-link-about-faq' }, 'About NewsBlur'),
            $.make('h2', { className: 'NB-modal-title' }, 'Frequently [enough] Asked Question'),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option' }, 'What:'),
                    'A Feed Reader with Intelligence'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-what' }, [
                      $.make('li', 'Read the original site or the RSS feed.'),
                      $.make('li', 'Automatically highlight stories you want to read.'),
                      $.make('li', { className: 'last' }, 'Filter out stories you don\'t want to read.')
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option' }, 'How:'),
                    'Server-side technologies'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-server' }, [
                      $.make('li', [
                        $.make('a', { href: 'http://www.djangoproject.com' }, 'Django'),
                        ': Web framework written in Python, used to serve all pages.'
                      ]),
                      $.make('li', [
                        $.make('a', { href: 'http://ask.github.com/celery' }, 'Celery'),
                        ' &amp; ',
                        $.make('a', { href: 'http://www.rabbitmq.com' }, 'RabbitMQ'),
                        ': Asynchronous queueing server, used to fetch and parse RSS feeds.'
                      ]),
                      $.make('li', [
                        $.make('a', { href: 'http://www.mongodb.com' }, 'MongoDB'),
                        ', ',
                        $.make('a', { href: 'http://www.mongodb.com/pymongo' }, 'Pymongo'),
                        ', &amp; ',
                        $.make('a', { href: 'http://www.github.com/hmarr/mongoengine' }, 'Mongoengine'),
                        ': Non-relational database, used to store stories, read stories, feed/page fetch histories, and proxied sites.'
                      ]),
                      $.make('li', { className: 'last' }, [
                        $.make('a', { href: 'http://www.postgresql.com' }, 'PostgreSQL'),
                        ': Relational database, used to store feeds, subscriptions, and user accounts.'
                      ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option' }, 'How:'),
                    'Client-side and design'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-client' }, [
                      $.make('li', [
                        $.make('a', { href: 'http://www.jquery.com' }, 'jQuery'),
                        ': Cross-browser compliant JavaScript code. IE works without effort.'
                      ]),
                      $.make('li', [
                        $.make('a', { href: 'http://documentcloud.github.com/underscore/' }, 'Underscore.js'),
                        ': Functional programming for JavaScript. Indispensible.'
                      ]),
                      $.make('li', [
                        $.make('b', 'Miscellaneous jQuery Plugins:'),
                        ' Everything from resizable layouts, to progress bars, sortables, date handling, colors, corners, JSON, animations. See the complete list on ',
                        $.make('a', { href: 'http://github.com/samuelclay/NewsBlur/' }, 'NewsBlur\'s GitHub repository')
                      ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option' }, 'Who:'),
                    'A Feed Reader with Intelligence'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-who' }, [
                      $.make('li', [
                        'Hand-crafted by: ',
                        $.make('a', { href: 'http://www.samuelclay.com' }, 'Samuel Clay')
                      ]),
                      $.make('li', [
                        'Find him on Twitter: ',
                        $.make('a', { href: 'http://twitter.com/samuelclay' }, '@samuelclay')
                      ]),
                      $.make('li', [
                        'E-mail him at: ',
                        $.make('a', { href: 'mailto:samuel@ofbrooklyn.com' }, 'samuel@ofbrooklyn.com')
                      ]),
                      $.make('li', { className: 'last' }, [
                        'Made in: ',
                        $.make('a', { href: 'http://www.newyorkfieldguide.com' }, 'New York City')
                      ])
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
        
        $.targetIs(e, { tagSelector: '.NB-link-about-faq' }, function($t, $p) {
            e.preventDefault();
            
            NEWSBLUR.about = new NEWSBLUR.About();
        });
    }
    
};