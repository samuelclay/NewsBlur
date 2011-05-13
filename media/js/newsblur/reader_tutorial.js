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
            $.make('h2', { className: 'NB-modal-title' }, 'Learn to use NewsBlur'),
            $.make('div', { className: 'NB-page NB-page-1' }, [
              'Page 1'
            ]),
            $.make('div', { className: 'NB-page NB-page-2' }, [
              'Page 2'
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