// motion.js owns reader motion; model identity survives row re-renders and scrolling back.
NEWSBLUR.motion = (function () {
    var reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
    var running = new Map();
    var part_observers = new WeakMap();
    function preference(name) {
        // motion.js also runs before assetmodel.js initializes, when template preferences are already available.
        var value = NEWSBLUR.assets && typeof NEWSBLUR.assets.preference === 'function' ?
            NEWSBLUR.assets.preference(name) : undefined;
        if (value === undefined && NEWSBLUR.Preferences) value = NEWSBLUR.Preferences[name];
        return value;
    }
    function animations_enabled() {
        var value = preference('animations');
        return value !== false && value !== 0;
    }
    function reduce_motion() {
        var value = preference('reduce_motion');
        return reduced.matches || value === true || value === 1;
    }
    function opacity_frames(frames) {
        return frames.map(function (frame) {
            var result = Object.assign({}, frame);
            delete result.transform;
            return result;
        });
    }
    function preference_changed() {
        running.forEach(function (animation) {
            if (!animations_enabled()) animation.cancel();
            else if (reduce_motion() && animation.effect) {
                // motion.js removes movement from the existing timeline without restarting or cancelling its fade.
                animation.effect.setKeyframes(opacity_frames(animation.effect.getKeyframes()));
            }
        });
    }
    // motion.js snapshots rendered layout and paint, not hundreds of unrelated computed browser properties.
    var snapshot_properties = ('display position top right bottom left z-index box-sizing width height min-width min-height max-width max-height ' +
        'margin-top margin-right margin-bottom margin-left padding-top padding-right padding-bottom padding-left ' +
        'border-top-width border-right-width border-bottom-width border-left-width border-top-style border-right-style border-bottom-style border-left-style ' +
        'border-top-color border-right-color border-bottom-color border-left-color border-radius ' +
        'font-family font-size font-weight font-style line-height letter-spacing text-align text-indent text-transform text-decoration ' +
        'white-space word-break overflow-wrap text-overflow overflow-x overflow-y color background-color background-image background-size ' +
        'background-position background-repeat opacity visibility align-items align-self justify-content justify-self flex-grow flex-shrink flex-basis ' +
        'flex-direction flex-wrap order row-gap column-gap grid-template-columns grid-template-rows grid-column grid-row ' +
        'float clear vertical-align object-fit object-position box-shadow transform transform-origin -webkit-line-clamp -webkit-box-orient').split(' ');
    function play(element, frames, duration, delay, complete) {
        if (!element || !element.animate) { if (complete) complete(); return; }
        var previous = running.get(element);
        if (previous) previous.cancel();
        if (!animations_enabled()) { if (complete) complete(); return; }
        var animation = element.animate(reduce_motion() ? opacity_frames(frames) : frames, {
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
        if (!animations_enabled() || !element || !element.getClientRects().length) return;
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
        function intersects(bounds) {
            return bounds.bottom > clip.top && bounds.top < clip.bottom && bounds.right > clip.left && bounds.left < clip.right;
        }
        function within(bounds) {
            return bounds.top >= clip.top && bounds.bottom <= clip.bottom && bounds.left >= clip.left && bounds.right <= clip.right;
        }
        function run_bounds(nodes) {
            var range = document.createRange();
            range.setStartBefore(nodes[0]);
            range.setEndAfter(nodes[nodes.length - 1]);
            return range.getBoundingClientRect();
        }
        // motion.js splits a box's children into blocks and runs of text and inline elements, each laid out on
        // its own. It returns null when that would change the drawing: lines wrapping around floats, an ordered
        // list numbering the items left out, or inline content in a flex or grid box.
        function parts_of(source, display) {
            if (source.nodeName === 'OL') return null;
            var parts = [], run = null, floats = false, runs = false;
            for (var index = 0; index < source.childNodes.length; index++) {
                var child = source.childNodes[index];
                if (child.nodeType === 1) {
                    var style = getComputedStyle(child);
                    if (style.display === 'none') continue;
                    if (style.display === 'contents') return null;
                    if (/^(block|flow-root|list-item|flex|grid|table)$/.test(style.display)) {
                        floats = floats || style.float !== 'none';
                        parts.push({ block: child });
                        run = null;
                        continue;
                    }
                } else if (child.nodeType !== 3 || !/\S/.test(child.nodeValue)) {
                    // motion.js drops comments and the whitespace between blocks, which draw nothing.
                    if (run) run.nodes.push(child);
                    continue;
                }
                if (!run) { run = { nodes: [] }; parts.push(run); runs = true; }
                run.nodes.push(child);
            }
            if (runs && (floats || !/^(block|flow-root|list-item|inline-block|table-cell)$/.test(display))) return null;
            return parts;
        }
        // motion.js pins rows in place even when offscreen rows above them are omitted from the snapshot.
        function pin(child, copy, bounds, child_bounds) {
            var child_copy = copy_rendered(child, child_bounds);
            stuck = stuck.filter(function (item) { return item.copy !== child_copy; });
            Object.assign(child_copy.style, { position: 'absolute', margin: 0, boxSizing: 'border-box',
                left: (child_bounds.left - bounds.left - (parseFloat(copy.style.borderLeftWidth) || 0)) + 'px',
                top: (child_bounds.top - bounds.top - (parseFloat(copy.style.borderTopWidth) || 0)) + 'px',
                width: child_bounds.width + 'px', height: child_bounds.height + 'px', transform: 'none' });
            copy.appendChild(child_copy);
        }
        function pin_children(source, copy, bounds) {
            Array.from(source.children).forEach(function (child) {
                var child_bounds = child.getBoundingClientRect();
                if (child.getClientRects().length && intersects(child_bounds)) pin(child, copy, bounds, child_bounds);
            });
        }
        // motion.js copies only the parts of a long story that are on screen: visible blocks are pinned in place
        // and each visible run of text flows in a box as wide as the original, moved onto its first line once drawn.
        var runs = [];
        function pin_parts(source, copy, bounds, parts) {
            var padding_left = parseFloat(copy.style.paddingLeft) || 0;
            var padding_right = parseFloat(copy.style.paddingRight) || 0;
            parts.forEach(function (part, index) {
                if (part.block) {
                    var child_bounds = part.block.getBoundingClientRect();
                    if (part.block.getClientRects().length && intersects(child_bounds)) pin(part.block, copy, bounds, child_bounds);
                    return;
                }
                var live = run_bounds(part.nodes);
                if (!intersects(live)) return;
                // motion.js uses its own element name so story stylesheet rules for divs cannot reach the box.
                var box = document.createElement('nb-motion-run');
                part.nodes.forEach(function (node) { box.appendChild(copy_rendered(node)); });
                Object.assign(box.style, { display: 'block', position: 'absolute', margin: 0, padding: 0, border: 0,
                    left: padding_left + 'px', width: (source.clientWidth - padding_left - padding_right) + 'px',
                    top: (live.top - bounds.top) + 'px' });
                if (index) box.style.textIndent = '0px';
                copy.appendChild(box);
                runs.push({ box: box, container: copy, offset: live.top - bounds.top });
            });
        }
        // motion.js pins sticky parts, like a Feed view story's header bar, where they were stuck rather than
        // where they sit in the flow, since the copy's own box never scrolls.
        var stuck = [];
        function copy_rendered(source, bounds) {
            // motion.js draws embedded media as an empty box of the same size, since a copied iframe or video
            // would load, and could play, its source again.
            var media = /^(IFRAME|VIDEO|AUDIO|OBJECT|EMBED)$/.test(source.nodeName);
            var copy = media ? document.createElement('div') : source.cloneNode(false);
            if (source.nodeType !== 1) return copy;
            if (!source.getClientRects().length) { copy.style.display = 'none'; return copy; }
            copy_style(source, copy);
            bounds = bounds || source.getBoundingClientRect();
            if (copy.style.position === 'sticky') {
                stuck.push({ copy: copy, bounds: bounds });
                Object.assign(copy.style, { position: 'relative', top: '0px', left: '0px', right: 'auto', bottom: 'auto' });
            }
            if (media) {
                // motion.js keeps the media's box: an inline div would ignore the width and height it copied.
                if (copy.style.display === 'inline') copy.style.display = 'inline-block';
                return copy;
            }
            // motion.js copies a box whole unless it is taller than the visible area, like a long story: a row
            // that merely runs past the edge is cheap to copy and keeps every detail, like a floated thumbnail.
            var taller = bounds.height > clip.bottom - clip.top;
            var parts = taller && !within(bounds) && source.children.length ? parts_of(source, copy.style.display) : null;
            if (parts) {
                if (copy.style.position === 'static') copy.style.position = 'relative';
                pin_parts(source, copy, bounds, parts);
                return copy;
            }
            Array.from(source.childNodes).forEach(function (child) { copy.appendChild(copy_rendered(child)); });
            return copy;
        }
        var snapshot_layout = options && options.snapshot_layout;
        var ghost = element.cloneNode(!snapshot_layout);
        if (snapshot_layout) {
            copy_style(element, ghost);
            pin_children(element, ghost, rect);
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
        // motion.js reads every place before moving anything, so each pass lays the ghost out once. A run of
        // text moves by the gap between its first line here and in the original, measured from its own box.
        runs.map(function (run) {
            return run.offset - (run_bounds(Array.from(run.box.childNodes)).top - run.container.getBoundingClientRect().top);
        }).forEach(function (shift, index) {
            runs[index].box.style.top = (parseFloat(runs[index].box.style.top) + shift) + 'px';
        });
        stuck.map(function (item) { return item.copy.getBoundingClientRect(); }).forEach(function (resting, index) {
            var item = stuck[index];
            item.copy.style.top = (item.bounds.top - resting.top) + 'px';
            item.copy.style.left = (item.bounds.left - resting.left) + 'px';
        });
        exit(ghost, function () { ghost.remove(); });
    }
    function remove(elements) {
        Array.from(elements).forEach(function (element) { depart(element); element.remove(); });
    }
    function enter(element, delay, distance, duration) {
        distance = distance === undefined ? 16 : distance;
        play(element, [
            { opacity: 0, transform: 'translateY(' + distance + 'px)' },
            { opacity: 1, transform: 'translateY(-1px)', offset: .75 },
            { opacity: 1, transform: 'translateY(0)' }
        ], duration === undefined ? 350 : duration, delay);
    }
    function screen_order(elements, horizontal_direction) {
        return elements.map(function (element, index) {
            return { element: element, rect: element.getBoundingClientRect(), index: index };
        }).sort(function (a, b) {
            if (horizontal_direction) {
                return (horizontal_direction === 'rtl' ? b.rect.right - a.rect.right : a.rect.left - b.rect.left) || a.index - b.index;
            }
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
    // motion.js times stories joining a list from the new stories pill with the same numbers as iOS
    // (NewStoriesPill.swift) and Android (NewStoriesPill.kt): each row takes 320ms, and the rows start 70ms apart
    // unless that would spread them over more than 400ms.
    var ARRIVAL_DURATION = 320;
    var ARRIVAL_STAGGER = 70;
    var ARRIVAL_SPREAD = 400;
    var ARRIVAL_EASING = 'cubic-bezier(.22,1,.36,1)';
    function arrival_step(count) {
        return count > 1 ? Math.min(ARRIVAL_STAGGER, ARRIVAL_SPREAD / (count - 1)) : 0;
    }
    function arrival_animation(element, frames, duration, delay, finished) {
        var previous = running.get(element);
        if (previous) previous.cancel();
        var animation = element.animate(frames, {
            duration: duration, delay: delay, fill: 'backwards', easing: ARRIVAL_EASING
        });
        running.set(element, animation);
        function done() {
            if (running.get(element) === animation) running.delete(element);
            if (finished) { var callback = finished; finished = null; callback(); }
        }
        animation.addEventListener('finish', done);
        animation.addEventListener('cancel', done);
        return animation;
    }
    // motion.js grows each row from nothing at its place while its content slides down from above the row's top
    // edge, so the rows below are pushed down as it opens and nothing is drawn over the rows above. The lowest new
    // row starts first.
    function unfold_rows(rows, step) {
        var heights = rows.map(function (row) { return row.offsetHeight; });
        rows.forEach(function (row, index) {
            var height = heights[index];
            var delay = (rows.length - 1 - index) * step;
            row.style.overflow = 'hidden';
            arrival_animation(row, [{ height: '0px', opacity: 0 }, { height: height + 'px', opacity: 1 }],
                ARRIVAL_DURATION, delay, function () { row.style.overflow = ''; });
            Array.from(row.children).forEach(function (child) {
                arrival_animation(child, [{ transform: 'translateY(' + (-height) + 'px)' },
                    { transform: 'translateY(0)' }], ARRIVAL_DURATION, delay);
            });
        });
    }
    // motion.js drops a grid's new cards in from above the list's top edge, lowest first, and moves each old card
    // from where it was drawn to its new cell in step with the new card that lands above it in its column, so the
    // column is pushed down as that card arrives. A card that changes column follows the first new card.
    function slide_cards(list, rows, before, step, edge) {
        var fresh = new Set(rows);
        var viewport_bottom = window.innerHeight;
        var arrivals = rows.map(function (card, index) {
            return { card: card, rect: card.getBoundingClientRect(), delay: (rows.length - 1 - index) * step };
        });
        Array.from(list.children).forEach(function (card) {
            var old = before.get(card);
            if (!old || fresh.has(card)) return;
            var now = card.getBoundingClientRect();
            var dx = old.left - now.left;
            var dy = old.top - now.top;
            var on_screen = (old.bottom > 0 && old.top < viewport_bottom) || (now.bottom > 0 && now.top < viewport_bottom);
            if ((!dx && !dy) || !on_screen) return;
            var above = _.max(_.filter(arrivals, function (arrival) {
                return Math.abs(arrival.rect.left - now.left) < 2 && arrival.rect.bottom <= now.top + 1;
            }), function (arrival) { return arrival.rect.bottom; });
            arrival_animation(card, [{ transform: 'translate(' + dx + 'px, ' + dy + 'px)' },
                { transform: 'translate(0, 0)' }], ARRIVAL_DURATION, _.isObject(above) ? above.delay : 0);
        });
        arrivals.forEach(function (arrival) {
            var rise = arrival.rect.bottom - edge;
            arrival_animation(arrival.card, [{ opacity: 0, transform: 'translateY(' + (-Math.max(rise, 0)) + 'px)' },
                { opacity: 1, transform: 'translateY(0)' }], ARRIVAL_DURATION, arrival.delay);
        });
    }
    // motion.js animates stories that insert() puts into a story list; insert() returns their rows in list order.
    // Stories joining the top of a list slide down into it; options.from_bottom has them rise into the end of an
    // oldest-first list instead. options.root is the pane that scrolls the list, if it isn't the page.
    function arrive(list, insert, options) {
        options = options || {};
        var moving = animations_enabled() && !reduce_motion();
        var grid = getComputedStyle(list).display.indexOf('grid') !== -1;
        var before = null;
        if (moving && grid && !options.from_bottom) {
            before = new Map();
            Array.from(list.children).forEach(function (card) { before.set(card, card.getBoundingClientRect()); });
        }
        var rows = insert();
        if (!rows.length || !animations_enabled()) return rows;
        if (!moving) {
            rows.forEach(function (row) { arrival_animation(row, [{ opacity: 0 }, { opacity: 1 }], 150, 0); });
            return rows;
        }
        var step = arrival_step(rows.length);
        if (options.from_bottom) {
            rows.forEach(function (row, index) {
                arrival_animation(row, [{ opacity: 0, transform: 'translateY(' + row.offsetHeight + 'px)' },
                    { opacity: 1, transform: 'translateY(0)' }], ARRIVAL_DURATION, index * step);
            });
        } else if (grid) {
            var edge = options.root ? options.root.getBoundingClientRect().top : list.getBoundingClientRect().top;
            slide_cards(list, rows, before, step, edge);
        } else {
            unfold_rows(rows, step);
        }
        return rows;
    }
    function article(element) {
        // motion.js enters every header item from story_detail_view.js without moving its nested children twice.
        cascade(element.querySelectorAll('.NB-feed-story-header-feed, .NB-feed-story-title-container, ' +
            '.NB-feed-story-show-changes, .NB-feed-story-date, .NB-feed-story-author-wrapper, ' +
            '.NB-feed-story-tags, .NB-feed-story-url-match, .NB-feed-story-ai-classifiers, ' +
            '.NB-feed-story-starred-date, .NB-feed-story-content'), 9);
        article_parts(element);
    }
    function article_parts(element, options) {
        return watch_parts(element, '.NB-sideoption, .NB-story-comments-label, .NB-story-share-label, ' +
            '.NB-story-share-profiles .NB-user-avatar, .NB-story-comments-public-header, .NB-story-comments-public-teaser, ' +
            '.NB-story-comment, .NB-story-cluster-detail-header, .NB-story-cluster-detail-item, .NB-cluster-locked-upsell, ' +
            '.NB-sideoption-share-title, .NB-sideoption-share-comments, .NB-sideoption-share-save, .NB-sideoption-share-unshare', options);
    }
    function feedbar_parts(element) {
        // motion.js combines header rebuilds and view changes into one horizontal cascade before paint.
        return watch_parts(element, '.NB-feedbar-options, .NB-story-title-search, .NB-feedbar-mark-feed-read-container, ' +
            '.NB-task-story-previous, .NB-task-story-next-unread, .NB-task-story-next', { horizontal: true, defer: true });
    }
    function watch_parts(element, selector, options) {
        if (!element) return;
        options = options || {};
        var existing = part_observers.get(element);
        if (existing) {
            existing.resume();
            if (options.defer) existing.schedule(); else existing.refresh(options);
            return existing;
        }
        var states = new Map();
        var connected = true;
        var observer = typeof IntersectionObserver === 'function' ? new IntersectionObserver(refresh, { threshold: 0 }) : null;
        var frame = null;
        var mutations = typeof MutationObserver === 'function' ? new MutationObserver(schedule) : null;
        function schedule() {
            if (!connected || frame !== null) return;
            frame = requestAnimationFrame(function () { frame = null; refresh(); });
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
        // motion.js can settle a resumed story's visible parts once; later observer refreshes still animate arrivals.
        function refresh(refresh_options) {
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
                    state = { shown: false, node: null };
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
                // motion.js entrances belong to appearance, never updates to an already visible control.
                if (!state.shown && (!refresh_options || refresh_options.animate !== false)) arriving.push(node);
                state.shown = true;
            });
            states.forEach(function (state, key) {
                if (!current.has(key)) { if (observer) observer.unobserve(state.node); states.delete(key); }
            });
            screen_order(arriving, options.horizontal && (getComputedStyle(element).direction || 'ltr')).forEach(function (node, index) {
                enter(node, stagger_delay(index, arriving.length, 30, 150), 7);
            });
        }
        function pause() {
            connected = false;
            if (frame !== null) cancelAnimationFrame(frame);
            frame = null;
            if (observer) observer.disconnect();
            if (mutations) mutations.disconnect();
        }
        function observe_mutations() {
            if (mutations) mutations.observe(element, { childList: true, subtree: true,
                attributes: true, attributeFilter: ['class', 'style', 'hidden'] });
        }
        var controller = { refresh: refresh, schedule: schedule, pause: pause, resume: function () {
            if (connected) return;
            connected = true;
            states.forEach(function (state) { if (observer) observer.observe(state.node); });
            observe_mutations();
        }, disconnect: function () { pause(); states.clear(); } };
        part_observers.set(element, controller);
        observe_mutations();
        if (options.defer) schedule(); else refresh(options);
        return controller;
    }
    function pause_parts(element) {
        var controller = part_observers.get(element);
        if (controller) controller.pause();
    }
    function unwatch_parts(element) {
        var controller = part_observers.get(element);
        if (controller) controller.disconnect();
        part_observers.delete(element);
    }
    function refresh_completed(element) {
        if (!element || !animations_enabled()) return;
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
            var last_title_start = null;
            var last_scroll_top = root ? root.scrollTop : window.scrollY;
            var scroll_target = root || window;
            var listening = false;
            var frame = null;
            function finish_titles() {
                entered.forEach(function (element) {
                    var animation = running.get(element);
                    if (animation) animation.cancel();
                });
                entered.clear();
                last_title_start = null;
            }
            function reveal(scrolling) {
                var scroll_top = root ? root.scrollTop : window.scrollY;
                var scroll_changed = scroll_top !== last_scroll_top;
                scrolling = scrolling || scroll_changed;
                last_scroll_top = scroll_top;
                // motion.js ignores queued scroll-reset events already reflected when this feed's observer started.
                if (scroll_changed && options.animate_on_scroll === false) {
                    // motion.js ends title entrances for this feed visit, including pages arriving after scrolling stops.
                    owner.motion_scrolled = true;
                    finish_titles();
                }
                // motion.js reads the whole visible batch before animation writes can change its geometry.
                var visible = screen_order(Array.from(pending.values()).filter(function (element) {
                    if (!element.isConnected) { controller.unobserve(element); return false; }
                    return visible_in_root(element, root);
                }));
                // motion.js continues one opening timeline across title pages, keeping their fades overlapping.
                var opening_titles = options.animate_on_scroll === false;
                // motion.js: rows that come into view without a scroll while earlier rows are still entering, as the
                // feed list settles after it draws, continue that cascade instead of starting a second one.
                var continues = opening_titles || (options.continue_cascade && !scrolling);
                var animate = animations_enabled();
                if (opening_titles && !animate) finish_titles();
                var spacing = options.spacing || 35;
                var spread = scrolling && !opening_titles ? 90 : (options.spread || 175);
                // motion.js gives opening titles twice the pace while retaining the shared pagination timeline.
                if (opening_titles) { spacing /= 2; spread /= 2; }
                var step = visible.length > 1 ? Math.min(spacing, spread / (visible.length - 1)) : spacing;
                entered.forEach(function (element) { if (!running.has(element)) entered.delete(element); });
                if (!entered.size) last_title_start = null;
                var now = continues ? performance.now() : 0;
                var delay = continues && last_title_start !== null && animate ?
                    Math.max(0, last_title_start + step - now) : 0;
                visible.forEach(function (element, index) {
                    var key = element.nb_motion_key;
                    controller.unobserve(element);
                    if (owner.motion_seen.has(key)) return;
                    owner.motion_seen.add(key);
                    if (owner.motion_scrolled && options.animate_on_scroll === false) return;
                    var row_delay = delay + stagger_delay(index, visible.length, spacing, spread);
                    enter(element, row_delay, scrolling && !opening_titles ? 8 : (options.distance || 16),
                        opening_titles ? 175 : 350);
                    if (continues && animate) {
                        entered.add(element);
                        last_title_start = now + row_delay;
                    }
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
                    finish_titles();
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
    reduced.addEventListener('change', preference_changed);
    return { enter: enter, exit: exit, depart: depart, remove: remove, cascade: cascade, arrive: arrive, article: article,
        article_parts: article_parts, feedbar_parts: feedbar_parts, watch_parts: watch_parts, pause_parts: pause_parts, unwatch_parts: unwatch_parts, watch: watch, refresh_completed: refresh_completed,
        reduced: reduce_motion, preference_changed: preference_changed,
        frames: function (frames) { return reduce_motion() ? opacity_frames(frames) : frames; },
        duration: function (milliseconds) { return animations_enabled() && !reduce_motion() ? milliseconds : 0; },
        fade_duration: function (milliseconds) { return animations_enabled() ? milliseconds : 0; } };
})();
