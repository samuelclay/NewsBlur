// folder_picker_utils.js: selection, filtering and sizing rules for the folder picker
// in the feed and folder manage menus (reader.js: make_folder_picker). Kept free of
// DOM and Backbone so node/tests/folder_picker_utils.test.js can exercise it directly.
(function (root, factory) {
    var api = factory();

    root.NEWSBLUR = root.NEWSBLUR || {};
    root.NEWSBLUR.folder_picker_utils = api;

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    function contains(list, value) {
        return list.indexOf(value) !== -1;
    }

    function same_folders(a, b) {
        if (a.length !== b.length) return false;
        return a.every(function (value) {
            return contains(b, value);
        });
    }

    function inside_moving_folder(moving_path, target_path) {
        return !!moving_path && moving_path.every(function (title, index) {
            return target_path[index] === title;
        });
    }

    // folder_picker_utils.js uses JSON paths for folder moves and titles for feed moves.
    function build_rows(tree, options) {
        options = options || {};
        var selected = options.selected || [];
        var disabled = options.disabled || [];
        var moving_path = options.moving_folder_path;
        var root_value = moving_path ? JSON.stringify([]) : '';
        var rows = [{
            value: root_value,
            title: options.top_level_title || 'Top Level',
            depth: 0,
            ancestors: [],
            selected: contains(selected, root_value),
            disabled: contains(disabled, root_value)
        }];

        function walk(items, parent_path, ancestors) {
            items.forEach(function (item) {
                var path = parent_path.concat([item.title]);
                var value = moving_path ? JSON.stringify(path) : item.title;
                rows.push({
                    value: value,
                    title: item.title,
                    depth: path.length,
                    ancestors: ancestors,
                    selected: contains(selected, value),
                    disabled: contains(disabled, value) || inside_moving_folder(moving_path, path)
                });
                walk(item.children || [], path, ancestors.concat([value]));
            });
        }
        walk(tree, [], []);

        return rows;
    }

    // Clicking a folder's name moves the feed there, replacing every other folder.
    function choose_folder(selected, value) {
        return [value];
    }

    // Clicking the check circle keeps the other folders, for feeds in several folders.
    function toggle_folder(selected, value) {
        if (contains(selected, value)) {
            return selected.filter(function (folder) {
                return folder !== value;
            });
        }
        return selected.concat([value]);
    }

    function save_state(selected, original) {
        if (!selected.length) {
            return { action: 'empty', count: 0 };
        }
        if (same_folders(selected, original)) {
            return { action: 'unchanged', count: selected.length };
        }
        if (selected.length === 1) {
            return { action: 'move', count: 1, folder: selected[0] };
        }
        return { action: 'save', count: selected.length };
    }

    // Returns the rows to show for a filter query: every matching folder plus the folders
    // that contain it, so a match keeps its place in the tree. Each row gains `matches`.
    function filter_rows(rows, query) {
        var needle = (query || '').trim().toLowerCase();
        if (!needle) {
            return rows.map(function (row) {
                return Object.assign({}, row, { matches: true });
            });
        }

        var matching = rows.filter(function (row) {
            return row.title.toLowerCase().indexOf(needle) !== -1;
        });
        var shown = new Set();
        matching.forEach(function (row) {
            shown.add(row.value);
            row.ancestors.forEach(function (ancestor) {
                shown.add(ancestor);
            });
        });

        return rows.filter(function (row) {
            return shown.has(row.value);
        }).map(function (row) {
            return Object.assign({}, row, { matches: contains(matching, row) });
        });
    }

    function first_match(rows) {
        var row = rows.find(function (row) {
            return row.matches && !row.disabled;
        });
        return row ? row.value : null;
    }

    // Arrow keys move the highlight through enabled rows and stop at either end.
    function next_highlight(rows, current, direction) {
        var enabled = rows.filter(function (row) {
            return !row.disabled;
        }).map(function (row) {
            return row.value;
        });
        if (!enabled.length) return null;

        var index = enabled.indexOf(current);
        if (index === -1) {
            return direction > 0 ? enabled[0] : enabled[enabled.length - 1];
        }
        var next = Math.max(0, Math.min(enabled.length - 1, index + direction));
        return enabled[next];
    }

    // Show every folder when the window has room, never more than the folders need,
    // and keep a few rows visible even when the menu already fills a short window.
    function list_height(options) {
        var height = Math.min(options.content_height, options.available_height);
        var floor = Math.min(options.content_height, options.min_height);
        return Math.max(height, floor);
    }

    // Where the menu's top goes once the picker adds `grow` pixels. A menu that opens
    // downward keeps its top, one that opens upward (inverse) keeps its bottom on the item,
    // and either one slides just enough to stay inside the window.
    function menu_top(options) {
        var new_height = options.height + options.grow;
        var top = options.inverse ? options.top - options.grow : options.top;
        var max_top = options.window_height - options.margin - new_height;

        top = Math.min(top, max_top);
        top = Math.max(top, options.margin);
        return top;
    }

    return {
        build_rows: build_rows,
        choose_folder: choose_folder,
        inside_moving_folder: inside_moving_folder,
        filter_rows: filter_rows,
        first_match: first_match,
        list_height: list_height,
        menu_top: menu_top,
        next_highlight: next_highlight,
        save_state: save_state,
        toggle_folder: toggle_folder
    };
});
