// motion.js owns reader motion; model identity survives row re-renders and scrolling back.
NEWSBLUR.motion = (function () {
    var reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
    var running = new Map();
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
    function depart(element) {
        if (reduced.matches || !element || !element.getClientRects().length) return;
        var rect = element.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        // motion.js removes live layout immediately; the inert copy cannot capture focus or clicks.
        var ghost = element.cloneNode(true);
        ghost.removeAttribute('id');
        ghost.querySelectorAll('[id]').forEach(function (node) { node.removeAttribute('id'); });
        ghost.setAttribute('aria-hidden', 'true');
        ghost.inert = true;
        Object.assign(ghost.style, { position: 'fixed', left: rect.left + 'px', top: rect.top + 'px',
            width: rect.width + 'px', height: rect.height + 'px', margin: 0, boxSizing: 'border-box',
            pointerEvents: 'none', overflow: 'hidden', zIndex: 1100 });
        // motion.js clips the outgoing drawing to the original scroll viewport.
        var clip = { top: 0, left: 0, right: window.innerWidth, bottom: window.innerHeight };
        for (var parent = element.parentElement; parent && parent !== document.body; parent = parent.parentElement) {
            if (/(auto|scroll|hidden|clip)/.test(getComputedStyle(parent).overflow)) {
                var bounds = parent.getBoundingClientRect();
                clip.top = Math.max(clip.top, bounds.top); clip.left = Math.max(clip.left, bounds.left);
                clip.right = Math.min(clip.right, bounds.right); clip.bottom = Math.min(clip.bottom, bounds.bottom);
            }
        }
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
        cascade(element.querySelectorAll('.NB-feed-story-title-container, .NB-feed-story-date, .NB-feed-story-author-wrapper, .NB-story-content-wrapper, .NB-feed-story-sideoptions'), 9);
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
    function visible_in_root(element, root) {
        if (!element.isConnected || !element.getClientRects().length) return false;
        var rect = element.getBoundingClientRect();
        var clip = { top: 0, left: 0, right: window.innerWidth, bottom: window.innerHeight };
        function intersects() {
            return clip.right > clip.left && clip.bottom > clip.top && rect.width > 0 && rect.height > 0 && rect.bottom > clip.top && rect.top < clip.bottom &&
                rect.right > clip.left && rect.left < clip.right;
        }
        function hidden(style) {
            return style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse' || style.opacity === '0';
        }
        if (root) {
            if (!root.getClientRects().length || hidden(getComputedStyle(root))) return false;
            var bounds = root.getBoundingClientRect();
            clip.top = Math.max(clip.top, bounds.top); clip.bottom = Math.min(clip.bottom, bounds.bottom);
            clip.left = Math.max(clip.left, bounds.left); clip.right = Math.min(clip.right, bounds.right);
        }
        if (!intersects()) return false;
        for (var node = element; node; node = node.parentElement) {
            var style = getComputedStyle(node);
            if (hidden(style)) return false;
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
            owner.motion_scope = scope;
            owner.motion_observer = null;
        }
        if (owner.motion_observer && owner.motion_root !== root) {
            owner.motion_observer.disconnect();
            owner.motion_observer = null;
        }
        if (!owner.motion_observer) {
            var pending = new Map();
            var last_scroll_top = root ? root.scrollTop : window.scrollY;
            var scroll_target = root || window;
            var listening = false;
            var frame = null;
            function reveal(scrolling) {
                var scroll_top = root ? root.scrollTop : window.scrollY;
                scrolling = scrolling || scroll_top !== last_scroll_top;
                last_scroll_top = scroll_top;
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
                    enter(element, stagger_delay(index, visible.length, options.spacing || 35, scrolling ? 90 : (options.spread || 175)), scrolling ? 8 : (options.distance || 16));
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
    return { enter: enter, exit: exit, depart: depart, remove: remove, cascade: cascade, pop: pop, article: article, watch: watch, refresh_completed: refresh_completed,
        duration: function (milliseconds) { return reduced.matches ? 0 : milliseconds; } };
})();
