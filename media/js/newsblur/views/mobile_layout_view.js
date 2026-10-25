// mobile_layout_view.js: turns the reader into a phone app at or below 768px.
//
// The desktop panes become stacked full-screen screens that slide over one another:
//   feeds      .left-pane, the feed list (the root screen)
//   dashboard  #NB-splash, pushed from the Dashboard row
//   titles     .right-pane, the story list in list or grid layout
//   story      views/mobile_story_pager_view.js, pushed by tapping a grid card
//
// Every screen change is a history entry tagged {screen, depth} (common/mobile_utils.js), so the
// header back button, an edge swipe and the browser or OS back gesture all walk the same stack.
// Styles live in media/css/reader/mobile.css.
NEWSBLUR.Views.MobileLayout = Backbone.View.extend({

    EDGE_WIDTH: 28,
    LONG_PRESS_MS: 480,

    initialize: function () {
        _.bindAll(this, 'check_mode', 'handle_popstate', 'handle_touchstart', 'handle_touchmove',
            'handle_touchend', 'handle_long_press_start', 'handle_long_press_cancel',
            'handle_long_press_click');
        this.utils = NEWSBLUR.mobile_utils;
        this.active = false;
        this.screen = null;
        this.depth = 0;
        this.titles_parent = 'feeds';
        this.pending_entry = null;
        this.transition = null;

        this.$body = $('body');
        this.$screens = {
            feeds: $('.NB-layout .left-pane'),
            dashboard: $('#NB-splash'),
            titles: $('.NB-layout .right-pane')
        };
        this.story_pager = new NEWSBLUR.Views.MobileStoryPager({ mobile: this });
        this.$screens.story = this.story_pager.$el;
        this.$body.append(this.story_pager.$el);

        this.build_titles_bar();
        this.build_dashboard_bar();
        this.wrap_router_navigate();

        this.media_query = window.matchMedia('(max-width: ' + this.utils.MAX_WIDTH + 'px)');
        if (this.media_query.addEventListener) {
            this.media_query.addEventListener('change', this.check_mode);
        } else {
            this.media_query.addListener(this.check_mode);
        }
        window.addEventListener('popstate', this.handle_popstate);
        document.addEventListener('touchstart', this.handle_touchstart, { passive: true });
        document.addEventListener('touchmove', this.handle_touchmove, { passive: false });
        document.addEventListener('touchend', this.handle_touchend, { passive: true });
        document.addEventListener('touchcancel', this.handle_touchend, { passive: true });
        this.setup_long_press();

        this.check_mode();
    },

    // ==========
    // = Mode   =
    // ==========

    is_active: function () {
        return this.active;
    },

    check_mode: function () {
        var should_be_active = this.media_query.matches && !NEWSBLUR.Globals.is_anonymous;
        if (should_be_active && !this.active) {
            this.activate();
        } else if (!should_be_active && this.active) {
            this.deactivate();
        }
    },

    activate: function () {
        this.active = true;
        NEWSBLUR.reader.flags.mobile = true;
        this.$body.addClass('NB-mobile');
        _.each(this.$screens, function ($screen) {
            $screen.addClass('NB-mobile-screen');
        });

        var entry = this.utils.read_history_state(window.history.state, window.location.pathname);
        var screen = entry.screen;
        if (screen === 'story' || screen === 'dashboard') {
            // A reload loses the story list and dashboard scroll, so land on the list beneath.
            screen = screen === 'story' ? 'titles' : 'feeds';
        }
        if (screen === 'titles' && NEWSBLUR.reader.flags.splash_page_frontmost &&
            this.utils.screen_for_path(window.location.pathname) !== 'titles') {
            screen = 'feeds';
        }
        this.depth = entry.tagged ? entry.depth : 0;
        this.set_screen(screen);
        this.tag_entry(screen, this.depth);
        this.update_titles_bar();
        this.refresh_story_layout();
    },

    deactivate: function () {
        this.finish_transition();
        this.story_pager.close();
        this.active = false;
        NEWSBLUR.reader.flags.mobile = false;
        this.$body.removeClass('NB-mobile NB-mobile-transitioning NB-mobile-sheet-open');
        this.$body.removeClass(this.screen_body_classes());
        _.each(this.$screens, function ($screen) {
            $screen.removeClass('NB-mobile-screen NB-mobile-pos-center NB-mobile-pos-left ' +
                'NB-mobile-pos-right NB-mobile-animating NB-mobile-dragging');
            $screen.css({ transform: '' });
            $screen[0].style.removeProperty('--nb-mobile-shade-opacity');
        });
        this.screen = null;
        this.refresh_story_layout();
        if (NEWSBLUR.reader.layout.outerLayout) {
            NEWSBLUR.reader.layout.outerLayout.resizeAll();
        }
        NEWSBLUR.reader.resize_window();
    },

    // mobile_layout_view.js: the layout preference reads differently on a phone (see
    // assetmodel.view_setting), so re-render the open story list whenever the mode flips.
    refresh_story_layout: function () {
        var reader = NEWSBLUR.reader;
        if (reader.active_feed) {
            reader.set_correct_story_view_for_feed();
            reader.switch_story_layout(null, true);
        } else if (reader.layout.rightLayout) {
            // reader.js built the panes before this view existed, and switch_story_layout skips
            // the rebuild while the layout name is unchanged, so rebuild them here.
            reader.story_layout = NEWSBLUR.assets.view_setting(null, 'layout');
            reader.apply_resizable_layout({ right_side: true });
        }
    },

    is_grid: function () {
        return this.active && NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout') == 'grid';
    },

    // ============
    // = Screens  =
    // ============

    screen_body_classes: function () {
        return 'NB-mobile-screen-is-feeds NB-mobile-screen-is-dashboard ' +
            'NB-mobile-screen-is-titles NB-mobile-screen-is-story';
    },

    // Jumps straight to a screen with no animation.
    set_screen: function (screen) {
        this.finish_transition();
        this.screen = screen;
        this.$body.removeClass(this.screen_body_classes()).addClass('NB-mobile-screen-is-' + screen);
        _.each(this.$screens, function ($screen, name) {
            $screen.removeClass('NB-mobile-pos-left NB-mobile-pos-right NB-mobile-animating')
                .toggleClass('NB-mobile-pos-center', name === screen);
        });
    },

    // Slides between screens. A push brings the new screen in from the trailing edge over the
    // old one, a pop slides the current screen away to reveal the one beneath.
    show_screen: function (screen, options) {
        options = options || {};
        var from = this.screen;
        if (!this.active || from === screen) {
            if (options.complete) options.complete();
            return;
        }
        if (!from || options.direction === 'none' || options.animate === false) {
            this.set_screen(screen);
            if (options.complete) options.complete();
            return;
        }
        this.finish_transition();

        var $from = this.$screens[from];
        var $to = this.$screens[screen];
        var push = options.direction !== 'pop';
        this.screen = screen;
        this.$body.removeClass(this.screen_body_classes()).addClass('NB-mobile-screen-is-' + screen);

        if (!options.from_drag) {
            $to.removeClass('NB-mobile-pos-center NB-mobile-pos-left NB-mobile-pos-right')
                .addClass(push ? 'NB-mobile-pos-right' : 'NB-mobile-pos-left');
            $from.removeClass('NB-mobile-pos-left NB-mobile-pos-right').addClass('NB-mobile-pos-center');
            // Flush the starting position so the class change below animates from it.
            $to[0].getBoundingClientRect();
        }

        this.$body.addClass('NB-mobile-transitioning');
        $from.add($to).removeClass('NB-mobile-dragging').addClass('NB-mobile-animating');
        this.clear_drag_styles($from.add($to));
        $to.removeClass('NB-mobile-pos-left NB-mobile-pos-right').addClass('NB-mobile-pos-center');
        $from.removeClass('NB-mobile-pos-center').addClass(push ? 'NB-mobile-pos-left' : 'NB-mobile-pos-right');

        var self = this;
        var done = function () {
            if (!self.transition || self.transition.done !== done) return;
            self.transition = null;
            clearTimeout(timer);
            $to.off('transitionend.mobile');
            $from.removeClass('NB-mobile-pos-left NB-mobile-pos-right NB-mobile-animating');
            $to.removeClass('NB-mobile-animating');
            self.$body.removeClass('NB-mobile-transitioning');
            if (options.complete) options.complete();
        };
        var timer = setTimeout(done, this.transition_duration() + 120);
        this.transition = { done: done };
        $to.on('transitionend.mobile', function (e) {
            if (e.target === $to[0] && e.originalEvent && e.originalEvent.propertyName === 'transform') {
                done();
            }
        });
    },

    finish_transition: function () {
        if (this.transition) this.transition.done();
    },

    transition_duration: function () {
        var duration = parseFloat(getComputedStyle(document.body).getPropertyValue('--nb-mobile-duration'));
        return _.isNaN(duration) ? 380 : duration;
    },

    // ============
    // = History  =
    // ============

    tag_entry: function (screen, depth, story_hash) {
        var state = this.utils.make_history_state(window.history.state, screen, depth, story_hash);
        window.history.replaceState(state, document.title, window.location.href);
    },

    push_entry: function (screen, story_hash) {
        this.depth += 1;
        var state = this.utils.make_history_state({}, screen, this.depth, story_hash);
        window.history.pushState(state, document.title, window.location.href);
    },

    // Backbone writes new entries whenever the reader opens a story list. Tag each one with the
    // screen it shows so popstate knows where to slide back to.
    wrap_router_navigate: function () {
        var self = this;
        var original_navigate = Backbone.history.navigate;
        Backbone.history.navigate = function (fragment, options) {
            var url_before = window.location.href;
            var result = original_navigate.apply(this, arguments);
            options = options || {};
            if (self.active && (options.replace || window.location.href !== url_before)) {
                var screen = self.pending_entry ||
                    self.utils.screen_for_path(window.location.pathname);
                self.pending_entry = null;
                if (!options.replace) self.depth += 1;
                self.tag_entry(screen, self.depth);
            }
            return result;
        };
    },

    handle_popstate: function (e) {
        if (!this.active) return;
        var target = this.utils.read_history_state(e.state, window.location.pathname);
        var from = { screen: this.screen, depth: this.depth, story_hash: this.story_pager.story_hash() };
        var direction = this.utils.transition_direction(from, target);
        if (!target.tagged) {
            target.depth = direction === 'pop' ? Math.max(0, this.depth - 1) : this.depth + 1;
            this.tag_entry(target.screen, target.depth);
        }
        this.depth = target.depth;

        var screen = target.screen;
        if (screen === 'story') {
            var story = target.story_hash && NEWSBLUR.assets.stories.get_by_story_hash(target.story_hash);
            if (story && this.is_grid()) {
                this.story_pager.open(story);
            } else {
                screen = 'titles';
            }
        }
        if (screen === 'titles' && !NEWSBLUR.reader.active_feed) {
            screen = 'feeds';
        }

        var drag = this.pending_back;
        this.pending_back = null;
        clearTimeout(this.pending_back_timer);
        this.show_screen(screen, {
            direction: direction === 'none' ? 'pop' : direction,
            // The browser already animated its own swipe-back, don't slide a second time.
            animate: !e.hasUAVisualTransition,
            from_drag: !!drag,
            complete: _.bind(this.after_screen_change, this)
        });
    },

    after_screen_change: function () {
        if (this.screen !== 'story') {
            this.story_pager.close();
        }
        if (this.screen === 'titles') {
            NEWSBLUR.app.story_titles.fill_out();
        }
    },

    // =============
    // = Actions   =
    // =============

    // Header back button and edge swipe. Walk back through history when the entry beneath is
    // ours, otherwise (a deep link or reload) move up a level and rewrite this entry.
    go_back: function (options) {
        options = options || {};
        if (!this.active || this.screen === 'feeds') return;
        var entry = this.utils.read_history_state(window.history.state, window.location.pathname);
        if (entry.tagged && entry.depth > 0) {
            this.pending_back = options;
            window.history.back();
            // A history.back() the browser ignores never fires popstate, so recover from that.
            this.pending_back_timer = setTimeout(_.bind(function () {
                if (!this.pending_back) return;
                this.pending_back = null;
                this.go_up(options);
            }, this), 600);
            return;
        }
        this.go_up(options);
    },

    go_up: function (options) {
        var parent = this.back_target();
        if (parent === 'feeds' && this.utils.screen_for_path(window.location.pathname) !== 'feeds') {
            this.pending_entry = 'feeds';
            NEWSBLUR.router.navigate('', { replace: true });
            this.pending_entry = null;
        }
        this.tag_entry(parent, this.depth);
        this.show_screen(parent, {
            direction: 'pop',
            from_drag: !!options.from_drag,
            complete: _.bind(this.after_screen_change, this)
        });
    },

    back_target: function () {
        if (this.screen === 'story') return 'titles';
        if (this.screen === 'titles') return this.titles_parent || 'feeds';
        return 'feeds';
    },

    // reader.js hide_splash_page: a story list opened. Slide it in unless it is already up.
    reader_opened: function () {
        if (!this.active) return;
        this.update_titles_bar();
        if (this.screen === 'titles') return;
        if (this.screen === 'story') {
            this.story_pager.close();
            this.set_screen('titles');
            return;
        }
        this.titles_parent = this.screen === 'dashboard' ? 'dashboard' : 'feeds';
        this.expect_entry('titles');
        this.show_screen('titles', { direction: 'push' });
    },

    // Most story lists navigate the router right after showing, which tags the new entry. The
    // ones that don't (silent opens, the same URL) still need an entry for back to pop.
    expect_entry: function (screen) {
        this.pending_entry = screen;
        _.defer(_.bind(function () {
            if (this.pending_entry !== screen) return;
            this.pending_entry = null;
            this.push_entry(screen);
        }, this));
    },

    // reader.js show_splash_page: the reader closed its story list (Esc, a deleted feed).
    splash_shown: function () {
        if (!this.active) return;
        this.story_pager.close();
        if (this.screen === 'feeds') return;
        this.show_screen('feeds', { direction: 'pop' });
    },

    // reader.js reset_feed: the stories under an open story screen are gone.
    feed_reset: function () {
        if (!this.active || this.screen !== 'story') return;
        this.story_pager.close();
        this.set_screen('titles');
        this.tag_entry('titles', this.depth);
    },

    open_dashboard: function () {
        if (!this.active) return false;
        if (this.screen === 'dashboard') return true;
        this.push_entry('dashboard');
        this.show_screen('dashboard', { direction: 'push' });
        return true;
    },

    // story_title_view.js: tapping a grid card pushes the full-screen story.
    open_story: function (story) {
        if (!this.active || !story) return;
        this.story_pager.open(story);
        if (this.screen === 'story') {
            this.tag_entry('story', this.depth, story.get('story_hash'));
            return;
        }
        this.push_entry('story', story.get('story_hash'));
        this.show_screen('story', { direction: 'push' });
    },

    // views/mobile_story_pager_view.js: paging to another story rewrites the story entry so
    // forward/back return to the story you were on.
    story_paged: function (story) {
        if (!this.active || this.screen !== 'story') return;
        this.tag_entry('story', this.depth, story.get('story_hash'));
    },

    // ===============
    // = Nav bars    =
    // ===============

    make_back_button: function () {
        return $.make('div', { className: 'NB-mobile-bar-back', role: 'button' }, [
            $.make('div', { className: 'NB-mobile-bar-back-icon' }),
            $.make('div', { className: 'NB-mobile-bar-back-label' })
        ]);
    },

    build_titles_bar: function () {
        this.$titles_bar = $.make('div', { className: 'NB-mobile-bar NB-mobile-titles-bar' }, [
            this.make_back_button(),
            $.make('div', { className: 'NB-mobile-bar-title' }, [
                $.make('span', { className: 'NB-mobile-bar-favicon' }),
                $.make('span', { className: 'NB-mobile-bar-title-text', dir: 'auto' })
            ]),
            $.make('div', { className: 'NB-mobile-bar-actions' }, [
                $.make('div', { className: 'NB-mobile-bar-button NB-mobile-layout-toggle', role: 'button' }, [
                    $.make('div', { className: 'NB-mobile-icon' })
                ])
            ])
        ]);
        this.$titles_bar.on('click', '.NB-mobile-bar-back', _.bind(function () {
            this.go_back();
        }, this));
        this.$titles_bar.on('click', '.NB-mobile-layout-toggle', _.bind(this.toggle_layout, this));
        this.$screens.titles.prepend(this.$titles_bar);
    },

    build_dashboard_bar: function () {
        this.$dashboard_bar = $.make('div', { className: 'NB-mobile-bar NB-mobile-dashboard-bar' }, [
            this.make_back_button(),
            $.make('div', { className: 'NB-mobile-bar-title' }, [
                $.make('span', { className: 'NB-mobile-bar-title-text' }, gettext('Dashboard'))
            ]),
            $.make('div', { className: 'NB-mobile-bar-actions' })
        ]);
        this.$dashboard_bar.find('.NB-mobile-bar-back-label').text(gettext('Feeds'));
        this.$dashboard_bar.on('click', '.NB-mobile-bar-back', _.bind(function () {
            this.go_back();
        }, this));
        this.$screens.dashboard.prepend(this.$dashboard_bar);
    },

    update_titles_bar: function () {
        if (!this.$titles_bar) return;
        var feed_id = NEWSBLUR.reader.active_feed;
        var title = feed_id && NEWSBLUR.reader.feed_title(feed_id);
        this.$titles_bar.find('.NB-mobile-bar-title-text').text(title || '');
        var $favicon = this.$titles_bar.find('.NB-mobile-bar-favicon').empty();
        if (feed_id) {
            $favicon.html($.favicon_html(feed_id));
        }
        var back_label = this.titles_parent === 'dashboard' ? gettext('Dashboard') : gettext('Feeds');
        this.$titles_bar.find('.NB-mobile-bar-back-label').text(back_label);

        var layout = feed_id && NEWSBLUR.assets.view_setting(feed_id, 'layout');
        this.$titles_bar.find('.NB-mobile-layout-toggle')
            .toggleClass('NB-hidden', !feed_id || !!NEWSBLUR.reader.flags.briefing_view)
            .attr('aria-label', layout === 'grid' ? gettext('List') : gettext('Grid'))
            .find('.NB-mobile-icon')
            .removeClass('NB-mobile-icon-list NB-mobile-icon-grid')
            .addClass(layout === 'grid' ? 'NB-mobile-icon-list' : 'NB-mobile-icon-grid');
    },

    // List expands stories inline, grid pushes them full screen. The choice is the feed's own
    // layout setting, so it follows the feed back to desktop.
    toggle_layout: function () {
        var feed_id = NEWSBLUR.reader.active_feed;
        if (!feed_id) return;
        var layout = NEWSBLUR.assets.view_setting(feed_id, 'layout') === 'grid' ? 'list' : 'grid';
        if (NEWSBLUR.reader.active_story) {
            NEWSBLUR.reader.active_story.set('selected', false);
        }
        NEWSBLUR.reader.switch_story_layout(layout);
        this.update_titles_bar();
    },

    // =================
    // = Edge swipe    =
    // =================

    is_overlay_open: function () {
        return ($.modal && $.modal.impl && _.keys($.modal.impl.d).length) ||
            (NEWSBLUR.ReaderPopover && NEWSBLUR.ReaderPopover.is_open()) ||
            this.$body.hasClass('NB-mobile-sheet-open');
    },

    is_edge_touch: function (x) {
        if (NEWSBLUR.utils.is_rtl()) {
            return x >= window.innerWidth - this.EDGE_WIDTH;
        }
        return x <= this.EDGE_WIDTH;
    },

    handle_touchstart: function (e) {
        this.swipe = null;
        if (!this.active || this.transition || e.touches.length !== 1) return;
        if (this.screen === 'feeds' || this.is_overlay_open()) return;
        var touch = e.touches[0];
        if (!this.is_edge_touch(touch.clientX)) return;
        this.swipe = {
            start_x: touch.clientX,
            start_y: touch.clientY,
            axis: null,
            dx: 0,
            samples: [{ x: touch.clientX, t: e.timeStamp }]
        };
    },

    handle_touchmove: function (e) {
        var swipe = this.swipe;
        if (!swipe) return;
        var touch = e.touches[0];
        var direction = NEWSBLUR.utils.is_rtl() ? -1 : 1;
        var dx = (touch.clientX - swipe.start_x) * direction;
        var dy = touch.clientY - swipe.start_y;
        if (!swipe.axis) {
            swipe.axis = this.utils.gesture_axis(dx, dy);
            if (!swipe.axis) return;
            if (swipe.axis !== 'horizontal' || dx <= 0) {
                this.swipe = null;
                return;
            }
            this.begin_drag();
        }
        e.preventDefault();
        swipe.dx = Math.max(0, dx);
        swipe.samples.push({ x: touch.clientX, t: e.timeStamp });
        if (swipe.samples.length > 5) swipe.samples.shift();
        this.render_drag(swipe.dx);
    },

    handle_touchend: function (e) {
        var swipe = this.swipe;
        this.swipe = null;
        if (!swipe || !swipe.dragging) return;
        var first = swipe.samples[0];
        var last = swipe.samples[swipe.samples.length - 1];
        var direction = NEWSBLUR.utils.is_rtl() ? -1 : 1;
        var elapsed = Math.max(1, last.t - first.t);
        var velocity = ((last.x - first.x) * direction) / elapsed;
        if (this.utils.swipe_completes(swipe.dx, velocity, window.innerWidth)) {
            this.go_back({ from_drag: true });
        } else {
            this.cancel_drag();
        }
    },

    begin_drag: function () {
        this.swipe.dragging = true;
        this.swipe.$top = this.$screens[this.screen];
        this.swipe.$under = this.$screens[this.back_target()];
        this.swipe.$under.removeClass('NB-mobile-pos-right').addClass('NB-mobile-pos-left');
        this.swipe.$top.add(this.swipe.$under).addClass('NB-mobile-dragging');
        this.$body.addClass('NB-mobile-transitioning');
    },

    render_drag: function (dx) {
        var width = window.innerWidth;
        var direction = NEWSBLUR.utils.is_rtl() ? -1 : 1;
        var progress = Math.min(1, dx / width);
        this.swipe.$top.css('transform', 'translate3d(' + (dx * direction) + 'px, 0, 0)');
        this.swipe.$under.css('transform',
            'translate3d(' + (-28 * (1 - progress) * direction) + '%, 0, 0)');
        this.swipe.$under[0].style.setProperty('--nb-mobile-shade-opacity', 1 - progress);
    },

    clear_drag_styles: function ($screens) {
        $screens.each(function () {
            this.style.transform = '';
            this.style.removeProperty('--nb-mobile-shade-opacity');
        });
    },

    cancel_drag: function () {
        var $top = this.$screens[this.screen];
        var $under = this.$screens[this.back_target()];
        var $both = $top.add($under);
        $both.removeClass('NB-mobile-dragging').addClass('NB-mobile-animating');
        this.clear_drag_styles($both);
        var self = this;
        setTimeout(function () {
            $both.removeClass('NB-mobile-animating');
            if (self.screen !== self.back_target()) {
                $under.removeClass('NB-mobile-pos-left');
            }
            self.$body.removeClass('NB-mobile-transitioning');
        }, this.transition_duration() + 40);
    },

    // ===================
    // = Long press      =
    // ===================

    // iOS Safari never fires contextmenu, so a held finger on a feed, folder or story opens the
    // same manage menu a right-click does on desktop.
    setup_long_press: function () {
        var selector = '.NB-feedlist .feed, .NB-feedlist .folder_title, .NB-story-title, ' +
            '.NB-feed-story-header';
        this.$body.on('touchstart.mobile_long_press', selector, this.handle_long_press_start);
        this.$body.on('touchmove.mobile_long_press touchend.mobile_long_press ' +
            'touchcancel.mobile_long_press', this.handle_long_press_cancel);
        document.addEventListener('click', this.handle_long_press_click, true);
        document.addEventListener('contextmenu', _.bind(function (e) {
            if (this.active && this.long_press_fired) e.preventDefault();
        }, this), true);
    },

    handle_long_press_start: function (e) {
        if (!this.active || e.originalEvent.touches.length !== 1) return;
        var touch = e.originalEvent.touches[0];
        var $target = $(e.currentTarget);
        this.long_press_fired = false;
        this.long_press_origin = { x: touch.clientX, y: touch.clientY };
        clearTimeout(this.long_press_timer);
        this.long_press_timer = setTimeout(_.bind(function () {
            this.long_press_fired = true;
            if (navigator.vibrate) navigator.vibrate(10);
            this.open_manage_menu_for($target);
        }, this), this.LONG_PRESS_MS);
    },

    handle_long_press_cancel: function (e) {
        if (!this.long_press_timer) return;
        if (e.type === 'touchmove') {
            var touch = e.originalEvent.touches[0];
            var origin = this.long_press_origin;
            if (origin && Math.abs(touch.clientX - origin.x) < 10 && Math.abs(touch.clientY - origin.y) < 10) {
                return;
            }
        }
        clearTimeout(this.long_press_timer);
        this.long_press_timer = null;
    },

    // The click that follows a long press would open the feed or story underneath the menu.
    handle_long_press_click: function (e) {
        if (!this.long_press_fired) return;
        this.long_press_fired = false;
        e.preventDefault();
        e.stopPropagation();
    },

    // The feed, folder and story views already open their manage menu on contextmenu. The
    // mobile_long_press flag lets them skip the desktop show_contextmenus preference.
    open_manage_menu_for: function ($target) {
        $target.trigger($.Event('contextmenu', { mobile_long_press: true }));
    }

});
