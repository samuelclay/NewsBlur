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
                        '添加订阅'
                    ]),
                    $.make('div', [
                        $.make('input', { type: 'text', id: 'NB-add-url', className: 'NB-input NB-add-url', name: 'url', value: self.options.url })
                    ]),
                    $.make('div', { className: 'NB-group NB-add-site' }, [
                        NEWSBLUR.utils.make_folders(this.model, this.options.folder_title),
                        $.make('div', { className: 'NB-add-folder-icon' }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-add-url-submit' }, '添加站点'),
                        $.make('div', { className: 'NB-loading' })
                    ]),
                    $.make('div', { className: "NB-add-folder NB-hidden" }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-add-folder-submit' }, '添加文件夹'),
                        $.make('div', { className: 'NB-loading' }),
                        $.make('input', { type: 'text', id: 'NB-add-folder', className: 'NB-input NB-add-folder-input', name: 'new_folder_name', placeholder: "新文件夹名..." })
                    ]),
                    $.make('div', { className: 'NB-group NB-error' }, [
                        $.make('div', { className: 'NB-error-message' })
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset NB-anonymous-ok NB-modal-submit NB-hidden' }, [
                    $.make('h5', [
                        '导入订阅'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', { className: 'NB-add-import-button NB-modal-submit-green NB-modal-submit-button' }, [
                            '从 Google Reader 导入或上传 OPML 文件',
                            $.make('img', { className: 'NB-add-google-reader-arrow', src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/arrow_right.png' })
                        ]),
                        $.make('div', { className: 'NB-add-danger' }, (NEWSBLUR.Globals.is_authenticated && _.size(this.model.feeds) > 0 && [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL']+'img/icons/silk/server_go.png' }),
                            '这将覆盖所有已存在的订阅和文件夹。'
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
        $submit.addClass('NB-disabled').text('正在添加...');
        
        this.model.save_add_url(url, folder, $.rescope(this.post_save_add_url, this), $.rescope(this.error, this));
    },
    
    post_save_add_url: function(e, data) {
        NEWSBLUR.log(['Data', data]);
        var $submit = this.$('.NB-add-url-submit');
        var $loading = this.$('.NB-add-site .NB-loading');
        $loading.removeClass('NB-active');
        
        if (data.code > 0) {
            NEWSBLUR.assets.load_feeds(function() {
                if (data.feed) {
                    NEWSBLUR.reader.open_feed(data.feed.id);
                }
            });
            NEWSBLUR.reader.load_recommended_feed();
            NEWSBLUR.reader.handle_mouse_indicator_hover();
            $submit.text('已添加!');
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
        $(".NB-error-message", $error).text(data.message || "抱歉，抓取此 URL 时发生了未知错误。");
        $error.slideDown(300);
        $submit.text('添加订阅');
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
        $submit.addClass('NB-disabled').text('正在添加...');

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
            $submit.text('已添加!');
            NEWSBLUR.assets.load_feeds(_.bind(function() {
                var $folders = NEWSBLUR.utils.make_folders(this.model, $folder.val());
                this.$(".NB-folders").replaceWith($folders);
                this.open_add_folder();
                $submit.text('添加文件夹');
                $folder.val('');
                this.$('.NB-add-url').focus();
            }, this));
        } else {
            $(".NB-error-message", $error).text(data.message);
            $error.slideDown(300);
            $submit.text('添加文件夹');
        }
    }
    
});