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
        this.MAX_FEEDS = NEWSBLUR.Globals.max_feed_limit;

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

        // Bind events to the DOM modal after SimpleModal has cloned and inserted it
        // (binding to this.$modal before open_modal creates stale closure references)
        var self = this;
        setTimeout(function () {
            var $domModal = $('.NB-modal-feedchooser');
            $domModal.bind('mousedown', $.rescope(self.handle_mousedown, self));
            $domModal.bind('change', $.rescope(self.handle_change, self));
        }, 50);
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

        var upgrade_text = this.get_upgrade_text();

        this.$modal = $.make('div', { className: 'NB-modal-feedchooser NB-modal' }, [
            // Feed chooser content
            $.make('div', { className: 'NB-feedchooser-type NB-feedchooser-left' }, [
                // Modal title with icon and dropdown
                $.make('h2', { className: 'NB-modal-title' }, [
                    $.make('div', { className: 'NB-icon' }),
                    this.MAX_FEEDS ? 'Choose sites' : 'Mute sites',
                    $.make('div', { className: 'NB-icon-dropdown' })
                ]),
                // Unified header card
                $.make('div', { className: 'NB-feedchooser-header' }, [
                    // Inline upgrade prompt (only for users with limits)
                    (this.MAX_FEEDS && upgrade_text.banner && $.make('div', { className: 'NB-feedchooser-upgrade-inline' }, [
                        $.make('span', { className: 'NB-feedchooser-upgrade-icon' }),
                        $.make('span', { className: 'NB-feedchooser-upgrade-text' }, upgrade_text.banner),
                        $.make('span', { className: 'NB-feedchooser-upgrade-limit' }, upgrade_text.description),
                        $.make('span', { className: 'NB-feedchooser-upgrade-arrow' })
                    ])),
                    // Progress bar (hidden for Pro users with no limit)
                    $.make('div', { className: 'NB-feedchooser-progress-container' }, [
                        $.make('div', { className: 'NB-feedchooser-progress-track' }, [
                            $.make('div', { className: 'NB-feedchooser-progress-bar' })
                        ]),
                        $.make('div', { className: 'NB-feedchooser-progress-label' })
                    ]),
                ]),
                // Actions row - directly above feed list
                $.make('div', { className: 'NB-feedchooser-actions-row' }, [
                    $.make('div', { className: 'NB-feedchooser-actions-left' }, [
                        $.make('div', { className: 'NB-feedchooser-info-reset' }, this.MAX_FEEDS ? 'Auto-select top sites' : 'Enable all sites'),
                        $.make('div', { className: 'NB-feedchooser-info-sort' }, 'Auto-selected by popularity')
                    ]),
                    $.make('div', { className: 'NB-feedchooser-actions-right' }, [
                        $.make('div', { className: 'NB-feedchooser-usage-text' }),
                        $.make('div', { className: 'NB-feedchooser-folder-actions' }, [
                            $.make('span', { className: 'NB-feedchooser-collapse-all NB-splash-link' }, 'Collapse all'),
                            $.make('span', { className: 'NB-feedchooser-folder-actions-separator' }, '|'),
                            $.make('span', { className: 'NB-feedchooser-expand-all NB-splash-link' }, 'Expand all')
                        ])
                    ])
                ]),
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

        // Trigger modal resize after feedlist is inserted so submit button is visible
        _.defer(_.bind(function () {
            this.resize();
            this.resize_modal();
        }, this));
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
        this.update_folder_highlight_statuses();
    },

    update_folder_highlight_statuses: function () {
        // Update ON/OFF status for all collapsed folders
        this.feedlist.$el.find('li.folder.NB-folder-collapsed').each(function () {
            var folder_view = $(this).data('folder_view');
            if (folder_view && folder_view.show_folder_highlight_status) {
                folder_view.show_folder_highlight_status();
            }
        });
    },

    get_tier_class: function () {
        if (NEWSBLUR.Globals.is_pro) return 'pro';
        if (NEWSBLUR.Globals.is_archive) return 'archive';
        if (NEWSBLUR.Globals.is_premium) return 'premium';
        return 'free';
    },

    get_tier_label: function () {
        if (NEWSBLUR.Globals.is_pro) return 'Pro';
        if (NEWSBLUR.Globals.is_archive) return 'Archive';
        if (NEWSBLUR.Globals.is_premium) {
            if (NEWSBLUR.Globals.is_premium_trial) {
                var days = NEWSBLUR.Globals.trial_days_remaining;
                return 'Premium Trial' + (days ? ' (' + days + ' days)' : '');
            }
            return 'Premium';
        }
        return 'Free';
    },

    get_upgrade_text: function () {
        if (NEWSBLUR.Globals.is_pro) {
            return { banner: '', description: '' };
        } else if (NEWSBLUR.Globals.is_archive) {
            return { banner: 'Upgrade to Premium Pro', description: 'Subscribe to ' + Inflector.commas(NEWSBLUR.Globals.pro_feed_limit) + ' sites' };
        } else if (NEWSBLUR.Globals.is_premium) {
            return { banner: 'Upgrade to Premium Archive', description: 'Subscribe to ' + Inflector.commas(NEWSBLUR.Globals.archive_feed_limit) + ' sites' };
        } else {
            return { banner: 'Upgrade to Premium', description: 'Subscribe to ' + Inflector.commas(NEWSBLUR.Globals.premium_feed_limit) + ' sites' };
        }
    },

    update_counts: function (autoselected) {
        var approved = this.feedlist.folder_view.highlighted_count();
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var muted = this.feed_count - approved;
        var has_limit = this.MAX_FEEDS !== null;
        var over_limit = has_limit && approved > this.MAX_FEEDS;
        var difference = has_limit ? approved - this.MAX_FEEDS : 0;

        // Update usage text in actions row
        var $usageText = $('.NB-feedchooser-usage-text');
        $usageText.removeClass('NB-state-ok NB-state-error');
        if (has_limit) {
            $usageText.text(Inflector.commas(approved) + ' of ' + Inflector.commas(this.MAX_FEEDS) + ' sites');
            if (over_limit) {
                $usageText.addClass('NB-state-error');
            } else {
                $usageText.addClass('NB-state-ok');
            }
        } else {
            $usageText.text(Inflector.commas(approved) + ' sites');
        }

        // Update progress bar
        var $container = $('.NB-feedchooser-progress-container');
        var $progress = $('.NB-feedchooser-progress-bar');
        var $label = $('.NB-feedchooser-progress-label');

        if (has_limit) {
            $container.show();
            var pct = Math.min(100, (approved / this.MAX_FEEDS) * 100);
            $progress.css('width', pct + '%');

            var available = this.MAX_FEEDS - approved;
            var availablePct = (available / this.MAX_FEEDS) * 100;
            $container.removeClass('NB-state-ok NB-state-warning NB-state-error');

            if (available < 0) {
                $container.addClass('NB-state-error');
                $label.text(Math.abs(available) + ' over limit');
            } else if (available === 0) {
                $container.addClass('NB-state-error');
                $label.text('No sites available');
            } else {
                $container.addClass('NB-state-ok');
                $label.text(available + (available === 1 ? ' site' : ' sites') + ' available');
            }
        } else {
            $container.hide();
        }

        // Update autoselected label visibility
        if (!autoselected && has_limit) {
            this.hide_autoselected_label();
        }

        // Update submit button state
        if (NEWSBLUR.Globals.is_premium && !has_limit) {
            // Pro user - no limits
            $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false);
            if (muted == 0) {
                $submit.val('Enable all ' + Inflector.pluralize('site', this.feed_count, true));
            } else {
                $submit.val('Mute ' + Inflector.pluralize('site', muted, true));
            }
        } else if (over_limit) {
            $submit.addClass('NB-disabled').addClass('NB-modal-submit-grey').attr('disabled', true).val('Too many sites! Deselect ' + (
                difference == 1 ?
                    '1 site...' :
                    difference + ' sites...'
            ));
        } else if (NEWSBLUR.Globals.is_premium) {
            // Premium or Archive user within limits
            $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false);
            if (muted == 0) {
                $submit.val('Enable all ' + Inflector.pluralize('site', this.feed_count, true));
            } else {
                $submit.val('Mute ' + Inflector.pluralize('site', muted, true));
            }
        } else {
            // Free user within limits
            $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false).val('Turn on these ' + approved + ' sites, please');
        }
    },

    initial_load_feeds: function (reset) {
        var start = new Date();
        var self = this;
        var feeds = this.model.get_feeds();
        var approved = 0;

        if (!feeds.size()) {
            _.defer(_.bind(function () {
                // Hide header elements when no feeds exist
                $('.NB-feedchooser-progress-container', this.$modal).hide();
                $('.NB-feedchooser-upgrade-inline', this.$modal).hide();
                $('.NB-feedchooser-info-sort', this.$modal).hide();
                $('.NB-feedchooser-info-reset', this.$modal).hide();
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
        var has_limit = this.MAX_FEEDS !== null;

        if (!active_feeds || reset) {
            if (!has_limit) {
                // Pro user with no limit - approve all feeds
                feeds.each(function (feed) {
                    self.add_feed_to_approve(feed, false);
                });
            } else {
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
            }

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

    // ===================
    // = Folder Actions =
    // ===================

    collapse_all_folders: function () {
        var self = this;
        this.feedlist.$el.find('li.folder').each(function () {
            var $folder = $(this);
            // Skip root folder (has no folder title text)
            var folder_title = $folder.children('.folder_title').find('.folder_title_text').text();
            if (!folder_title) return;

            var $children = $folder.children('ul.folder');
            if ($children.length && $children.eq(0).is(':visible')) {
                $folder.addClass('NB-folder-collapsed');
                $children.hide().css('opacity', 0);
            }
        });
        // Update ON/OFF status for all collapsed folders
        this.update_folder_highlight_statuses();
    },

    expand_all_folders: function () {
        this.feedlist.$el.find('li.folder').each(function () {
            var $folder = $(this);
            $folder.removeClass('NB-folder-collapsed');
            $folder.children('ul.folder').show().css('opacity', 1);
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

        $.targetIs(e, { tagSelector: '.NB-feedchooser-upgrade-inline' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.open_premium_upgrade();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-feedchooser-info-reset' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.initial_load_feeds(true);
        }, this));

        $.targetIs(e, { tagSelector: '.NB-feedchooser-collapse-all' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.collapse_all_folders();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-feedchooser-expand-all' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.expand_all_folders();
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
