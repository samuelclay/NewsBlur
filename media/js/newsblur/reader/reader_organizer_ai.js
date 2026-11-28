// reader_organizer_ai.js: the "Reorganize with AI" tab of the Organize sites dialog
// (reader_organizer.js). The AI proposes a new arrangement of the reader's sites and folders, the
// reader approves or rejects each change, and the approved changes are applied, all through
// apps/reorganize/views.py. A proposal is made in the background by apps/reorganize/tasks.py. Its
// progress arrives over the socket (handle_reorganize_event in reader.js), and the tab also polls
// while a run works in case the socket is down.
//
// The tab shows one screen at a time, picked from the current proposal's status by current_screen():
// setup, progress, review or applied. Each screen is built by its own make_*_screen method.

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

    this.$steps = this.make_steps();
    this.$screen = $.make('div', { className: 'NB-organizer-ai-screen' });
    this.$tab = $.make('div', { className: 'NB-tab NB-tab-ai NB-organizer-ai' }, [
        this.$steps,
        this.$screen
    ]);

    this.$tab.bind('click', $.rescope(this.handle_click, this));
    this.$tab.bind('change', $.rescope(this.handle_change, this));
    this.$tab.bind('input', $.rescope(this.handle_input, this));
    this.$tab.bind('keydown', $.rescope(this.handle_keydown, this));
};

_.extend(NEWSBLUR.ReaderOrganizerAI, {

    POLL_INTERVAL: 4000,

    INSTRUCTIONS_LIMIT: 4000

});

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
            if (proposal && proposal.status == 'failed') this.prefill_form(proposal);
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
        if (status == 'ready' && !this.revisiting_setup) return 'review';
        if (status == 'applying' || status == 'applied') return 'applied';
        return 'setup';
    },

    render: function () {
        var screen = this.current_screen();
        if (screen == 'progress' && this.screen == 'progress' && this.progress_id == this.proposal.id) {
            this.update_progress();
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
        var current = { 'setup': 'setup', 'progress': 'setup', 'review': 'review', 'applied': 'apply' }[this.screen];
        $('.NB-organizer-ai-step', this.$steps).each(_.bind(function (i, button) {
            var step = $(button).data('step');
            var is_current = step == current;
            $(button).toggleClass('NB-active', is_current)
                .attr('aria-current', is_current ? 'step' : null)
                .prop('disabled', !is_current && !this.can_visit_step(step));
        }, this));
    },

    // A ready proposal can be set aside to start again, and returned to from setup.
    can_visit_step: function (step) {
        var is_ready = this.proposal && this.proposal.status == 'ready';
        if (step == 'setup') return is_ready && this.screen == 'review';
        if (step == 'review') return is_ready && this.screen == 'setup';
        return false;
    },

    visit_step: function (step) {
        if (!this.can_visit_step(step)) return;
        this.revisiting_setup = step == 'setup';
        this.render();
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

    // Locking a folder also drops the locks inside it, since its own lock now covers them.
    change_lock: function (index, lock) {
        var path = this.folder_rows[index].path;
        var keeps = function (locked_path) {
            var is_inside = locked_path.length >= path.length && _.isEqual(locked_path.slice(0, path.length), path);
            return lock ? !is_inside : !_.isEqual(locked_path, path);
        };
        var locks = {
            keep: _.filter(this.locks.keep, keeps),
            skip: _.filter(this.locks.skip, keeps)
        };
        if (lock) locks[lock].push(path);
        this.locks = locks;
        this.refresh_folder_list();
        this.save_locks();
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
                this.refresh_folder_list();
            } else if (had_error) {
                this.update_setup_notes();
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

    make_review_screen: function () {
        var proposal = this.proposal.proposal || {};
        var count = function (key) { return (proposal[key] || []).length; };
        return $.make('div', { className: 'NB-organizer-ai-center NB-organizer-ai-review' }, [
            $.make('h3', { className: 'NB-organizer-ai-center-title' }, gettext('The proposal is ready')),
            $.make('ul', { className: 'NB-organizer-ai-tally' }, [
                this.make_tally_line(interpolate(ngettext("%(count)s folder change", "%(count)s folder changes", count('ops')),
                    { count: Inflector.commas(count('ops')) }, true)),
                this.make_tally_line(interpolate(ngettext("%(count)s site move", "%(count)s site moves", count('moves')),
                    { count: Inflector.commas(count('moves')) }, true)),
                this.make_tally_line(interpolate(ngettext("%(count)s dead site", "%(count)s dead sites", count('dead')),
                    { count: Inflector.commas(count('dead')) }, true))
            ])
        ]);
    },

    make_tally_line: function (text) {
        return $.make('li', { className: 'NB-organizer-ai-tally-line' }).text(text);
    },

    // ==================
    // = Applied screen =
    // ==================

    make_applied_screen: function () {
        var proposal = this.proposal;
        var is_applied = proposal.status == 'applied';
        return $.make('div', { className: 'NB-organizer-ai-center NB-organizer-ai-applied' }, [
            $.make('h3', { className: 'NB-organizer-ai-center-title' }, is_applied
                ? gettext('Folders updated')
                : gettext('Applying the changes...')),
            is_applied && proposal.applied_date && $.make('p', { className: 'NB-organizer-ai-center-text' }).text(
                interpolate(gettext('Applied on %(date)s.'), { date: this.format_date(proposal.applied_date, true) }, true))
        ]);
    },

    // ===========
    // = Helpers =
    // ===========

    // A sentence for a refusal or run error code from apps/reorganize/views.py, never the code itself.
    error_message: function (code) {
        var messages = {
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
            'locks_failed': gettext("Your locked folders couldn't be saved. Please try again.")
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
    },

    handle_keydown: function (elem, e) {
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
