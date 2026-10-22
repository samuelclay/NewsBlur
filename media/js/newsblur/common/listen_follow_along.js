// media/js/newsblur/common/listen_follow_along.js
//
// NEWSBLUR.ListenFollowAlong highlights the paragraphs being read aloud in every rendered copy of
// the story (feed view, Text view, and the inline story in list, grid and magazine layouts, all of
// which are StoryDetailViews), scrolls the highlight into view gently, and lets a click on a
// paragraph jump playback there.
//
// Server paragraphs (apps/listen/text.py) are mapped to the DOM by walking the rendered story
// content with the same block rules the server uses and matching each paragraph's first 40
// normalized characters, scanning forward in order. Paragraph 0 is the story title.
NEWSBLUR.ListenFollowAlong = {

    MATCH_PREFIX_LENGTH: 40,
    USER_SCROLL_QUIET_MS: 3000,
    SCROLL_MARGIN: 40,

    BLOCK_TAGS: ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'blockquote', 'dd', 'dt'],
    CONTAINER_TAGS: ['div', 'section', 'article', 'main', 'header', 'ul', 'ol', 'dl', 'center',
        'body', 'html', 'details', 'summary'],
    SKIP_TAGS: ['script', 'style', 'noscript', 'svg', 'canvas', 'iframe', 'pre', 'table', 'figure',
        'figcaption', 'audio', 'video', 'object', 'embed', 'form', 'button', 'nav', 'aside', 'footer',
        'img', 'picture', 'select', 'textarea'],
    // listen_follow_along.js: NewsBlur's own controls inside story content, never part of the article.
    SKIP_SELECTOR: '.NB-media-overlay-buttons, .NB-media-youtube-overlay, .NB-briefing-admin-badge',
    // listen_follow_along.js: Same as NOT_PROSE_RE and MAX_CAPTION_CHARACTERS in apps/listen/text.py.
    NOT_PROSE_RE: /caption|credit|gallery/i,
    MAX_CAPTION_CHARACTERS: 1000,

    story_hash: null,
    manifest: null,
    active_paragraphs: [],
    is_playing: false,
    last_user_scroll_at: 0,
    programmatic_scroll_until: 0,
    pending_jump: null,
    scroll_tracking_bound: false,

    // ===========
    // = Control =
    // ===========

    start: function (story_hash, manifest) {
        if (this.story_hash && this.story_hash !== story_hash) this.clear();
        this.story_hash = story_hash;
        this.manifest = manifest;
        this.bind_scroll_tracking();
        _.each(this.views(), function (view) {
            view._listen_map = null;
        });
        this.apply();
    },

    clear: function () {
        var story_hash = this.story_hash;
        this.story_hash = null;
        this.manifest = null;
        this.active_paragraphs = [];
        this.is_playing = false;
        _.each(this.views(story_hash), function (view) {
            this.clear_view(view);
        }, this);
    },

    set_playing: function (is_playing) {
        this.is_playing = !!is_playing;
        _.each(this.views(), function (view) {
            view.$el.toggleClass('NB-listen-playing-story', this.is_playing);
        }, this);
    },

    highlight: function (paragraphs, options) {
        options = options || {};
        this.active_paragraphs = paragraphs || [];
        this.apply({ scroll: options.scroll !== false });
    },

    highlight_enabled: function () {
        var pref = NEWSBLUR.assets.preference('listen_highlight');
        return !(pref === false || pref === 'false' || pref === 0 || pref === '0');
    },

    // listen_follow_along.js: Called from story_detail_view.js whenever a story's content renders,
    // so a story opened (or switched to the Text view) mid-listen picks up the highlight.
    attach_view: function (view) {
        if (!this.story_hash || !view.model || view.model.get('story_hash') !== this.story_hash) return;
        view._listen_map = null;
        this.apply_view(view, { scroll: false });
    },

    // ==============
    // = Rendering  =
    // ==============

    views: function (story_hash) {
        story_hash = story_hash || this.story_hash;
        if (!story_hash) return [];
        var views = [];
        _.each(document.querySelectorAll('.NB-feed-story'), function (el) {
            var view = el.nb_story_detail_view;
            if (view && view.model && view.model.get('story_hash') === story_hash) {
                views.push(view);
            }
        });
        return views;
    },

    apply: function (options) {
        options = options || {};
        // listen_follow_along.js: Decided before the old highlight is cleared, since whether it
        // was on screen is part of the answer.
        var scrolled = !(options.scroll && this.may_autoscroll());
        _.each(this.views(), function (view) {
            // listen_follow_along.js: Only the first visible copy scrolls, so two panes never fight.
            var did_scroll = this.apply_view(view, { scroll: !scrolled });
            scrolled = scrolled || did_scroll;
        }, this);
    },

    // listen_follow_along.js: Follow the reading only while the reader is with this story: it's the
    // selected story, or the paragraph being read was on screen. After moving on to another story
    // in the Feed view, the pane never yanks back.
    may_autoscroll: function () {
        var active = NEWSBLUR.reader && NEWSBLUR.reader.active_story;
        if (active && active.get('story_hash') === this.story_hash) return true;
        return _.any(document.querySelectorAll('.NB-listen-highlight'), function (el) {
            var container = this.scroll_container(el);
            if (!container) return false;
            var rect = el.getBoundingClientRect();
            var container_rect = container.getBoundingClientRect();
            return rect.bottom > container_rect.top && rect.top < container_rect.bottom;
        }, this);
    },

    apply_view: function (view, options) {
        options = options || {};
        if (!this.manifest) return false;
        var map = this.paragraph_map(view);
        view.$el.addClass('NB-listen-story');
        view.$el.toggleClass('NB-listen-playing-story', this.is_playing);
        view.$('.NB-listen-highlight').removeClass('NB-listen-highlight');
        if (!this.highlight_enabled()) return false;

        var $highlighted = $();
        _.each(this.active_paragraphs, function (paragraph_index) {
            if (map[paragraph_index]) $highlighted = $highlighted.add(map[paragraph_index]);
        });
        $highlighted.addClass('NB-listen-highlight');

        if (options.scroll && $highlighted.length && view.$el.is(':visible')) {
            return this.scroll_into_view($highlighted.first()[0]);
        }
        return false;
    },

    clear_view: function (view) {
        view.$el.removeClass('NB-listen-story NB-listen-playing-story');
        view.$('.NB-listen-highlight').removeClass('NB-listen-highlight');
        view.$('.NB-listen-paragraph').removeClass('NB-listen-paragraph').removeAttr('data-listen-paragraph');
        view._listen_map = null;
    },

    // ===========
    // = Mapping =
    // ===========

    paragraph_map: function (view) {
        var manifest_id = this.manifest && this.manifest.manifest_id;
        var content = view.$('.NB-feed-story-content')[0];
        if (view._listen_map && view._listen_map.manifest_id === manifest_id &&
            view._listen_map.content === content) {
            return view._listen_map.map;
        }

        view.$('.NB-listen-paragraph').removeClass('NB-listen-paragraph').removeAttr('data-listen-paragraph');
        var map = {};
        var paragraphs = (this.manifest && this.manifest.paragraphs) || [];
        var title_el = view.$('.NB-feed-story-title')[0];
        if (title_el) map[0] = title_el;

        if (content) {
            var blocks = this.collect_blocks(content);
            var cursor = 0;
            _.each(paragraphs, function (paragraph) {
                if (paragraph.index === 0 || paragraph.kind === 'title') return;
                var key = this.match_key(paragraph.text);
                if (!key) return;
                for (var j = cursor; j < blocks.length; j++) {
                    if (blocks[j].key.indexOf(key) === 0 || key.indexOf(blocks[j].key) === 0 && blocks[j].key.length >= key.length) {
                        map[paragraph.index] = blocks[j].el;
                        $(blocks[j].el).addClass('NB-listen-paragraph').attr('data-listen-paragraph', paragraph.index);
                        cursor = j + 1;
                        break;
                    }
                }
            }, this);
        }

        view._listen_map = { manifest_id: manifest_id, content: content, map: map };
        return map;
    },

    normalize: function (text) {
        return (text || '').replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, '');
    },

    match_key: function (text) {
        return this.normalize(text).substr(0, this.MATCH_PREFIX_LENGTH).toLowerCase();
    },

    tag_name: function (node) {
        return node.nodeType === 1 ? node.tagName.toLowerCase() : null;
    },

    // listen_follow_along.js: Mirrors _is_skipped in apps/listen/text.py: skipped tags, hidden
    // decoration, and captions, credits and galleries that sites mark by class or id. A long
    // element is an article wrapper that happens to mention galleries, so it isn't skipped.
    is_skipped: function (node) {
        var tag = this.tag_name(node);
        if (!tag || _.contains(this.SKIP_TAGS, tag) || node.getAttribute('aria-hidden') === 'true') return true;
        if ($(node).is(this.SKIP_SELECTOR)) return true;
        var hints = (node.getAttribute('class') || '') + ' ' + (node.getAttribute('id') || '');
        if (!this.NOT_PROSE_RE.test(hints)) return false;
        return (node.textContent || '').length < this.MAX_CAPTION_CHARACTERS;
    },

    contains_embed: function (node) {
        return !!node.querySelector('iframe, video, audio, object, embed');
    },

    has_block_descendant: function (node) {
        var selector = this.BLOCK_TAGS.concat(this.CONTAINER_TAGS).join(',');
        return !!node.querySelector(selector);
    },

    inline_text: function (node) {
        if (node.nodeType === 3) return node.nodeValue;
        if (node.nodeType !== 1 || this.is_skipped(node)) return '';
        if (this.tag_name(node) === 'br') return ' ';
        var text = '';
        _.each(node.childNodes, function (child) {
            text += this.inline_text(child);
        }, this);
        return text;
    },

    // listen_follow_along.js: Mirrors _collect in apps/listen/text.py. Loose text inside a
    // container that also holds blocks is wrapped in a span so it can be highlighted on its own.
    // A run never swallows skipped elements or embeds: moving an iframe or video in the DOM
    // would reload it, so they end the run instead.
    collect_blocks: function (root) {
        var blocks = [];
        this.walk(root, blocks, root);
        return blocks;
    },

    walk: function (element, blocks, root) {
        var run = [];
        var run_text = '';
        var children = _.toArray(element.childNodes);
        var self = this;

        var flush = function () {
            var text = self.normalize(run_text);
            var nodes = run;
            run = [];
            run_text = '';
            if (!text) return;
            var el;
            if (nodes.length === children.length && element !== root) {
                el = element;
            } else {
                el = document.createElement('span');
                el.className = 'NB-listen-run';
                nodes[0].parentNode.insertBefore(el, nodes[0]);
                _.each(nodes, function (node) { el.appendChild(node); });
            }
            blocks.push({ el: el, key: self.match_key(text) });
        };

        _.each(children, function (child) {
            var tag = this.tag_name(child);
            if (child.nodeType === 3) {
                run.push(child);
                run_text += child.nodeValue;
            } else if (child.nodeType !== 1) {
                return;
            } else if ($(child).hasClass('NB-listen-run')) {
                // listen_follow_along.js: Already wrapped by an earlier mapping of this content.
                flush();
                blocks.push({ el: child, key: this.match_key(this.inline_text(child)) });
            } else if (this.is_skipped(child) || this.contains_embed(child)) {
                flush();
            } else if (tag === 'br') {
                run.push(child);
                run_text += ' ';
            } else if (_.contains(this.BLOCK_TAGS, tag) && !this.has_block_descendant(child)) {
                flush();
                var text = this.normalize(this.inline_text(child));
                if (text) blocks.push({ el: child, key: this.match_key(text) });
            } else if (_.contains(this.BLOCK_TAGS, tag) || _.contains(this.CONTAINER_TAGS, tag) ||
                this.has_block_descendant(child)) {
                flush();
                this.walk(child, blocks, root);
            } else {
                run.push(child);
                run_text += this.inline_text(child);
            }
        }, this);
        flush();
    },

    // =============
    // = Scrolling =
    // =============

    bind_scroll_tracking: function () {
        if (this.scroll_tracking_bound) return;
        this.scroll_tracking_bound = true;
        var self = this;
        var mark = function () {
            if (Date.now() < self.programmatic_scroll_until) return;
            self.last_user_scroll_at = Date.now();
        };
        document.addEventListener('wheel', mark, { capture: true, passive: true });
        document.addEventListener('touchmove', mark, { capture: true, passive: true });
        document.addEventListener('keydown', function (e) {
            var scroll_keys = ['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown', 'Home', 'End', ' '];
            if (_.contains(scroll_keys, e.key)) mark();
        }, true);
    },

    user_is_scrolling: function () {
        return Date.now() - this.last_user_scroll_at < this.USER_SCROLL_QUIET_MS;
    },

    scroll_container: function (el) {
        var node = el.parentNode;
        while (node && node !== document.body && node.nodeType === 1) {
            var overflow = window.getComputedStyle(node).overflowY;
            if ((overflow === 'auto' || overflow === 'scroll') && node.scrollHeight > node.clientHeight + 1) {
                return node;
            }
            node = node.parentNode;
        }
        return null;
    },

    // listen_follow_along.js: Only scrolls when the highlight is off screen and the reader isn't
    // scrolling themselves, and then only enough to bring it into the upper third.
    scroll_into_view: function (el) {
        if (this.user_is_scrolling()) return false;
        var container = this.scroll_container(el);
        if (!container) return false;
        var container_rect = container.getBoundingClientRect();
        var rect = el.getBoundingClientRect();
        var margin = this.SCROLL_MARGIN;
        if (rect.top >= container_rect.top + margin && rect.bottom <= container_rect.bottom - margin) return true;
        if (rect.top >= container_rect.top + margin && rect.height > container_rect.height - 2 * margin &&
            rect.top < container_rect.bottom - margin) return true;

        var target = container.scrollTop + (rect.top - container_rect.top) - container.clientHeight * 0.3;
        target = Math.max(0, Math.min(target, container.scrollHeight - container.clientHeight));
        this.programmatic_scroll_until = Date.now() + 900;
        // listen_follow_along.js: The flag keeps story_list_view.js from selecting (and marking
        // read) whatever story scrolls past during the animation.
        var reader = NEWSBLUR.reader;
        if (reader && reader.flags) reader.flags.scrolling_by_selecting_story_title = true;
        $(container).stop(true).animate({ scrollTop: target }, {
            duration: 600,
            easing: 'easeInOutQuad',
            complete: function () {
                _.delay(function () {
                    if (reader && reader.flags) reader.flags.scrolling_by_selecting_story_title = false;
                }, 100);
            }
        });
        return true;
    },

    // ==========
    // = Clicks =
    // ==========

    // listen_follow_along.js: Returns true when the click jumped playback, so the caller can skip
    // its own handling.
    JUMP_DELAY_MS: 280,

    handle_click: function (view, e) {
        // listen_follow_along.js: The second click of a double-click (selecting a word) cancels
        // the jump the first click scheduled.
        if (e.detail > 1) {
            this.cancel_pending_jump();
            return false;
        }
        if (!this.story_hash || !this.is_playing) return false;
        if (!view.model || view.model.get('story_hash') !== this.story_hash) return false;
        if ($(e.target).closest('a, button, input, textarea, video, audio, iframe').length) return false;
        // listen_follow_along.js: Saved highlights open their own menu.
        if ($(e.target).closest('.NB-highlight, .NB-starred-story-selection-highlight').length) return false;
        if (this.has_selection()) return false;
        var $paragraph = $(e.target).closest('.NB-listen-paragraph');
        if (!$paragraph.length) return false;
        var paragraph_index = parseInt($paragraph.attr('data-listen-paragraph'), 10);
        if (isNaN(paragraph_index) || !NEWSBLUR.app.media_player) return false;

        this.cancel_pending_jump();
        this.pending_jump = setTimeout(_.bind(function () {
            this.pending_jump = null;
            if (!this.is_playing || this.has_selection()) return;
            NEWSBLUR.app.media_player.listen_jump_to_paragraph(paragraph_index);
        }, this), this.JUMP_DELAY_MS);
        return true;
    },

    has_selection: function () {
        var selection = window.getSelection && window.getSelection();
        return !!(selection && selection.toString().length > 0);
    },

    cancel_pending_jump: function () {
        if (this.pending_jump) {
            clearTimeout(this.pending_jump);
            this.pending_jump = null;
        }
    }

};
