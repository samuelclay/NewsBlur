// new_stories_indicator_view.js: The "N new stories" pill that floats over the story titles while stories that
// arrived over the socket wait to join the open feed or folder. reader.js fetches them
// (handle_realtime_new_story) and puts them into the list when the pill is clicked. It floats at the top of a
// newest-first list and at the bottom of an oldest-first one, like the iOS and Android apps'
// (clients/ios/Classes/NewStoriesPill.swift).
//
// It keeps out of the way of reading: the first scroll away from it (down from the top pill, up from the bottom
// one) gives it REALTIME_PILL_HIDE_AFTER_SCROLLING before it slides away, whatever the reader does meanwhile, and
// it comes back only once the list hasn't scrolled for REALTIME_PILL_RETURN_AFTER_IDLE. Both numbers live in
// reader.js's constants.
//
// While stories wait, a full-width "N new stories" row also leads the list (ends an oldest-first one), part of the
// list like a story title, so the stories can be brought in even after scrolling has sent the pill away. The pill
// stays hidden while the row is on screen.
NEWSBLUR.Views.NewStoriesIndicatorView = Backbone.View.extend({

    className: 'NB-new-stories-indicator',

    events: {
        'click': 'on_click',
        'keydown': 'on_keydown'
    },

    initialize: function (options) {
        this.$container = options.$container;
        this.count = 0;
        this.at_bottom = false;
        this.reset_scrolling();
        this.last_scroll_at = 0;
        this.last_scroll_top = null;
        this.own_scroll_top = null;
        this.note_scroll = _.bind(this.note_scroll, this);
        // new_stories_indicator_view.js: a phone list scrolls the page itself while at rest (mobile.css
        // NB-mobile-page-scroll), so both scrollers count.
        this.$container.on('scroll', this.note_scroll);
        $(window).on('scroll', this.note_scroll);
    },

    render: function () {
        this.$el.attr({ role: 'button', tabindex: 0 });
        this.$el.html([
            '<span class="NB-new-stories-indicator-icon" aria-hidden="true">',
            '<svg viewBox="0 0 16 16" width="14" height="14"><path d="M8 3.5 L3.5 8 H6 V12 H10 V8 H12.5 Z" fill="currentColor"></path></svg>',
            '</span>',
            '<span class="NB-new-stories-indicator-label"></span>'
        ].join(''));
        // new_stories_indicator_view.js: #story_titles is the scrolling element, so zero-height sticky anchors at
        // its top and bottom keep the pill in view without taking space in the list.
        this.$top_anchor = $.make('div', { className: 'NB-new-stories-indicator-anchor NB-top' });
        this.$bottom_anchor = $.make('div', { className: 'NB-new-stories-indicator-anchor NB-bottom' });
        this.$container.prepend(this.$top_anchor).append(this.$bottom_anchor);
        this.$top_anchor.append(this.$el);
        this.$row = $.make('div', { className: 'NB-new-stories-row', role: 'button', tabindex: 0 }, [
            $.make('span', { className: 'NB-new-stories-indicator-icon', 'aria-hidden': 'true' }),
            $.make('span', { className: 'NB-new-stories-row-label' })
        ]);
        this.$row.find('.NB-new-stories-indicator-icon').html(this.$('.NB-new-stories-indicator-icon').html());
        this.$row.on('click', _.bind(this.on_click, this)).on('keydown', _.bind(this.on_keydown, this));
        return this;
    },

    show: function (count, at_bottom) {
        if (!count) return this.hide();
        var moved = this.at_bottom != !!at_bottom;
        this.count = count;
        this.at_bottom = !!at_bottom;
        var label = interpolate(ngettext("%(count)s new story", "%(count)s new stories", count),
            { count: Inflector.commas(count) }, true);
        this.$('.NB-new-stories-indicator-label').text(label);
        this.$el.attr('aria-label', label).toggleClass('NB-at-bottom', this.at_bottom);
        this.$row.find('.NB-new-stories-row-label').text(label);
        this.$row.attr('aria-label', label).toggleClass('NB-at-bottom', this.at_bottom);
        if (moved) {
            this.$el.removeClass('NB-visible');
            (this.at_bottom ? this.$bottom_anchor : this.$top_anchor).append(this.$el);
        }
        this.place_row();
        if (this.hidden_by_scrolling) {
            this.schedule_return();
        } else {
            this.slide_in();
        }
    },

    hide: function () {
        this.count = 0;
        this.reset_scrolling();
        this.$el.removeClass('NB-visible');
        this.place_row();
    },

    // new_stories_indicator_view.js: the row is in the list while stories are waiting. Adding or removing it above
    // the stories being read keeps them where they are on screen.
    place_row: function () {
        var wanted = !!this.count;
        var $titles = this.$container.find('.NB-story-titles').first();
        var placed = this.$row[0].isConnected;
        var in_place = placed && (this.at_bottom ? this.$row.parent().is($titles) : this.$row.next().is($titles));
        if (wanted == placed && (!wanted || in_place)) return;
        var titles_top = $titles.length ? $titles[0].getBoundingClientRect().top : 0;
        var scroll_top = NEWSBLUR.reader.$s.$story_titles.scrollTop();
        this.$row.detach();
        if (wanted && $titles.length) {
            if (!this.at_bottom) {
                $titles.before(this.$row);
            } else {
                var $end = $titles.children('.NB-end-line').first();
                if ($end.length) $end.before(this.$row); else $titles.append(this.$row);
            }
        }
        var shift = $titles.length ? $titles[0].getBoundingClientRect().top - titles_top : 0;
        if (shift && scroll_top > 0) {
            // new_stories_indicator_view.js: browsers without scroll anchoring would otherwise move the stories.
            NEWSBLUR.reader.$s.$story_titles.scrollTop(NEWSBLUR.reader.$s.$story_titles.scrollTop() + shift);
        }
        // new_stories_indicator_view.js: the scroll this shift makes, or the browser's scroll anchoring makes for it,
        // isn't the reader scrolling, so note_scroll lets it pass.
        var settled_top = NEWSBLUR.reader.$s.$story_titles.scrollTop();
        this.own_scroll_top = settled_top != scroll_top ? settled_top : null;
    },

    slide_in: function () {
        if (this.$el.hasClass('NB-visible') || this.row_on_screen()) return;
        // new_stories_indicator_view.js: the next frame, so the CSS transition runs instead of snapping in.
        _.defer(_.bind(function () {
            if (this.count && !this.hidden_by_scrolling && !this.row_on_screen()) this.$el.addClass('NB-visible');
        }, this));
    },

    // new_stories_indicator_view.js: whether any of the row shows in the list's viewport, below a phone's bars.
    row_on_screen: function () {
        if (!this.$row || !this.$row[0].isConnected) return false;
        var rect = this.$row[0].getBoundingClientRect();
        var top, bottom;
        if ($('body').hasClass('NB-mobile-page-scroll')) {
            top = parseFloat(getComputedStyle(this.$top_anchor[0]).top) || 0;
            bottom = window.innerHeight;
        } else {
            var pane = this.$container[0].getBoundingClientRect();
            top = pane.top;
            bottom = pane.bottom;
        }
        return rect.bottom > top + 1 && rect.top < bottom - 1;
    },

    // new_stories_indicator_view.js: the pill gives way to the row while the row is on screen.
    sync_with_row: function () {
        if (!this.count || this.hidden_by_scrolling) return;
        if (this.row_on_screen()) {
            this.$el.removeClass('NB-visible');
        } else {
            this.slide_in();
        }
    },

    reset_scrolling: function () {
        this.hidden_by_scrolling = false;
        clearTimeout(this.hide_timer);
        this.hide_timer = null;
        clearTimeout(this.return_timer);
        this.return_timer = null;
    },

    // new_stories_indicator_view.js: the first scroll away from the visible pill starts its countdown, and every
    // scroll restarts the idle wait of a pill that scrolling hid.
    note_scroll: function () {
        var scroll_top = NEWSBLUR.reader.$s.$story_titles.scrollTop();
        var own_scroll = this.own_scroll_top !== null && scroll_top == this.own_scroll_top;
        this.own_scroll_top = null;
        if (own_scroll) {
            // new_stories_indicator_view.js: place_row's shift starts no countdown and doesn't restart the idle wait.
            this.last_scroll_top = scroll_top;
            return;
        }
        var previous_top = this.last_scroll_top;
        this.last_scroll_top = scroll_top;
        this.last_scroll_at = Date.now();
        if (!this.count) return;
        if (this.hidden_by_scrolling) return this.schedule_return();
        this.sync_with_row();
        if (this.hide_timer || previous_top === null || !this.$el.hasClass('NB-visible')) return;
        var away = this.at_bottom ? scroll_top < previous_top : scroll_top > previous_top;
        if (!away) return;
        this.hide_timer = setTimeout(_.bind(function () {
            this.hide_timer = null;
            if (!this.count || !this.$el.hasClass('NB-visible')) return;
            this.hidden_by_scrolling = true;
            this.hidden_at = Date.now();
            this.$el.removeClass('NB-visible');
            this.schedule_return();
        }, this), NEWSBLUR.reader.constants.REALTIME_PILL_HIDE_AFTER_SCROLLING);
    },

    // new_stories_indicator_view.js: the idle wait counts from the later of the pill hiding and the last scroll, so
    // the scroll that started its countdown doesn't shorten the wait.
    schedule_return: function () {
        clearTimeout(this.return_timer);
        var idle = NEWSBLUR.reader.constants.REALTIME_PILL_RETURN_AFTER_IDLE;
        var still_since = Math.max(this.last_scroll_at, this.hidden_at || 0);
        var wait = Math.max(0, still_since + idle - Date.now());
        this.return_timer = setTimeout(_.bind(function () {
            this.return_timer = null;
            if (!this.count || Date.now() - Math.max(this.last_scroll_at, this.hidden_at || 0) < idle) return;
            this.hidden_by_scrolling = false;
            this.slide_in();
        }, this), wait);
    },

    on_click: function (e) {
        e.preventDefault();
        if (!this.count) return;
        this.hide();
        NEWSBLUR.reader.insert_realtime_new_stories();
    },

    on_keydown: function (e) {
        if (e.which == 13 || e.which == 32) this.on_click(e);
    }

});
