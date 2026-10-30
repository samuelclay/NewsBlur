// feed_folder_picker_view.js: The searchable folder and site dropdown used across NewsBlur.
// A native select can't show icons, so this draws each choice with the reader's own icons:
// custom folder icons, site favicons, and the special river icons.
//
// Two ways in:
//   - new NEWSBLUR.Views.FeedFolderPicker({ items, value, on_change }) for a picker with its
//     own values, like Manage Training's add panel (media/js/newsblur/reader/reader_classifier.js).
//   - NEWSBLUR.Views.FeedFolderPicker.enhance(select) wraps an existing <select>. The select stays
//     in the page, hidden, as the real form field: choosing sets its value and fires its change
//     event, so code reading .val() or listening for change keeps working. Selects built by
//     NEWSBLUR.utils.make_feed_chooser and make_folders (reader_utils.js) carry data-nb-picker and
//     are enhanced automatically when they are added to the page (watch_for_selects below).
//
// Item fields: value, title, kind ('global', 'folder', 'feed' or 'other'), group (header shown
// above it), depth (folder nesting), parent_path (shown while searching), icon_value (passed to
// $.favicon_el) or icon_svg (a NEWSBLUR.ClassifierConstants.SCOPE_ICON_DATA key).

NEWSBLUR.Views.FeedFolderPicker = Backbone.View.extend({

    className: "NB-feed-folder-picker",

    // Short lists don't need a search box
    SEARCH_MIN_ITEMS: 9,

    events: {
        "click .NB-feed-folder-picker-trigger": "toggle",
        "keydown .NB-feed-folder-picker-trigger": "handle_trigger_keydown",
        "keyup .NB-feed-folder-picker-trigger": "handle_trigger_keyup"
    },

    initialize: function (options) {
        this.items = options.items || [];
        this.value = options.value;
        this.on_change = options.on_change;
        this.label_id = options.label_id;
        this.list_id = _.uniqueId('NB-feed-folder-picker-list-');
        this.close_on_outside = _.bind(this.close_on_outside, this);
        this.close_on_scroll = _.bind(this.close_on_scroll, this);
    },

    has_value: function (value) {
        return !!this.find_item(value);
    },

    find_item: function (value) {
        return _.find(this.items, function (item) {
            return item.value === value;
        });
    },

    set_items: function (items) {
        this.items = items;
        this.list_rendered = false;
        this.render_trigger();
    },

    set_value: function (value) {
        this.value = value;
        this.render_trigger();
        if (this.list_rendered) {
            this.$popover.find('.NB-feed-folder-picker-option').each(_.bind(function (index, option) {
                var item = this.items[$(option).data('index')];
                $(option).attr('aria-selected', item && item.value === value ? 'true' : 'false');
            }, this));
        }
    },

    make_icon: function (item) {
        var $icon = $.make('span', {
            className: 'NB-feed-folder-picker-icon NB-feed-folder-picker-icon-' + item.kind,
            'aria-hidden': 'true'
        });
        if (item.icon_svg) {
            $icon.html(_.find(NEWSBLUR.ClassifierConstants.SCOPE_ICON_DATA, function (icon) {
                return icon.key === item.icon_svg;
            }).svg);
        } else if (item.icon_value !== undefined && item.icon_value !== null) {
            var $favicon = $.favicon_el(item.icon_value);
            if ($favicon) $icon.append($favicon);
        }
        return $icon;
    },

    render: function () {
        this.$el.empty().append($.make('button', {
            type: 'button',
            className: 'NB-feed-folder-picker-trigger',
            'aria-haspopup': 'listbox',
            'aria-expanded': 'false',
            'aria-labelledby': _.compact([this.label_id, this.list_id + '-value']).join(' ')
        }));
        this.render_trigger();
        return this;
    },

    focus: function () {
        this.$('.NB-feed-folder-picker-trigger').focus();
    },

    render_trigger: function () {
        var item = this.find_item(this.value) || this.items[0];
        var $trigger = this.$('.NB-feed-folder-picker-trigger').empty();
        if (!item) return;
        // Titles and paths are plain text, never markup: a select option's .text() decodes an
        // escaped feed title, and $.make with a string child would parse it as HTML.
        $trigger.append([
            this.make_icon(item),
            $.make('span', { className: 'NB-feed-folder-picker-trigger-label', id: this.list_id + '-value' }).text(item.title)
        ]).attr('title', item.parent_path ? item.parent_path + ' › ' + item.title : item.title);
    },

    // The list lives on body with fixed positioning, so modals and popovers that clip their
    // overflow can't cut it off. Built on first open, since a reader can have hundreds of sites.
    render_popover: function () {
        var self = this;
        var show_search = this.items.length >= this.SEARCH_MIN_ITEMS;
        if (this.$popover) this.$popover.remove();

        this.$popover = $.make('div', { className: 'NB-feed-folder-picker-popover' }, [
            (show_search && $.make('input', {
                type: 'text',
                className: 'NB-feed-folder-picker-search',
                placeholder: gettext('Search folders and sites'),
                'aria-label': gettext('Search folders and sites'),
                'aria-controls': this.list_id,
                autocomplete: 'off',
                spellcheck: 'false'
            })),
            $.make('div', { className: 'NB-feed-folder-picker-list', id: this.list_id, role: 'listbox', tabindex: show_search ? -1 : 0 }),
            $.make('div', { className: 'NB-feed-folder-picker-empty NB-hidden' }, gettext('No matching folders or sites'))
        ]);

        var $list = this.$popover.find('.NB-feed-folder-picker-list');
        var last_group = null;
        _.each(this.items, function (item, index) {
            if (item.group && item.group !== last_group) {
                $list.append($.make('div', {
                    className: 'NB-feed-folder-picker-group',
                    'data-group': item.group,
                    role: 'presentation'
                }).text(item.group));
            }
            last_group = item.group;

            var $option = $.make('div', {
                className: 'NB-feed-folder-picker-option NB-feed-folder-picker-option-' + item.kind,
                id: self.list_id + '-' + index,
                role: 'option',
                'data-index': index,
                'data-group': item.group || '',
                'aria-selected': item.value === self.value ? 'true' : 'false',
                'aria-disabled': item.disabled ? 'true' : null
            }, [
                self.make_icon(item),
                $.make('span', { className: 'NB-feed-folder-picker-option-title' }).text(item.title),
                (item.parent_path && $.make('span', { className: 'NB-feed-folder-picker-option-path' }).text(item.parent_path))
            ]);
            if (item.depth) {
                $option.css('padding-inline-start', 10 + item.depth * 16);
            }
            $('img', $option).attr('loading', 'lazy');
            $list.append($option);
        });

        this.$popover.on('input', '.NB-feed-folder-picker-search', _.bind(this.filter, this))
            .on('keydown', _.bind(this.handle_popover_keydown, this))
            // Keeps focus in the search field while clicking
            .on('mousedown', '.NB-feed-folder-picker-option', function (e) { e.preventDefault(); })
            .on('click', '.NB-feed-folder-picker-option', _.bind(this.choose_option, this))
            .on('mousemove', '.NB-feed-folder-picker-option', _.bind(this.hover_option, this))
            // The list sits on body, outside the popover or menu that holds the picker, and those
            // close on any click or key that reaches the document (reader_popover.js autohide,
            // the manage menu in reader.js), so nothing in the list goes past it.
            .on('mousedown click keydown keypress keyup', function (e) { e.stopPropagation(); });
        this.list_rendered = true;
    },

    is_open: function () {
        return this.$el.hasClass('NB-open');
    },

    toggle: function (e) {
        if (e) e.preventDefault();
        if (this.is_open()) {
            this.close(true);
        } else {
            this.open();
        }
    },

    open: function () {
        if (!this.items.length) return;
        if (!this.list_rendered) this.render_popover();
        this.$popover.appendTo('body');
        this.position_popover();
        this.$el.addClass('NB-open');
        this.$('.NB-feed-folder-picker-trigger').attr('aria-expanded', 'true');

        var $search = this.$popover.find('.NB-feed-folder-picker-search');
        $search.val('');
        this.filter();
        var $selected = this.$popover.find('.NB-feed-folder-picker-option[aria-selected="true"]');
        this.set_active($selected.length ? $selected : this.visible_options().first(), true);
        ($search.length ? $search : this.$popover.find('.NB-feed-folder-picker-list')).focus();

        $(document).on('mousedown', this.close_on_outside);
        // Fixed to the trigger's spot on screen, so a scroll anywhere would leave it behind
        window.addEventListener('scroll', this.close_on_scroll, true);
        $(window).on('resize', this.close_on_scroll);
    },

    // Below the trigger, or above it when there isn't room, and never off the side of the screen.
    position_popover: function () {
        var rect = this.$('.NB-feed-folder-picker-trigger')[0].getBoundingClientRect();
        var width = Math.max(rect.width, 280);
        var left = Math.max(8, Math.min(rect.left, window.innerWidth - width - 8));
        if (NEWSBLUR.utils.is_rtl && NEWSBLUR.utils.is_rtl()) {
            left = Math.max(8, Math.min(rect.right - width, window.innerWidth - width - 8));
        }
        this.$popover.css({ position: 'fixed', left: left, width: width, top: '', bottom: '' });

        var space_below = window.innerHeight - rect.bottom;
        var height = this.$popover.outerHeight();
        if (space_below < height + 12 && rect.top > space_below) {
            this.$popover.css({ bottom: window.innerHeight - rect.top + 4 });
        } else {
            this.$popover.css({ top: rect.bottom + 4 });
        }
    },

    close: function (restore_focus) {
        if (!this.is_open()) return;
        this.$el.removeClass('NB-open');
        this.$('.NB-feed-folder-picker-trigger').attr('aria-expanded', 'false');
        if (this.$popover) this.$popover.detach();
        $(document).off('mousedown', this.close_on_outside);
        window.removeEventListener('scroll', this.close_on_scroll, true);
        $(window).off('resize', this.close_on_scroll);
        if (restore_focus) this.$('.NB-feed-folder-picker-trigger').focus();
    },

    close_on_outside: function (e) {
        if (!$.contains(document.documentElement, this.el)) {
            // The picker left the page while it was open, like a dialog closing
            this.close(false);
            return;
        }
        if (!$.contains(this.el, e.target) && !$.contains(this.$popover[0], e.target)) this.close(false);
    },

    close_on_scroll: function (e) {
        // Scrolling the list itself is fine
        if (e && e.target && this.$popover && $.contains(this.$popover[0], e.target)) return;
        this.close(false);
    },

    visible_options: function () {
        return this.$popover.find('.NB-feed-folder-picker-option').not('.NB-hidden').not('[aria-disabled="true"]');
    },

    filter: function () {
        var query = this.$popover.find('.NB-feed-folder-picker-search').val() || '';
        var visible = {};
        _.each(NEWSBLUR.classifier_add_utils.filter_scope_options(this.items, query), function (item) {
            visible[item.value] = true;
        });

        var self = this;
        var visible_groups = {};
        var any_visible = false;
        this.$popover.find('.NB-feed-folder-picker-option').each(function () {
            var item = self.items[$(this).data('index')];
            var is_visible = !!visible[item.value];
            $(this).toggleClass('NB-hidden', !is_visible);
            if (is_visible) {
                any_visible = true;
                visible_groups[item.group || ''] = true;
            }
        });
        this.$popover.find('.NB-feed-folder-picker-group').each(function () {
            $(this).toggleClass('NB-hidden', !visible_groups[$(this).data('group')]);
        });
        // While searching, show each nested folder's parent so same-named folders differ
        this.$popover.toggleClass('NB-searching', !!$.trim(query));
        this.$popover.find('.NB-feed-folder-picker-empty').toggleClass('NB-hidden', any_visible);

        var $active = this.$popover.find('.NB-feed-folder-picker-option.NB-active');
        if (!$active.length || $active.hasClass('NB-hidden')) {
            this.set_active(this.visible_options().first());
        }
    },

    set_active: function ($option, center) {
        var $list = this.$popover.find('.NB-feed-folder-picker-list');
        var $focus = this.$popover.find('.NB-feed-folder-picker-search');
        if (!$focus.length) $focus = $list;
        this.$popover.find('.NB-feed-folder-picker-option.NB-active').removeClass('NB-active');
        if (!$option || !$option.length) {
            $focus.removeAttr('aria-activedescendant');
            return;
        }
        $option.addClass('NB-active');
        $focus.attr('aria-activedescendant', $option.attr('id'));

        var list = $list[0];
        var top = $option[0].offsetTop;
        var bottom = top + $option[0].offsetHeight;
        if (center) {
            list.scrollTop = top - list.clientHeight / 2 + $option[0].offsetHeight / 2;
        } else if (top < list.scrollTop) {
            list.scrollTop = top - 28;
        } else if (bottom > list.scrollTop + list.clientHeight) {
            list.scrollTop = bottom - list.clientHeight;
        }
    },

    move_active: function (direction) {
        var $options = this.visible_options();
        var index = $options.index(this.$popover.find('.NB-feed-folder-picker-option.NB-active'));
        var next = Math.max(0, Math.min($options.length - 1, index + direction));
        this.set_active($options.eq(next));
    },

    select: function ($option) {
        var item = this.items[$option.data('index')];
        if (!item || item.disabled) return;
        this.set_value(item.value);
        this.close(true);
        if (this.on_change) this.on_change(item.value);
    },

    choose_option: function (e) {
        e.preventDefault();
        this.select($(e.currentTarget));
    },

    hover_option: function (e) {
        var $option = $(e.currentTarget);
        if (!$option.hasClass('NB-active') && $option.attr('aria-disabled') !== 'true') this.set_active($option);
    },

    handle_trigger_keydown: function (e) {
        if (e.which === 40 || e.which === 38) {
            e.preventDefault();
            this.open();
        }
    },

    // The key that closed the list comes back up on the trigger, where a popover around the
    // picker would take an Esc for its own (reader_popover.js autohide closes on Esc keyup).
    handle_trigger_keyup: function (e) {
        if (e.which === this.closing_key) e.stopPropagation();
        this.closing_key = null;
    },

    handle_popover_keydown: function (e) {
        if (e.which === 40 || e.which === 38) {
            e.preventDefault();
            this.move_active(e.which === 40 ? 1 : -1);
        } else if (e.which === 13) {
            // Enter that confirms an IME composition isn't a choice
            if (e.originalEvent && e.originalEvent.isComposing) return;
            e.preventDefault();
            var $active = this.$popover.find('.NB-feed-folder-picker-option.NB-active');
            if ($active.length) {
                this.closing_key = e.which;
                this.select($active);
            }
        } else if (e.which === 27) {
            // Esc closes the list, not the dialog around it
            e.preventDefault();
            e.stopPropagation();
            this.closing_key = e.which;
            this.close(true);
        } else if (e.which === 9) {
            e.preventDefault();
            this.closing_key = e.which;
            this.close(true);
        } else if (e.key && e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey &&
            !this.$popover.find('.NB-feed-folder-picker-search').length) {
            e.preventDefault();
            this.type_ahead(e.key);
        }
    },

    // Short lists have no search field, so typing moves to the next title starting with what
    // was typed, like a native select.
    type_ahead: function (character) {
        clearTimeout(this.type_ahead_timer);
        this.type_ahead_timer = setTimeout(_.bind(function () {
            this.typed = '';
        }, this), 800);
        this.typed = (this.typed || '') + character.toLowerCase();
        // "nnn" steps through the titles starting with n
        var prefix = /^(.)\1+$/.test(this.typed) ? this.typed.charAt(0) : this.typed;

        var $options = this.visible_options();
        var active = $options.index(this.$popover.find('.NB-feed-folder-picker-option.NB-active'));
        var first = active < 0 ? 0 : active + (prefix.length === 1 ? 1 : 0);
        for (var i = 0; i < $options.length; i++) {
            var $option = $options.eq((first + i) % $options.length);
            if (this.items[$option.data('index')].title.toLowerCase().indexOf(prefix) === 0) {
                this.set_active($option);
                return;
            }
        }
    },

    remove: function () {
        this.close(false);
        if (this.$popover) this.$popover.remove();
        return Backbone.View.prototype.remove.apply(this, arguments);
    }

}, {

    // Picker items from a select's options. Folder options from make_folders are named
    // "river:<folder title>" and indented with data-depth; site options are "feed:<id>".
    items_from_select: function (select) {
        var items = [];
        var parents = [];
        var special_values = ['river:', 'river:global', 'river:blurblogs', 'river:infrequent'];

        $(select).find('option').each(function () {
            var value = this.value;
            var $optgroup = $(this).parent('optgroup');
            var title = $.trim($(this).text().replace(/ /g, ' '));
            var depth = parseInt($(this).attr('data-depth'), 10) || 0;
            var is_folder = _.string.startsWith(value, 'river:') && !_.contains(special_values, value);
            var kind = 'other';

            if (is_folder) {
                kind = 'folder';
                parents[depth] = title;
                parents.length = depth + 1;
            } else if (_.string.startsWith(value, 'feed:') || /^\d+$/.test(value)) {
                kind = 'feed';
            } else if (value === '' || value === 'river:') {
                kind = 'global';
            }

            items.push({
                value: value,
                title: title,
                kind: kind,
                group: $optgroup.length ? $optgroup.attr('label') : null,
                depth: depth,
                parent_path: is_folder && depth ? parents.slice(0, depth).join(' › ') : '',
                disabled: this.disabled,
                icon_value: NEWSBLUR.Views.FeedFolderPicker.icon_value_for(value)
            });
        });
        return items;
    },

    // What to hand $.favicon_el (jquery.newsblur.js) for an option's value, or null for a value
    // it doesn't know, which gets no icon.
    icon_value_for: function (value) {
        // An empty value is "everything", drawn with the All Site Stories icon
        if (value === '') return 'river:';
        if (/^\d+$/.test(value)) return parseInt(value, 10);
        if (/^(river|feed|social|starred|search|trending|briefing):/.test(value)) return value;
        if (_.contains(['read', 'starred', 'searches', 'archive'], value)) return value;
        return null;
    },

    // The picker takes the select's place in its layout: the size, spacing, float and flex
    // settings the select gets from CSS. Read once the select is hidden, so these are the values
    // CSS gave it (250px, 100%, auto) rather than its drawn size. A select sized to its options
    // but capped by a max-width is as wide as that cap once any folder name is long, so the
    // picker takes the cap instead of growing and shrinking with the chosen title.
    layout_from_select: function (select) {
        var style = window.getComputedStyle(select);
        var layout = {};
        _.each({
            'width': 'auto',
            'min-width': 'auto',
            'max-width': 'none',
            'float': 'none',
            'align-self': 'auto',
            'flex-grow': '0',
            'flex-shrink': '1',
            'flex-basis': 'auto',
            'margin-top': '0px',
            'margin-right': '0px',
            'margin-bottom': '0px',
            'margin-left': '0px'
        }, function (initial, property) {
            var value = style.getPropertyValue(property);
            if (value && value !== initial) layout[property] = value;
        });
        if (!layout.width && layout['max-width']) layout.width = layout['max-width'];
        return layout;
    },

    // Each wrapped select's picker. Not jQuery data: replaceWith and remove clear that before
    // the select leaves the page, and then its picker couldn't be found to go with it.
    pickers: new WeakMap(),

    for_select: function (select) {
        return NEWSBLUR.Views.FeedFolderPicker.pickers.get(select);
    },

    enhance: function (select) {
        var $select = $(select);
        var existing = NEWSBLUR.Views.FeedFolderPicker.for_select(select);
        if (existing) return existing;

        var picker = new NEWSBLUR.Views.FeedFolderPicker({
            items: NEWSBLUR.Views.FeedFolderPicker.items_from_select(select),
            value: $select.val(),
            on_change: function (value) {
                $select.val(value);
                // A native event reaches jQuery, Backbone and addEventListener handlers alike
                select.dispatchEvent(new Event('change', { bubbles: true }));
            }
        });
        picker.render();

        $select.addClass('NB-feed-folder-picker-select');
        picker.$el.css(NEWSBLUR.Views.FeedFolderPicker.layout_from_select(select));
        if (!picker.el.style.width) picker.$el.addClass('NB-feed-folder-picker-fit');
        picker.$el.addClass(_.map(($select.attr('class') || '').split(/\s+/), function (class_name) {
            return class_name && class_name !== 'NB-feed-folder-picker-select' ? 'NB-feed-folder-picker-for-' + class_name : '';
        }).join(' '));
        $select.after(picker.el);
        NEWSBLUR.Views.FeedFolderPicker.pickers.set(select, picker);

        $select.on('change.nb_feed_folder_picker', function () {
            picker.set_value($select.val());
        });
        // Options added or removed after the fact, like a new folder
        if (window.MutationObserver) {
            new MutationObserver(function () {
                picker.set_items(NEWSBLUR.Views.FeedFolderPicker.items_from_select(select));
                picker.set_value($select.val());
            }).observe(select, { childList: true, subtree: true });
        }
        return picker;
    },

    // Selects from make_feed_chooser and make_folders are enhanced as they enter the page,
    // and their picker goes when a select is swapped out with replaceWith.
    watch_for_selects: function () {
        if (this.watching || !window.MutationObserver) return;
        this.watching = true;

        var enhance_within = function (node) {
            if (node.nodeType !== 1) return;
            if (node.matches('select[data-nb-picker]')) {
                NEWSBLUR.Views.FeedFolderPicker.enhance(node);
            } else if (node.firstElementChild) {
                _.each(node.querySelectorAll('select[data-nb-picker]'), NEWSBLUR.Views.FeedFolderPicker.enhance);
            }
        };
        var remove_orphan = function (node) {
            if (node.nodeType !== 1 || !node.matches('select[data-nb-picker]')) return;
            var picker = NEWSBLUR.Views.FeedFolderPicker.for_select(node);
            if (picker && !node.isConnected) {
                picker.remove();
                NEWSBLUR.Views.FeedFolderPicker.pickers.delete(node);
            }
        };

        new MutationObserver(function (mutations) {
            _.each(mutations, function (mutation) {
                _.each(mutation.addedNodes, enhance_within);
                _.each(mutation.removedNodes, remove_orphan);
            });
        }).observe(document.body, { childList: true, subtree: true });
        _.each(document.querySelectorAll('select[data-nb-picker]'), NEWSBLUR.Views.FeedFolderPicker.enhance);
    }

});

// Setting a wrapped select's value in code moves its picker too
(function () {
    var original_set = $.valHooks.select && $.valHooks.select.set;
    if (!original_set) return;
    $.valHooks.select.set = function (elem, value) {
        var result = original_set.apply(this, arguments);
        var picker = NEWSBLUR.Views.FeedFolderPicker.for_select(elem);
        if (picker) picker.set_value(elem.value);
        return result;
    };
})();

$(function () {
    NEWSBLUR.Views.FeedFolderPicker.watch_for_selects();
});
