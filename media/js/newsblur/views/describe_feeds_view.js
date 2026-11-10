// describe_feeds_view.js: the Describe tab of the Add Site view.
//
// A written description of what you want to read is sent to /discover/describe/start,
// which runs the pipeline in apps/describe/pipeline.py. Results stream in over the
// socket as describe:* events (relayed by node/describe.coffee); when the socket is
// quiet the view polls /discover/describe/status so nothing is missed. The last 20
// searches live in a rail on the left and replay instantly from the server cache.
NEWSBLUR.Views.DescribeFeedsView = Backbone.View.extend({

    className: 'NB-describe',

    events: {
        "click .NB-describe-submit": "submit_prompt",
        "keydown .NB-describe-input": "handle_input_keydown",
        "input .NB-describe-input": "handle_input_change",
        "click .NB-describe-history-item": "open_history_item",
        "click .NB-describe-history-delete": "delete_history_item",
        "click .NB-describe-new-search": "start_new_search",
        "click .NB-describe-search-again": "search_again",
        "click .NB-describe-upgrade": "open_upgrade",
        "click .NB-describe-example": "use_example"
    },

    POLL_INTERVAL: 2500,
    SOCKET_GRACE: 6000,

    // describe_feeds_view.js: pipeline phases in order, as shown in the progress stepper.
    PHASES: [
        { id: 'expanding', label: function () { return gettext('Reading'); } },
        { id: 'searching', label: function () { return gettext('Searching feeds'); } },
        { id: 'judging', label: function () { return gettext('Judging'); } },
        { id: 'hunting', label: function () { return gettext('Searching the web'); } },
        { id: 'complete', label: function () { return gettext('Done'); } }
    ],

    EXAMPLES: [
        function () { return gettext('Reviews of new iOS apps with lots of screenshots'); },
        function () { return gettext('Long essays about cities, housing and public transit'); },
        function () { return gettext('Indie game developers writing about their work in progress'); }
    ],

    initialize: function (options) {
        this.options = options || {};
        this.add_site_view = this.options.add_site_view;
        this.history = [];
        this.usage = null;
        this.search = null;
        this.rows = {};
        this.cards = {};
        this.poll_timer = null;
        this.last_event_at = 0;
        this.pending_scroll_top = this.options.initial_scroll_top || null;
        this.history_loaded = false;
    },

    close: function () {
        this.stop_polling();
        this.$el.remove();
    },

    // =============
    // = Rendering =
    // =============

    render: function () {
        this.$el.html([
            $.make('div', { className: 'NB-describe-rail' }, [
                $.make('div', { className: 'NB-describe-rail-header' }, [
                    $.make('div', { className: 'NB-describe-rail-title' }, gettext('Your searches')),
                    $.make('div', { className: 'NB-describe-new-search', role: 'button' }, [
                        $.make('span', { className: 'NB-describe-new-search-plus' }, '+'),
                        gettext('New')
                    ])
                ]),
                $.make('div', { className: 'NB-describe-history' }),
                $.make('div', { className: 'NB-describe-usage' })
            ]),
            $.make('div', { className: 'NB-describe-main' }, [
                $.make('div', { className: 'NB-describe-composer' }, [
                    $.make('div', { className: 'NB-describe-composer-box' }, [
                        $.make('img', { className: 'NB-describe-composer-icon', src: '/media/img/icons/lucide/sparkles.svg' }),
                        $.make('textarea', {
                            className: 'NB-describe-input',
                            rows: 1,
                            placeholder: gettext('Describe the feeds you’re looking for, like “reviews of new iOS apps with screenshots”')
                        }),
                        $.make('div', { className: 'NB-describe-submit NB-modal-submit-button NB-modal-submit-green', role: 'button' }, gettext('Find feeds'))
                    ]),
                    $.make('div', { className: 'NB-describe-composer-hint' }, gettext('NewsBlur reads your description, searches its index of feeds and the open web, then judges every match. It can take a minute.'))
                ]),
                $.make('div', { className: 'NB-describe-status NB-hidden' }),
                $.make('div', { className: 'NB-describe-body' })
            ])
        ]);
        this.$el.data('view', this);
        this.render_empty_state();
        this.load_history();

        if (this.options.initial_search_id) {
            this.open_search(this.options.initial_search_id, { scroll_top: this.pending_scroll_top });
        } else if (this.options.initial_query) {
            this.$('.NB-describe-input').val(this.options.initial_query);
            this.start_search(this.options.initial_query);
        }
        return this;
    },

    // describe_feeds_view.js: called whenever the Add Site view re-renders this tab, including after the
    // Grid/List toggle or a column change, so the results are rebuilt in the new layout.
    on_shown: function () {
        this.autosize_input();
        if (this.search && this.rendered_layout !== this.current_layout()) {
            this.pending_scroll_top = this.scroll_top();
            this.show_search(this.search);
        }
        if (!this.search) {
            this.$('.NB-describe-input').focus();
        }
    },

    current_layout: function () {
        return [this.add_site_view.view_mode, NEWSBLUR.assets.preference('add_site_grid_columns') || 'auto'].join(':');
    },

    render_empty_state: function () {
        var self = this;
        var $examples = $.make('div', { className: 'NB-describe-examples' }, _.map(this.EXAMPLES, function (example) {
            var text = example();
            return $.make('div', { className: 'NB-describe-example', role: 'button', 'data-prompt': text }, [
                $.make('img', { src: '/media/img/icons/lucide/sparkles.svg', className: 'NB-describe-example-icon' }),
                $.make('span', text)
            ]);
        }));
        this.$('.NB-describe-body').html($.make('div', { className: 'NB-describe-empty' }, [
            $.make('div', { className: 'NB-describe-empty-title' }, gettext('Try describing something like')),
            $examples
        ]));
        this.$('.NB-describe-status').addClass('NB-hidden').empty();
    },

    render_upgrade_state: function (message) {
        this.$('.NB-describe-body').html($.make('div', { className: 'NB-describe-upgrade-card' }, [
            $.make('img', { src: '/media/img/icons/lucide/sparkles.svg', className: 'NB-describe-upgrade-icon' }),
            $.make('div', { className: 'NB-describe-upgrade-title' }, gettext('Find feeds by describing them')),
            $.make('div', { className: 'NB-describe-upgrade-desc' }, message || gettext('Describing the feeds you want is a premium feature. Upgrade to search by description.')),
            $.make('div', { className: 'NB-describe-upgrade NB-modal-submit-button NB-modal-submit-green', role: 'button' }, gettext('Upgrade to Premium'))
        ]));
    },

    // ===========
    // = History =
    // ===========

    load_history: function () {
        var self = this;
        NEWSBLUR.assets.make_request('/discover/describe/history', {}, function (data) {
            self.history = data.searches || [];
            self.usage = data.usage || null;
            self.history_loaded = true;
            self.render_history();
            self.render_usage();
            if (self.usage && self.usage.limit === 0 && !self.search) {
                self.render_upgrade_state();
            }
        }, function () {
            self.history_loaded = true;
            self.render_history();
        }, { request_type: 'GET' });
    },

    render_history: function () {
        var self = this;
        var $history = this.$('.NB-describe-history');
        if (!this.history.length) {
            $history.html($.make('div', { className: 'NB-describe-history-empty' },
                this.history_loaded ? gettext('Searches you run will be kept here.') : gettext('Loading…')));
            return;
        }
        var active_id = this.search && this.search.id;
        $history.html(_.map(this.history, function (entry) {
            var is_active = entry.id === active_id;
            var is_running = entry.status === 'queued' || entry.status === 'running';
            var meta;
            if (entry.status === 'error') {
                meta = gettext('Failed');
            } else if (is_running) {
                meta = gettext('Searching…');
            } else {
                meta = interpolate(ngettext('%(count)s feed', '%(count)s feeds', entry.result_count), {count: entry.result_count}, true);
            }
            return $.make('div', {
                className: 'NB-describe-history-item' + (is_active ? ' NB-active' : '') + (is_running ? ' NB-running' : ''),
                'data-search-id': entry.id,
                role: 'button'
            }, [
                $.make('div', { className: 'NB-describe-history-prompt', dir: 'auto' }, entry.prompt),
                $.make('div', { className: 'NB-describe-history-meta' }, [
                    $.make('span', { className: 'NB-describe-history-count' }, meta),
                    $.make('span', { className: 'NB-describe-history-date' }, self.relative_date(entry.created_date))
                ]),
                $.make('div', { className: 'NB-describe-history-delete', title: gettext('Remove from history'), role: 'button' }, '×')
            ]);
        }));
    },

    render_usage: function () {
        var $usage = this.$('.NB-describe-usage');
        if (!this.usage) {
            $usage.empty();
            return;
        }
        var text;
        if (this.usage.limit === null || this.usage.limit === undefined) {
            text = gettext('Unlimited searches');
        } else if (this.usage.limit === 0) {
            text = gettext('Premium feature');
        } else {
            text = interpolate(gettext('%(remaining)s of %(limit)s searches left today'), {
                remaining: this.usage.remaining,
                limit: this.usage.limit
            }, true);
        }
        $usage.text(text);
    },

    update_history_entry: function (search) {
        var entry = _.find(this.history, function (e) { return e.id === search.id; });
        var summary = {
            id: search.id,
            prompt: search.prompt,
            status: search.status,
            phase: search.phase,
            created_date: search.created_date,
            completed_date: search.completed_date,
            result_count: search.result_count
        };
        if (entry) {
            _.extend(entry, summary);
        } else {
            this.history.unshift(summary);
        }
        this.render_history();
    },

    open_history_item: function (e) {
        if ($(e.target).closest('.NB-describe-history-delete').length) return;
        var search_id = $(e.currentTarget).data('search-id');
        if (this.search && this.search.id === search_id) return;
        this.open_search(search_id);
    },

    delete_history_item: function (e) {
        e.preventDefault();
        e.stopPropagation();
        var self = this;
        var $item = $(e.currentTarget).closest('.NB-describe-history-item');
        var search_id = $item.data('search-id');
        $item.addClass('NB-deleting');
        NEWSBLUR.assets.make_request('/discover/describe/delete', { search_id: search_id }, function (data) {
            self.history = data.searches || _.reject(self.history, function (e) { return e.id === search_id; });
            if (self.search && self.search.id === search_id) {
                self.start_new_search();
            }
            self.render_history();
        }, function () {
            $item.removeClass('NB-deleting');
        });
    },

    start_new_search: function () {
        this.stop_polling();
        this.search = null;
        this.rows = {};
        this.cards = {};
        this.$('.NB-describe-input').val('');
        this.autosize_input();
        this.render_history();
        if (this.usage && this.usage.limit === 0) {
            this.render_upgrade_state();
        } else {
            this.render_empty_state();
        }
        this.$('.NB-describe-input').focus();
    },

    // =============
    // = Searching =
    // =============

    submit_prompt: function () {
        var prompt = (this.$('.NB-describe-input').val() || '').trim();
        if (!prompt) {
            this.$('.NB-describe-input').focus();
            return;
        }
        this.start_search(prompt);
    },

    search_again: function () {
        if (!this.search) return;
        this.start_search(this.search.prompt, this.search.id);
    },

    use_example: function (e) {
        var prompt = $(e.currentTarget).data('prompt');
        this.$('.NB-describe-input').val(prompt);
        this.autosize_input();
        this.start_search(prompt);
    },

    handle_input_keydown: function (e) {
        if (e.which === 13 && !e.shiftKey) {
            e.preventDefault();
            this.submit_prompt();
        }
    },

    handle_input_change: function () {
        this.autosize_input();
    },

    // describe_feeds_view.js: the textarea is border-box (reader.css), so scrollHeight maps straight to height.
    autosize_input: function () {
        var $input = this.$('.NB-describe-input');
        if (!$input.length) return;
        $input.css('height', '44px');
        var needed = $input[0].scrollHeight;
        if (needed > 44) {
            $input.css('height', Math.min(160, needed) + 'px');
        }
    },

    start_search: function (prompt, search_id) {
        var self = this;
        var $submit = this.$('.NB-describe-submit');
        if ($submit.hasClass('NB-disabled')) return;
        $submit.addClass('NB-disabled').text(gettext('Starting…'));
        this.stop_polling();

        var params = { prompt: prompt };
        if (search_id) params.search_id = search_id;

        NEWSBLUR.assets.make_request('/discover/describe/start', params, function (data) {
            $submit.removeClass('NB-disabled').text(gettext('Find feeds'));
            if (data.code > 0 && data.search) {
                self.usage = data.usage || self.usage;
                self.render_usage();
                self.show_search(data.search);
                self.update_history_entry(data.search);
                self.begin_streaming();
            } else if (data.upgrade) {
                self.usage = data.usage || self.usage;
                self.render_usage();
                self.render_upgrade_state(data.message);
            } else {
                self.show_error(data.message || gettext('The search could not be started.'));
            }
        }, function () {
            $submit.removeClass('NB-disabled').text(gettext('Find feeds'));
            self.show_error(gettext('The search could not be started.'));
        });
    },

    open_search: function (search_id, options) {
        var self = this;
        options = options || {};
        this.stop_polling();
        this.loading_search_id = search_id;
        this.pending_scroll_top = options.scroll_top || null;
        this.$('.NB-describe-body').html($.make('div', { className: 'NB-describe-loading' }, gettext('Loading your search…')));
        NEWSBLUR.assets.make_request('/discover/describe/status', { search_id: search_id }, function (data) {
            if (data.code > 0 && data.search) {
                self.show_search(data.search);
                self.update_history_entry(data.search);
                if (!self.is_finished(data.search)) {
                    self.begin_streaming();
                }
            } else {
                self.show_error(data.message || gettext('That search is no longer in your history.'));
            }
        }, function () {
            self.show_error(gettext('That search could not be loaded.'));
        }, { request_type: 'GET' });
    },

    // describe_feeds_view.js: render a search payload from scratch (start and replay).
    show_search: function (search) {
        this.search = search;
        this.loading_search_id = search.id;
        this.$('.NB-describe-input').val(search.prompt);
        this.autosize_input();
        this.render_results(search.results || []);
        this.render_status();
        this.render_history();
        this.restore_scroll();
    },

    render_results: function (results) {
        this.rows = {};
        this.cards = {};
        var $results = this.add_site_view.make_results_container().addClass('NB-describe-results');
        this.rendered_layout = this.current_layout();
        this.$('.NB-describe-body').html($results);
        _.each(results, _.bind(function (row) {
            this.rows[row.feed_id] = row;
            $results.append(this.make_card(row));
        }, this));
        this.order_cards(_.pluck(results, 'feed_id'));
    },

    is_finished: function (search) {
        return search && (search.status === 'complete' || search.status === 'error');
    },

    // ================
    // = Live updates =
    // ================

    begin_streaming: function () {
        this.last_event_at = new Date().getTime();
        this.schedule_poll();
    },

    schedule_poll: function () {
        this.stop_polling();
        this.poll_timer = setTimeout(_.bind(this.poll_status, this), this.POLL_INTERVAL);
    },

    stop_polling: function () {
        if (this.poll_timer) {
            clearTimeout(this.poll_timer);
            this.poll_timer = null;
        }
    },

    // describe_feeds_view.js: the socket carries events as they happen; the poll only catches up when
    // the socket is disconnected or has been quiet for longer than SOCKET_GRACE.
    poll_status: function () {
        var self = this;
        this.poll_timer = null;
        if (!this.search || this.is_finished(this.search)) return;

        var socket = NEWSBLUR.reader.socket;
        var socket_live = socket && socket.connected && (new Date().getTime() - this.last_event_at) < this.SOCKET_GRACE;
        if (socket_live) {
            this.schedule_poll();
            return;
        }

        NEWSBLUR.assets.make_request('/discover/describe/status', { search_id: this.search.id }, function (data) {
            if (data.code > 0 && data.search && self.search && data.search.id === self.search.id) {
                self.apply_search_payload(data.search);
            }
            if (self.search && !self.is_finished(self.search)) {
                self.schedule_poll();
            }
        }, function () {
            if (self.search && !self.is_finished(self.search)) {
                self.schedule_poll();
            }
        }, { request_type: 'GET' });
    },

    // describe_feeds_view.js: poll catch-up touches only what changed, so cards don't flash and a prompt
    // being typed for the next search is left alone.
    apply_search_payload: function (search) {
        var status_changed = search.status !== this.search.status ||
            search.phase !== this.search.phase ||
            search.phase_message !== this.search.phase_message ||
            (search.sub_queries || []).join('|') !== (this.search.sub_queries || []).join('|');
        var results_changed = this.results_signature(search.results) !== this.results_signature(_.values(this.rows));
        if (!status_changed && !results_changed) return;

        _.extend(this.search, _.pick(search, 'status', 'phase', 'phase_message', 'sub_queries', 'error', 'stats', 'result_count', 'completed_date'));
        if (results_changed) {
            this.pending_scroll_top = this.scroll_top();
            this.render_results(search.results || []);
            this.restore_scroll();
        }
        this.render_status();
        this.update_history_entry(this.search);
    },

    results_signature: function (results) {
        return _.map(results || [], function (row) {
            return [row.feed_id, row.judged ? row.score : '-'].join(':');
        }).join(',');
    },

    handle_event: function (data) {
        if (!data || !this.search || data.search_id !== this.search.id) return;
        // describe_feeds_view.js: a "Search again" gets a new request id, so events from the run it
        // replaced are ignored.
        if (data.request_id && this.search.request_id && data.request_id !== this.search.request_id) return;
        this.last_event_at = new Date().getTime();

        switch (data.type) {
            case 'start':
                this.search.status = 'running';
                this.render_status();
                break;
            case 'phase':
                this.search.status = 'running';
                this.search.phase = data.phase;
                this.search.phase_message = data.message;
                this.render_status();
                break;
            case 'queries':
                this.search.sub_queries = data.sub_queries || [];
                this.render_status();
                break;
            case 'candidates':
                this.add_rows(data.results || []);
                if (data.order) this.order_cards(data.order);
                this.render_status();
                break;
            case 'verdicts':
                this.apply_verdicts(data.verdicts || []);
                if (data.order) this.order_cards(data.order);
                break;
            case 'remove':
                this.remove_rows(data.feed_ids || []);
                if (data.order) this.order_cards(data.order);
                this.render_status();
                break;
            case 'complete':
                this.search.status = 'complete';
                this.search.phase = 'complete';
                this.search.phase_message = '';
                this.search.result_count = data.result_count;
                this.search.stats = data.stats || this.search.stats;
                if (data.order) this.order_cards(data.order);
                this.stop_polling();
                this.render_status();
                this.update_history_entry(this.search);
                break;
            case 'error':
                this.search.status = 'error';
                this.search.error = data.error;
                this.stop_polling();
                this.render_status();
                this.update_history_entry(this.search);
                break;
            case 'usage':
                if (data.usage) {
                    this.usage = data.usage;
                    this.render_usage();
                }
                if (data.message) {
                    this.search.usage_message = data.message;
                    this.render_status();
                }
                break;
        }
    },

    add_rows: function (rows) {
        var $results = this.$('.NB-describe-results');
        if (!$results.length) {
            $results = this.add_site_view.make_results_container().addClass('NB-describe-results');
            this.rendered_layout = this.current_layout();
            this.$('.NB-describe-body').html($results);
        }
        _.each(rows, _.bind(function (row) {
            if (this.rows[row.feed_id]) return;
            this.rows[row.feed_id] = row;
            var $card = this.make_card(row).addClass('NB-describe-card-new');
            $results.append($card);
            _.delay(function () { $card.removeClass('NB-describe-card-new'); }, 600);
        }, this));
    },

    apply_verdicts: function (verdicts) {
        _.each(verdicts, _.bind(function (verdict) {
            var row = this.rows[verdict.feed_id];
            if (!row) return;
            row.score = verdict.score;
            row.reason = verdict.reason;
            row.judged = true;
            var $card = this.cards[verdict.feed_id];
            if ($card) {
                $card.find('.NB-describe-card-tags').replaceWith(this.make_card_tags(row));
                $card.find('.NB-describe-reason').replaceWith(this.make_reason(row));
                $card.addClass('NB-describe-card-judged');
            }
        }, this));
    },

    remove_rows: function (feed_ids) {
        _.each(feed_ids, _.bind(function (feed_id) {
            var $card = this.cards[feed_id];
            delete this.rows[feed_id];
            delete this.cards[feed_id];
            if ($card) {
                $card.addClass('NB-describe-card-removed');
                _.delay(function () { $card.remove(); }, 400);
            }
        }, this));
    },

    // describe_feeds_view.js: reorder cards in place by feed id; unknown ids keep their position at the end.
    order_cards: function (order) {
        var $results = this.$('.NB-describe-results');
        if (!$results.length || !order) return;
        _.each(order, _.bind(function (feed_id) {
            var $card = this.cards[feed_id];
            if ($card) $results.append($card);
        }, this));
    },

    // =========
    // = Cards =
    // =========

    make_card: function (row) {
        var feed = row.feed || {};
        var $card = this.add_site_view.render_feed_card(feed, row.stories || []);
        $card.addClass('NB-describe-card' + (row.judged ? ' NB-describe-card-judged' : ''));
        $card.attr('data-feed-id', row.feed_id);
        $card.find('.NB-add-site-card-header').after([this.make_card_tags(row), this.make_reason(row)]);
        this.cards[row.feed_id] = $card;
        return $card;
    },

    make_card_tags: function (row) {
        var tags = [];
        if (row.judged && row.score !== null && row.score !== undefined) {
            var level = row.score >= 8 ? 'high' : (row.score >= 5 ? 'medium' : 'low');
            tags.push($.make('span', { className: 'NB-describe-score NB-describe-score-' + level, title: gettext('How well this feed matches your description') },
                interpolate(gettext('%(score)s/10'), {score: row.score}, true)));
        } else {
            tags.push($.make('span', { className: 'NB-describe-score NB-describe-score-pending' }, gettext('Judging…')));
        }
        if (row.source === 'web') {
            tags.push($.make('span', { className: 'NB-describe-source NB-describe-source-web', title: gettext('Found on the web during this search') }, [
                $.make('img', { src: '/media/img/icons/lucide/globe.svg', className: 'NB-describe-source-icon' }),
                gettext('Found on the web')
            ]));
        } else {
            tags.push($.make('span', { className: 'NB-describe-source NB-describe-source-index', title: gettext('Already in NewsBlur’s feed index') }, [
                $.make('img', { src: '/media/img/icons/lucide/rss.svg', className: 'NB-describe-source-icon' }),
                gettext('NewsBlur index')
            ]));
        }
        return $.make('div', { className: 'NB-describe-card-tags' }, tags);
    },

    make_reason: function (row) {
        if (row.judged && row.reason) {
            return $.make('div', { className: 'NB-describe-reason', dir: 'auto' }, row.reason);
        }
        return $.make('div', { className: 'NB-describe-reason NB-describe-reason-pending' },
            row.matched_query ? interpolate(gettext('Matched “%(query)s”'), {query: row.matched_query}, true) : gettext('Waiting for a verdict…'));
    },

    // ==========
    // = Status =
    // ==========

    render_status: function () {
        var search = this.search;
        var $status = this.$('.NB-describe-status');
        if (!search) {
            $status.addClass('NB-hidden').empty();
            return;
        }
        var count = _.size(this.rows);
        var is_running = !this.is_finished(search);
        var phase_index = _.indexOf(_.pluck(this.PHASES, 'id'), search.phase);
        if (search.status === 'complete') phase_index = this.PHASES.length - 1;

        var $steps = $.make('div', { className: 'NB-describe-steps' }, _.map(this.PHASES, function (phase, index) {
            var state = '';
            if (phase_index > index || search.status === 'complete') state = ' NB-done';
            else if (phase_index === index && is_running) state = ' NB-current';
            return $.make('div', { className: 'NB-describe-step' + state }, [
                $.make('span', { className: 'NB-describe-step-dot' }),
                $.make('span', { className: 'NB-describe-step-label' }, phase.label())
            ]);
        }));

        var message;
        if (search.status === 'error') {
            message = search.error || gettext('Something went wrong while searching.');
        } else if (search.status === 'complete') {
            message = count ?
                interpolate(ngettext('Found %(count)s feed that matches your description', 'Found %(count)s feeds that match your description', count), {count: count}, true) :
                gettext('No feeds matched that description. Try describing it another way.');
        } else if (search.phase_message) {
            message = search.phase_message;
        } else {
            message = gettext('Starting your search…');
        }

        var $counter = null;
        if (is_running && count) {
            $counter = $.make('span', { className: 'NB-describe-status-count' },
                interpolate(ngettext('%(count)s feed so far', '%(count)s feeds so far', count), {count: count}, true));
        }

        var $extra = [];
        if (search.sub_queries && search.sub_queries.length) {
            // describe_feeds_view.js: $.make takes a flat list of children, so the chips are concatenated in.
            $extra.push($.make('div', { className: 'NB-describe-queries' }, [
                $.make('span', { className: 'NB-describe-queries-label' }, gettext('Searching for'))
            ].concat(_.map(search.sub_queries, function (query) {
                return $.make('span', { className: 'NB-describe-query', dir: 'auto' }, query);
            }))));
        }
        if (search.usage_message) {
            $extra.push($.make('div', { className: 'NB-describe-usage-message' }, search.usage_message));
        }
        if (search.stats && search.stats.note) {
            $extra.push($.make('div', { className: 'NB-describe-usage-message' }, search.stats.note));
        }

        $status.removeClass('NB-hidden').toggleClass('NB-running', is_running).toggleClass('NB-error', search.status === 'error').html([
            $.make('div', { className: 'NB-describe-status-row' }, [
                $.make('div', { className: 'NB-describe-status-message' }, [
                    is_running ? $.make('span', { className: 'NB-describe-spinner' }) : null,
                    $.make('span', { className: 'NB-describe-status-text' }, message),
                    $counter
                ].filter(Boolean)),
                is_running ? null : $.make('div', { className: 'NB-describe-search-again NB-modal-submit-button NB-modal-submit-grey', role: 'button' }, gettext('Search again'))
            ].filter(Boolean)),
            $steps
        ].concat($extra));
    },

    show_error: function (message) {
        this.$('.NB-describe-body').html(this.add_site_view.make_error_with_icon(message));
    },

    // ==============
    // = Navigation =
    // ==============

    // describe_feeds_view.js: what the tryfeed "Go back" breadcrumb needs to land back on this search.
    get_origin: function () {
        if (!this.search) return {};
        var prompt = this.search.prompt || '';
        if (prompt.length > 60) prompt = prompt.substring(0, 57) + '…';
        return {
            query: prompt,
            search_id: this.search.id,
            scroll_top: this.scroll_top()
        };
    },

    scrollable: function () {
        return this.$el.closest('.NB-add-site-tab-pane');
    },

    scroll_top: function () {
        var $pane = this.scrollable();
        return $pane.length ? $pane.scrollTop() : 0;
    },

    restore_scroll: function () {
        if (!this.pending_scroll_top) return;
        var scroll_top = this.pending_scroll_top;
        this.pending_scroll_top = null;
        var $pane = this.scrollable();
        _.defer(function () {
            if ($pane.length) $pane.scrollTop(scroll_top);
        });
    },

    open_upgrade: function () {
        NEWSBLUR.reader.open_premium_upgrade_modal();
    },

    // ===========
    // = Helpers =
    // ===========

    // describe_feeds_view.js: the server's timestamps are naive UTC (settings.TIME_ZONE is GMT), so an
    // offset-less ISO string is read as UTC rather than browser-local time.
    relative_date: function (iso_date) {
        if (!iso_date) return '';
        if (!/[zZ]|[+-]\d\d:?\d\d$/.test(iso_date)) iso_date += 'Z';
        var date = new Date(iso_date);
        if (isNaN(date.getTime())) return '';
        var days_ago = Math.floor((new Date() - date) / (1000 * 60 * 60 * 24));
        if (days_ago < 1) return gettext('Today');
        if (days_ago < 7) return interpolate(ngettext('%(count)sd ago', '%(count)sd ago', days_ago), {count: days_ago}, true);
        if (days_ago < 30) {
            var weeks_ago = Math.floor(days_ago / 7);
            return interpolate(ngettext('%(count)sw ago', '%(count)sw ago', weeks_ago), {count: weeks_ago}, true);
        }
        return date.toLocaleDateString(document.documentElement.lang || undefined, { month: 'short', day: 'numeric' });
    }

});
