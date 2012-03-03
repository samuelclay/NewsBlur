NEWSBLUR.ReaderIntro = function(options) {
    var defaults = {};
    
    _.bindAll(this, 'close');
    
    this.options = $.extend({
      'page_number': 2
    }, defaults, options);
    this.model   = NEWSBLUR.AssetModel.reader();

    this.page_number = this.options.page_number;
    this.slider_value = 0;
    this.intervals = {};
    this.runner();
};

NEWSBLUR.ReaderIntro.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderIntro.prototype.constructor = NEWSBLUR.ReaderIntro;

_.extend(NEWSBLUR.ReaderIntro.prototype, {
    
    TITLES: [
      'Welcome to NewsBlur',
      'Welcome to NewsBlur',
      'Welcome to NewsBlur',
      'Welcome to NewsBlur',
      'Welcome to NewsBlur'
    ],
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        this.page(this.page_number);
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
        
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-intro NB-modal' }, [
            $.make('span', { className: 'NB-modal-loading NB-spinner'}),
            $.make('div', { className: 'NB-modal-page' }),
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('img', { className: 'NB-intro-spinning-logo', src: NEWSBLUR.Globals.MEDIA_URL + 'img/logo_512.png' }),
            $.make('div', { className: 'NB-page NB-page-1' }, [
                $.make('h4', { className: 'NB-page-1-started' }, "So much time and so little to do. Strike that! Reverse it.")
            ]),
            $.make('div', { className: 'NB-page NB-page-2' }, [
                $.make('h4', { className: 'NB-page-2-started' }, "Let's get some sites to read."),
                $.make('div', { className: 'NB-intro-imports' }, [
                    $.make('div', { className: 'NB-intro-import' }, [
                        $.make('h3', [
                            'Import from', 
                            $.make('br'), 
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/google-reader-logo.gif' })
                        ]),
                        $.make('a', { href: NEWSBLUR.URLs['google-reader-authorize'], className: 'NB-google-reader-oauth NB-modal-submit-green NB-modal-submit-button' }, [
                            'Connect to Google'
                        ])
                    ]),
                    $.make('div', { className: 'NB-intro-import NB-intro-import-opml' }, [
                        $.make('h3', ['Upload an', $.make('br'), ' OPML file']),
                        $.make('form', { method: 'post', enctype: 'multipart/form-data', className: 'NB-add-form' }, [
                            $.make('div', { className: 'NB-loading' }),
                            // $.make('input', { type: 'file', name: 'file', id: 'opml_file_input' }),
                            $.make('a', { href: '#', className: 'NB-intro-upload-opml NB-modal-submit-green NB-modal-submit-button' }, [
                                'Upload OPML File',
                                $.make('input', { type: 'file', className: 'NB-intro-upload-opml-button' })
                            ])
                        ]),
                        $.make('div', { className: 'NB-error' })
                    ])
                ]),
                $.make('div', { className: 'NB-intro-bookmarklet' }, [
                    NEWSBLUR.generate_bookmarklet(),
                    $.make('div', { className: 'NB-intro-bookmarklet-arrow' }, '&larr;'),
                    $.make('div', { className: 'NB-intro-bookmarklet-info' }, 'Install the bookmarklet')
                ])
            ]),
            $.make('div', { className: 'NB-page NB-page-3' }, [
                $.make('h4', { className: 'NB-page-3-started' }, "Social")
            ]),
            $.make('div', { className: 'NB-page NB-page-4' }, [
                $.make('h4', { className: 'NB-page-4-started' }, "Feed chooser/premium")
            ]),
            $.make('div', { className: 'NB-page NB-page-5' }, [
                $.make('h4', { className: 'NB-page-5-started' }, "Feedback")
            ]),
            $.make('div', { className: 'NB-modal-submit' }, [
              $.make('div', { className: 'NB-page-next NB-modal-submit-button NB-modal-submit-green NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-tutorial-next-page-text' }, "Let's Get Started "),
                $.make('span', { className: 'NB-raquo' }, '&raquo;')
              ]),
              $.make('div', { className: 'NB-page-previous NB-modal-submit-button NB-modal-submit-close NB-modal-submit-save' }, [
                $.make('span', { className: 'NB-tutorial-previous-page-text' }, "Skip this step "),
                $.make('span', { className: 'NB-raquo' }, '&raquo;')
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
      return this.page(this.page_number+1, this.page_number);
    },
    
    previous_page: function() {
      return this.page(this.page_number-1, this.page_number);
    },
    
    page: function(page_number, from_page) {
      if (page_number == null) {
        return this.page_number;
      }
      var page_count = $('.NB-page', this.$modal).length;
      this.page_number = page_number;
      
      if (page_number == page_count) {
        $('.NB-tutorial-next-page-text', this.$modal).text('All Done ');
      } else if (page_number > page_count) {
        return this.close();
      } else if (page_number == 1) {
        $('.NB-tutorial-next-page-text', this.$modal).text("Let's Get Started ");
      } else {
        $('.NB-tutorial-next-page-text', this.$modal).text('Next Page ');
      }
      $('.NB-page-previous', this.$modal).toggle(page_number != 1);
      $('.NB-page', this.$modal).css({'display': 'none'});
      $('.NB-page-'+this.page_number, this.$modal).css({'display': 'block'});
      $('.NB-modal-page', this.$modal).html($.make('div', [
        'Step ',
        $.make('b', this.page_number),
        ' of ',
        $.make('b', page_count)
      ]));
      if (page_number > 1) {
          $('.NB-intro-spinning-logo', this.$modal).css({'top': 0, 'left': 0, 'width': 48, 'height': 48});
          $('.NB-modal-title', this.$modal).css({'paddingLeft': 42});
      }
      
      this.set_title();
    },
    
    fade_out_logo: function() {
        var self = this;
        var $logo = $('.NB-intro-spinning-logo', this.$modal);
        var $page1 = $('.NB-page-1', this.$modal);
        var $page2 = $('.NB-page-2', this.$modal);
        var $submit = $('.NB-modal-submit', this.$modal);
        var $title = $('.NB-modal-title', this.$modal);
        
        $submit.animate({'opacity': 0}, {'duration': 800, 'easing': 'easeInOutQuad'});
        $page1.animate({'opacity': 0}, {
            'duration': 800, 
            'easing': 'easeInOutQuint', 
            'complete': function() {
                $logo.animate({'top': 0, 'left': 0, 'width': 48, 'height': 48}, {
                    'duration': 1360,
                    'easing': 'easeInOutCubic',
                    'complete': function() {
                        $page2.css({'opacity': 0});
                        self.page(2);
                        $page2.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeInOutQuad'});
                        $submit.animate({'opacity': 1}, {'duration': 1000, 'easing': 'easeInOutQuad'});
                    }
                });
                $title.animate({'paddingLeft': 42}, {'duration': 1400, 'easing': 'easeInOutQuart'});
            }
        });
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
            
            if (self.page_number == 1) {
                self.fade_out_logo();
            } else {
                self.next_page();
            }
        });
        $.targetIs(e, { tagSelector: '.NB-page-previous' }, function($t, $p) {
            e.preventDefault();
            
            self.previous_page();
        });
        $.targetIs(e, { tagSelector: '.NB-tutorial-finish-newsblur-blog' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_newsblur_blog();
        });
        
        $.targetIs(e, { tagSelector: '.NB-goodies-bookmarklet-button' }, function($t, $p) {
            e.preventDefault();
            
            alert('Drag this button to your bookmark toolbar.');
        });
    }
    
});