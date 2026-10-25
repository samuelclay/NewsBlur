// classifier_scope_picker_view.js: Where a classifier typed into Manage Training's add panel
// applies (media/js/newsblur/reader/reader_classifier.js, forum #13907). A native select can't
// show icons, so this is a searchable dropdown of All sites, the reader's folders with their
// custom folder icons, and their sites with favicons. Values match
// NEWSBLUR.classifier_add_utils.parse_scope: 'global', 'folder:<folder path>' or 'feed:<feed id>'.

NEWSBLUR.Views.ClassifierScopePicker = Backbone.View.extend({

    className: "NB-scope-picker",

    events: {
        "click .NB-scope-picker-trigger": "toggle",
        "keydown .NB-scope-picker-trigger": "handle_trigger_keydown",
        "input .NB-scope-picker-search": "filter",
        "keydown .NB-scope-picker-search": "handle_search_keydown",
        "mousedown .NB-scope-picker-option": "choose_option",
        "mousemove .NB-scope-picker-option": "hover_option"
    },

    initialize: function (options) {
        this.value = options.value;
        this.on_change = options.on_change;
        this.label_id = options.label_id;
        this.list_id = _.uniqueId('NB-scope-picker-list-');
        this.scope_options = this.build_scope_options();
        this.close_on_outside = _.bind(this.close_on_outside, this);
    },

    // All sites, then folders in sidebar order with their full paths (the name
    // folder-scoped classifiers store, see folder_path), then active sites by title.
    build_scope_options: function () {
        var utils = NEWSBLUR.classifier_add_utils;
        var scope_options = [{ value: 'global', kind: 'global', title: gettext('All sites') }];

        var add_folders = function (items, parent_path, depth) {
            items.each(function (item) {
                if (!item.is_folder()) return;
                var folder_title = item.get('folder_title');
                var path = utils.folder_path(parent_path, folder_title);
                scope_options.push({
                    value: 'folder:' + path,
                    kind: 'folder',
                    title: folder_title,
                    path: path,
                    parent_path: parent_path,
                    depth: depth
                });
                add_folders(item.folders, path, depth + 1);
            });
        };
        add_folders(NEWSBLUR.assets.get_folders(), '', 0);

        NEWSBLUR.assets.feeds.chain()
            .filter(function (feed) {
                return feed.get('active') && feed.get('feed_title') && !feed.is_social();
            })
            .sortBy(function (feed) {
                return feed.get('feed_title').toLowerCase();
            })
            .each(function (feed) {
                scope_options.push({ value: 'feed:' + feed.id, kind: 'feed', title: feed.get('feed_title'), feed: feed });
            });

        return scope_options;
    },

    has_value: function (value) {
        return !!this.find_option(value);
    },

    find_option: function (value) {
        return _.find(this.scope_options, function (option) {
            return option.value === value;
        });
    },

    // The same glyphs the classifier pills use for scope, with the reader's own icons where
    // they have them: a custom folder icon, or the site's favicon.
    make_icon: function (option) {
        var $icon = $.make('span', { className: 'NB-scope-picker-icon NB-scope-' + option.kind, 'aria-hidden': 'true' });
        var folder_icon = option.kind === 'folder' && NEWSBLUR.assets.get_folder_icon(option.title);

        if (option.kind === 'feed') {
            $icon.append($.favicon_el(option.feed));
        } else if (folder_icon && folder_icon.icon_type && folder_icon.icon_type !== 'none') {
            $icon.addClass('NB-scope-picker-icon-custom').append($.favicon_el('river:' + option.title));
        } else {
            $icon.html(_.find(NEWSBLUR.ClassifierConstants.SCOPE_ICON_DATA, function (icon) {
                return icon.key === option.kind;
            }).svg);
        }
        return $icon;
    },

    render: function () {
        this.$el.empty().append([
            $.make('button', {
                type: 'button',
                className: 'NB-scope-picker-trigger',
                'aria-haspopup': 'listbox',
                'aria-expanded': 'false',
                'aria-labelledby': _.compact([this.label_id, this.list_id + '-value']).join(' ')
            }),
            $.make('div', { className: 'NB-scope-picker-popover NB-hidden' }, [
                $.make('input', {
                    type: 'text',
                    className: 'NB-scope-picker-search',
                    placeholder: gettext('Search folders and sites'),
                    'aria-label': gettext('Search folders and sites'),
                    'aria-controls': this.list_id,
                    autocomplete: 'off',
                    spellcheck: 'false'
                }),
                $.make('div', { className: 'NB-scope-picker-list', id: this.list_id, role: 'listbox' }),
                $.make('div', { className: 'NB-scope-picker-empty NB-hidden' }, gettext('No matching folders or sites'))
            ])
        ]);
        this.render_trigger();
        return this;
    },

    render_trigger: function () {
        var option = this.find_option(this.value) || this.scope_options[0];
        this.$('.NB-scope-picker-trigger').empty().append([
            this.make_icon(option),
            $.make('span', { className: 'NB-scope-picker-trigger-label', id: this.list_id + '-value' }, option.title)
        ]).attr('title', option.path || option.title);
    },

    // Built on first open, since a reader can have hundreds of sites and favicons.
    render_list: function () {
        var self = this;
        var $list = this.$('.NB-scope-picker-list').empty();
        var headers = { folder: gettext('Folders'), feed: gettext('Sites') };
        var last_kind = null;

        _.each(this.scope_options, function (option, index) {
            if (headers[option.kind] && option.kind !== last_kind) {
                $list.append($.make('div', {
                    className: 'NB-scope-picker-group',
                    'data-kind': option.kind,
                    role: 'presentation'
                }, headers[option.kind]));
            }
            last_kind = option.kind;

            var $option = $.make('div', {
                className: 'NB-scope-picker-option NB-scope-picker-option-' + option.kind,
                id: self.list_id + '-' + index,
                role: 'option',
                'data-index': index,
                'aria-selected': option.value === self.value ? 'true' : 'false'
            }, [
                self.make_icon(option),
                $.make('span', { className: 'NB-scope-picker-option-title' }, option.title),
                (option.parent_path && $.make('span', { className: 'NB-scope-picker-option-path' }, option.parent_path))
            ]);
            if (option.depth) {
                $option.css('padding-left', 10 + option.depth * 16);
            }
            $('img', $option).attr('loading', 'lazy');
            $list.append($option);
        });
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
        if (!this.list_rendered) this.render_list();
        this.$el.addClass('NB-open');
        this.$('.NB-scope-picker-trigger').attr('aria-expanded', 'true');
        this.$('.NB-scope-picker-popover').removeClass('NB-hidden');
        this.$('.NB-scope-picker-search').val('').focus();
        this.filter();

        var $selected = this.$('.NB-scope-picker-option[aria-selected="true"]');
        this.set_active($selected.length ? $selected : this.$('.NB-scope-picker-option').first());
        $(document).on('mousedown', this.close_on_outside);
    },

    close: function (restore_focus) {
        if (!this.is_open()) return;
        this.$el.removeClass('NB-open');
        this.$('.NB-scope-picker-trigger').attr('aria-expanded', 'false');
        this.$('.NB-scope-picker-popover').addClass('NB-hidden');
        $(document).off('mousedown', this.close_on_outside);
        if (restore_focus) this.$('.NB-scope-picker-trigger').focus();
    },

    close_on_outside: function (e) {
        if (!$.contains(document.documentElement, this.el)) {
            // The trainer closed with the picker open
            $(document).off('mousedown', this.close_on_outside);
            return;
        }
        if (!$.contains(this.el, e.target)) this.close(false);
    },

    filter: function () {
        var query = this.$('.NB-scope-picker-search').val();
        var visible = {};
        _.each(NEWSBLUR.classifier_add_utils.filter_scope_options(this.scope_options, query), function (option) {
            visible[option.value] = true;
        });

        var self = this;
        var visible_kinds = {};
        this.$('.NB-scope-picker-option').each(function () {
            var option = self.scope_options[$(this).data('index')];
            var is_visible = !!visible[option.value];
            $(this).toggleClass('NB-hidden', !is_visible);
            if (is_visible) visible_kinds[option.kind] = true;
        });
        this.$('.NB-scope-picker-group').each(function () {
            $(this).toggleClass('NB-hidden', !visible_kinds[$(this).data('kind')]);
        });
        // While searching, show each nested folder's parent so same-named folders differ
        this.$el.toggleClass('NB-searching', !!$.trim(query));
        this.$('.NB-scope-picker-empty').toggleClass('NB-hidden', !_.isEmpty(visible_kinds));

        var $active = this.$('.NB-scope-picker-option.NB-active');
        if (!$active.length || $active.hasClass('NB-hidden')) {
            this.set_active(this.$('.NB-scope-picker-option:not(.NB-hidden)').first());
        }
    },

    set_active: function ($option) {
        this.$('.NB-scope-picker-option.NB-active').removeClass('NB-active');
        if (!$option || !$option.length) {
            this.$('.NB-scope-picker-search').removeAttr('aria-activedescendant');
            return;
        }
        $option.addClass('NB-active');
        this.$('.NB-scope-picker-search').attr('aria-activedescendant', $option.attr('id'));

        var list = this.$('.NB-scope-picker-list')[0];
        var top = $option[0].offsetTop;
        var bottom = top + $option[0].offsetHeight;
        if (top < list.scrollTop) {
            list.scrollTop = top - 28;
        } else if (bottom > list.scrollTop + list.clientHeight) {
            list.scrollTop = bottom - list.clientHeight;
        }
    },

    move_active: function (direction) {
        var $options = this.$('.NB-scope-picker-option:not(.NB-hidden)');
        var index = $options.index(this.$('.NB-scope-picker-option.NB-active'));
        var next = Math.max(0, Math.min($options.length - 1, index + direction));
        this.set_active($options.eq(next));
    },

    select: function ($option) {
        var option = this.scope_options[$option.data('index')];
        if (!option) return;
        this.value = option.value;
        this.$('.NB-scope-picker-option[aria-selected="true"]').attr('aria-selected', 'false');
        $option.attr('aria-selected', 'true');
        this.render_trigger();
        this.close(true);
        if (this.on_change) this.on_change(option.value);
    },

    choose_option: function (e) {
        // mousedown so the search field's blur doesn't close the list first
        e.preventDefault();
        this.select($(e.currentTarget));
    },

    hover_option: function (e) {
        var $option = $(e.currentTarget);
        if (!$option.hasClass('NB-active')) this.set_active($option);
    },

    handle_trigger_keydown: function (e) {
        if (e.which === 40 || e.which === 38) {
            e.preventDefault();
            this.open();
        }
    },

    handle_search_keydown: function (e) {
        if (e.which === 40 || e.which === 38) {
            e.preventDefault();
            this.move_active(e.which === 40 ? 1 : -1);
        } else if (e.which === 13) {
            // Enter that confirms an IME composition isn't a choice
            if (e.originalEvent && e.originalEvent.isComposing) return;
            e.preventDefault();
            var $active = this.$('.NB-scope-picker-option.NB-active');
            if ($active.length) this.select($active);
        } else if (e.which === 27) {
            // Esc closes the list, not the trainer
            e.preventDefault();
            e.stopPropagation();
            this.close(true);
        } else if (e.which === 9) {
            this.close(false);
        }
    }

});
