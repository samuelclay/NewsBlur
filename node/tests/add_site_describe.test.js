const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// add_site_describe.test.js runs the real reader.js, add_site_view.js and describe_feeds_view.js with only
// the DOM and the network faked. It checks that text handed over by the add-feed popover (reader_add_feed.js)
// reaches the server whether or not the Add + Discover Sites view is already open, and that a Describe search
// the server refuses never costs the reader the search they are looking at.

// A jQuery stand-in: every method chains, val() remembers what was set per selector, and html() records what
// replaced each selector's contents.
function fake_dom() {
    const values = new Map();
    const htmls = [];
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
                if (prop === 'html') {
                    return function (content) {
                        if (arguments.length) htmls.push(selector);
                        return proxy;
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
    return { $: $, collection: collection, values: values, htmls: htmls };
}

function popover_fixture(open_tab) {
    const dom = fake_dom();
    let timers = 0;
    const requests = [];
    // A test answers a URL with respond(url, fn); fn gets (params, callback, error_callback) the way
    // assetmodel.js make_request calls them, where any response with code < 0 goes to error_callback.
    const responders = {};
    const assets = {
        make_request: function (url, params, callback, error_callback) {
            requests.push({ url: url, params: params || {} });
            if (responders[url]) responders[url](params || {}, callback, error_callback);
        },
        preference: function () { return null; },
        view_setting: function () { return null; },
        feeds: { active: function () { return []; }, get: function () { return undefined; } }
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
            // A card's folder picker; the fake DOM stands in for the markup.
            utils: { make_folders: function () { return '<select></select>'; } }
        },
        Backbone: Backbone,
        $: dom.$,
        gettext: function (text) { return text; },
        ngettext: function (singular, plural, count) { return count === 1 ? singular : plural; },
        interpolate: function (text) { return text; },
        window: { addEventListener: function () {}, location: { pathname: '/add/' + open_tab } },
        document: {},
        setTimeout: function () { timers += 1; return timers; },
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

    return {
        reader: reader,
        add_site_view: add_site_view,
        requests: requests,
        values: dom.values,
        htmls: dom.htmls,
        respond: function (url, fn) { responders[url] = fn; }
    };
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

// A search the view is showing and still waiting on: the server lets one search run per reader at a time.
function show_running_search(h) {
    const describe_view = h.add_site_view.describe_view;
    describe_view.show_search({ id: 'running-1', status: 'running', prompt: 'ham radio operators', results: [] });
    describe_view.begin_streaming();
    h.requests.length = 0;
    return describe_view;
}

test('a description from the popover leaves a Describe search that is still running alone', function () {
    const h = popover_fixture('describe');
    const describe_view = show_running_search(h);

    h.reader.open_add_site({ tab: 'describe', initial_query: 'ham radio operation' });

    assert.equal(describe_starts(h.requests).length, 0, 'the server would refuse a second search');
    assert.equal(describe_view.search.id, 'running-1');
    assert.ok(describe_view.poll_timer, 'the running search keeps getting its updates');
});

test('submitting another description keeps updating the search that is still running', function () {
    const h = popover_fixture('describe');
    const describe_view = show_running_search(h);

    describe_view.start_search('bike touring trip reports');

    assert.equal(describe_starts(h.requests).length, 0);
    assert.ok(describe_view.poll_timer, 'the running search keeps getting its updates');
});

test('a refused search leaves the results on screen in place', function () {
    const h = popover_fixture('describe');
    const describe_view = h.add_site_view.describe_view;
    describe_view.show_search({ id: 'done-1', status: 'complete', prompt: 'ham radio operators', results: [] });
    h.respond('/discover/describe/start', function (params, callback, error_callback) {
        error_callback({ code: -1, message: 'You already have a search running. Wait for it to finish first.' });
    });
    h.htmls.length = 0;

    describe_view.start_search('bike touring trip reports');

    assert.equal(describe_starts(h.requests).length, 1);
    assert.equal(describe_view.search.id, 'done-1');
    assert.ok(h.htmls.indexOf('.NB-describe-body') === -1, 'the shown results are not replaced by an error');
});

test('a search refused for the plan shows the allowance from the refusal', function () {
    const h = popover_fixture('describe');
    const describe_view = h.add_site_view.describe_view;
    const usage = { plan: 'free', limit: 0, used: 0, remaining: 0 };
    h.respond('/discover/describe/start', function (params, callback, error_callback) {
        error_callback({ code: -1, upgrade: true, usage: usage, message: 'Describing feeds is a premium feature.' });
    });

    describe_view.start_search('ham radio operators');

    assert.deepEqual(describe_view.usage, usage);
});

// A result row as /discover/describe/status stores it, without stories so the card draws no story rows.
function result_row(feed_id, score) {
    return {
        feed_id: feed_id,
        feed: { id: feed_id, feed_title: 'Feed ' + feed_id, feed_address: 'https://feed' + feed_id + '.example.com/rss' },
        source: 'index',
        judged: true,
        score: score,
        reason: 'Matches',
        stories: []
    };
}

test('a finished search shows the results the socket missed', function () {
    const h = popover_fixture('describe');
    const describe_view = show_running_search(h);
    h.respond('/discover/describe/status', function (params, callback) {
        callback({ code: 1, search: { id: 'running-1', status: 'complete', phase: 'complete', prompt: 'ham radio operators', results: [result_row(42, 9)] } });
    });

    describe_view.handle_event({ type: 'complete', search_id: 'running-1', result_count: 1 });

    assert.deepEqual(Object.keys(describe_view.rows), ['42']);
    assert.equal(describe_view.search.status, 'complete');
});

test('a poll that finds the same ranked results leaves the cards in place', function () {
    const h = popover_fixture('describe');
    const describe_view = h.add_site_view.describe_view;
    // Ranked 42 then 7: not the order of their feed ids.
    const results = [result_row(42, 9), result_row(7, 8)];
    describe_view.show_search({ id: 'running-1', status: 'running', phase: 'judging', prompt: 'ham radio operators', results: results });
    h.htmls.length = 0;

    describe_view.apply_search_payload({ id: 'running-1', status: 'running', phase: 'judging', prompt: 'ham radio operators', results: results });

    assert.ok(h.htmls.indexOf('.NB-describe-body') === -1, 'unchanged results are not drawn again');
});

test('only the last search picked from history is shown when answers arrive out of order', function () {
    const h = popover_fixture('describe');
    const describe_view = h.add_site_view.describe_view;
    const answers = [];
    h.respond('/discover/describe/status', function (params, callback) {
        answers.push(function () {
            callback({ code: 1, search: { id: params.search_id, status: 'complete', phase: 'complete', prompt: 'Search ' + params.search_id, results: [] } });
        });
    });

    describe_view.open_search('first');
    describe_view.open_search('second');
    answers[1]();
    answers[0]();

    assert.equal(describe_view.search.id, 'second');
});

test('a search opened from history before New was clicked stays closed', function () {
    const h = popover_fixture('describe');
    const describe_view = h.add_site_view.describe_view;
    const answers = [];
    h.respond('/discover/describe/status', function (params, callback) {
        answers.push(function () {
            callback({ code: 1, search: { id: params.search_id, status: 'complete', phase: 'complete', prompt: 'Search ' + params.search_id, results: [] } });
        });
    });

    describe_view.open_search('first');
    describe_view.start_new_search();
    answers[0]();

    assert.equal(describe_view.search, null);
});
