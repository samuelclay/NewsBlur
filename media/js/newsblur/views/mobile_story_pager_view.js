// mobile_story_pager_view.js: the full-screen story screen of the phone layout
// (views/mobile_layout_view.js). Grid cards push it; it shows one story at a time and a
// horizontal swipe pages to the previous or next visible story. The story either side is
// rendered ahead of time so a swipe always reveals real content.
NEWSBLUR.Views.MobileStoryPager = Backbone.View.extend({

    className: 'NB-mobile-story-screen',

    events: {
        'click .NB-mobile-bar-back': 'go_back',
        'click .NB-mobile-story-view-option': 'select_view',
        'click .NB-mobile-story-previous': 'open_previous',
        'click .NB-mobile-story-next': 'open_next',
        'click .NB-mobile-story-save': 'toggle_saved',
        'click .NB-mobile-story-share': 'share_story',
        'click .NB-mobile-story-unread': 'toggle_unread',
        'click .NB-mobile-story-next-unread': 'open_next_unread',
        'click .NB-mobile-story-options': 'open_story_options'
    },

    initialize: function (options) {
        _.bindAll(this, 'handle_pointerdown', 'handle_pointermove', 'handle_pointerup',
            'stories_added', 'story_changed');
        this.mobile = options.mobile;
        this.utils = NEWSBLUR.mobile_utils;
        this.story = null;
        this.pages = {
            previous: { story: null, view: null },
            current: { story: null, view: null },
            next: { story: null, view: null }
        };
        this.render();

        var pager = this.$pager[0];
        pager.addEventListener('pointerdown', this.handle_pointerdown);
        pager.addEventListener('pointermove', this.handle_pointermove);
        pager.addEventListener('pointerup', this.handle_pointerup);
        pager.addEventListener('pointercancel', this.handle_pointerup);
    },

    render: function () {
        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-mobile-bar NB-mobile-story-bar' }, [
                $.make('div', { className: 'NB-mobile-bar-back', role: 'button' }, [
                    $.make('div', { className: 'NB-mobile-bar-back-icon' }),
                    $.make('div', { className: 'NB-mobile-bar-back-label' }, gettext('Stories'))
                ]),
                $.make('div', { className: 'NB-mobile-bar-title' }, [
                    $.make('div', { className: 'NB-mobile-segmented NB-mobile-story-views' }, [
                        $.make('div', { className: 'NB-mobile-segmented-option NB-mobile-story-view-option', 'data-view': 'feed', role: 'button' }, gettext('Feed')),
                        $.make('div', { className: 'NB-mobile-segmented-option NB-mobile-story-view-option', 'data-view': 'text', role: 'button' }, gettext('Text')),
                        $.make('div', { className: 'NB-mobile-segmented-option NB-mobile-story-view-option', 'data-view': 'story', role: 'button' }, gettext('Story'))
                    ])
                ]),
                $.make('div', { className: 'NB-mobile-bar-actions' }, [
                    $.make('div', { className: 'NB-mobile-bar-button NB-mobile-story-options', role: 'button' }, [
                        $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-options' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-mobile-story-pager' }, [
                $.make('div', { className: 'NB-mobile-story-track' }, [
                    $.make('div', { className: 'NB-mobile-story-page NB-mobile-story-page-previous' }),
                    $.make('div', { className: 'NB-mobile-story-page NB-mobile-story-page-current' }),
                    $.make('div', { className: 'NB-mobile-story-page NB-mobile-story-page-next' })
                ])
            ]),
            $.make('div', { className: 'NB-mobile-toolbar NB-mobile-story-toolbar' }, [
                $.make('div', { className: 'NB-mobile-toolbar-group' }, [
                    $.make('div', { className: 'NB-mobile-toolbar-button NB-mobile-story-previous', role: 'button', 'aria-label': gettext('Previous story') }, [
                        $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-chevron-previous' })
                    ]),
                    $.make('div', { className: 'NB-mobile-toolbar-button NB-mobile-story-next', role: 'button', 'aria-label': gettext('Next story') }, [
                        $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-chevron-next' })
                    ])
                ]),
                $.make('div', { className: 'NB-mobile-toolbar-group' }, [
                    $.make('div', { className: 'NB-mobile-toolbar-button NB-mobile-story-save', role: 'button', 'aria-label': gettext('Save') }, [
                        $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-star' })
                    ]),
                    $.make('div', { className: 'NB-mobile-toolbar-button NB-mobile-story-share', role: 'button', 'aria-label': gettext('Share') }, [
                        $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-share' })
                    ]),
                    $.make('div', { className: 'NB-mobile-toolbar-button NB-mobile-story-unread', role: 'button' }, [
                        $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-unread' })
                    ])
                ]),
                $.make('div', { className: 'NB-mobile-toolbar-button NB-mobile-story-next-unread', role: 'button' }, [
                    $.make('span', gettext('Next unread')),
                    $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-next' })
                ])
            ])
        ]).children());

        this.$pager = this.$('.NB-mobile-story-pager');
        this.$track = this.$('.NB-mobile-story-track');
        this.pages.previous.$el = this.$('.NB-mobile-story-page-previous');
        this.pages.current.$el = this.$('.NB-mobile-story-page-current');
        this.pages.next.$el = this.$('.NB-mobile-story-page-next');
        return this;
    },

    story_hash: function () {
        return this.story && this.story.get('story_hash');
    },

    // ============
    // = Content  =
    // ============

    open: function (story) {
        this.cancel_page_turn();
        if (!this.story) {
            NEWSBLUR.assets.stories.bind('add', this.stories_added, this);
        }
        if (this.story) this.story.unbind('change:read_status change:starred', this.story_changed, this);
        this.story = story;
        this.story.bind('change:read_status change:starred', this.story_changed, this);
        if (!story.get('selected')) {
            story.set('selected', true, { click_on_story_title: true });
        }
        this.render_all_pages();
        this.update_chrome();
        this.load_more_if_near_end();
    },

    close: function () {
        this.cancel_page_turn();
        if (!this.story) return;
        NEWSBLUR.assets.stories.unbind('add', this.stories_added, this);
        this.story.unbind('change:read_status change:starred', this.story_changed, this);
        this.story = null;
        _.each(this.pages, function (page) {
            this.destroy_page(page);
            page.story = null;
        }, this);
        this.$track.removeClass('NB-mobile-animating').css('transform', '');
    },

    // Shown while Next unread opens another feed.
    show_loading: function (message) {
        this.cancel_page_turn();
        if (this.story) {
            NEWSBLUR.assets.stories.unbind('add', this.stories_added, this);
            this.story.unbind('change:read_status change:starred', this.story_changed, this);
            this.story = null;
        }
        _.each(this.pages, function (page) {
            this.destroy_page(page);
            page.story = null;
        }, this);
        this.pages.current.$el.removeClass('NB-mobile-story-page-empty').html($.make('div', {
            className: 'NB-mobile-story-loading'
        }, message));
    },

    neighbors: function (story) {
        var visible = NEWSBLUR.assets.stories.visible();
        var index = _.indexOf(visible, story);
        return {
            index: index,
            count: visible.length,
            previous: index > 0 ? visible[index - 1] : null,
            next: index >= 0 && index < visible.length - 1 ? visible[index + 1] : null
        };
    },

    // Feed, Text or Story for the story on screen. Read from the saved view setting because
    // reader.js switch_taskbar_view folds Story into Feed for list and grid layouts on desktop.
    // Original (page) has no single-story form, so it shows as Feed.
    story_view_mode: function () {
        var view = NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'view');
        if (!_.contains(['feed', 'text', 'story'], view)) view = 'feed';
        if (view === 'story' && this.story && this.story_page_disabled(this.story)) view = 'text';
        return view;
    },

    // Publishers can block framing, and story_tab_view.js falls back to text for them too.
    story_page_disabled: function (story) {
        var feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
        return !!(feed && (feed.get('disabled_page') ||
            NEWSBLUR.utils.is_url_iframe_buster(feed.get('feed_link'))));
    },

    render_all_pages: function () {
        var around = this.neighbors(this.story);
        this.render_page(this.pages.current, this.story, true);
        this.render_page(this.pages.previous, around.previous, false);
        this.render_page(this.pages.next, around.next, false);
    },

    render_page: function (page, story, is_current) {
        var mode = is_current ? this.story_view_mode() : 'feed';
        if (page.story === story && page.mode === mode && page.is_current === is_current && page.view) {
            return;
        }
        this.destroy_page(page);
        page.story = story;
        page.mode = mode;
        page.is_current = is_current;
        page.$el.toggleClass('NB-mobile-story-page-empty', !story)
            .removeClass('NB-mobile-story-page-iframe')
            .scrollTop(0);
        if (!story) return;

        if (mode === 'story') {
            // The original page is the publisher's HTML served from NewsBlur's origin, so the
            // sandbox keeps it in an opaque origin, as the desktop Story view does
            // (templates/reader/feeds_skeleton.xhtml). allow-same-origin would let its scripts
            // act as the signed-in reader.
            page.$el.addClass('NB-mobile-story-page-iframe').html($.make('iframe', {
                className: 'NB-mobile-story-iframe',
                sandbox: 'allow-scripts',
                src: '/rss_feeds/original_story?story_hash=' + encodeURIComponent(story.get('story_hash'))
            }));
            page.view = { destroy: function () { page.$el.empty(); } };
        } else if (mode === 'text') {
            var text_view = new NEWSBLUR.Views.TextTabView({ el: null, inline_story_title: true });
            text_view.fetch_and_render(story);
            page.$el.html(text_view.$el);
            if (text_view.story_detail) {
                text_view.story_detail.attach_handlers();
                text_view.setElement(text_view.$el);
                text_view.story_detail.setElement(text_view.story_detail.$el);
            }
            page.view = text_view;
        } else {
            // Only the story on screen registers itself as the story's detail view. Neighbors
            // render detached (feed_floater) so they don't steal keyboard and share handlers.
            var detail = new NEWSBLUR.Views.StoryDetailView({
                model: story,
                collection: story.collection,
                tagName: 'div',
                show_feed_title: true,
                inline_story_title: is_current,
                feed_floater: !is_current
            }).render();
            page.$el.html(detail.$el);
            detail.attach_handlers();
            detail.setElement(detail.$el);
            page.view = detail;
        }
    },

    destroy_page: function (page) {
        var view = page.view;
        if (view) {
            // TextTabView only removes itself, so its StoryDetailView (and that view's bindings
            // on the story) is destroyed here.
            var detail = view.story_detail || view;
            if (view.story_detail && view.story_detail.destroy) view.story_detail.destroy();
            if (view.destroy) view.destroy();
            // The story keeps pointing at the views that rendered it; forget the ones that are gone.
            var story = page.story;
            if (story) {
                _.each(['story_view', 'latest_story_detail_view', 'inline_story_detail_view'], function (key) {
                    if (story[key] === detail) delete story[key];
                });
            }
        }
        page.view = null;
        page.mode = null;
        page.$el.empty();
    },

    // A neighbor rendered detached becomes the story on screen after a swipe. Promote it in
    // place instead of re-rendering, so its images and scroll position don't flash.
    promote_page: function (page) {
        var view = page.view;
        if (view && view.options && page.mode === 'feed' && this.story_view_mode() === 'feed') {
            view.options.feed_floater = false;
            view.options.inline_story_title = true;
            page.story.story_view = view;
            page.story.inline_story_detail_view = view;
            page.story.latest_story_detail_view = view;
            page.is_current = true;
        }
    },

    // The story that just slid off-screen stays rendered as the new neighbor, now detached.
    demote_page: function (page) {
        if (!page.view) return;
        page.is_current = false;
        if (page.view.options && page.mode === 'feed') {
            page.view.options.feed_floater = true;
            page.view.options.inline_story_title = false;
        }
    },

    stories_added: function () {
        if (!this.story) return;
        var around = this.neighbors(this.story);
        if (!this.pages.next.story && around.next) {
            this.render_page(this.pages.next, around.next, false);
        }
        this.update_chrome();
    },

    story_changed: function () {
        this.update_chrome();
    },

    load_more_if_near_end: function () {
        var around = this.neighbors(this.story);
        if (around.index >= around.count - 3 && !NEWSBLUR.assets.stories.no_more_stories) {
            NEWSBLUR.reader.load_page_of_feed_stories({ scroll_to_loadbar: false });
        }
    },

    update_chrome: function () {
        if (!this.story) return;
        var around = this.neighbors(this.story);
        this.$('.NB-mobile-story-previous').toggleClass('NB-disabled', !around.previous);
        this.$('.NB-mobile-story-next').toggleClass('NB-disabled', !around.next);
        var starred = !!this.story.get('starred');
        this.$('.NB-mobile-story-save').toggleClass('NB-active', starred)
            .attr('aria-label', starred ? gettext('Saved') : gettext('Save'));

        var mode = this.story_view_mode();
        this.$('.NB-mobile-story-view-option').each(function () {
            $(this).toggleClass('NB-active', $(this).data('view') === mode);
        });
        this.$('.NB-mobile-story-view-option[data-view="story"]')
            .toggleClass('NB-disabled', this.story_page_disabled(this.story));
        this.$('.NB-mobile-story-unread')
            .toggleClass('NB-active', !this.story.get('read_status'))
            .attr('aria-label', this.story.get('read_status') ? gettext('Mark as unread') : gettext('Mark as read'));
        this.$('.NB-mobile-story-unread .NB-mobile-icon')
            .toggleClass('NB-mobile-icon-unread', !this.story.get('read_status'))
            .toggleClass('NB-mobile-icon-read', !!this.story.get('read_status'));
    },

    // ============
    // = Paging   =
    // ============

    // Moves to the story `step` positions away (-1 or 1). Animates the track from wherever the
    // finger left it, then rotates the three pages so the new story sits in the middle.
    page_to: function (step) {
        var around = this.neighbors(this.story);
        var target = step < 0 ? around.previous : around.next;
        if (!target || this.animating) {
            this.snap_back();
            return;
        }
        var direction = NEWSBLUR.utils.is_rtl() ? -1 : 1;
        this.animating = true;
        this.$track.addClass('NB-mobile-animating')
            .css('transform', 'translate3d(' + (-step * 100 * direction) + '%, 0, 0)');

        var self = this;
        var turn = {};
        var finish = function () {
            if (self.page_turn !== turn) return;
            self.page_turn = null;
            clearTimeout(turn.timer);
            self.$track.off('transitionend.pager');
            self.finish_page(step, target);
        };
        this.page_turn = turn;
        this.$track.on('transitionend.pager', function (e) {
            if (e.target === self.$track[0]) finish();
        });
        turn.timer = setTimeout(finish, 420);
    },

    // Closing the screen mid page turn abandons it: the story it was turning to must not be
    // selected (and marked read) on a screen that is already gone.
    cancel_page_turn: function () {
        if (!this.page_turn) return;
        clearTimeout(this.page_turn.timer);
        this.page_turn = null;
        this.animating = false;
        this.$track.off('transitionend.pager').removeClass('NB-mobile-animating').css('transform', '');
    },

    finish_page: function (step, target) {
        var leaving = step < 0 ? this.pages.next : this.pages.previous;
        var arriving = step < 0 ? this.pages.previous : this.pages.next;
        var current = this.pages.current;

        // Rotate the page slots: the arriving page becomes current, the old current becomes
        // the neighbor on the side we came from, and the far page is recycled.
        this.destroy_page(leaving);
        var recycled_el = leaving.$el;
        var slots = step < 0 ?
            { previous: { $el: recycled_el }, current: arriving, next: current } :
            { previous: current, current: arriving, next: { $el: recycled_el } };
        this.pages = {
            previous: _.extend({ story: null, view: null }, slots.previous),
            current: slots.current,
            next: _.extend({ story: null, view: null }, slots.next)
        };
        this.pages.previous.$el.removeClass('NB-mobile-story-page-current NB-mobile-story-page-next')
            .addClass('NB-mobile-story-page-previous');
        this.pages.current.$el.removeClass('NB-mobile-story-page-previous NB-mobile-story-page-next')
            .addClass('NB-mobile-story-page-current');
        this.pages.next.$el.removeClass('NB-mobile-story-page-current NB-mobile-story-page-previous')
            .addClass('NB-mobile-story-page-next');
        this.demote_page(this.pages.previous);
        this.demote_page(this.pages.next);

        this.$track.removeClass('NB-mobile-animating').css('transform', '');
        this.animating = false;

        if (this.story) this.story.unbind('change:read_status change:starred', this.story_changed, this);
        this.story = target;
        this.story.bind('change:read_status change:starred', this.story_changed, this);
        this.promote_page(this.pages.current);
        target.set('selected', true, { click_on_story_title: true });

        var around = this.neighbors(target);
        this.render_page(this.pages.current, target, true);
        this.render_page(this.pages.previous, around.previous, false);
        this.render_page(this.pages.next, around.next, false);
        this.update_chrome();
        this.load_more_if_near_end();
        this.mobile.story_paged(target);
    },

    snap_back: function () {
        this.$track.addClass('NB-mobile-animating').css('transform', '');
        var $track = this.$track;
        setTimeout(function () {
            $track.removeClass('NB-mobile-animating');
        }, 340);
    },

    // ==============
    // = Gestures   =
    // ==============

    // The pages scroll vertically on their own (touch-action: pan-y in mobile.css). Pointer
    // events only reach us for horizontal moves, which page between stories.
    handle_pointerdown: function (e) {
        this.drag = null;
        if (e.pointerType === 'mouse' || this.animating || !this.story) return;
        if (this.mobile.is_edge_touch(e.clientX)) return;
        if (this.inside_horizontal_scroller(e.target)) return;
        this.drag = {
            id: e.pointerId,
            start_x: e.clientX,
            start_y: e.clientY,
            axis: null,
            dx: 0,
            samples: [{ x: e.clientX, t: e.timeStamp }]
        };
    },

    handle_pointermove: function (e) {
        var drag = this.drag;
        if (!drag || e.pointerId !== drag.id) return;
        var dx = e.clientX - drag.start_x;
        var dy = e.clientY - drag.start_y;
        if (!drag.axis) {
            drag.axis = this.utils.gesture_axis(dx, dy);
            if (!drag.axis) return;
            if (drag.axis !== 'horizontal') {
                this.drag = null;
                return;
            }
            this.$track.removeClass('NB-mobile-animating');
            try {
                this.$pager[0].setPointerCapture(e.pointerId);
            } catch (err) {
                // setPointerCapture throws when the pointer is already gone, the drag still works.
            }
        }
        var direction = NEWSBLUR.utils.is_rtl() ? -1 : 1;
        var logical_dx = dx * direction;
        var around = this.neighbors(this.story);
        var width = this.$pager.width();
        if ((logical_dx > 0 && !around.previous) || (logical_dx < 0 && !around.next)) {
            logical_dx = this.utils.rubber_band(logical_dx, width);
        }
        drag.dx = logical_dx;
        drag.samples.push({ x: e.clientX, t: e.timeStamp });
        if (drag.samples.length > 5) drag.samples.shift();
        this.$track.css('transform', 'translate3d(' + (logical_dx * direction) + 'px, 0, 0)');
    },

    handle_pointerup: function (e) {
        var drag = this.drag;
        this.drag = null;
        if (!drag || drag.axis !== 'horizontal' || e.pointerId !== drag.id) return;
        var direction = NEWSBLUR.utils.is_rtl() ? -1 : 1;
        var first = drag.samples[0];
        var last = drag.samples[drag.samples.length - 1];
        var velocity = ((last.x - first.x) * direction) / Math.max(1, last.t - first.t);
        var around = this.neighbors(this.story);
        var step = this.utils.pager_step(drag.dx, velocity, this.$pager.width(),
            !!around.previous, !!around.next);
        if (e.type === 'pointercancel' || !step) {
            this.snap_back();
        } else {
            this.page_to(step);
        }
    },

    // Wide tables and code blocks scroll sideways themselves; leave those swipes to them.
    inside_horizontal_scroller: function (target) {
        var node = target;
        while (node && node !== this.$pager[0]) {
            if (node.scrollWidth > node.clientWidth + 2) {
                var overflow_x = getComputedStyle(node).overflowX;
                if (overflow_x === 'auto' || overflow_x === 'scroll') return true;
            }
            node = node.parentNode;
        }
        return false;
    },

    // ============
    // = Actions  =
    // ============

    go_back: function () {
        this.mobile.go_back();
    },

    select_view: function (e) {
        var view = $(e.currentTarget).data('view');
        if ($(e.currentTarget).hasClass('NB-disabled')) return;
        if (!this.story || view === this.story_view_mode()) return;
        NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, { view: view });
        // The reader itself only knows Feed and Text in a grid, keep it off the desktop story iframe.
        NEWSBLUR.reader.story_view = view === 'story' ? 'feed' : view;
        this.render_page(this.pages.current, this.story, true);
        this.update_chrome();
    },

    toggle_unread: function () {
        if (!this.story) return;
        if (this.story.get('read_status')) {
            NEWSBLUR.assets.stories.mark_unread(this.story);
        } else {
            NEWSBLUR.assets.stories.mark_read(this.story, { skip_delay: true });
        }
        this.update_chrome();
    },

    open_next_unread: function () {
        if (!this.story) return;
        var next = NEWSBLUR.assets.stories.get_next_unread_story();
        if (!next || next === this.story) {
            // reader.js loads more of this list or opens the next feed with unreads, the same as
            // the desktop Next unread button. The story screen waits for that story
            // (mobile_layout_view.js story_selected).
            this.mobile.follow_next_unread();
            NEWSBLUR.reader.open_next_unread_story_across_feeds();
            return;
        }
        var around = this.neighbors(this.story);
        if (next === around.next) {
            this.page_to(1);
        } else if (next === around.previous) {
            this.page_to(-1);
        } else {
            this.open(next);
            this.mobile.story_paged(next);
        }
    },

    open_previous: function () {
        this.page_to(-1);
    },

    open_next: function () {
        this.page_to(1);
    },

    toggle_saved: function () {
        if (!this.story) return;
        this.story.toggle_starred();
        this.update_chrome();
    },

    // The native share sheet when the browser has one, otherwise NewsBlur's own share dialog
    // at the end of the story.
    share_story: function () {
        if (!this.story) return;
        var title = $('<div>').html(this.story.get('story_title')).text();
        var url = this.story.get('story_permalink');
        if (navigator.share) {
            navigator.share({ title: title, url: url }).catch(function () {
                // mobile_story_pager_view.js: dismissing the share sheet rejects; nothing to do.
            });
            return;
        }
        var view = this.pages.current.view;
        var detail = view && (view.story_detail || view);
        if (detail && detail.share_view) {
            detail.share_view.toggle_feed_story_share_dialog();
        }
    },

    open_story_options: function (e) {
        NEWSBLUR.StoryOptionsPopover.create({
            anchor: $(e.currentTarget)
        });
    }

});
