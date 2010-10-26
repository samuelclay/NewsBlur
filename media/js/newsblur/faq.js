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
            $.make('h2', { className: 'NB-modal-title' }, 'Frequently Asked Questions'),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    'The Reader'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-what' }, [
                      $.make('li', [
                        $.make('div', { className: 'NB-faq-question' }, 'What is the different between the three views: Original, Feed, and Story?'),
                        $.make('div', { className: 'NB-faq-answer' }, 'Original view is the original site. Feed view is the RSS feed from the site. And Story view is the same as Feed view, but only shows one story at a time. It\'s all personal preference, really.')
                      ]),
                      $.make('li', [
                        $.make('div', { className: 'NB-faq-question' }, 'Am I actually at the original site? Can NewsBlur see what I see?'),
                        $.make('div', { className: 'NB-faq-answer' }, 'In order to show you the original site, NewsBlur takes a snapshot of the page. You may have noticed that if you are logged into the original site, you are not logged into NewsBlur\'s snapshot of the page. This is because NewsBlur fetched the site for you.')
                      ]),
                      $.make('li', { className: 'last' }, [
                        $.make('div', { className: 'NB-faq-question' }, 'Why doesn\'t NewsBlur follow me when I click on links on the page?'),
                        $.make('div', { className: 'NB-faq-answer' }, 'When you click on a link, you are technically leaving NewsBlur, although only for a portion of the page. In order to track what you\'re reading, you need to read NewsBlur\'s snapshot of the page, or switch to the Feed view.'),
                        $.make('div', { className: 'NB-faq-answer last' }, 'This may change one day. There is a way to fix this behavior so it works like you would expect. It is not easy to do, however. One day.')
                      ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    'The Intelligence'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-server' }, [
                      $.make('li', [
                        $.make('div', { className: 'NB-faq-question' }, [
                            'What does the three-color slider do?'
                        ]),
                        $.make('div', { className: 'NB-faq-answer' }, [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/intelligence_slider_positive.png', className: 'NB-faq-image', width: 114, height: 29 }),
                            'This is called the intelligence slider. Slide it to the right to only show stories you like.'
                        ]),
                        $.make('div', { className: 'NB-faq-answer last' }, [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/intelligence_slider_negative.png', className: 'NB-faq-image', width: 114, height: 29 }),
                            'Slide it to the left to show stories you dislike. Stories all start off neutral, in the center of the slider.'
                        ]),
                        $.make('div', { className: 'NB-faq-answer' }, [
                            $.make('br'),
                            $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_red.png'}),
                            ' are stories you don\'t like',
                            $.make('br'),
                            $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_yellow.png'}),
                            ' are stories you have not yet rated',
                            $.make('br'),
                            $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_green.png'}),
                            ' are stories you like'
                        ])
                      ]),
                      $.make('li', { className: 'last' }, [
                        $.make('div', { className: 'NB-faq-question' }, 'How does NewsBlur know whether I like or dislike a story?'),
                        $.make('div', { className: 'NB-faq-answer' }, 'When you like or dislike a story, you mark a facet of that story by checking a tag, author, part of the title, or entire publisher. When these facets are found in future stories, the stories are then weighted with your preferences. It is a very simple, explicit process where you tell NewsBlur what you like and don\'t like.'),
                        $.make('div', { className: 'NB-faq-answer' }, 'The idea is that by explicitly telling NewsBlur what your story preferences are, there is increased likelihood that you will like what the intelligence slider does for you.'),
                        $.make('div', { className: 'NB-faq-answer last'}, 'Currently, there is not an automated way of detecting stories you like or dislike without having to train NewsBlur. This implicit, automatic intelligence will come in the near-term future, but it will require an evolution to the interface that has not been easy to figure out how to make in a simple, clear, and effective manner. Soon.')
                      ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    $.make('span', { className: 'NB-exception-option-option', style: 'float:right' }, 'September - October 2010'),
                    'What\'s Coming'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-who' }, [
                      $.make('li', [
                        $.make('div', { className: 'NB-faq-answer' }, 'An iPhone app.')
                      ]),
                      $.make('li', [
                        $.make('div', { className: 'NB-faq-answer' }, 'Indication of story titles that are below the intelligence slider threshold.')
                      ]),
                      $.make('li', [
                        $.make('div', { className: 'NB-faq-answer' }, 'Sort sites alphabetically, by popularity, use, unread counts, and hiding sites with no unreads.')
                      ]),
                      $.make('li', { className: 'last' }, [
                        $.make('div', { className: 'NB-faq-answer' }, 'Account management, password recovery.')
                      ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    'Something\'s Wrong'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'NB-about-client' }, [
                      $.make('li', [
                        $.make('div', { className: 'NB-faq-question' }, 'Help! All of the stories are several days old and new stories are not showing up.'),
                        $.make('div', { className: 'NB-faq-answer' }, 'Sites that only have a single subscriber tend to get updated much less often than popular sites. Additionally, the frequency that a site publishes stories (once per month or several per day) has an impact on how often the site is refreshed.')
                      ]),
                      $.make('li', { className: 'last' }, [
                        $.make('div', { className: 'NB-faq-question' }, 'Help! I have an issue and it\'s not mentioned here.'),
                        $.make('div', { className: 'NB-faq-answer last' }, [
                            'Please, please, please e-mail ',
                            $.make('a', { href: 'mailto:samuel@ofbrooklyn.com' }, 'samuel@ofbrooklyn.com'),
                            '. If you have an issue it is entirely possible that other people do, too.'
                        ])
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
            'onClose': function(dialog, callback) {
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(200, function() {
                    dialog.overlay.empty().remove();
                    $.modal.close(callback);
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
            
            $.modal.close(function() {
              NEWSBLUR.about = new NEWSBLUR.About();
            });
        });
    }
    
};