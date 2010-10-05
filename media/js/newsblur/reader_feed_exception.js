NEWSBLUR.ReaderFeedException = function(feed_id, options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.feed_id = feed_id;
    this.feed = this.model.get_feed(feed_id);
    this.runner();
};

NEWSBLUR.ReaderFeedException.prototype = {
    
    runner: function() {
        this.make_modal();
        this.show_recommended_options_meta();
        this.handle_cancel();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        
        NEWSBLUR.log(['Exception Modal', this.feed]);
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-exception NB-modal' }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, 'Fix a misbehaving site'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: NEWSBLUR.Globals.google_favicon_url + this.feed.feed_link }),
                $.make('span', { className: 'NB-modal-feed-title' }, this.feed.feed_title)
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-retry NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option' }, 'Option 1:'),
                    'Retry'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('input', { type: 'submit', value: 'Retry fetching and parsing', className: 'NB-modal-submit-green NB-modal-submit-retry' }),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-page NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option' }, 'Option 2:'),
                    'Change Website Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-link' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'Website URL: '
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-link', className: 'NB-exception-input-link', name: 'feed_link', value: this.feed['feed_link'] }),
                        $.make('input', { type: 'submit', value: 'Fetch Feed From Website', className: 'NB-modal-submit-green NB-modal-submit-link' }),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-feed NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option' }, 'Option 3:'),
                    'Change RSS Feed Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-address' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'RSS/XML URL: '
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-address', className: 'NB-exception-input-address', name: 'feed_address', value: this.feed['feed_address'] }),
                        $.make('input', { type: 'submit', value: 'Parse this RSS/XML Feed', className: 'NB-modal-submit-green NB-modal-submit-address' }),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-delete NB-modal-submit' }, [
                $.make('h5', [
                    $.make('span', { className: 'NB-exception-option-option' }, 'Option 4:'),
                    'Just Delete This Feed'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('input', { type: 'submit', value: 'Delete It. It Just Won\'t Work!', className: 'NB-modal-submit-red NB-modal-submit-delete' }),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ])
        ]);
    },
    
    show_recommended_options_meta: function() {
      var $meta_retry = $('.NB-exception-option-retry .NB-exception-option-meta', this.$modal);
      var $meta_page = $('.NB-exception-option-page .NB-exception-option-meta', this.$modal);
      var $meta_feed = $('.NB-exception-option-feed .NB-exception-option-meta', this.$modal);
      var is_400 = (400 <= this.feed.exception_code && this.feed.exception_code < 500);
      
      if (!is_400) {
          $meta_retry.addClass('NB-exception-option-meta-recommended');
          $meta_retry.text('Recommended');
          return;
      }
      if (this.feed.exception_type == 'feed') {
          $meta_page.addClass('NB-exception-option-meta-recommended');
          $meta_page.text('Recommended');
      }
      if (this.feed.exception_type == 'page') {
          if (is_400) {
              $meta_feed.addClass('NB-exception-option-meta-recommended');
              $meta_feed.text('Recommended');
          } else {
              $meta_page.addClass('NB-exception-option-meta-recommended');
              $meta_page.text('Recommended');
          }
      }
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
    
    save_retry_feed: function() {
        var self = this;
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        $('.NB-modal-submit-retry', this.$modal).addClass('NB-disabled').attr('value', 'Fetching...');
        
        this.model.save_exception_retry(this.feed_id, function() {
            NEWSBLUR.reader.flags['has_unfetched_feeds'] = true;
            NEWSBLUR.reader.force_feed_refresh();
            $.modal.close();
        });
    },
    
    delete_feed: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        $('.NB-modal-submit-delete', this.$modal).addClass('NB-disabled').attr('value', 'Deleting...');
        
        var feed_id = this.feed_id;
        
        this.model.delete_publisher(feed_id, function() {
            NEWSBLUR.reader.delete_feed(feed_id);
            $.modal.close();
        });
    },
    
    change_feed_address: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        $('.NB-modal-submit-address', this.$modal).addClass('NB-disabled').attr('value', 'Parsing...');
        
        var feed_id = this.feed_id;
        var feed_address = $('input[name=feed_address]', this.$modal).val();
        
        if (feed_address.length) {
            this.model.save_exception_change_feed_address(feed_id, feed_address, function(code) {
                NEWSBLUR.reader.flags['has_unfetched_feeds'] = true;
                NEWSBLUR.reader.load_feeds();
                $.modal.close();
            });
        }
    },
    
    change_feed_link: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        $('.NB-modal-submit-link', this.$modal).addClass('NB-disabled').attr('value', 'Fetching...');
        
        var feed_id = this.feed_id;
        var feed_link = $('input[name=feed_link]', this.$modal).val();
        
        if (feed_link.length) {
            this.model.save_exception_change_feed_link(feed_id, feed_link, function(code) {
                NEWSBLUR.reader.flags['has_unfetched_feeds'] = true;
                NEWSBLUR.reader.load_feeds();
                $.modal.close();
            });
        }
    },
            
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
    
        $.targetIs(e, { tagSelector: '.NB-modal-submit-retry' }, function($t, $p) {
            e.preventDefault();
            
            self.save_retry_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-delete' }, function($t, $p) {
            e.preventDefault();
            
            self.delete_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-address' }, function($t, $p) {
            e.preventDefault();
            
            self.change_feed_address();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-link' }, function($t, $p) {
            e.preventDefault();
            
            self.change_feed_link();
        });
    }
    
};