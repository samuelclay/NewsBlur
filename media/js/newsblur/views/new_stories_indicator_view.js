// new_stories_indicator_view.js: The "N new stories" pill that floats over the story titles while stories that
// arrived over the socket wait to join the open feed or folder. reader.js fetches them
// (handle_realtime_new_story) and puts them into the list when the pill is clicked. It floats at the top of a
// newest-first list and at the bottom of an oldest-first one, like the iOS and Android apps'
// (clients/ios/Classes/NewStoriesPill.swift).
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
        return this;
    },

    show: function (count, at_bottom) {
        if (!count) return this.hide();
        var appearing = !this.count || this.at_bottom != at_bottom;
        this.count = count;
        this.at_bottom = !!at_bottom;
        var label = interpolate(ngettext("%(count)s new story", "%(count)s new stories", count),
            { count: Inflector.commas(count) }, true);
        this.$('.NB-new-stories-indicator-label').text(label);
        this.$el.attr('aria-label', label).toggleClass('NB-at-bottom', this.at_bottom);
        if (appearing) {
            this.$el.removeClass('NB-visible');
            (this.at_bottom ? this.$bottom_anchor : this.$top_anchor).append(this.$el);
            // new_stories_indicator_view.js: the next frame, so the CSS transition runs instead of snapping in.
            _.defer(_.bind(function () {
                if (this.count) this.$el.addClass('NB-visible');
            }, this));
        }
    },

    hide: function () {
        this.count = 0;
        this.$el.removeClass('NB-visible');
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
