NEWSBLUR.ReaderTagSettings = function (feed_id, options) {
    var defaults = {
        'onOpen': function () {
            $(window).trigger('resize.simplemodal');
        },
        'width': 560
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.feed_id = feed_id;
    // Extract tag name from feed_id (format: 'starred:tagname')
    this.tag_name = feed_id.replace('starred:', '');
    this.feed = this.model.get_feed(feed_id);

    this.runner();
};

NEWSBLUR.ReaderTagSettings.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderTagSettings.prototype.constructor = NEWSBLUR.ReaderTagSettings;

_.extend(NEWSBLUR.ReaderTagSettings.prototype, {

    runner: function () {
        this.make_modal();
        this.initialize_settings();
        this.handle_cancel();
        this.open_modal();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },

    initialize_settings: function () {
        var view_setting = this.model.view_setting(this.feed_id, 'view');
        var story_layout = this.model.view_setting(this.feed_id, 'layout');

        // Set active state on segmented controls
        $('.NB-view-setting-option[data-value="' + view_setting + '"]', this.$modal).addClass('NB-active');
        $('.NB-layout-setting-option[data-value="' + story_layout + '"]', this.$modal).addClass('NB-active');
    },

    make_modal: function () {
        var self = this;
        var rss_url = this.feed ? this.feed.get('feed_address') : '';

        this.$modal = $.make('div', { className: 'NB-modal-tag-settings NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Tag Settings'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/tag.svg' }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.tag_name)
                ])
            ]),
            // View Settings
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', [
                    $.make('span', { className: 'NB-exception-option-status' }),
                    'View settings'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    // Reading view row
                    $.make('div', { className: 'NB-tag-setting-row' }, [
                        $.make('div', { className: 'NB-tag-setting-label' }, 'Reading view'),
                        $.make('ul', { className: 'segmented-control NB-tag-view-control' }, [
                            $.make('li', { className: 'NB-view-setting-option', 'data-value': 'feed' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/content-view-feed.svg' }),
                                $.make('span', 'Feed')
                            ]),
                            $.make('li', { className: 'NB-view-setting-option', 'data-value': 'text' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/content-view-text.svg' }),
                                $.make('span', 'Text')
                            ]),
                            $.make('li', { className: 'NB-view-setting-option', 'data-value': 'story' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/content-view-story.svg' }),
                                $.make('span', 'Story')
                            ])
                        ])
                    ]),
                    // Story layout row
                    $.make('div', { className: 'NB-tag-setting-row' }, [
                        $.make('div', { className: 'NB-tag-setting-label' }, 'Story layout'),
                        $.make('ul', { className: 'segmented-control NB-tag-layout-control' }, [
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'full' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-full.svg' }),
                                $.make('span', 'Full')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'split' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-split.svg' }),
                                $.make('span', 'Split')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'list' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-list.svg' }),
                                $.make('span', 'List')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'grid' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-grid.svg' }),
                                $.make('span', 'Grid')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'magazine' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-magazine.svg' }),
                                $.make('span', 'Magazine')
                            ])
                        ])
                    ])
                ])
            ]),
            // RSS Feed Address
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', 'Tag RSS Feed'),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-tag-rss-wrapper' }, [
                        $.make('input', {
                            type: 'text',
                            id: 'NB-tag-rss-url',
                            className: 'NB-input NB-tag-rss-input',
                            name: 'tag_rss_url',
                            value: rss_url || '',
                            readonly: 'readonly'
                        }),
                        $.make('div', { className: 'NB-tag-rss-copy NB-modal-submit-button NB-modal-submit-grey' }, 'Copy')
                    ]),
                    (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-premium-only' }, [
                        $.make('div', { className: 'NB-premium-only-text' }, [
                            'RSS feeds for saved story tags is a ',
                            $.make('a', { href: '#', className: 'NB-premium-only-link NB-splash-link' }, 'premium feature'),
                            '.'
                        ])
                    ]))
                ])
            ]),
            // Rename Tag
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', 'Rename Tag'),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-tag-rename-wrapper' }, [
                        $.make('input', {
                            type: 'text',
                            className: 'NB-input NB-tag-rename-input',
                            name: 'new_tag_name',
                            value: this.tag_name,
                            placeholder: 'New tag name'
                        }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-tag-rename-save' }, 'Rename')
                    ]),
                    $.make('div', { className: 'NB-tag-rename-error NB-error' })
                ])
            ]),
            // Delete Tag
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('h5', 'Delete Tag'),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-tag-delete-info' }, [
                        'This removes the tag from all saved stories. Stories will remain saved without this tag.'
                    ]),
                    $.make('div', { className: 'NB-tag-delete-wrapper' }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-red NB-tag-delete' }, 'Delete Tag'),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-red NB-tag-delete-confirm' }, 'Yes, delete it')
                    ]),
                    $.make('div', { className: 'NB-tag-delete-error NB-error' })
                ])
            ])
        ]);
    },

    handle_cancel: function () {
        var $cancel = $('.NB-modal-cancel', this.$modal);

        $cancel.click(function (e) {
            e.preventDefault();
            $.modal.close();
        });
    },

    animate_saved: function () {
        var $status = $('.NB-exception-option-status', this.$modal);
        $status.text('Saved').addClass('NB-visible');
        _.delay(function () {
            $status.removeClass('NB-visible');
        }, 1200);
    },

    copy_rss_url: function () {
        var $input = $('#NB-tag-rss-url', this.$modal);
        var $button = $('.NB-tag-rss-copy', this.$modal);

        $input[0].select();
        document.execCommand('copy');

        $button.text('Copied!');
        _.delay(function () {
            $button.text('Copy');
        }, 1500);
    },

    rename_tag: function () {
        var self = this;
        var new_tag_name = $('input[name=new_tag_name]', this.$modal).val().trim();
        var $button = $('.NB-tag-rename-save', this.$modal);
        var $error = $('.NB-tag-rename-error', this.$modal);

        $error.hide().html('');

        if (!new_tag_name) {
            $error.html('Please enter a tag name.').show();
            return;
        }

        if (new_tag_name.length > 128) {
            $error.html('Tag name must be 128 characters or less.').show();
            return;
        }

        $button.addClass('NB-disabled').text('Renaming...');

        this.model.rename_starred_tag(this.tag_name, new_tag_name, function (data) {
            if (data.code < 0) {
                $button.removeClass('NB-disabled').text('Rename');
                $error.html(data.message || 'Failed to rename tag.').show();
                return;
            }

            // Update the sidebar with new starred counts
            if (data.starred_counts) {
                self.model.starred_feeds.reset(data.starred_counts, { parse: true });
            }

            $.modal.close();

            // Navigate to the renamed tag
            NEWSBLUR.reader.open_starred_stories({ tag: new_tag_name });
        }, function () {
            $button.removeClass('NB-disabled').text('Rename');
            $error.html('An error occurred. Please try again.').show();
        });
    },

    delete_tag: function () {
        var self = this;
        var $button = $('.NB-tag-delete-confirm', this.$modal);
        var $error = $('.NB-tag-delete-error', this.$modal);

        $error.hide().html('');
        $button.addClass('NB-disabled').text('Deleting...');

        this.model.delete_starred_tag(this.tag_name, function (data) {
            if (data.code < 0) {
                $button.removeClass('NB-disabled').text('Yes, delete it');
                $error.html(data.message || 'Failed to delete tag.').show();
                return;
            }

            // Update the sidebar with new starred counts
            if (data.starred_counts) {
                self.model.starred_feeds.reset(data.starred_counts, { parse: true });
            }

            $.modal.close();
        }, function () {
            $button.removeClass('NB-disabled').text('Yes, delete it');
            $error.html('An error occurred. Please try again.').show();
        });
    },

    show_delete_confirm: function () {
        var $delete_button = $('.NB-tag-delete', this.$modal);
        var $confirm_button = $('.NB-tag-delete-confirm', this.$modal);

        $delete_button.hide();
        $confirm_button.show();
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-view-setting-option' }, function ($t, $p) {
            e.preventDefault();
            var value = $t.data('value');
            $('.NB-view-setting-option', self.$modal).removeClass('NB-active');
            $t.addClass('NB-active');
            NEWSBLUR.assets.view_setting(self.feed_id, { 'view': value });
            self.animate_saved();
        });

        $.targetIs(e, { tagSelector: '.NB-layout-setting-option' }, function ($t, $p) {
            e.preventDefault();
            var value = $t.data('value');
            $('.NB-layout-setting-option', self.$modal).removeClass('NB-active');
            $t.addClass('NB-active');
            NEWSBLUR.assets.view_setting(self.feed_id, { 'layout': value });
            self.animate_saved();
        });

        $.targetIs(e, { tagSelector: '.NB-tag-rss-copy' }, function ($t, $p) {
            e.preventDefault();
            self.copy_rss_url();
        });

        $.targetIs(e, { tagSelector: '.NB-tag-rename-save' }, function ($t, $p) {
            e.preventDefault();
            if (!$t.hasClass('NB-disabled')) {
                self.rename_tag();
            }
        });

        $.targetIs(e, { tagSelector: '.NB-tag-delete' }, function ($t, $p) {
            e.preventDefault();
            if (!$t.hasClass('NB-disabled')) {
                self.show_delete_confirm();
            }
        });

        $.targetIs(e, { tagSelector: '.NB-tag-delete-confirm' }, function ($t, $p) {
            e.preventDefault();
            if (!$t.hasClass('NB-disabled')) {
                self.delete_tag();
            }
        });

        $.targetIs(e, { tagSelector: '.NB-premium-only-link' }, function ($t, $p) {
            e.preventDefault();
            self.close(function () {
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
        });
    }

});
