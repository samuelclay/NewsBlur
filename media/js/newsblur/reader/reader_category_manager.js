NEWSBLUR.ReaderCategoryManager = function (options) {
    var defaults = {
        width: 700,
        onOpen: _.bind(function () {
            this.resize_modal();
        }, this)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.archive_view = options.archive_view;
    this.runner();
};

NEWSBLUR.ReaderCategoryManager.prototype = new NEWSBLUR.Modal();
NEWSBLUR.ReaderCategoryManager.prototype.constructor = NEWSBLUR.ReaderCategoryManager;

_.extend(NEWSBLUR.ReaderCategoryManager.prototype, {

    runner: function () {
        this.active_tab = 'merge';
        this.merge_groups = this.archive_view.merge_groups || [];
        this.unassigned_categories = this.archive_view.unassigned_categories || [];
        this.categories = this.archive_view.categories || [];
        this.split_candidates = _.filter(this.categories, function (cat) {
            return cat.count >= 10;
        });
        this.split_suggestions = null;
        this.selected_split_category = null;
        this.split_loading = false;

        this.make_modal();
        this.open_modal();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));

        // Setup drag and drop for merge pills
        _.defer(_.bind(this.setup_drag_drop, this));
    },

    make_modal: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal NB-modal-category-manager' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-merge' }, 'Merge'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-split' }, 'Split'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-all' }, 'All Categories')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Manage Categories',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('div', { className: 'NB-modal-content' }, [
                // Merge Tab
                $.make('div', { className: 'NB-tab NB-tab-merge NB-active' }),
                // Split Tab
                $.make('div', { className: 'NB-tab NB-tab-split' }),
                // All Categories Tab
                $.make('div', { className: 'NB-tab NB-tab-all' })
            ])
        ]);

        this.render_merge_tab();
        this.render_split_tab();
        this.render_all_tab();
    },

    resize_modal: function () {
        var $tab = this.$modal.find('.NB-tab.NB-active');
        var height = Math.min(500, $tab.outerHeight());
        $tab.css('max-height', height);
    },

    // =============
    // = Tab Views =
    // =============

    render_merge_tab: function () {
        var self = this;
        var $tab = this.$modal.find('.NB-tab-merge');
        $tab.empty();

        if (this.merge_groups.length === 0) {
            $tab.append($.make('div', { className: 'NB-category-empty' },
                'No merge suggestions available. Categories are analyzed for similarity.'));
            return;
        }

        // Merge groups container
        var $groups = $.make('div', { className: 'NB-merge-groups' });

        _.each(this.merge_groups, function (group) {
            var $group = $.make('div', { className: 'NB-merge-group', 'data-group-id': group.id }, [
                $.make('div', { className: 'NB-merge-group-header' }, [
                    $.make('input', {
                        type: 'text',
                        className: 'NB-merge-target-input',
                        value: group.target,
                        'data-group-id': group.id,
                        placeholder: 'Target category name'
                    }),
                    $.make('span', {
                        className: 'NB-merge-group-remove',
                        'data-group-id': group.id,
                        title: 'Remove this merge group'
                    }, '&times;')
                ]),
                $.make('div', { className: 'NB-merge-group-pills', 'data-group-id': group.id },
                    _.map(group.categories, function (cat) {
                        return self.make_category_pill(cat, group.id);
                    })
                )
            ]);
            $groups.append($group);
        });

        $tab.append($groups);

        // Unassigned drop zone
        $tab.append($.make('div', { className: 'NB-unassigned-zone' }, [
            $.make('div', { className: 'NB-unassigned-label' }, 'Excluded from merges'),
            $.make('div', { className: 'NB-unassigned-pills' },
                this.unassigned_categories.length > 0 ?
                    _.map(this.unassigned_categories, function (cat) {
                        return self.make_category_pill(cat, null);
                    }) :
                    $.make('span', { className: 'NB-unassigned-hint' }, 'Drag categories here to exclude them')
            )
        ]));

        // Apply All footer with summary
        if (this.merge_groups.length > 0) {
            var summary = this.get_merge_summary();
            $tab.append($.make('div', { className: 'NB-merge-footer' }, [
                $.make('div', { className: 'NB-merge-summary' }, summary),
                $.make('div', { className: 'NB-merge-actions' }, [
                    $.make('button', { className: 'NB-modal-submit-button NB-modal-submit-green NB-apply-all-merges' }, 'Apply All Merges')
                ])
            ]));
        }
    },

    make_category_pill: function (cat, group_id) {
        var attrs = {
            className: 'NB-category-pill',
            draggable: 'true',
            'data-category': cat.name
        };
        if (group_id) {
            attrs['data-group-id'] = group_id;
        }

        return $.make('div', attrs, [
            $.make('span', { className: 'NB-pill-name' }, cat.name),
            $.make('span', { className: 'NB-pill-count' }, cat.count)
        ]);
    },

    get_merge_summary: function () {
        var total_merges = 0;
        var total_categories = 0;

        _.each(this.merge_groups, function (group) {
            if (group.categories.length > 1) {
                total_merges++;
                total_categories += group.categories.length;
            }
        });

        if (total_merges === 0) {
            return 'No merges to apply';
        }

        return total_merges + ' merge' + (total_merges > 1 ? 's' : '') +
               ' (' + total_categories + ' categories into ' + total_merges + ')';
    },

    render_split_tab: function () {
        var self = this;
        var $tab = this.$modal.find('.NB-tab-split');
        $tab.empty();

        if (this.split_candidates.length === 0) {
            $tab.append($.make('div', { className: 'NB-category-empty' },
                'No categories with 10+ stories available for splitting.'));
            return;
        }

        // Candidates list
        var $list = $.make('div', { className: 'NB-split-list' });
        _.each(this.split_candidates, function (cat) {
            var is_selected = self.selected_split_category === cat._id;
            $list.append($.make('div', {
                className: 'NB-split-item' + (is_selected ? ' NB-selected' : ''),
                'data-category': cat._id
            }, [
                $.make('span', { className: 'NB-split-item-name' }, cat._id),
                $.make('span', { className: 'NB-split-item-count' }, cat.count),
                $.make('span', { className: 'NB-split-item-action' }, 'Get AI Suggestions')
            ]));
        });
        $tab.append($list);

        // Split suggestions panel
        if (this.split_loading) {
            $tab.append($.make('div', { className: 'NB-split-panel NB-loading' }, [
                $.make('div', { className: 'NB-modal-loading NB-active' }),
                $.make('span', 'Getting AI suggestions...')
            ]));
        } else if (this.split_suggestions) {
            var $panel = $.make('div', { className: 'NB-split-panel' }, [
                $.make('div', { className: 'NB-split-panel-header' },
                    'Split "' + this.selected_split_category + '" into:')
            ]);

            var $suggestions = $.make('div', { className: 'NB-split-suggestions' });
            _.each(this.split_suggestions.suggestions, function (suggestion, i) {
                $suggestions.append($.make('div', { className: 'NB-split-suggestion' }, [
                    $.make('input', {
                        type: 'checkbox',
                        className: 'NB-split-checkbox',
                        checked: true,
                        'data-index': i
                    }),
                    $.make('input', {
                        type: 'text',
                        className: 'NB-split-name-input',
                        value: suggestion.name,
                        'data-index': i
                    }),
                    $.make('span', { className: 'NB-split-count' },
                        (suggestion.story_ids ? suggestion.story_ids.length : 0) + ' stories')
                ]));
            });
            $panel.append($suggestions);

            $panel.append($.make('div', { className: 'NB-split-actions' }, [
                $.make('button', { className: 'NB-modal-submit-button NB-modal-submit-green NB-apply-split' }, 'Apply Split'),
                $.make('button', { className: 'NB-modal-submit-button NB-modal-submit-grey NB-cancel-split' }, 'Cancel')
            ]));

            $tab.append($panel);
        }
    },

    render_all_tab: function () {
        var self = this;
        var $tab = this.$modal.find('.NB-tab-all');
        $tab.empty();

        var sorted = _.sortBy(this.categories, function (c) { return -c.count; });

        var $list = $.make('div', { className: 'NB-all-list' });
        _.each(sorted, function (cat) {
            $list.append($.make('div', {
                className: 'NB-all-item',
                'data-category': cat._id
            }, [
                $.make('span', { className: 'NB-all-item-name' }, cat._id),
                $.make('span', { className: 'NB-all-item-count' }, cat.count),
                $.make('span', {
                    className: 'NB-all-item-edit',
                    'data-category': cat._id,
                    title: 'Rename category'
                }, 'Rename')
            ]));
        });
        $tab.append($list);
    },

    // ==============
    // = Tab Switch =
    // ==============

    switch_tab: function (tab) {
        if (this.active_tab === tab) return;

        this.active_tab = tab;

        // Update tab buttons
        this.$modal.find('.NB-modal-tab').removeClass('NB-active');
        this.$modal.find('.NB-modal-tab-' + tab).addClass('NB-active');

        // Update tab content
        this.$modal.find('.NB-tab').removeClass('NB-active');
        this.$modal.find('.NB-tab-' + tab).addClass('NB-active');
    },

    // ============
    // = Handlers =
    // ============

    handle_click: function (elem, e) {
        var self = this;

        // Tab switching
        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function ($t, $p) {
            e.preventDefault();
            var newtab;
            if ($t.hasClass('NB-modal-tab-merge')) {
                newtab = 'merge';
            } else if ($t.hasClass('NB-modal-tab-split')) {
                newtab = 'split';
            } else if ($t.hasClass('NB-modal-tab-all')) {
                newtab = 'all';
            }
            if (newtab) {
                self.switch_tab(newtab);
            }
        });

        // Apply All Merges
        $.targetIs(e, { tagSelector: '.NB-apply-all-merges' }, function ($t, $p) {
            e.preventDefault();
            self.apply_all_merges();
        });

        // Remove merge group
        $.targetIs(e, { tagSelector: '.NB-merge-group-remove' }, function ($t, $p) {
            e.preventDefault();
            var group_id = $t.data('group-id');
            self.remove_merge_group(group_id);
        });

        // Split candidate selection
        $.targetIs(e, { tagSelector: '.NB-split-item' }, function ($t, $p) {
            e.preventDefault();
            var category = $t.data('category');
            self.select_split_candidate(category);
        });

        // Apply split
        $.targetIs(e, { tagSelector: '.NB-apply-split' }, function ($t, $p) {
            e.preventDefault();
            self.apply_split();
        });

        // Cancel split
        $.targetIs(e, { tagSelector: '.NB-cancel-split' }, function ($t, $p) {
            e.preventDefault();
            self.cancel_split();
        });

        // Rename category
        $.targetIs(e, { tagSelector: '.NB-all-item-edit' }, function ($t, $p) {
            e.preventDefault();
            var category = $t.data('category');
            self.start_rename(category);
        });
    },

    handle_change: function (elem, e) {
        var self = this;

        // Merge target input change
        $.targetIs(e, { tagSelector: '.NB-merge-target-input' }, function ($t, $p) {
            var group_id = $t.data('group-id');
            var new_target = $t.val();
            self.update_merge_target(group_id, new_target);
        });
    },

    // ===========
    // = Actions =
    // ===========

    apply_all_merges: function () {
        var self = this;
        var $button = this.$modal.find('.NB-apply-all-merges');
        $button.text('Applying...').prop('disabled', true);

        var merges_to_apply = [];
        _.each(this.merge_groups, function (group) {
            if (group.categories.length > 1) {
                merges_to_apply.push({
                    target: group.target,
                    sources: _.pluck(group.categories, 'name')
                });
            }
        });

        if (merges_to_apply.length === 0) {
            $button.text('Apply All Merges').prop('disabled', false);
            return;
        }

        // Apply merges sequentially
        var apply_next = function (index) {
            if (index >= merges_to_apply.length) {
                // All done
                self.archive_view.load_categories();
                self.close();
                return;
            }

            var merge = merges_to_apply[index];
            self.model.make_request('/api/archive/categories/merge', {
                sources: JSON.stringify(merge.sources),
                target: merge.target
            }, function (data) {
                if (data.code === 0) {
                    apply_next(index + 1);
                } else {
                    $button.text('Error - Try Again').prop('disabled', false);
                }
            }, function () {
                $button.text('Error - Try Again').prop('disabled', false);
            }, { method: 'POST' });
        };

        apply_next(0);
    },

    remove_merge_group: function (group_id) {
        var group = _.find(this.merge_groups, function (g) { return g.id === group_id; });
        if (group) {
            // Move categories to unassigned
            this.unassigned_categories = this.unassigned_categories.concat(group.categories);
            this.merge_groups = _.filter(this.merge_groups, function (g) { return g.id !== group_id; });
            this.render_merge_tab();
            // Update archive view
            this.archive_view.merge_groups = this.merge_groups;
            this.archive_view.unassigned_categories = this.unassigned_categories;
        }
    },

    update_merge_target: function (group_id, new_target) {
        var group = _.find(this.merge_groups, function (g) { return g.id === group_id; });
        if (group) {
            group.target = new_target;
            this.archive_view.merge_groups = this.merge_groups;
        }
    },

    select_split_candidate: function (category) {
        var self = this;
        this.selected_split_category = category;
        this.split_loading = true;
        this.split_suggestions = null;
        this.render_split_tab();

        this.model.make_request('/api/archive/categories/suggest-splits', {
            category: category
        }, function (data) {
            self.split_loading = false;
            if (data.code === 0) {
                self.split_suggestions = data;
            }
            self.render_split_tab();
        }, function () {
            self.split_loading = false;
            self.render_split_tab();
        }, { method: 'POST' });
    },

    apply_split: function () {
        var self = this;
        var $button = this.$modal.find('.NB-apply-split');
        $button.text('Applying...').prop('disabled', true);

        var splits = [];
        this.$modal.find('.NB-split-suggestion').each(function () {
            var $suggestion = $(this);
            var $checkbox = $suggestion.find('.NB-split-checkbox');
            var $input = $suggestion.find('.NB-split-name-input');
            var index = $checkbox.data('index');

            if ($checkbox.is(':checked')) {
                splits.push({
                    name: $input.val(),
                    story_ids: self.split_suggestions.suggestions[index].story_ids
                });
            }
        });

        this.model.make_request('/api/archive/categories/split', {
            source_category: this.selected_split_category,
            splits: JSON.stringify(splits)
        }, function (data) {
            if (data.code === 0) {
                self.archive_view.load_categories();
                self.cancel_split();
            } else {
                $button.text('Error - Try Again').prop('disabled', false);
            }
        }, function () {
            $button.text('Error - Try Again').prop('disabled', false);
        }, { method: 'POST' });
    },

    cancel_split: function () {
        this.selected_split_category = null;
        this.split_suggestions = null;
        this.split_loading = false;
        this.render_split_tab();
    },

    start_rename: function (category) {
        var $item = this.$modal.find('.NB-all-item[data-category="' + category + '"]');
        var $name = $item.find('.NB-all-item-name');
        var current_name = $name.text();

        $name.html($.make('input', {
            type: 'text',
            className: 'NB-all-rename-input',
            value: current_name,
            'data-original': current_name
        }));

        var $input = $name.find('input');
        $input.focus().select();

        $input.on('blur keydown', _.bind(function (e) {
            if (e.type === 'blur' || e.which === 13) {
                this.finish_rename($input);
            } else if (e.which === 27) {
                $name.text(current_name);
            }
        }, this));
    },

    finish_rename: function ($input) {
        var self = this;
        var original = $input.data('original');
        var new_name = $input.val().trim();

        if (new_name && new_name !== original) {
            this.model.make_request('/api/archive/categories/rename', {
                old_name: original,
                new_name: new_name
            }, function (data) {
                if (data.code === 0) {
                    self.archive_view.load_categories();
                    self.categories = self.archive_view.categories;
                    self.render_all_tab();
                }
            }, function () {
                self.render_all_tab();
            }, { method: 'POST' });
        } else {
            $input.parent().text(original);
        }
    },

    // ==============
    // = Drag/Drop =
    // ==============

    setup_drag_drop: function () {
        var self = this;

        this.$modal.on('dragstart', '.NB-category-pill', function (e) {
            var $pill = $(this);
            $pill.addClass('NB-dragging');
            e.originalEvent.dataTransfer.setData('text/plain', JSON.stringify({
                category: $pill.data('category'),
                group_id: $pill.data('group-id')
            }));
        });

        this.$modal.on('dragend', '.NB-category-pill', function (e) {
            $(this).removeClass('NB-dragging');
            self.$modal.find('.NB-drop-target').removeClass('NB-drop-target');
        });

        this.$modal.on('dragover', '.NB-merge-group-pills, .NB-unassigned-pills', function (e) {
            e.preventDefault();
            $(this).addClass('NB-drop-target');
        });

        this.$modal.on('dragleave', '.NB-merge-group-pills, .NB-unassigned-pills', function (e) {
            $(this).removeClass('NB-drop-target');
        });

        this.$modal.on('drop', '.NB-merge-group-pills, .NB-unassigned-pills', function (e) {
            e.preventDefault();
            $(this).removeClass('NB-drop-target');

            var data = JSON.parse(e.originalEvent.dataTransfer.getData('text/plain'));
            var $target = $(this);
            var target_group_id = $target.data('group-id') || null;

            self.move_category(data.category, data.group_id, target_group_id);
        });
    },

    move_category: function (category_name, from_group_id, to_group_id) {
        if (from_group_id === to_group_id) return;

        var cat_data = null;

        // Remove from source
        if (from_group_id) {
            var from_group = _.find(this.merge_groups, function (g) { return g.id === from_group_id; });
            if (from_group) {
                cat_data = _.find(from_group.categories, function (c) { return c.name === category_name; });
                from_group.categories = _.filter(from_group.categories, function (c) { return c.name !== category_name; });
            }
        } else {
            cat_data = _.find(this.unassigned_categories, function (c) { return c.name === category_name; });
            this.unassigned_categories = _.filter(this.unassigned_categories, function (c) { return c.name !== category_name; });
        }

        if (!cat_data) return;

        // Add to destination
        if (to_group_id) {
            var to_group = _.find(this.merge_groups, function (g) { return g.id === to_group_id; });
            if (to_group) {
                to_group.categories.push(cat_data);
            }
        } else {
            this.unassigned_categories.push(cat_data);
        }

        // Update archive view and re-render
        this.archive_view.merge_groups = this.merge_groups;
        this.archive_view.unassigned_categories = this.unassigned_categories;
        this.render_merge_tab();
    }
});
