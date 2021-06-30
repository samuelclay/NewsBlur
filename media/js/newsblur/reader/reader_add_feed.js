NEWSBLUR.ReaderAddFeed = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-add-popover",
    
    options: {
        'width': 380,
        'anchor': function() {
            return NEWSBLUR.reader.$s.$add_button;
        },
        'placement': 'top -left',
        offset: {
            top: 6,
            left: 1
        },
        'onOpen': _.bind(function() {
            this.focus_add_feed();
        }, this)
    },
    
    events: {
        "click .NB-modal-cancel"        : "close",
        "click .NB-add-url-submit"      : "save_add_url",
        "click .NB-add-folder-icon"     : "open_add_folder",
        "click .NB-add-folder-submit"   : "save_add_folder",
        "click .NB-add-import-button"   : "close_and_open_import",
        "focus .NB-add-url"             : "handle_focus_add_site",
        "blur .NB-add-url"              : "handle_blur_add_site"
    },
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this);
        this.model = NEWSBLUR.assets;
        this.render();
        this.handle_keystrokes();
        this.setup_autocomplete();
        
        // this.setup_chosen();
        this.focus_add_feed();
    },

    on_show: function() {
        this.options.onOpen();
    },
    
    on_hide: function() {
        
    },
    
    render: function() {
        var self = this;

        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        
        this.$el.html($.make('div', { className: 'NB-add' }, [
            $.make('div', { className: 'NB-add-form' }, [
                $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                    $.make('h3', { className: 'NB-module-content-header' }, [
                        'Add a new site'
                    ]),
                    $.make('div', [
                        $.make('input', { type: 'text', id: 'NB-add-url', className: 'NB-input NB-add-url', name: 'url', value: self.options.url })
                    ]),
                    $.make('div', { className: 'NB-group NB-add-site' }, [
                        NEWSBLUR.utils.make_folders(this.options.folder_title),
                        $.make('div', { className: 'NB-add-folder-icon', title: "Add folder", role: "button" }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-add-url-submit' }, 'Add site'),
                        $.make('div', { className: 'NB-loading' })
                    ]),
                    $.make('div', { className: "NB-add-folder NB-hidden" }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-add-folder-submit' }, 'Add folder'),
                        $.make('div', { className: 'NB-loading' }),
                        $.make('input', { type: 'text', id: 'NB-add-folder', className: 'NB-input NB-add-folder-input', name: 'new_folder_name', placeholder: "New folder name..." })
                    ]),
                    $.make('div', { className: 'NB-group NB-error' }, [
                        $.make('div', { className: 'NB-error-message' })
                    ])
                ]),
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
                    this.$('.NB-add-folder-input') :
                    this.$('.NB-add-url');
        if (!NEWSBLUR.Globals.is_anonymous) {
            _.delay(_.bind(function() {
                if (this.options.init_folder) {
                    this.open_add_folder();
                }
                $add.focus();
            }, this), 200);
        }
    },
    
    setup_autocomplete: function() {
        var self = this;
        var $add = this.$('.NB-add-url');
        
        $add.autocomplete({
            minLength: 1,
            appendTo: ".NB-add-form",
            source: '/rss_feeds/feed_autocomplete',
            position: {
                my: "left bottom",
                at: "left top",
                collision: "none"
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
        }).data("ui-autocomplete")._renderItem = function(ul, item) {
            var feed = new NEWSBLUR.Models.Feed(item);
            return $.make('li', [
                $.make('a', [
                    $.make('div', { className: 'NB-add-autocomplete-subscribers'}, Inflector.pluralize(' subscriber', item.num_subscribers, true)),
                    $.make('img', { className: 'NB-add-autocomplete-favicon', src: $.favicon(feed) }),
                    $.make('div', { className: 'NB-add-autocomplete-title'}, item.label),
                    $.make('div', { className: 'NB-add-autocomplete-address'}, item.value)
                ])
            ]).data("ui-autocomplete-item", item).prependTo(ul);
        };
        $add.data("ui-autocomplete")._resizeMenu = function () {
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
        
        this.$('.NB-add-folder-input').bind('keyup', 'return', function(e) {
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
        var $submit = this.$('.NB-add-url-submit');
        var $error = this.$('.NB-error');
        var $loading = this.$('.NB-add-site .NB-loading');
        
        var url = this.$('.NB-add-url').val();
        var folder = this.$('.NB-folders').val();
            
        $error.slideUp(300);
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').text('Adding...');
        
        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        this.model.save_add_url(url, folder, $.rescope(this.post_save_add_url, this), $.rescope(this.error, this));
    },
    
    post_save_add_url: function(e, data) {
        NEWSBLUR.log(['Data', data]);
        var $submit = this.$('.NB-add-url-submit');
        var $loading = this.$('.NB-add-site .NB-loading');
        $loading.removeClass('NB-active');
        NEWSBLUR.reader.flags['reloading_feeds'] = false;
        
        if (data.code > 0) {
            NEWSBLUR.assets.load_feeds(function() {
                if (data.feed) {
                    NEWSBLUR.reader.open_feed(data.feed.id);
                }
            });
            NEWSBLUR.reader.load_recommended_feed();
            NEWSBLUR.reader.handle_mouse_indicator_hover();
            $submit.text('Added!');
            this.close();
            this.model.preference('has_setup_feeds', true);
            NEWSBLUR.reader.check_hide_getting_started();
        } else {
            this.error(data);
            $submit.removeClass('NB-disabled');
        }
    },
    
    error: function(data) {
        var $submit = this.$('.NB-add-url-submit');
        var $error = this.$('.NB-error');

        $(".NB-error-message", $error).text(data.message || "Oh no, there was a problem grabbing that URL and there's no good explanation for what happened.");
        $error.slideDown(300);
        $submit.text('Add Site');
        NEWSBLUR.reader.flags['reloading_feeds'] = false;
    },
    
    open_add_folder: function() {
        var $folder = this.$(".NB-add-folder");
        var $icon = this.$(".NB-add-folder-icon");
        
        if (this._open_folder) {
            $folder.slideUp(300);
            $icon.removeClass('NB-active');
            this._open_folder = false;
        } else {
            this._open_folder = true;
            $icon.addClass('NB-active');
            $folder.slideDown(300);
        }
    },
    
    save_add_folder: function() {
        var $submit = this.$('.NB-add-folder-submit');
        var $error = this.$('.NB-error');
        var $loading = this.$('.NB-add-folder .NB-loading');
        
        var folder = $('.NB-add-folder-input').val();
        var parent_folder = this.$('.NB-folders').val();
            
        $error.slideUp(300);
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').text('Adding...');

        this.model.save_add_folder(folder, parent_folder, $.rescope(this.post_save_add_folder, this));
    },
    
    post_save_add_folder: function(e, data) {
        var $submit = this.$('.NB-add-folder-submit');
        var $error = this.$('.NB-error');
        var $loading = this.$('.NB-add-folder .NB-loading');
        var $folder = $('.NB-add-folder-input');
        $loading.removeClass('NB-active');
        $submit.removeClass('NB-disabled');
        
        if (data.code > 0) {
            $submit.text('Added!');
            NEWSBLUR.assets.load_feeds(_.bind(function() {
                var $folders = NEWSBLUR.utils.make_folders($folder.val());
                this.$(".NB-folders").replaceWith($folders);
                this.open_add_folder();
                $submit.text('Add Folder');
                $folder.val('');
                this.$('.NB-add-url').focus();
            }, this));
        } else {
            $(".NB-error-message", $error).text(data.message);
            $error.slideDown(300);
            $submit.text('Add Folder');
        }
    }
    
});
