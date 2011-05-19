NEWSBLUR.ReaderTutorial = function(options) {
    var defaults = {};
    
    _.bindAll(this, 'close');
    
    this.options = $.extend({
      'page_number': 1
    }, defaults, options);
    this.model   = NEWSBLUR.AssetModel.reader();

    this.page_number = this.options.page_number;
    this.runner();
};

NEWSBLUR.ReaderTutorial.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderTutorial.prototype.constructor = NEWSBLUR.ReaderTutorial;

_.extend(NEWSBLUR.ReaderTutorial.prototype, {
    
    TITLES: [
      'Learn to use NewsBlur',
      'Three Feed Views',
      'Training the Intelligence',
      'Tips and Tricks',
      'Feedback and Open Source'
    ],
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        this.page(1);
        this.load_newsblur_blog_info();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    load_newsblur_blog_info: function() {
      this.model.load_tutorial(_.bind(function(data) {
        this.newsblur_feed = data.newsblur_feed;
        $('.NB-javascript', this.$modal).removeClass('NB-javascript');
      }, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-tutorial NB-modal' }, [
            $.make('span', { className: 'NB-modal-loading NB-spinner'}),
            $.make('div', { className: 'NB-modal-page' }),
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('div', { className: 'NB-page NB-page-1' }, [
              'Page 1'
            ]),
            $.make('div', { className: 'NB-page NB-page-2' }, [
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
                  'Double-click on story titles to temporarily open them up in the Story view.'
                ]),
                $.make('li', [
                  'You can train stories directly in the Feed view.'
                ]),
                $.make('li', [
                  'In the Original view, if a story is not found, it will temporarily open in the Feed view.'
                ]),
                $.make('li', [
                  'Much of these views can be customized under Preferences.'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-page NB-page-3' }, [
              $.make('h4', 'NewsBlur works best when you use intelligence classifiers.'),
              $.make('ul', [
                $.make('li', 'Something'),
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/intelligence_slider_all.png', style: 'float: right', width: 127, height: 92 }),
                    $.make('b', 'The intelligence slider filters stories.'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_green.png'}),
                    ' are stories you like',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_yellow.png'}),
                    ' are stories you have not yet rated',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_red.png'}),
                    ' are stories you don\'t like'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-page NB-page-4' }, [
              $.make('h4', 'Here are a few tricks that may enhance your experience:'),
              $.make('ul', [
                $.make('li', { className: 'NB-tutorial-tips-sites' }, [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_tips_sites.png' }),
                  $.make('div', [
                    'Click on ',
                    $.make('span', { className: 'NB-tutorial-sites-count' }),
                    ' at the top of the sidebar to hide sites with no unread stories.'
                  ])
                ]),
                $.make('li', [
                  $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tutorial_tips_instafetch.png' }),
                  'Instantly refresh a site by right-clicking on it and selecting ',
                  $.make('b', 'Insta-fetch stories.')
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
                  'There are more than a dozen keyboard shortcuts you can use:'
                ])
              ])
            ]),
            $.make('div', { className: 'NB-page NB-page-5' }, [
              $.make('h4', 'Stay connected to NewsBlur on Twitter'),
              $.make('div', { className: 'NB-tutorial-twitter' }, [
                $.make('a', { className: 'NB-splash-link', href: 'http://twitter.com/samuelclay', target: '_blank' }, [
                  $.make('img', { src: 'http://img.tweetimag.es/i/samuelclay_n.png', style: 'border: 1px solid #505050;' }),
                  $.make('span', '@samuelclay')
                ]),
                $.make('a', { className: 'NB-splash-link', href: 'http://twitter.com/newsblur', target: '_blank' }, [
                  $.make('img', { src: 'http://img.tweetimag.es/i/newsblur_n.png' }),
                  $.make('span', '@newsblur')
                ])
              ]),
              $.make('h4', { className: 'NB-tutorial-feedback-header' }, 'Community Feedback'),
              $.make('ul', [
                $.make('li', [
                  $.make('a', { href: 'http://getsatisfaction.com/newsblur', className: 'NB-splash-link' }, [
                    'NewsBlur on ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/getsatisfaction.png', style: 'vertical-align: middle;margin: -2px 0 0' }),
                    ' Get Satisfaction'
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
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/favicon.png', style: "margin: -3px 0px 0px 4px; vertical-align: middle;" }),
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
              $.make('div', { className: 'NB-page-previous NB-modal-submit-button NB-modal-submit-close NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-raquo' }, '&laquo;'),
                ' Previous Page'
              ])
            ])
        ]);
    },
    
    set_title: function() {
      $('.NB-modal-title', this.$modal).text(this.TITLES[this.page_number-1]);
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
    },
    
    close: function() {
      _.delay(function() {
        NEWSBLUR.reader.hide_tutorial();
      }, 500);
      NEWSBLUR.Modal.prototype.close.call(this);
    },
    
    close_and_load_newsblur_blog: function() {
      this.close();
      NEWSBLUR.reader.load_feed_in_tryfeed_view(this.newsblur_feed.id, this.newsblur_feed);
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
    }
    
});