NEWSBLUR.utils = {

    // reader_utils.js: True when the user's tier is below Premium Archive, which
    // means briefings are preview-only: no scheduled auto-generation and only the
    // first few curated stories per briefing.
    is_briefing_preview: function () {
        return !NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_pro;
    },

    // reader_utils.js: True when the interface language is written right to left
    // (Arabic, Hebrew). templates/base.html sets <html dir> from the account
    // language, and the page links CSS mirrored by utils/rtl_css.py plus the
    // overrides in media/css/reader/reader_rtl.css.
    is_rtl: function () {
        return document.documentElement.dir == 'rtl';
    },

    // reader_utils.js: jQuery Layout pane names are physical ("west" is always
    // the left side). Callers name the logical edge they mean for LTR, and in RTL
    // this returns the mirrored pane, so the feed list and the side-by-side story
    // titles pane sit on the right.
    layout_edge: function (edge) {
        if (!NEWSBLUR.utils.is_rtl()) return edge;
        if (edge == 'west') return 'east';
        if (edge == 'east') return 'west';
        return edge;
    },

    // reader_utils.js: $.fn.align (media/js/vendor/jquery.newsblur.js) only knows
    // LTR placements. In RTL, flip an aligned popover or menu horizontally around
    // its anchor so it opens toward the inline end, mirroring the LTR geometry.
    mirror_aligned_element: function ($el, $anchor) {
        if (!NEWSBLUR.utils.is_rtl()) return;
        $anchor = $($anchor).first();
        if (!$el || !$el.length || !$anchor.length) return;
        var anchor_offset = $anchor.offset();
        var el_offset = $el.offset();
        if (!anchor_offset || !el_offset) return;
        var el_width = $el.outerWidth();
        var anchor_width = $anchor.outerWidth();
        var client_width = document.documentElement.clientWidth;
        var mirrored_left = 2 * anchor_offset.left + anchor_width - el_offset.left - el_width;
        mirrored_left = Math.max(0, Math.min(mirrored_left, client_width - el_width));
        // Pin the mirrored element by its right edge, so if it grows later (scrollbars,
        // late content) it grows toward the inline end like the LTR original does.
        var $parent = $el.offsetParent();
        var parent = $parent[0];
        var parent_right = client_width;
        if (parent && parent != document.documentElement && parent != document.body) {
            parent_right = $parent.offset().left + parent.clientLeft + parent.clientWidth;
        }
        $el.css({ right: parent_right - (mirrored_left + el_width), left: 'auto' });
    },

    // reader_utils.js: CSS for a position: fixed popover whose inline-end edge lines up
    // with its trigger's inline-end edge, so it opens toward the middle of the screen:
    // from the trigger's right edge leftward in LTR, from its left edge rightward in RTL.
    inline_end_alignment_css: function (rect, inset) {
        inset = inset || 0;
        if (NEWSBLUR.utils.is_rtl()) {
            return { left: rect.left - inset, right: 'auto' };
        }
        return { right: window.innerWidth - rect.right - inset, left: 'auto' };
    },

    // reader_utils.js: jquery.corners takes physical corner names (tl, tr, bl, br).
    // Swap them in RTL so rounded corners follow the mirrored menus.
    rtl_corners: function (spec) {
        if (!NEWSBLUR.utils.is_rtl()) return spec;
        return spec.replace(/\b(t|b)(l|r)\b/g, function (match, vertical, horizontal) {
            return vertical + (horizontal == 'l' ? 'r' : 'l');
        });
    },

    // reader_utils.js: Splits a translated message around %(name)s placeholders
    // and inserts the matching DOM nodes, so links, badges, selects and styled
    // words stay inside one complete translatable sentence that translators can
    // reorder. A string or number in `nodes` is inserted as text. Text pieces
    // become text nodes, or whatever wrap_text returns for them; wrap_text can
    // return null to drop a piece, such as whitespace between two flex items.
    // Returns an array usable as $.make children or with $.fn.append.
    interpolate_nodes: function (message, nodes, wrap_text) {
        var parts = [];
        _.each(message.split(/(%\([a-z_]+\)s)/), function (part) {
            var match = part.match(/^%\(([a-z_]+)\)s$/);
            var node;
            if (match && _.has(nodes, match[1])) {
                node = nodes[match[1]];
                if (_.isString(node) || _.isNumber(node)) {
                    node = document.createTextNode(String(node));
                }
                parts.push(node);
            } else if (part) {
                node = wrap_text ? wrap_text(part) : document.createTextNode(part);
                if (node) parts.push(node);
            }
        });
        return parts;
    },

    // reader_utils.js: Shared Premium Archive callout — a light strip with the
    // archive badge and a one-line message that opens the upgrade modal. Used by
    // the briefing views and the related stories upsell. Pass
    // options.highlight_feature to pulse that tier line in the modal, or
    // options.on_upgrade to run custom logic (e.g. closing a popover) first.
    make_archive_callout: function (message, options) {
        options = options || {};
        var $callout = $.make('div', { className: 'NB-archive-callout', role: 'button' }, [
            $.make('span', { className: 'NB-archive-badge' }, gettext('Premium Archive')),
            $.make('span', { className: 'NB-archive-callout-text' }, message)
        ]);
        $callout.on('click', function (e) {
            e.preventDefault();
            if (options.on_upgrade) {
                options.on_upgrade();
            } else {
                NEWSBLUR.reader.open_premium_upgrade_modal({ highlight_feature: options.highlight_feature });
            }
        });
        return $callout;
    },

    // reader_utils.js: "[Upgrade to Premium] for up to 14 days" as one plural
    // message, with the upgrade badge as a placeholder so translations can put
    // it anywhere. Shown under the mark-as-unread sliders in reader_mark_read.js
    // and reader_feed_exception.js when the reader picks more days than their
    // plan keeps.
    make_upgrade_days_notice: function ($badge, days) {
        return NEWSBLUR.utils.interpolate_nodes(
            ngettext("%(badge)s for up to %(count)s day", "%(badge)s for up to %(count)s days", days),
            { badge: $badge, count: days });
    },

    service_name: function (service) {
        switch (service) {
            case 'twitter':
                return 'Twitter';
            case 'facebook':
                return 'Facebook';
        }
    },

    compute_story_score: function (story) {
        var score = 0;
        var intelligence = story.get('intelligence');
        if (!intelligence) return score;

        // AI prompt classifier takes absolute priority
        var prompt = intelligence['prompt'] || 0;
        if (prompt != 0) return prompt;

        var score_max = Math.max(intelligence['title'],
            intelligence['title_regex'] || 0,
            intelligence['author'],
            intelligence['author_regex'] || 0,
            intelligence['tags'],
            intelligence['text'] || 0,
            intelligence['text_regex'] || 0,
            intelligence['url'] || 0,
            intelligence['url_regex'] || 0);
        var score_min = Math.min(intelligence['title'],
            intelligence['title_regex'] || 0,
            intelligence['author'],
            intelligence['author_regex'] || 0,
            intelligence['tags'],
            intelligence['text'] || 0,
            intelligence['text_regex'] || 0,
            intelligence['url'] || 0,
            intelligence['url_regex'] || 0);
        if (score_min <= -2) score = score_min;       // super downvote beats everything
        else if (score_max > 0) score = score_max;
        else if (score_min < 0) score = score_min;

        if (score == 0) score = intelligence['feed'];

        return score;
    },

    generate_shadow: _.memoize(function (feed) {
        if (!feed) return '';
        var color = feed.get('favicon_color');

        if (!color) {
            return '0 1px 0 #222';
        }

        var r, g, b;
        if (feed.is_light()) {
            color = feed.get('favicon_fade');
        } else {
            color = feed.get('favicon_border');
        }
        r = parseInt(color.substr(0, 2), 16);
        g = parseInt(color.substr(2, 2), 16);
        b = parseInt(color.substr(4, 2), 16);
        return [
            '0 1px 0 ',
            'rgb(',
            [r, g, b].join(','),
            ')'
        ].join('');
    }, function (feed) {
        return "" + feed.id;
    }),

    generate_gradient: _.memoize(function (feed, type) {
        if (!feed) return '';
        var color = feed.get('favicon_color');
        var colorFade = feed.get('favicon_fade');
        var colorBorder = feed.get('favicon_border');
        if (!color) return '';

        var r = parseInt(color.substr(0, 2), 16);
        var g = parseInt(color.substr(2, 2), 16);
        var b = parseInt(color.substr(4, 2), 16);
        var rF = parseInt(colorFade.substr(0, 2), 16);
        var gF = parseInt(colorFade.substr(2, 2), 16);
        var bF = parseInt(colorFade.substr(4, 2), 16);

        if (type == 'border') {
            r = parseInt(colorBorder.substr(0, 2), 16);
            g = parseInt(colorBorder.substr(2, 2), 16);
            b = parseInt(colorBorder.substr(4, 2), 16);
            return [
                (type == 'border' ? '1px solid ' : '') + 'rgb(',
                [
                    r,
                    g,
                    b
                ].join(','),
                ')'
            ].join('');
        } else if (type == 'webkit') {
            return [
                '-webkit-gradient(',
                'linear,',
                'left bottom,',
                'left top,',
                'color-stop(0, rgba(',
                [
                    r,
                    g,
                    b,
                    255
                ].join(','),
                ')),',
                'color-stop(1, rgba(',
                [
                    rF,
                    gF,
                    bF,
                    255
                ].join(','),
                ')))'
            ].join('');
        } else if (type == 'moz') {
            return [
                '-moz-linear-gradient(',
                'center bottom,',
                'rgb(',
                [
                    r,
                    g,
                    b
                ].join(','),
                ') 0%,',
                'rgb(',
                [
                    rF,
                    gF,
                    bF
                ].join(','),
                ') 100%)'
            ].join('');
        }
    }, function (feed, type) {
        return "" + feed.id + '-' + type;
    }),

    attach_loading_gradient: function ($elem, percentage) {
        var theme = NEWSBLUR.assets.theme();;

        if (theme == 'dark') {
            var color1 = '#315681';
            var color2 = '#214a7b';
        } else {
            var color1 = '#fcfcfc';
            var color2 = '#b1d2f9';
        }

        $elem.css('background', '-moz-linear-gradient(left, ' + color1 + ' 0%, ' + color1 + ' ' + percentage + '%, ' + color2 + ' ' + percentage + '%, ' + color2 + ' 100%)'); // FF3.6+
        $elem.css('background', '-webkit-gradient(linear, left top, right top, color-stop(0%,' + color1 + '), color-stop(' + percentage + '%,' + color1 + '), color-stop(' + percentage + '%,' + color2 + '), color-stop(100%,' + color2 + '))'); // Chrome,Safari4+
        $elem.css('background', '-webkit-linear-gradient(left, ' + color1 + ' 0%, ' + color1 + ' ' + percentage + '%, ' + color2 + ' ' + percentage + '%, ' + color2 + ' 100%)'); // Chrome10+,Safari5.1+
        $elem.css('background', 'linear-gradient(to right, ' + color1 + ' 0%, ' + color1 + ' ' + percentage + '%, ' + color2 + ' ' + percentage + '%, ' + color2 + ' 100%)');
        $elem.css("filter", "progid:DXImageTransform.Microsoft.gradient( startColorstr='" + color1 + "', endColorstr='" + color2 + "',GradientType=1 )");
    },

    is_feed_social: function (feed_id) {
        return _.string.include(feed_id, 'social:');
    },

    monthNames: [gettext('January'), gettext('February'), gettext('March'), gettext('April'), gettext('May'), gettext('June'), gettext('July'), gettext('August'), gettext('September'), gettext('October'), gettext('November'), gettext('December')],
    // reader_utils.js: The page language abbreviates month names, since gettext cannot tell a short "May" from the full name.
    shortMonthNames: _.map(_.range(12), function (month) {
        return new Date(2000, month, 1).toLocaleDateString(document.documentElement.lang || undefined, { month: 'short' });
    }),
    dayNames: [gettext('Sunday'), gettext('Monday'), gettext('Tuesday'), gettext('Wednesday'), gettext('Thursday'), gettext('Friday'), gettext('Saturday')],

    format_date: function (date) {
        var dayOfWeek = date.getDay();
        var month = date.getMonth();
        var year = date.getUTCFullYear();
        var day = date.getDate();

        return interpolate(gettext("%(weekday)s, %(month)s %(day)s, %(year)s"), {
            weekday: this.dayNames[dayOfWeek],
            month: this.monthNames[month],
            day: day,
            year: year
        }, true);
    },

    make_feed_chooser: function (options) {
        options = options || {};
        var $chooser = $.make('select', { name: 'feed', className: 'NB-modal-feed-chooser' });
        var $folders_optgroup = $.make('optgroup', { label: gettext("Folders") });
        var $feeds_optgroup = $.make('optgroup', { label: gettext("Sites") });
        var $social_feeds_optgroup = $.make('optgroup', { label: gettext("Blurblogs") });
        var $saved_searches_optgroup = $.make('optgroup', { label: gettext("Saved Searches") });
        var $starred_feeds_optgroup = $.make('optgroup', { label: gettext("Saved Tags") });
        var current_feed_id = options.feed_id;
        var selected_feed_prefix = '';

        var make_feed_option = function (feed) {
            if (!feed.get('feed_title')) return;
            if (!feed.get('active')) return;
            // If filter_feed_ids is provided, only include feeds in that set
            if (options.filter_feed_ids && !options.filter_feed_ids[feed.id]) return;
            var prefix = 'feed:';
            if (feed.is_starred()) prefix = '';
            else if (feed.is_social()) prefix = '';
            else if (feed.is_search()) prefix = '';

            var $option = $.make('option', { value: prefix + feed.id }, feed.get('feed_title'));
            $option.appendTo(feed.is_starred() ? $starred_feeds_optgroup :
                feed.is_social() ? $social_feeds_optgroup :
                    feed.is_search() ? $saved_searches_optgroup :
                        $feeds_optgroup);

            if (feed.id == current_feed_id) {
                // console.log('Selecting feed id in feed chooser', feed, current_feed_id);
                $option.attr('selected', true);
                $chooser.val(prefix + feed.id);
                selected_feed_prefix = prefix;
            }
        };

        this.feeds = NEWSBLUR.assets.get_feeds();
        this.feeds.each(make_feed_option);

        if (!options.skip_social) {
            this.social_feeds = NEWSBLUR.assets.get_social_feeds();
            this.social_feeds.each(make_feed_option);
        }

        if (!options.skip_searches) {
            this.search_feeds = NEWSBLUR.assets.get_search_feeds();
            this.search_feeds.each(make_feed_option);
        }

        if (!options.skip_starred) {
            this.starred_feeds = NEWSBLUR.assets.get_starred_feeds();
            this.starred_feeds.each(make_feed_option);
        }

        if (options.include_folders) {
            var $folders = NEWSBLUR.utils.make_folders(options.feed_id, options.toplevel, options.name, options.include_special_folders, options.filter_feed_ids);
            $('option', $folders).each(function () {
                $(this).appendTo($folders_optgroup);
            });
        }

        $('option', $feeds_optgroup).tsort();
        $('option', $social_feeds_optgroup).tsort();
        $('option', $starred_feeds_optgroup).tsort();
        $('option', $saved_searches_optgroup).tsort();
        // $('option[value^=river]', $folders_optgroup).tsort();

        if (options.include_folders) {
            $chooser.append($folders_optgroup);
        }
        $chooser.append($feeds_optgroup);
        if (!options.skip_social) {
            $chooser.append($social_feeds_optgroup);
        }
        if (!options.skip_searches) {
            $chooser.append($saved_searches_optgroup);
        }
        if (!options.skip_starred) {
            $chooser.append($starred_feeds_optgroup);
        }

        if (options.feed_id) {
            $chooser.val(selected_feed_prefix + options.feed_id);
        }

        return $chooser;
    },

    make_folders: function (selected_folder_title, toplevel, select_name, include_special_folders, filter_feed_ids) {
        // console.log('make_folders', selected_folder_title);
        var folders = NEWSBLUR.assets.get_folders();
        var $options = $.make('select', { className: 'NB-folders', name: select_name });

        if (include_special_folders) {
            var $option = $.make('option', { value: 'river:global' }, gettext("Global Shared Stories"));
            $options.append($option);
            if (selected_folder_title == "river:global") {
                $option.attr('selected', true);
            }

            var $option = $.make('option', { value: 'river:blurblogs' }, gettext("All Shared Stories"));
            $options.append($option);
            if (selected_folder_title == "river:blurblogs") {
                $option.attr('selected', true);
            }

            var $option = $.make('option', { value: 'river:infrequent' }, gettext("Infrequent Site Stories"));
            $options.append($option);
            if (selected_folder_title == "river:infrequent") {
                $option.attr('selected', true);
            }

            var $option = $.make('option', { value: 'trending:well_read' }, gettext("Widely Read Stories"));
            $options.append($option);
            if (selected_folder_title == "trending:well_read") {
                $option.attr('selected', true);
            }

            var $option = $.make('option', { value: 'trending:long_reads' }, gettext("Long Reads"));
            $options.append($option);
            if (selected_folder_title == "trending:long_reads") {
                $option.attr('selected', true);
            }

            var $option = $.make('option', { value: 'trending:good_reads' }, gettext("Good Reads"));
            $options.append($option);
            if (selected_folder_title == "trending:good_reads") {
                $option.attr('selected', true);
            }
        }

        // Only show Top Level if not filtering, or if it contains filtered feeds
        var show_top_level = !filter_feed_ids;
        if (filter_feed_ids) {
            // Check if top-level folder has any feeds with classifiers
            var top_feeds = NEWSBLUR.assets.get_feeds().filter(function (f) {
                return !f.get('folder') || f.get('folder') === '';
            });
            show_top_level = _.any(top_feeds, function (f) {
                return filter_feed_ids[f.id];
            });
        }
        if (show_top_level) {
            var $option = $.make('option', { value: 'river:' }, toplevel || gettext("Top Level"));
            $options.append($option);
            if (selected_folder_title == "river:") {
                $option.attr('selected', true);
            }
        }

        $options = this.make_folder_options($options, folders, '&nbsp;&nbsp;&nbsp;', selected_folder_title, filter_feed_ids);

        return $options;
    },

    make_folder_options: function ($options, items, depth, selected_folder_title, filter_feed_ids) {
        var self = this;
        items.each(function (item) {
            if (item.is_folder()) {
                // If filtering, check if folder contains any feeds with classifiers
                if (filter_feed_ids) {
                    var folder_feeds = item.feed_ids_in_folder();
                    var has_filtered_feed = _.any(folder_feeds, function (feed_id) {
                        return filter_feed_ids[feed_id];
                    });
                    if (!has_filtered_feed) return;
                }
                var $option = $.make('option', {
                    value: 'river:' + item.get('folder_title')
                }, depth + ' ' + item.get('folder_title'));
                $options.append($option);
                if (item.get('folder_title') == selected_folder_title) {
                    $option.attr('selected', true);
                }
                $options = self.make_folder_options($options, item.folders, depth + '&nbsp;&nbsp;&nbsp;', selected_folder_title, filter_feed_ids);
            }
        });

        return $options;
    },

    is_url_iframe_buster: function (url) {
        // Also change in utils/page_importer.py.
        var BROKEN_URLS = [
            'nytimes.com',
            'github.com',
            'medium.com',
            'washingtonpost.com',
            'stackoverflow.com',
            'stackexchange.com',
            'twitter.com',
            'rankexploits',
            'gamespot.com',
            'royalroad.com'
        ];
        return _.any(BROKEN_URLS, function (broken_url) {
            return _.string.contains(url, broken_url);
        });
    },

    calculate_update_interval: function (update_interval_minutes) {
        if (!update_interval_minutes) return '&nbsp;';

        var interval_start = update_interval_minutes;
        var interval_end = update_interval_minutes * 1.25;
        var interval = '';
        if (interval_start < 60) {
            interval = interpolate(ngettext("%(start)s to %(end)s minute", "%(start)s to %(end)s minutes", interval_end), {
                start: interval_start,
                end: interval_end
            }, true);
        } else {
            var interval_start_hours = parseInt(interval_start / 60, 10);
            var interval_end_hours = parseInt(interval_end / 60, 10);
            var dec_start = interval_start % 60;
            var dec_end = interval_end % 60;
            var start_hours = interval_start_hours + (dec_start >= 30 ? '.5' : '');
            var end_hours = interval_end_hours + (dec_end >= 30 || interval_start_hours == interval_end_hours ? '.5' : '');
            interval = interpolate(ngettext("%(start)s to %(end)s hour", "%(start)s to %(end)s hours", parseFloat(end_hours)), {
                start: start_hours,
                end: end_hours
            }, true);
        }

        return interval;
    },

    days_back_to_timestamp: function (days_back) {
        if (days_back > 365) {
            // It's a timestamp, not the number of days back
            return days_back;
        }

        days_back = days_back || 0;
        var now = Math.round((new Date()).getTime() / 1000);

        return now - (days_back * 60 * 60 * 24);
    },

    MUTE_SLIDER_STOPS: [1, 2, 3, 4, 5, 6, 7, 10, 14, 21, 30, 60, 90, 180, 270, 365],

    mute_slider_to_days: function (index) {
        return this.MUTE_SLIDER_STOPS[index] || 7;
    },

    format_mute_days: function (days) {
        // reader_utils.js: Mute slider stops read as days, whole weeks, months, or a year.
        if (days >= 365) {
            return interpolate(ngettext("%(count)s year", "%(count)s years", 1), {count: 1}, true);
        }
        if (days >= 30) {
            var months = Math.round(days / 30);
            return interpolate(ngettext("%(count)s month", "%(count)s months", months), {count: months}, true);
        }
        if (days == 7 || days == 14 || days == 21) {
            var weeks = days / 7;
            return interpolate(ngettext("%(count)s week", "%(count)s weeks", weeks), {count: weeks}, true);
        }
        return interpolate(ngettext("%(count)s day", "%(count)s days", days), {count: days}, true);
    },

    // reader_utils.js: Label for the save button under every mute duration slider.
    format_mute_button_label: function (days) {
        return interpolate(gettext("Mute for %(duration)s"), {duration: this.format_mute_days(days)}, true);
    },

    // reader_utils.js: Localized time until a mute expires, or null once it has expired.
    mute_duration_remaining: function (expires_at_iso) {
        var now = new Date();
        var expires = new Date(expires_at_iso);
        var diff_ms = expires - now;
        if (diff_ms <= 0) return null;

        var days = Math.floor(diff_ms / (1000 * 60 * 60 * 24));
        var hours = Math.floor(diff_ms / (1000 * 60 * 60));

        if (days >= 365) {
            var years = Math.round(days / 365);
            return interpolate(ngettext("%(count)s year", "%(count)s years", years), {count: years}, true);
        }
        if (days >= 30) {
            var months = Math.round(days / 30);
            return interpolate(ngettext("%(count)s month", "%(count)s months", months), {count: months}, true);
        }
        if (days >= 7) {
            var weeks = Math.round(days / 7);
            return interpolate(ngettext("%(count)s week", "%(count)s weeks", weeks), {count: weeks}, true);
        }
        if (days >= 1) {
            return interpolate(ngettext("%(count)s day", "%(count)s days", days), {count: days}, true);
        }
        return interpolate(ngettext("%(count)s hour", "%(count)s hours", hours), {count: hours}, true);
    },

    mute_time_remaining: function (expires_at_iso) {
        var remaining = this.mute_duration_remaining(expires_at_iso);
        if (!remaining) return gettext('unmuting soon');
        return interpolate(gettext("%(time)s left"), {time: remaining}, true);
    }

};
