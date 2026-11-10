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
    BROWSER_SWIPE_MS: 8000,
    PRESS_DELAY_MS: 120,
    PRESS_FLASH_MS: 160,
    PILLS_PENDING_MS: 4000,

    initialize: function () {
        _.bindAll(this, 'check_mode', 'handle_popstate', 'handle_touchstart', 'handle_touchmove',
            'handle_touchend', 'handle_touchcancel', 'handle_long_press_start', 'handle_long_press_cancel',
            'handle_long_press_click', 'fit_pills', 'handle_search_close', 'update_titles_actions',
            'handle_story_button', 'handle_sheet_touchstart', 'handle_sheet_touchmove', 'handle_sheet_touchend',
            'measure_browser_chrome', 'scroll_page_to_top', 'sync_page_scroll', 'handle_page_scroll',
            'skip_toolbar_resize');
        this.utils = NEWSBLUR.mobile_utils;
        this.active = false;
        this.screen = null;
        this.depth = 0;
        // The screen and history depth beneath each pushed screen (common/mobile_utils.js
        // back_steps), so back skips same-screen entries like a search or the next feed.
        this.titles_parent = 'feeds';
        this.titles_parent_depth = 0;
        this.dashboard_parent_depth = 0;
        this.story_parent_depth = 0;
        this.pending_entry = null;
        this.transition = null;
        this.following_unread = null;
        this.awaiting_story = null;
        this.$pressed = null;
        // The screen whose list the page is scrolling in place of, if any (Page scroll below).
        this.page_scroll_screen = null;

        this.$body = $('body');
        this.$screens = {
            feeds: $('.NB-layout .left-pane'),
            dashboard: $('#NB-splash'),
            titles: $('.NB-layout .right-pane')
        };
        this.story_pager = new NEWSBLUR.Views.MobileStoryPager({ mobile: this });
        this.$screens.story = this.story_pager.$el;
        this.$body.append(this.story_pager.$el);

        NEWSBLUR.assets.stories.bind('change:selected', this.story_selected, this);
        NEWSBLUR.assets.stories.bind('reset', this.stories_reset, this);

        this.build_titles_bar();
        this.build_dashboard_bar();
        // mobile.css dims the page behind bottom-sheet menus with this.
        this.$body.append($.make('div', { className: 'NB-mobile-sheet-shade' }));
        this.wrap_history();

        this.media_query = window.matchMedia(this.utils.MEDIA_QUERY);
        if (this.media_query.addEventListener) {
            this.media_query.addEventListener('change', this.check_mode);
        } else {
            this.media_query.addListener(this.check_mode);
        }
        window.addEventListener('popstate', this.handle_popstate);
        // Capture runs ahead of every other resize listener, jquery.layout's included.
        this.resize_width = window.innerWidth;
        window.addEventListener('resize', this.skip_toolbar_resize, true);
        window.addEventListener('resize', _.debounce(this.fit_pills, 100));
        window.addEventListener('resize', this.measure_browser_chrome);
        window.addEventListener('scroll', this.scroll_page_to_top, { passive: true });
        window.addEventListener('scroll', this.handle_page_scroll, { passive: true });
        document.addEventListener('focusout', function () {
            _.defer(this.scroll_page_to_top);
        }.bind(this));
        document.addEventListener('touchstart', this.handle_touchstart, { passive: true });
        document.addEventListener('touchstart', this.handle_sheet_touchstart, { passive: true });
        document.addEventListener('touchmove', this.handle_sheet_touchmove, { passive: false });
        document.addEventListener('touchend', this.handle_sheet_touchend, { passive: true });
        document.addEventListener('touchcancel', this.handle_sheet_touchend, { passive: true });
        document.addEventListener('touchmove', this.handle_touchmove, { passive: false });
        document.addEventListener('touchend', this.handle_touchend, { passive: true });
        document.addEventListener('touchcancel', this.handle_touchcancel, { passive: true });
        this.setup_long_press();
        this.setup_sheet_edits();
        this.setup_pull_to_refresh();
        this.setup_player();
        this.setup_page_scroll();
        this.setup_sideoption_sheets();

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
        // templates/reader/dashboard.xhtml hid the page until the layout knew which it would be.
        this.$body.removeClass('NB-mobile-booting');
    },

    activate: function () {
        this.active = true;
        NEWSBLUR.reader.flags.mobile = true;
        this.$body.addClass('NB-mobile');
        this.measure_browser_chrome();
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
        this.restore_parent(entry);
        this.set_screen(screen);
        this.tag_entry(screen);
        this.update_titles_bar();
        this.refresh_story_layout();
        this.dock_player(true);
        this.sync_page_scroll();
    },

    deactivate: function () {
        this.finish_transition();
        this.leave_page_scroll();
        this.story_pager.close();
        this.active = false;
        NEWSBLUR.reader.flags.mobile = false;
        this.close_sideoption_sheet();
        this.$body.removeClass('NB-mobile NB-mobile-transitioning NB-mobile-sheet-open');
        this.$body.removeClass(this.screen_body_classes());
        this.measure_browser_chrome();
        _.each(this.$screens, function ($screen) {
            $screen.removeClass('NB-mobile-screen NB-mobile-pos-center NB-mobile-pos-left ' +
                'NB-mobile-pos-right NB-mobile-animating NB-mobile-dragging');
            $screen.css({ transform: '' });
            $screen[0].style.removeProperty('--nb-mobile-shade-opacity');
        });
        this.screen = null;
        this.dock_player(false);
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

    // The open story list's phone layout: list, page or grid (common/mobile_utils.js).
    layout: function () {
        if (!this.active || !NEWSBLUR.reader.active_feed) return null;
        return NEWSBLUR.assets.phone_layout(NEWSBLUR.reader.active_feed);
    },

    // Grid cards and full-screen lists open stories on the story screen instead of in the list.
    opens_story_page: function () {
        return _.contains(['page', 'grid'], this.layout());
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
        this.close_sideoption_sheet();
        this.clear_drag();
        this.screen = screen;
        this.$body.removeClass(this.screen_body_classes()).addClass('NB-mobile-screen-is-' + screen);
        _.each(this.$screens, function ($screen, name) {
            $screen.removeClass('NB-mobile-pos-left NB-mobile-pos-right NB-mobile-animating')
                .toggleClass('NB-mobile-pos-center', name === screen);
        });
        this.sync_page_scroll();
    },

    // Slides between screens. A push brings the new screen in from the trailing edge over the
    // old one, a pop slides the current screen away to reveal the one beneath.
    show_screen: function (screen, options) {
        options = options || {};
        var from = this.screen;
        if (!this.active || from === screen) {
            this.clear_drag();
            if (options.complete) options.complete();
            return;
        }
        if (!from || options.direction === 'none' || options.animate === false || !this.transition_duration()) {
            this.set_screen(screen);
            if (options.complete) options.complete();
            return;
        }
        this.finish_transition();
        this.close_sideoption_sheet();
        // Both screens slide as fixed, window-sized boxes.
        this.leave_page_scroll();

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
            self.sync_page_scroll();
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

    // A screen change that lands mid edge-swipe drops the swipe. Its inline transforms and the
    // NB-mobile-transitioning class, which blocks taps in mobile.css, would otherwise stay.
    clear_drag: function () {
        this.swipe = null;
        var $dragged = $('.NB-mobile-screen.NB-mobile-dragging');
        if (!$dragged.length) return;
        $dragged.removeClass('NB-mobile-dragging');
        this.clear_drag_styles($dragged);
        if (!this.transition) this.$body.removeClass('NB-mobile-transitioning');
    },

    transition_duration: function () {
        var duration = parseFloat(getComputedStyle(document.body).getPropertyValue('--nb-mobile-duration'));
        return NEWSBLUR.motion.duration(_.isNaN(duration) ? 380 : duration);
    },

    // ============
    // = History  =
    // ============

    make_entry: function (screen, story_hash) {
        var entry = { screen: screen, depth: this.depth, story_hash: story_hash };
        if (screen === 'titles') {
            entry.parent_depth = this.titles_parent_depth;
            entry.parent_screen = this.titles_parent;
        } else if (screen === 'story') {
            entry.parent_depth = this.story_parent_depth;
            entry.parent_screen = 'titles';
        } else if (screen === 'dashboard') {
            entry.parent_depth = this.dashboard_parent_depth;
            entry.parent_screen = 'feeds';
        }
        return entry;
    },

    // Popstate and reloads land on entries written earlier; take their parents back.
    restore_parent: function (entry) {
        if (!entry.tagged || entry.parent_depth === null) return;
        if (entry.screen === 'titles') {
            this.titles_parent_depth = entry.parent_depth;
            this.titles_parent = entry.parent_screen || 'feeds';
        } else if (entry.screen === 'story') {
            this.story_parent_depth = entry.parent_depth;
        } else if (entry.screen === 'dashboard') {
            this.dashboard_parent_depth = entry.parent_depth;
        }
    },

    tag_entry: function (screen, story_hash) {
        var state = this.utils.make_history_state(window.history.state, this.make_entry(screen, story_hash));
        this.replace_state.call(window.history, state, document.title, window.location.href);
    },

    // Pushes a deeper screen, which sits on top of the entry we are leaving.
    push_entry: function (screen, story_hash) {
        if (screen === 'story') this.story_parent_depth = this.depth;
        if (screen === 'dashboard') this.dashboard_parent_depth = this.depth;
        this.depth += 1;
        var state = this.utils.make_history_state({}, this.make_entry(screen, story_hash));
        this.push_state.call(window.history, state, document.title, window.location.href);
    },

    // The router, search and classifier filters all write history entries of their own. Tag
    // each one with the screen it belongs to so popstate knows where to slide back to and the
    // back button knows how far the screen beneath is.
    wrap_history: function () {
        var self = this;
        this.push_state = window.history.pushState;
        this.replace_state = window.history.replaceState;
        var path_of = function (url) {
            return url ? new URL(url, window.location.href).pathname : window.location.pathname;
        };
        window.history.pushState = function (state, title, url) {
            if (self.active) {
                var screen = self.pending_entry || self.utils.screen_for_path(path_of(url));
                self.pending_entry = null;
                self.depth += 1;
                state = self.utils.make_history_state(state, self.make_entry(screen));
            }
            return self.push_state.call(window.history, state, title, url);
        };
        window.history.replaceState = function (state, title, url) {
            if (self.active) {
                var current = self.utils.read_history_state(window.history.state, window.location.pathname);
                var screen = self.pending_entry ||
                    (current.tagged ? current.screen : self.utils.screen_for_path(path_of(url)));
                self.pending_entry = null;
                state = self.utils.make_history_state(state, self.make_entry(screen, current.story_hash));
            }
            return self.replace_state.call(window.history, state, title, url);
        };
    },

    handle_popstate: function (e) {
        if (!this.active) return;
        var target = this.utils.read_history_state(e.state, window.location.pathname);
        var from = { screen: this.screen, depth: this.depth, story_hash: this.story_pager.story_hash() };
        var direction = this.utils.transition_direction(from, target);
        if (!target.tagged) {
            target.depth = direction === 'pop' ? Math.max(0, this.depth - 1) : this.depth + 1;
            this.depth = target.depth;
            this.tag_entry(target.screen);
        }
        this.depth = target.depth;
        this.restore_parent(target);
        this.update_titles_bar();

        var screen = target.screen;
        this.awaiting_story = null;
        clearTimeout(this.awaiting_story_timer);
        if (screen === 'story') {
            var story = target.story_hash && NEWSBLUR.assets.stories.get_by_story_hash(target.story_hash);
            if (story) {
                this.story_pager.open(story);
            } else if (target.story_hash && this.router_will_route()) {
                // The entry belongs to another feed (Next unread crossed into this one), which the
                // router opens once this handler returns. stories_reset opens the story then.
                this.awaiting_story = target.story_hash;
                this.awaiting_story_timer = setTimeout(_.bind(this.stories_failed, this), 15000);
                this.story_pager.show_loading(gettext('Loading...'));
            } else {
                screen = 'titles';
            }
        }
        if (screen === 'titles' && !NEWSBLUR.reader.active_feed) {
            screen = 'feeds';
        }

        // Only an edge swipe leaves the screens mid-slide; the header button starts from rest.
        var from_drag = !!(this.pending_back && this.pending_back.from_drag);
        var browser_swiped = this.browser_swiped();
        this.browser_edge_touch_at = null;
        this.pending_back = null;
        clearTimeout(this.pending_back_timer);
        this.show_screen(screen, {
            direction: direction === 'none' ? 'pop' : direction,
            // The browser already animated its own swipe-back, don't slide a second time.
            animate: !e.hasUAVisualTransition && !browser_swiped,
            from_drag: from_drag,
            complete: _.bind(this.after_screen_change, this)
        });
    },

    // Backbone's popstate listener runs after handle_popstate, which was added first, so a
    // fragment that differs from the router's last one is a route it's about to open.
    router_will_route: function () {
        return !!Backbone.History.started &&
            Backbone.history.getFragment() !== Backbone.history.fragment;
    },

    // NEWSBLUR.assets.stories reset: a story list finished loading. reader.js reset_feed empties
    // the collection with a bare reset first, which passes no count of added stories.
    stories_reset: function (stories, options) {
        var loaded = !!options && options.added !== undefined;
        // Another list is opening, as when a related story is tapped in its sheet.
        if (!loaded) this.close_sideoption_sheet();
        this.set_pills_pending(!loaded);
        if (!this.awaiting_story || !loaded) return;
        var story_hash = this.awaiting_story;
        this.awaiting_story = null;
        clearTimeout(this.awaiting_story_timer);
        if (!this.active || this.screen !== 'story') return;
        var story = NEWSBLUR.assets.stories.get_by_story_hash(story_hash);
        if (story) {
            this.story_pager.open(story);
            return;
        }
        // The story has dropped off the feed's first page, so show the list it was in.
        this.show_list_for_story();
    },

    // reader_taskbar_info.js show_stories_error: the story list failed to load. A story waiting
    // on it gives up after 15 seconds too, offline requests can take that long to fail, and so
    // does a Next unread waiting on the next feed's list.
    stories_failed: function () {
        this.set_pills_pending(false);
        var waiting = !!this.awaiting_story || this.is_following_unread();
        this.awaiting_story = null;
        this.following_unread = null;
        clearTimeout(this.awaiting_story_timer);
        clearTimeout(this.following_unread_timer);
        if (!waiting || !this.active || this.screen !== 'story') return;
        this.show_list_for_story();
    },

    // The list shows the story list's own error or its stories, under an entry retagged to match.
    show_list_for_story: function () {
        this.story_pager.close();
        this.tag_entry('titles');
        this.show_screen('titles', { direction: 'pop', complete: _.bind(this.after_screen_change, this) });
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

    // Header back button and edge swipe. Walk back through history to the screen beneath when
    // its entry is ours, otherwise (a deep link or reload) move up a level and rewrite this entry.
    go_back: function (options) {
        options = options || {};
        if (!this.active || this.screen === 'feeds') return;
        var entry = this.utils.read_history_state(window.history.state, window.location.pathname);
        var steps = this.utils.back_steps(entry);
        if (steps > 0) {
            this.pending_back = options;
            window.history.go(-steps);
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
        this.tag_entry(parent);
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
            if (this.is_following_unread()) {
                this.story_pager.show_loading(gettext('Loading the next unread story...'));
                return;
            }
            if (this.awaiting_story) return;
            this.story_pager.close();
            this.set_screen('titles');
            return;
        }
        this.titles_parent = this.screen === 'dashboard' ? 'dashboard' : 'feeds';
        this.titles_parent_depth = this.depth;
        // A Previous or Next unread that selected nothing doesn't carry over to a new list.
        this.open_on_select = null;
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
        if (this.is_following_unread()) {
            this.story_pager.show_loading(gettext('Loading the next unread story...'));
            return;
        }
        if (this.awaiting_story) return;
        this.story_pager.close();
        this.set_screen('titles');
        this.tag_entry('titles');
    },

    open_dashboard: function () {
        if (!this.active) return false;
        if (this.screen === 'dashboard') return true;
        this.push_entry('dashboard');
        this.show_screen('dashboard', { direction: 'push' });
        return true;
    },

    // story_title_view.js: tapping a grid card pushes the full-screen story, and tapping its
    // share count opens it at the comments.
    open_story: function (story, options) {
        if (!this.active || !story) return;
        this.story_pager.open(story);
        if (options && options.scroll_to_comments) {
            _.defer(_.bind(this.story_pager.scroll_to_comments, this.story_pager));
        }
        if (this.screen === 'story') {
            this.tag_entry('story', story.get('story_hash'));
            return;
        }
        this.push_entry('story', story.get('story_hash'));
        this.show_screen('story', { direction: 'push' });
    },

    // reader.js select_story_in_feed: a specific story was asked for, from the dashboard or a
    // link. A grid shows it on the story screen; a list has already expanded it in place.
    story_requested: function (story) {
        if (!this.active || !this.opens_story_page() || this.screen === 'story') return;
        this.open_story(story);
    },

    // views/mobile_story_pager_view.js: Next unread ran out of unread stories in this list, so
    // reader.js show_next_unread_story is loading more or moving on to the next feed. Keep the
    // story screen up until that next unread story is selected.
    follow_next_unread: function () {
        this.following_unread = Date.now();
        clearTimeout(this.following_unread_timer);
        this.following_unread_timer = setTimeout(_.bind(this.next_unread_timed_out, this), 20000);
    },

    // Nothing was selected in time. The story screen is only left when it is still showing the
    // loading message, not a story Next unread came back to.
    next_unread_timed_out: function () {
        if (!this.following_unread) return;
        this.following_unread = null;
        if (!this.active || this.screen !== 'story' || this.story_pager.story) return;
        this.show_list_for_story();
    },

    is_following_unread: function () {
        return !!this.following_unread && Date.now() - this.following_unread < 20000;
    },

    story_selected: function (story, selected) {
        if (!this.active || !selected) return;
        // handle_story_button: Next unread may load the next feed first, hence the long wait.
        var open_on_select = this.open_on_select && Date.now() - this.open_on_select < 20000;
        this.open_on_select = null;
        if (open_on_select && this.screen === 'titles' && this.opens_story_page()) {
            this.open_story(story);
            return;
        }
        if (!this.is_following_unread()) return;
        this.following_unread = null;
        clearTimeout(this.following_unread_timer);
        if (this.screen !== 'story') return;
        // Reading continues on the story screen even when the next feed is a list, whose own
        // list expands the same story underneath for when you go back.
        var entry = this.utils.read_history_state(window.history.state, window.location.pathname);
        this.story_pager.open(story);
        if (entry.screen === 'story') {
            this.tag_entry('story', story.get('story_hash'));
        } else {
            this.push_entry('story', story.get('story_hash'));
        }
    },

    // views/mobile_story_pager_view.js: paging to another story rewrites the story entry so
    // forward/back return to the story you were on.
    story_paged: function (story) {
        if (!this.active || this.screen !== 'story') return;
        this.tag_entry('story', story.get('story_hash'));
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
                $.make('div', {
                    className: 'NB-mobile-bar-button NB-mobile-mark-read',
                    role: 'button',
                    'aria-label': gettext('Mark as read')
                }, [
                    $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-markread' })
                ]),
                $.make('div', { className: 'NB-mobile-bar-button NB-mobile-layout-toggle', role: 'button' }, [
                    $.make('div', { className: 'NB-mobile-icon' })
                ])
            ])
        ]);
        this.$titles_bar.on('click', '.NB-mobile-bar-back', _.bind(function () {
            this.go_back();
        }, this));
        this.$titles_bar.on('click', '.NB-mobile-layout-toggle', _.bind(this.open_layout_menu, this));
        this.$titles_bar.on('click', '.NB-mobile-mark-read', _.bind(this.open_mark_read_menu, this));
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
        // The story list's own controls render right after this.
        _.defer(this.update_titles_actions);
        var feed_id = NEWSBLUR.reader.active_feed;
        var title = feed_id && NEWSBLUR.reader.feed_title(feed_id);
        this.$titles_bar.find('.NB-mobile-bar-title-text').text(title || '');
        var $favicon = this.$titles_bar.find('.NB-mobile-bar-favicon').empty();
        if (feed_id === 'add-site') {
            // jquery.newsblur.js $.favicon knows feeds, rivers and the saved, read and archive
            // lists, but Add + Discover is a view of its own, so it gets the sidebar's add icon.
            $favicon.html($.make('img', {
                className: 'feed_favicon',
                src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/add.svg'
            }));
        } else if (feed_id) {
            $favicon.html($.favicon_html(feed_id));
        }
        var back_label = this.titles_parent === 'dashboard' ? gettext('Dashboard') : gettext('Feeds');
        this.$titles_bar.find('.NB-mobile-bar-back-label').text(back_label);

        this.$titles_bar.find('.NB-mobile-layout-toggle')
            .toggleClass('NB-hidden', !feed_id || !!NEWSBLUR.reader.flags.briefing_view)
            .attr('aria-label', gettext('Layout'))
            .find('.NB-mobile-icon')
            .removeClass('NB-mobile-icon-layout-list NB-mobile-icon-layout-page NB-mobile-icon-layout-grid')
            .addClass('NB-mobile-icon-layout-' + (this.layout() || 'list'));
        // mobile.css shows the bar's Previous and Next unread only in an inline list.
        this.$screens.titles.removeClass('NB-mobile-layout-list NB-mobile-layout-page NB-mobile-layout-grid')
            .addClass('NB-mobile-layout-' + (this.layout() || 'list'));
    },

    // views/mobile_layout_popover.js: the layout button opens a menu of the three phone layouts.
    open_layout_menu: function () {
        if (!NEWSBLUR.reader.active_feed) return;
        NEWSBLUR.MobileLayoutPopover.create({ anchor: this.$titles_bar.find('.NB-mobile-layout-toggle') });
    },

    // The choice is the feed's own desktop layout (assetmodel.js save_phone_layout), so it follows
    // the feed back to desktop. A full-screen list renders the same rows as an inline one, so the
    // list re-renders either way to drop a story expanded in place.
    set_layout: function (phone_layout) {
        var feed_id = NEWSBLUR.reader.active_feed;
        if (!feed_id || this.layout() === phone_layout) return;
        if (NEWSBLUR.reader.active_story) {
            NEWSBLUR.reader.active_story.set('selected', false);
        }
        NEWSBLUR.assets.save_phone_layout(feed_id, phone_layout);
        NEWSBLUR.reader.switch_story_layout(NEWSBLUR.assets.view_setting(feed_id, 'layout'), true);
        this.update_titles_bar();
    },

    // =================
    // = Edge swipe    =
    // =================

    is_overlay_open: function () {
        return ($.modal && $.modal.impl && _.keys($.modal.impl.d).length) ||
            (NEWSBLUR.ReaderPopover && NEWSBLUR.ReaderPopover.is_open()) ||
            this.$body.hasClass('NB-mobile-sheet-open') ||
            !!this.sideoption ||
            this.$body.hasClass('NB-mobile-player-open');
    },

    is_edge_touch: function (x) {
        if (NEWSBLUR.utils.is_rtl()) {
            return x >= window.innerWidth - this.EDGE_WIDTH;
        }
        return x <= this.EDGE_WIDTH;
    },

    // iOS Safari and the other iOS browsers swipe back and forward from the screen's edges
    // themselves, sliding a snapshot of the page, so the layout's own edge swipe stands down
    // there or both run at once. A home screen web app has no browser gesture and keeps it.
    // navigator.standalone is iOS WebKit's, false in the browser and true from the home screen.
    browser_owns_edge_swipe: function () {
        return window.navigator.standalone === false;
    },

    // mobile.css (Under Safari's toolbar): iOS Safari draws a page beneath its floating toolbar
    // only where the page isn't position: fixed, so in its browser mode the screens hang below
    // the visible page by as much of the screen as lies beneath it, and lists scroll on under
    // the toolbar. Measured against the whole screen, which also counts the status bar above
    // the page, so the screens reach a little past the bottom of the glass, where no one sees.
    measure_browser_chrome: function () {
        // A screen the page scrolls for is in the page's flow, where the browser already draws it
        // under its toolbar.
        var under_chrome = this.active && this.browser_owns_edge_swipe() && !this.page_scroll_screen;
        var chrome_bottom = 0;
        if (under_chrome) {
            var screen_sides = [window.screen.width, window.screen.height];
            var landscape = window.innerWidth > window.innerHeight;
            var screen_height = landscape ? _.min(screen_sides) : _.max(screen_sides);
            chrome_bottom = Math.max(0, screen_height - window.innerHeight);
        }
        var style = this.$body[0].style;
        this.$body.toggleClass('NB-mobile-under-chrome', under_chrome);
        if (under_chrome) {
            style.setProperty('--nb-mobile-chrome-bottom', chrome_bottom + 'px');
            style.setProperty('--nb-mobile-screen-height', (window.innerHeight + chrome_bottom) + 'px');
        } else {
            style.removeProperty('--nb-mobile-chrome-bottom');
            style.removeProperty('--nb-mobile-screen-height');
        }
        this.measure_page_bars();
    },

    // The screens hanging under Safari's toolbar make the page taller than the window, so it
    // scrolls when something asks it to: Safari lifting a focused field above the keyboard, or
    // reader.js scrolling an element into view. Once nothing is being typed into, it goes back.
    scroll_page_to_top: function () {
        if (!this.$body.hasClass('NB-mobile-under-chrome')) return;
        if (!window.scrollX && !window.scrollY) return;
        if ($(document.activeElement).is('input, textarea, select, [contenteditable="true"]')) return;
        window.scrollTo(0, 0);
    },

    // ===============
    // = Page scroll =
    // ===============

    // mobile.css (Page scrolling): a phone browser shrinks its toolbar only when the page itself
    // scrolls. While the feed list, the story list or an open story is at rest, its screen is
    // laid out in the page's flow and the page scrolls in place of the list or story. Anything
    // that moves or covers the screen (a slide, an edge swipe, a swipe between stories, a sheet,
    // a modal, the player) puts it back in the fixed layout first, scrolled to where the page
    // was, and it returns to the page afterwards.
    page_scroller: function (screen) {
        if (screen === 'feeds') return this.$screens.feeds.find('.left-center-content')[0];
        if (screen === 'titles') return NEWSBLUR.reader.$s.$story_titles[0];
        // mobile_story_pager_view.js rotates its three pages, so this is whichever holds the story.
        if (screen === 'story') return this.story_pager.pages.current.$el[0];
        return null;
    },

    // Every element the page can scroll in place of.
    page_scrollers: function () {
        return [this.page_scroller('feeds'), this.page_scroller('titles')]
            .concat(_.map(this.story_pager.pages, function (page) { return page.$el[0]; }));
    },

    // Whether the page is scrolling in place of this list right now.
    page_scrolls: function (el) {
        return !!this.page_scroll_screen && !!el && this.page_scroller(this.page_scroll_screen) === el;
    },

    wants_page_scroll: function () {
        if (!this.active || this.transition || this.$body.hasClass('NB-mobile-transitioning')) return false;
        if (!_.contains(['feeds', 'titles', 'story'], this.screen) || this.is_overlay_open()) return false;
        // Add + Discover replaces the story list with tab panes that scroll themselves.
        if (this.screen === 'titles' && $('.NB-layout').hasClass('NB-add-site-active')) return false;
        if (this.screen === 'story' && !this.story_pager.can_page_scroll()) return false;
        return !!this.page_scroller(this.screen);
    },

    // Code all over the reader reads and sets these lists' scrollTop and listens for their
    // scroll (story_titles_view.js, mobile_pull_to_refresh.js, jQuery's scrollTo). While the
    // page scrolls for a list, its scrollTop is the page's, so that code keeps working.
    setup_page_scroll: function () {
        var self = this;
        var native_scroll_top = Object.getOwnPropertyDescriptor(Element.prototype, 'scrollTop');
        _.each(this.page_scrollers(), function (el) {
            if (!el) return;
            Object.defineProperty(el, 'scrollTop', {
                configurable: true,
                get: function () {
                    return self.page_scrolls(el) ? window.scrollY : native_scroll_top.get.call(el);
                },
                set: function (value) {
                    if (self.page_scrolls(el)) {
                        window.scrollTo({ top: value, left: 0, behavior: 'instant' });
                    } else {
                        native_scroll_top.set.call(el, value);
                    }
                }
            });
            // Capture runs first on the list itself, ahead of its jQuery listeners.
            el.addEventListener('scroll', function (e) {
                if (self.page_scroll_handoff) e.stopImmediatePropagation();
            }, true);
        });
        // jquery.scrollTo.js won't scroll a list past its own overflow, which a list the page
        // scrolls for doesn't have. Its limit there is the page's.
        var scroll_to_max = $.scrollTo.max;
        $.scrollTo.max = function (el, axis) {
            if (axis === 'y' && self.page_scrolls(el)) {
                return Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
            }
            return scroll_to_max.apply(this, arguments);
        };
        // Sheets, modals, the player and edge swipes mark the body or add themselves to it.
        var observer = new MutationObserver(this.sync_page_scroll);
        observer.observe(document.body, { attributes: true, attributeFilter: ['class'], childList: true });
        var layout = $('.NB-layout')[0];
        if (layout) observer.observe(layout, { attributes: true, attributeFilter: ['class'] });
    },

    sync_page_scroll: function () {
        var screen = this.wants_page_scroll() ? this.screen : null;
        if (screen === this.page_scroll_screen) return;
        this.leave_page_scroll();
        if (screen) this.enter_page_scroll(screen);
    },

    // Trading the scroll between the list and the page moves nothing on screen, but each side
    // reports a scroll of its own a frame later. Listeners that act on a scroll, like the feed
    // menu that closes when its list moves (reader.js show_manage_menu), must not hear those.
    hold_page_scroll_events: function () {
        var self = this;
        var token = this.page_scroll_handoff = {};
        var release = function () {
            if (self.page_scroll_handoff === token) self.page_scroll_handoff = null;
        };
        // Scroll events go out before a frame's animation callbacks, so the second frame is clear.
        window.requestAnimationFrame(function () {
            window.requestAnimationFrame(release);
        });
        setTimeout(release, 400);
    },

    enter_page_scroll: function (screen) {
        var top = this.page_scroller(screen).scrollTop;
        this.hold_page_scroll_events();
        this.page_scroll_screen = screen;
        this.$body.addClass('NB-mobile-page-scroll');
        this.measure_browser_chrome();
        this.measure_page_bars();
        window.scrollTo({ top: top, left: 0, behavior: 'instant' });
    },

    leave_page_scroll: function () {
        if (!this.page_scroll_screen) return;
        var el = this.page_scroller(this.page_scroll_screen);
        var top = window.scrollY;
        this.hold_page_scroll_events();
        this.page_scroll_screen = null;
        this.$body.removeClass('NB-mobile-page-scroll');
        this.measure_browser_chrome();
        el.scrollTop = top;
        window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
    },

    // The two bars stuck to the top of a screen the page scrolls for: its nav bar or account
    // header, then its bar of controls.
    page_bars: function () {
        if (this.page_scroll_screen === 'feeds') {
            return [this.$screens.feeds.children('.left-north')[0], this.$screens.feeds.children('.left-south')[0]];
        }
        if (this.page_scroll_screen === 'titles') {
            return [this.$titles_bar[0], this.$screens.titles.children('.content-north')[0]];
        }
        if (this.page_scroll_screen === 'story') {
            return [this.story_pager.$('.NB-mobile-story-bar')[0], this.story_pager.$('.NB-mobile-story-toolbar')[0]];
        }
        return [];
    },

    // mobile.css sticks the second bar this far down, under the first, and sizes what waits
    // beside the screen's content to the window under both.
    measure_page_bars: function () {
        var bars = this.page_bars();
        if (!bars[0]) return;
        var style = this.$body[0].style;
        style.setProperty('--nb-mobile-page-bar-top', bars[0].offsetHeight + 'px');
        style.setProperty('--nb-mobile-page-bars-height',
            (bars[0].offsetHeight + (bars[1] ? bars[1].offsetHeight : 0)) + 'px');
    },

    // How much of the window the list shows under its bars, which is what its own height was
    // while it scrolled itself.
    page_viewport_height: function () {
        var bars_height = _.reduce(this.page_bars(), function (sum, bar) {
            return sum + (bar ? bar.offsetHeight : 0);
        }, 0);
        return Math.max(0, window.innerHeight - bars_height);
    },

    // A phone browser's toolbar shrinks and returns as the page scrolls, and each time the window
    // gets taller or shorter and reports a resize. Nothing in a screen laid out in the page
    // depends on the window's height, but jquery.layout answers every resize by measuring and
    // rewriting all its panes (and reader.js resize_window after it), in the middle of the
    // scroll that caused it, which makes the scroll stutter. Only a change of width goes on.
    skip_toolbar_resize: function (e) {
        var width = window.innerWidth;
        var same_width = width === this.resize_width;
        this.resize_width = width;
        if (this.page_scroll_screen && same_width) e.stopImmediatePropagation();
    },

    // The list's own scroll listeners, jQuery's and native ones alike, hear the page's scroll.
    handle_page_scroll: function () {
        if (!this.page_scroll_screen || this.page_scroll_handoff) return;
        this.page_scroller(this.page_scroll_screen).dispatchEvent(new Event('scroll'));
    },

    is_browser_edge_touch: function (x) {
        return x <= this.EDGE_WIDTH || x >= window.innerWidth - this.EDGE_WIDTH;
    },

    // The browser's swipe cancels the page's touch instead of ending it, so a touch that began at
    // the edge and hasn't ended when popstate arrives is the browser's own swipe, which already
    // slid the screens. A tap on the nav bar's back button ends normally and keeps its slide. A
    // swipe let go of before it goes anywhere sends no popstate, so the touch only counts for long
    // enough to cover a slow swipe, or a later Back from the browser's toolbar would skip its
    // slide.
    browser_swiped: function () {
        return !!this.browser_edge_touch_at && Date.now() - this.browser_edge_touch_at < this.BROWSER_SWIPE_MS;
    },

    handle_touchstart: function (e) {
        this.swipe = null;
        this.browser_edge_touch_at = null;
        if (!this.active || e.touches.length !== 1) return;
        var touch = e.touches[0];
        var browser_edge = this.browser_owns_edge_swipe() && this.is_browser_edge_touch(touch.clientX);
        if (browser_edge) {
            this.browser_edge_touch_at = Date.now();
            return;
        }
        if (this.transition) return;
        if (this.screen === 'feeds' || this.is_overlay_open()) return;
        if ($(e.target).closest('.NB-media-player').length) return;
        // The story list and dashboard go back from a swipe anywhere on them, as in the iOS and
        // Android apps. The story screen's own swipe pages stories, so it goes back from the edge.
        // In an iOS browser the edges are the browser's own swipe, so only the rest is the layout's.
        var from_anywhere = _.contains(['titles', 'dashboard'], this.screen) && this.swipes_from_anywhere(e.target);
        if (this.browser_owns_edge_swipe() ? !from_anywhere : !(from_anywhere || this.is_edge_touch(touch.clientX))) return;
        this.swipe = {
            start_x: touch.clientX,
            start_y: touch.clientY,
            axis: null,
            dx: 0,
            samples: [{ x: touch.clientX, t: e.timeStamp }]
        };
    },

    // Anywhere except text fields, sliders and things that scroll sideways, such as a wide table
    // in a story opened inline or Add + Discover's tabs.
    swipes_from_anywhere: function (target) {
        if ($(target).closest('input, textarea, select, [contenteditable="true"]').length) return false;
        return !this.utils.inside_horizontal_scroller(target, document.body);
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
        this.browser_edge_touch_at = null;
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

    // iOS Safari cancels the page's touches when its own edge swipe-back takes over. That
    // gesture goes back by itself (popstate then switches screens), so only snap back here.
    handle_touchcancel: function () {
        var swipe = this.swipe;
        this.swipe = null;
        if (swipe && swipe.dragging) this.cancel_drag();
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
        var finish = function () {
            $both.removeClass('NB-mobile-animating');
            if (self.screen !== self.back_target()) {
                $under.removeClass('NB-mobile-pos-left');
            }
            self.$body.removeClass('NB-mobile-transitioning');
        };
        var duration = this.transition_duration();
        if (duration) setTimeout(finish, duration + 40);
        else finish();
    },

    // ===================
    // = Listen player   =
    // ===================

    // views/media_player_view.js docks the player in the feed list's footer. On a phone it floats
    // above every screen as a one-row bar (mobile.css), so audio started from a story keeps its
    // controls while you read, and tapping the bar opens the full player as a bottom sheet.
    setup_player: function () {
        this.$player = $('.NB-media-player').first();
        if (!this.$player.length) return;
        this.$player_home = this.$player.parent();
        this.$player_shade = $.make('div', { className: 'NB-mobile-player-shade' });
        this.$body.append(this.$player_shade);
        this.$player_shade.on('click', _.bind(this.collapse_player, this));

        // The player shows and hides itself with NB-hidden.
        var observer = new MutationObserver(_.bind(this.update_player_visibility, this));
        observer.observe(this.$player[0], { attributes: true, attributeFilter: ['class'] });

        // Tapping the collapsed bar anywhere but play/pause, Next story or close expands it. In
        // the sheet, a tap on its top edge (the grab handle) collapses it again.
        this.$player[0].addEventListener('click', _.bind(function (e) {
            if (!this.active) return;
            var expanded = this.$player.hasClass('NB-mobile-player-expanded');
            if (!expanded && !$(e.target).closest('.NB-media-player-play-pause, .NB-media-player-next, .NB-media-player-close').length) {
                e.preventDefault();
                e.stopPropagation();
                this.expand_player();
            } else if (expanded && e.target === this.$player[0]) {
                this.collapse_player();
            }
        }, this), true);
    },

    dock_player: function (mobile) {
        if (!this.$player || !this.$player.length) return;
        if (mobile) {
            this.$body.append(this.$player);
            this.$player.addClass('NB-mobile-player');
        } else {
            this.collapse_player();
            this.$player.removeClass('NB-mobile-player');
            this.$player_home.prepend(this.$player);
            // media_player_view.js sizes the feed list's footer pane to the player.
            if (!this.$player.hasClass('NB-hidden') && NEWSBLUR.app.media_player) {
                NEWSBLUR.app.media_player.show_player();
            }
        }
        this.update_player_visibility();
    },

    update_player_visibility: function () {
        if (!this.$player) return;
        var visible = this.active && !this.$player.hasClass('NB-hidden');
        this.$body.toggleClass('NB-mobile-has-player', visible);
        if (!visible) this.collapse_player();
    },

    expand_player: function () {
        this.$player.addClass('NB-mobile-player-expanded');
        this.$body.addClass('NB-mobile-player-open');
    },

    collapse_player: function () {
        if (!this.$player) return;
        this.$player.removeClass('NB-mobile-player-expanded');
        this.$body.removeClass('NB-mobile-player-open');
    },

    // ======================
    // = Pull to refresh    =
    // ======================

    setup_pull_to_refresh: function () {
        var self = this;
        this.feeds_refresher = new NEWSBLUR.Views.MobilePullToRefresh({
            scroller: this.$screens.feeds.find('.left-center-content')[0],
            is_enabled: function () {
                return self.active && self.screen === 'feeds';
            },
            refresh: function (done) {
                NEWSBLUR.reader.force_feeds_refresh(function () {
                    done();
                }, false, null, done);
            }
        });
        this.titles_refresher = new NEWSBLUR.Views.MobilePullToRefresh({
            scroller: NEWSBLUR.reader.$s.$story_titles[0],
            is_enabled: function () {
                return self.active && self.screen === 'titles' && !!NEWSBLUR.reader.active_feed;
            },
            refresh: function (done) {
                NEWSBLUR.reader.reload_feed({});
                // reload_feed empties the list right away; the next reset brings the new stories.
                NEWSBLUR.assets.stories.once('reset', done);
            }
        });
    },

    // ===================
    // = Long press      =
    // ===================

    // iOS Safari never fires contextmenu, so a held finger on a feed, folder or story opens the
    // same manage menu a right-click does on desktop.
    setup_long_press: function () {
        var selector = '.NB-feedlist .feed, .NB-feedlist .folder_title, .NB-story-title, ' +
            '.NB-feed-story-header';
        this.long_press_selector = selector;
        this.$body.on('touchstart.mobile_long_press', selector, this.handle_long_press_start);
        this.$body.on('touchmove.mobile_long_press touchend.mobile_long_press ' +
            'touchcancel.mobile_long_press', this.handle_long_press_cancel);
        document.addEventListener('click', this.handle_long_press_click, true);
        document.addEventListener('click', this.handle_story_button, true);
        document.addEventListener('touchend', this.handle_search_close, true);
        // Android Chrome fires its own contextmenu on a long press. The long press above already
        // opened the menu, and letting this through would toggle it shut again.
        document.addEventListener('contextmenu', _.bind(function (e) {
            if (!this.active || !e.isTrusted) return;
            if ($(e.target).closest(this.long_press_selector).length || this.long_press_recent()) {
                e.preventDefault();
                e.stopPropagation();
            }
        }, this), true);
    },

    handle_long_press_start: function (e) {
        if (!this.active || e.originalEvent.touches.length !== 1) return;
        var touch = e.originalEvent.touches[0];
        var $target = $(e.currentTarget);
        this.long_press_fired = false;
        this.long_press_origin = { x: touch.clientX, y: touch.clientY };
        this.start_press($target);
        clearTimeout(this.long_press_timer);
        this.long_press_timer = setTimeout(_.bind(function () {
            this.long_press_fired = Date.now();
            this.release_press(false);
            if (navigator.vibrate) navigator.vibrate(10);
            this.open_manage_menu_for($target);
        }, this), this.LONG_PRESS_MS);
    },

    handle_long_press_cancel: function (e) {
        if (!this.long_press_timer && !this.$pressed) return;
        if (e.type === 'touchmove') {
            var touch = e.originalEvent.touches[0];
            var origin = this.long_press_origin;
            if (origin && Math.abs(touch.clientX - origin.x) < 10 && Math.abs(touch.clientY - origin.y) < 10) {
                return;
            }
        }
        this.release_press(e.type === 'touchend');
        clearTimeout(this.long_press_timer);
        this.long_press_timer = null;
    },

    // A row shows it's pressed only once a finger rests on it, the way a native list delays its
    // highlight, so a thumb that lands on a row to scroll never lights it up. mobile.css styles
    // NB-mobile-pressed and turns off the desktop :hover that touch browsers apply on contact.
    start_press: function ($target) {
        this.release_press(false);
        this.$pressed = $target;
        this.press_timer = setTimeout(_.bind(function () {
            if (this.$pressed) this.$pressed.addClass('NB-mobile-pressed');
        }, this), this.PRESS_DELAY_MS);
    },

    release_press: function (tapped) {
        clearTimeout(this.press_timer);
        var $pressed = this.$pressed;
        this.$pressed = null;
        if (!$pressed) return;
        if (!tapped) {
            $pressed.removeClass('NB-mobile-pressed');
            return;
        }
        // A quick tap lifts before the press shows, so flash it to acknowledge the tap.
        $pressed.addClass('NB-mobile-pressed');
        _.delay(function () {
            $pressed.removeClass('NB-mobile-pressed');
        }, this.PRESS_FLASH_MS);
    },

    // A browser may follow the long press with a click, which would open the feed or story
    // underneath the menu. Only a click arriving right after the press counts, since some
    // browsers send none and a later tap must still go through.
    long_press_recent: function () {
        return !!this.long_press_fired && Date.now() - this.long_press_fired < 800;
    },

    handle_long_press_click: function (e) {
        if (!this.long_press_fired) return;
        var recent = this.long_press_recent();
        this.long_press_fired = false;
        if (!recent) return;
        e.preventDefault();
        e.stopPropagation();
    },

    // ======================
    // = Story list pills   =
    // ======================

    // Like StoryTitlesHeaderBar.swift relayoutPills in the iOS app: when the pills don't fit, the
    // story options pill drops its story order, then its words, before anything else gives way
    // (mobile.css NB-mobile-options-compact and NB-mobile-options-icon).
    // The bar's Next unread drops its label after the story order and before the options' words
    // (mobile.css NB-mobile-nav-compact).
    fit_pills: function () {
        var $bar = $('.right-pane > .content-north');
        var $row = $bar.find('.NB-story-titles-header').children('.feed, .NB-folder');
        $bar.removeClass('NB-mobile-nav-compact');
        $row.removeClass('NB-mobile-options-compact NB-mobile-options-icon');
        var options = $row.find('.NB-feedbar-options')[0];
        if (!this.active || !options || !options.clientWidth) return;
        // NB-mobile-options-measure lays the pill out at its natural width, which its container
        // can only give it when there's room.
        $row.addClass('NB-mobile-options-measure');
        var clipped = function () {
            return options.offsetWidth > options.parentNode.clientWidth + 1 ||
                $row[0].scrollWidth > $row[0].clientWidth + 1;
        };
        if (clipped()) $row.addClass('NB-mobile-options-compact');
        if (clipped()) $bar.addClass('NB-mobile-nav-compact');
        if (clipped()) $row.addClass('NB-mobile-options-icon');
        $row.removeClass('NB-mobile-options-measure');
    },

    // The story list's pills are drawn in stages while a list loads: the header renders, the
    // layout decides whether Previous and Next unread show, then fit_pills sizes the options
    // pill. mobile.css NB-mobile-pills-pending keeps the bar's row but hides those stages, so
    // the pills first appear at their final size. A list that never reports back (a dashboard
    // river handed over without a count) shows them after PILLS_PENDING_MS.
    set_pills_pending: function (pending) {
        var $bar = $('.right-pane > .content-north');
        clearTimeout(this.pills_pending_timer);
        // A search reloads the list under the field being typed in, which has to stay put.
        if (pending && (NEWSBLUR.reader.flags.search || $bar.find('.NB-story-titles-header.NB-searching').length)) {
            pending = false;
        }
        if (pending) {
            $bar.addClass('NB-mobile-pills-pending');
            this.pills_pending_timer = setTimeout(_.bind(this.set_pills_pending, this, false), this.PILLS_PENDING_MS);
            return;
        }
        // story_titles_header_view.js renders the list's header right after its stories arrive.
        _.defer(_.bind(function () {
            this.fit_pills();
            $bar.removeClass('NB-mobile-pills-pending');
        }, this));
    },

    // The story list's search field closes from its x or from its pill. iOS dismisses the keyboard
    // on the first touch outside the field, which moves the bar before a click arrives, so the
    // close runs as the finger lifts and the touch's own click is cancelled.
    handle_search_close: function (e) {
        if (!this.active || !NEWSBLUR.app.active_search) return;
        var $target = $(e.target);
        var $header = $target.closest('.right-pane .NB-story-titles-header.NB-searching');
        if (!$header.length) return;
        var on_close = $target.closest('.NB-search-close').length;
        var on_pill = $target.closest('.NB-search-container').length &&
            !$target.closest('.NB-story-title-search-input').length;
        if (!on_close && !on_pill) return;
        e.preventDefault();
        // An empty field only needs the blur, which closes it (feed_search_view.js blur_search).
        var $input = NEWSBLUR.app.active_search.$('input');
        var has_query = !!$input.val();
        $input.blur();
        if (has_query) NEWSBLUR.app.active_search.close_search();
    },

    // The story list's mark read lives in the nav bar. It shows only for lists the reader can mark
    // read, those whose header has its own mark read control (curated rivers like Global Shared
    // Stories don't, as on desktop).
    update_titles_actions: function () {
        if (!this.$titles_bar) return;
        var $header = $('.right-pane .NB-story-titles-header');
        var can_mark_read = $header.find('.NB-feedbar-mark-feed-read').length > 0 &&
            !$header.find('.NB-folder-fake').length;
        this.$titles_bar.find('.NB-mobile-mark-read').toggleClass('NB-hidden', !can_mark_read);
        this.fit_pills();
    },

    // views/mobile_mark_read_popover.js: mark everything or stories older than some days.
    open_mark_read_menu: function () {
        NEWSBLUR.MobileMarkReadPopover.create({ anchor: this.$titles_bar.find('.NB-mobile-mark-read') });
    },

    // Presses the list header's own hidden control, so feeds, folders and rivers each mark read
    // their own way. Picking from the menu is the confirmation, so the inline one is skipped.
    mark_list_read: function (days) {
        var $header = $('.right-pane .NB-story-titles-header');
        var $control = days ?
            $header.find('.NB-feedbar-mark-feed-read-time[data-days="' + days + '"]') :
            $header.find('.NB-feedbar-mark-feed-read');
        if (!$control.length) return;
        NEWSBLUR.reader.flags.mark_read_confirmed = true;
        try {
            $control.first().trigger('click');
        } finally {
            NEWSBLUR.reader.flags.mark_read_confirmed = false;
        }
    },

    // The bar's Previous and Next unread select a story with the reader's own buttons. Next unread
    // may carry on into another feed, so story_selected decides by the layout of the list the
    // story lands in: full screen or grid shows it on the story screen, inline expands it there.
    handle_story_button: function (e) {
        if (!this.active || this.screen !== 'titles') return;
        if (!$(e.target).closest('.right-pane .NB-taskbar-nav .NB-taskbar-button').length) return;
        this.open_on_select = Date.now();
    },

    // ======================
    // = Sideoption sheets  =
    // ======================

    // A story's Share form, Save tags and notes, and Related stories open inside the story on
    // desktop, growing a panel beside its buttons. On a phone each slides up over the screen as
    // a bottom sheet, like Ask AI: its panel moves into a sheet on the body, above the shade,
    // and goes back into the story when the sheet closes. The view that owns the panel finds
    // and hears it through the sheet meanwhile.
    //
    // story_share_view.js, story_save_view.js and discover_stories_view.js call this from
    // resize, which runs whenever their panel opens, changes or closes. Returns whether a phone
    // is handling the panel, which needs no height animated in the story.
    sideoption_sheet: function (view, $panel, options) {
        // A story's long-press menu has a share form of its own, already inside that sheet,
        // which reader.js fills in before the menu is on the page.
        if (!this.active || $panel.closest('.NB-menu-manage').length) return false;
        if ($panel.length && !$.contains(document.documentElement, $panel[0])) return false;
        var open = this.sideoption;
        if (options.close) {
            if (open && open.view === view) this.dismiss_sideoption_sheet();
            return true;
        }
        if (open && open.view === view) return true;
        if (options.present === false || !$panel.length) return true;
        if (open) open.dismiss();
        this.present_sideoption_sheet(view, $panel, options.dismiss);
        return true;
    },

    present_sideoption_sheet: function (view, $panel, dismiss) {
        var $sheet = $.make('div', { className: 'NB-mobile-sideoption-sheet' }, [
            $.make('div', { className: 'NB-mobile-sideoption-sheet-handle' })
        ]);
        var placeholder = document.createComment('mobile_layout_view.js sideoption sheet');
        $panel.before(placeholder);
        $sheet.append($panel);
        this.$body.append($sheet).addClass('NB-mobile-sideoption-open');
        this.sideoption = {
            view: view,
            $panel: $panel,
            $sheet: $sheet,
            $el: view.$el,
            placeholder: placeholder,
            dismiss: dismiss
        };
        // The view's lookups and delegated events now reach into the sheet as well.
        view.setElement(view.$el.add($sheet));
        this.fit_sideoption_sheet();
    },

    // The owning view closes its panel, whose resize comes back through sideoption_sheet.
    close_sideoption_sheet: function (options) {
        var open = this.sideoption;
        if (!open) return;
        open.dragged = !!(options && options.dragged);
        open.dismiss();
        // A view that could not close its panel still gives the sheet up.
        if (this.sideoption === open) this.dismiss_sideoption_sheet();
    },

    dismiss_sideoption_sheet: function () {
        var open = this.sideoption;
        if (!open) return;
        this.sideoption = null;
        this.$body.removeClass('NB-mobile-sideoption-open');
        var restore = function () {
            // The story may have been drawn again while the sheet was up.
            if (open.placeholder.parentNode) {
                $(open.placeholder).replaceWith(open.$panel);
            } else {
                open.$panel.remove();
            }
            open.view.setElement(open.$el);
            open.$sheet.remove();
        };
        var duration = open.dragged ? 0 : Math.min(260, this.transition_duration());
        if (!duration) {
            restore();
            return;
        }
        open.$sheet.addClass('NB-mobile-sideoption-sheet-closing');
        setTimeout(restore, duration);
    },

    // The keyboard covers the bottom of the window without resizing it, so the sheet rests on
    // top of the keyboard, where its field and buttons stay in view.
    fit_sideoption_sheet: function () {
        var open = this.sideoption;
        var viewport = window.visualViewport;
        if (!open || !viewport) return;
        var covered = Math.max(0, Math.round(window.innerHeight - viewport.height - viewport.offsetTop));
        open.$sheet[0].style.bottom = covered + 'px';
        open.$sheet[0].style.maxHeight = Math.round(viewport.height * 0.85) + 'px';
    },

    setup_sideoption_sheets: function () {
        var self = this;
        this.$body.on('click', '.NB-mobile-sheet-shade', function () {
            self.close_sideoption_sheet();
        });
        if (window.visualViewport) {
            var fit = _.bind(this.fit_sideoption_sheet, this);
            window.visualViewport.addEventListener('resize', fit);
            window.visualViewport.addEventListener('scroll', fit);
        }
    },

    // ======================
    // = Sheet dismissal    =
    // ======================

    // Every phone sheet follows a downward drag that starts while its content is scrolled to the
    // top, and a far or fast enough drag sends it away, like an iOS sheet. Reused sheets (the
    // manage menu, the Listen player) drop the drag's inline styles once closed. A sheet that
    // holds_edits stays put once something in it has changed (setup_sheet_edits).
    SHEETS: [
        { selector: '.NB-popover.popover.in', overlay: '.NB-overlay', close: function () { NEWSBLUR.ReaderPopover.close(); } },
        { selector: '.NB-menu-manage-container.NB-mobile-sheet', overlay: '.NB-mobile-sheet-shade', reused: true, close: function () { NEWSBLUR.reader.hide_manage_menu(); } },
        { selector: '.NB-menu-ask-ai-container', close: function () { $(document).trigger('click.ask_ai_menu'); } },
        { selector: '.NB-mobile-sideoption-sheet', overlay: '.NB-mobile-sheet-shade', reused: true, close: function () { NEWSBLUR.app.mobile.close_sideoption_sheet({ dragged: true }); } },
        { selector: '#simplemodal-container', overlay: '#simplemodal-overlay', holds_edits: true, close: function () { $.modal.close(); } },
        { selector: '.NB-media-player.NB-mobile-player-expanded', overlay: '.NB-mobile-player-shade', reused: true, close: function () { NEWSBLUR.app.mobile.collapse_player(); } }
    ],

    // Preferences, Account, Site Settings and the trainer save only from their Save button, so
    // once someone changes something in a modal, a swipe down would throw it away. Like an iOS
    // sheet with changes, the modal then only gives a little under the finger and springs back.
    // Only a person's own edits count, not a modal setting its controls as it opens: their
    // input, a trainer classifier they tap, or a Save button they have enabled since their first
    // touch, which is how Preferences and Account notice their segmented controls.
    setup_sheet_edits: function () {
        $(document).on('input change click', '#simplemodal-container', function (e) {
            if (!e.originalEvent || !e.originalEvent.isTrusted) return;
            if (e.type === 'click' && !$(e.target).closest('.NB-classifier').length) return;
            $(e.currentTarget).addClass('NB-mobile-sheet-edited');
        });
        document.addEventListener('touchstart', _.bind(function (e) {
            var modal = $(e.target).closest('#simplemodal-container')[0];
            if (!modal || modal.nb_disabled_saves !== undefined) return;
            modal.nb_disabled_saves = this.disabled_saves(modal);
        }, this), { capture: true, passive: true });
    },

    disabled_saves: function (modal) {
        return $(modal).find('.NB-modal-submit-button, input[type=submit]').filter('.NB-disabled, [disabled]').length;
    },

    modal_edited: function (modal) {
        return $(modal).hasClass('NB-mobile-sheet-edited') ||
            (modal.nb_disabled_saves !== undefined && this.disabled_saves(modal) < modal.nb_disabled_saves);
    },

    // A drag inside anything scrolled down scrolls it back up instead.
    scrolled_below_top: function (node, sheet) {
        for (; node && node !== sheet.parentNode; node = node.parentNode) {
            if (node.scrollTop > 0 && node.scrollHeight > node.clientHeight) return true;
        }
        return false;
    },

    handle_sheet_touchstart: function (e) {
        this.sheet_drag = null;
        if (!this.active || e.touches.length !== 1) return;
        var $target = $(e.target);
        var sheet = _.find(this.SHEETS, function (sheet) {
            return $target.closest(sheet.selector).length;
        });
        if (!sheet) return;
        var $sheet = $target.closest(sheet.selector);
        // Text fields and sliders keep their own drags.
        if ($target.closest('input, textarea, select, [contenteditable="true"]').length) return;
        if (this.scrolled_below_top(e.target, $sheet[0])) return;
        var touch = e.touches[0];
        this.sheet_drag = {
            sheet: sheet,
            $sheet: $sheet,
            $overlay: sheet.overlay ? $(sheet.overlay) : $(),
            start_x: touch.clientX,
            start_y: touch.clientY,
            held: !!sheet.holds_edits && this.modal_edited($sheet[0]),
            axis: null,
            dy: 0,
            samples: [{ y: touch.clientY, t: e.timeStamp }]
        };
    },

    handle_sheet_touchmove: function (e) {
        var drag = this.sheet_drag;
        if (!drag) return;
        var touch = e.touches[0];
        var dy = touch.clientY - drag.start_y;
        if (!drag.axis) {
            drag.axis = this.utils.gesture_axis(touch.clientX - drag.start_x, dy);
            if (!drag.axis) return;
            if (drag.axis !== 'vertical' || dy <= 0) {
                this.sheet_drag = null;
                return;
            }
            drag.height = drag.$sheet[0].getBoundingClientRect().height;
            drag.$sheet.addClass('NB-mobile-sheet-dragging');
        }
        e.preventDefault();
        drag.dy = drag.held ? this.utils.rubber_band(Math.max(0, dy), 240) : Math.max(0, dy);
        drag.samples.push({ y: touch.clientY, t: e.timeStamp });
        if (drag.samples.length > 5) drag.samples.shift();
        drag.$sheet[0].style.transform = 'translate3d(0, ' + drag.dy + 'px, 0)';
        if (!drag.held) drag.$overlay.css('opacity', Math.max(0, 1 - drag.dy / drag.height));
    },

    handle_sheet_touchend: function () {
        var drag = this.sheet_drag;
        this.sheet_drag = null;
        if (!drag || !drag.axis) return;
        var el = drag.$sheet[0];
        var first = drag.samples[0];
        var last = drag.samples[drag.samples.length - 1];
        var velocity = (last.y - first.y) / Math.max(1, last.t - first.t);
        drag.$sheet.removeClass('NB-mobile-sheet-dragging');
        var settle = function () {
            el.style.transition = '';
            el.style.transform = '';
            drag.$overlay.css('opacity', '');
        };
        if (drag.held || !this.utils.swipe_completes(drag.dy, velocity, drag.height)) {
            var snap_duration = NEWSBLUR.motion.duration(260);
            if (!snap_duration) { settle(); return; }
            el.style.transition = 'transform ' + snap_duration + 'ms cubic-bezier(0.2, 0.85, 0.25, 1)';
            el.style.transform = 'translate3d(0, 0, 0)';
            drag.$overlay.css('opacity', '');
            _.delay(settle, snap_duration + 20);
            return;
        }
        // A fling keeps its speed for the rest of the way down.
        var remaining = drag.height - drag.dy;
        var duration = NEWSBLUR.motion.duration(Math.round(Math.min(320, Math.max(120, remaining / Math.max(velocity, 1.2)))));
        if (!duration) {
            drag.sheet.close();
            if (drag.sheet.reused) settle();
            return;
        }
        el.style.transition = 'transform ' + duration + 'ms cubic-bezier(0.25, 0.7, 0.35, 1)';
        el.style.transform = 'translate3d(0, ' + Math.round(drag.height + 24) + 'px, 0)';
        drag.$overlay.css({ transition: 'opacity ' + duration + 'ms', opacity: 0 });
        _.delay(function () {
            drag.sheet.close();
            drag.$overlay.css('transition', '');
            if (drag.sheet.reused) settle();
        }, duration);
    },

    // The feed, folder and story views already open their manage menu on contextmenu. The
    // mobile_long_press flag lets them skip the desktop show_contextmenus preference.
    open_manage_menu_for: function ($target) {
        $target.trigger($.Event('contextmenu', { mobile_long_press: true }));
    }

});
