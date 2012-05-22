NEWSBLUR.ReaderFeedException = function(feed_id, options) {
    var defaults = {};
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.assets;
    this.feed_id = feed_id;
    this.feed    = this.model.get_feed(feed_id);

    this.runner();
};

NEWSBLUR.ReaderFeedException.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderFeedException.prototype.constructor = NEWSBLUR.ReaderFeedException;

_.extend(NEWSBLUR.ReaderFeedException.prototype, {
    
    runner: function() {
        NEWSBLUR.Modal.prototype.initialize_feed.call(this, this.feed_id);
        this.make_modal();
        this.show_recommended_options_meta();
        this.handle_cancel();
        this.open_modal();
        this.initialize_feed(this.feed_id);
        
        _.delay(_.bind(function() {
            this.get_feed_settings();
        }, this), 50);
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },

    initialize_feed: function(feed_id) {
        var view_setting = this.model.view_setting(feed_id);
        NEWSBLUR.Modal.prototype.initialize_feed.call(this, feed_id);
        $('input[name=feed_link]', this.$modal).val(this.feed.get('feed_link'));
        $('input[name=feed_address]', this.$modal).val(this.feed.get('feed_address'));
        $('input[name=view_settings]', this.$modal).each(function() {
            if ($(this).val() == view_setting) {
                $(this).attr('checked', true);
                return false;
            }
        });
                
        if (this.feed.get('exception_type')) {
            this.$modal.removeClass('NB-modal-feed-settings');
        } else {
            this.$modal.addClass('NB-modal-feed-settings');
        }
        
        this.resize();
    },
    
    get_feed_settings: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        var settings_fn = this.options.social_feed ? this.model.get_social_settings : this.model.get_feed_settings;
        settings_fn.call(this.model, this.feed_id, _.bind(this.populate_settings, this));
    },
    
    populate_settings: function() {
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.removeClass('NB-active');
        this.resize();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-exception NB-modal' }, [
            $.make('div', { className: 'NB-modal-feed-chooser-container'}, [
                this.make_feed_chooser()
            ]),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title NB-exception-block-only' }, 'Fix a misbehaving site'),
            $.make('h2', { className: 'NB-modal-title' }, 'Site settings'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed) }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title')),
                    $.make('span', { className: 'NB-modal-feed-subscribers' },Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true))
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-view NB-modal-submit NB-settings-only' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-status NB-right' }),
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    'View settings'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Reading view'
                        ]),
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-view-1', type: 'radio', name: 'view_settings', value: 'page' }),
                                $.make('label', { 'for': 'NB-preference-view-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/preferences_view_original.png' })
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-view-2', type: 'radio', name: 'view_settings', value: 'feed' }),
                                $.make('label', { 'for': 'NB-preference-view-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/preferences_view_feed.png' })
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-view-3', type: 'radio', name: 'view_settings', value: 'story' }),
                                $.make('label', { 'for': 'NB-preference-view-3' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/preferences_view_story.png' })
                                ])
                            ])
                        ])                      
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-retry NB-modal-submit NB-exception-block-only' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 1:'),
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
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-feed NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 2:'),
                    'Change RSS Feed Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-address', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'RSS/XML URL: '
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-address', className: 'NB-exception-input-address NB-input', name: 'feed_address', value: this.feed.get('feed_address') })
                    ]),
                    (!this.options.social_feed && $.make('div', { className: 'NB-exception-submit-wrapper' }, [
                        $.make('input', { type: 'submit', value: 'Parse this RSS/XML Feed', className: 'NB-modal-submit-green NB-modal-submit-address' }),
                        $.make('div', { className: 'NB-error' })
                    ]))
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-page NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 3:'),
                    'Change Website Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-link', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'Website URL: '
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-link', className: 'NB-exception-input-link NB-input', name: 'feed_link', value: this.feed.get('feed_link') })
                    ]),
                    (!this.options.social_feed && $.make('div', { className: 'NB-exception-submit-wrapper' }, [
                        $.make('input', { type: 'submit', value: 'Fetch Feed From Website', className: 'NB-modal-submit-green NB-modal-submit-link' }),
                        $.make('div', { className: 'NB-error' })
                    ]))
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-delete NB-exception-block-only NB-modal-submit' }, [
                $.make('h5', [
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 4:'),
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
      var is_400 = (400 <= this.feed.get('exception_code') && this.feed.get('exception_code') < 500);
      
      if (!is_400) {
          $meta_retry.addClass('NB-exception-option-meta-recommended');
          $meta_retry.text('Recommended');
          return;
      }
      if (this.feed.get('exception_type') == 'feed') {
          $meta_page.addClass('NB-exception-option-meta-recommended');
          $meta_page.text('Recommended');
      }
      if (this.feed.get('exception_type') == 'page') {
          if (is_400) {
              $meta_feed.addClass('NB-exception-option-meta-recommended');
              $meta_feed.text('Recommended');
          } else {
              $meta_page.addClass('NB-exception-option-meta-recommended');
              $meta_page.text('Recommended');
          }
      }
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
    
    save_retry_feed: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        var feed_id = this.feed_id;
        
        $('.NB-modal-submit-retry', this.$modal).addClass('NB-disabled').attr('value', 'Fetching...');
        
        this.model.save_exception_retry(feed_id, function() {
            NEWSBLUR.reader.force_feed_refresh(feed_id);
            $.modal.close();
        });
    },
    
    delete_feed: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        $('.NB-modal-submit-delete', this.$modal).addClass('NB-disabled').attr('value', 'Deleting...');
        
        var feed_id = this.feed_id;
        
        // this.model.delete_feed(feed_id, function() {
        NEWSBLUR.reader.manage_menu_delete_feed(feed_id);
        _.delay(function() { $.modal.close(); }, 500);
        // });
    },
    
    change_feed_address: function() {
        var feed_id = this.feed_id;
        var $loading = $('.NB-modal-loading', this.$modal);
        var $feed_address = $('input[name=feed_address]', this.$modal);
        var $submit = $('.NB-modal-submit-address', this.$modal);
        var $error = $feed_address.closest('.NB-exception-option').find('.NB-error');
        var feed_address = $feed_address.val();
        
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').attr('value', 'Parsing...');
        $error.hide().html('');
        
        if (feed_address.length) {
            this.model.save_exception_change_feed_address(feed_id, feed_address, function(code) {
                NEWSBLUR.reader.force_feed_refresh(feed_id);
                $.modal.close();
            }, function(data) {
                $error.show().html((data && data.message) || "There was a problem fetching the feed from this URL.");
                $loading.removeClass('NB-active');
                $submit.removeClass('NB-disabled').attr('value', 'Parse this RSS/XML Feed');
            });
        }
    },
    
    change_feed_link: function() {
        var feed_id = this.feed_id;
        var $feed_link = $('input[name=feed_link]', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        var $submit = $('.NB-modal-submit-link', this.$modal);
        var $error = $feed_link.closest('.NB-exception-option').find('.NB-error');
        var feed_link = $feed_link.val();

        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').attr('value', 'Fetching...');
        $error.hide().html('');

        if (feed_link.length) {
            this.model.save_exception_change_feed_link(feed_id, feed_link, function(code) {
                NEWSBLUR.reader.force_feed_refresh(feed_id);
                $.modal.close();
            }, function(data) {
                $error.show().html((data && data.message) || "There was a problem fetching the feed from this URL.");
                $loading.removeClass('NB-active');
                $submit.removeClass('NB-disabled').attr('value', 'Fetch Feed from Website');
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
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function($t, $p){
            var feed_id = $t.val();
            self.first_load = false;
            self.initialize_feed(feed_id);
            self.get_feed_settings();
        });
        
        $.targetIs(e, { tagSelector: 'input[name=view_settings]' }, function($t, $p){
            self.model.view_setting(self.feed_id, $t.val());

            var $status = $('.NB-exception-option-view .NB-exception-option-status', self.$modal);
            $status.text('Saved').animate({
                'opacity': 1
            }, {
                'queue': false,
                'duration': 600,
                'complete': function() {
                    _.delay(function() {
                        $status.animate({'opacity': 0}, {'queue': false, 'duration': 1000});
                    }, 300);
                }
            });
        });
    }
    
});