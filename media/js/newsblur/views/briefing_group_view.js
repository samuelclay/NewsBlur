NEWSBLUR.Views.BriefingGroupView = Backbone.View.extend({

    className: 'NB-briefing-group',

    events: {
        "click .NB-briefing-group-header": "toggle_collapse"
    },

    initialize: function () {
        this.briefing = this.options.briefing;
        this.stories = [];
    },

    render: function () {
        var briefing = this.briefing;
        var briefing_date = briefing.briefing_date ? new Date(briefing.briefing_date) : new Date();
        var story_count = (briefing.curated_stories || []).length;

        var $header = this.render_header(briefing_date, story_count);
        var $stories = this.render_curated_stories(briefing);

        this.$el.empty()
            .append($header)
            .append($stories);

        return this;
    },

    render_header: function (briefing_date, story_count) {
        var date_label = this.format_date(briefing_date);

        return $.make('div', { className: 'NB-briefing-group-header' }, [
            $.make('div', { className: 'NB-briefing-group-collapse-icon' }),
            $.make('div', { className: 'NB-briefing-group-date' }, date_label),
            $.make('div', { className: 'NB-briefing-group-count' }, [
                $.make('span', story_count + (story_count === 1 ? ' story' : ' stories'))
            ])
        ]);
    },

    render_curated_stories: function (briefing) {
        var $container = $.make('div', { className: 'NB-briefing-group-stories' });
        var collection = this.options.collection;
        var story_layout = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') || 'list';

        // briefing_group_view.js: Build the full story list with summary first
        var stories_to_render = briefing.summary_story ? [briefing.summary_story] : [];
        stories_to_render = stories_to_render.concat(briefing.curated_stories || []);

        // briefing_group_view.js: Ensure feeds are in the asset model so StoryTitleView
        // can look them up via NEWSBLUR.assets.get_feed().
        _.each(stories_to_render, function (story_data) {
            if (story_data.feed_id && !NEWSBLUR.assets.get_feed(story_data.feed_id)) {
                NEWSBLUR.assets.temp_feeds.add({
                    id: story_data.feed_id,
                    feed_title: story_data.feed_title || '',
                    favicon_color: story_data.favicon_color || ''
                });
            }
        });

        // briefing_group_view.js: Look up Story models from the main collection
        // (populated by render_briefing) so selection and split view work correctly.
        _.each(stories_to_render, function (story_data) {
            var story_model = collection.get_by_story_hash(story_data.story_hash);
            if (!story_model) {
                story_model = new NEWSBLUR.Models.Story(story_data);
            }
            var story_view = new NEWSBLUR.Views.StoryTitleView({
                model: story_model,
                collection: collection,
                is_list: story_layout == 'list',
                is_grid: story_layout == 'grid',
                is_magazine: story_layout == 'magazine'
            }).render();

            // briefing_group_view.js: Mark the summary story with a special class
            if (story_data.is_briefing_summary) {
                story_view.$el.addClass('NB-briefing-summary-story');
            }

            $container.append(story_view.el);
        }, this);

        // briefing_group_view.js: Show preview upsell for free users
        if (briefing.is_preview) {
            var $upsell = $.make('div', { className: 'NB-briefing-upsell' }, [
                $.make('div', { className: 'NB-briefing-upsell-text' }, [
                    'Get daily briefings with all your top stories. ',
                    $.make('a', {
                        href: '#',
                        className: 'NB-briefing-upsell-link'
                    }, 'Upgrade to Premium Archive')
                ])
            ]);
            $upsell.on('click', '.NB-briefing-upsell-link', function (e) {
                e.preventDefault();
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
            $container.append($upsell);
        }

        return $container;
    },

    // ==========
    // = Events =
    // ==========

    toggle_collapse: function (e) {
        var $header = this.$('.NB-briefing-group-header');
        var $stories = this.$('.NB-briefing-group-stories');

        $header.toggleClass('NB-collapsed');

        if ($header.hasClass('NB-collapsed')) {
            // briefing_group_view.js: Use CSS transition instead of jQuery animate
            // because jQuery animate forces overflow:hidden which breaks sticky positioning
            $stories.css({ height: $stories[0].scrollHeight + 'px', overflow: 'clip' });
            requestAnimationFrame(function () {
                $stories.addClass('NB-collapsing');
                $stories.css({ height: '0px' });
            });
            $stories.one('transitionend', function () {
                $stories.removeClass('NB-collapsing').hide().css({ height: '', overflow: '' });
            });
        } else {
            // briefing_group_view.js: Measure scrollHeight while hidden to avoid a flash
            $stories.css({ visibility: 'hidden', display: '', height: 'auto', overflow: 'clip' });
            var target_height = $stories[0].scrollHeight;
            $stories.css({ height: '0px', visibility: '' });
            requestAnimationFrame(function () {
                $stories.addClass('NB-collapsing');
                $stories.css({ height: target_height + 'px' });
            });
            $stories.one('transitionend', function () {
                $stories.removeClass('NB-collapsing').css({ height: '', overflow: '' });
            });
        }
    },

    // =============
    // = Utilities =
    // =============

    format_date: function (date) {
        var today = new Date();
        var yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);

        var date_str = date.toLocaleDateString(undefined, {
            month: 'long', day: 'numeric', year: 'numeric'
        });

        if (date.toDateString() === today.toDateString()) {
            return 'Today, ' + date_str;
        } else if (date.toDateString() === yesterday.toDateString()) {
            return 'Yesterday, ' + date_str;
        }

        return date.toLocaleDateString(undefined, {
            weekday: 'long', month: 'long', day: 'numeric', year: 'numeric'
        });
    },

    destroy: function () {
        this.remove();
    }

});
