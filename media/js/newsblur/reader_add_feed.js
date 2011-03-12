NEWSBLUR.ReaderAddFeed = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.runner();
};

NEWSBLUR.ReaderAddFeed.prototype = {
    
    runner: function() {
        this.make_modal();
        this.handle_cancel();
        this.open_modal();
        this.handle_keystrokes();
        this.setup_autocomplete();
        this.focus_add_feed();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-add NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Add feeds and folders'),
            $.make('div', { className: 'NB-add-form' }, [
                $.make('div', { className: 'NB-fieldset NB-add-add-url NB-modal-submit' }, [
                    $.make('h5', [
                        $.make('div', { className: 'NB-add-folders' }, this.make_folders()),
                        'Add a new feed'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', [
                            $.make('div', { className: 'NB-loading' }),
                            $.make('label', { 'for': 'NB-add-url' }, 'RSS or URL: '),
                            $.make('input', { type: 'text', id: 'NB-add-url', className: 'NB-add-url', name: 'url', value: self.options.url }),
                            $.make('input', { type: 'submit', value: 'Add it', className: 'NB-modal-submit-green NB-add-url-submit' }),
                            $.make('div', { className: 'NB-error' })
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset NB-add-add-folder NB-modal-submit' }, [
                    $.make('h5', [
                        $.make('div', { className: 'NB-add-folders' }, this.make_folders()),
                        'Add a new folder'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', [
                            $.make('div', { className: 'NB-loading' }),
                            $.make('label', { 'for': 'NB-add-folder' }, [
                                $.make('div', { className: 'NB-folder-icon' })
                            ]),
                            $.make('input', { type: 'text', id: 'NB-add-folder', className: 'NB-add-folder', name: 'url' }),
                            $.make('input', { type: 'submit', value: 'Add folder', className: 'NB-add-folder-submit NB-modal-submit-green' }),
                            $.make('div', { className: 'NB-error' })
                        ])
                    ])
                ]),
                // $.make('div', { className: 'NB-fieldset-divider' }, [
                //     'Google Reader and OPML'
                // ]),
                $.make('div', { className: 'NB-fieldset NB-anonymous-ok NB-modal-submit' }, [
                    $.make('h5', [
                        'Import feeds'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('a', { href: NEWSBLUR.URLs['google-reader-authorize'], className: 'NB-google-reader-oauth NB-modal-submit-green NB-modal-submit-button' }, [
                            'Import from Google Reader',
                            $.make('img', { className: 'NB-add-google-reader-arrow', src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/arrow_right.png' })
                        ]),
                        (this.model.feeds.length && $.make('div', { className: 'NB-add-danger' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/server_go.png' }),
                            'This will erase all existing feeds and folders.'
                        ]))
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset NB-add-opml NB-modal-submit' }, [
                    $.make('h5', [
                        'Upload OPML',
                        $.make('a', { className: 'NB-right NB-splash-link', href: NEWSBLUR.URLs['opml-export'] }, 'Export OPML')
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('form', { method: 'post', enctype: 'multipart/form-data', className: 'NB-add-form' }, [
                            $.make('div', { className: 'NB-loading' }),
                            $.make('input', { type: 'file', name: 'file', id: 'opml_file_input' }),
                            $.make('input', { type: 'submit', className: 'NB-add-opml-button NB-modal-submit-green', value: 'Upload OPML File' }).click(function(e) {
                                e.preventDefault();
                                self.handle_opml_upload();
                                return false;
                            })
                        ]),
                        (this.model.feeds.length && $.make('div', { className: 'NB-add-danger' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/server_go.png' }),
                            'This will erase all existing feeds and folders.'
                        ])),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ])
        ]);
        
        if (NEWSBLUR.Globals.is_anonymous) {
            this.$modal.addClass('NB-signed-out');
        }
    },
    
    make_folders: function() {
        var folders = this.model.get_folders();
        var $options = $.make('select', { className: 'NB-folders'});
        
        var $option = $.make('option', { value: '' }, "Top Level");
        $options.append($option);

        $options = this.make_folder_options($options, folders, '-');
        
        return $options;
    },

    make_folder_options: function($options, items, depth) {
        for (var i in items) {
            var item = items[i];
            if (typeof item == "object") {
                for (var o in item) {
                    var folder = item[o];
                    var $option = $.make('option', { value: o }, depth + ' ' + o);
                    $options.append($option);
                    $options = this.make_folder_options($options, folder, depth+'-');
                }
            }
        }
    
        return $options;
    },

    open_modal: function() {
        var self = this;
        
        this.$modal.modal({
            'minWidth': 600,
            'maxWidth': 600,
            'overlayClose': true,
            'autoResize': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200, function() {
                        self.focus_add_feed();
                    });
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
    
    focus_add_feed: function() {
        var $add = $('.NB-add-url', this.$modal);
        if (!NEWSBLUR.Globals.is_anonymous) {
            _.delay(function() {
                $add.focus();
            }, 200);
        }
    },
    
    setup_autocomplete: function() {
        var self = this;
        var $add = $('.NB-add-url', this.$modal);
        
        $add.autocomplete({
            minLength: 1,
            source: '/rss_feeds/feed_autocomplete',
            focus: function(e, ui) {
                $add.val(ui.item.value);
                return false;
            },
            select: function(e, ui) {
                $add.val(ui.item.value);
                self.save_add_url();
                return false;
            }
        }).data("autocomplete")._renderItem = function(ul, item) {
            return $.make('li', [
                $.make('a', [
                    $.make('div', { className: 'NB-add-autocomplete-subscribers'}, item.num_subscribers + Inflector.pluralize(' subscriber', item.num_subscribers)),
                    $.make('div', { className: 'NB-add-autocomplete-title'}, item.label),
                    $.make('div', { className: 'NB-add-autocomplete-address'}, item.value)
                ])
            ]).data("item.autocomplete", item).appendTo(ul);
        };
    },
    
    handle_keystrokes: function() {
        var self = this;
        
        $('.NB-add-url', this.$modal).bind('keyup', 'return', function(e) {
            e.preventDefault();
            self.save_add_url();
        });  
        
        $('.NB-add-folder', this.$modal).bind('keyup', 'return', function(e) {
            e.preventDefault();
            self.save_add_folder();
        });  
    },
        
    // ========
    // = OPML =
    // ========
        
    handle_opml_upload: function() {
        var self = this;
        var $loading = $('.NB-fieldset.NB-add-opml .NB-loading');
        $loading.addClass('NB-active');

        if (NEWSBLUR.Globals.is_anonymous) {
            var $error = $('.NB-error', '.NB-fieldset.NB-add-opml');
            $error.text("Please create an account. Not much to do without an account.");
            $error.slideDown(300);
            $loading.removeClass('NB-active');
            return false;
        }

        // NEWSBLUR.log(['Uploading']);
        $.ajaxFileUpload({
            url: NEWSBLUR.URLs['opml-upload'], 
            secureuri: false,
            fileElementId: 'opml_file_input',
            dataType: 'text',
            success: function (data, status)
            {
                $loading.removeClass('NB-active');
                NEWSBLUR.reader.load_feeds();
                $.modal.close();
            },
            error: function (data, status, e)
            {
                $loading.removeClass('NB-active');
                NEWSBLUR.log(['Error', data, status, e]);
            }
        });
        
        return false;
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-add-url-submit' }, function($t, $p) {
            e.preventDefault();
            
            self.save_add_url();
        });
        
        $.targetIs(e, { tagSelector: '.NB-add-folder-submit' }, function($t, $p) {
            e.preventDefault();
            
            self.save_add_folder();
        });        
        
    },
    
    save_add_url: function() {
        var $error = $('.NB-error', '.NB-fieldset.NB-add-add-url');
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-url');
        
        var url = $('.NB-add-url').val();
        var folder = $('.NB-add-url').parents('.NB-fieldset').find('.NB-folders').val();
            
        $error.slideUp(300);
        $loading.addClass('NB-active');

        this.model.save_add_url(url, folder, $.rescope(this.post_save_add_url, this));
    },
    
    post_save_add_url: function(e, data) {
        NEWSBLUR.log(['Data', data]);
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-url');
        $loading.removeClass('NB-active');
        
        if (data.code > 0) {
            NEWSBLUR.reader.load_feeds();
            NEWSBLUR.reader.handle_mouse_indicator_hover();
            $.modal.close();
        } else {
            var $error = $('.NB-error', '.NB-fieldset.NB-add-add-url');
            $error.text(data.message);
            $error.slideDown(300);
        }
    },
    
    save_add_folder: function() {
        var $error = $('.NB-error', '.NB-fieldset.NB-add-add-folder');
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-folder');
        
        var folder = $('.NB-add-folder').val();
        var parent_folder = $('.NB-add-folder').parents('.NB-fieldset').find('.NB-folders').val();
            
        $error.slideUp(300);
        $loading.addClass('NB-active');

        this.model.save_add_folder(folder, parent_folder, $.rescope(this.post_save_add_folder, this));
    },
    
    post_save_add_folder: function(e, data) {
        NEWSBLUR.log(['Data', data]);
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-folder');
        $loading.removeClass('NB-active');
        
        if (data.code > 0) {
            NEWSBLUR.reader.load_feeds();
            _.defer(function() {
              NEWSBLUR.reader.open_add_feed_modal();
            });
        } else {
            var $error = $('.NB-error', '.NB-fieldset.NB-add-add-folder');
            $error.text(data.message);
            $error.slideDown(300);
        }
    }
    
};