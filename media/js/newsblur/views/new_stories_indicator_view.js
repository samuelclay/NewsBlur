// new_stories_indicator_view.js: Floating pill over the story titles pane
// that tells the user "N new stories" when our refresh_feeds poll reports
// story hashes they don't have yet. Click prepends those stories at the
// top of the collection and smooth-scrolls there. See reader.js
// handle_new_story_hashes / load_new_stories_from_indicator for the wiring.
NEWSBLUR.Views.NewStoriesIndicatorView = Backbone.View.extend({

    className: 'NB-new-stories-indicator',

    events: {
        'click': 'on_click'
    },

    initialize: function (options) {
        options = options || {};
        this.count = 0;
        this.visible = false;
        this.loading = false;
        this.$container = options.$container;
    },

    render: function () {
        this.$el.attr('role', 'button');
        this.$el.attr('tabindex', '0');
        this.$el.html(this._markup());
        if (this.$container && this.$container.length) {
            this.$container.append(this.$el);
        }
        return this;
    },

    _markup: function () {
        // new_stories_indicator_view.js: Arrow icon + count + label.
        // Uses inline SVG so we don't ship a separate asset for one icon.
        return [
            '<span class="NB-new-stories-indicator-icon" aria-hidden="true">',
            '  <svg viewBox="0 0 16 16" width="14" height="14">',
            '    <path d="M8 3.5 L3.5 8 H6 V12 H10 V8 H12.5 Z" fill="currentColor"></path>',
            '  </svg>',
            '</span>',
            '<span class="NB-new-stories-indicator-label">',
            '  <span class="NB-new-stories-indicator-count">0</span>',
            '  <span class="NB-new-stories-indicator-text">new stories</span>',
            '</span>'
        ].join('');
    },

    show: function (count) {
        if (!count || count < 1) {
            this.hide();
            return;
        }
        if (this.loading) return;
        this.count = count;
        this._update_text();
        if (!this.visible) {
            this.visible = true;
            // Next tick so the CSS transition runs instead of snapping in.
            _.defer(_.bind(function () {
                this.$el.addClass('NB-visible');
            }, this));
        }
    },

    hide: function () {
        if (!this.visible && !this.loading) return;
        this.visible = false;
        this.loading = false;
        this.count = 0;
        this.$el.removeClass('NB-visible NB-loading');
    },

    set_loading: function (loading) {
        this.loading = !!loading;
        this.$el.toggleClass('NB-loading', this.loading);
    },

    _update_text: function () {
        this.$('.NB-new-stories-indicator-count').text(this.count);
        this.$('.NB-new-stories-indicator-text').text(this.count === 1 ? 'new story' : 'new stories');
    },

    on_click: function (e) {
        e.preventDefault();
        if (this.loading) return;
        if (!this.visible || !this.count) return;
        if (NEWSBLUR.reader && _.isFunction(NEWSBLUR.reader.load_new_stories_from_indicator)) {
            NEWSBLUR.reader.load_new_stories_from_indicator();
        }
    }

});
