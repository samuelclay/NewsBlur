NEWSBLUR.ReaderFeedchooser = function (options) {
    options = options || {};
    var defaults = {
        'width': 700,
        'height': 700,
        'onOpen': _.bind(function () {
            this.resize_modal();
        }, this),
        'onClose': _.bind(function () {
            if (!this.flags['has_saved'] && !this.model.flags['has_chosen_feeds']) {
                NEWSBLUR.reader.show_feed_chooser_button();
            }
            dialog.data.hide().empty().remove();
            dialog.container.hide().empty().remove();
            dialog.overlay.fadeOut(200, function () {
                dialog.overlay.empty().remove();
                $.modal.close(callback);
            });
            $('.NB-modal-holder').empty().remove();
        }, this)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderFeedchooser.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderFeedchooser.prototype.constructor = NEWSBLUR.ReaderFeedchooser;

_.extend(NEWSBLUR.ReaderFeedchooser.prototype, {

    runner: function () {
        var self = this;
        this.start = new Date();
        this.MAX_FEEDS = 64;

        NEWSBLUR.assets.feeds.each(function (feed) {
            self.add_feed_to_decline(feed);
        });

        this.make_modal();
        this.initial_load_feeds();

        _.defer(_.bind(function () { this.update_counts(true); }, this));

        this.flags = {
            'has_saved': false
        };
        this.open_modal();

        // Insert the feedlist after the modal is fully rendered
        // Using setTimeout to ensure SimpleModal has finished cloning and inserting elements
        setTimeout(_.bind(this.insert_feedlist, this), 300);

        this.$modal.bind('mousedown', $.rescope(this.handle_mousedown, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },

    make_modal: function () {
        var self = this;

        // Create the feed list first
        this.feedlist = new NEWSBLUR.Views.FeedList({
            feed_chooser: true,
            sorting: this.options.sorting
        }).make_feeds();

        var $feeds = this.feedlist.$el;
        this.feed_count = _.unique(NEWSBLUR.assets.folders.feed_ids_in_folder({ include_inactive: true })).length;

        if (this.options.resize) {
            $feeds.css({ 'max-height': this.options.resize });
        }
        if ($feeds.data('sortable')) $feeds.data('sortable').disable();

        // Expand collapsed folders
        $('.NB-folder-collapsed', $feeds).css({
            'display': 'block',
            'opacity': 1
        }).removeClass('NB-folder-collapsed');

        // Pretend unfetched feeds are fine
        $('.NB-feed-unfetched', $feeds).removeClass('NB-feed-unfetched');

        // Make sure all folders are visible
        $('.NB-folder.NB-hidden', $feeds).removeClass('NB-hidden');

        NEWSBLUR.assets.folders.sort();

        NEWSBLUR.assets.feeds.off('change:highlighted')
            .on('change:highlighted', _.bind(this.change_selection, this));

        // Create a placeholder for the feed list - $.make() clones elements,
        // so we need to insert the actual feedlist.$el after modal creation
        var $feedsPlaceholder = $.make('div', { className: 'NB-feedchooser-feeds-placeholder' });

        this.$modal = $.make('div', { className: 'NB-modal-feedchooser NB-modal' }, [
            // Upgrade banner for free users
            (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-feedchooser-upgrade-banner' }, [
                $.make('div', { className: 'NB-feedchooser-upgrade-banner-text' }, [
                    $.make('div', { className: 'NB-feedchooser-upgrade-banner-icon' }),
                    'Want unlimited sites? Go Premium'
                ]),
                $.make('div', { className: 'NB-feedchooser-upgrade-banner-price' }, '$36/year'),
                $.make('div', { className: 'NB-feedchooser-upgrade-banner-arrow' })
            ])),
            // Feed chooser content
            $.make('div', { className: 'NB-feedchooser-type NB-feedchooser-left' }, [
                (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-feedchooser-info' }, [
                    $.make('div', { className: 'NB-feedchooser-info-type' }, [
                        'Standard Account',
                        $.make('span', { className: 'NB-feedchooser-subtitle-type-price' }, 'Free'),
                    ]),
                    $.make('h2', { className: 'NB-modal-subtitle' }, [
                        $.make('b', [
                            'You can follow up to ' + this.MAX_FEEDS + ' sites.'
                        ]),
                        $.make('br'),
                        'You can always change these.'
                    ]),
                    $.make('div', { className: 'NB-feedchooser-info-counts' }),
                    $.make('div', { className: 'NB-feedchooser-info-sort' }, 'Auto-Selected By Popularity'),
                    $.make('div', { className: 'NB-feedchooser-info-reset NB-splash-link' }, 'Reset to popular sites')
                ])),
                (NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-feedchooser-info' }, [
                    $.make('h2', { className: 'NB-modal-title' }, [
                        $.make('div', { className: 'NB-icon' }),
                        'Mute sites',
                        $.make('div', { className: 'NB-icon-dropdown' })
                    ]),
                    $.make('div', { className: 'NB-feedchooser-info-reset NB-splash-link' }, 'Turn every site on'),
                    $.make('div', { className: 'NB-feedchooser-info-counts' })
                ])),
                $feedsPlaceholder,
                $.make('form', { className: 'NB-feedchooser-form' }, [
                    $.make('div', { className: 'NB-modal-submit' }, [
                        $.make('input', { type: 'submit', disabled: 'true', className: 'NB-disabled NB-modal-submit-button NB-modal-submit-save NB-modal-submit-green', value: 'Check what you like above...' }),
                        $.make('input', { type: 'submit', className: 'NB-modal-submit-add NB-modal-submit-button NB-modal-submit-green', value: 'First, add sites' })
                    ])
                ]).bind('submit', function (e) {
                    e.preventDefault();
                    return false;
                })
            ])
        ]);

    },

    insert_feedlist: function () {
        // Insert the actual feedlist element into the opened modal
        // This must happen AFTER the modal opens because SimpleModal clones elements
        if (!this.feedlist || !this.feedlist.$el) return;

        var $form = $('.NB-modal-feedchooser .NB-feedchooser-form');
        if (!$form.length) return;

        // Remove the placeholder and any cloned feedlist elements from the DOM
        // (our actual feedlist.$el is not in the DOM yet, so this won't remove it)
        $('.NB-feedchooser-feeds-placeholder').remove();
        $('#NB-feedchooser-feeds').remove();

        // Insert the actual feedlist element before the form
        this.feedlist.$el.insertBefore($form);

        // Set minimum height on the feedlist - resize_modal will shrink it if needed
        this.feedlist.$el.css({ 'min-height': '350px', 'max-height': '500px' });
    },

    resize_modal: function (previous_height) {
        var MIN_FEEDLIST_HEIGHT = 350;
        var content_height = $('.NB-feedchooser-left', this.$modal).height() + 54;
        var container_height = this.$modal.parent().height();
        if (content_height > container_height && previous_height != content_height) {
            var chooser_height = $('#NB-feedchooser-feeds').height();
            var diff = Math.max(4, content_height - container_height);
            var new_height = Math.max(MIN_FEEDLIST_HEIGHT, chooser_height - diff);
            $('#NB-feedchooser-feeds').css({ 'max-height': new_height });
            // Only continue resizing if we haven't hit the minimum
            if (new_height > MIN_FEEDLIST_HEIGHT) {
                _.defer(_.bind(function () { this.resize_modal(content_height); }, this), 1);
            }
        }
    },

    add_feed_to_decline: function (feed, update) {
        feed.highlight_in_all_folders(false, true, { silent: !update });

        if (update) {
            this.update_counts(true);
        }
    },

    add_feed_to_approve: function (feed, update) {
        feed.highlight_in_all_folders(true, false, { silent: false });

        if (update) {
            this.update_counts(true);
        }
    },

    change_selection: function (update) {
        this.update_counts();
    },

    update_counts: function (autoselected) {
        var $count = $('.NB-feedchooser-info-counts');
        var approved = this.feedlist.folder_view.highlighted_count();
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var difference = approved - this.MAX_FEEDS;
        var muted = this.feed_count - approved;

        $count.text(approved + '/' + Inflector.commas(this.feed_count));

        if (NEWSBLUR.Globals.is_premium) {
            $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false);
            if (muted == 0) {
                $submit.val('Enable all ' + Inflector.pluralize('site', this.feed_count, true));
            } else {
                $submit.val('Mute ' + Inflector.pluralize('site', muted, true));
            }
            $count.toggleClass('NB-full', muted == 0);
        } else {
            $count.toggleClass('NB-full', approved == this.MAX_FEEDS);
            $count.toggleClass('NB-error', approved > this.MAX_FEEDS);

            if (!autoselected) {
                this.hide_autoselected_label();
            }
            if (approved > this.MAX_FEEDS) {
                $submit.addClass('NB-disabled').addClass('NB-modal-submit-grey').attr('disabled', true).val('Too many sites! Deselect ' + (
                    difference == 1 ?
                        '1 site...' :
                        difference + ' sites...'
                ));
            } else {
                $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false).val('Turn on these ' + approved + ' sites, please');
            }
        }
    },

    initial_load_feeds: function (reset) {
        var start = new Date();
        var self = this;
        var feeds = this.model.get_feeds();
        var approved = 0;

        if (!feeds.size()) {
            _.defer(_.bind(function () {
                var $info = $('.NB-feedchooser-info', this.$modal);
                $('.NB-feedchooser-info-counts', $info).hide();
                $('.NB-feedchooser-info-sort', $info).hide();
                $('.NB-feedchooser-info-reset', $info).hide();
                $('#NB-feedchooser-feeds').hide();
                $('.NB-modal-submit-save').hide();
                $('.NB-modal-submit-add').show();
            }, this));
            return;
        }

        if (reset) {
            feeds.each(function (feed) {
                self.add_feed_to_decline(feed, true);
            });
        }

        var active_feeds = feeds.any(function (feed) { return feed.get('active'); });
        if (!active_feeds || reset) {
            // Get feed subscribers bottom cut-off
            var min_subscribers = _.last(
                _.first(
                    _.map(feeds.select(function (f) { return !f.has_exception; }), function (f) { return f.get('subs'); }).sort(function (a, b) {
                        return b - a;
                    }),
                    this.MAX_FEEDS
                )
            );

            // Decline everything
            var approve_feeds = [];
            feeds.each(function (feed) {
                if (feed.get('subs') >= min_subscribers) {
                    approve_feeds.push(feed);
                }
            });

            // Approve feeds in subs
            _.each(approve_feeds, function (feed) {
                if (feed.get('subs') > min_subscribers &&
                    approved < self.MAX_FEEDS &&
                    !feed.get('has_exception')) {
                    approved++;
                    self.add_feed_to_approve(feed, false);
                }
            });
            _.each(approve_feeds, function (feed) {
                if (feed.get('subs') == min_subscribers &&
                    approved < self.MAX_FEEDS) {
                    approved++;
                    self.add_feed_to_approve(feed, false);
                }
            });

            this.show_autoselected_label();
        } else {
            // Get active feeds
            var active_feeds = feeds.select(function (feed) {
                return feed.get('active');
            });

            // Approve or decline
            _.each(active_feeds, function (feed) {
                self.add_feed_to_approve(feed, false);
            });

            this.hide_autoselected_label();
        }
        this.update_counts(true);
    },

    show_autoselected_label: function () {
        $('.NB-feedchooser-info-sort', this.$modal).stop();
        $('.NB-feedchooser-info-reset', this.$modal).stop().fadeOut(500, _.bind(function () {
            $('.NB-feedchooser-info-reset', this.$modal).hide();
            $('.NB-feedchooser-info-sort', this.$modal).fadeIn(500);
        }, this));
    },

    hide_autoselected_label: function () {
        $('.NB-feedchooser-info-reset', this.$modal).stop();
        $('.NB-feedchooser-info-sort', this.$modal).stop().fadeOut(500, _.bind(function () {
            $('.NB-feedchooser-info-sort', this.$modal).hide();
            $('.NB-feedchooser-info-reset', this.$modal).fadeIn(500);
        }, this));
    },

    save: function () {
        var self = this;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        $submit.addClass('NB-disabled').removeClass('NB-modal-submit-green').val('Saving...');
        var approve_list = _.pluck(NEWSBLUR.assets.feeds.filter(function (feed) {
            return feed.get('highlighted');
        }), 'id');

        console.log(["Saving", approve_list]);

        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        this.model.save_feed_chooser(approve_list, function () {
            self.flags['has_saved'] = true;
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
            NEWSBLUR.reader.hide_feed_chooser_button();
            NEWSBLUR.assets.load_feeds();
            $.modal.close();
        });
    },

    close_and_add: function () {
        $.modal.close(function () {
            NEWSBLUR.add_feed = new NEWSBLUR.ReaderAddFeed();
        });
    },

    open_premium_upgrade: function () {
        var self = this;
        $.modal.close(function () {
            NEWSBLUR.reader.open_premium_upgrade_modal();
        });
    },

    // ===========
    // = Actions =
    // ===========

    handle_mousedown: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-submit-save' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.save();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-modal-submit-add' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.close_and_add();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-feedchooser-upgrade-banner' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.open_premium_upgrade();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-feedchooser-info-reset' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.initial_load_feeds(true);
        }, this));
    },

    handle_change: function (elem, e) {


    },

    handle_cancel: function () {
        var $cancel = $('.NB-modal-cancel', this.$modal);

        $cancel.click(function (e) {
            e.preventDefault();
            $.modal.close();
        });
    }

});
