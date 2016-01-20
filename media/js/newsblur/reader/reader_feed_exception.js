NEWSBLUR.ReaderFeedException = function(feed_id, options) {
    var defaults = {
        'onOpen': function() {
            $(window).trigger('resize.simplemodal');
        }
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.assets;
    this.feed_id = feed_id;
    this.feed    = this.model.get_feed(feed_id);
    this.folder_title  = this.options.folder_title;
    this.folder  = this.folder_title && NEWSBLUR.assets.get_folder(this.folder_title);
    
    this.runner();
};

NEWSBLUR.ReaderFeedException.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderFeedException.prototype.constructor = NEWSBLUR.ReaderFeedException;

_.extend(NEWSBLUR.ReaderFeedException.prototype, {
    
    runner: function() {
        if (this.folder) {
            NEWSBLUR.Modal.prototype.initialize_folder.call(this, this.folder_title);
        } else {
            NEWSBLUR.Modal.prototype.initialize_feed.call(this, this.feed_id);            
        }
        this.make_modal();
        if (this.feed) {
            this.show_recommended_options_meta();
            _.delay(_.bind(function() {
                this.get_feed_settings();
            }, this), 50);
        }
        this.handle_cancel();
        this.open_modal();
        this.initialize_feed(this.feed_id);
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },

    initialize_feed: function(feed_id) {
        var view_setting = this.model.view_setting(feed_id, 'view');
        var story_layout = this.model.view_setting(feed_id, 'layout');

        if (this.feed) {
            NEWSBLUR.Modal.prototype.initialize_feed.call(this, feed_id);
            $('input[name=feed_link]', this.$modal).val(this.feed.get('feed_link'));
            $('input[name=feed_address]', this.$modal).val(this.feed.get('feed_address'));
            $(".NB-exception-option-page", this.$modal).toggle(this.feed.is_feed() || this.feed.is_social());
            $(".NB-view-setting-original", this.$modal).toggle(this.feed.is_feed() || this.feed.is_social());
        } else if (this.folder) {
            NEWSBLUR.Modal.prototype.initialize_folder.call(this, feed_id);
        }
        
        $('input[name=view_settings]', this.$modal).each(function() {
            if ($(this).val() == view_setting) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=story_layout]', this.$modal).each(function() {
            if ($(this).val() == story_layout) {
                $(this).attr('checked', true);
                return false;
            }
        });
        
        if (this.folder) {
            this.$modal.addClass('NB-modal-folder-settings');
            this.$modal.removeClass('NB-modal-feed-settings');
            $(".NB-modal-title", this.$modal).text("Folder Settings");
        } else if (this.feed.get('exception_type')) {
            this.$modal.removeClass('NB-modal-folder-settings');
            this.$modal.removeClass('NB-modal-feed-settings');
            $(".NB-modal-title", this.$modal).text("Fix a misbehaving site");
        } else {
            this.$modal.removeClass('NB-modal-folder-settings');
            this.$modal.addClass('NB-modal-feed-settings');
            $(".NB-modal-title", this.$modal).text("Site Settings");
        }

        this.resize();
    },
    
    get_feed_settings: function() {
        if (this.feed.is_starred()) return;
        
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        var settings_fn = this.options.social_feed ? this.model.get_social_settings :
                          this.model.get_feed_settings;
        settings_fn.call(this.model, this.feed_id, _.bind(this.populate_settings, this));
    },
    
    populate_settings: function(data) {
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        var $page_history = $(".NB-exception-page-history", this.$modal);
        var $feed_history = $(".NB-exception-feed-history", this.$modal);
        
        $feed_history.html(this.make_history(data, 'feed_fetch'));
        $page_history.html(this.make_history(data, 'page_fetch'));
        
        $loading.removeClass('NB-active');
        this.resize();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-exception NB-modal' }, [
            (this.feed && $.make('div', { className: 'NB-modal-feed-chooser-container'}, [
                this.make_feed_chooser()
            ])),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title NB-exception-block-only' }, 'Fix a misbehaving site'),
            $.make('h2', { className: 'NB-modal-title' }, 'Site settings'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon' }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }),
                    $.make('span', { className: 'NB-modal-feed-subscribers' })
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
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "NB-view-setting-original" }, [
                                $.make('label', { 'for': 'NB-preference-view-1' }, [
                                    $.make('input', { id: 'NB-preference-view-1', type: 'radio', name: 'view_settings', value: 'page' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_original_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Original")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-2' }, [
                                    $.make('input', { id: 'NB-preference-view-2', type: 'radio', name: 'view_settings', value: 'feed' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_feed_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Feed")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-3' }, [
                                    $.make('input', { id: 'NB-preference-view-3', type: 'radio', name: 'view_settings', value: 'text' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_text_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Text")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-4' }, [
                                    $.make('input', { id: 'NB-preference-view-4', type: 'radio', name: 'view_settings', value: 'story' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_story_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Story")
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Story layout'
                        ]),
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "" }, [
                                $.make('label', { 'for': 'NB-preference-layout-1' }, [
                                    $.make('input', { id: 'NB-preference-layout-1', type: 'radio', name: 'story_layout', value: 'full' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_full_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Full")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-2' }, [
                                    $.make('input', { id: 'NB-preference-layout-2', type: 'radio', name: 'story_layout', value: 'split' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_split_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Split")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-3' }, [
                                    $.make('input', { id: 'NB-preference-layout-3', type: 'radio', name: 'story_layout', value: 'list' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_list_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "List")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-4' }, [
                                    $.make('input', { id: 'NB-preference-layout-4', type: 'radio', name: 'story_layout', value: 'grid' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_grid_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Grid")
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
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-retry' }, 'Retry fetching and parsing'),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ]),
            (this.feed && $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-feed NB-modal-submit' }, [
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
                    (this.feed.is_feed() && $.make('div', { className: 'NB-exception-submit-wrapper' }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-address' }, 'Parse this RSS/XML Feed'),
                        $.make('div', { className: 'NB-error' }),
                        $.make('div', { className: 'NB-exception-feed-history' })
                    ]))
                ])
            ])),
            (this.feed && $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-page NB-modal-submit' }, [
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
                    (this.feed.is_feed() && $.make('div', { className: 'NB-exception-submit-wrapper' }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-link' }, 'Fetch Feed From Website'),
                        $.make('div', { className: 'NB-error' }),
                        $.make('div', { className: 'NB-exception-page-history' })
                    ]))
                ])
            ])),
            (this.folder && $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-feed NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    'Folder RSS Feed Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-unread', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'Unread+Focus:'
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-unread', className: 'NB-exception-input-unread NB-input', name: 'folder_rss_unread_url', value: this.folder.rss_url('unread') })
                    ]),
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-focus', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'Only Focus:'
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-focus', className: 'NB-exception-input-focus NB-input', name: 'folder_rss_focus_url', value: this.folder.rss_url('focus') })
                    ]),
                    (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-premium-only' }, [
                        $.make('div', { className: 'NB-premium-only-divider'}),
                        $.make('div', { className: 'NB-premium-only-text'}, [
                            'RSS feeds for folders is a ',
                            $.make('a', { href: '#', className: 'NB-premium-only-link NB-splash-link' }, 'premium feature'),
                            '.'
                        ])
                    ]))
                ])
            ])),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-delete NB-exception-block-only NB-modal-submit' }, [
                $.make('h5', [
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 4:'),
                    'Just Delete This Feed'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-red NB-modal-submit-delete' }, 'Delete It. It Just Won\'t Work!'),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ])
        ]);
    },
    
    make_history: function(data, fetch_type) {
        var fetches = data[fetch_type+'_history'];
        var $history;
        
        if (fetches && fetches.length) {
            $history = _.map(fetches, function(fetch) {
                var feed_ok = _.contains([200, 304], fetch.status_code) || !fetch.status_code;
                var status_class = feed_ok ? ' NB-ok ' : ' NB-errorcode ';
                return $.make('div', { className: 'NB-history-fetch' + status_class, title: feed_ok ? '' : fetch.exception }, [
                    $.make('div', { className: 'NB-history-fetch-date' }, fetch.fetch_date || fetch.push_date),
                    $.make('div', { className: 'NB-history-fetch-message' }, [
                        fetch.message,
                        (fetch.status_code && $.make('div', { className: 'NB-history-fetch-code' }, ' ('+fetch.status_code+')'))
                    ])
                ]);
            });
        }

        return $.make('div', $history);
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
            this.model.save_exception_change_feed_address(feed_id, feed_address, _.bind(function(data) {
                console.log(["return to change address", data]);
                NEWSBLUR.assets.feeds.add(_.values(data.feeds));
                var feed = NEWSBLUR.assets.get_feed(data.new_feed_id || feed_id);
                var old_feed = NEWSBLUR.assets.get_feed(feed_id);
                if (data.new_feed_id != feed_id && old_feed.get('selected')) {
                    old_feed.set('selected', false);
                }
                
                if (data && data.new_feed_id) {
                    NEWSBLUR.assets.load_feeds(function() {
                        var feed = NEWSBLUR.assets.get_feed(data.new_feed_id || feed_id);
                        console.log(["Loading feed", data.new_feed_id || feed_id, feed]);
                        NEWSBLUR.reader.open_feed(feed.id);
                    });
                }
                
                console.log(["feed address", feed, NEWSBLUR.assets.get_feed(feed_id)]);
                if (!data || data.code < 0 || !data.new_feed_id) {
                    var error = data.message || "There was a problem fetching the feed from this URL.";
                    if (parseInt(feed.get('exception_code'), 10) == 404) {
                        error = "URL gives a 404 - page not found.";
                    }
                    $error.show().html((data && data.message) || error);
                }
                $loading.removeClass('NB-active');
                $submit.removeClass('NB-disabled').attr('value', 'Parse this RSS/XML Feed');
                this.populate_settings(data);
            }, this));
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
            this.model.save_exception_change_feed_link(feed_id, feed_link, _.bind(function(data) {
                var old_feed = NEWSBLUR.assets.get_feed(feed_id);
                if (data.new_feed_id != feed_id && old_feed.get('selected')) {
                    old_feed.set('selected', false);
                }
                
                if (data && data.new_feed_id) {
                    NEWSBLUR.assets.load_feeds(function() {
                        var feed = NEWSBLUR.assets.get_feed(data.new_feed_id || feed_id);
                        console.log(["Loading feed", data.new_feed_id || feed_id, feed]);
                        NEWSBLUR.reader.open_feed(feed.id);
                    });
                }
                
                var feed = NEWSBLUR.assets.get_feed(data.new_feed_id) || NEWSBLUR.assets.get_feed(feed_id);
                
                if (!data || data.code < 0 || !data.new_feed_id) {
                    var error = data.message || "There was a problem fetching the feed from this URL.";
                    if (feed.get('exception_code') == '404') {
                        error = "URL gives a 404 - page not found.";
                    }
                    $error.show().html((data && data.message) || error);
                }
                $loading.removeClass('NB-active');
                $submit.removeClass('NB-disabled').attr('value', 'Fetch Feed from Website');
                this.populate_settings(data);
            }, this));
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
        $.targetIs(e, { tagSelector: '.NB-premium-only-link' }, function($t, $p){
            e.preventDefault();
            
            self.close(function() {
                NEWSBLUR.reader.open_feedchooser_modal({premium_only: true});
            });
        });
    },
    
    animate_saved: function() {
        var $status = $('.NB-exception-option-view .NB-exception-option-status', this.$modal);
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
    },
    
    animate_saved: function() {
        var $status = $('.NB-exception-option-view .NB-exception-option-status', this.$modal);
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
            if (self.folder) {
                self.folder.view_setting({'view': $t.val()});
            } else {
                NEWSBLUR.assets.view_setting(self.feed_id, {'view': $t.val()});
            }
            self.animate_saved();
        });
        $.targetIs(e, { tagSelector: 'input[name=story_layout]' }, function($t, $p){
            if (self.folder) {
                self.folder.view_setting({'layout': $t.val()});
            } else {
                NEWSBLUR.assets.view_setting(self.feed_id, {'layout': $t.val()});
            }
            self.animate_saved();
        });
    }
    
});