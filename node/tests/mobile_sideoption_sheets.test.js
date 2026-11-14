// mobile_sideoption_sheets.test.js protects the live editors when phone sheets close, reopen, or finish requests.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');

function fixture() {
    const timers = new Map();
    let next_timer = 0;
    class Element {
        constructor(classes = '') { this.classes = new Set(classes.split(' ').filter(Boolean)); this.children = []; this.parentNode = null; this.style = {}; }
        get isConnected() { return this === document.documentElement || !!this.parentNode?.isConnected; }
        remove() { if (this.parentNode) this.parentNode.children.splice(this.parentNode.children.indexOf(this), 1); this.parentNode = null; }
        append(child) { child.remove(); this.children.push(child); child.parentNode = this; }
    }
    const document = { documentElement: new Element(), createComment: () => new Element() };
    const body = new Element(); document.documentElement.append(body);
    function matches(node, selector) { return selector.split('.').filter(Boolean).every(name => node.classes.has(name)); }
    class Collection extends Array {
        static get [Symbol.species]() { return Array; }
        closest(selector) { const result = []; for (let node of this) { while (node && !matches(node, selector)) node = node.parentNode; if (node) result.push(node); } return $(result); }
        addClass(classes) { for (const node of this) classes.split(' ').forEach(name => node.classes.add(name)); return this; }
        removeClass(classes) { for (const node of this) classes.split(' ').forEach(name => node.classes.delete(name)); return this; }
        before(item) { const node = this[0], parent = node.parentNode; for (const child of $(item)) { child.remove(); parent.children.splice(parent.children.indexOf(node), 0, child); child.parentNode = parent; } return this; }
        append(item) { for (const child of $(item)) this[0].append(child); return this; }
        replaceWith(item) { this.before(item); return this.remove(); }
        remove() { for (const node of this) node.remove(); return this; }
        add(item) { return $([...this, ...$(item)]); }
        css(name, value) { for (const node of this) Object.assign(node.style, typeof name === 'object' ? name : {[name]: value}); return this; }
        find(selector) { const found = []; const visit = node => { for (const child of node.children) { if (matches(child, selector)) found.push(child); visit(child); } }; this.forEach(visit); return $(found); }
        height() { return 100; }
        animate(_, options) { options?.complete?.(); return this; }
        focus() { return this; }
        autosize() { return this; }
    }
    function $(item) { return new Collection(...(item == null ? [] : item instanceof Collection || Array.isArray(item) ? item : [item])); }
    $.make = (_, attrs, children = []) => { const node = new Element(attrs.className); for (const child of children) $(node).append(child); return $(node); };
    $.contains = (parent, child) => { for (let node = child.parentNode; node; node = node.parentNode) if (node === parent) return true; return false; };
    const context = {
        NEWSBLUR: { Views: {}, app: {}, Globals: {is_premium: true}, assets: {view_setting: () => 'global'}, reader: {flags: {}, blur_to_page() {}} },
        Backbone: {View: {extend: definition => definition}},
        _: {template: () => {}, bind: (fn, owner, ...args) => fn.bind(owner, ...args), string: {startsWith: (value, prefix) => value.startsWith(prefix)}},
        $, document, window: {}, console: {log() {}},
        setTimeout(fn) { const id = ++next_timer; timers.set(id, fn); return id; },
        clearTimeout(id) { timers.delete(id); }
    };
    for (const name of ['mobile_layout_view', 'story_detail_view', 'story_save_view', 'discover_stories_view']) {
        vm.runInNewContext(fs.readFileSync(path.join(root, `media/js/newsblur/views/${name}.js`), 'utf8'), context);
    }
    const mobile = Object.assign(Object.create(context.NEWSBLUR.Views.MobileLayout), {active: true, $body: $(body), transition_duration: () => 260});
    context.NEWSBLUR.app.mobile = mobile;
    function editor() {
        const story = new Element('story'), panel = new Element('panel'); body.append(story); story.append(panel);
        const view = {$el: $(story), setElement(el) { this.$el = el; }};
        const dismiss = () => mobile.sideoption_sheet(view, $(panel), {close: true});
        return {story, panel, view, open: () => mobile.sideoption_sheet(view, $(panel), {dismiss})};
    }
    function finish_timers() { for (const [id, fn] of [...timers]) { timers.delete(id); fn(); } }
    return {context, mobile, body, Element, $, editor, finish_timers};
}

test('reopening a closing editor keeps its panel connected and restores the original story', () => {
    const f = fixture(), editor = f.editor();
    editor.open();
    f.mobile.close_sideoption_sheet();
    editor.open();
    f.finish_timers();
    assert.equal(editor.panel.parentNode, f.mobile.sideoption.$sheet[0], 'old close must not steal the reopened editor');
    assert.equal(editor.panel.isConnected, true);
    f.mobile.close_sideoption_sheet();
    f.finish_timers();
    assert.equal(editor.panel.parentNode, editor.story);
    assert.deepEqual([...editor.view.$el], [editor.story]);
});

test('closing after the original story is replaced discards the obsolete panel', () => {
    const f = fixture(), editor = f.editor();
    editor.open();
    editor.story.remove();
    f.mobile.close_sideoption_sheet();
    f.finish_timers();
    assert.equal(editor.panel.parentNode, null, 'a placeholder in a detached old story is not a restoration target');
});

test('a late Related response cannot replace an active Share sheet after Related was dismissed', () => {
    const f = fixture();
    const related = f.editor();
    let response;
    const view = Object.assign(related.view, f.context.NEWSBLUR.Views.DiscoverStoriesView, {
        is_open: true, page: 1, has_more_results: true,
        model: {get: () => 'story:1'},
        discover_stories: {fetch(options) { response = options.success; return {}; }},
        show_loading() {}, hide_loading() {}, render() {},
        $(selector) { return selector === '.NB-story-content-discover-wrapper' ? f.$(related.panel) : f.$(); }
    });
    view.load_discover_stories();
    view.resize();
    f.mobile.close_sideoption_sheet();
    const share = f.editor(); share.open();
    response({length: 1}, {discover_stories: [{}]});
    assert.equal(f.mobile.sideoption.view, share.view);
    assert.equal(related.panel.parentNode, related.story);
    assert.equal(view.is_open, false);
});

test('the phone Saved action opens its editor without unsaving while desktop keeps its toggle', () => {
    const f = fixture();
    let toggles = 0, opened = false;
    const save_view = {toggle_feed_story_save_dialog() { opened = this.open_as_sheet; }};
    const detail = {sideoptions_view: {save_view}, model: {get: key => key === 'starred', toggle_starred() { toggles++; }}};
    f.context.NEWSBLUR.Views.StoryDetailView.toggle_starred.call(detail);
    assert.equal(toggles, 0, 'editing notes must preserve the saved story');
    assert.equal(opened, true);
    f.context.NEWSBLUR.app.mobile.active = false;
    f.context.NEWSBLUR.Views.StoryDetailView.toggle_starred.call(detail);
    assert.equal(toggles, 1, 'desktop keeps its existing save toggle');
});

test('tag autocomplete travels with the editor above the phone sheet shade', () => {
    const f = fixture(), editor = f.editor();
    const menu = new f.Element('ui-autocomplete');
    const tag_input = f.$(new f.Element('tag-input'));
    tag_input.tagit = options => {
        if (typeof options === 'object') {
            // mobile_sideoption_sheets.test.js models jQuery UI's appendTo contract at the plugin boundary.
            f.$(options.autocomplete.appendTo || f.body).append(menu);
        }
        return tag_input;
    };
    const view = Object.assign(editor.view, f.context.NEWSBLUR.Views.StorySaveView, {
        model: {get: () => true, all_tags: () => ['existing tag']},
        resize() { editor.open(); },
        $(selector) { return selector === '.NB-sideoption-save-tag' ? tag_input : selector === '.NB-sideoption-save-wrapper' ? f.$(editor.panel) : f.$(); }
    });
    view.toggle_feed_story_save_dialog();
    assert.equal(f.$.contains(f.mobile.sideoption.$sheet[0], menu), true, 'the selectable suggestion must share the sheet stacking context');
});
