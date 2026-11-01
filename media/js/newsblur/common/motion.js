// motion.js owns reader motion; model identity survives row re-renders and scrolling back.
NEWSBLUR.motion = (function () {
    var reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
    var running = new Map();
    var part_observers = new WeakMap();
    // motion.js snapshots rendered layout and paint, not hundreds of unrelated computed browser properties.
    var snapshot_properties = ('display position top right bottom left box-sizing width height min-width min-height max-width max-height ' +
        'margin-top margin-right margin-bottom margin-left padding-top padding-right padding-bottom padding-left ' +
        'border-top-width border-right-width border-bottom-width border-left-width border-top-style border-right-style border-bottom-style border-left-style ' +
        'border-top-color border-right-color border-bottom-color border-left-color border-radius ' +
        'font-family font-size font-weight font-style line-height letter-spacing text-align text-indent text-transform text-decoration ' +
        'white-space word-break overflow-wrap text-overflow overflow-x overflow-y color background-color background-image background-size ' +
        'background-position background-repeat opacity visibility align-items align-self justify-content justify-self flex-grow flex-shrink flex-basis ' +
        'flex-direction flex-wrap order row-gap column-gap grid-template-columns grid-template-rows grid-column grid-row ' +
        'float clear vertical-align object-fit object-position box-shadow transform transform-origin').split(' ');
    function play(element, frames, duration, delay, complete) {
        if (!element || !element.animate) { if (complete) complete(); return; }
        var previous = running.get(element);
        if (previous) previous.cancel();
        if (reduced.matches) { if (complete) complete(); return; }
        var animation = element.animate(frames, {
            duration: duration, delay: delay || 0, fill: 'backwards',
            easing: 'cubic-bezier(.2,.75,.3,1)'
        });
        running.set(element, animation);
        function finished() {
            if (running.get(element) === animation) running.delete(element);
            if (complete) { var callback = complete; complete = null; callback(); }
        }
        animation.onfinish = finished;
        animation.oncancel = finished;
        return animation;
    }
    function exit(element, complete) {
        return play(element, [{ opacity: 1, transform: 'translateY(0)' },
            { opacity: 0, transform: 'translateY(-8px)' }], 220, 0, complete);
    }
    function depart(element, options) {
        if (reduced.matches || !element || !element.getClientRects().length) return;
        var rect = element.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        // motion.js clips the outgoing drawing to the original scroll viewport.
        var clip = { top: 0, left: 0, right: window.innerWidth, bottom: window.innerHeight };
        for (var parent = element.parentElement; parent && parent !== document.body; parent = parent.parentElement) {
            if (/(auto|scroll|hidden|clip)/.test(getComputedStyle(parent).overflow)) {
                var bounds = parent.getBoundingClientRect();
                clip.top = Math.max(clip.top, bounds.top); clip.left = Math.max(clip.left, bounds.left);
                clip.right = Math.min(clip.right, bounds.right); clip.bottom = Math.min(clip.bottom, bounds.bottom);
            }
        }
        // motion.js freezes only visible title rows, so reparenting cannot lose the pane's layout selectors.
        function copy_style(source, target) {
            var style = getComputedStyle(source);
            snapshot_properties.forEach(function (name) {
                var value = style.getPropertyValue(name);
                if (value) target.style.setProperty(name, value);
            });
            target.style.animation = 'none';
            target.style.transition = 'none';
        }
        function copy_rendered(source) {
            var copy = source.cloneNode(false);
            if (source.nodeType !== 1) return copy;
            if (!source.getClientRects().length) { copy.style.display = 'none'; return copy; }
            copy_style(source, copy);
            Array.from(source.childNodes).forEach(function (child) { copy.appendChild(copy_rendered(child)); });
            return copy;
        }
        var snapshot_layout = options && options.snapshot_layout;
        var ghost = element.cloneNode(!snapshot_layout);
        if (snapshot_layout) {
            copy_style(element, ghost);
            var border_left = parseFloat(ghost.style.borderLeftWidth) || 0;
            var border_top = parseFloat(ghost.style.borderTopWidth) || 0;
            Array.from(element.children).forEach(function (child) {
                var bounds = child.getBoundingClientRect();
                if (!child.getClientRects().length || bounds.bottom <= clip.top || bounds.top >= clip.bottom ||
                    bounds.right <= clip.left || bounds.left >= clip.right) return;
                var copy = copy_rendered(child);
                // motion.js pins rows in place even when offscreen rows above them are omitted from the snapshot.
                Object.assign(copy.style, { position: 'absolute', margin: 0, boxSizing: 'border-box',
                    left: (bounds.left - rect.left - border_left) + 'px', top: (bounds.top - rect.top - border_top) + 'px',
                    width: bounds.width + 'px', height: bounds.height + 'px', transform: 'none' });
                ghost.appendChild(copy);
            });
        }
        // motion.js removes live layout immediately; the inert copy cannot capture focus or clicks.
        ghost.removeAttribute('id');
        ghost.querySelectorAll('[id]').forEach(function (node) { node.removeAttribute('id'); });
        ghost.setAttribute('aria-hidden', 'true');
        ghost.inert = true;
        Object.assign(ghost.style, { position: 'fixed', left: rect.left + 'px', top: rect.top + 'px',
            width: rect.width + 'px', height: rect.height + 'px', margin: 0, boxSizing: 'border-box',
            pointerEvents: 'none', overflow: 'hidden', zIndex: 1100 });
        ghost.style.clipPath = 'inset(' + [Math.max(0, clip.top - rect.top), Math.max(0, rect.right - clip.right),
            Math.max(0, rect.bottom - clip.bottom), Math.max(0, clip.left - rect.left)].map(function (n) { return n + 'px'; }).join(' ') + ')';
        document.body.appendChild(ghost);
        exit(ghost, function () { ghost.remove(); });
    }
    function remove(elements) {
        Array.from(elements).forEach(function (element) { depart(element); element.remove(); });
    }
    function enter(element, delay, distance) {
        distance = distance === undefined ? 16 : distance;
        play(element, [
            { opacity: 0, transform: 'translateY(' + distance + 'px)' },
            { opacity: 1, transform: 'translateY(-1px)', offset: .75 },
            { opacity: 1, transform: 'translateY(0)' }
        ], 350, delay);
    }
    function screen_order(elements) {
        return elements.map(function (element, index) {
            return { element: element, rect: element.getBoundingClientRect(), index: index };
        }).sort(function (a, b) {
            return a.rect.top - b.rect.top || a.rect.left - b.rect.left || a.index - b.index;
        }).map(function (item) { return item.element; });
    }
    function stagger_delay(index, count, spacing, spread) {
        var step = count > 1 ? Math.min(spacing, spread / (count - 1)) : 0;
        return Math.min(index * step, spread);
    }
    function cascade(elements, distance) {
        var visible = screen_order(Array.from(elements).filter(function (el) { return visible_in_root(el, null); }));
        visible.forEach(function (el, index) { enter(el, stagger_delay(index, visible.length, 30, 180), distance); });
    }
    function pop(element) {
        play(element, [
            { transform: 'scale(1)' }, { transform: 'scale(.86)', offset: .2 },
            { transform: 'scale(1.14) rotate(-4deg)', offset: .6 }, { transform: 'scale(1)' }
        ], 330);
    }
    function article(element) {
        cascade(element.querySelectorAll('.NB-feed-story-title-container, .NB-feed-story-date, .NB-feed-story-author-wrapper, .NB-feed-story-content'), 9);
        article_parts(element);
    }
    function article_parts(element) {
        return watch_parts(element, '.NB-sideoption, .NB-story-comments-label, .NB-story-share-label, ' +
            '.NB-story-share-profiles .NB-user-avatar, .NB-story-comments-public-header, .NB-story-comments-public-teaser, ' +
            '.NB-story-comment, .NB-story-cluster-detail-header, .NB-story-cluster-detail-item, .NB-cluster-locked-upsell, ' +
            '.NB-sideoption-share-title, .NB-sideoption-share-comments, .NB-sideoption-share-save, .NB-sideoption-share-unshare');
    }
    function watch_parts(element, selector) {
        var existing = part_observers.get(element);
        if (existing) { existing.refresh(); return existing; }
        var states = new Map();
        var connected = true;
        var observer = typeof IntersectionObserver === 'function' ? new IntersectionObserver(refresh, { threshold: 0 }) : null;
        var frame = null;
        var mutations = typeof MutationObserver === 'function' ? new MutationObserver(schedule) : null;
        function schedule() {
            if (!connected || frame !== null) return;
            frame = requestAnimationFrame(function () { frame = null; refresh(); });
        }
        function signature(node) {
            // motion.js tracks labels and semantic states, never hover, highlight, or layout-only class changes.
            var flags = (node.className || '').split(/\s+/).filter(function (name) {
                return /^(NB-disabled|NB-active|NB-listen-playing|NB-listen-queued)$/.test(name);
            }).sort().join(' ');
            return [node.textContent.trim(), flags, node.getAttribute('disabled'),
                node.getAttribute('aria-pressed'), node.getAttribute('aria-expanded')].join('|');
        }
        function identity(node, counts) {
            var key = node.getAttribute('data-motion-key');
            if (key) return key;
            var control = (node.className || '').split(/\s+/).find(function (name) {
                return /^(NB-feed-story-(email|train|save|share|discover|ask-ai|listen)|NB-sideoption-sharing-.+|NB-task-story-(previous|next|next-unread)|task_view_.+)$/.test(name);
            });
            if (control) return control;
            var kind = selector.split(',').find(function (part) { return node.matches(part.trim()); }) || selector;
            var index = counts.get(kind) || 0;
            counts.set(kind, index + 1);
            return kind + ':' + index;
        }
        function refresh() {
            if (!connected) return;
            var nodes = Array.from(element.querySelectorAll(selector));
            var current = new Set();
            var counts = new Map();
            var arriving = [];
            nodes.forEach(function (node) {
                var key = identity(node, counts);
                current.add(key);
                var state = states.get(key);
                if (!state) {
                    state = { shown: false, signature: null, node: null };
                    states.set(key, state);
                }
                if (state.node !== node) {
                    if (observer && state.node) observer.unobserve(state.node);
                    state.node = node;
                    if (observer) observer.observe(node);
                }
                // motion.js distinguishes a closed bar from controls merely outside the scroll viewport.
                if (!node.getClientRects().length) { state.shown = false; return; }
                if (!visible_in_root(node, null, true)) return;
                var value = signature(node);
                if (!state.shown || state.signature !== value) arriving.push(node);
                state.shown = true;
                state.signature = value;
            });
            states.forEach(function (state, key) {
                if (!current.has(key)) { if (observer) observer.unobserve(state.node); states.delete(key); }
            });
            screen_order(arriving).forEach(function (node, index) {
                enter(node, stagger_delay(index, arriving.length, 30, 150), 7);
            });
        }
        var controller = { refresh: refresh, disconnect: function () {
            connected = false;
            if (frame !== null) cancelAnimationFrame(frame);
            frame = null;
            if (observer) observer.disconnect();
            if (mutations) mutations.disconnect();
            states.clear();
        } };
        part_observers.set(element, controller);
        if (mutations) mutations.observe(element, { childList: true, subtree: true, characterData: true,
            attributes: true, attributeFilter: ['class', 'style', 'hidden', 'disabled', 'aria-pressed', 'aria-expanded'] });
        refresh();
        return controller;
    }
    function unwatch_parts(element) {
        var controller = part_observers.get(element);
        if (controller) controller.disconnect();
        part_observers.delete(element);
    }
    function refresh_completed(element) {
        if (!element || reduced.matches) return;
        var rect = element.getBoundingClientRect();
        var check = document.createElement('span');
        check.className = 'NB-motion-refresh-check';
        check.textContent = '✓';
        check.setAttribute('aria-hidden', 'true');
        check.style.left = (rect.left + rect.width / 2 - 14) + 'px';
        check.style.top = (rect.top + rect.height / 2 - 14) + 'px';
        document.body.appendChild(check);
        play(check, [{ opacity: 0, transform: 'scale(.6)' },
            { opacity: 1, transform: 'scale(1.15)', offset: .35 },
            { opacity: 1, transform: 'scale(1)', offset: .7 }, { opacity: 0 }], 600);
        setTimeout(function () { check.remove(); }, 650);
    }
    function visible_in_root(element, root, ignore_motion_opacity) {
        if (!element.isConnected || !element.getClientRects().length) return false;
        var rect = element.getBoundingClientRect();
        var clip = { top: 0, left: 0, right: window.innerWidth, bottom: window.innerHeight };
        function intersects() {
            return clip.right > clip.left && clip.bottom > clip.top && rect.width > 0 && rect.height > 0 && rect.bottom > clip.top && rect.top < clip.bottom &&
                rect.right > clip.left && rect.left < clip.right;
        }
        function hidden(style, node) {
            return style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse' ||
                (style.opacity === '0' && !(ignore_motion_opacity && running.has(node)));
        }
        if (root) {
            if (!root.getClientRects().length || hidden(getComputedStyle(root), root)) return false;
            var bounds = root.getBoundingClientRect();
            clip.top = Math.max(clip.top, bounds.top); clip.bottom = Math.min(clip.bottom, bounds.bottom);
            clip.left = Math.max(clip.left, bounds.left); clip.right = Math.min(clip.right, bounds.right);
        }
        if (!intersects()) return false;
        for (var node = element; node; node = node.parentElement) {
            var style = getComputedStyle(node);
            if (hidden(style, node)) return false;
            // motion.js already clips the document to the viewport; NewsBlur's absolute layout leaves body with zero height.
            if (node === element || node === document.body || node === document.documentElement) continue;
            var clips_x = /(auto|scroll|hidden|clip)/.test(style.overflowX);
            var clips_y = /(auto|scroll|hidden|clip)/.test(style.overflowY);
            if (!clips_x && !clips_y) continue;
            var bounds = node.getBoundingClientRect();
            if (clips_x) { clip.left = Math.max(clip.left, bounds.left); clip.right = Math.min(clip.right, bounds.right); }
            if (clips_y) { clip.top = Math.max(clip.top, bounds.top); clip.bottom = Math.min(clip.bottom, bounds.bottom); }
            if (!intersects()) return false;
        }
        return true;
    }
    function watch(owner, records, root, scope, options) {
        options = options || {};
        if (!window.IntersectionObserver) return;
        if (!owner.motion_seen || owner.motion_scope !== scope) {
            if (owner.motion_observer) owner.motion_observer.disconnect();
            owner.motion_seen = new Set();
            owner.motion_scrolled = false;
            owner.motion_scope = scope;
            owner.motion_observer = null;
        }
        if (owner.motion_observer && owner.motion_root !== root) {
            owner.motion_observer.disconnect();
            owner.motion_observer = null;
        }
        if (!owner.motion_observer) {
            var pending = new Map();
            var entered = new Set();
            var last_scroll_top = root ? root.scrollTop : window.scrollY;
            var scroll_target = root || window;
            var listening = false;
            var frame = null;
            function reveal(scrolling) {
                var scroll_top = root ? root.scrollTop : window.scrollY;
                var scroll_changed = scroll_top !== last_scroll_top;
                scrolling = scrolling || scroll_changed;
                last_scroll_top = scroll_top;
                // motion.js ignores queued scroll-reset events already reflected when this feed's observer started.
                if (scroll_changed && options.animate_on_scroll === false) {
                    // motion.js ends title entrances for this feed visit, including pages arriving after scrolling stops.
                    owner.motion_scrolled = true;
                    entered.forEach(function (element) {
                        var animation = running.get(element);
                        if (animation) animation.cancel();
                    });
                    entered.clear();
                }
                // motion.js reads the whole visible batch before animation writes can change its geometry.
                var visible = screen_order(Array.from(pending.values()).filter(function (element) {
                    if (!element.isConnected) { controller.unobserve(element); return false; }
                    return visible_in_root(element, root);
                }));
                visible.forEach(function (element, index) {
                    var key = element.nb_motion_key;
                    controller.unobserve(element);
                    if (owner.motion_seen.has(key)) return;
                    owner.motion_seen.add(key);
                    if (owner.motion_scrolled && options.animate_on_scroll === false) return;
                    enter(element, stagger_delay(index, visible.length, options.spacing || 35, scrolling ? 90 : (options.spread || 175)), scrolling ? 8 : (options.distance || 16));
                    if (options.animate_on_scroll === false) entered.add(element);
                });
            }
            function on_scroll() { reveal(true); }
            var observer = new IntersectionObserver(function (entries) {
                if (owner.motion_observer !== controller) return;
                if (entries.some(function (entry) { return entry.isIntersecting; })) reveal();
            }, { root: root || null, threshold: 0 });
            var controller = {
                observe: function (element) {
                    var previous = pending.get(element.nb_motion_key);
                    if (previous && previous !== element) observer.unobserve(previous);
                    pending.set(element.nb_motion_key, element);
                    observer.observe(element);
                    // motion.js captures nested form scrolling as well as the containing pane's own scroll.
                    if (!listening) { scroll_target.addEventListener('scroll', on_scroll, { passive: true, capture: true }); listening = true; }
                },
                unobserve: function (element) {
                    pending.delete(element.nb_motion_key);
                    observer.unobserve(element);
                },
                disconnect: function () {
                    observer.disconnect();
                    pending.clear();
                    entered.clear();
                    scroll_target.removeEventListener('scroll', on_scroll, true);
                    listening = false;
                    if (frame !== null) cancelAnimationFrame(frame);
                    frame = null;
                },
                reveal: reveal,
                before_paint: function () {
                    if (frame !== null) return;
                    frame = requestAnimationFrame(function () { frame = null; reveal(); });
                }
            };
            owner.motion_observer = controller;
            owner.motion_root = root;
        }
        records.forEach(function (record) {
            record.el.nb_motion_key = record.model.id || record.model.cid;
            if (!owner.motion_seen.has(record.el.nb_motion_key)) owner.motion_observer.observe(record.el);
        });
        // motion.js starts inserted rows before their first paint; the next frame catches synchronous pane/layout changes.
        owner.motion_observer.reveal();
        owner.motion_observer.before_paint();
    }
    reduced.addEventListener('change', function () {
        if (reduced.matches) { running.forEach(function (animation) { animation.cancel(); }); running.clear(); }
    });
    $(document).on('click.nb-motion', '.NB-feed-story-save, .NB-feedbar-mark-feed-read, .NB-taskbar .NB-taskbar-button, .NB-storytitles-sentiment, .NB-feedlist-collapse-icon, .NB-intelligence-slider-control, .NB-feed-story-train, .NB-search-icon', function () { pop(this); });
    return { enter: enter, exit: exit, depart: depart, remove: remove, cascade: cascade, pop: pop, article: article,
        article_parts: article_parts, watch_parts: watch_parts, unwatch_parts: unwatch_parts, watch: watch, refresh_completed: refresh_completed,
        duration: function (milliseconds) { return reduced.matches ? 0 : milliseconds; } };
})();
