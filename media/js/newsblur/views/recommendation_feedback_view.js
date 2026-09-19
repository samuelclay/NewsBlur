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

NEWSBLUR.discovery_preview_active = function () {
    return NEWSBLUR.reader.active_feed === 'trending:discovery' &&
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

NEWSBLUR.reveal_discovery_stories = function () {
    NEWSBLUR.assets.stories.each(function (story, index) {
        if (index >= 12) return;
        _.each([story.story_title_view, story.story_view], function (view) {
            if (!view) return;
            view.$el.css('--discovery-reveal-delay', Math.min(index * 110, 770) + 'ms')
                .addClass('NB-discovery-reveal').one('animationend', function () {
                    $(this).removeClass('NB-discovery-reveal');
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
            this.$el.append($('<span class="NB-feedback-count unread_count_positive">').text(summary.more));
            this.$el.append($('<span class="NB-feedback-count unread_count_negative">').text(summary.less));
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
        this.choice = 1;
        this.request_number = 0;
        this.active = true;
        this.$el.html('<h2 class="NB-modal-title" id="NB-feedback-history-title">Your Discovery preferences</h2>' +
            '<p class="NB-feedback-history-intro">The stories shaping your recommendations. Change or clear a choice at any time.</p>' +
            '<div class="NB-feedback-tabs" role="group" aria-label="Preference lists">' +
            '<button type="button" class="NB-feedback-tab" data-value="1" aria-pressed="true">More like this <b>0</b></button>' +
            '<button type="button" class="NB-feedback-tab" data-value="-1" aria-pressed="false">Less like this <b>0</b></button></div>' +
            '<div class="NB-feedback-history-chart"></div>' +
            '<div class="NB-feedback-chart-caption"><span>Current choices by last update · 30 days (UTC)</span><span class="NB-feedback-chart-dates"></span></div>' +
            '<div class="NB-feedback-history-status" role="status" aria-live="polite"></div>' +
            '<div class="NB-feedback-history-stories"></div>' +
            '<button type="button" class="NB-feedback-load-more" hidden>Show more stories</button>' +
            '<button type="button" class="NB-feedback-history-retry" hidden>Couldn’t load preferences · Retry</button>' +
            '<div class="NB-modal-submit"><button type="button" class="NB-modal-submit-button NB-modal-submit-green NB-feedback-history-close">Done</button></div>');
    },

    open: function () {
        var self = this;
        this.$el.modal({
            minWidth: Math.min(680, $(window).width() - 40),
            maxWidth: 680,
            overlayClose: true,
            onClose: function () {
                self.active = false;
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
        this.load(false);
    },

    load: function (append) {
        var self = this, request_number = ++this.request_number;
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
