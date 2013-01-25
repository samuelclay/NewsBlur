NEWSBLUR.ReaderAddFeed = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-add-popover",
    
    options: {
        'anchor': function() {
            return NEWSBLUR.reader.$s.$add_button;
        },
        'placement': 'top -left',
        offset: {
            top: -6,
            left: 1
        },
        'onOpen': _.bind(function() {
            this.focus_add_feed();
        }, this)
    },
    
    events: {
        "click .NB-modal-cancel"        : "close",
        "click .NB-add-url-submit"      : "save_add_url",
        "click .NB-add-folder-submit"   : "save_add_folder",
        "click .NB-add-import-button"   : "close_and_open_import",
        "focus .NB-add-url"             : "handle_focus_add_site",
        "blur .NB-add-url"              : "handle_blur_add_site"
    },
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        this.model = NEWSBLUR.assets;
        this.make_modal();
        this.handle_keystrokes();
        this.setup_autocomplete();
        
        NEWSBLUR.ReaderPopover.prototype.initialize.apply(this);

        // this.setup_chosen();
        this.focus_add_feed();
    },

    on_show: function() {
        this.options.onOpen();
    },
    
    on_hide: function() {
        
    },
    
    make_modal: function() {
        var self = this;
        
        this.$el.html($.make('div', { className: 'NB-add' }, [
            $.make('div', { className: 'NB-add-form' }, [
                $.make('div', { className: 'NB-fieldset NB-add-add-url NB-modal-submit' }, [
                    $.make('h5', [
                        'Add a new site'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', [
                            $.make('div', { className: 'NB-loading' }),
                            $.make('label', { 'for': 'NB-add-url' }, 'Website or RSS: '),
                            $.make('input', { type: 'text', id: 'NB-add-url', className: 'NB-input NB-add-url', name: 'url', value: self.options.url }),
                            $.make('input', { type: 'submit', value: 'Add site', className: 'NB-modal-submit-green NB-add-url-submit' }),
                            $.make('div', { className: 'NB-error' })
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset NB-add-add-folder NB-modal-submit' }, [
                    $.make('div', { className: 'NB-add-folders' }, NEWSBLUR.utils.make_folders(this.model, this.options.folder_title)),
                    $.make('div', { className: 'NB-fieldset-fields NB-hidden' }, [
                        $.make('div', [
                            $.make('div', { className: 'NB-loading' }),
                            $.make('label', { 'for': 'NB-add-folder' }, [
                                $.make('div', { className: 'NB-folder-icon' })
                            ]),
                            $.make('input', { type: 'text', id: 'NB-add-folder', className: 'NB-input NB-add-folder', name: 'url' }),
                            $.make('input', { type: 'submit', value: 'Add folder', className: 'NB-add-folder-submit NB-modal-submit-green' }),
                            $.make('div', { className: 'NB-error' })
                        ])
                    ])
                ]),
                // $.make('div', { className: 'NB-fieldset-divider' }, [
                //     'Google Reader and OPML'
                // ]),
                $.make('div', { className: 'NB-fieldset NB-anonymous-ok NB-modal-submit NB-hidden' }, [
                    $.make('h5', [
                        'Import feeds'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', { className: 'NB-add-import-button NB-modal-submit-green NB-modal-submit-button' }, [
                            'Import from Google Reader or upload OPML',
                            $.make('img', { className: 'NB-add-google-reader-arrow', src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/arrow_right.png' })
                        ]),
                        $.make('div', { className: 'NB-add-danger' }, (NEWSBLUR.Globals.is_authenticated && _.size(this.model.feeds) > 0 && [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/server_go.png' }),
                            'This will erase all existing feeds and folders.'
                        ]))
                    ])
                ])
            ])
        ]));
        
        if (NEWSBLUR.Globals.is_anonymous) {
            this.$el.addClass('NB-signed-out');
        }
        
        return this;
    },
    
    focus_add_feed: function() {
        var $add = this.options.init_folder ? 
                    this.$('.NB-add-folder') :
                    this.$('.NB-add-url');
        if (!NEWSBLUR.Globals.is_anonymous) {
            _.delay(function() {
                $add.focus();
            }, 200);
        }
    },
    
    setup_autocomplete: function() {
        var self = this;
        var $add = this.$('.NB-add-url');
        
        $add.autocomplete({
            minLength: 1,
            source: '/rss_feeds/feed_autocomplete',
            focus: function(e, ui) {
                $add.val(ui.item.value);
                return false;
            },
            select: function(e, ui) {
                $add.val(ui.item.value);
                // self.save_add_url();
                return false;
            },
            search: function(e, ui) {
            },
            open: function(e, ui) {
                if (!$add.is(":focus")) {
                    e.preventDefault();
                    $add.autocomplete('close');
                    return false;
                }
            },
            close: function(e, ui) {
            },
            change: function(e, ui) {
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
        $add.data("autocomplete")._resizeMenu = function () {
            var ul = this.menu.element;
            ul.outerWidth(this.element.outerWidth());
        };
    },
    
    handle_focus_add_site: function() {
        var $add = this.$('.NB-add-url');
        $add.autocomplete('search');
    },
    
    handle_blur_add_site: function() {
        var $add = this.$('.NB-add-url');
        $add.autocomplete('close');
    },
    
    setup_chosen: function() {
        var $select = this.$('select');
        $select.chosen();
    },
    
    handle_keystrokes: function() {
        var self = this;
        
        this.$('.NB-add-url').bind('keyup', 'return', function(e) {
            e.preventDefault();
            self.save_add_url();
        });  
        
        this.$('.NB-add-folder').bind('keyup', 'return', function(e) {
            e.preventDefault();
            self.save_add_folder();
        });  
    },

    close_and_open_import: function() {
        this.close(function() {
            NEWSBLUR.reader.open_intro_modal({
                'page_number': 2,
                'force_import': true
            });
        });
    },
    
    // ===========
    // = Actions =
    // ===========
    
    save_add_url: function() {
        var $submit = this.$('.NB-add-add-url input[type=submit]');
        var $error = $('.NB-error', '.NB-fieldset.NB-add-add-url');
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-url');
        
        var url = $('.NB-add-url').val();
        var folder = $('.NB-add-url').parents('.NB-fieldset').find('.NB-folders').val();
            
        $error.slideUp(300);
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').val('Adding...');
        
        this.model.save_add_url(url, folder, $.rescope(this.post_save_add_url, this), $.rescope(this.error, this));
    },
    
    post_save_add_url: function(e, data) {
        NEWSBLUR.log(['Data', data]);
        var $submit = this.$('.NB-add-add-url input[type=submit]');
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-url');
        $loading.removeClass('NB-active');
        $submit.removeClass('NB-disabled');
        
        if (data.code > 0) {
            NEWSBLUR.assets.load_feeds(function() {
                if (data.feed) {
                    NEWSBLUR.reader.open_feed(data.feed.id);
                }
            });
            NEWSBLUR.reader.load_recommended_feed();
            NEWSBLUR.reader.handle_mouse_indicator_hover();
            $.modal.close();
            $submit.val('Added!');
            this.model.preference('has_setup_feeds', true);
            NEWSBLUR.reader.check_hide_getting_started();
        } else {
            this.error(data);
        }
    },
    
    error: function(data) {
        var $submit = this.$('.NB-add-add-url input[type=submit]');
        var $error = $('.NB-error', '.NB-fieldset.NB-add-add-url');
        $error.text(data.message || "Oh no, there was a problem grabbing that URL and there's no good explanation for what happened.");
        $error.slideDown(300);
        $submit.val('Add Site');
    },
    
    save_add_folder: function() {
        var $submit = this.$('.NB-add-add-folder input[type=submit]');
        var $error = $('.NB-error', '.NB-fieldset.NB-add-add-folder');
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-folder');
        
        var folder = $('.NB-add-folder').val();
        var parent_folder = $('.NB-add-folder').parents('.NB-fieldset').find('.NB-folders').val();
            
        $error.slideUp(300);
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').val('Adding...');

        this.model.save_add_folder(folder, parent_folder, $.rescope(this.post_save_add_folder, this));
    },
    
    post_save_add_folder: function(e, data) {
        var $submit = this.$('.NB-add-add-folder input[type=submit]');
        var $loading = $('.NB-loading', '.NB-fieldset.NB-add-add-folder');
        $loading.removeClass('NB-active');
        $submit.removeClass('NB-disabled');
        
        if (data.code > 0) {
            NEWSBLUR.assets.load_feeds();
            _.defer(_.bind(function() {
                this.close();
            }, this));
            $submit.val('Added!');
        } else {
            var $error = $('.NB-error', '.NB-fieldset.NB-add-add-folder');
            $error.text(data.message);
            $error.slideDown(300);
            $submit.val('Add Folder');
        }
    }
    
});