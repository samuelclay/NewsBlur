// test_departure_motion.cjs reproduces title snapshots losing ancestor-dependent layout.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness() {
    const style_reads = new Map();
    const property_reads = new Map();
    const animations = [];
    function style() {
        return { setProperty(name, value) { this[name] = value; } };
    }
    function node(name, top, height = 80) {
        return {
            name, nodeType: 1, style: style(), children: [], childNodes: [], parentElement: null,
            bounds: { top, bottom: top + height, left: 10, right: 310, width: 300, height },
            appendChild(child) { this.children.push(child); this.childNodes.push(child); child.parentElement = this; },
            getClientRects() { return [this.bounds]; },
            getBoundingClientRect() { return this.bounds; },
            removeAttribute() {}, setAttribute() {}, remove() { this.removed = true; },
            querySelectorAll() { return this.children.flatMap(child => [child, ...child.querySelectorAll()]); },
            cloneNode(deep) {
                const copy = node(this.name, top, height);
                Object.assign(copy.style, this.style);
                if (deep) this.children.forEach(child => copy.appendChild(child.cloneNode(true)));
                return copy;
            },
            animate(frames, options) {
                const animation = { frames, options, cancel() { this.oncancel?.(); } };
                animations.push(animation);
                return animation;
            }
        };
    }
    const body = node('body', 0, 800), pane = node('pane', 0, 200), titles = node('titles', 0, 1100);
    body.appendChild(pane);
    pane.appendChild(titles);
    const row = node('row', 0), headline = node('headline', 0);
    row.appendChild(headline);
    titles.appendChild(row);
    const offscreen = node('row', 1000), offscreen_headline = node('headline', 1000);
    offscreen.appendChild(offscreen_headline);
    titles.appendChild(offscreen);
    function computed(element) {
        style_reads.set(element, (style_reads.get(element) || 0) + 1);
        let in_pane = false;
        for (let ancestor = element; ancestor; ancestor = ancestor.parentElement) if (ancestor === pane) in_pane = true;
        const values = {
            display: 'block', position: 'relative', 'box-sizing': 'border-box',
            width: element.name === 'headline' ? (in_pane ? '250px' : '120px') : '300px',
            'padding-right': element.name === 'row' ? (in_pane ? '10px' : '140px') : '0px',
            'font-size': in_pane ? '14px' : '12px',
            '-webkit-line-clamp': in_pane ? '4' : '2',
            overflow: element === pane ? 'hidden' : 'visible',
            ...element.style
        };
        // test_departure_motion.cjs models the hundreds of computed properties exposed by a real browser.
        for (let index = 0; index < 600; index++) values[`unused-property-${index}`] = 'initial';
        return { ...values, [Symbol.iterator]: function* () { yield* Object.keys(values).filter(key => typeof values[key] === 'string'); },
            getPropertyValue(name) { property_reads.set(element, (property_reads.get(element) || 0) + 1); return values[name] || ''; },
            getPropertyPriority: () => '' };
    }
    const context = { NEWSBLUR: {}, document: { body }, getComputedStyle: computed,
        window: { innerWidth: 1200, innerHeight: 800, matchMedia: () => ({ matches: false, addEventListener() {} }) },
        $: () => ({ on() {} }) };
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/common/motion.js', 'utf8'), context);
    return { motion: context.NEWSBLUR.motion, body, pane, titles, row, headline, offscreen, offscreen_headline,
        computed, style_reads, property_reads, animations };
}

test('outgoing titles retain their rendered headline width and layout outside the original pane', () => {
    const h = harness();
    const width = h.computed(h.headline).width;
    h.motion.depart(h.titles, { snapshot_layout: true });
    const ghost = h.body.children.at(-1);
    const copied_row = ghost.children[0], copied_headline = copied_row.children[0];
    assert.equal(h.computed(copied_headline).width, width, 'Leaving #story_titles must not squeeze the visible headline');
    assert.equal(h.computed(copied_row)['padding-right'], '10px');
    assert.equal(h.computed(copied_headline)['font-size'], '14px');
    assert.equal(h.computed(copied_headline)['-webkit-line-clamp'], '4', 'The west-pane preview must keep all four visible lines');
    assert.equal(ghost.children.length, 1, 'Only viewport rows belong in the outgoing snapshot');
    assert.equal(h.style_reads.has(h.offscreen), false, 'Offscreen rows must not incur style-copy work');
    assert.equal(h.style_reads.has(h.offscreen_headline), false);
    assert.equal(h.animations.length, 1, 'Keep the smooth outgoing fade');
    h.animations[0].onfinish();
    assert.equal(ghost.removed, true);
});

test('snapshot style work is bounded independently of the browser computed-property count', () => {
    const h = harness();
    h.motion.depart(h.titles, { snapshot_layout: true });
    assert.ok([...h.property_reads.values()].every(count => count < 100),
        'A visible node must not copy hundreds of unrelated browser properties on a feed-switch click');
});

test('a scrolled title snapshot keeps visible rows at their original positions without copying preceding rows', () => {
    const h = harness();
    h.titles.bounds.top = -900;
    h.titles.bounds.bottom = 200;
    h.row.bounds.top = -900;
    h.row.bounds.bottom = -820;
    h.offscreen.bounds.top = 100;
    h.offscreen.bounds.bottom = 180;
    h.motion.depart(h.titles, { snapshot_layout: true });
    const ghost = h.body.children.at(-1);
    assert.equal(ghost.children.length, 1);
    assert.equal(ghost.style.top, '-900px');
    assert.equal(ghost.children[0].style.top, '1000px', 'The visible row stays at viewport y=100 rather than jumping to the top');
    assert.equal(h.style_reads.has(h.row), false);
    assert.equal(h.style_reads.has(h.headline), false);
});
