NEWSBLUR.Modal = function (options) {
    var defaults = {
        width: 600,
        overlayClose: true
    };

    this.options = _.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
    this.flags = {};
};

NEWSBLUR.Modal.prototype = {

    runner: function () { },

    open_modal: function (callback) {
        var self = this;

        this.simplemodal = this.$modal.modal({
            'minWidth': this.options.width || 600,
            'maxWidth': this.options.width || 600,
            'overlayClose': this.options.overlayClose,
            'onOpen': function (dialog) {
                self.flags.open = true;
                dialog.overlay.fadeIn(NEWSBLUR.motion.duration(200), function () {
                    dialog.container.addClass(self.options.modal_container_class);
                    dialog.container.show();
                    dialog.data.show();
                    if (self.options.onOpen) self.options.onOpen();
                    if (callback) callback();
                    self.resize();
                    self.section_motion_root = dialog.container[0];
                    self.animate_sections(dialog.data);
                    NEWSBLUR.motion.enter(dialog.container[0], 0, 14);
                    setTimeout(function () {
                        // $(window).resize();
                        self.resize();
                        self.flags.modal_loaded = true;
                    }, 0);
                });
            },
            'onShow': function (dialog) {
                $('#simplemodal-container').corner('6px');
                if (self.options.onShow) {
                    self.options.onShow();
                }
            },
            'onClose': function (dialog, callback) {
                self.flags.open = false;
                if (self.section_motion_owner && self.section_motion_owner.motion_observer) self.section_motion_owner.motion_observer.disconnect();
                var container = dialog.container[0];
                container.inert = true;
                container.style.pointerEvents = 'none';
                var transitions_remaining = 2;
                function complete_close() {
                    if (--transitions_remaining) return;
                    dialog.data.hide().empty().remove();
                    dialog.container.hide().empty().remove();
                    if (self.options.onOpen) {
                        self.options.onOpen();
                    }
                    dialog.overlay.empty().remove();
                    $('.NB-modal-holder').empty().remove();
                    $.modal.close(callback);
                }
                dialog.overlay.fadeOut(NEWSBLUR.motion.duration(200), complete_close);
                // modal.js keeps ID-based styling on the live container throughout its exit.
                NEWSBLUR.motion.exit(container, function () {
                    container.style.opacity = 0;
                    complete_close();
                });
            }
        });
    },

    resize: function () {
        // $(window).trigger('resize.simplemodal');
        $.modal.resize();
    },

    animate_sections: function ($root) {
        // modal.js reveals complete sections before first paint, without stacking parent and child entrances.
        var sections = $root.find('.NB-modal-title, .NB-modal-subtitle, .NB-modal-tabs, .NB-preference, .NB-fieldset, fieldset, .NB-modal-section, .NB-keyboard-group, .NB-modal-submit').toArray();
        $root.children().add($root.find('form > *, .NB-tab.NB-active > *')).each(function () {
            var section = this;
            if ($(section).is('form, .NB-tab, .NB-modal-loading')) return;
            if (!sections.some(function (other) { return other === section || other.contains(section) || section.contains(other); })) sections.push(section);
        });
        sections = sections.filter(function (section) {
            return !sections.some(function (parent) { return parent !== section && parent.contains(section); });
        });
        // modal.js keeps offscreen sections pending and resets the observer when switching tabs.
        this.section_motion_owner = this.section_motion_owner || {};
        NEWSBLUR.motion.watch(this.section_motion_owner, sections.map(function (section) {
            return { el: section, model: { id: section } };
        }), this.section_motion_root || $root[0], $root[0], { distance: 8, spacing: 30, spread: 180 });
    },

    close: function (callback) {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        $.modal.close(callback);
    },

    make_feed_chooser: function (options) {
        options = options || {};
        options.selected_folder_title = this.model.folder_title;
        options.feed_id = this.feed_id;

        return NEWSBLUR.utils.make_feed_chooser(options);
    },

    initialize_feed: function (feed_id) {
        this.feed_id = feed_id;
        if (this.options.embedded) {
            this.feed = NEWSBLUR.stats_feed;
        } else {
            this.feed = this.model.get_feed(feed_id);
        }
        this.options.social_feed = this.feed && this.feed.is_social();

        var $feed_icon = $.favicon_el(this.feed, {
            image_class: 'NB-modal-feed-image feed_favicon',
            emoji_class: 'NB-modal-feed-image NB-feed-emoji',
            colored_class: 'NB-modal-feed-image NB-feed-icon-colored'
        });
        var $feed_icon_container = $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).first();
        if ($feed_icon) {
            if ($feed_icon_container.length) {
                $feed_icon_container.replaceWith($feed_icon);
            } else {
                $('.NB-modal-subtitle', this.$modal).prepend($feed_icon);
            }
        }
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed.get('feed_title'));
        // Hide subscriber count for starred/saved tags and social feeds
        if (this.feed.is_starred() || this.feed.is_social()) {
            $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).hide();
        } else {
            var num_subscribers = this.feed.get('num_subscribers');
            $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).html(interpolate(ngettext("%(count)s subscriber", "%(count)s subscribers", num_subscribers), { count: Inflector.commas(num_subscribers) }, true)).show();
        }
    },

    initialize_folder: function (folder_title) {
        this.folder_title = folder_title;
        this.folder = this.model.get_folder(folder_title);

        var $folder_icon = $.favicon_el('river:' + folder_title, {
            image_class: 'NB-modal-feed-image feed_favicon',
            emoji_class: 'NB-modal-feed-image NB-folder-emoji',
            colored_class: 'NB-modal-feed-image NB-folder-icon-colored'
        });
        var $folder_icon_container = $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).first();
        if ($folder_icon) {
            if ($folder_icon_container.length) {
                $folder_icon_container.replaceWith($folder_icon);
            } else {
                $('.NB-modal-subtitle', this.$modal).prepend($folder_icon);
            }
        }
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.folder_title);
        $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).hide();
    },

    switch_tab: function (newtab) {
        var $modal_tabs = $('.NB-modal-tab', this.$modal);
        var $tabs = $('.NB-tab', this.$modal);

        $modal_tabs.removeClass('NB-active');
        $tabs.removeClass('NB-active');

        $modal_tabs.filter('.NB-modal-tab-' + newtab).addClass('NB-active');
        var $selected = $tabs.filter('.NB-tab-' + newtab).addClass('NB-active');
        this.animate_sections($selected);
    }

};
