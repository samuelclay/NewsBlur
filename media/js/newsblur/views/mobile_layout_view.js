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
    PRESS_DELAY_MS: 120,
    PRESS_FLASH_MS: 160,

    initialize: function () {
        _.bindAll(this, 'check_mode', 'handle_popstate', 'handle_touchstart', 'handle_touchmove',
            'handle_touchend', 'handle_touchcancel', 'handle_long_press_start', 'handle_long_press_cancel',
            'handle_long_press_click', 'handle_mark_read_days', 'fit_pills');
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
        window.addEventListener('resize', _.debounce(this.fit_pills, 100));
        document.addEventListener('touchstart', this.handle_touchstart, { passive: true });
        document.addEventListener('touchmove', this.handle_touchmove, { passive: false });
        document.addEventListener('touchend', this.handle_touchend, { passive: true });
        document.addEventListener('touchcancel', this.handle_touchcancel, { passive: true });
        this.setup_long_press();
        this.setup_pull_to_refresh();
        this.setup_player();

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
        this.restore_parent(entry);
        this.set_screen(screen);
        this.tag_entry(screen);
        this.update_titles_bar();
        this.refresh_story_layout();
        this.dock_player(true);
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
        this.clear_drag();
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
            this.clear_drag();
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
        return _.isNaN(duration) ? 380 : duration;
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
        if (screen === 'story') {
            var story = target.story_hash && NEWSBLUR.assets.stories.get_by_story_hash(target.story_hash);
            if (story) {
                this.story_pager.open(story);
            } else if (target.story_hash && this.router_will_route()) {
                // The entry belongs to another feed (Next unread crossed into this one), which the
                // router opens once this handler returns. stories_reset opens the story then.
                this.awaiting_story = target.story_hash;
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
        this.pending_back = null;
        clearTimeout(this.pending_back_timer);
        this.show_screen(screen, {
            direction: direction === 'none' ? 'pop' : direction,
            // The browser already animated its own swipe-back, don't slide a second time.
            animate: !e.hasUAVisualTransition,
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
        if (!this.awaiting_story || !options || options.added === undefined) return;
        var story_hash = this.awaiting_story;
        this.awaiting_story = null;
        if (!this.active || this.screen !== 'story') return;
        var story = NEWSBLUR.assets.stories.get_by_story_hash(story_hash);
        if (story) {
            this.story_pager.open(story);
            return;
        }
        // The story has dropped off the feed's first page, so show the list it was in.
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

    // story_title_view.js: tapping a grid card pushes the full-screen story.
    open_story: function (story) {
        if (!this.active || !story) return;
        this.story_pager.open(story);
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
        if (!this.active || !this.is_grid() || this.screen === 'story') return;
        this.open_story(story);
    },

    // views/mobile_story_pager_view.js: Next unread ran out of unread stories in this list, so
    // reader.js show_next_unread_story is loading more or moving on to the next feed. Keep the
    // story screen up until that next unread story is selected.
    follow_next_unread: function () {
        this.following_unread = Date.now();
    },

    is_following_unread: function () {
        return !!this.following_unread && Date.now() - this.following_unread < 20000;
    },

    story_selected: function (story, selected) {
        if (!this.active || !selected || !this.is_following_unread()) return;
        this.following_unread = null;
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
        // The pill bar's header element outlives the story list it controls, and the list's own
        // controls render right after this.
        $('.right-pane .NB-story-titles-header').removeClass('NB-mobile-mark-read-days');
        _.defer(this.fit_pills);
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
            this.$body.hasClass('NB-mobile-sheet-open') ||
            this.$body.hasClass('NB-mobile-player-open');
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
        if ($(e.target).closest('.NB-media-player').length) return;
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
        setTimeout(function () {
            $both.removeClass('NB-mobile-animating');
            if (self.screen !== self.back_target()) {
                $under.removeClass('NB-mobile-pos-left');
            }
            self.$body.removeClass('NB-mobile-transitioning');
        }, this.transition_duration() + 40);
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

        // Tapping the collapsed bar anywhere but play/pause or close expands it. In the sheet, a
        // tap on its top edge (the grab handle) collapses it again.
        this.$player[0].addEventListener('click', _.bind(function (e) {
            if (!this.active) return;
            var expanded = this.$player.hasClass('NB-mobile-player-expanded');
            if (!expanded && !$(e.target).closest('.NB-media-player-play-pause, .NB-media-player-close').length) {
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
        document.addEventListener('click', this.handle_mark_read_days, true);
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
    fit_pills: function () {
        var $row = $('.right-pane .NB-story-titles-header').children('.feed, .NB-folder');
        $row.removeClass('NB-mobile-options-compact NB-mobile-options-icon');
        var options = $row.find('.NB-feedbar-options')[0];
        if (!this.active || !options || !options.clientWidth) return;
        // NB-mobile-options-measure lays the pill out at its natural width, which its container
        // can only give it when there's room.
        $row.addClass('NB-mobile-options-measure');
        var clipped = function () {
            return options.offsetWidth > options.parentNode.clientWidth + 1;
        };
        if (clipped()) $row.addClass('NB-mobile-options-compact');
        if (clipped()) $row.addClass('NB-mobile-options-icon');
        $row.removeClass('NB-mobile-options-measure');
    },

    // The + beside the story list's mark read checkmark lays the 1d to 14d choices out across
    // the pill bar (mobile.css NB-mobile-mark-read-days) instead of fanning them out the desktop
    // way (feed_title_view.js expand_mark_read). It closes on a second tap, a choice or a tap
    // anywhere else.
    handle_mark_read_days: function (e) {
        if (!this.active) return;
        var $target = $(e.target);
        var $header = $target.closest('.right-pane .NB-story-titles-header');
        if ($target.closest('.NB-feedbar-mark-feed-read-expand').length && $header.length) {
            e.preventDefault();
            e.stopPropagation();
            $header.toggleClass('NB-mobile-mark-read-days');
            return;
        }
        var $open = $('.right-pane .NB-story-titles-header.NB-mobile-mark-read-days');
        if (!$open.length) return;
        // A choice still reaches its view, which marks the stories read, before this closes.
        _.defer(function () {
            $open.removeClass('NB-mobile-mark-read-days');
        });
    },

    // The feed, folder and story views already open their manage menu on contextmenu. The
    // mobile_long_press flag lets them skip the desktop show_contextmenus preference.
    open_manage_menu_for: function ($target) {
        $target.trigger($.Event('contextmenu', { mobile_long_press: true }));
    }

});
