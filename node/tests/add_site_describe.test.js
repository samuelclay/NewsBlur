const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// add_site_popover_query.test.js: the add-feed popover (reader_add_feed.js) hands its text to
// NEWSBLUR.reader.open_add_site as initial_query. These tests run the real reader.js, add_site_view.js
// and describe_feeds_view.js with only the DOM and the network faked, and check that the text reaches
// the server whether or not the Add + Discover Sites view is already open.

// A jQuery stand-in: every method chains, and val() remembers what was set per selector.
function fake_dom() {
    const values = new Map();
    function collection(selector) {
        const proxy = new Proxy(function () {}, {
            get: function (target, prop) {
                if (prop === 'length') return 1;
                if (prop === 'then' || prop === Symbol.toPrimitive) return undefined;
                if (prop === Symbol.iterator) return function* () {};
                if (prop === 'val') {
                    return function (value) {
                        if (arguments.length) {
                            values.set(selector, value);
                            return proxy;
                        }
                        return values.has(selector) ? values.get(selector) : '';
                    };
                }
                if (prop === 'hasClass' || prop === 'is') return function () { return false; };
                if (prop === 'data' || prop === 'attr' || prop === 'prop') return function () { return undefined; };
                if (prop === 'scrollTop' || prop === 'width' || prop === 'height' || prop === 'outerWidth' ||
                    prop === 'outerHeight' || prop === 'innerWidth' || prop === 'innerHeight') {
                    return function () { return 0; };
                }
                return function () { return proxy; };
            },
            apply: function () { return proxy; }
        });
        return proxy;
    }
    const $ = function (selector) {
        return collection(typeof selector === 'string' ? selector : 'node');
    };
    $.make = function () { return collection('made'); };
    $.trim = function (value) { return String(value).trim(); };
    $.extend = function () { return Object.assign.apply(Object, arguments); };
    return { $: $, collection: collection, values: values };
}

function popover_fixture(open_tab) {
    const dom = fake_dom();
    const requests = [];
    const assets = {
        make_request: function (url, params) { requests.push({ url: url, params: params || {} }); },
        preference: function () { return null; },
        view_setting: function () { return null; },
        feeds: { active: function () { return []; } }
    };
    // Backbone.View.extend returns a constructor so `new NEWSBLUR.Views.DescribeFeedsView(...)` works;
    // each view's $el and $() go to the fake DOM.
    const Backbone = {
        View: {
            extend: function (methods) {
                function View(options) {
                    this.options = options || {};
                    this.el = {};
                    this.$el = dom.collection('el');
                    this.$ = function (selector) { return dom.collection(selector); };
                    if (this.initialize) this.initialize(this.options);
                }
                View.prototype = methods;
                return View;
            }
        },
        Router: { extend: function (methods) { return methods; } },
        Events: {}
    };
    function Collection(models) {
        this.models = models || [];
        this.length = this.models.length;
    }
    Collection.prototype.reset = function (models) { this.models = models || []; this.length = this.models.length; };
    Collection.prototype.each = function (fn) { this.models.forEach(fn); };
    Collection.prototype.map = function (fn) { return this.models.map(fn); };
    Collection.prototype.on = function () {};
    Collection.prototype.off = function () {};
    // The trending list the empty Search tab shows is fetched from the server; it never answers here.
    Collection.prototype.fetch = function () {};
    const context = {
        NEWSBLUR: {
            Views: {},
            Collections: { TrendingFeeds: Collection },
            Models: {},
            Globals: { MEDIA_URL: '/media/', is_premium: true, is_archive: true },
            assets: assets,
            router: { navigate: function () {} },
            utils: {}
        },
        Backbone: Backbone,
        $: dom.$,
        gettext: function (text) { return text; },
        ngettext: function (singular, plural, count) { return count === 1 ? singular : plural; },
        interpolate: function (text) { return text; },
        window: { addEventListener: function () {}, location: { pathname: '/add/' + open_tab } },
        document: {},
        setTimeout: function () { return 0; },
        clearTimeout: function () {},
        console: { log: function () {}, warn: function () {}, error: function () {} }
    };
    context.jQuery = context.$;
    vm.createContext(context);
    ['media/js/vendor/underscore-1.4.3.js', 'media/js/vendor/underscore.string.js',
        'media/js/newsblur/reader/reader.js',
        'media/js/newsblur/views/add_site_view.js',
        'media/js/newsblur/views/describe_feeds_view.js'].forEach(function (filename) {
        vm.runInContext(fs.readFileSync(path.join(repo_root, filename), 'utf8'), context);
    });
    // _.defer would otherwise wait on a timer the sandbox never fires.
    context._.defer = function (fn) { fn(); };

    // The Add + Discover Sites view as the page renders it when opened on open_tab with no text.
    const add_site_view = new context.NEWSBLUR.Views.AddSiteView({ tab: open_tab, initial_tab: open_tab });

    const reader = Object.create(context.NEWSBLUR.Reader);
    reader.flags = { add_site_view: true };
    reader.add_site_view = add_site_view;
    context.NEWSBLUR.reader = reader;
    requests.length = 0;

    return { reader: reader, add_site_view: add_site_view, requests: requests, values: dom.values };
}

function describe_starts(requests) {
    return requests.filter(function (request) { return request.url === '/discover/describe/start'; });
}

for (const open_tab of ['describe', 'search']) {
    test('a description from the popover starts a Describe search when Add Site is already open on ' +
        open_tab, function () {
        const h = popover_fixture(open_tab);

        h.reader.open_add_site({ tab: 'describe', initial_query: 'ham radio operation' });

        assert.equal(h.add_site_view.active_tab, 'describe');
        const starts = describe_starts(h.requests);
        assert.equal(starts.length, 1, 'expected one /discover/describe/start request');
        assert.equal(starts[0].params.prompt, 'ham radio operation');
        assert.equal(h.values.get('.NB-describe-input'), 'ham radio operation');
    });
}

test('a site name from the popover searches when Add Site is already open on Describe', function () {
    const h = popover_fixture('describe');

    h.reader.open_add_site({ tab: 'search', initial_query: 'daring fireball' });

    assert.equal(h.add_site_view.active_tab, 'search');
    const searches = h.requests.filter(function (request) { return request.url === '/discover/autocomplete'; });
    assert.equal(searches.length, 1, 'expected one /discover/autocomplete request');
    assert.equal(searches[0].params.query, 'daring fireball');
});

test('opening Describe again with no text starts no search', function () {
    const h = popover_fixture('describe');

    h.reader.open_add_site({ tab: 'describe' });

    assert.equal(describe_starts(h.requests).length, 0);
});
