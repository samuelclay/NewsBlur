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
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
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
              'Page 3'
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
    }
    
});