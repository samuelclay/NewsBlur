// recommendation_feedback_view.js: Current choices, shared by the river header and history dialog.
NEWSBLUR.recommendation_feedback_chart = function (days, width, height, neutral) {
    var namespace = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(namespace, 'svg');
    svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
    svg.setAttribute('aria-hidden', 'true');
    function shape(tag, attributes) {
        var element = document.createElementNS(namespace, tag);
        _.each(attributes, function (value, key) { element.setAttribute(key, value); });
        svg.appendChild(element);
        return element;
    }
    if (neutral) {
        svg.setAttribute('class', 'NB-feedback-constellation');
        var stars = [[.08, .65], [.28, .3], [.49, .55], [.7, .2], [.92, .45]];
        shape('polyline', { points: _.map(stars, function (point) {
            return point[0] * width + ',' + point[1] * height;
        }).join(' '), class: 'NB-feedback-constellation-line' });
        _.each(stars, function (point, index) {
            shape('circle', { cx: point[0] * width, cy: point[1] * height,
                r: index === 2 ? 2 : 1.2, class: 'NB-feedback-constellation-star' });
        });
        return svg;
    }
    var middle = height / 2;
    shape('line', { x1: 3, x2: width - 3, y1: middle, y2: middle, class: 'NB-feedback-chart-axis' });
    var maximum = Math.max(1, _.max(_.map(days, function (day) { return Math.max(day.more, day.less); })));
    _.each(['more', 'less'], function (choice) {
        var points = _.map(days, function (day, i) {
            return [3 + i * (width - 6) / Math.max(1, days.length - 1),
                middle + (choice === 'more' ? -1 : 1) * day[choice] / maximum * (middle - 3)];
        });
        var coordinates = _.map(points, function (point) { return point.join(','); }).join(' ');
        shape('polygon', { points: '3,' + middle + ' ' + coordinates + ' ' + (width - 3) + ',' + middle,
            class: 'NB-feedback-chart-area NB-feedback-chart-area-' + choice });
        shape('polyline', { points: coordinates, class: 'NB-feedback-chart-' + choice });
        _.each(points, function (point, i) {
            if (days[i][choice]) shape('circle', { cx: point[0], cy: point[1], r: 1.5,
                class: 'NB-feedback-chart-dot NB-feedback-chart-dot-' + choice });
        });
    });
    _.each(days, function (day, i) {
        var hit = document.createElementNS(namespace, 'rect');
        hit.setAttribute('x', i * width / days.length);
        hit.setAttribute('y', 0);
        hit.setAttribute('width', width / days.length);
        hit.setAttribute('height', height);
        hit.setAttribute('fill', 'transparent');
        var title = document.createElementNS(namespace, 'title');
        title.textContent = day.date + ': ' + day.more + ' More, ' + day.less + ' Less';
        hit.appendChild(title);
        svg.appendChild(hit);
    });
    return svg;
};

NEWSBLUR.discovery_preview_active = function (collection) {
    return collection === NEWSBLUR.assets.stories && NEWSBLUR.reader.active_feed === 'trending:discovery' &&
        NEWSBLUR.assets.discovery_preview && NEWSBLUR.assets.discovery_preview.limited;
};

NEWSBLUR.discovery_preview_callout = function () {
    var preview = NEWSBLUR.assets.discovery_preview;
    var $callout = $('<div class="NB-end-line NB-discovery-preview-end"><div class="NB-feed-story-premium-only"></div></div>');
    var $content = $callout.children().append(NEWSBLUR.recommendation_feedback_chart([], 96, 32, true));
    $content.append($('<h3>').text('There’s more to discover'));
    $content.append($('<p>').text('Three stories, picked for you each week. Get the full Discovery stream with Premium Archive.'));
    $content.append($('<a href="#" class="NB-discovery-upgrade" data-feature="discovery">').text('Unlock Discovery'));
    $content.append($('<div class="NB-discovery-next-week">').text('New picks ' +
        new Date(preview.resets_at).toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })));
    return $callout;
};

NEWSBLUR.discovery_loading = function () {
    return $('<div class="NB-end-line NB-discovery-loading" role="status">')
        .append(NEWSBLUR.recommendation_feedback_chart([], 160, 56, true))
        .append($('<span>').text('Finding stories for you…'))
        .append('<div class="NB-discovery-loading-lines"><i></i><i></i><i></i></div>');
};

// recommendation_feedback_view.js: Each page continues the cascade on the beat after the page before it.
NEWSBLUR.reveal_discovery_stories = function (first_new_story) {
    var now = Date.now();
    var assets = NEWSBLUR.assets;
    var queued_delay = first_new_story ? Math.max(0, (assets.discovery_reveal_next_at || 0) - now) : 0;
    _.each(assets.stories.models.slice(first_new_story), function (story, index) {
        var delay = queued_delay + index * 70;
        assets.discovery_reveal_next_at = now + delay + 70;
        _.each([story.story_title_view, story.story_view], function (view) {
            if (!view) return;
            view.$el.css('--discovery-reveal-delay', delay + 'ms')
                .addClass('NB-discovery-reveal').on('animationend.discovery_reveal', function (e) {
                    // recommendation_feedback_view.js: A child's animation must not end a queued reveal early.
                    if (e.target !== this) return;
                    $(this).off('animationend.discovery_reveal').removeClass('NB-discovery-reveal');
                });
        });
    });
};

NEWSBLUR.Views.RecommendationFeedbackSummary = Backbone.View.extend({
    tagName: 'button',
    className: 'NB-feedback-summary',
    attributes: { type: 'button', title: 'Review your recommendation preferences' },
    events: {
        'click': 'open_history',
        'mousedown': 'stop_event',
        'dblclick': 'stop_event',
        'keydown': 'stop_event',
        'keypress': 'stop_event'
    },

    initialize: function () {
        this.request_number = 0;
        this.listenTo(NEWSBLUR.assets, 'recommendation:updated', this.load);
        this.$el.toggleClass('NB-feedback-summary-sidebar', !!this.options.sidebar);
        this.render_summary({ more: 0, less: 0, days: [] });
        this.load();
    },

    render_summary: function (summary) {
        // recommendation_feedback_view.js: Let the first few choices fill the tiny chart; history keeps all 30 days.
        var first_activity = _.find(summary.days, function (day) { return day.more || day.less; });
        var days = first_activity ? summary.days.slice(Math.max(0, _.indexOf(summary.days, first_activity) - 1)) : summary.days;
        this.$el.empty().append(NEWSBLUR.recommendation_feedback_chart(days, 72, 24,
            !summary.more && !summary.less));
        if (summary.more || summary.less) {
            this.$el.append($('<span class="NB-feedback-count unread_count unread_count_negative">').text(summary.less));
            this.$el.append($('<span class="NB-feedback-count unread_count unread_count_positive">').text(summary.more));
        }
        var label = 'Recommendation preferences: ' + summary.more + ' More, ' + summary.less + ' Less. Open history.';
        this.$el.attr({ 'aria-label': label, title: label });
    },

    stop_event: function (e) { e.stopPropagation(); },

    load: function () {
        var self = this, request_number = ++this.request_number;
        NEWSBLUR.assets.load_recommendation_feedback({ summary: 1 }, function (data) {
            if (self.removed || request_number !== self.request_number) return;
            self.render_summary(data.summary);
            if (self.options.sidebar) NEWSBLUR.assets.ensure_discovery_taste(data.summary.more + ':' + data.summary.less);
        }, function () {
            if (!self.removed && request_number === self.request_number) {
                self.$el.attr({ title: 'Preferences unavailable. Click to retry in history.',
                    'aria-label': 'Preferences unavailable. Click to retry in history.' });
            }
        });
    },

    open_history: function (e) {
        e.preventDefault();
        e.stopImmediatePropagation();
        new NEWSBLUR.Views.RecommendationFeedbackHistory({ anchor: this.el }).open();
    },

    remove: function () {
        this.removed = true;
        return Backbone.View.prototype.remove.call(this);
    }
});

NEWSBLUR.Views.DiscoveryTaste = Backbone.View.extend({
    events: {
        'click .NB-taste-refresh': 'learn',
        'click .NB-taste-preview': 'preview',
        'click .NB-taste-save': 'save',
        'click .NB-taste-remove': 'remove_interest',
        'click .NB-taste-restore': 'restore_interest',
        'click .NB-taste-add': 'add',
        'click .NB-taste-evidence-vote': 'vote',
        'click .NB-taste-cancel': 'cancel_edit',
        'input .NB-taste-form': 'mark_dirty',
        'change .NB-taste-form': 'mark_dirty'
    },

    initialize: function () {
        this.active = true;
        this.listenTo(NEWSBLUR.assets, 'recommendation:taste', this.receive);
        this.listenTo(NEWSBLUR.assets, 'recommendation:taste-learning', function () { this.status('Learning from your latest ratings…'); });
        this.listenTo(NEWSBLUR.assets, 'recommendation:taste-error', function (message) { this.status(message); });
    },

    load: function () {
        var self = this;
        if (!this.profile) this.$el.text('Loading your interests…');
        NEWSBLUR.assets.discovery_taste_request('taste_profile', {}, function (data) {
            if (!self.active) return;
            if (data.profile.stale && data.profile.can_learn && !data.profile.learning) self.learn();
        });
    },

    receive: function (profile) {
        if (!this.active) return;
        // recommendation_feedback_view.js: Keep an unfinished form intact when background learning completes.
        if (this.dirty && !this.busy) {
            this.pending_profile = profile;
            this.status('Your interests have updated. Your draft is kept; save to apply your edit.');
            return;
        }
        this.profile = profile;
        this.render();
    },

    status: function (text) {
        this.$('.NB-taste-status').text(text);
    },

    render: function () {
        var self = this, profile = this.profile;
        this.$el.empty();
        this.$el.append($('<p class="NB-taste-summary">').text(profile.summary ||
            'Rate a few stories and Discovery will start connecting the dots. You can also add an interest yourself.'));
        this.$el.append($('<p class="NB-taste-context">').text(profile.rating_count + ' rated stories · ' +
            'Inferred interests apply automatically. Editing one makes it yours to control.'));
        var $actions = $('<div class="NB-taste-actions">').append(
            $('<button type="button" class="NB-taste-refresh">').text('Update from ratings').prop('disabled', !profile.can_learn),
            $('<button type="button" class="NB-taste-preview">').text('See what changes')
                .prop('disabled', !profile.can_compare).attr('title', profile.can_compare ? 'Compare your next recommendations' : 'Included with Premium Archive'));
        this.$el.append($actions, $('<div class="NB-taste-status" role="status" aria-live="polite">'));
        if (profile.learning) this.status('Learning from your latest ratings…');
        else if (profile.stale && profile.can_learn) this.status('New ratings are ready to learn from.');
        else if (NEWSBLUR.assets.discovery_taste_error) this.status(NEWSBLUR.assets.discovery_taste_error);
        _.each(profile.rules, function (rule) { if (!rule.removed) self.$el.append(self.rule_row(rule)); });
        this.$el.append($('<button type="button" class="NB-taste-add">').text('Add an interest'));
        var removed = _.filter(profile.rules, function (rule) { return rule.removed; });
        if (removed.length) {
            var $removed = $('<details class="NB-taste-removed">').append($('<summary>').text('Removed interests (' + removed.length + ')'));
            _.each(removed, function (rule) {
                $removed.append($('<div class="NB-taste-removed-row">').attr('data-interest-id', rule.id)
                    .append($('<span>').text(rule.label), $('<button type="button" class="NB-taste-restore">').text('Restore')));
            });
            this.$el.append($removed);
        }
        var impact = profile.impact;
        if (impact && impact.candidate_count !== undefined) {
            var $impact = $('<section class="NB-taste-impact">').append($('<h3>').text('What your feedback changes'));
            $impact.append($('<p>').text(impact.changed_top12 + ' of ' + impact.pick_count + ' top picks changed compared with reading history alone.'));
            $impact.append($('<p class="NB-taste-context">').text('Snapshot of ' + impact.candidate_count + ' candidates · ' +
                (impact.status === 'interests' ? 'Interest matching applied to ' + impact.assessed_count + ' shortlisted stories.' :
                    (impact.status === 'fallback' ? 'Interest matching is unavailable; story ratings and reading history are still active.' : 'Using story ratings and reading history.')) +
                ' Checked ' + new Date(impact.updated_date).toLocaleString() + '.'));
            _.each(impact.stories, function (story) {
                $impact.append($('<div class="NB-taste-impact-story">').append(
                    $('<span>').text(story.title), $('<strong>').text('#' + story.before + ' → #' + story.after)));
                if (story.interests.length) $impact.append($('<p class="NB-taste-context">').text('Matches: ' + story.interests.join(', ')));
            });
            this.$el.append($impact);
        }
        this.$el.append($('<p class="NB-taste-context">').text('Changes affect your next Discovery refresh. They do not hide stories in your subscribed feeds or replace this week’s preview.'));
        $.modal.resize();
    },

    select: function (name, value, choices) {
        var $select = $('<select>').attr('name', name);
        _.each(choices, function (choice) { $select.append($('<option>').attr('value', choice[0]).text(choice[1])); });
        return $select.val(String(value));
    },

    rule_row: function (rule) {
        var $row = $('<details class="NB-taste-rule">').attr('data-interest-id', rule.id);
        var $summary = $('<summary>').append($('<span class="NB-taste-direction">').attr('data-direction', rule.direction)
            .text(rule.direction === 1 ? 'More' : (rule.direction === -1 ? 'Less' : 'Paused')),
            $('<span class="NB-taste-label">').text(rule.label || 'New interest'),
            $('<span class="NB-taste-origin">').text((rule.manual ? 'Set by you' :
                (rule.tentative ? 'Inferred · tentative' : 'Inferred')) + (rule.active === false ? ' · not applied' : '')));
        $row.append($summary, $('<p class="NB-taste-rule-description">').text(rule.criterion));
        var $form = $('<div class="NB-taste-form">').append(
            $('<label>').text('Interest').append($('<input name="label" maxlength="100">').val(rule.label)),
            $('<label>').text('What should match').append($('<textarea name="criterion" maxlength="500" rows="2">').val(rule.criterion)),
            $('<div class="NB-taste-fields">').append(
                $('<label>').text('Type').append(this.select('kind', rule.kind, [['topic','Topic'],['angle','Angle'],['format','Format']])),
                $('<label>').text('Preference').append(this.select('direction', rule.direction, [[1,'More like this'],[-1,'Less like this'],[0,'Pause']])),
                $('<label>').text('Strength').append(this.select('strength', rule.strength, [[1,'Normal'],[2,'Stronger'],[3,'Strongest']]))),
            $('<div class="NB-taste-actions">').append($('<button type="button" class="NB-taste-save">').text('Save interest'),
                $('<button type="button" class="NB-taste-cancel">').text('Cancel edit'),
                $('<button type="button" class="NB-taste-remove">').text('Remove')));
        $row.append($form);
        if (rule.stories && rule.stories.length) {
            $row.append($('<h4>').text('Based on ' + rule.more + ' More and ' + rule.less + ' Less ratings'));
            _.each(rule.stories, function (story) {
                var $evidence = $('<div class="NB-taste-evidence">').attr('data-story-hash', story.story_hash)
                    .append($('<span>').text(story.title));
                var $votes = $('<div class="NB-taste-actions">');
                _.each([[1,'More'],[-1,'Less'],[0,'Clear']], function (choice) {
                    $votes.append($('<button type="button" class="NB-taste-evidence-vote">').attr('data-value', choice[0])
                        .attr('aria-pressed', story.value === choice[0] ? 'true' : 'false').prop('disabled', story.value === choice[0]).text(choice[1]));
                });
                $row.append($evidence.append($votes));
            });
        } else {
            $row.append($('<p class="NB-taste-context">').text(rule.manual ? 'An interest you set directly.' : 'No current ratings support this interest.'));
        }
        return $row;
    },

    learn: function () {
        if (this.busy) return;
        if (this.dirty) { this.status('Save or cancel your edit before updating interests.'); return; }
        this.request('learn_taste', {}, 'Learning from your ratings…');
    },

    preview: function () {
        if (this.busy) return;
        if (this.dirty) { this.status('Save or cancel your edit before comparing recommendations.'); return; }
        this.request('preview_taste', {}, 'Comparing recommendations with and without your feedback…');
    },

    request: function (action, params, message) {
        var self = this;
        this.busy = true;
        this.$('button').prop('disabled', true);
        this.status(message);
        NEWSBLUR.assets.discovery_taste_request(action, params, function (data) {
            if (!self.active) return;
            self.busy = false;
            self.dirty = false;
            self.pending_profile = null;
            self.profile = data.profile;
            self.render();
            self.status(data.profile.learning ? 'Learning from your ratings…' :
                (action === 'edit_taste' ? 'Saved. This will shape your next Discovery refresh.' : 'Up to date.'));
        }, function (data) {
            if (!self.active) return;
            self.busy = false;
            if (data && data.profile) self.pending_profile = data.profile;
            self.$('button').prop('disabled', false);
            self.$('.NB-taste-preview').prop('disabled', !self.profile.can_compare);
        });
    },

    save: function (e) {
        if (this.busy) return;
        var $row = $(e.currentTarget).closest('.NB-taste-rule');
        var latest = this.pending_profile || this.profile;
        var id = $row.attr('data-interest-id');
        var exists = _.find(latest.rules, function (rule) { return rule.id === id; });
        var params = { revision: latest.revision, id: id, action: $row.attr('data-new') || !exists ? 'add' : 'save' };
        _.each(['label','criterion','kind','direction','strength'], function (name) { params[name] = $row.find('[name="' + name + '"]').val(); });
        $(e.currentTarget).blur();
        this.request('edit_taste', params, 'Saving your interest…');
    },

    remove_interest: function (e) {
        if (this.busy) return;
        var $row = $(e.currentTarget).closest('.NB-taste-rule');
        if ($row.attr('data-new')) { this.cancel_edit(); return; }
        this.request('edit_taste', { revision: this.profile.revision, id: $row.attr('data-interest-id'), action: 'remove' }, 'Removing interest…');
    },

    restore_interest: function (e) {
        if (this.busy) return;
        this.request('edit_taste', { revision: this.profile.revision, id: $(e.currentTarget).closest('[data-interest-id]').attr('data-interest-id'), action: 'restore' }, 'Restoring interest…');
    },

    add: function () {
        if (this.$('[data-new]').length) return;
        var $row = this.rule_row({ id:'', label:'', criterion:'', kind:'topic', direction:1, strength:1, manual:true });
        $row.attr('data-new', 'true').prop('open', true);
        this.$('.NB-taste-add').before($row);
        this.dirty = true;
        $row.find('input').focus();
        $.modal.resize();
    },

    mark_dirty: function () { this.dirty = true; },

    cancel_edit: function () {
        this.dirty = false;
        this.receive(this.pending_profile || this.profile);
        this.pending_profile = null;
    },

    vote: function (e) {
        if (this.busy) return;
        var self = this, $button = $(e.currentTarget);
        this.busy = true;
        this.status('Updating story rating…');
        NEWSBLUR.assets.save_recommendation_feedback($button.closest('[data-story-hash]').attr('data-story-hash'), Number($button.attr('data-value')), function () {
            self.busy = false;
            if (self.active) self.load();
        }, function () {
            self.busy = false;
            if (self.active) self.status('Couldn’t save the rating. Please try again.');
        });
    },

    remove: function () {
        this.active = false;
        return Backbone.View.prototype.remove.call(this);
    }
});

NEWSBLUR.Views.RecommendationFeedbackHistory = Backbone.View.extend({
    className: 'NB-modal NB-feedback-history',
    attributes: { role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'NB-feedback-history-title' },
    events: {
        'click .NB-feedback-tab': 'switch_choice',
        'click .NB-feedback-history-vote': 'save_choice',
        'click .NB-feedback-load-more': 'load_more',
        'click .NB-feedback-history-retry': 'retry',
        'click .NB-feedback-history-close': 'close',
        'keydown': 'stop_event',
        'keypress': 'stop_event'
    },

    initialize: function () {
        this.choice = 0;
        this.request_number = 0;
        this.active = true;
        this.$el.html('<h2 class="NB-modal-title" id="NB-feedback-history-title">Your Discovery preferences</h2>' +
            '<p class="NB-feedback-history-intro">What Discovery is learning, and the stories behind it. Your edits always take precedence.</p>' +
            '<div class="NB-feedback-tabs" role="group" aria-label="Preference lists">' +
            '<button type="button" class="NB-feedback-tab" data-value="0" aria-pressed="true">Your interests</button>' +
            '<button type="button" class="NB-feedback-tab" data-value="1" aria-pressed="false">More like this <b>0</b></button>' +
            '<button type="button" class="NB-feedback-tab" data-value="-1" aria-pressed="false">Less like this <b>0</b></button></div>' +
            '<div class="NB-feedback-history-chart"></div>' +
            '<div class="NB-feedback-chart-caption"><span>Current choices by last update · 30 days (UTC)</span><span class="NB-feedback-chart-dates"></span></div>' +
            '<div class="NB-feedback-history-status" role="status" aria-live="polite"></div>' +
            '<div class="NB-discovery-taste"></div>' +
            '<div class="NB-feedback-history-stories"></div>' +
            '<button type="button" class="NB-feedback-load-more" hidden>Show more stories</button>' +
            '<button type="button" class="NB-feedback-history-retry" hidden>Couldn’t load preferences · Retry</button>' +
            '<div class="NB-modal-submit"><button type="button" class="NB-modal-submit-button NB-modal-submit-green NB-feedback-history-close">Done</button></div>');
        this.taste_view = new NEWSBLUR.Views.DiscoveryTaste({ el: this.$('.NB-discovery-taste') });
    },

    open: function () {
        var self = this;
        this.$el.modal({
            minWidth: Math.min(680, $(window).width() - 40),
            maxWidth: 680,
            overlayClose: true,
            onClose: function () {
                self.active = false;
                self.taste_view.remove();
                self.remove();
                $.modal.close();
                if (self.options.anchor && document.contains(self.options.anchor)) self.options.anchor.focus();
            }
        });
        this.load(false);
        this.$('.NB-feedback-tab').first().focus();
        return this;
    },

    close: function () { $.modal.close(); },

    stop_event: function (e) {
        // recommendation_feedback_view.js: Preserve Escape and the modal's Tab trap, isolate reader shortcuts.
        if (e.key !== 'Escape' && e.key !== 'Tab' && e.which !== 27 && e.which !== 9) e.stopPropagation();
    },

    switch_choice: function (e) {
        if (this.saving) return;
        this.choice = Number($(e.currentTarget).attr('data-value'));
        this.$('.NB-feedback-tab').attr('aria-pressed', 'false');
        $(e.currentTarget).attr('aria-pressed', 'true');
        this.$('.NB-feedback-history-status').text('');
        this.$('.NB-discovery-taste').prop('hidden', this.choice !== 0);
        this.$('.NB-feedback-history-stories').prop('hidden', this.choice === 0);
        this.load(false);
    },

    load: function (append) {
        var self = this, request_number = ++this.request_number;
        if (this.choice === 0) {
            this.loading = false;
            this.$('.NB-feedback-history-stories, .NB-feedback-load-more, .NB-feedback-history-retry').prop('hidden', true);
            NEWSBLUR.assets.load_recommendation_feedback({ summary: 1 }, function (data) {
                if (!self.active || request_number !== self.request_number) return;
                self.$('.NB-feedback-tab[data-value="1"] b').text(data.summary.more);
                self.$('.NB-feedback-tab[data-value="-1"] b').text(data.summary.less);
                self.$('.NB-feedback-history-chart').empty().append(NEWSBLUR.recommendation_feedback_chart(data.summary.days, 600, 78));
                self.$('.NB-feedback-chart-dates').text(data.summary.days[0].date.slice(5) + ' – ' + data.summary.days[29].date.slice(5));
            }, function () {});
            this.taste_view.load();
            return;
        }
        this.loading = true;
        this.retry_append = append;
        this.$('.NB-feedback-history-stories').attr('aria-busy', 'true');
        this.$('.NB-feedback-load-more').prop('disabled', true);
        this.$('.NB-feedback-history-retry').prop('hidden', true);
        if (!append) this.$('.NB-feedback-history-stories').empty().append($('<p>').text('Loading preferences…'));
        NEWSBLUR.assets.load_recommendation_feedback({ value: this.choice, cursor: append ? this.next_cursor : '' }, function (data) {
            if (!self.active || request_number !== self.request_number) return;
            self.loading = false;
            self.next_cursor = data.next_cursor;
            self.$('.NB-feedback-tab[data-value="1"] b').text(data.summary.more);
            self.$('.NB-feedback-tab[data-value="-1"] b').text(data.summary.less);
            self.$('.NB-feedback-history-chart').empty().append(NEWSBLUR.recommendation_feedback_chart(data.summary.days, 600, 78));
            self.$('.NB-feedback-chart-dates').text(data.summary.days[0].date.slice(5) + ' – ' + data.summary.days[29].date.slice(5));
            var $stories = self.$('.NB-feedback-history-stories').attr('aria-busy', 'false');
            if (!append) $stories.empty().scrollTop(0);
            _.each(data.stories, function (story) { $stories.append(self.story_row(story, data.feeds)); });
            if (!append && !data.stories.length) $stories.append($('<p class="NB-feedback-history-empty">').text(
                'No ' + (self.choice === 1 ? 'More' : 'Less') + ' preferences yet. Your choices in Discovery will appear here.'));
            self.$('.NB-feedback-load-more').prop('hidden', !self.next_cursor).prop('disabled', false);
            if (self.focus_after_save) {
                self.$('.NB-feedback-tab[aria-pressed="true"]').focus();
                self.focus_after_save = false;
            }
            $.modal.resize();
        }, function () {
            if (!self.active || request_number !== self.request_number) return;
            self.loading = false;
            self.retry_append = false;
            self.$('.NB-feedback-history-stories').attr('aria-busy', 'false');
            if (!append) self.$('.NB-feedback-history-stories').empty();
            self.$('.NB-feedback-history-retry').prop('hidden', false);
            self.$('.NB-feedback-load-more').prop('hidden', true);
        });
    },

    story_row: function (story, feeds) {
        var $row = $('<div class="NB-feedback-history-story">').attr('data-story-hash', story.story_hash);
        var feed = new Backbone.Model(feeds[story.story_feed_id] || { id: story.story_feed_id });
        var $source = $('<div class="NB-feedback-history-source">').append($.favicon_el(feed));
        $source.append($('<span>').text((feeds[story.story_feed_id] || {}).feed_title || 'Source no longer available'));
        $source.append($('<time>').attr('datetime', story.updated_date).text(new Date(story.updated_date).toLocaleDateString()));
        var $title = $('<span class="NB-feedback-history-title">').text(story.story_title || 'Untitled story');
        if (/^https?:\/\//i.test(story.story_permalink)) {
            $title = $('<a class="NB-feedback-history-title" target="_blank" rel="noopener noreferrer">')
                .attr('href', story.story_permalink).text(story.story_title || 'Untitled story');
        }
        var $actions = $('<div class="NB-feedback-history-actions">');
        _.each([1, -1, 0], function (value) {
            var label = value === 1 ? 'More like this' : (value === -1 ? 'Less like this' : 'Clear');
            $actions.append($('<button type="button" class="NB-feedback-history-vote">').attr('data-value', value)
                .attr('aria-pressed', value !== 0 && story.value === value ? 'true' : 'false')
                .prop('disabled', story.value === value).text(label));
        });
        return $row.append($source, $title, $actions);
    },

    save_choice: function (e) {
        if (this.saving || this.loading) return;
        var self = this, $button = $(e.currentTarget), value = Number($button.attr('data-value'));
        var story_hash = $button.closest('.NB-feedback-history-story').attr('data-story-hash');
        this.saving = true;
        this.$('.NB-feedback-history-vote, .NB-feedback-tab, .NB-feedback-load-more').prop('disabled', true);
        this.$('.NB-feedback-history-status').text('Saving preference…');
        NEWSBLUR.assets.save_recommendation_feedback(story_hash, value, function () {
            if (!self.active) return;
            self.saving = false;
            self.$('.NB-feedback-tab').prop('disabled', false);
            self.$('.NB-feedback-history-status').text(value === 0 ? 'Preference cleared.' :
                (value === 1 ? 'Moved to More like this.' : 'Moved to Less like this.'));
            self.focus_after_save = true;
            self.load(false);
        }, function () {
            if (!self.active) return;
            self.saving = false;
            self.$('.NB-feedback-history-status').text('Couldn’t save. Your choice is unchanged. Please try again.');
            self.$('.NB-feedback-tab, .NB-feedback-load-more').prop('disabled', false);
            self.$('.NB-feedback-history-vote').each(function () {
                $(this).prop('disabled', $(this).attr('aria-pressed') === 'true');
            });
        });
    },

    load_more: function () { if (!this.loading && !this.saving && this.next_cursor) this.load(true); },
    retry: function () { if (!this.loading) this.load(this.retry_append); }
});
