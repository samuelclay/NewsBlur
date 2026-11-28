// reader_organizer_ai.js: the "Reorganize with AI" tab of the Organize sites dialog
// (reader_organizer.js). The AI proposes a new arrangement of the reader's sites and folders, the
// reader approves or rejects each change, and the approved changes are applied, all through
// apps/reorganize/views.py. A proposal is made in the background by apps/reorganize/tasks.py. Its
// progress arrives over the socket (handle_reorganize_event in reader.js), and the tab also polls
// while a run works in case the socket is down.
//
// The tab shows one screen at a time, picked from the current proposal's status by current_screen():
// setup, progress, review, confirm or applied. Each screen is built by its own make_*_screen method.

NEWSBLUR.ReaderOrganizerAI = function (organizer) {
    this.organizer = organizer;
    this.model = NEWSBLUR.assets;
    this.limits = null;
    this.locks = { keep: [], skip: [] };
    this.proposal = null;
    this.form = { level: 'reorganize', find_dead: true, instructions: '' };
    this.screen = null;
    this.error_code = null;
    this.revisiting_setup = false;
    this.proposing = false;
    this.closed = false;
    this.poll_timer = null;
    this.pending_lock_saves = 0;
    this.lock_save_count = 0;
    this.folder_rows = [];

    // The review: the reader's decisions on proposal `decisions_for`, with what is still to be sent.
    this.review = null;
    this.decisions = null;
    this.decisions_for = null;
    this.pending_changes = null;
    this.saving_decisions = false;
    this.save_waiters = [];
    this.review_view = 'folders';
    this.review_filter = 'all';
    this.review_error = null;
    this.revise_text = '';
    this.revise_error = null;
    this.revising = false;

    // Applying and undoing: the confirm screen, the requests in flight, and the applied screen's state.
    this.confirming = false;
    this.confirm_plan = null;
    this.applying = false;
    this.undoing = false;
    this.asking_undo = false;
    this.showing_skipped = false;
    this.review_scroll = 0;

    this.$steps = this.make_steps();
    this.$notice = $.make('div', { className: 'NB-organizer-ai-notice NB-hidden' });
    this.$screen = $.make('div', { className: 'NB-organizer-ai-screen' });
    this.$tab = $.make('div', { className: 'NB-tab NB-tab-ai NB-organizer-ai' }, [
        this.$steps,
        this.$notice,
        this.$screen
    ]);

    this.$tab.bind('click', $.rescope(this.handle_click, this));
    this.$tab.bind('change', $.rescope(this.handle_change, this));
    this.$tab.bind('input', $.rescope(this.handle_input, this));
    this.$tab.bind('keydown', $.rescope(this.handle_keydown, this));
};

_.extend(NEWSBLUR.ReaderOrganizerAI, {

    POLL_INTERVAL: 4000,

    INSTRUCTIONS_LIMIT: 4000,

    // UNDO_DAYS in apps/reorganize/apply.py: how long an applied proposal can be undone.
    UNDO_DAYS: 30,

    OUTCOME_CLASSES: 'NB-organizer-ai-row-move NB-organizer-ai-row-both NB-organizer-ai-row-ask NB-organizer-ai-row-stay'

});

// ==================
// = Decision rules =
// ==================
//
// What the reader's decisions do, worked out the way apps/reorganize/plan.py works them out, so the
// review screen shows what applying will do. resolve() is resolve_decisions(), plan() follows
// _Applier.run() step by step, and merge_decisions() is merge_decisions() in
// apps/reorganize/decisions.py. They read and touch nothing but their arguments.
//
// A tree is the reader's folders as [{path, feed_ids}] in stored order: the top level first with an
// empty path, then every folder, with the feeds directly in it.

NEWSBLUR.ReaderOrganizerAI.Rules = (function () {

    var ROOT_KEY = 'root';
    var OP_TYPES = ['create', 'rename', 'nest', 'merge', 'remove'];
    var DEAD_ACTIONS = ['keep', 'mute', 'unsubscribe'];
    var RESERVED_FOLDER_NAMES = ['global', 'infrequent', 'blurblogs', 'read', 'all', 'everything',
        'starred', 'searches', 'river_blurblog'];

    // Reasons a change does not happen, as plan.py names them, and "empty" for a new folder that
    // would end up with nothing in it.
    var INVALID = 'invalid';
    var FOLDER_CHANGED = 'folder_changed';
    var FEED_NOT_IN_FOLDER = 'feed_not_in_folder';
    var LOCKED = 'locked';
    var NAME_TAKEN = 'name_taken';
    var WOULD_CYCLE = 'would_cycle';
    var NOT_EMPTY = 'not_empty';
    var FOLDER_REJECTED = 'folder_rejected';
    var EMPTY = 'empty';

    var as_dict = function (value) {
        return value && _.isObject(value) && !_.isArray(value) ? value : {};
    };

    var is_feed_id = function (value) {
        return typeof value == 'number' && Math.floor(value) === value;
    };

    var is_existing_key = function (key) {
        return _.isString(key) && /^e\d+$/.test(key);
    };

    var is_new_key = function (key) {
        return _.isString(key) && /^n\d+$/.test(key);
    };

    var is_valid_path = function (path) {
        return _.isArray(path) && path.length > 0 && _.all(path, _.isString);
    };

    var clean_folder_name = function (name) {
        if (!_.isString(name)) return null;
        name = name.trim();
        if (!name || name.indexOf('river:') != -1 || name.indexOf(' - ') != -1 || name.toLowerCase() == 'top level') {
            return null;
        }
        return _.contains(RESERVED_FOLDER_NAMES, name) ? null : name;
    };

    // The entries of a proposal section that have a string id, first occurrence only.
    var entries = function (proposal, section) {
        var seen = {};
        return _.filter(_.isArray(as_dict(proposal)[section]) ? proposal[section] : [], function (entry) {
            if (!_.isObject(entry) || !_.isString(entry.id) || _.has(seen, entry.id)) return false;
            seen[entry.id] = true;
            return true;
        });
    };

    var lock_for = function (path, locks) {
        path = path || [];
        if (!path.length) return null;
        var covers = function (locked_path) {
            return is_valid_path(locked_path) && locked_path.length <= path.length &&
                _.isEqual(path.slice(0, locked_path.length), locked_path);
        };
        locks = as_dict(locks);
        if (_.any(_.isArray(locks.skip) ? locks.skip : [], covers)) return 'skip';
        if (_.any(_.isArray(locks.keep) ? locks.keep : [], covers)) return 'keep';
        return null;
    };

    var recorded_path = function (folder_entries, key) {
        if (is_existing_key(key)) {
            var path = as_dict(folder_entries[key]).path;
            if (is_valid_path(path)) return path.slice();
        }
        return [];
    };

    var move_outcome = function (arrive, leave, source_lock) {
        if (arrive === false || source_lock == 'skip') return 'stay';
        // A copy only ever happens on an explicit accept.
        if (leave === false || source_lock == 'keep') return arrive === true ? 'both' : 'ask';
        return 'move';
    };

    var dead_action = function (entry, decision) {
        if (_.contains(DEAD_ACTIONS, decision)) return decision;
        return entry.suggest == 'mute' ? 'mute' : null;
    };

    // New folder keys whose create, or the create of a new folder around them, is rejected or missing.
    var rejected_new_folders = function (proposal, ops_approved) {
        var create_ids = {};
        _.each(entries(proposal, 'ops'), function (entry) {
            if (entry.type == 'create' && !_.has(create_ids, entry.folder)) create_ids[entry.folder] = entry.id;
        });
        var new_entries = {};
        _.each(as_dict(proposal.folders), function (entry, key) {
            if (is_new_key(key)) new_entries[key] = entry;
        });

        var rejected = {};
        _.each(_.keys(new_entries), function (key) {
            var current = key;
            var seen = {};
            while (is_new_key(current) && !seen[current]) {
                seen[current] = true;
                var op_id = create_ids[current];
                if (op_id === undefined || ops_approved[op_id] === false) {
                    rejected[key] = true;
                    break;
                }
                current = as_dict(new_entries[current]).parent;
            }
        });
        return rejected;
    };

    var feeds_in_locked_folders = function (tree, locks) {
        var feeds = {};
        _.each(tree, function (folder) {
            if (folder.path.length && lock_for(folder.path, locks)) {
                _.each(folder.feed_ids, function (feed_id) { feeds[feed_id] = true; });
            }
        });
        return feeds;
    };

    // resolve_decisions() in apps/reorganize/plan.py: moves resolve to "move", "both", "ask" (nothing
    // until a copy is accepted) or "stay", ops to whether they are approved, and dead sites to "keep",
    // "mute", "unsubscribe" or null.
    var resolve = function (proposal, decisions, tree, locks) {
        proposal = as_dict(proposal);
        decisions = as_dict(decisions);
        var op_decisions = as_dict(decisions.ops);
        var move_decisions = as_dict(decisions.moves);
        var dead_decisions = as_dict(decisions.dead);
        var folder_entries = as_dict(proposal.folders);

        var ops = {};
        _.each(entries(proposal, 'ops'), function (entry) {
            ops[entry.id] = op_decisions[entry.id] !== false;
        });
        var rejected_folders = rejected_new_folders(proposal, ops);

        var moves = {};
        _.each(entries(proposal, 'moves'), function (entry) {
            var decision = as_dict(move_decisions[entry.id]);
            if (_.isString(entry.to) && rejected_folders[entry.to]) {
                moves[entry.id] = 'stay';
                return;
            }
            var source_lock = lock_for(recorded_path(folder_entries, entry.from), locks);
            moves[entry.id] = move_outcome(decision.arrive, decision.leave, source_lock);
        });

        var locked_feeds = feeds_in_locked_folders(tree, locks);
        var dead = {};
        _.each(entries(proposal, 'dead'), function (entry) {
            dead[entry.id] = locked_feeds[entry.feed_id] ? null : dead_action(entry, dead_decisions[entry.id]);
        });

        return { moves: moves, ops: ops, dead: dead };
    };

    // merge_decisions() in apps/reorganize/decisions.py: `changes` holds only what changed. A move
    // side set to null clears it, an op set to null or true clears its rejection, and a dead site set
    // to null clears its choice. Ids that are not in the proposal are dropped.
    var merge_decisions = function (stored, changes, proposal) {
        var ids = {};
        var merged = { ops: {}, moves: {}, dead: {} };
        _.each(['ops', 'moves', 'dead'], function (section) {
            ids[section] = {};
            _.each(entries(proposal, section), function (entry) { ids[section][entry.id] = true; });
        });

        _.each(merged, function (entries_out, section) {
            _.each(as_dict(as_dict(stored)[section]), function (value, entry_id) {
                if (ids[section][entry_id]) set_choice(entries_out, section, entry_id, value);
            });
        });
        _.each(merged, function (entries_out, section) {
            _.each(as_dict(as_dict(changes)[section]), function (change, entry_id) {
                if (ids[section][entry_id]) change_choice(entries_out, section, entry_id, change);
            });
        });
        return merged;
    };

    var set_choice = function (entries_out, section, entry_id, value) {
        if (section == 'moves') {
            var sides = {};
            _.each(['arrive', 'leave'], function (side) {
                if (_.isBoolean(as_dict(value)[side])) sides[side] = value[side];
            });
            if (_.size(sides)) entries_out[entry_id] = sides;
        } else if (section == 'ops') {
            if (value === false) entries_out[entry_id] = false;
        } else if (_.contains(DEAD_ACTIONS, value)) {
            entries_out[entry_id] = value;
        }
    };

    var change_choice = function (entries_out, section, entry_id, change) {
        if (section == 'moves') {
            if (!_.isObject(change) || _.isArray(change)) return;
            var sides = _.extend({}, entries_out[entry_id]);
            _.each(['arrive', 'leave'], function (side) {
                if (!_.has(change, side)) return;
                if (change[side] === null) {
                    delete sides[side];
                } else if (_.isBoolean(change[side])) {
                    sides[side] = change[side];
                }
            });
            if (_.size(sides)) {
                entries_out[entry_id] = sides;
            } else {
                delete entries_out[entry_id];
            }
        } else if (section == 'ops') {
            if (change === false) {
                entries_out[entry_id] = false;
            } else if (change === null || change === true) {
                delete entries_out[entry_id];
            }
        } else if (change === null) {
            delete entries_out[entry_id];
        } else if (_.contains(DEAD_ACTIONS, change)) {
            entries_out[entry_id] = change;
        }
    };

    // One folder of the tree plan() works on, as _Folder in plan.py.
    var Node = function (name, id) {
        this.id = id;
        this.name = name;
        this.parent = null;
        this.feeds = [];
        this.children = [];
        this.dropped_path = null;
    };

    Node.prototype = {
        path: function () {
            var names = [];
            for (var folder = this; folder.parent; folder = folder.parent) names.unshift(folder.name);
            return names;
        },
        top: function () {
            var folder = this;
            while (folder.parent) folder = folder.parent;
            return folder;
        },
        is_within: function (other) {
            for (var folder = this; folder; folder = folder.parent) {
                if (folder === other) return true;
            }
            return false;
        },
        is_empty: function () {
            return !this.feeds.length && !this.children.length;
        },
        subfolder_named: function (name, ignore_case, excluding) {
            return _.find(this.children, function (child) {
                return child !== excluding && (child.name == name ||
                    (ignore_case && child.name.toLowerCase() == name.toLowerCase()));
            }) || null;
        },
        append: function (child) {
            child.parent = this;
            this.children.push(child);
        },
        detach: function () {
            this.parent.children = _.without(this.parent.children, this);
            this.parent = null;
        },
        walk: function (callback) {
            callback(this);
            _.each(this.children, function (child) { child.walk(callback); });
        }
    };

    // What applying `proposal` with `decisions` under `locks` does to `tree`, following _Applier in
    // apps/reorganize/plan.py step by step. Returns:
    //   resolved: resolve()'s answer
    //   moves:   {id: {outcome, offered, happens}}
    //   ops:     {id: {approved, offered, happens, reason}}
    //   dead:    {id: {action, offered}}
    //   folders: [{id, key, name_before, name_after, place, before, after, arrivals, exists, fate, lock}]
    //            for the top level, every folder and every new folder, where `id` is
    //            JSON.stringify(original path) or the new folder's key, `place` its path after the
    //            changes (or where it was when it went), and `fate` null, "merged", "removed",
    //            "rejected" or "unplaced". A new folder with nothing in it is never made, so its fate
    //            is "unplaced".
    //   folder_ids: {proposal folder key: id}
    // `offered` is false for an item the locks or the folders as they are now rule out, which the
    // review leaves off the screen: moves out of a folder left out, moves and changes involving a
    // locked folder, and dead sites in a locked folder.
    var plan = function (proposal, decisions, tree, locks) {
        proposal = as_dict(proposal);
        decisions = as_dict(decisions);
        var folder_entries = as_dict(proposal.folders);
        var resolved = resolve(proposal, decisions, tree, locks);
        var move_decisions = as_dict(decisions.moves);
        var dead_decisions = as_dict(decisions.dead);

        // The tree, merging same-named sibling folders as plan.py's _load_items does.
        var root = new Node(null, '[]');
        var originals = [];
        var find = function (path) {
            var folder = root;
            for (var i = 0; i < path.length && folder; i++) folder = folder.subfolder_named(path[i]);
            return folder;
        };
        _.each(tree, function (entry) {
            var folder = root;
            _.each(entry.path, function (name) {
                var child = folder.subfolder_named(name);
                if (!child) {
                    child = new Node(name, JSON.stringify(folder.path().concat([name])));
                    folder.append(child);
                    originals.push(child);
                }
                folder = child;
            });
            _.each(entry.feed_ids, function (feed_id) {
                if (!_.contains(folder.feeds, feed_id)) folder.feeds.push(feed_id);
            });
        });

        var info = {};
        var feeds_before = {};
        var locked = {};
        root.walk(function (folder) {
            var path = folder.path();
            info[folder.id] = { path: path, feeds: folder.feeds.slice(), lock: lock_for(path, locks) };
            if (info[folder.id].lock) locked[folder.id] = info[folder.id].lock;
            _.each(folder.feeds, function (feed_id) { feeds_before[feed_id] = true; });
        });
        var is_locked = function (folder) { return _.has(locked, folder.id); };
        var holds_lock = function (folder) {
            return _.any(originals, function (other) { return is_locked(other) && other.is_within(folder); });
        };
        var attached = function (folder) { return folder.top() === root; };

        var validated = function (section) {
            var seen = {};
            return _.filter(_.isArray(proposal[section]) ? proposal[section] : [], function (entry) {
                if (!_.isObject(entry) || !_.isString(entry.id)) return false;
                if (_.has(seen, entry.id) || (section == 'ops' && !_.contains(OP_TYPES, entry.type))) return false;
                seen[entry.id] = true;
                return true;
            });
        };
        var section_entries = { ops: validated('ops'), moves: validated('moves'), dead: validated('dead') };
        var op_result = {};
        var skip = function (entry, reason) { op_result[entry.id] = reason; };

        var existing = {};
        _.each(folder_entries, function (entry, key) {
            if (!is_existing_key(key)) return;
            var path = as_dict(entry).path;
            if (!is_valid_path(path)) {
                existing[key] = [null, INVALID];
            } else {
                var folder = find(path);
                existing[key] = folder ? [folder, null] : [null, FOLDER_CHANGED];
            }
        });
        var new_folders = {};
        var node_for = function (key) {
            var found;
            if (key == ROOT_KEY) return [root, null];
            if (is_existing_key(key) && _.has(existing, key)) {
                found = existing[key];
            } else if (is_new_key(key) && _.has(new_folders, key)) {
                found = new_folders[key];
            } else {
                return [null, INVALID];
            }
            if (found[0] && !attached(found[0])) return [null, FOLDER_CHANGED];
            return found;
        };
        var existing_node = function (key) {
            return is_existing_key(key) ? node_for(key) : [null, INVALID];
        };

        // Creates
        var create_ops = {};
        var created = [];
        _.each(section_entries.ops, function (entry) {
            if (entry.type != 'create') return;
            var key = entry.folder;
            if (!is_new_key(key) || _.has(create_ops, key) || !_.isObject(folder_entries[key])) {
                skip(entry, INVALID);
            } else {
                create_ops[key] = entry;
            }
        });
        var place_new_folder = function (key, visiting) {
            var entry = folder_entries[key];
            var name = clean_folder_name(entry.name);
            if (name === null) return [null, INVALID];
            var parent_key = entry.parent;
            if (is_new_key(parent_key) && visiting[parent_key]) return [null, WOULD_CYCLE];
            var parent_found = is_new_key(parent_key) ? create(parent_key, visiting) : node_for(parent_key);
            var parent = parent_found[0];
            if (!parent) return [null, parent_found[1]];
            if (is_locked(parent)) return [null, LOCKED];
            var sibling = parent.subfolder_named(name, true);
            if (sibling) return [sibling, null];
            var folder = new Node(name, key);
            parent.append(folder);
            created.push([key, folder]);
            return [folder, null];
        };
        var create = function (key, visiting) {
            if (_.has(new_folders, key)) return new_folders[key];
            var entry = create_ops[key];
            var outcome;
            if (!entry) {
                outcome = [null, INVALID];
            } else if (resolved.ops[entry.id] === false) {
                outcome = [null, FOLDER_REJECTED];
            } else {
                var inner = _.clone(visiting);
                inner[key] = true;
                outcome = place_new_folder(key, inner);
                if (!outcome[0]) skip(entry, outcome[1]);
            }
            new_folders[key] = outcome;
            return outcome;
        };
        _.each(_.keys(create_ops), function (key) { create(key, {}); });

        // Moves: every placement leaves before any arrives.
        var move_results = {};
        var planned = [];
        var placements = {};
        _.each(section_entries.moves, function (entry) {
            var feed_id = entry.feed_id;
            var source_found = node_for(entry.from);
            var destination_found = node_for(entry.to);
            var source = source_found[0];
            var destination = destination_found[0];
            move_results[entry.id] = false;
            if (!is_feed_id(feed_id) || is_new_key(entry.from) ||
                source_found[1] == INVALID || destination_found[1] == INVALID) {
                return;
            }
            var outcome = resolved.moves[entry.id];
            if (outcome != 'move' && outcome != 'both') return;
            if (!source || !destination) return;
            if (source === destination || placements[feed_id + ':' + source.id]) return;
            if (!_.contains(source.feeds, feed_id)) return;
            if (is_locked(destination) || (outcome == 'move' && is_locked(source))) return;
            placements[feed_id + ':' + source.id] = true;
            planned.push({ id: entry.id, feed_id: feed_id, source: source, destination: destination, outcome: outcome });
        });
        _.each(planned, function (placement) {
            if (placement.outcome == 'move') placement.source.feeds = _.without(placement.source.feeds, placement.feed_id);
        });
        var arrivals = {};
        _.each(planned, function (placement) {
            var already_there = _.contains(placement.destination.feeds, placement.feed_id);
            if (!already_there) {
                placement.destination.feeds.push(placement.feed_id);
                arrivals[placement.destination.id] = (arrivals[placement.destination.id] || []).concat([placement.feed_id]);
            }
            move_results[placement.id] = placement.outcome == 'move' || !already_there;
        });

        // Dead sites
        var seen_dead = {};
        var unsubscribed = {};
        _.each(section_entries.dead, function (entry) {
            var feed_id = entry.feed_id;
            if (!is_feed_id(feed_id) || seen_dead[feed_id]) return;
            seen_dead[feed_id] = true;
            var action = resolved.dead[entry.id];
            var wanted = dead_action(entry, dead_decisions[entry.id]);
            if ((wanted == 'mute' || wanted == 'unsubscribe') && (!feeds_before[feed_id] || action === null)) return;
            if (action == 'unsubscribe') {
                root.walk(function (folder) { folder.feeds = _.without(folder.feeds, feed_id); });
                unsubscribed[feed_id] = true;
            }
        });

        var approved_ops = function (type) {
            return _.filter(section_entries.ops, function (entry) {
                return entry.type == type && resolved.ops[entry.id] !== false;
            });
        };
        var happened = {};
        var drop = function (folder) {
            folder.dropped_path = folder.path();
            folder.detach();
        };

        _.each(approved_ops('rename'), function (entry) {
            var found = existing_node(entry.folder);
            var folder = found[0];
            var name = clean_folder_name(entry.name);
            if (!folder) return skip(entry, found[1]);
            if (name === null) return skip(entry, INVALID);
            if (holds_lock(folder)) return skip(entry, LOCKED);
            if (name == folder.name) return;
            if (folder.parent.subfolder_named(name, true, folder)) return skip(entry, NAME_TAKEN);
            folder.name = name;
            happened[entry.id] = true;
        });

        _.each(approved_ops('nest'), function (entry) {
            var found = existing_node(entry.folder);
            var parent_found = node_for(entry.parent);
            var folder = found[0];
            var parent = parent_found[0];
            if (!folder || !parent) return skip(entry, found[1] || parent_found[1]);
            if (holds_lock(folder) || is_locked(parent)) return skip(entry, LOCKED);
            if (parent.is_within(folder)) return skip(entry, WOULD_CYCLE);
            if (parent === folder.parent) return;
            if (parent.subfolder_named(folder.name, true)) return skip(entry, NAME_TAKEN);
            folder.detach();
            parent.append(folder);
            happened[entry.id] = true;
        });

        var merged = {};
        _.each(approved_ops('merge'), function (entry) {
            var found = existing_node(entry.folder);
            var into_found = node_for(entry.into);
            var folder = found[0];
            var into = into_found[0];
            if (!folder || !into) return skip(entry, found[1] || into_found[1]);
            if (into === folder) return skip(entry, INVALID);
            if (holds_lock(folder) || is_locked(into)) return skip(entry, LOCKED);
            if (into.is_within(folder)) return skip(entry, WOULD_CYCLE);
            if (folder.feeds.length) return skip(entry, NOT_EMPTY);
            var names = _.map(folder.children, function (child) { return child.name.toLowerCase(); });
            var clash = _.uniq(names).length != names.length || _.any(names, function (child_name) {
                return into.subfolder_named(child_name, true, folder);
            });
            if (clash) return skip(entry, NAME_TAKEN);
            _.each(folder.children.slice(), function (child) {
                child.detach();
                into.append(child);
            });
            merged[folder.id] = true;
            happened[entry.id] = true;
            drop(folder);
        });

        var deepest_first = function (pairs) {
            return _.sortBy(pairs, function (pair) { return -pair[1].path().length; });
        };
        var prune_empty_new_folders = function () {
            _.each(deepest_first(created), function (pair) {
                if (attached(pair[1]) && pair[1].is_empty()) drop(pair[1]);
            });
        };
        prune_empty_new_folders();

        var removed = {};
        var candidates = [];
        _.each(approved_ops('remove'), function (entry) {
            var found = existing_node(entry.folder);
            if (!found[0]) return skip(entry, found[1]);
            candidates.push([entry, found[0]]);
        });
        _.each(deepest_first(candidates), function (pair) {
            var entry = pair[0];
            var folder = pair[1];
            if (!attached(folder)) return skip(entry, FOLDER_CHANGED);
            if (holds_lock(folder)) return skip(entry, LOCKED);
            if (!folder.is_empty()) return skip(entry, NOT_EMPTY);
            removed[folder.id] = true;
            happened[entry.id] = true;
            drop(folder);
        });
        prune_empty_new_folders();

        _.each(created, function (pair) {
            var entry = create_ops[pair[0]];
            if (attached(pair[1])) {
                happened[entry.id] = true;
            } else if (!_.has(op_result, entry.id)) {
                op_result[entry.id] = EMPTY;
            }
        });

        // Whether each item is on offer under the locks and with the folders as they are now.
        var start_node = function (key) {
            if (key == ROOT_KEY) return root;
            return (is_existing_key(key) && existing[key] && existing[key][0]) || null;
        };
        var placeable = function (key, visiting) {
            visiting = visiting || {};
            if (!is_new_key(key)) {
                var folder = start_node(key);
                return !!folder && !is_locked(folder);
            }
            var entry = folder_entries[key];
            if (!_.isObject(entry) || visiting[key] || clean_folder_name(entry.name) === null) return false;
            visiting[key] = true;
            return placeable(entry.parent, visiting);
        };
        var offered_ops = {};
        _.each(section_entries.ops, function (entry) {
            var folder = start_node(entry.folder);
            var offered;
            if (entry.type == 'create') {
                offered = create_ops[entry.folder] === entry && placeable(entry.folder);
            } else {
                offered = !!folder && folder !== root && !holds_lock(folder);
                if (entry.type == 'nest') offered = offered && placeable(entry.parent);
                if (entry.type == 'merge') offered = offered && placeable(entry.into);
            }
            offered_ops[entry.id] = offered;
        });

        var result = { resolved: resolved, moves: {}, ops: {}, dead: {}, folders: [], folder_ids: {} };
        _.each(entries(proposal, 'moves'), function (entry) {
            var source = start_node(entry.from);
            var offered = is_feed_id(entry.feed_id) && !!source && locked[source.id] != 'skip' &&
                _.contains(info[source.id].feeds, entry.feed_id) && placeable(entry.to) &&
                start_node(entry.to) !== source;
            result.moves[entry.id] = {
                outcome: resolved.moves[entry.id],
                offered: offered,
                happens: !!move_results[entry.id]
            };
        });
        _.each(entries(proposal, 'ops'), function (entry) {
            result.ops[entry.id] = {
                approved: resolved.ops[entry.id],
                offered: !!offered_ops[entry.id],
                happens: !!happened[entry.id],
                reason: op_result[entry.id] || null
            };
        });
        var locked_feeds = feeds_in_locked_folders(tree, locks);
        _.each(entries(proposal, 'dead'), function (entry) {
            result.dead[entry.id] = {
                action: resolved.dead[entry.id],
                offered: is_feed_id(entry.feed_id) && !!feeds_before[entry.feed_id] && !locked_feeds[entry.feed_id]
            };
        });

        var describe = function (folder, id, key) {
            var is_original = _.has(info, folder.id) && folder.id == id;
            var is_attached = attached(folder);
            var after = is_attached ? folder.feeds.length : 0;
            var arriving = _.filter(arrivals[folder.id] || [], function (feed_id) { return !unsubscribed[feed_id]; }).length;
            var fate = null;
            if (!is_attached) fate = merged[folder.id] ? 'merged' : removed[folder.id] ? 'removed' : 'unplaced';
            return {
                id: id,
                key: key || null,
                is_new: !is_original,
                name_before: is_original ? _.last(info[folder.id].path) || null : null,
                name_after: folder.name,
                place: is_attached ? folder.path() : folder.dropped_path || folder.path(),
                before: is_original ? info[folder.id].feeds.length : 0,
                after: after,
                arrivals: arriving,
                exists: is_attached,
                fate: fate,
                lock: is_original ? info[folder.id].lock : null
            };
        };
        var key_for_original = {};
        _.each(existing, function (found, key) {
            if (found[0]) {
                result.folder_ids[key] = found[0].id;
                if (!_.has(key_for_original, found[0].id)) key_for_original[found[0].id] = key;
            }
        });
        result.folder_ids[ROOT_KEY] = root.id;
        result.folders.push(describe(root, root.id, ROOT_KEY));
        _.each(originals, function (folder) {
            result.folders.push(describe(folder, folder.id, key_for_original[folder.id]));
        });
        _.each(folder_entries, function (entry, key) {
            if (!is_new_key(key)) return;
            var found = new_folders[key];
            if (found && found[0] && found[0].id != key) {
                // A new folder whose name an existing folder beside it already has is that folder.
                result.folder_ids[key] = found[0].id;
                return;
            }
            result.folder_ids[key] = key;
            if (found && found[0]) {
                result.folders.push(describe(found[0], key, key));
            } else {
                var parent_id = result.folder_ids[as_dict(entry).parent];
                var parent_place = _.find(result.folders, function (folder) { return folder.id == parent_id; });
                result.folders.push({
                    id: key,
                    key: key,
                    is_new: true,
                    name_before: null,
                    name_after: clean_folder_name(as_dict(entry).name) || '',
                    place: (parent_place ? parent_place.place : []).concat([clean_folder_name(as_dict(entry).name) || '']),
                    before: 0,
                    after: 0,
                    arrivals: 0,
                    exists: false,
                    fate: found && found[1] == FOLDER_REJECTED ? 'rejected' : 'unplaced',
                    lock: null
                });
            }
        });
        return result;
    };

    // Unsent changes followed by newer ones, as one change. A later value wins, including null,
    // which clears a choice.
    var combine_changes = function (earlier, later) {
        earlier = earlier || {};
        var combined = {
            ops: _.extend({}, earlier.ops, later.ops),
            moves: _.extend({}, earlier.moves),
            dead: _.extend({}, earlier.dead, later.dead)
        };
        _.each(later.moves, function (sides, move_id) {
            combined.moves[move_id] = _.extend({}, combined.moves[move_id], sides);
        });
        return combined;
    };

    // Folder paths in reading order: name by name with `collator`, a folder before those inside it.
    var compare_places = function (collator, a, b) {
        for (var i = 0; i < Math.min(a.length, b.length); i++) {
            var order = collator.compare(a[i], b[i]);
            if (order) return order;
        }
        return a.length - b.length;
    };

    return {
        ROOT_KEY: ROOT_KEY,
        is_new_key: is_new_key,
        resolve: resolve,
        plan: plan,
        merge_decisions: merge_decisions,
        combine_changes: combine_changes,
        compare_places: compare_places
    };

})();

NEWSBLUR.ReaderOrganizerAI.prototype = {

    // ==========
    // = Status =
    // ==========

    open: function () {
        this.load_status();
    },

    close: function () {
        this.closed = true;
        this.stop_polling();
    },

    load_status: function (options) {
        options = options || {};
        if (this.closed) return;
        if (!options.quiet) this.set_loading(true);
        this.model.reorganize_status(_.bind(function (data) {
            this.set_loading(false);
            this.update(data);
        }, this), _.bind(function () {
            this.set_loading(false);
            if (this.screen) {
                this.update_polling();
            } else {
                this.show_status_error();
            }
        }, this));
    },

    // Takes the response of status, propose, revise, apply or undo, using whichever of limits,
    // locks and proposal it carries.
    update: function (data) {
        if (this.closed) return;
        if (data.limits) this.limits = data.limits;
        if (data.locks && !this.pending_lock_saves) this.locks = data.locks;
        if (_.has(data, 'proposal')) this.set_proposal(data.proposal);
        this.render();
    },

    set_proposal: function (proposal) {
        var previous = this.proposal;
        var changed = !previous || !proposal || previous.id != proposal.id || previous.status != proposal.status;
        if (!changed && proposal.status == 'working') {
            proposal.progress = this.newer_progress(previous.progress, proposal.progress);
        }
        if (changed) {
            this.revisiting_setup = false;
            this.confirming = false;
            this.asking_undo = false;
            this.showing_skipped = false;
            if (proposal && proposal.status == 'failed') this.prefill_form(proposal);
            // A revision that fails leaves the proposal it revised as the current one, so its error
            // belongs beside the revise box.
            if (previous && previous.revises && previous.status == 'working' && proposal &&
                proposal.id == previous.revises && proposal.status == 'ready') {
                this.revise_error = this.error_code || 'run_failed';
                this.error_code = null;
            }
        }
        this.proposal = proposal;
    },

    // A failed run's settings, so trying again starts from what the reader asked for.
    prefill_form: function (proposal) {
        this.form = {
            level: proposal.level || 'reorganize',
            find_dead: !!proposal.find_dead,
            instructions: proposal.instructions || ''
        };
    },

    current_screen: function () {
        var status = this.proposal && this.proposal.status;
        if (status == 'working') return 'progress';
        if (status == 'ready' && !this.revisiting_setup) return this.confirming ? 'confirm' : 'review';
        if ((status == 'applying' || status == 'applied') && !this.revisiting_setup) return 'applied';
        return 'setup';
    },

    render: function () {
        var screen = this.current_screen();
        if (screen == 'progress' && this.screen == 'progress' && this.progress_id == this.proposal.id) {
            this.update_progress();
        } else if (screen == 'review' && this.screen == 'review' && this.review && this.review.proposal_id == this.proposal.id) {
            this.refresh_review_from_server();
        } else {
            this.show_screen(screen);
        }
        this.update_polling();
    },

    show_screen: function (screen) {
        var makers = {
            'setup': this.make_setup_screen,
            'progress': this.make_progress_screen,
            'review': this.make_review_screen,
            'confirm': this.make_confirm_screen,
            'applied': this.make_applied_screen
        };
        this.screen = screen;
        this.$screen.empty().append(makers[screen].call(this));
        this.update_steps();
        this.organizer.resize();
    },

    show_status_error: function () {
        this.$screen.empty().append($.make('div', { className: 'NB-organizer-ai-center' }, [
            $.make('p', { className: 'NB-organizer-ai-error', role: 'alert' }, gettext("Couldn't load Reorganize with AI.")),
            $.make('button', { type: 'button', className: 'NB-modal-submit-button NB-modal-submit-grey NB-organizer-ai-retry' }, gettext('Try again'))
        ]));
        this.organizer.resize();
    },

    set_loading: function (loading) {
        $('.NB-modal-loading', this.organizer.$modal).toggleClass('NB-active', loading);
    },

    // ===========
    // = Polling =
    // ===========

    update_polling: function () {
        if (!this.closed && this.proposal && this.proposal.status == 'working') {
            this.start_polling();
        } else {
            this.stop_polling();
        }
    },

    start_polling: function () {
        if (this.poll_timer) return;
        this.poll_timer = setTimeout(_.bind(function () {
            this.poll_timer = null;
            this.load_status({ quiet: true });
        }, this), NEWSBLUR.ReaderOrganizerAI.POLL_INTERVAL);
    },

    stop_polling: function () {
        clearTimeout(this.poll_timer);
        this.poll_timer = null;
    },

    // ==========
    // = Socket =
    // ==========

    // Events from reader.js for the proposal on screen. Events for any other proposal are ignored.
    handle_event: function (event_type, data) {
        if (this.closed || !data || !this.proposal || data.proposal_id != this.proposal.id) return;

        if (event_type == 'progress') {
            this.proposal.progress = this.newer_progress(this.proposal.progress, {
                step: data.step,
                done: data.done,
                total: data.total
            });
            if (this.screen == 'progress') this.update_progress();
        } else if (event_type == 'ready') {
            this.load_status();
        } else if (event_type == 'error') {
            this.error_code = data.code || 'run_failed';
            this.load_status();
        }
    },

    // A poll that started before a socket event can answer after it, so progress never goes back.
    newer_progress: function (current, incoming) {
        if (!current) return incoming || null;
        if (!incoming) return current;
        return incoming.done >= current.done ? incoming : current;
    },

    // =========
    // = Steps =
    // =========

    make_steps: function () {
        var steps = [
            ['setup', gettext('Set up')],
            ['review', gettext('Review')],
            ['apply', gettext('Apply')]
        ];
        return $.make('ol', { className: 'NB-organizer-ai-steps' }, _.map(steps, function (step, index) {
            return $.make('li', { className: 'NB-organizer-ai-steps-item' }, [
                $.make('button', {
                    type: 'button',
                    className: 'NB-organizer-ai-step NB-organizer-ai-step-' + step[0],
                    'data-step': step[0],
                    disabled: 'disabled'
                }, [
                    $.make('span', { className: 'NB-organizer-ai-step-number' }, String(index + 1)),
                    $.make('span', { className: 'NB-organizer-ai-step-label' }, step[1])
                ])
            ]);
        }));
    },

    update_steps: function () {
        var current = { 'setup': 'setup', 'progress': 'setup', 'review': 'review', 'confirm': 'apply', 'applied': 'apply' }[this.screen];
        $('.NB-organizer-ai-step', this.$steps).each(_.bind(function (i, button) {
            var step = $(button).data('step');
            var is_current = step == current;
            $(button).toggleClass('NB-active', is_current)
                .attr('aria-current', is_current ? 'step' : null)
                .prop('disabled', !is_current && !this.can_visit_step(step));
        }, this));
    },

    // A ready proposal can be set aside to start again, and returned to from setup. So can an applied
    // one, from its applied screen. Nothing moves while an apply or undo is answering.
    can_visit_step: function (step) {
        var status = this.proposal && this.proposal.status;
        var is_ready = status == 'ready';
        var is_applied = status == 'applied';
        if (this.applying || this.undoing) return false;
        if (step == 'setup') {
            return (is_ready && (this.screen == 'review' || this.screen == 'confirm')) ||
                (is_applied && this.screen == 'applied');
        }
        if (step == 'review') return is_ready && (this.screen == 'setup' || this.screen == 'confirm');
        if (step == 'apply') return is_applied && this.screen == 'setup';
        return false;
    },

    visit_step: function (step) {
        if (!this.can_visit_step(step)) return;
        var from_confirm = this.screen == 'confirm';
        this.revisiting_setup = step == 'setup';
        this.confirming = false;
        this.asking_undo = false;
        this.clear_notice();
        this.render();
        if (from_confirm && step == 'review') this.restore_review_scroll();
    },

    // ================
    // = Setup screen =
    // ================

    make_setup_screen: function () {
        this.$folder_list = this.make_folder_list();
        this.$setup_notes = $.make('div', { className: 'NB-organizer-ai-notes' });
        this.$propose = $.make('button', {
            type: 'button',
            className: 'NB-modal-submit-button NB-modal-submit-green NB-organizer-ai-propose'
        }, gettext('Propose changes'));

        var $screen = $.make('div', { className: 'NB-organizer-ai-setup' }, [
            $.make('div', { className: 'NB-organizer-ai-setup-folders' }, [
                $.make('div', { className: 'NB-organizer-sidebar-title' }, gettext('Lock the folders the AI should leave alone')),
                this.$folder_list
            ]),
            $.make('div', { className: 'NB-organizer-ai-setup-options' }, [
                $.make('div', { className: 'NB-organizer-sidebar-title' }, gettext('How much to change')),
                $.make('div', { className: 'NB-organizer-sidebar-container NB-organizer-ai-levels', role: 'radiogroup', 'aria-label': gettext('How much to change') }, [
                    this.make_level('tidy', gettext('Tidy'), gettext('File sites into the folders you already have.')),
                    this.make_level('reorganize', gettext('Reorganize'), gettext('Also add, rename, merge, nest and remove folders.')),
                    this.make_level('fresh', gettext('Start fresh'), gettext('Propose a new set of folders. Locked folders still stay.'))
                ]),
                $.make('div', { className: 'NB-organizer-sidebar-title' }, gettext('Also look for')),
                $.make('div', { className: 'NB-organizer-sidebar-container' }, [
                    $.make('label', { className: 'NB-organizer-ai-check' }, [
                        $.make('input', {
                            type: 'checkbox',
                            className: 'NB-organizer-ai-find-dead',
                            checked: this.form.find_dead ? 'checked' : null
                        }),
                        $.make('span', gettext('Dead sites that stopped publishing or keep failing'))
                    ])
                ]),
                $.make('label', { className: 'NB-organizer-sidebar-title', 'for': 'NB-organizer-ai-instructions' }, gettext('Anything the AI should know')),
                $.make('div', { className: 'NB-organizer-sidebar-container' }, [
                    $.make('textarea', {
                        id: 'NB-organizer-ai-instructions',
                        className: 'NB-input NB-organizer-ai-instructions',
                        maxlength: NEWSBLUR.ReaderOrganizerAI.INSTRUCTIONS_LIMIT,
                        placeholder: gettext('Split Tech into smaller folders. No folder over 40 sites.')
                    }).val(this.form.instructions)
                ]),
                this.$propose,
                this.$setup_notes
            ])
        ]);
        this.update_setup_notes();
        return $screen;
    },

    make_level: function (level, title, description) {
        return $.make('label', { className: 'NB-organizer-ai-level' }, [
            $.make('input', {
                type: 'radio',
                name: 'NB-organizer-ai-level',
                value: level,
                className: 'NB-organizer-ai-level-input',
                checked: this.form.level == level ? 'checked' : null
            }),
            $.make('span', { className: 'NB-organizer-ai-level-text' }, [
                $.make('span', { className: 'NB-organizer-ai-level-title' }, title),
                $.make('span', { className: 'NB-organizer-ai-level-description' }, description)
            ])
        ]);
    },

    // The propose button's state and the lines under it: what is sent, the limits, and any error.
    update_setup_notes: function () {
        if (!this.$setup_notes) return;
        var site_count = this.count_sites();
        var limits = this.limits || {};
        var refusal = this.propose_refusal(site_count);
        var notes = [];

        var error = this.setup_error_code();
        if (error) {
            notes.push($.make('div', { className: 'NB-organizer-ai-error', role: 'alert' }).text(this.error_message(error)));
        }
        if (refusal) {
            notes.push($.make('p', { className: 'NB-organizer-ai-note NB-organizer-ai-note-limit' }).text(refusal));
        } else {
            notes.push($.make('p', { className: 'NB-organizer-ai-note' }).text(interpolate(ngettext(
                "Sends the names, addresses and recent headlines of %(count)s site to the AI model. Nothing changes until you approve it.",
                "Sends the names, addresses and recent headlines of %(count)s sites to the AI model. Nothing changes until you approve it.",
                site_count), { count: Inflector.commas(site_count) }, true)));
        }
        if (this.limits && !limits.can_apply && !refusal) {
            notes.push($.make('p', { className: 'NB-organizer-ai-note' }).text(this.monthly_limit_sentence(limits.limit)));
        }
        if (this.proposal && this.proposal.status == 'ready') {
            notes.push($.make('p', { className: 'NB-organizer-ai-note' }, gettext('Proposing again replaces the proposal you are reviewing.')));
        }
        // The dialog shows only the latest proposal (MReorganizeProposal.current in
        // apps/reorganize/models.py), so a new one takes the applied screen and its undo with it.
        if (this.proposal && this.proposal.status == 'applied' && this.proposal.can_undo) {
            notes.push($.make('p', { className: 'NB-organizer-ai-note' }, gettext('Once you propose again, your last reorganization can no longer be undone.')));
        }

        this.$setup_notes.empty().append(notes);
        this.$propose.toggleClass('NB-disabled', !!refusal || this.proposing)
            .prop('disabled', !!refusal || this.proposing)
            .text(this.proposing ? gettext('Proposing...') : gettext('Propose changes'));
    },

    setup_error_code: function () {
        if (this.error_code) return this.error_code;
        if (this.proposal && this.proposal.status == 'failed') return this.proposal.error || 'run_failed';
        return null;
    },

    // Why a proposal can't be started now, as a sentence, or null.
    propose_refusal: function (site_count) {
        var limits = this.limits;
        if (!limits) return gettext('Loading...');
        if (limits.running) return this.error_message('already_running');
        if (limits.remaining <= 0) {
            var next_date = limits.next_date && this.format_date(limits.next_date, limits.period == 'day');
            if (limits.period == 'month') {
                return next_date
                    ? interpolate(gettext("You've had this month's proposal. The next one is available on %(date)s."), { date: next_date }, true)
                    : gettext("You've had this month's proposal.");
            }
            return next_date
                ? interpolate(ngettext(
                    "You've made %(count)s proposal in the last day. The next one is available on %(date)s.",
                    "You've made %(count)s proposals in the last day. The next one is available on %(date)s.",
                    limits.limit), { count: Inflector.commas(limits.limit), date: next_date }, true)
                : interpolate(ngettext(
                    "You've made %(count)s proposal in the last day.",
                    "You've made %(count)s proposals in the last day.",
                    limits.limit), { count: Inflector.commas(limits.limit) }, true);
        }
        if (!site_count) return gettext('Every site is in a folder you left out. Open a folder so the AI has sites to look at.');
        return null;
    },

    monthly_limit_sentence: function (limit) {
        if (limit == 1) {
            return gettext('You get one proposal a month. Applying one needs Premium Archive.');
        }
        return interpolate(ngettext(
            "You get %(count)s proposal a month. Applying one needs Premium Archive.",
            "You get %(count)s proposals a month. Applying one needs Premium Archive.",
            limit), { count: Inflector.commas(limit) }, true);
    },

    propose: function () {
        if (this.proposing || this.propose_refusal(this.count_sites())) return;
        this.proposing = true;
        this.error_code = null;
        this.clear_notice();
        this.update_setup_notes();

        this.model.reorganize_propose(this.form.level, this.form.find_dead, this.form.instructions, _.bind(function (data) {
            this.proposing = false;
            this.update(data);
        }, this), _.bind(function (data) {
            this.proposing = false;
            if (this.closed) return;
            if (data && data.limits) this.limits = data.limits;
            if (data && data.reason == 'already_running') {
                this.load_status();
                return;
            }
            // A refusal the fresh limits already explain, like this month's proposal being used, shows once.
            this.error_code = this.propose_refusal(this.count_sites()) ? null : ((data && data.reason) || 'request_failed');
            this.update_setup_notes();
        }, this));
    },

    // =========
    // = Locks =
    // =========

    make_folder_list: function () {
        this.folder_rows = this.collect_folders();
        var $list = $.make('div', { className: 'NB-organizer-ai-folders' }, _.map(this.folder_rows, _.bind(this.make_folder_row, this)));
        if (this.organizer.options.resize) {
            $list.css({ 'max-height': this.organizer.options.resize });
        }
        return $list;
    },

    make_folder_row: function (folder, index) {
        var own_lock = this.own_lock(folder.path);
        var parent_lock = this.lock_for(folder.path.slice(0, -1));
        var lock = parent_lock || own_lock;
        var $icon = $.favicon_el('river:' + folder.title, {
            image_class: 'NB-organizer-ai-folder-icon',
            emoji_class: 'NB-organizer-ai-folder-icon NB-folder-emoji',
            colored_class: 'NB-organizer-ai-folder-icon NB-folder-icon-colored'
        });

        var $row = $.make('div', {
            className: 'NB-organizer-ai-folder' + (lock ? ' NB-organizer-ai-folder-' + lock : ''),
            'data-index': index
        }, [
            $.make('span', { className: 'NB-organizer-ai-folder-icon-wrap' }, [$icon]),
            $.make('span', { className: 'NB-organizer-ai-folder-title' }).text(folder.title),
            $.make('span', { className: 'NB-organizer-ai-folder-count' }).text(Inflector.commas(folder.site_count)),
            parent_lock
                ? $.make('span', { className: 'NB-organizer-ai-locked-with-parent' }, [
                    $.make('span', { className: 'NB-organizer-ai-lock-icon' }),
                    gettext('Locked with parent')
                ])
                : this.make_lock_control(folder, own_lock)
        ]);
        $row.css({ 'padding-inline-start': (8 + folder.depth * 22) + 'px' });
        return $row;
    },

    make_lock_control: function (folder, own_lock) {
        var options = [
            [null, gettext('Open'), gettext('The AI can move sites in and out, and rename, merge or nest the folder.')],
            ['keep', gettext('Keep sites'), gettext('Nothing leaves and the folder is left alone. Its sites can still be offered to other folders as copies.')],
            ['skip', gettext('Leave out'), gettext('The AI never sees this folder or the sites in it.')]
        ];
        var $control = $.make('ul', { className: 'segmented-control NB-organizer-ai-lock', role: 'radiogroup' }, _.map(options, function (option) {
            var is_active = option[0] == own_lock;
            return $.make('li', {
                className: 'NB-organizer-ai-lock-option' + (is_active ? ' NB-active' : ''),
                role: 'radio',
                tabindex: 0,
                title: option[2],
                'aria-checked': is_active ? 'true' : 'false',
                'data-lock': option[0] || ''
            }, [
                option[0] && $.make('span', { className: 'NB-organizer-ai-lock-icon' }),
                option[1]
            ]);
        }));
        $control.attr('aria-label', folder.title);
        return $control;
    },

    // The reader's folders, alphabetical, each followed by the folders nested in it:
    // [{title, path, depth, site_count}], where path lists folder names from the top.
    collect_folders: function () {
        var rows = [];
        var lang = document.documentElement.lang || undefined;
        var walk = function (collection, path) {
            var folders = collection.folders().sort(function (a, b) {
                return a.get('folder_title').localeCompare(b.get('folder_title'), lang, { sensitivity: 'base', numeric: true });
            });
            _.each(folders, function (folder) {
                var folder_path = path.concat([folder.get('folder_title')]);
                rows.push({
                    title: folder.get('folder_title'),
                    path: folder_path,
                    depth: path.length,
                    site_count: folder.folders.select(function (item) { return item.is_feed(); }).length
                });
                walk(folder.folders, folder_path);
            });
        };
        walk(this.model.folders, []);
        return rows;
    },

    // Sites the AI is sent, counted as apps/reorganize/derive.py does: every site with a place
    // outside the folders left out.
    count_sites: function () {
        var counted = {};
        var self = this;
        var walk = function (collection, path) {
            collection.each(function (item) {
                if (item.is_feed()) {
                    if (self.lock_for(path) != 'skip') counted[item.feed.id] = true;
                } else if (item.is_folder()) {
                    walk(item.folders, path.concat([item.get('folder_title')]));
                }
            });
        };
        walk(this.model.folders, []);
        return _.size(counted);
    },

    // The lock on the folder at `path`, as lock_for in apps/reorganize/plan.py: a lock covers every
    // folder inside it, and "skip" wins over "keep".
    lock_for: function (path) {
        if (!path.length) return null;
        var covers = function (locked_path) {
            return locked_path.length <= path.length && _.isEqual(path.slice(0, locked_path.length), locked_path);
        };
        if (_.any(this.locks.skip, covers)) return 'skip';
        if (_.any(this.locks.keep, covers)) return 'keep';
        return null;
    },

    own_lock: function (path) {
        var is_path = function (locked_path) { return _.isEqual(locked_path, path); };
        if (_.any(this.locks.skip, is_path)) return 'skip';
        if (_.any(this.locks.keep, is_path)) return 'keep';
        return null;
    },

    change_lock: function (index, lock) {
        this.locks = this.locks_with(this.folder_rows[index].path, lock);
        this.refresh_folder_list();
        this.save_locks();
    },

    // The locks with the folder at `path` set to `lock`. Locking a folder also drops the locks inside
    // it, since its own lock now covers them.
    locks_with: function (path, lock) {
        var keeps = function (locked_path) {
            var is_inside = locked_path.length >= path.length && _.isEqual(locked_path.slice(0, path.length), path);
            return lock ? !is_inside : !_.isEqual(locked_path, path);
        };
        var locks = {
            keep: _.filter(this.locks.keep, keeps),
            skip: _.filter(this.locks.skip, keeps)
        };
        if (lock) locks[lock].push(path);
        return locks;
    },

    // Locks changed, by the reader or by the server's answer: redraw whichever screen shows them.
    refresh_locks: function () {
        if (this.screen == 'review') {
            this.refresh_review();
        } else {
            this.refresh_folder_list();
        }
    },

    // Saves run in order, and only the answer to the latest one is shown, so quick changes never flicker.
    save_locks: function () {
        var save_number = ++this.lock_save_count;
        this.pending_lock_saves += 1;
        this.model.reorganize_save_locks(this.locks.keep, this.locks.skip, _.bind(function (data) {
            this.pending_lock_saves -= 1;
            if (this.closed || save_number != this.lock_save_count) return;
            var had_error = this.error_code == 'locks_failed';
            if (had_error) this.error_code = null;
            if (!_.isEqual(data.locks, this.locks)) {
                this.locks = data.locks;
                this.refresh_locks();
            } else if (had_error) {
                this.update_setup_notes();
                this.update_review_error();
            }
        }, this), _.bind(function () {
            this.pending_lock_saves -= 1;
            if (this.closed || save_number != this.lock_save_count) return;
            this.error_code = 'locks_failed';
            this.load_status();
        }, this));
    },

    // Rebuilt in place, keeping the scroll position and the keyboard focus on the row it was in.
    refresh_folder_list: function () {
        if (this.screen != 'setup' || !this.$folder_list) return;
        var scroll_top = this.$folder_list.scrollTop();
        var $focused_row = $(document.activeElement).closest('.NB-organizer-ai-folder');
        var focus_index = $.contains(this.$folder_list[0], document.activeElement) ? $focused_row.data('index') : null;
        var $list = this.make_folder_list();
        this.$folder_list.replaceWith($list);
        this.$folder_list = $list.scrollTop(scroll_top);
        if (focus_index != null) {
            $('.NB-organizer-ai-folder[data-index="' + focus_index + '"] .NB-organizer-ai-lock-option.NB-active', $list).focus();
        }
        this.update_setup_notes();
    },

    // ===================
    // = Progress screen =
    // ===================

    make_progress_screen: function () {
        this.progress_id = this.proposal.id;
        var $screen = $.make('div', { className: 'NB-organizer-ai-center NB-organizer-ai-progress' }, [
            $.make('h3', { className: 'NB-organizer-ai-center-title' }, this.proposal.revises
                ? gettext('AI is revising the proposal')
                : gettext('AI is looking through your sites')),
            $.make('p', { className: 'NB-organizer-ai-center-text' }, gettext('You can close this dialog. The proposal will be waiting here when you come back.')),
            $.make('div', {
                className: 'NB-organizer-ai-progress-track',
                role: 'progressbar',
                'aria-label': gettext('Progress'),
                'aria-valuemin': 0
            }, [
                $.make('div', { className: 'NB-organizer-ai-progress-bar' })
            ]),
            $.make('ol', { className: 'NB-organizer-ai-checklist' })
        ]);
        this.fill_progress($screen);
        return $screen;
    },

    update_progress: function () {
        this.fill_progress(this.$screen);
    },

    fill_progress: function ($screen) {
        var progress = this.proposal.progress || {};
        var done = progress.done || 0;
        var total = progress.total || 0;
        var fraction = total ? Math.min(1, done / total) : 0;

        $('.NB-organizer-ai-progress-track', $screen).attr({
            'aria-valuemax': total || 1,
            'aria-valuenow': total ? done : 0
        });
        $('.NB-organizer-ai-progress-bar', $screen).css({ width: Math.max(2, Math.round(fraction * 100)) + '%' });

        var current_found = false;
        $('.NB-organizer-ai-checklist', $screen).empty().append(_.map(this.progress_steps(total), function (step) {
            var state = 'pending';
            if (done >= step.finished_at) {
                state = 'done';
            } else if (!current_found) {
                state = 'current';
                current_found = true;
            }
            return $.make('li', {
                className: 'NB-organizer-ai-checklist-item NB-organizer-ai-checklist-' + state,
                'aria-current': state == 'current' ? 'step' : null
            }, [
                $.make('span', { className: 'NB-organizer-ai-checklist-icon' }),
                $.make('span').text(step.label)
            ]);
        }));
    },

    // The run's steps, as apps/reorganize/generate.py reports them: each report says a step has
    // finished and raises done by one. The folder sketch is skipped at Tidy, and sorting reports
    // once per batch of sites, so it finishes one report before the end.
    progress_steps: function (total) {
        var proposal = this.proposal;
        var site_count = proposal.sites || this.count_sites();
        var steps = [{
            label: interpolate(ngettext("Reading %(count)s site", "Reading %(count)s sites", site_count),
                { count: Inflector.commas(site_count) }, true),
            finished_at: 1
        }];
        if (proposal.level != 'tidy') {
            steps.push({ label: gettext('Sketching folders'), finished_at: 2 });
        }
        steps.push({ label: gettext('Sorting sites into folders'), finished_at: total ? total - 1 : Infinity });
        steps.push({
            label: proposal.find_dead ? gettext('Checking for dead sites') : gettext('Putting the proposal together'),
            finished_at: total || Infinity
        });
        return steps;
    },

    // =================
    // = Review screen =
    // =================

    // Every move is listed twice, under Arriving in the folder it enters and under Leaving in the
    // folder it leaves, and either side can stop it. The screen is built once per proposal. A click
    // changes this.decisions, works the plan out again with NEWSBLUR.ReaderOrganizerAI.Rules,
    // rewrites only the rows, cards and counts whose state changed, and then saves what changed.

    make_review_screen: function () {
        var proposal = this.proposal;
        var Rules = NEWSBLUR.ReaderOrganizerAI.Rules;
        if (this.decisions_for != proposal.id) {
            this.decisions_for = proposal.id;
            this.decisions = Rules.merge_decisions(proposal.decisions, {}, proposal.proposal);
            this.pending_changes = null;
            this.review_view = 'folders';
            this.review_filter = 'all';
            this.review_error = null;
            if (proposal.revises) this.revise_text = '';
        }

        var lang = document.documentElement.lang || undefined;
        var review = this.review = {
            proposal_id: proposal.id,
            data: proposal.proposal || {},
            tree: this.collect_tree(),
            collator: new Intl.Collator(lang, { sensitivity: 'base', numeric: true }),
            moves: [],
            moves_by_id: {},
            ops: [],
            dead: [],
            cards: [],
            cards_by_folder: {},
            list_rows: null,
            open_menu: null,
            outline_signature: null,
            card_order: null
        };
        review.plan = this.compute_review_plan();
        this.collect_review_items();

        this.$review_list = $.make('div', { className: 'NB-organizer-ai-review-list' }, [
            this.$review_legend = this.make_review_legend(),
            this.$review_cards = $.make('div', { className: 'NB-organizer-ai-cards' }, _.pluck(review.cards, '$el')),
            this.$review_unchanged = $.make('div', { className: 'NB-organizer-ai-unchanged' }),
            this.$review_moves = $.make('div', { className: 'NB-organizer-ai-moves NB-hidden' }),
            this.$review_dead = this.make_dead_card(),
            this.$review_empty = $.make('div', { className: 'NB-organizer-ai-review-empty NB-hidden' })
        ]);
        if (this.organizer.options.resize) {
            this.$review_list.css({ 'max-height': this.organizer.options.resize });
        }
        this.$review_error = $.make('div', { className: 'NB-organizer-ai-error NB-organizer-ai-review-error NB-hidden', role: 'alert' });

        var $screen = $.make('div', { className: 'NB-organizer-ai-review' }, [
            $.make('div', { className: 'NB-organizer-ai-review-main' }, [
                this.make_review_toolbar(),
                this.$review_error,
                this.$review_list
            ]),
            this.make_review_sidebar()
        ]);
        this.refresh_review();
        this.update_review_error();
        return $screen;
    },

    // The reader's folders as NEWSBLUR.ReaderOrganizerAI.Rules reads them, from the client's own
    // folders, so a site the client no longer has is left out.
    collect_tree: function () {
        var tree = [{ path: [], feed_ids: [] }];
        var by_path = { '[]': tree[0] };
        var walk = function (collection, path) {
            collection.each(function (item) {
                if (item.is_feed()) {
                    by_path[JSON.stringify(path)].feed_ids.push(item.feed.id);
                } else if (item.is_folder()) {
                    var child_path = path.concat([item.get('folder_title')]);
                    var key = JSON.stringify(child_path);
                    if (!_.has(by_path, key)) {
                        by_path[key] = { path: child_path, feed_ids: [] };
                        tree.push(by_path[key]);
                    }
                    walk(item.folders, child_path);
                }
            });
        };
        walk(this.model.folders, []);
        return tree;
    },

    compute_review_plan: function () {
        var review = this.review;
        return NEWSBLUR.ReaderOrganizerAI.Rules.plan(review.data, this.decisions, review.tree, this.locks);
    },

    // The moves, folder changes and dead sites the screen can show, each with its rows, and a card
    // for every folder they touch. A site the client does not know is skipped.
    collect_review_items: function () {
        var review = this.review;
        var data = review.data;
        var plan = review.plan;
        var collator = review.collator;
        var by_title = function (item) { return item.title; };
        var sort_by_title = function (items) {
            return items.sort(function (a, b) { return collator.compare(by_title(a), by_title(b)); });
        };

        _.each(_.isArray(data.moves) ? data.moves : [], _.bind(function (entry) {
            var feed = this.model.get_feed(entry.feed_id);
            var source_id = plan.folder_ids[entry.from];
            var destination_id = plan.folder_ids[entry.to];
            if (!feed || !source_id || !destination_id || _.has(review.moves_by_id, entry.id)) return;
            review.moves.push({
                id: entry.id,
                entry: entry,
                feed: feed,
                title: this.site_title(feed),
                source_id: source_id,
                destination_id: destination_id
            });
            review.moves_by_id[entry.id] = _.last(review.moves);
        }, this));
        sort_by_title(review.moves);

        _.each(_.isArray(data.ops) ? data.ops : [], function (entry) {
            var folder_id = plan.folder_ids[entry.folder];
            var seen = _.any(review.ops, function (op) { return op.id == entry.id; });
            if (folder_id && plan.ops[entry.id] && !seen) review.ops.push({ id: entry.id, entry: entry, folder_id: folder_id });
        });

        _.each(_.isArray(data.dead) ? data.dead : [], _.bind(function (entry) {
            var feed = this.model.get_feed(entry.feed_id);
            if (feed && plan.dead[entry.id]) {
                review.dead.push({ id: entry.id, entry: entry, feed: feed, title: this.site_title(feed) });
            }
        }, this));
        sort_by_title(review.dead);

        var card_for = _.bind(function (folder_id) {
            if (!_.has(review.cards_by_folder, folder_id)) {
                var card = this.make_card(folder_id, review.cards.length);
                review.cards.push(card);
                review.cards_by_folder[folder_id] = card;
            }
            return review.cards_by_folder[folder_id];
        }, this);
        _.each(review.ops, _.bind(function (op) {
            op.line = this.make_op_line(op);
            card_for(op.folder_id).$ops.append(op.line.$el);
        }, this));
        _.each(review.moves, _.bind(function (move) {
            move.row_in = this.make_move_row(move, 'in');
            move.row_out = this.make_move_row(move, 'out');
            var destination = card_for(move.destination_id);
            var source = card_for(move.source_id);
            destination.arriving.rows.push(move.row_in);
            destination.arriving.$rows.append(move.row_in.$el);
            source.leaving.rows.push(move.row_out);
            source.leaving.$rows.append(move.row_out.$el);
        }, this));
        _.each(review.dead, _.bind(function (dead) {
            dead.row = this.make_dead_row(dead);
        }, this));
    },

    // Site titles can carry entities and markup. DOMParser reads them into a document that never runs
    // or loads anything, and only the text is kept.
    site_title: function (feed) {
        var raw = feed.get('feed_title') || '';
        return new DOMParser().parseFromString(raw, 'text/html').body.textContent || raw;
    },

    // The plan's record for a folder id, or for a proposal folder key.
    review_folder: function (folder_id) {
        var plan = this.review.plan;
        if (!plan.folders_by_id) plan.folders_by_id = _.object(_.pluck(plan.folders, 'id'), plan.folders);
        return plan.folders_by_id[folder_id] || null;
    },

    review_folder_name: function (folder) {
        if (!folder) return '';
        return folder.id == '[]' ? gettext('Top level') : folder.name_after;
    },

    // Locks are kept by original path, which is what a folder id holds for every folder that exists now.
    review_folder_path: function (folder_id) {
        var path = folder_id && folder_id.charAt(0) == '[' ? JSON.parse(folder_id) : null;
        return _.isArray(path) ? path : null;
    },

    effective_review_view: function () {
        return this.review_filter == 'both' ? 'list' : this.review_view;
    },

    review_filter_matches: function (outcome) {
        var filter = this.review_filter;
        if (filter == 'open') return outcome == 'ask';
        if (filter == 'no') return outcome == 'stay';
        if (filter == 'both') return outcome == 'both' || outcome == 'ask';
        return true;
    },

    // ===============
    // = Review: DOM =
    // ===============

    make_review_toolbar: function () {
        var make_switch = function (view, label) {
            return $.make('button', {
                type: 'button',
                className: 'NB-organizer-ai-switch-option',
                'data-review': 'view',
                'data-value': view
            }, label);
        };
        this.$review_switch = $.make('div', { className: 'NB-organizer-ai-switch', role: 'group', 'aria-label': gettext('Show') }, [
            make_switch('folders', gettext('By folder')),
            make_switch('list', gettext('All moves'))
        ]);
        this.$review_chips = $.make('div', { className: 'NB-organizer-ai-chips', role: 'group', 'aria-label': gettext('Filter') },
            _.map(['all', 'open', 'no', 'both'], function (filter) {
                return $.make('button', {
                    type: 'button',
                    className: 'NB-organizer-ai-chip NB-organizer-ai-chip-' + filter,
                    'data-review': 'filter',
                    'data-value': filter
                });
            }));
        return $.make('div', { className: 'NB-organizer-ai-toolbar' }, [this.$review_switch, this.$review_chips]);
    },

    make_review_legend: function () {
        return $.make('div', { className: 'NB-organizer-ai-legend' }, [
            $.make('span', { className: 'NB-organizer-ai-legend-text' }, gettext('Everything starts approved. Reject a move from either folder.')),
            $.make('span', { className: 'NB-organizer-ai-pill NB-organizer-ai-pill-move' }, gettext('Moves')),
            $.make('span', { className: 'NB-organizer-ai-pill NB-organizer-ai-pill-both' }, gettext('In both folders')),
            $.make('span', { className: 'NB-organizer-ai-pill NB-organizer-ai-pill-ask' }, gettext('Copy?')),
            $.make('span', { className: 'NB-organizer-ai-pill NB-organizer-ai-pill-stay' }, gettext('Stays'))
        ]);
    },

    make_card: function (folder_id, index) {
        var make_section = function (side) {
            var section = { side: side, rows: [], signature: null };
            section.$title = $.make('span', { className: 'NB-organizer-ai-section-title' });
            section.$bulk = $.make('span', { className: 'NB-organizer-ai-section-bulk' });
            section.$rows = $.make('div', { className: 'NB-organizer-ai-section-rows' });
            section.$el = $.make('div', { className: 'NB-organizer-ai-section NB-organizer-ai-section-' + side }, [
                $.make('div', { className: 'NB-organizer-ai-section-head' }, [section.$title, section.$bulk]),
                section.$rows
            ]);
            return section;
        };
        var card = {
            id: folder_id,
            index: index,
            arriving: make_section('arriving'),
            leaving: make_section('leaving'),
            signature: null,
            tools_signature: null
        };
        card.$parent = $.make('span', { className: 'NB-organizer-ai-card-parent' });
        card.$name = $.make('span', { className: 'NB-organizer-ai-card-title' });
        card.$count = $.make('span', { className: 'NB-organizer-ai-card-count' });
        card.$tools = $.make('div', { className: 'NB-organizer-ai-card-tools' });
        card.$ops = $.make('div', { className: 'NB-organizer-ai-card-ops' });
        card.$note = $.make('div', { className: 'NB-organizer-ai-card-note' });
        card.$head = $.make('div', { className: 'NB-organizer-ai-card-head' }, [
            $.make('div', { className: 'NB-organizer-ai-card-name' }, [
                $.make('span', { className: 'NB-organizer-ai-card-icon' }),
                card.$parent,
                card.$name
            ]),
            card.$count,
            card.$tools
        ]);
        card.$el = $.make('section', { className: 'NB-organizer-ai-card', 'data-card': index }, [
            card.$head,
            card.$ops,
            card.arriving.$el,
            card.leaving.$el,
            card.$note
        ]);
        return card;
    },

    make_site_icon: function (feed) {
        var $icon = $.favicon_el(feed, {
            image_class: 'NB-organizer-ai-site-icon',
            emoji_class: 'NB-organizer-ai-site-icon NB-feed-emoji',
            colored_class: 'NB-organizer-ai-site-icon NB-feed-icon-colored'
        });
        return $.make('span', { className: 'NB-organizer-ai-site-icon-wrap' }, [$icon]);
    },

    make_choice_button: function (kind, action, id, value) {
        return $.make('button', {
            type: 'button',
            className: 'NB-organizer-ai-choice NB-organizer-ai-choice-' + kind,
            'data-review': action,
            'data-id': id,
            'data-value': value,
            'aria-pressed': 'false'
        }, [$.make('span', { className: 'NB-organizer-ai-choice-icon' })]);
    },

    make_move_row: function (move, side) {
        var row = { move: move, side: side, signature: null, visible: false };
        row.$jump_text = $.make('span', { className: 'NB-organizer-ai-jump-text' });
        row.$jump = $.make('button', {
            type: 'button',
            className: 'NB-organizer-ai-jump',
            'data-review': 'jump',
            'data-id': move.id,
            'data-value': side == 'in' ? 'out' : 'in'
        }, [
            $.make('span', { className: 'NB-organizer-ai-jump-lock' }),
            row.$jump_text
        ]);
        row.$reason = $.make('span', { className: 'NB-organizer-ai-row-reason' });
        row.$pill = $.make('span', { className: 'NB-organizer-ai-pill' });
        var action = side == 'in' ? 'arrive' : 'leave';
        row.$yes = this.make_choice_button('yes', action, move.id, 'true');
        row.$no = this.make_choice_button('no', action, move.id, 'false');
        row.$choices = $.make('span', { className: 'NB-organizer-ai-choices' }, [row.$yes, row.$no]);
        row.$el = $.make('div', { className: 'NB-organizer-ai-row' }, [
            this.make_site_icon(move.feed),
            $.make('div', { className: 'NB-organizer-ai-row-main' }, [
                $.make('div', { className: 'NB-organizer-ai-row-title' }).text(move.title),
                $.make('div', { className: 'NB-organizer-ai-row-sub' }, [row.$jump, side == 'in' && row.$reason])
            ]),
            row.$pill,
            row.$choices
        ]);
        return row;
    },

    make_op_line: function (op) {
        var line = { op: op, signature: null, visible: false };
        line.$tag = $.make('span', { className: 'NB-organizer-ai-op-tag NB-organizer-ai-op-tag-' + op.entry.type });
        line.$detail = $.make('span', { className: 'NB-organizer-ai-op-detail' });
        line.$reason = $.make('span', { className: 'NB-organizer-ai-op-reason' });
        line.$note = $.make('div', { className: 'NB-organizer-ai-op-note' });
        line.$yes = this.make_choice_button('yes', 'op', op.id, 'true');
        line.$no = this.make_choice_button('no', 'op', op.id, 'false');
        line.$el = $.make('div', { className: 'NB-organizer-ai-op' }, [
            $.make('div', { className: 'NB-organizer-ai-op-main' }, [
                $.make('div', { className: 'NB-organizer-ai-op-what' }, [line.$tag, line.$detail]),
                line.$reason,
                line.$note
            ]),
            $.make('span', { className: 'NB-organizer-ai-choices' }, [line.$yes, line.$no])
        ]);
        return line;
    },

    make_dead_card: function () {
        var review = this.review;
        this.$review_dead_count = $.make('span', { className: 'NB-organizer-ai-card-count' });
        this.$review_dead_note = $.make('div', { className: 'NB-organizer-ai-card-note NB-organizer-ai-dead-intro' },
            gettext('Stopped publishing or failing to fetch. Sites in locked folders are not flagged. Suggested mutes start selected. Unsubscribing always needs your click.'));
        return $.make('section', { className: 'NB-organizer-ai-card NB-organizer-ai-dead-card NB-hidden' }, [
            $.make('div', { className: 'NB-organizer-ai-card-head' }, [
                $.make('div', { className: 'NB-organizer-ai-card-name' }, [
                    $.make('span', { className: 'NB-organizer-ai-dead-icon' }),
                    $.make('span', { className: 'NB-organizer-ai-card-title' }, gettext('Dead sites'))
                ]),
                this.$review_dead_count
            ]),
            this.$review_dead_note,
            $.make('div', { className: 'NB-organizer-ai-section-rows' }, _.map(review.dead, function (dead) { return dead.row.$el; }))
        ]);
    },

    make_dead_row: function (dead) {
        var row = { dead: dead, signature: null, visible: false, buttons: {} };
        var labels = { keep: gettext('Keep'), mute: gettext('Mute'), unsubscribe: gettext('Unsubscribe') };
        _.each(labels, function (label, action) {
            row.buttons[action] = $.make('button', {
                type: 'button',
                className: 'NB-organizer-ai-choice-wide NB-organizer-ai-choice-' + action,
                'data-review': 'dead',
                'data-id': dead.id,
                'data-value': action,
                'aria-pressed': 'false'
            }, label);
        });
        row.$folder = $.make('span', { className: 'NB-organizer-ai-row-folder' });
        row.$el = $.make('div', { className: 'NB-organizer-ai-row NB-organizer-ai-dead-row' }, [
            this.make_site_icon(dead.feed),
            $.make('div', { className: 'NB-organizer-ai-row-main' }, [
                $.make('div', { className: 'NB-organizer-ai-row-title' }).text(dead.title),
                $.make('div', { className: 'NB-organizer-ai-row-sub' }, [
                    row.$folder,
                    $.make('span', { className: 'NB-organizer-ai-row-reason' }).text(this.dead_cause(dead.entry)),
                    $.make('span', { className: 'NB-organizer-ai-row-reason' }).text(dead.entry.suggest == 'unsubscribe'
                        ? gettext('Suggested: unsubscribe.')
                        : gettext('Suggested: mute.'))
                ])
            ]),
            $.make('span', { className: 'NB-organizer-ai-choices NB-organizer-ai-choices-wide' }, [
                row.buttons.keep, row.buttons.mute, row.buttons.unsubscribe
            ])
        ]);
        return row;
    },

    // Why a site was flagged, from apps/reorganize/sites.py's `cause` and `since`.
    dead_cause: function (entry) {
        var month = this.format_month(entry.since);
        if (entry.cause == 'failing') {
            return month
                ? interpolate(gettext('Failing to fetch. The last story was in %(month)s.'), { month: month }, true)
                : gettext('Failing to fetch, and it has never had a story.');
        }
        return month
            ? interpolate(gettext('No stories since %(month)s.'), { month: month }, true)
            : gettext('It has never had a story.');
    },

    // "YYYY-MM" as a month and year in the reader's language, or null.
    format_month: function (since) {
        var parts = /^(\d{4})-(\d{2})$/.exec(since || '');
        if (!parts) return null;
        var date = new Date(Date.UTC(parseInt(parts[1], 10), parseInt(parts[2], 10) - 1, 1));
        var lang = document.documentElement.lang || undefined;
        return date.toLocaleDateString(lang, { month: 'long', year: 'numeric', timeZone: 'UTC' });
    },

    // The All moves view is built the first time it is shown.
    build_review_list: function () {
        var review = this.review;
        if (review.list_rows) return;
        review.list_rows = {};
        this.$review_moves_legend = $.make('div', { className: 'NB-organizer-ai-legend NB-organizer-ai-moves-legend' },
            gettext('These sites are set to stay in their old folder and are also offered to a new one. Pick where each should live.'));
        var $rows = _.map(review.moves, _.bind(function (move) {
            var row = { move: move, signature: null, visible: false, buttons: {} };
            var labels = { move: gettext('Move'), both: gettext('Both'), stay: gettext('Stay') };
            _.each(labels, function (label, route) {
                row.buttons[route] = $.make('button', {
                    type: 'button',
                    className: 'NB-organizer-ai-choice-wide NB-organizer-ai-choice-' + route,
                    'data-review': 'route',
                    'data-id': move.id,
                    'data-value': route,
                    'aria-pressed': 'false'
                }, label);
            });
            row.$source = $.make('span', { className: 'NB-organizer-ai-route-from' });
            row.$destination = $.make('span', { className: 'NB-organizer-ai-route-to' });
            row.$route = $.make('span', { className: 'NB-organizer-ai-route' }, [
                $.make('span', { className: 'NB-organizer-ai-jump-lock' }),
                row.$source,
                $.make('span', { className: 'NB-organizer-ai-route-arrow' }),
                row.$destination
            ]);
            row.$reason = $.make('span', { className: 'NB-organizer-ai-row-reason' });
            row.$el = $.make('div', { className: 'NB-organizer-ai-row NB-organizer-ai-route-row' }, [
                this.make_site_icon(move.feed),
                $.make('div', { className: 'NB-organizer-ai-row-main' }, [
                    $.make('div', { className: 'NB-organizer-ai-row-title' }).text(move.title),
                    $.make('div', { className: 'NB-organizer-ai-row-sub' }, [
                        row.$route,
                        row.$reason
                    ])
                ]),
                $.make('span', { className: 'NB-organizer-ai-choices NB-organizer-ai-choices-wide' }, [
                    row.buttons.move, row.buttons.both, row.buttons.stay
                ])
            ]);
            review.list_rows[move.id] = row;
            return row.$el;
        }, this));
        this.$review_moves.append(this.$review_moves_legend).append($rows);
    },

    make_review_sidebar: function () {
        var make_cell = function (kind, label) {
            return $.make('div', { className: 'NB-organizer-ai-tally-cell NB-organizer-ai-tally-' + kind }, [
                $.make('span', { className: 'NB-organizer-ai-tally-number' }),
                $.make('span', { className: 'NB-organizer-ai-tally-label' }, label)
            ]);
        };
        this.$review_tally = $.make('div', { className: 'NB-organizer-sidebar-container NB-organizer-ai-tally-cells' }, [
            make_cell('approved', gettext('approved')),
            make_cell('rejected', gettext('rejected')),
            make_cell('open', gettext('to decide'))
        ]);
        this.$review_outline = $.make('ul', { className: 'NB-organizer-ai-outline' });
        this.$revise_input = $.make('textarea', {
            id: 'NB-organizer-ai-revise',
            className: 'NB-input NB-organizer-ai-revise-input',
            maxlength: NEWSBLUR.ReaderOrganizerAI.INSTRUCTIONS_LIMIT,
            placeholder: gettext('Keep the photo blogs together. Split News by country.')
        }).val(this.revise_text);
        this.$revise_button = $.make('button', {
            type: 'button',
            className: 'NB-modal-submit-button NB-modal-submit-grey NB-organizer-ai-revise-button',
            'data-review': 'revise'
        }, gettext('Revise proposal'));
        this.$revise_notes = $.make('div', { className: 'NB-organizer-ai-revise-notes' });
        this.$review_apply = $.make('div', { className: 'NB-organizer-ai-apply' });

        return $.make('div', { className: 'NB-organizer-ai-review-side' }, [
            $.make('div', { className: 'NB-organizer-sidebar-title' }, gettext('Your decisions')),
            this.$review_tally,
            $.make('div', { className: 'NB-organizer-sidebar-title' }, gettext('Folders after')),
            $.make('div', { className: 'NB-organizer-sidebar-container NB-organizer-ai-outline-box' }, [this.$review_outline]),
            $.make('label', { className: 'NB-organizer-sidebar-title', 'for': 'NB-organizer-ai-revise' }, gettext('Ask AI to revise')),
            $.make('div', { className: 'NB-organizer-sidebar-container' }, [
                this.$revise_input,
                this.$revise_button,
                this.$revise_notes
            ]),
            this.$review_apply
        ]);
    },

    // ===================
    // = Review: refresh =
    // ===================

    // Works the plan out again and rewrites whatever it changed. `anchor`, the element clicked,
    // stays where it was on screen while cards above it come, go or reorder.
    refresh_review: function (options) {
        options = options || {};
        var review = this.review;
        if (!review || this.screen != 'review' || !this.$review_list) return;
        var anchor = options.anchor && this.review_anchor(options.anchor);
        var view = this.effective_review_view();
        if (view == 'list') this.build_review_list();

        review.plan = this.compute_review_plan();
        var counts = {};
        _.each(review.cards, function (card) {
            counts[card.index] = { arriving: 0, leaving: 0, ops: 0, rejected_ops: 0, leaving_feeds: {} };
        });

        _.each(review.moves, _.bind(function (move) {
            if (this.fill_move_row(move.row_in)) counts[review.cards_by_folder[move.destination_id].index].arriving += 1;
            var source_count = counts[review.cards_by_folder[move.source_id].index];
            if (this.fill_move_row(move.row_out)) source_count.leaving += 1;
            if (review.plan.moves[move.id].offered) source_count.leaving_feeds[move.entry.feed_id] = true;
            if (review.list_rows) this.fill_route_row(review.list_rows[move.id]);
        }, this));
        _.each(review.ops, _.bind(function (op) {
            if (this.fill_op_line(op.line)) {
                var card_count = counts[review.cards_by_folder[op.folder_id].index];
                card_count.ops += 1;
                if (!review.plan.ops[op.id].approved) card_count.rejected_ops += 1;
            }
        }, this));
        var dead_visible = 0;
        _.each(review.dead, _.bind(function (dead) {
            if (this.fill_dead_row(dead.row)) dead_visible += 1;
        }, this));

        var cards_visible = 0;
        _.each(review.cards, _.bind(function (card) {
            if (this.fill_card(card, counts[card.index])) cards_visible += 1;
        }, this));
        this.order_review_cards();

        var tally = this.review_tally();
        var is_list = view == 'list';
        var routes_visible = is_list && _.any(review.list_rows, function (row) { return row.visible; });
        this.$review_legend.toggleClass('NB-hidden', is_list);
        this.$review_cards.toggleClass('NB-hidden', is_list);
        this.$review_moves.toggleClass('NB-hidden', !is_list);
        if (this.$review_moves_legend) this.$review_moves_legend.toggleClass('NB-hidden', this.review_filter != 'both');
        this.$review_dead.toggleClass('NB-hidden', !dead_visible);
        this.$review_dead_count.text(interpolate(ngettext('%(count)s flagged', '%(count)s flagged', dead_visible),
            { count: Inflector.commas(dead_visible) }, true));
        this.$review_dead_note.toggleClass('NB-hidden', this.review_filter != 'all');
        this.fill_unchanged(!is_list && this.review_filter == 'all');

        var nothing_shown = !dead_visible && (is_list ? !routes_visible : !cards_visible);
        var has_items = review.moves.length || review.ops.length || review.dead.length;
        this.$review_empty.toggleClass('NB-hidden', !nothing_shown)
            .text(has_items ? gettext('Nothing matches this filter.') : gettext('The AI found nothing to change.'));

        this.fill_review_toolbar(tally);
        this.fill_review_tally(tally);
        this.fill_review_outline();
        this.fill_revise_box();
        this.fill_review_apply(tally);
        if (anchor) this.restore_review_anchor(anchor);
    },

    // The server's proposal or locks arrived again for the proposal on screen. Decisions the server
    // holds replace the screen's, unless some of the screen's are still being sent.
    refresh_review_from_server: function () {
        if (!this.saving_decisions && !this.pending_changes) {
            this.decisions = NEWSBLUR.ReaderOrganizerAI.Rules.merge_decisions(this.proposal.decisions, {}, this.review.data);
        }
        this.review.tree = this.collect_tree();
        this.refresh_review();
        this.update_review_error();
        this.update_steps();
    },

    // Writes a move row and returns whether it is shown.
    fill_move_row: function (row) {
        var move = row.move;
        var state = this.review.plan.moves[move.id];
        var decision = this.decisions.moves[move.id] || {};
        var source = this.review_folder(move.source_id);
        var destination = this.review_folder(move.destination_id);
        if (!source || !destination) return this.hide_review_row(row);
        var source_name = this.review_folder_name(source);
        var destination_name = this.review_folder_name(destination);
        var locked_source = source.lock == 'keep';
        var copy = locked_source || decision.leave === false;
        var no_folder = destination.fate == 'rejected';
        var outcome = state.outcome;
        var view = {
            visible: state.offered && this.review_filter_matches(outcome),
            outcome: outcome,
            choices: true
        };

        if (row.side == 'in') {
            view.jump = interpolate(copy ? gettext('Copy from %(folder)s') : gettext('From %(folder)s'), { folder: source_name }, true);
            view.jump_title = interpolate(gettext('Show this move in %(folder)s'), { folder: source_name }, true);
            view.jump_locked = !!source.lock;
            view.reason = this.move_reason(move);
            if (outcome == 'move') {
                view.pill = ['move', gettext('Moves')];
            } else if (outcome == 'both') {
                view.pill = ['both', gettext('In both folders')];
            } else if (outcome == 'ask') {
                view.pill = ['ask', gettext('Copy?')];
            } else {
                view.pill = ['stay', no_folder
                    ? gettext('Stays, no folder')
                    : interpolate(gettext('Stays in %(folder)s'), { folder: source_name }, true)];
            }
            view.no = no_folder || decision.arrive === false;
            view.yes = !view.no && outcome != 'ask';
            view.yes_label = copy ? gettext('Add a copy here') : gettext('Accept into this folder');
            view.no_label = gettext('Do not put it here');
        } else {
            view.jump = interpolate(locked_source ? gettext('Copy offered to %(folder)s') : gettext('To %(folder)s'),
                { folder: destination_name }, true);
            view.jump_title = interpolate(gettext('Show this move in %(folder)s'), { folder: destination_name }, true);
            view.jump_locked = !!destination.lock;
            if (locked_source) {
                view.choices = false;
                if (outcome == 'both') {
                    view.pill = ['both', interpolate(gettext('Also in %(folder)s'), { folder: destination_name }, true)];
                } else if (outcome == 'ask') {
                    view.pill = ['ask', gettext('Copy undecided')];
                } else {
                    view.pill = ['stay', gettext('No copy')];
                }
            } else if (outcome == 'move') {
                view.pill = ['move', gettext('Moves')];
            } else if (outcome == 'both') {
                view.pill = ['both', gettext('In both folders')];
            } else {
                view.pill = ['stay', gettext('Stays here')];
            }
            view.no = decision.leave === false;
            view.yes = !view.no && outcome == 'move';
            view.yes_label = gettext('Let it go');
            view.no_label = gettext('Keep it here');
        }

        row.visible = view.visible;
        var signature = JSON.stringify(view);
        if (signature == row.signature) return row.visible;
        row.signature = signature;

        row.$el.toggleClass('NB-hidden', !view.visible)
            .removeClass(NEWSBLUR.ReaderOrganizerAI.OUTCOME_CLASSES)
            .addClass('NB-organizer-ai-row-' + outcome);
        row.$jump.attr('title', view.jump_title).toggleClass('NB-organizer-ai-jump-locked', view.jump_locked);
        row.$jump_text.text(view.jump);
        if (row.side == 'in') row.$reason.text(view.reason).toggleClass('NB-hidden', !view.reason);
        row.$pill.attr('class', 'NB-organizer-ai-pill NB-organizer-ai-pill-' + view.pill[0]).text(view.pill[1]).attr('title', view.pill[1]);
        row.$choices.toggleClass('NB-hidden', !view.choices);
        row.$yes.attr({ 'aria-pressed': view.yes ? 'true' : 'false', title: view.yes_label, 'aria-label': view.yes_label });
        row.$no.attr({ 'aria-pressed': view.no ? 'true' : 'false', title: view.no_label, 'aria-label': view.no_label });
        return row.visible;
    },

    // A folder deleted by hand since the proposal was made takes its rows with it.
    hide_review_row: function (row) {
        row.visible = false;
        row.signature = null;
        row.$el.addClass('NB-hidden');
        return false;
    },

    // The model's reason, or for a move a merge made, which comes without one, a line of our own.
    move_reason: function (move) {
        if (move.entry.reason) return move.entry.reason;
        var merge = _.find(this.review.ops, function (op) {
            return op.entry.type == 'merge' && op.entry.folder == move.entry.from;
        });
        if (!merge) return '';
        return interpolate(gettext('Moves with %(folder)s as it merges.'),
            { folder: this.review_folder_name(this.review_folder(move.source_id)) }, true);
    },

    fill_route_row: function (row) {
        var move = row.move;
        var state = this.review.plan.moves[move.id];
        var source = this.review_folder(move.source_id);
        var destination = this.review_folder(move.destination_id);
        if (!source || !destination) return this.hide_review_row(row);
        var view = {
            visible: state.offered && this.review_filter_matches(state.outcome),
            outcome: state.outcome,
            locked: source.lock == 'keep',
            source: this.review_folder_name(source),
            destination: this.review_folder_name(destination),
            reason: this.move_reason(move)
        };
        row.visible = view.visible;
        var signature = JSON.stringify(view);
        if (signature == row.signature) return;
        row.signature = signature;

        row.$el.toggleClass('NB-hidden', !view.visible)
            .removeClass(NEWSBLUR.ReaderOrganizerAI.OUTCOME_CLASSES)
            .addClass('NB-organizer-ai-row-' + view.outcome);
        row.$route.toggleClass('NB-organizer-ai-route-locked', !!view.locked);
        row.$source.text(view.source);
        row.$destination.text(view.destination);
        row.$reason.text(view.reason).toggleClass('NB-hidden', !view.reason);
        _.each(row.buttons, function ($button, route) {
            $button.attr('aria-pressed', route == view.outcome ? 'true' : 'false');
        });
        row.buttons.move.prop('disabled', view.locked)
            .attr('title', view.locked ? gettext('Its folder is locked to keep its sites.') : null);
    },

    // Writes a folder change and returns whether it is shown.
    fill_op_line: function (line) {
        var entry = line.op.entry;
        var state = this.review.plan.ops[line.op.id];
        var folder = this.review_folder(line.op.folder_id);
        var view = {
            visible: state.offered,
            approved: state.approved,
            detail: this.op_detail(entry, folder),
            reason: entry.reason || (entry.type == 'remove' ? gettext('Nothing is left in this folder after the other changes.') : ''),
            note: state.approved && !state.happens ? this.op_blocked_sentence(entry, state.reason, folder) : ''
        };
        line.visible = view.visible;
        var signature = JSON.stringify(view);
        if (signature == line.signature) return line.visible;
        line.signature = signature;

        var tags = {
            create: gettext('New folder'),
            rename: gettext('Rename'),
            nest: gettext('Nest'),
            merge: gettext('Merge'),
            remove: gettext('Remove')
        };
        line.$el.toggleClass('NB-hidden', !view.visible).toggleClass('NB-organizer-ai-op-rejected', !view.approved);
        line.$tag.text(tags[entry.type] || '');
        line.$detail.text(view.detail).toggleClass('NB-hidden', !view.detail);
        line.$reason.text(view.reason).toggleClass('NB-hidden', !view.reason);
        line.$note.text(view.note).toggleClass('NB-hidden', !view.note);
        line.$yes.attr({ 'aria-pressed': view.approved ? 'true' : 'false', title: gettext('Approve'), 'aria-label': gettext('Approve') });
        line.$no.attr({ 'aria-pressed': view.approved ? 'false' : 'true', title: gettext('Reject'), 'aria-label': gettext('Reject') });
        return line.visible;
    },

    op_detail: function (entry, folder) {
        var name_of = _.bind(function (key) {
            return this.review_folder_name(this.review_folder(this.review.plan.folder_ids[key]));
        }, this);
        if (entry.type == 'create') {
            var new_folder = (this.review.data.folders || {})[entry.folder] || {};
            return new_folder.parent && new_folder.parent != NEWSBLUR.ReaderOrganizerAI.Rules.ROOT_KEY
                ? interpolate(gettext('Inside %(folder)s'), { folder: name_of(new_folder.parent) }, true)
                : '';
        }
        if (entry.type == 'rename') {
            return interpolate(gettext('“%(old)s” becomes “%(new)s”'), {
                old: folder ? folder.name_before : '',
                'new': entry.name || ''
            }, true);
        }
        if (entry.type == 'nest') return interpolate(gettext('Goes inside %(folder)s'), { folder: name_of(entry.parent) }, true);
        if (entry.type == 'merge') return interpolate(gettext('Into %(folder)s, then removed'), { folder: name_of(entry.into) }, true);
        return '';
    },

    // Why an approved folder change will not happen with the reader's other choices.
    op_blocked_sentence: function (entry, reason, folder) {
        if (reason == 'not_empty') {
            var count = folder ? folder.after : 0;
            if (!count) return gettext('Stays, because a folder inside it stays.');
            return interpolate(ngettext('Stays, because %(count)s site stays in it.', 'Stays, because %(count)s sites stay in it.', count),
                { count: Inflector.commas(count) }, true);
        }
        if (reason == 'empty') return gettext("Nothing goes into this folder, so it won't be made.");
        if (reason == 'name_taken') return gettext('Another folder there already has this name.');
        if (reason == 'folder_rejected') return gettext('It needs a new folder you rejected.');
        if (!reason) return '';
        return gettext("This change doesn't fit with your other choices.");
    },

    // Writes a dead site row and returns whether it is shown.
    fill_dead_row: function (row) {
        var state = this.review.plan.dead[row.dead.id];
        var filter = this.review_filter;
        var matches = filter == 'all' || (filter == 'open' && !state.action) || (filter == 'no' && state.action == 'keep');
        var view = {
            visible: state.offered && matches,
            action: state.action,
            folder: this.dead_folder_name(row.dead.entry.feed_id)
        };
        row.visible = view.visible;
        var signature = JSON.stringify(view);
        if (signature == row.signature) return row.visible;
        row.signature = signature;

        row.$el.toggleClass('NB-hidden', !view.visible);
        row.$folder.text(interpolate(gettext('In %(folder)s'), { folder: view.folder }, true));
        _.each(row.buttons, function ($button, action) {
            $button.attr('aria-pressed', action == view.action ? 'true' : 'false');
        });
        return row.visible;
    },

    // The folder a site is in now, the first one if it is in several.
    dead_folder_name: function (feed_id) {
        var folder = _.find(this.review.tree, function (entry) { return _.contains(entry.feed_ids, feed_id); });
        if (!folder || !folder.path.length) return gettext('Top level');
        return _.last(folder.path);
    },

    // Writes a card and returns whether it is shown.
    fill_card: function (card, counts) {
        var folder = this.review_folder(card.id);
        if (!folder) return false;
        var filter = this.review_filter;
        var path = this.review_folder_path(card.id);
        var has_rows = counts.arriving || counts.leaving;
        var visible = filter == 'all'
            ? !!(has_rows || counts.ops || folder.lock)
            : !!(has_rows || (filter == 'no' && counts.rejected_ops));
        card.visible = visible;

        var other_sites = folder.before - _.size(counts.leaving_feeds);
        var note = '';
        if (filter == 'all') {
            if (folder.lock == 'skip') {
                note = gettext('Left out. Nothing in this folder changes.');
            } else if (folder.lock == 'keep') {
                note = gettext('Nothing leaves this folder.');
            } else if (other_sites > 0) {
                note = interpolate(has_rows
                    ? ngettext('%(count)s other site here is not part of any change.', '%(count)s other sites here are not part of any change.', other_sites)
                    : ngettext('%(count)s site here, none part of any change.', '%(count)s sites here, none part of any change.', other_sites),
                    { count: Inflector.commas(other_sites) }, true);
            }
        }
        var count_text = folder.before == folder.after
            ? interpolate(ngettext('%(count)s site', '%(count)s sites', folder.after), { count: Inflector.commas(folder.after) }, true)
            : interpolate(ngettext('%(before)s → %(count)s site', '%(before)s → %(count)s sites', folder.after),
                { before: Inflector.commas(folder.before), count: Inflector.commas(folder.after) }, true);
        var view = {
            visible: visible,
            parent: folder.place.length > 1 ? folder.place[folder.place.length - 2] : '',
            name: this.review_folder_name(folder),
            gone: !!folder.fate && folder.fate != 'unplaced',
            count: count_text,
            arriving: counts.arriving,
            leaving: counts.leaving,
            copies: folder.lock == 'keep',
            note: note
        };
        var signature = JSON.stringify(view);
        if (signature != card.signature) {
            card.signature = signature;
            card.$el.toggleClass('NB-hidden', !visible).toggleClass('NB-organizer-ai-card-gone', view.gone);
            card.$parent.text(view.parent).toggleClass('NB-hidden', !view.parent);
            card.$name.text(view.name);
            card.$count.text(view.count);
            card.$note.text(note).toggleClass('NB-hidden', !note);
            this.fill_card_section(card, card.arriving, counts.arriving, 'arriving');
            this.fill_card_section(card, card.leaving, counts.leaving, view.copies ? 'copies' : 'leaving');
        }
        this.fill_card_tools(card, path);
        return visible;
    },

    fill_card_section: function (card, section, count, mode) {
        var signature = mode + ':' + count;
        if (signature == section.signature) return;
        section.signature = signature;
        section.$el.toggleClass('NB-hidden', !count);
        if (!count) return;
        var titles = {
            arriving: ngettext('Arriving %(count)s', 'Arriving %(count)s', count),
            leaving: ngettext('Leaving %(count)s', 'Leaving %(count)s', count),
            copies: ngettext('Offered elsewhere as a copy %(count)s', 'Offered elsewhere as copies %(count)s', count)
        };
        var bulk = {
            arriving: [['accept', gettext('Accept all')], ['reject', gettext('Reject all')]],
            leaving: [['let_go', gettext('Let all go')], ['keep', gettext('Keep all here')]],
            copies: [['decline', gettext('Decline all copies')]]
        };
        section.$el.removeClass('NB-organizer-ai-section-arriving NB-organizer-ai-section-leaving NB-organizer-ai-section-copies')
            .addClass('NB-organizer-ai-section-' + mode);
        section.$title.text(interpolate(titles[mode], { count: Inflector.commas(count) }, true));
        section.$bulk.empty().append(_.map(bulk[mode], function (choice) {
            return $.make('button', {
                type: 'button',
                className: 'NB-organizer-ai-link',
                'data-review': 'bulk',
                'data-id': card.index,
                'data-value': choice[0]
            }, choice[1]);
        }));
    },

    // A folder's lock: a button that opens the three choices, "Locked with parent" under a locked
    // folder, and nothing for the top level or a new folder.
    fill_card_tools: function (card, path) {
        var is_open = this.review.open_menu === card.index;
        var own_lock = path && path.length ? this.own_lock(path) : null;
        var parent_lock = path && path.length ? this.lock_for(path.slice(0, -1)) : null;
        var signature = JSON.stringify([path && path.length, own_lock, parent_lock, is_open]);
        if (signature == card.tools_signature) return;
        card.tools_signature = signature;
        card.$el.toggleClass('NB-organizer-ai-card-menu-open', is_open);
        card.$tools.empty();
        if (!path || !path.length) return;
        if (parent_lock) {
            card.$tools.append($.make('span', { className: 'NB-organizer-ai-locked-with-parent' }, [
                $.make('span', { className: 'NB-organizer-ai-lock-icon' }),
                gettext('Locked with parent')
            ]));
            return;
        }
        var options = [
            [null, gettext('Open'), gettext('The AI can move sites in and out, and rename, merge or nest the folder.')],
            ['keep', gettext('Keep sites'), gettext('Nothing leaves and the folder is left alone. Its sites can still be offered to other folders as copies.')],
            ['skip', gettext('Leave out'), gettext('The AI never sees this folder or the sites in it.')]
        ];
        var current = _.find(options, function (option) { return option[0] == own_lock; });
        card.$tools.append($.make('button', {
            type: 'button',
            className: 'NB-organizer-ai-lock-button' + (own_lock ? ' NB-organizer-ai-lock-button-locked' : ''),
            'data-review': 'lock-menu',
            'data-id': card.index,
            'aria-haspopup': 'true',
            'aria-expanded': is_open ? 'true' : 'false'
        }, [
            $.make('span', { className: 'NB-organizer-ai-lock-button-icon' }),
            $.make('span', { className: 'NB-organizer-ai-lock-button-label' }, current[1]),
            $.make('span', { className: 'NB-organizer-ai-lock-button-caret' })
        ]));
        if (!is_open) return;
        card.$tools.append($.make('div', { className: 'NB-organizer-ai-lock-menu', role: 'menu' }, _.map(options, function (option) {
            return $.make('button', {
                type: 'button',
                role: 'menuitemradio',
                className: 'NB-organizer-ai-lock-menu-option',
                'aria-checked': option[0] == own_lock ? 'true' : 'false',
                'data-review': 'lock',
                'data-id': card.index,
                'data-value': option[0] || ''
            }, [
                $.make('span', { className: 'NB-organizer-ai-lock-menu-title' }, option[1]),
                $.make('span', { className: 'NB-organizer-ai-lock-menu-description' }, option[2])
            ]);
        })));
    },

    // Cards in the order of the folders after the changes: alphabetical, each folder followed by
    // the folders inside it.
    order_review_cards: function () {
        var review = this.review;
        var collator = review.collator;
        var places = {};
        _.each(review.cards, _.bind(function (card) {
            var folder = this.review_folder(card.id);
            places[card.index] = folder ? folder.place : [];
        }, this));
        var ordered = review.cards.slice().sort(function (a, b) {
            return NEWSBLUR.ReaderOrganizerAI.Rules.compare_places(collator, places[a.index], places[b.index]);
        });
        var order = _.pluck(ordered, 'index').join(',');
        if (order == review.card_order) return;
        review.card_order = order;
        this.$review_cards.append(_.pluck(ordered, '$el'));
    },

    // The folders no card is shown for, listed once at the end.
    fill_unchanged: function (show) {
        var review = this.review;
        var shown = {};
        _.each(review.cards, function (card) { if (card.visible) shown[card.id] = true; });
        var folders = show ? _.filter(review.plan.folders, function (folder) {
            return !folder.is_new && folder.exists && !shown[folder.id] && (folder.id != '[]' || folder.before);
        }) : [];
        var collator = review.collator;
        folders.sort(function (a, b) { return NEWSBLUR.ReaderOrganizerAI.Rules.compare_places(collator, a.place, b.place); });
        var signature = JSON.stringify(_.map(folders, function (folder) { return [folder.id, folder.name_after, folder.after]; }));
        if (signature == review.unchanged_signature) return;
        review.unchanged_signature = signature;
        this.$review_unchanged.empty().toggleClass('NB-hidden', !folders.length);
        if (!folders.length) return;
        this.$review_unchanged.append(
            $.make('span', { className: 'NB-organizer-ai-unchanged-title' }, gettext('No changes')),
            _.map(folders, _.bind(function (folder) {
                return $.make('span', { className: 'NB-organizer-ai-unchanged-folder' }, [
                    $.make('span', { className: 'NB-organizer-ai-unchanged-name' }).text(this.review_folder_name(folder)),
                    $.make('span', { className: 'NB-organizer-ai-unchanged-count' }).text(Inflector.commas(folder.after))
                ]);
            }, this))
        );
    },

    fill_review_toolbar: function (tally) {
        var view = this.effective_review_view();
        $('.NB-organizer-ai-switch-option', this.$review_switch).each(function () {
            var is_active = $(this).attr('data-value') == view;
            $(this).toggleClass('NB-active', is_active).attr('aria-pressed', is_active ? 'true' : 'false');
        });
        var labels = {
            all: gettext('Everything'),
            open: interpolate(gettext('To decide %(count)s'), { count: Inflector.commas(tally.open) }, true),
            no: interpolate(gettext('Rejected %(count)s'), { count: Inflector.commas(tally.rejected) }, true),
            both: interpolate(gettext('In two folders %(count)s'), { count: Inflector.commas(tally.two_folders) }, true)
        };
        var filter = this.review_filter;
        $('.NB-organizer-ai-chip', this.$review_chips).each(function () {
            var value = $(this).attr('data-value');
            $(this).text(labels[value]).attr('aria-pressed', value == filter ? 'true' : 'false');
        });
    },

    // What the decisions add up to, counting only what will happen: approved, rejected, and still
    // to decide, which is copies on offer and suggested unsubscribes.
    review_tally: function () {
        var plan = this.review.plan;
        var tally = { approved: 0, rejected: 0, open: 0, two_folders: 0, moved: 0, copied: 0, folders: 0, muted: 0, unsubscribed: 0 };
        _.each(this.review.moves, function (move) {
            var state = plan.moves[move.id];
            if (!state.offered) return;
            if (state.outcome == 'move' && state.happens) {
                tally.approved += 1;
                tally.moved += 1;
            } else if (state.outcome == 'both') {
                tally.two_folders += 1;
                if (state.happens) {
                    tally.approved += 1;
                    tally.copied += 1;
                }
            } else if (state.outcome == 'ask') {
                tally.open += 1;
                tally.two_folders += 1;
            } else if (state.outcome == 'stay') {
                tally.rejected += 1;
            }
        });
        _.each(this.review.ops, function (op) {
            var state = plan.ops[op.id];
            if (!state.offered) return;
            if (!state.approved) {
                tally.rejected += 1;
            } else if (state.happens) {
                tally.approved += 1;
                tally.folders += 1;
            }
        });
        _.each(this.review.dead, function (dead) {
            var state = plan.dead[dead.id];
            if (!state.offered) return;
            if (state.action == 'keep') {
                tally.rejected += 1;
            } else if (state.action == 'mute') {
                tally.approved += 1;
                tally.muted += 1;
            } else if (state.action == 'unsubscribe') {
                tally.approved += 1;
                tally.unsubscribed += 1;
            } else {
                tally.open += 1;
            }
        });
        return tally;
    },

    fill_review_tally: function (tally) {
        var numbers = { approved: tally.approved, rejected: tally.rejected, open: tally.open };
        _.each(numbers, _.bind(function (number, kind) {
            $('.NB-organizer-ai-tally-' + kind + ' .NB-organizer-ai-tally-number', this.$review_tally).text(Inflector.commas(number));
        }, this));
    },

    // The folders as they will be, alphabetical, with what arrives and leaves each one. A folder
    // that goes is struck through where it was.
    fill_review_outline: function () {
        var review = this.review;
        var collator = review.collator;
        var folders = _.filter(review.plan.folders, function (folder) {
            return folder.exists || folder.fate == 'merged' || folder.fate == 'removed';
        });
        folders.sort(function (a, b) { return NEWSBLUR.ReaderOrganizerAI.Rules.compare_places(collator, a.place, b.place); });
        var items = _.map(folders, _.bind(function (folder) {
            return {
                id: folder.id,
                name: this.review_folder_name(folder),
                depth: Math.max(0, folder.place.length - 1),
                arrivals: folder.arrivals,
                departures: folder.before + folder.arrivals - folder.after,
                after: folder.after,
                gone: !folder.exists,
                locked: !!folder.lock
            };
        }, this));
        var signature = JSON.stringify(items);
        if (signature == review.outline_signature) return;
        review.outline_signature = signature;
        this.$review_outline.empty().append(_.map(items, function (item) {
            var changes = [];
            if (item.arrivals) {
                changes.push($.make('span', { className: 'NB-organizer-ai-outline-in' },
                    interpolate(gettext('+%(count)s'), { count: Inflector.commas(item.arrivals) }, true)));
            }
            if (item.departures) {
                changes.push($.make('span', { className: 'NB-organizer-ai-outline-out' },
                    interpolate(gettext('−%(count)s'), { count: Inflector.commas(item.departures) }, true)));
            }
            var $button = $.make('button', {
                type: 'button',
                className: 'NB-organizer-ai-outline-folder',
                'data-review': 'goto',
                'data-id': item.id
            }, [
                $.make('span', { className: 'NB-organizer-ai-outline-name' }, [
                    item.locked && $.make('span', { className: 'NB-organizer-ai-lock-icon' }),
                    $.make('span', { className: 'NB-organizer-ai-outline-name-text' }).text(item.name)
                ]),
                $.make('span', { className: 'NB-organizer-ai-outline-counts' }, changes.concat([
                    $.make('span', { className: 'NB-organizer-ai-outline-total' }, Inflector.commas(item.after))
                ]))
            ]);
            $button.css({ 'padding-inline-start': (4 + item.depth * 12) + 'px' });
            return $.make('li', { className: 'NB-organizer-ai-outline-item' + (item.gone ? ' NB-organizer-ai-outline-gone' : '') }, [$button]);
        }));
    },

    fill_revise_box: function () {
        if (!this.$revise_notes) return;
        var proposal = this.proposal;
        var revisions_left = proposal.revisions_left || 0;
        var notes = [];
        if (this.revise_error) {
            notes.push($.make('div', { className: 'NB-organizer-ai-error', role: 'alert' }).text(this.error_message(this.revise_error)));
        }
        notes.push($.make('p', { className: 'NB-organizer-ai-note' }).text(revisions_left > 0
            ? interpolate(ngettext('%(count)s revision left.', '%(count)s revisions left.', revisions_left),
                { count: Inflector.commas(revisions_left) }, true)
            : gettext("This proposal can't be revised again.")));
        if (proposal.revision_request) {
            notes.push($.make('p', { className: 'NB-organizer-ai-note NB-organizer-ai-revise-last' }).text(
                interpolate(gettext('Revised as you asked: “%(request)s”'), { request: proposal.revision_request }, true)));
        }
        this.$revise_notes.empty().append(notes);
        var disabled = this.revising || revisions_left <= 0;
        this.$revise_button.prop('disabled', disabled).toggleClass('NB-disabled', disabled)
            .text(this.revising ? gettext('Revising...') : gettext('Revise proposal'));
    },

    fill_review_apply: function (tally) {
        var signature = JSON.stringify([tally.approved, tally.open, this.limits && this.limits.can_apply]);
        if (signature == this.review.apply_signature) return;
        this.review.apply_signature = signature;
        var notes = tally.open
            ? interpolate(ngettext('%(count)s still to decide. Anything left undecided stays as it is.',
                '%(count)s still to decide. Anything left undecided stays as it is.', tally.open),
                { count: Inflector.commas(tally.open) }, true)
            : gettext('Everything is decided.');
        this.$review_apply.empty();
        if (this.limits && !this.limits.can_apply) {
            this.$review_apply.append(
                NEWSBLUR.utils.make_archive_callout(gettext('Applying changes needs Premium Archive. Your decisions are saved and will be here after you upgrade.'), {
                    on_upgrade: _.bind(this.open_upgrade, this)
                }),
                $.make('p', { className: 'NB-organizer-ai-note' }).text(notes)
            );
            return;
        }
        this.$review_apply.append(
            $.make('button', {
                type: 'button',
                className: 'NB-modal-submit-button NB-modal-submit-green NB-organizer-ai-apply-button' + (tally.approved ? '' : ' NB-disabled'),
                'data-review': 'apply',
                disabled: tally.approved ? null : 'disabled'
            }, interpolate(ngettext('Apply %(count)s change', 'Apply %(count)s changes', tally.approved),
                { count: Inflector.commas(tally.approved) }, true)),
            $.make('p', { className: 'NB-organizer-ai-note' }).text(notes)
        );
    },

    update_review_error: function () {
        if (!this.$review_error) return;
        var code = this.review_error || (this.error_code == 'locks_failed' ? 'locks_failed' : null);
        this.$review_error.toggleClass('NB-hidden', !code).text(code ? this.error_message(code) : '');
    },

    // =====================
    // = Review: decisions =
    // =====================

    handle_review_action: function ($target) {
        var action = $target.attr('data-review');
        var id = $target.attr('data-id');
        var value = $target.attr('data-value');
        var anchor = $target[0];
        if (action != 'lock-menu' && action != 'lock') this.close_lock_menu();

        if (action == 'arrive' || action == 'leave') {
            this.decide_side(id, action, value == 'true', anchor);
        } else if (action == 'route') {
            this.decide_route(id, value, anchor);
        } else if (action == 'op') {
            this.decide_op(id, value == 'true', anchor);
        } else if (action == 'dead') {
            this.decide_dead(id, value, anchor);
        } else if (action == 'bulk') {
            this.decide_bulk(parseInt(id, 10), value, anchor);
        } else if (action == 'jump') {
            this.jump_to_move(id, value);
        } else if (action == 'goto') {
            this.go_to_folder(id);
        } else if (action == 'view') {
            this.set_review_view(value);
        } else if (action == 'filter') {
            this.set_review_filter(value);
        } else if (action == 'lock-menu') {
            this.toggle_lock_menu(parseInt(id, 10));
        } else if (action == 'lock') {
            this.change_review_lock(parseInt(id, 10), value || null, anchor);
        } else if (action == 'revise') {
            this.revise();
        } else if (action == 'apply') {
            this.after_saves(_.bind(function () { this.apply_changes(this.review.plan); }, this));
        }
    },

    // What the Apply button does, once every decision has been saved, given the plan on screen: ask
    // first, on the confirm screen.
    apply_changes: function (plan) {
        if (this.screen != 'review' || this.applying) return;
        this.review_scroll = this.$review_list ? this.$review_list.scrollTop() : 0;
        this.confirm_plan = plan;
        this.confirming = true;
        this.clear_notice();
        this.render();
    },

    // Pressing a side's pressed button clears that side's decision, so it goes back to the default.
    decide_side: function (move_id, side, value, anchor) {
        var move = this.review.moves_by_id[move_id];
        if (!move) return;
        var current = (this.decisions.moves[move_id] || {})[side];
        var next = current === value ? null : value;
        var changes = { moves: {} };
        changes.moves[move_id] = {};
        changes.moves[move_id][side] = next;
        if (side == 'arrive' && next === true) this.reopen_folder(move, changes);
        this.change_decisions(changes, anchor);
    },

    decide_route: function (move_id, route, anchor) {
        var move = this.review.moves_by_id[move_id];
        if (!move) return;
        var changes = { moves: {} };
        if (route == 'move') {
            changes.moves[move_id] = { arrive: null, leave: null };
        } else if (route == 'both') {
            changes.moves[move_id] = { arrive: true, leave: false };
        } else {
            changes.moves[move_id] = { arrive: false };
        }
        if (route != 'stay') this.reopen_folder(move, changes);
        this.change_decisions(changes, anchor);
    },

    // Accepting a site into a new folder that was rejected brings the folder back with just that
    // site: the folder's create, and the creates of new folders around it, are approved again, and
    // the other sites offered to those folders that had no answer are turned down.
    reopen_folder: function (move, changes) {
        var Rules = NEWSBLUR.ReaderOrganizerAI.Rules;
        var review = this.review;
        var folders = review.data.folders || {};
        var reopened = {};
        var seen = {};
        for (var key = move.entry.to; Rules.is_new_key(key) && !seen[key]; key = (folders[key] || {}).parent) {
            seen[key] = true;
            var create = _.find(review.ops, function (op) { return op.entry.type == 'create' && op.entry.folder == key; });
            if (create && this.decisions.ops[create.id] === false) {
                changes.ops = changes.ops || {};
                changes.ops[create.id] = null;
                reopened[key] = true;
            }
        }
        if (!_.size(reopened)) return;
        _.each(review.moves, _.bind(function (other) {
            var decision = this.decisions.moves[other.id] || {};
            if (other === move || !reopened[other.entry.to] || _.has(decision, 'arrive') || changes.moves[other.id]) return;
            changes.moves[other.id] = { arrive: false };
        }, this));
    },

    // Rejecting a merge keeps its sites where they are, and approving it again lets them go, since
    // a folder only merges once it is empty.
    decide_op: function (op_id, approve, anchor) {
        var op = _.find(this.review.ops, function (candidate) { return candidate.id == op_id; });
        if (!op) return;
        var rejected = this.decisions.ops[op_id] === false;
        var reject = !approve && !rejected;
        var changes = { ops: {}, moves: {} };
        changes.ops[op_id] = reject ? false : null;
        if (op.entry.type == 'merge') {
            _.each(this.review.moves, _.bind(function (move) {
                if (move.entry.from != op.entry.folder || move.entry.to != op.entry.into) return;
                var decision = this.decisions.moves[move.id] || {};
                if (reject && !_.has(decision, 'arrive')) {
                    changes.moves[move.id] = { arrive: false };
                } else if (!reject && (decision.arrive === false || decision.leave === false)) {
                    changes.moves[move.id] = { arrive: null, leave: null };
                }
            }, this));
        }
        this.change_decisions(changes, anchor);
    },

    decide_dead: function (dead_id, action, anchor) {
        var changes = { dead: {} };
        changes.dead[dead_id] = this.decisions.dead[dead_id] == action ? null : action;
        this.change_decisions(changes, anchor);
    },

    // A bulk choice covers the rows of that section the filter shows, in one save.
    decide_bulk: function (card_index, choice, anchor) {
        var card = this.review.cards[card_index];
        if (!card) return;
        var section = choice == 'accept' || choice == 'reject' ? card.arriving : card.leaving;
        var rows = _.filter(section.rows, function (row) { return row.visible; });
        var changes = { moves: {} };
        if (choice == 'accept') {
            _.each(rows, _.bind(function (row) { this.reopen_folder(row.move, changes); }, this));
        }
        var sides = {
            accept: { arrive: true },
            reject: { arrive: false },
            let_go: { leave: true },
            keep: { leave: false },
            decline: { arrive: false }
        }[choice];
        if (!sides) return;
        _.each(rows, function (row) { changes.moves[row.move.id] = _.clone(sides); });
        this.change_decisions(changes, anchor);
    },

    // The screen changes first and the save follows, so a click is never kept waiting.
    change_decisions: function (changes, anchor) {
        this.decisions = NEWSBLUR.ReaderOrganizerAI.Rules.merge_decisions(this.decisions, changes, this.review.data);
        this.pending_changes = NEWSBLUR.ReaderOrganizerAI.Rules.combine_changes(this.pending_changes, changes);
        this.refresh_review({ anchor: anchor });
        this.send_decisions();
    },

    // One save at a time, sending everything changed since the last one. When the last answer
    // lands, the decisions the server holds are the screen's.
    send_decisions: function () {
        if (this.saving_decisions || !this.pending_changes) return;
        var proposal_id = this.decisions_for;
        var changes = this.pending_changes;
        this.pending_changes = null;
        this.saving_decisions = true;
        this.model.reorganize_save_decisions(proposal_id, changes, _.bind(function (data) {
            this.saving_decisions = false;
            if (this.closed || proposal_id != this.decisions_for) return;
            if (this.review_error) {
                this.review_error = null;
                this.update_review_error();
            }
            if (this.pending_changes) {
                this.send_decisions();
                return;
            }
            var saved = NEWSBLUR.ReaderOrganizerAI.Rules.merge_decisions(data.decisions, {}, this.review ? this.review.data : {});
            if (!_.isEqual(saved, this.decisions)) {
                this.decisions = saved;
                this.refresh_review();
            }
            this.run_save_waiters();
        }, this), _.bind(function (data) {
            this.saving_decisions = false;
            this.pending_changes = null;
            this.cancel_save_waiters();
            if (this.closed || proposal_id != this.decisions_for) return;
            var reason = data && data.reason;
            this.review_error = _.contains(['replaced', 'already_applied', 'not_ready', 'not_found'], reason)
                ? reason
                : 'decisions_failed';
            this.update_review_error();
            this.load_status();
        }, this));
    },

    // Runs `callback` once every decision has been saved, or `cancelled` if a save fails first.
    after_saves: function (callback, cancelled) {
        if (!this.saving_decisions && !this.pending_changes) {
            callback();
            return;
        }
        this.save_waiters.push({ callback: callback, cancelled: cancelled });
    },

    run_save_waiters: function () {
        var waiters = this.save_waiters;
        this.save_waiters = [];
        _.each(waiters, function (waiter) { waiter.callback(); });
    },

    cancel_save_waiters: function () {
        var waiters = this.save_waiters;
        this.save_waiters = [];
        _.each(waiters, function (waiter) { if (waiter.cancelled) waiter.cancelled(); });
    },

    // Locks apply as they are when the proposal is applied, so changing one here changes outcomes.
    change_review_lock: function (card_index, lock, anchor) {
        var card = this.review.cards[card_index];
        var path = card && this.review_folder_path(card.id);
        this.close_lock_menu(true);
        if (!path || !path.length || lock == this.own_lock(path)) return;
        this.locks = this.locks_with(path, lock);
        this.refresh_review({ anchor: anchor });
        this.save_locks();
    },

    toggle_lock_menu: function (card_index) {
        var review = this.review;
        var was_open = review.open_menu;
        review.open_menu = was_open === card_index ? null : card_index;
        _.each(_.compact([review.cards[was_open], review.cards[review.open_menu]]), _.bind(function (card) {
            this.fill_card_tools(card, this.review_folder_path(card.id));
        }, this));
        var open_card = review.cards[review.open_menu];
        if (open_card) $('.NB-organizer-ai-lock-menu-option[aria-checked="true"]', open_card.$tools).focus();
    },

    close_lock_menu: function (restore_focus) {
        var review = this.review;
        if (!review || review.open_menu === null) return;
        var card = review.cards[review.open_menu];
        review.open_menu = null;
        if (!card) return;
        this.fill_card_tools(card, this.review_folder_path(card.id));
        if (restore_focus) $('.NB-organizer-ai-lock-button', card.$tools).focus();
    },

    // ======================
    // = Review: navigation =
    // ======================

    set_review_view: function (view) {
        if (view == this.review_view && this.review_filter != 'both') return;
        this.review_view = view;
        if (this.review_filter == 'both') this.review_filter = 'all';
        this.refresh_review();
        this.$review_list.scrollTop(0);
        this.organizer.resize();
    },

    set_review_filter: function (filter) {
        if (filter == this.review_filter) return;
        this.review_filter = filter;
        this.refresh_review();
        this.$review_list.scrollTop(0);
        this.organizer.resize();
    },

    // Shows the same move in the other folder and flashes it.
    jump_to_move: function (move_id, side) {
        var move = this.review.moves_by_id[move_id];
        if (!move) return;
        if (this.effective_review_view() != 'folders' || this.review_filter != 'all') {
            this.review_view = 'folders';
            this.review_filter = 'all';
            this.refresh_review();
        }
        var row = side == 'in' ? move.row_in : move.row_out;
        if (!row.visible) return;
        this.scroll_review_to(row.$el, 90);
        this.flash_review_row(row.$el);
        $('.NB-organizer-ai-jump', row.$el).focus();
    },

    go_to_folder: function (folder_id) {
        if (this.effective_review_view() != 'folders' || this.review_filter != 'all') {
            this.review_view = 'folders';
            this.review_filter = 'all';
            this.refresh_review();
        }
        var card = this.review.cards_by_folder[folder_id];
        this.scroll_review_to(card && card.visible ? card.$el : this.$review_unchanged, 0);
    },

    scroll_review_to: function ($el, margin) {
        var list = this.$review_list[0];
        var top = $el[0].getBoundingClientRect().top - list.getBoundingClientRect().top;
        list.scrollTop += top - margin;
    },

    flash_review_row: function ($row) {
        $row.removeClass('NB-organizer-ai-flash');
        $row[0].offsetWidth;
        $row.addClass('NB-organizer-ai-flash');
        clearTimeout(this.flash_timer);
        this.flash_timer = setTimeout(function () { $row.removeClass('NB-organizer-ai-flash'); }, 700);
    },

    // The clicked element and its card, with where each sits on screen before the change.
    review_anchor: function (element) {
        if (!this.$review_list || !$.contains(this.$review_list[0], element)) return null;
        var $card = $(element).closest('.NB-organizer-ai-card');
        return {
            element: element,
            top: element.getBoundingClientRect().top,
            card: $card[0],
            card_top: $card.length ? $card[0].getBoundingClientRect().top : null
        };
    },

    restore_review_anchor: function (anchor) {
        var list = this.$review_list[0];
        var visible = function (element) { return element && element.offsetParent !== null; };
        if (visible(anchor.element)) {
            list.scrollTop += anchor.element.getBoundingClientRect().top - anchor.top;
        } else if (visible(anchor.card)) {
            list.scrollTop += anchor.card.getBoundingClientRect().top - anchor.card_top;
        }
    },

    // =================
    // = Review: other =
    // =================

    revise: function () {
        if (this.revising) return;
        var request = $.trim(this.revise_text);
        if (!request) {
            this.revise_error = 'empty_request';
            this.fill_revise_box();
            return;
        }
        this.revising = true;
        this.revise_error = null;
        this.fill_revise_box();
        this.after_saves(_.bind(function () {
            this.model.reorganize_revise(this.proposal.id, request, _.bind(function (data) {
                this.revising = false;
                this.update(data);
            }, this), _.bind(function (data) {
                this.revising = false;
                if (this.closed) return;
                if (data && data.limits) this.limits = data.limits;
                if (data && data.reason == 'already_running') {
                    this.load_status();
                    return;
                }
                this.revise_error = (data && data.reason) || 'request_failed';
                this.fill_revise_box();
            }, this));
        }, this), _.bind(function () {
            this.revising = false;
            this.fill_revise_box();
        }, this));
    },

    open_upgrade: function () {
        this.organizer.close(function () {
            NEWSBLUR.reader.open_premium_upgrade_modal();
        });
    },

    // ==================
    // = Confirm screen =
    // ==================

    // Step 3 before anything changes: what applying the reviewed proposal does, counted as the
    // review's tally counts it.
    make_confirm_screen: function () {
        var tally = this.confirm_tally(this.confirm_plan || this.review.plan);
        var can_apply = !this.limits || this.limits.can_apply;
        var undo_days = NEWSBLUR.ReaderOrganizerAI.UNDO_DAYS;
        var lines = [
            ['move', tally.moved, ngettext('%(count)s site moves to another folder', '%(count)s sites move to another folder', tally.moved)],
            ['copy', tally.copied, ngettext('%(count)s site is added to a second folder', '%(count)s sites are added to a second folder', tally.copied)],
            ['folder', tally.created, ngettext('%(count)s folder is added', '%(count)s folders are added', tally.created)],
            ['folder', tally.renamed, ngettext('%(count)s folder is renamed', '%(count)s folders are renamed', tally.renamed)],
            ['folder', tally.nested, ngettext('%(count)s folder moves inside another', '%(count)s folders move inside others', tally.nested)],
            ['folder', tally.merged, ngettext('%(count)s folder is merged into another', '%(count)s folders are merged into others', tally.merged)],
            ['folder', tally.removed, ngettext('%(count)s empty folder is removed', '%(count)s empty folders are removed', tally.removed)],
            ['mute', tally.muted, ngettext('%(count)s dead site is muted', '%(count)s dead sites are muted', tally.muted)],
            ['unsubscribe', tally.unsubscribed, ngettext('You unsubscribe from %(count)s dead site', 'You unsubscribe from %(count)s dead sites', tally.unsubscribed)]
        ];

        this.$confirm_back = $.make('button', {
            type: 'button',
            className: 'NB-modal-submit-button NB-modal-submit-grey',
            'data-ai-action': 'back-to-review'
        }, gettext('Back to review'));
        this.$confirm_apply = can_apply ? $.make('button', {
            type: 'button',
            className: 'NB-modal-submit-button NB-modal-submit-green',
            'data-ai-action': 'apply'
        }) : null;

        var $screen = $.make('div', { className: 'NB-organizer-ai-center NB-organizer-ai-confirm' }, [
            $.make('h3', { className: 'NB-organizer-ai-center-title' }).text(interpolate(
                ngettext('Apply %(count)s change?', 'Apply %(count)s changes?', tally.approved),
                { count: Inflector.commas(tally.approved) }, true)),
            tally.open && $.make('p', { className: 'NB-organizer-ai-center-text NB-organizer-ai-center-text-first' }).text(interpolate(ngettext(
                '%(count)s site still has no decision and stays as it is.',
                '%(count)s sites still have no decision and stay as they are.',
                tally.open), { count: Inflector.commas(tally.open) }, true)),
            $.make('p', { className: 'NB-organizer-ai-center-text' }).text(interpolate(ngettext(
                'Your current folders are saved first, so this can be undone for %(count)s day.',
                'Your current folders are saved first, so this can be undone for %(count)s days.',
                undo_days), { count: Inflector.commas(undo_days) }, true)),
            this.make_summary(lines, gettext('Nothing changes.')),
            tally.unsubscribed && $.make('p', { className: 'NB-organizer-ai-warning' }).text(interpolate(ngettext(
                "Unsubscribing from %(count)s dead site can't be undone. Undo puts your folders back, but doesn't subscribe you again.",
                "Unsubscribing from %(count)s dead sites can't be undone. Undo puts your folders back, but doesn't subscribe you again.",
                tally.unsubscribed), { count: Inflector.commas(tally.unsubscribed) }, true)),
            $.make('div', { className: 'NB-organizer-ai-buttons' }, [this.$confirm_back, this.$confirm_apply]),
            !can_apply && NEWSBLUR.utils.make_archive_callout(gettext('Applying changes needs Premium Archive. Your decisions are saved and will be here after you upgrade.'), {
                on_upgrade: _.bind(this.open_upgrade, this)
            })
        ]);
        this.fill_confirm_buttons();
        return $screen;
    },

    // The review's tally, with the folder changes that happen counted by kind.
    confirm_tally: function (plan) {
        var tally = this.review_tally();
        var kinds = { create: 0, rename: 0, nest: 0, merge: 0, remove: 0 };
        _.each(this.review.ops, function (op) {
            var state = plan.ops[op.id];
            if (state && state.offered && state.approved && state.happens && _.has(kinds, op.entry.type)) {
                kinds[op.entry.type] += 1;
            }
        });
        return _.extend(tally, {
            created: kinds.create,
            renamed: kinds.rename,
            nested: kinds.nest,
            merged: kinds.merge,
            removed: kinds.remove
        });
    },

    fill_confirm_buttons: function () {
        if (this.$confirm_apply) {
            this.$confirm_apply.prop('disabled', this.applying).toggleClass('NB-disabled', this.applying)
                .text(this.applying ? gettext('Applying...') : gettext('Apply changes'));
        }
        if (this.$confirm_back) {
            this.$confirm_back.prop('disabled', this.applying).toggleClass('NB-disabled', this.applying);
        }
        this.update_steps();
    },

    // What an apply does or did, one sentence for each kind of change, leaving out the kinds with
    // nothing in them. Each line is [kind, count, its message from ngettext].
    make_summary: function (lines, nothing_text) {
        var shown = _.filter(lines, function (line) { return line[1] > 0; });
        if (!shown.length) return $.make('p', { className: 'NB-organizer-ai-center-text' }, nothing_text);
        return $.make('ul', { className: 'NB-organizer-ai-summary' }, _.map(shown, function (line) {
            var $count = $.make('b', { className: 'NB-organizer-ai-summary-count' }).text(Inflector.commas(line[1]));
            return $.make('li', { className: 'NB-organizer-ai-summary-line NB-organizer-ai-summary-' + line[0] }, [
                $.make('span', { className: 'NB-organizer-ai-summary-mark' }),
                $.make('span', { className: 'NB-organizer-ai-summary-text' }, NEWSBLUR.utils.interpolate_nodes(line[2], { count: $count }))
            ]);
        }));
    },

    // ============
    // = Applying =
    // ============

    apply_proposal: function () {
        var proposal = this.proposal;
        if (this.applying || !proposal || proposal.status != 'ready') return;
        this.applying = true;
        this.clear_notice();
        this.fill_confirm_buttons();
        this.set_loading(true);
        this.start_folder_change();
        this.model.reorganize_apply(proposal.id, _.bind(function (data) {
            this.finish_folder_change(true, _.bind(function () {
                this.applying = false;
                this.set_loading(false);
                this.update(data);
            }, this));
        }, this), _.bind(function (data) {
            this.apply_failed(proposal.id, data);
        }, this));
    },

    // A refusal changed nothing, except already_applied, where another client may have applied it.
    // A request that failed may have applied some or all of it.
    apply_failed: function (proposal_id, data) {
        var reason = this.refusal_reason(data);
        this.finish_folder_change(!reason || reason == 'already_applied', _.bind(function () {
            this.applying = false;
            this.set_loading(false);
            if (this.closed) return;
            if (data && data.limits) this.limits = data.limits;
            if (reason == 'archive_required') {
                this.render();
                return;
            }
            this.show_server_state(proposal_id, reason == 'not_ready' ? 'apply_not_ready' : (reason || 'apply_failed'));
        }, this));
    },

    // The reason in a refusal from apps/reorganize/views.py, or null for a request that failed.
    refusal_reason: function (data) {
        return data && data.code == -1 && data.reason ? data.reason : null;
    },

    // After a refusal or a failed request, shows the proposal as the server has it now, with `code`
    // explained above it. A failed request that went through after all needs no explaining: the
    // applied screen, or the restored line, says what happened.
    show_server_state: function (proposal_id, code) {
        this.set_loading(true);
        this.model.reorganize_status(_.bind(function (data) {
            this.set_loading(false);
            if (this.closed) return;
            var proposal = data.proposal;
            var same = proposal && proposal.id == proposal_id;
            if (same && code == 'apply_failed' && proposal.status != 'ready') code = null;
            if (same && code == 'undo_failed' && proposal.status == 'undone') {
                this.show_notice(gettext('Your folders are back to how they were before the reorganization.'), 'done');
                code = null;
            }
            if (code) this.show_notice(this.error_message(code), 'error');
            this.update(data);
        }, this), _.bind(function () {
            this.set_loading(false);
            if (this.closed) return;
            this.show_notice(this.error_message(code), 'error');
            this.render();
        }, this));
    },

    // ===============
    // = Catching up =
    // ===============

    // After an apply or an undo, the rest of the app catches up the way a reload:feeds message from
    // apps/reorganize/apply.py makes every open client catch up (handle_realtime_update in reader.js):
    // the folders and subscriptions load again, which redraws the feed list and refreshes unread
    // counts. That message reaches this client too, while the request is answering or the folders
    // are loading, so NEWSBLUR.reader.flags.reloading_feeds, which makes reader.js skip it, is held
    // from the request until they have loaded, and they load once.
    start_folder_change: function () {
        NEWSBLUR.reader.flags['reloading_feeds'] = true;
    },

    finish_folder_change: function (changed, callback) {
        var finish = _.bind(function () {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
            if (changed && !this.closed) this.organizer.refresh_feeds();
            callback();
        }, this);
        if (!changed) {
            finish();
            return;
        }
        this.model.load_feeds(finish, finish);
    },

    // ==================
    // = Applied screen =
    // ==================

    // What the apply did, from the proposal's `result` (apply_proposal in apps/reorganize/apply.py),
    // and the way back. A proposal left "applying" stopped partway and has no result.
    make_applied_screen: function () {
        var proposal = this.proposal;
        var finished = proposal.status == 'applied';
        var date = proposal.applied_date && this.format_date(proposal.applied_date, true);
        var $text;
        if (finished) {
            $text = date && $.make('p', { className: 'NB-organizer-ai-center-text' }).text(
                interpolate(gettext('Applied on %(date)s.'), { date: date }, true));
        } else {
            $text = $.make('p', {
                className: 'NB-organizer-ai-center-text' + (proposal.can_undo ? ' NB-organizer-ai-center-text-first' : '')
            }).text(date
                ? interpolate(gettext('Applying it on %(date)s stopped partway, so some of your folders may have changed.'), { date: date }, true)
                : gettext('Applying it stopped partway, so some of your folders may have changed.'));
        }
        this.$skipped_list = null;
        this.$applied_actions = $.make('div', { className: 'NB-organizer-ai-applied-actions' });
        var $screen = $.make('div', { className: 'NB-organizer-ai-center NB-organizer-ai-applied' }, [
            $.make('h3', { className: 'NB-organizer-ai-center-title' }, finished
                ? gettext('Folders updated')
                : gettext("This reorganization didn't finish")),
            $text,
            !finished && proposal.can_undo && $.make('p', { className: 'NB-organizer-ai-center-text' },
                gettext('Undo puts your folders back as they were before it started.')),
            finished && this.make_summary(this.result_lines(proposal.result || {}), gettext('Nothing changed.')),
            finished && this.make_skipped((proposal.result || {}).skipped),
            this.$applied_actions
        ]);
        this.fill_applied_actions();
        return $screen;
    },

    result_lines: function (result) {
        var count = function (name) { return _.isNumber(result[name]) ? result[name] : 0; };
        return [
            ['move', count('moved'), ngettext('%(count)s site moved to another folder', '%(count)s sites moved to another folder', count('moved'))],
            ['copy', count('copied'), ngettext('%(count)s site added to a second folder', '%(count)s sites added to a second folder', count('copied'))],
            ['folder', count('folders_created'), ngettext('%(count)s folder added', '%(count)s folders added', count('folders_created'))],
            ['folder', count('folders_changed'), ngettext('%(count)s folder renamed or moved', '%(count)s folders renamed or moved', count('folders_changed'))],
            ['folder', count('folders_merged'), ngettext('%(count)s folder merged into another', '%(count)s folders merged into others', count('folders_merged'))],
            ['folder', count('folders_removed'), ngettext('%(count)s empty folder removed', '%(count)s empty folders removed', count('folders_removed'))],
            ['mute', count('muted'), ngettext('%(count)s dead site muted', '%(count)s dead sites muted', count('muted'))],
            ['unsubscribe', count('unsubscribed'), ngettext('Unsubscribed from %(count)s dead site', 'Unsubscribed from %(count)s dead sites', count('unsubscribed'))]
        ];
    },

    // What the apply left out (`skipped` in apps/reorganize/plan.py), counted, with the list behind
    // a toggle.
    make_skipped: function (skipped) {
        skipped = _.isArray(skipped) ? skipped : [];
        if (!skipped.length) return null;
        this.$skipped_toggle = $.make('button', {
            type: 'button',
            className: 'NB-organizer-ai-link',
            'data-ai-action': 'toggle-skipped',
            'aria-controls': 'NB-organizer-ai-skipped-list'
        });
        this.$skipped_list = $.make('ul', { className: 'NB-organizer-ai-skipped-list', id: 'NB-organizer-ai-skipped-list' },
            _.map(skipped, _.bind(function (item) {
                item = item || {};
                return $.make('li', { className: 'NB-organizer-ai-skipped-item' }, [
                    $.make('span', { className: 'NB-organizer-ai-skipped-what' }).text(this.skipped_title(item.id)),
                    $.make('span', { className: 'NB-organizer-ai-skipped-why' }).text(this.skip_reason(item.reason))
                ]);
            }, this)));
        var $skipped = $.make('div', { className: 'NB-organizer-ai-skipped' }, [
            $.make('p', { className: 'NB-organizer-ai-skipped-head' }, [
                $.make('span').text(interpolate(ngettext("%(count)s change couldn't be made.", "%(count)s changes couldn't be made.", skipped.length),
                    { count: Inflector.commas(skipped.length) }, true)),
                this.$skipped_toggle
            ]),
            this.$skipped_list
        ]);
        this.fill_skipped();
        return $skipped;
    },

    fill_skipped: function () {
        if (!this.$skipped_list) return;
        this.$skipped_toggle.attr('aria-expanded', this.showing_skipped ? 'true' : 'false')
            .text(this.showing_skipped ? gettext('Hide them') : gettext('Show them'));
        this.$skipped_list.toggleClass('NB-hidden', !this.showing_skipped);
    },

    toggle_skipped: function () {
        this.showing_skipped = !this.showing_skipped;
        this.fill_skipped();
        this.organizer.resize();
    },

    // A skipped item in words, found in the proposal by its id.
    skipped_title: function (id) {
        var proposal = this.proposal;
        var data = proposal.proposal || {};
        var find = function (section) {
            return _.find(_.isArray(data[section]) ? data[section] : [], function (entry) {
                return _.isObject(entry) && _.isString(id) && entry.id === id;
            });
        };
        var folder = _.bind(function (key) { return this.proposal_folder_name(data, key); }, this);

        var move = find('moves');
        if (move) {
            return interpolate(gettext('Move %(site)s to %(folder)s'),
                { site: this.skipped_site_title(move.feed_id), folder: folder(move.to) }, true);
        }
        var op = find('ops');
        if (op && op.type == 'create') return interpolate(gettext('Add the folder %(folder)s'), { folder: folder(op.folder) }, true);
        if (op && op.type == 'rename') {
            return interpolate(gettext('Rename “%(old)s” to “%(new)s”'),
                { old: folder(op.folder), 'new': _.isString(op.name) ? op.name : '' }, true);
        }
        if (op && op.type == 'nest') {
            return interpolate(gettext('Put %(folder)s inside %(parent)s'), { folder: folder(op.folder), parent: folder(op.parent) }, true);
        }
        if (op && op.type == 'merge') {
            return interpolate(gettext('Merge %(folder)s into %(into)s'), { folder: folder(op.folder), into: folder(op.into) }, true);
        }
        if (op && op.type == 'remove') return interpolate(gettext('Remove the folder %(folder)s'), { folder: folder(op.folder) }, true);
        var dead = find('dead');
        if (dead) {
            var action = ((proposal.decisions || {}).dead || {})[dead.id] || dead.suggest;
            var site = this.skipped_site_title(dead.feed_id);
            if (action == 'unsubscribe') return interpolate(gettext('Unsubscribe from %(site)s'), { site: site }, true);
            if (action == 'mute') return interpolate(gettext('Mute %(site)s'), { site: site }, true);
        }
        return gettext('One of the proposed changes');
    },

    // A proposal's folder key in words: the top level, an existing folder by the name it had when
    // the proposal was made, or a new folder by its proposed name.
    proposal_folder_name: function (data, key) {
        if (key == NEWSBLUR.ReaderOrganizerAI.Rules.ROOT_KEY) return gettext('Top level');
        var folders = data.folders && _.isObject(data.folders) ? data.folders : {};
        var entry = _.isString(key) && _.has(folders, key) ? folders[key] : null;
        if (entry && _.isArray(entry.path) && entry.path.length) return String(_.last(entry.path));
        if (entry && _.isString(entry.name)) return entry.name;
        return gettext('a folder');
    },

    skipped_site_title: function (feed_id) {
        var feed = this.model.get_feed(feed_id);
        return feed ? this.site_title(feed) : gettext('a site you no longer follow');
    },

    // Why plan.py skipped an item, from its reason code.
    skip_reason: function (reason) {
        var reasons = {
            'invalid': gettext("The proposal described it in a way that couldn't be applied."),
            'folder_changed': gettext('A folder it needs was renamed, moved or deleted after the proposal was made.'),
            'feed_not_in_folder': gettext('The site was no longer where the proposal expected it.'),
            'locked': gettext('It involves a folder you locked.'),
            'name_taken': gettext('Another folder there already has this name.'),
            'would_cycle': gettext('It would have put a folder inside itself.'),
            'not_empty': gettext('The folder still had sites or folders in it, so it stayed.'),
            'folder_rejected': gettext('It needs a new folder you rejected.')
        };
        return reasons[reason] || gettext("This change couldn't be made.");
    },

    // The applied screen's buttons, or the question that comes before an undo.
    fill_applied_actions: function () {
        if (!this.$applied_actions || this.screen != 'applied') return;
        var proposal = this.proposal;
        this.update_steps();
        this.$applied_actions.empty();
        if (this.asking_undo && proposal.can_undo) {
            this.$applied_actions.append(this.make_undo_question());
            this.organizer.resize();
            return;
        }
        var undo_until = proposal.can_undo && proposal.undo_until && this.format_date(proposal.undo_until, true);
        var note = proposal.can_undo
            ? undo_until && interpolate(gettext('You can undo this until %(date)s.'), { date: undo_until }, true)
            : gettext('This reorganization can no longer be undone.');
        this.$applied_actions.append(
            $.make('div', { className: 'NB-organizer-ai-buttons' }, [
                proposal.can_undo && $.make('button', {
                    type: 'button',
                    className: 'NB-modal-submit-button NB-modal-submit-grey NB-organizer-ai-undo-start',
                    'data-ai-action': 'ask-undo'
                }, gettext('Undo this reorganization')),
                proposal.status == 'applied' && $.make('button', {
                    type: 'button',
                    className: 'NB-modal-submit-button NB-modal-submit-grey',
                    'data-ai-action': 'reorganize-again'
                }, gettext('Reorganize again')),
                $.make('button', {
                    type: 'button',
                    className: 'NB-modal-submit-button NB-modal-submit-green',
                    'data-ai-action': 'done'
                }, gettext('Done'))
            ]),
            note && $.make('p', { className: 'NB-organizer-ai-note NB-organizer-ai-undo-note' }).text(note)
        );
        this.organizer.resize();
    },

    // ===========
    // = Undoing =
    // ===========

    // What an undo does, as undo_proposal in apps/reorganize/apply.py does it. Without a result, as
    // after an apply that stopped partway, every line that could apply is said.
    make_undo_question: function () {
        var result = this.proposal.result;
        var lines = [
            gettext('Your folders go back to how they were before this reorganization.'),
            gettext("Sites you've subscribed to since then stay.")
        ];
        if (!result || result.muted) lines.push(gettext('Dead sites it muted are unmuted.'));
        if (!result) {
            lines.push(gettext('Sites it unsubscribed you from are not brought back.'));
        } else if (result.unsubscribed) {
            lines.push(interpolate(ngettext(
                'The %(count)s dead site it unsubscribed you from is not brought back.',
                'The %(count)s dead sites it unsubscribed you from are not brought back.',
                result.unsubscribed), { count: Inflector.commas(result.unsubscribed) }, true));
        }
        var disabled = this.undoing ? 'disabled' : null;
        return $.make('div', { className: 'NB-organizer-ai-question', role: 'group', 'aria-labelledby': 'NB-organizer-ai-undo-title' }, [
            $.make('div', { className: 'NB-organizer-ai-question-title', id: 'NB-organizer-ai-undo-title' }, gettext('Undo this reorganization?')),
            $.make('ul', { className: 'NB-organizer-ai-question-text' }, _.map(lines, function (line) {
                return $.make('li').text(line);
            })),
            $.make('div', { className: 'NB-organizer-ai-buttons' }, [
                $.make('button', {
                    type: 'button',
                    className: 'NB-modal-submit-button NB-modal-submit-grey NB-organizer-ai-undo-cancel' + (disabled ? ' NB-disabled' : ''),
                    'data-ai-action': 'cancel-undo',
                    disabled: disabled
                }, gettext('Keep the new folders')),
                $.make('button', {
                    type: 'button',
                    className: 'NB-modal-submit-button NB-modal-submit-red' + (disabled ? ' NB-disabled' : ''),
                    'data-ai-action': 'undo',
                    disabled: disabled
                }, this.undoing ? gettext('Undoing...') : gettext('Undo'))
            ])
        ]);
    },

    ask_undo: function () {
        if (!this.proposal.can_undo || this.undoing) return;
        this.asking_undo = true;
        this.clear_notice();
        this.fill_applied_actions();
        $('.NB-organizer-ai-undo-cancel', this.$applied_actions).focus();
    },

    cancel_undo: function () {
        if (this.undoing) return;
        this.asking_undo = false;
        this.fill_applied_actions();
        $('.NB-organizer-ai-undo-start', this.$applied_actions).focus();
    },

    undo_proposal: function () {
        var proposal = this.proposal;
        if (this.undoing || !proposal || !proposal.can_undo) return;
        this.undoing = true;
        this.clear_notice();
        this.fill_applied_actions();
        this.set_loading(true);
        this.start_folder_change();
        this.model.reorganize_undo(proposal.id, _.bind(function (data) {
            this.finish_folder_change(true, _.bind(function () {
                this.undoing = false;
                this.set_loading(false);
                if (this.closed) return;
                this.show_notice(gettext('Your folders are back to how they were before the reorganization.'), 'done');
                this.update(data);
            }, this));
        }, this), _.bind(function (data) {
            // A refusal changed nothing, except not_applied, where another client may have undone it.
            // A request that failed may have undone it.
            var reason = this.refusal_reason(data);
            this.finish_folder_change(!reason || reason == 'not_applied', _.bind(function () {
                this.undoing = false;
                this.asking_undo = false;
                this.set_loading(false);
                if (this.closed) return;
                this.show_server_state(proposal.id, reason || 'undo_failed');
            }, this));
        }, this));
    },

    // ==========
    // = Notice =
    // ==========

    // A line above the screen: why an apply or undo was refused or failed, or that the folders were
    // restored. It stays through the screen change that follows and goes at the reader's next step.
    show_notice: function (text, kind) {
        this.$notice.text(text || '').toggleClass('NB-hidden', !text)
            .toggleClass('NB-organizer-ai-error', kind == 'error')
            .toggleClass('NB-organizer-ai-notice-done', kind == 'done')
            .attr('role', kind == 'error' ? 'alert' : 'status');
        this.organizer.resize();
    },

    clear_notice: function () {
        this.show_notice(null);
    },

    restore_review_scroll: function () {
        if (this.screen == 'review' && this.$review_list) this.$review_list.scrollTop(this.review_scroll);
    },

    handle_action: function (action) {
        if (action == 'back-to-review') {
            this.visit_step('review');
        } else if (action == 'apply') {
            this.apply_proposal();
        } else if (action == 'toggle-skipped') {
            this.toggle_skipped();
        } else if (action == 'ask-undo') {
            this.ask_undo();
        } else if (action == 'cancel-undo') {
            this.cancel_undo();
        } else if (action == 'undo') {
            this.undo_proposal();
        } else if (action == 'reorganize-again') {
            this.visit_step('setup');
        } else if (action == 'done') {
            this.organizer.close();
        }
    },

    // ===========
    // = Helpers =
    // ===========

    // A sentence for a refusal or run error code from apps/reorganize/views.py, never the code itself.
    error_message: function (code) {
        var undo_days = NEWSBLUR.ReaderOrganizerAI.UNDO_DAYS;
        var messages = {
            'archive_required': gettext('Applying changes needs Premium Archive.'),
            'apply_not_ready': gettext("This proposal isn't ready to apply."),
            'apply_failed': gettext("The changes couldn't be applied. Please try again."),
            'not_applied': gettext("This reorganization isn't applied, so there's nothing to undo."),
            'expired': interpolate(ngettext(
                "It's been more than %(count)s day, so this reorganization can no longer be undone.",
                "It's been more than %(count)s days, so this reorganization can no longer be undone.",
                undo_days), { count: Inflector.commas(undo_days) }, true),
            'superseded': gettext('A later reorganization was applied, so this one can no longer be undone.'),
            'undo_failed': gettext("The reorganization couldn't be undone. Please try again."),
            'no_api_key': gettext("The AI isn't available right now. Please try again later."),
            'nothing_to_organize': gettext('There was nothing for the AI to organize. Open more of your folders, or choose Reorganize so it can add folders.'),
            'model_declined': gettext("The AI couldn't finish a proposal for your sites. Please try again."),
            'model_failed': gettext('The AI had trouble answering. Please try again.'),
            'run_failed': gettext('Something went wrong while making the proposal. Please try again.'),
            'stalled': gettext('The proposal took too long and was stopped. Please try again.'),
            'already_applied': gettext('This proposal has already been applied.'),
            'already_running': gettext('A proposal is already being made.'),
            'monthly_limit': gettext("You've had this month's proposal."),
            'daily_cap': gettext("You've reached today's limit on proposals."),
            'unknown_level': gettext('Choose how much to change, then try again.'),
            'invalid_locks': gettext("Your locked folders couldn't be saved. Please try again."),
            'locks_failed': gettext("Your locked folders couldn't be saved. Please try again."),
            'decisions_failed': gettext("Your last choice couldn't be saved, so this shows the choices that are saved. Please try again."),
            'replaced': gettext('This proposal was replaced by a newer one.'),
            'not_ready': gettext("This proposal can't be changed right now."),
            'not_found': gettext("This proposal couldn't be found."),
            'revision_limit': gettext("This proposal can't be revised again."),
            'empty_request': gettext('Say what the AI should change, then try again.')
        };
        return messages[code] || gettext('Something went wrong. Please try again.');
    },

    // An ISO date from the server ("...Z") in the reader's language and time zone.
    format_date: function (iso_date, with_time) {
        var date = new Date(iso_date);
        var lang = document.documentElement.lang || undefined;
        if (with_time) return date.toLocaleString(lang, { dateStyle: 'long', timeStyle: 'short' });
        return date.toLocaleDateString(lang, { dateStyle: 'long' });
    },

    // ==========
    // = Events =
    // ==========

    handle_click: function (elem, e) {
        if (this.review && this.review.open_menu !== null &&
            !$(e.target).closest('.NB-organizer-ai-lock-menu, .NB-organizer-ai-lock-button').length) {
            this.close_lock_menu();
        }

        $.targetIs(e, { tagSelector: '[data-review]' }, _.bind(function ($t) {
            e.preventDefault();
            if (this.screen == 'review' && this.review) this.handle_review_action($t);
        }, this));

        $.targetIs(e, { tagSelector: '[data-ai-action]' }, _.bind(function ($t) {
            e.preventDefault();
            if (!$t.prop('disabled')) this.handle_action($t.attr('data-ai-action'));
        }, this));

        $.targetIs(e, { tagSelector: '.NB-organizer-ai-lock-option' }, _.bind(function ($t) {
            e.preventDefault();
            this.choose_lock($t);
        }, this));

        $.targetIs(e, { tagSelector: '.NB-organizer-ai-propose' }, _.bind(function ($t) {
            e.preventDefault();
            this.propose();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-organizer-ai-step' }, _.bind(function ($t) {
            e.preventDefault();
            this.visit_step($t.data('step'));
        }, this));

        $.targetIs(e, { tagSelector: '.NB-organizer-ai-retry' }, _.bind(function ($t) {
            e.preventDefault();
            this.load_status();
        }, this));
    },

    handle_change: function (elem, e) {
        $.targetIs(e, { tagSelector: '.NB-organizer-ai-level-input' }, _.bind(function ($t) {
            this.form.level = $t.val();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-organizer-ai-find-dead' }, _.bind(function ($t) {
            this.form.find_dead = $t.is(':checked');
        }, this));
    },

    handle_input: function (elem, e) {
        $.targetIs(e, { tagSelector: '.NB-organizer-ai-instructions' }, _.bind(function ($t) {
            this.form.instructions = $t.val();
        }, this));

        $.targetIs(e, { tagSelector: '.NB-organizer-ai-revise-input' }, _.bind(function ($t) {
            this.revise_text = $t.val();
            if (this.revise_error == 'empty_request') {
                this.revise_error = null;
                this.fill_revise_box();
            }
        }, this));
    },

    handle_keydown: function (elem, e) {
        if (e.which == 27 && this.review && this.review.open_menu !== null) {
            e.preventDefault();
            e.stopPropagation();
            this.close_lock_menu(true);
            return;
        }
        if (e.which != 13 && e.which != 32) return;
        $.targetIs(e, { tagSelector: '.NB-organizer-ai-lock-option' }, _.bind(function ($t) {
            e.preventDefault();
            this.choose_lock($t);
        }, this));
    },

    choose_lock: function ($option) {
        var index = parseInt($option.closest('.NB-organizer-ai-folder').data('index'), 10);
        var lock = $option.data('lock') || null;
        if (!this.folder_rows[index] || lock == this.own_lock(this.folder_rows[index].path)) return;
        this.change_lock(index, lock);
    }

};
