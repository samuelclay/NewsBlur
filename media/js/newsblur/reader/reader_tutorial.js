NEWSBLUR.ReaderTutorial = function(options) {
    var defaults = {};
    
    _.bindAll(this, 'close');
    
    this.options = $.extend({
      'page_number': 1
    }, defaults, options);
    this.model   = NEWSBLUR.assets;

    this.page_number = this.options.page_number;
    this.slider_value = 0;
    this.intervals = {};
    this.runner();
};

NEWSBLUR.ReaderTutorial.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderTutorial.prototype.constructor = NEWSBLUR.ReaderTutorial;

_.extend(NEWSBLUR.ReaderTutorial.prototype, {
    
    TITLES: [
      'Learn to use NewsBlur',
      'Three Site Views',
      'Training the Intelligence',
      'Tips and Tricks',
      'Feedback and Open Source'
    ],
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        this.page(1);
        this.load_newsblur_blog_info();
        this.load_intelligence_slider();
        this.load_tips();
        this.make_story_titles();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    load_newsblur_blog_info: function() {
      this.model.load_tutorial({}, _.bind(function(data) {
        this.newsblur_feed = data.newsblur_feed;
        $('.NB-javascript', this.$modal).removeClass('NB-javascript');
      }, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-tutorial NB-modal' }, [
            $.make('span', { className: 'NB-modal-loading NB-spinner'}),
            $.make('div', { className: 'NB-modal-page' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                $.make('span', 'Tips &amp; Tricks'),
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('div', { className: 'NB-page NB-page-1' }, [
              $.make('h4', 'NewsBlur is a visual feed reader with intelligence.'),
              $.make('div', 'You\'ll figure out much of NewsBlur by playing around and trying things out. This tutorial is here to quickly offer a foundation.'),
              $.make('h4', 'This tutorial covers:'),
              $.make('ul', [
                $.make('li', [
                  $.make('div', { className: 'NB-right' }, 'Page 2'),
                  'Using the three views (Original, Feed, and Story)'
                ]),
                $.make('li', [
                  $.make('div', { className: 'NB-right' }, 'Page 3'),
                  'Training and filtering stories'
                ]),
                $.make('li', [
                  $.make('div', { className: 'NB-right' }, 'Page 4'),
                  'Tips and tricks that may not be obvious'
                ]),
                $.make('li', [
                  $.make('div', { className: 'NB-right' }, 'Page 5'),
                  'Feedback, open source, the blog, and twitter'
                ])
              ]),
              $.make('h4', 'Why you should use NewsBlur:'),
              $.make('ul', [
                $.make('li', [
                  'This is a free service that is always getting better.'
                ]),
                $.make('li', [
                  'See the original site and read stories as the author intended.'
                ]),
                $.make('li', [
                  'Spend less time as NewsBlur filters the stories for you.'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-page NB-page-2' }, [
              $.make('h4', 'Read your sites with three different views:'),
              $.make('div', { className: 'NB-tutorial-view' }, [
                $.make('div', { className: 'NB-tutorial-view-title' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/application_view_tile.png' }),
                  'Original'
                ]),
                $.make('img', { className: 'NB-tutorial-view-image', src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_view_original.png' }),
                $.make('span', 'The site itself.')
              ]),
              $.make('div', { className: 'NB-tutorial-view' }, [
                $.make('div', { className: 'NB-tutorial-view-title' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/application_view_list.png' }),
                  'Feed'
                ]),
                $.make('img', { className: 'NB-tutorial-view-image', src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_view_feed.png' }),
                $.make('span', 'All feed stories.')
              ]),
              $.make('div', { className: 'NB-tutorial-view' }, [
                $.make('div', { className: 'NB-tutorial-view-title' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/application_view_gallery.png' }),
                  'Story'
                ]),
                $.make('img', { className: 'NB-tutorial-view-image', src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_view_story.png' }),
                $.make('span', 'Story click-through.')
              ]),
              $.make('ul', [
                $.make('li', [
                  'The view you choose is saved per-site, so you can mix-and-match.'
                ]),
                $.make('li', [
                  'Double-click story titles to temporarily open a story in the Story view.'
                ]),
                $.make('li', [
                  'In the Original view, if a story is not found, it will temporarily open in the Feed view.'
                ]),
                $.make('li', [
                  'Much about these views can be customized under Preferences.'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-page NB-page-3' }, [
              $.make('h4', 'NewsBlur works best when you use intelligence classifiers.'),
              $.make('ul', [
                $.make('li', { className: 'NB-tutorial-train-1' }, [
                  $.make('b', 'First: Train stories and sites.'),
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_train_feed.png' }),
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_train_story.png' })
                ]),
                $.make('li', [
                  $.make('b', 'Second: The intelligence slider filters stories based on training.'),
                  $.make('div', { className: 'NB-tutorial-stories', id: 'story_titles' }),
                  $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-focus.svg'}),
                  'Focus stories are stories you like',
                  $.make('br'),
                  $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-unread.svg'}),
                  'Unread stories include both focus and unread stories',
                  $.make('br'),
                  $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-hidden.svg'}),
                  'Hidden stories are filtered out'
                ]),
                $.make('li', [
                    $.make('a', { href: '/faq#intelligence', target: "_blank", className: 'NB-splash-link' }, 'Read more about how Intelligence works in the FAQ')
                ])
              ])
            ]),
            $.make('div', { className: 'NB-page NB-page-4' }, [
              $.make('h4', 'Here are a few tricks that may enhance your experience:'),
              $.make('ul', [
                $.make('li', { className: 'NB-tutorial-tips-sites' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_tips_sites.png' }),
                  $.make('div', [
                    'Click on the sites count at the top of the sidebar to hide sites with no unread stories.'
                  ])
                ]),
                $.make('li', [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_tips_instafetch.png' }),
                  'Instantly refresh a site by right-clicking on it and selecting ',
                  $.make('b', 'Insta-fetch stories.')
                ]),
                $.make('li', [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_tips_stories.png' }),
                  'Click the arrow next to sites and stories to open up a menu.'
                ]),
                $.make('li', { className: 'NB-tutorial-tips-train' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_tips_train.png' }),
                  $.make('div', 'Train sites in the Feed view by clicking directly on the tags and authors. The tags will rotate color between like and dislike.')
                ]),
                $.make('li', [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_tips_folders.png' }),
                  'Folders can be nested inside folders.'
                ]),
                $.make('li', [
                  'There are more than a dozen keyboard shortcuts you can use:',
                  $.make('div', { className: 'NB-modal-keyboard' }, [
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
                      $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
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
                        $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Next site'),
                        $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                            'shift',
                            $.make('span', '+'),
                            '&#x2193;'
                        ])
                      ]),
                      $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                        $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Prev. site'),
                        $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                            'shift',
                            $.make('span', '+'),
                            '&#x2191;'
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
                        ])
                      ]),        
                      $.make('div', { className: 'NB-keyboard-shortcut NB-last' }, [
                        $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, 'Open Site'),
                        $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
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
                            'shift',
                            $.make('span', '+'),
                            'u'
                        ])
                      ])
                    ])
                  ])
                ])
              ])
            ]),
            $.make('div', { className: 'NB-page NB-page-5' }, [
              $.make('h4', 'Stay connected to NewsBlur on Twitter'),
              $.make('div', { className: 'NB-tutorial-twitter' }, [
                $.make('a', { className: 'NB-splash-link', href: 'http://twitter.com/samuelclay', target: '_blank' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/static/Samuel%20Clay%20sq.jpg', style: 'border-color: #505050;' }),
                  $.make('span', '@samuelclay')
                ]),
                $.make('a', { className: 'NB-splash-link', href: 'http://twitter.com/newsblur', target: '_blank' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/logo_128.png' }),
                  $.make('span', '@newsblur')
                ])
              ]),
              $.make('h4', { className: 'NB-tutorial-feedback-header' }, 'Community Feedback'),
              $.make('ul', [
                $.make('li', [
                  $.make('a', { href: 'https://forum.newsblur.com/', className: 'NB-splash-link' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/discourse.png', style: 'vertical-align: middle;margin: -2px 0 0; width: 16px;height: 16px;' }),
                    ' NewsBlur Support Forum'
                  ])
                ])
              ]),
              $.make('h4', { className: 'NB-tutorial-feedback-header' }, [
                'Open Source Code'
              ]),
              $.make('ul', [
                $.make('li', [
                  $.make('a', { href: 'http://github.com/samuelclay', className: 'NB-splash-link' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/howitworks_github.png', style: 'float: right;margin: -68px 12px 0 0' }),
                    'NewsBlur on ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/github_icon.png', style: 'vertical-align: middle;margin: -2px 0 0' }),
                    ' GitHub'
                  ])
                ])
              ]),
              $.make('h4', { className: 'NB-tutorial-feedback-header' }, 'The NewsBlur Blog'),
              $.make('ul', [
                $.make('li', [
                  $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-javascript NB-tutorial-finish-newsblur-blog', style: 'float: right;margin-top: -2px' }, [
                    'Finish Tutorial and Load',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/favicon_32.png', style: "margin: -3px 0px 0px 4px; vertical-align: middle;width: 16px;height: 16px;" }),
                    ' the NewsBlur Blog ',
                    $.make('span', { className: 'NB-raquo' }, '&raquo;')
                  ]),
                  'Monthly updates.'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-page-next NB-modal-submit-button NB-modal-submit-green NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-tutorial-next-page-text' }, 'Next Page '),
                $.make('span', { className: 'NB-raquo' }, '&raquo;')
              ]),
              $.make('div', { className: 'NB-page-previous NB-modal-submit-button NB-modal-submit-grey NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-raquo' }, '&laquo;'),
                ' Previous Page'
              ])
            ])
        ]);
    },
    
    set_title: function() {
      $('.NB-modal-title span', this.$modal).text(this.TITLES[this.page_number-1]);
    },

    load_tips: function() {
      
    },
    
    make_story_titles: function() {
      var $story_titles = $('.NB-tutorial-stories', this.$modal);
      
      var stories = [
        ['Story about space travel',        '',         'space',  'neutral'],
        ['NewsBlur becomes #1 feed reader', '',         '',       'positive'],
        ['Everyday news',                   'Sam Clay', 'news',   'neutral'],
        ['Another top 10 list',             'RSC',      'top 10', 'negative'],
        ['Boring story about sports',       'Godzilla', '',       'negative'],
        ['New Strokes album!',              'P. Smith', 'music',  'positive']
      ];
      
      _.each(stories, function(story) {
        var $story = $.make('div', { className: 'story NB-story-' + story[3] }, [
          $.make('div', { className: 'NB-storytitles-sentiment'}),
          $.make('a', { href: '#', className: 'story_title' }, [
            $.make('span', { className: 'NB-storytitles-title' }, story[0]),
            (story[1] && $.make('span', { className: 'NB-storytitles-author' }, story[1])),
            (story[2] && $.make('span', { className: 'NB-storytitles-tags'}, [
              $.make('span', { className: 'NB-storytitles-tag'}, story[2]).corner('4px')
            ]))
          ]),
          $.make('div', { className: 'NB-story-manage-icon' })
        ]);
        $story_titles.append($story);
      });
    },
    
    load_intelligence_slider: function() {
      var self = this;
      var unread_view = this.model.preference('unread_view');
      this.set_slider_value(unread_view);
    },
    
    rotate_slider: function() {
      clearInterval(this.intervals.slider);
      this.intervals.slider = setInterval(_.bind(function() {
        this.slider_value = ((this.slider_value + 1) % 3);
        this.set_slider_value(this.slider_value - 1);
      }, this), 2000);
    },
    
    set_slider_value: function(value) {
      this.slider_value = value + 1;
      var $slider = $('.NB-intelligence-slider', this.$modal);

      $('.NB-active', $slider).removeClass('NB-active');
      if (value < 0) {
          $('.NB-intelligence-slider-red', $slider).addClass('NB-active');
      } else if (value > 0) {
          $('.NB-intelligence-slider-green', $slider).addClass('NB-active');
      } else {
          $('.NB-intelligence-slider-yellow', $slider).addClass('NB-active');
      }
      this.show_story_titles_above_intelligence_level(value);
      this.rotate_slider();
    },
    
    show_story_titles_above_intelligence_level: function(level) {
      level = level || 0;
      var $stories_show, $stories_hide;
      if (level > 0) {
        $stories_show = $('.NB-story-positive', this.$modal);
        $stories_hide = $('.NB-story-neutral,.NB-story-negative', this.$modal);
      } else if (level == 0) {
        $stories_show = $('.NB-story-positive,.NB-story-neutral', this.$modal);
        $stories_hide = $('.NB-story-negative', this.$modal);
      } else if (level < 0) {
        $stories_show = $('.NB-story-positive,.NB-story-neutral,.NB-story-negative', this.$modal);
        $stories_hide = $('.NB-story-nothing', this.$modal);
      }
      
      $stories_show.slideDown(500);
      $stories_hide.slideUp(500);
    },
    
    // ==========
    // = Paging =
    // ==========
    
    next_page: function() {
      return this.page(this.page_number+1);
    },
    
    previous_page: function() {
      return this.page(this.page_number-1);
    },
    
    page: function(page_number) {
      if (page_number == null) {
        return this.page_number;
      }
      var page_count = $('.NB-page', this.$modal).length;
      this.page_number = page_number;
      
      if (page_number == page_count) {
        $('.NB-tutorial-next-page-text', this.$modal).text('Finish Tutorial ');
      } else if (page_number > page_count) {
        return this.close();
      } else {
        $('.NB-tutorial-next-page-text', this.$modal).text('Next Page ');
      }
      $('.NB-page-previous', this.$modal).toggle(page_number != 1);
      $('.NB-page', this.$modal).css({'display': 'none'});
      $('.NB-page-'+this.page_number, this.$modal).css({'display': 'block'});
      $('.NB-modal-page', this.$modal).html($.make('div', [
        'Page ',
        $.make('b', this.page_number),
        ' of ',
        $.make('b', page_count)
      ]));
      this.set_title();
      this.resize();
      _.defer(_.bind(function() {
          this.resize();
      }, this));
    },
    
    close: function() {
      this.model.load_tutorial({'finished': true});
      NEWSBLUR.Modal.prototype.close.call(this);
    },
    
    close_and_load_newsblur_blog: function() {
      this.close();
      NEWSBLUR.reader.load_feed_in_tryfeed_view(this.newsblur_feed.id, {'feed': this.newsblur_feed});
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-page-next' }, function($t, $p) {
            e.preventDefault();
            
            self.next_page();
        });
        $.targetIs(e, { tagSelector: '.NB-page-previous' }, function($t, $p) {
            e.preventDefault();
            
            self.previous_page();
        });
        $.targetIs(e, { tagSelector: '.NB-tutorial-finish-newsblur-blog' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_newsblur_blog();
        });
        $.targetIs(e, { tagSelector: '.NB-story-manage-icon' }, function($t, $p) {
            e.preventDefault();
            e.stopPropagation();
        });
        $.targetIs(e, { tagSelector: '.NB-intelligence-slider-control' }, function($t, $p) {
            e.preventDefault();
            e.stopPropagation();

            var unread_value;
            if ($t.hasClass('NB-intelligence-slider-red')) {
                unread_value = -1;
            } else if ($t.hasClass('NB-intelligence-slider-yellow')) {
                unread_value = 0;
            } else if ($t.hasClass('NB-intelligence-slider-green')) {
                unread_value = 1;
            }
            
            self.set_slider_value(unread_value);

        });
    }
    
});
