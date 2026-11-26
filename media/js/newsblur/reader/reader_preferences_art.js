// reader_preferences_art.js: the small drawings on the option cards in Preferences
// (reader_preferences.js make_cards). Each one is a 120 by 76 sketch of the part of the reader a
// choice changes, drawn from a handful of shapes. Shapes take their colors from the --nb-art-*
// variables in css/reader/reader.css, so the drawings follow the reader's theme.
//
// Shape classes: ap page, as sidebar or panel, al faint line, ak text, ab strong text, aa accent,
// ay selection, ag positive, ao notice, ar negative, ad dark chrome, aw white.

NEWSBLUR.PreferencesArt = (function () {

    var R = function (x, y, w, h, c, r) {
        return '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="' + (r == null ? 2 : r) + '" class="' + c + '"/>';
    };
    var B = function (x, y, w, c, h) { return R(x, y, w, h || 4, c || 'ak', (h || 4) / 2); };
    var C = function (x, y, r, c) { return '<circle cx="' + x + '" cy="' + y + '" r="' + r + '" class="' + c + '"/>'; };
    var P = function (d, c) { return '<path d="' + d + '" class="' + c + '"/>'; };
    var T = function (x, y, s, c, size, anchor) {
        return '<text x="' + x + '" y="' + y + '" class="' + (c || 'ab') + '" font-size="' + (size || 10) + '" text-anchor="' + (anchor || 'start') + '">' + s + '</text>';
    };
    var page = function () { return R(0, 0, 120, 76, 'ap', 0); };

    // The feed list: six sites, optionally one selected, with unread counts or folder markers.
    var sidebar = function (o) {
        o = o || {};
        var w = o.w || 36;
        var widths = o.widths || [20, 15, 22, 12, 18, 14];
        var out = [R(0, 0, w, 76, 'as', 0)];
        _.each(widths, function (bar, i) {
            var y = (o.top || 9) + i * (o.gap || 10);
            if (o.sel === i) out.push(R(2, y - 3, w - 4, 10, 'ay', 3));
            if (o.folders && _.contains(o.folders, i)) out.push(R(5, y - 1, 5, 5, 'ak', 1));
            out.push(B(o.folders ? 13 : 6, y, o.folders ? Math.min(bar, 14) : bar, o.sel === i ? 'ab' : 'al'));
            if (o.counts && _.contains(o.counts, i)) out.push(R(w - 10, y - 1, 7, 6, 'aa', 3));
        });
        return out.join('');
    };

    // One story title row: a title, an optional preview and thumbnail, optionally unread or selected.
    var row = function (x, y, w, o) {
        o = o || {};
        var h = o.h || 16;
        var out = [];
        var left = x + 4, right = x + w - 4;
        if (o.selected) out.push(R(x + 1, y, w - 2, h, 'ay', 3));
        if (o.image == 'left') { out.push(R(left, y + 2, o.big ? 20 : 11, h - 4, 'al', 2)); left += (o.big ? 23 : 14); }
        if (o.image == 'right') { out.push(R(right - (o.big ? 20 : 11), y + 2, o.big ? 20 : 11, h - 4, 'al', 2)); right -= (o.big ? 23 : 14); }
        if (o.dot) { out.push(C(left + 2, y + 5, 2, o.dot)); left += 7; }
        out.push(B(left, y + 3, (right - left) * (o.title || 0.72), o.read ? 'al' : 'ab'));
        if (o.preview !== false && h >= 14) out.push(B(left, y + 10, (right - left) * 0.95, 'al', 3));
        return out.join('');
    };
    var rows = function (x, y, w, n, o) {
        o = o || {};
        return _.map(_.range(n), function (i) {
            return row(x, y + i * ((o.h || 16) + (o.gap == null ? 2 : o.gap)), w, _.extend({}, o, { selected: o.sel === i, read: o.read && _.contains(o.read, i) }));
        }).join('');
    };

    // Paragraph text in a story.
    var text = function (x, y, w, n, o) {
        o = o || {};
        return _.map(_.range(n), function (i) {
            return B(x, y + i * 7, w * (i == n - 1 ? 0.6 : (i % 2 ? 0.92 : 1)), o.c || 'al', 3);
        }).join('');
    };
    var cursor = function (x, y) {
        return P('M' + x + ' ' + y + 'l0 13l3.6-3.4l2.6 5.6l2.4-1.1l-2.6-5.5l4.8-.3z', 'ab acur');
    };
    var key = function (x, y, label, w) {
        return R(x, y, w || 18, 18, 'ad', 4) + T(x + (w || 18) / 2, y + 13, label, 'aw', 10, 'middle');
    };
    var check = function (x, y, c) { return C(x, y, 5, c || 'ag') + P('M' + (x - 2.4) + ' ' + y + 'l1.7 1.8l3.2-3.6', 'astroke'); };
    var cross = function (x, y) { return P('M' + (x - 4) + ' ' + (y - 4) + 'l8 8M' + (x + 4) + ' ' + (y - 4) + 'l-8 8', 'aline'); };
    var arrow = function (x1, y1, x2, y2) {
        var a = Math.atan2(y2 - y1, x2 - x1), s = 4;
        return P('M' + x1 + ' ' + y1 + 'L' + x2 + ' ' + y2 + 'M' + x2 + ' ' + y2 + 'l' + (-s * Math.cos(a - 0.5)).toFixed(1) + ' ' + (-s * Math.sin(a - 0.5)).toFixed(1) +
            'M' + x2 + ' ' + y2 + 'l' + (-s * Math.cos(a + 0.5)).toFixed(1) + ' ' + (-s * Math.sin(a + 0.5)).toFixed(1), 'aarrow');
    };
    var reader = function (inner, o) { return page() + sidebar(o) + inner; };
    var story = function (x, w, o) {
        o = o || {};
        return R(x, 0, w, 14, 'as', 0) + B(x + 6, 5, w * 0.55, 'ab') + text(x + 6, 21, w - 12, o.lines || 6);
    };

    // One tall story in a column 54 wide: cut short with a button to open it, or shown in full.
    var tall = function (x, shortened, shared) {
        var out = [R(x, 4, 54, 68, 'as', 3)];
        if (shared) out.push(C(x + 9, 13, 4, 'aa') + B(x + 16, 11, 24, 'ab'));
        var top = shared ? 23 : 11;
        out.push(text(x + 6, top, 42, shortened ? 4 : (shared ? 7 : 9)));
        if (shortened) out.push(R(x, 44, 54, 14, 'as afadeup', 0) + R(x + 15, 58, 24, 8, 'aa', 4));
        return out.join('');
    };

    var art = {

        // ----- General -----

        'density-compact': function () { return page() + sidebar({ top: 7, gap: 8, widths: [20, 15, 22, 12, 18, 14, 20, 16] }) + rows(40, 4, 78, 6, { h: 9, gap: 2, preview: false }); },
        'density-comfortable': function () { return page() + sidebar() + rows(40, 5, 78, 4, { h: 14, gap: 4, preview: false }); },
        'motion-full': function () { return page() + R(14, 22, 30, 32, 'al', 4) + R(40, 22, 30, 32, 'al aghost', 4) + R(68, 22, 30, 32, 'aa', 4) + arrow(46, 62, 82, 62); },
        'motion-reduced': function () { return page() + R(30, 22, 30, 32, 'al aghost', 4) + R(58, 22, 30, 32, 'aa', 4) + R(58, 22, 30, 32, 'ap afade', 4); },
        'motion-none': function () { return page() + R(45, 22, 30, 32, 'aa', 4); },
        'clock-12': function () { return page() + T(60, 43, '3:45', 'ab', 22, 'middle') + T(60, 58, 'PM', 'ak', 10, 'middle'); },
        'clock-24': function () { return page() + T(60, 46, '15:45', 'ab', 22, 'middle'); },
        'title-count': function () { return page() + R(0, 0, 120, 26, 'as', 0) + R(10, 8, 70, 18, 'ap', 5) + C(20, 17, 4, 'ao') + R(28, 13, 16, 8, 'aa', 4) + B(48, 15, 26, 'ab') + text(12, 38, 96, 4); },
        'title-plain': function () { return page() + R(0, 0, 120, 26, 'as', 0) + R(10, 8, 70, 18, 'ap', 5) + C(20, 17, 4, 'ao') + B(28, 15, 34, 'ab') + text(12, 38, 96, 4); },
        'tooltip-on': function () { return page() + R(42, 14, 36, 14, 'as', 7) + B(50, 19, 20, 'ab') + P('M56 34l4-5l4 5z', 'ad') + R(30, 34, 60, 18, 'ad', 4) + B(38, 41, 44, 'aw'); },
        'tooltip-off': function () { return page() + R(42, 14, 36, 14, 'as', 7) + B(50, 19, 20, 'ab') + cursor(62, 24); },
        'menu-newsblur': function () { return reader(rows(40, 5, 78, 4, { preview: false, h: 12 }), { sel: 1 }) + R(22, 20, 52, 46, 'ap ashadow', 4) + C(30, 29, 3, 'ag') + B(36, 27, 30, 'ab') + C(30, 40, 3, 'ao') + B(36, 38, 24, 'ab') + C(30, 51, 3, 'aa') + B(36, 49, 28, 'ab') + C(30, 60, 3, 'ar') + B(36, 58, 20, 'ab'); },
        'menu-browser': function () { return reader(rows(40, 5, 78, 4, { preview: false, h: 12 }), { sel: 1 }) + R(22, 20, 52, 46, 'as ashadow', 1) + B(27, 27, 36, 'ak') + B(27, 36, 28, 'ak') + R(22, 43, 52, 1, 'al', 0) + B(27, 49, 40, 'ak') + B(27, 58, 22, 'ak'); },

        // ----- Feeds: sidebar -----

        'order-alpha': function () { return page() + R(0, 0, 120, 76, 'as', 0) + _.map(['A', 'B', 'C', 'D'], function (letter, i) { return T(18, 19 + i * 16, letter, 'ab', 11, 'middle') + B(32, 12 + i * 16, [60, 44, 68, 36][i], 'al', 5); }).join(''); },
        'order-used': function () { return page() + R(0, 0, 120, 76, 'as', 0) + _.map([70, 52, 34, 18], function (w, i) { return R(12, 9 + i * 16, w, 9, i == 0 ? 'aa' : 'al', 4) + B(88, 11 + i * 16, 20 - i * 3, 'ak', 5); }).join(''); },
        'counts-collapsed': function () { return page() + R(0, 0, 120, 76, 'as', 0) + P('M12 13l8 0l-4 6z', 'ak') + B(26, 13, 44, 'ab', 5) + B(34, 27, 38, 'al') + R(98, 25, 12, 8, 'aa', 4) + B(34, 39, 30, 'al') + R(98, 37, 12, 8, 'aa', 4) + P('M13 54l6 4l-6 4z', 'ak') + B(26, 55, 36, 'ab', 5) + R(96, 53, 14, 9, 'aa', 4); },
        'counts-always': function () { return page() + R(0, 0, 120, 76, 'as', 0) + P('M12 13l8 0l-4 6z', 'ak') + B(26, 13, 44, 'ab', 5) + R(96, 11, 14, 9, 'aa', 4) + B(34, 27, 38, 'al') + R(98, 25, 12, 8, 'aa', 4) + B(34, 39, 30, 'al') + R(98, 37, 12, 8, 'aa', 4) + P('M13 54l6 4l-6 4z', 'ak') + B(26, 55, 36, 'ab', 5) + R(96, 53, 14, 9, 'aa', 4); },
        'launch-dashboard': function () { return reader(R(42, 6, 34, 28, 'as', 3) + B(46, 11, 20, 'ab') + B(46, 19, 26, 'al', 3) + B(46, 25, 18, 'al', 3) + R(80, 6, 34, 28, 'as', 3) + B(84, 11, 16, 'ab') + B(84, 19, 26, 'al', 3) + R(42, 40, 34, 30, 'as', 3) + B(46, 45, 22, 'ab') + B(46, 53, 26, 'al', 3) + R(80, 40, 34, 30, 'as', 3) + B(84, 45, 18, 'ab') + B(84, 53, 24, 'al', 3)); },
        'launch-folder': function () { return reader(rows(40, 5, 78, 4), { sel: 2, folders: [0, 2, 4] }); },
        'briefing-on': function () { return page() + R(0, 0, 120, 76, 'as', 0) + R(4, 6, 112, 14, 'ay', 4) + R(10, 9, 7, 8, 'ao', 2) + B(22, 11, 50, 'ab', 5) + B(22, 30, 60, 'al', 5) + B(22, 44, 46, 'al', 5) + B(22, 58, 66, 'al', 5) + C(13, 32, 3, 'ak') + C(13, 46, 3, 'ak') + C(13, 60, 3, 'ak'); },
        'briefing-off': function () { return page() + R(0, 0, 120, 76, 'as', 0) + B(22, 12, 60, 'al', 5) + B(22, 28, 46, 'al', 5) + B(22, 44, 66, 'al', 5) + B(22, 60, 40, 'al', 5) + C(13, 14, 3, 'ak') + C(13, 30, 3, 'ak') + C(13, 46, 3, 'ak') + C(13, 62, 3, 'ak'); },

        // ----- Feeds: story list -----

        'layout-full': function () { return reader(R(36, 0, 84, 14, 'as', 0) + B(42, 5, 40, 'ab') + text(42, 21, 72, 3) + R(36, 44, 84, 1, 'al', 0) + B(42, 50, 34, 'ab') + text(42, 58, 72, 2)); },
        'layout-split': function () { return reader(rows(36, 4, 38, 4, { h: 15, sel: 1 }) + R(74, 0, 1, 76, 'al', 0) + B(80, 7, 30, 'ab') + text(80, 17, 34, 7)); },
        'layout-list': function () { return reader(rows(36, 4, 84, 3, { h: 9, gap: 1, preview: false, sel: 1 }) + R(36, 35, 84, 1, 'al', 0) + B(42, 41, 44, 'ab') + text(42, 50, 72, 3)); },
        'layout-grid': function () { return reader(_.map(_.range(6), function (i) { var x = 40 + (i % 3) * 26, y = 5 + Math.floor(i / 3) * 35; return R(x, y, 23, 31, 'as', 3) + R(x, y, 23, 14, 'al', 3) + B(x + 3, y + 18, 16, 'ab', 3) + B(x + 3, y + 24, 12, 'al', 3); }).join('')); },
        'layout-magazine': function () { return reader(_.map(_.range(3), function (i) { var y = 5 + i * 23; return R(40, y, 76, 20, 'as', 3) + R(92, y + 3, 20, 14, 'al', 2) + B(44, y + 4, 38, 'ab') + B(44, y + 11, 44, 'al', 3); }).join('')); },
        'sort-newest': function () { return page() + rows(8, 6, 80, 4, { preview: false, h: 14 }) + arrow(104, 12, 104, 64) + C(104, 12, 3, 'aa'); },
        'sort-oldest': function () { return page() + rows(8, 6, 80, 4, { preview: false, h: 14 }) + arrow(104, 64, 104, 12) + C(104, 64, 3, 'aa'); },
        'filter-all': function () { return page() + row(8, 6, 104, { dot: 'aa', preview: false, h: 14 }) + row(8, 23, 104, { dot: 'al', read: true, preview: false, h: 14 }) + row(8, 40, 104, { dot: 'aa', preview: false, h: 14 }) + row(8, 57, 104, { dot: 'al', read: true, preview: false, h: 14 }); },
        'filter-unread': function () { return page() + row(8, 6, 104, { dot: 'aa', preview: false, h: 14 }) + row(8, 23, 104, { dot: 'aa', preview: false, h: 14 }); },
        'preview-on': function () { return page() + rows(8, 6, 104, 4); },
        'preview-off': function () { return page() + rows(8, 6, 104, 6, { h: 9, preview: false, gap: 2 }); },
        'image-small-left': function () { return page() + rows(8, 5, 104, 4, { image: 'left' }); },
        'image-small-right': function () { return page() + rows(8, 5, 104, 4, { image: 'right' }); },
        'image-large-left': function () { return page() + rows(8, 5, 104, 3, { image: 'left', big: true, h: 21, gap: 2 }); },
        'image-large-right': function () { return page() + rows(8, 5, 104, 3, { image: 'right', big: true, h: 21, gap: 2 }); },
        'image-none': function () { return page() + rows(8, 5, 104, 4); },
        'pill-on': function () { return page() + R(34, 5, 52, 13, 'aa', 7) + B(44, 10, 32, 'aw') + rows(8, 23, 104, 3); },
        'pill-off': function () { return page() + rows(8, 5, 104, 4); },
        'cluster-on': function () { return page() + row(8, 5, 104, {}) + R(16, 24, 96, 26, 'as', 3) + R(16, 24, 3, 26, 'aa', 1) + B(24, 29, 60, 'ak', 3) + B(24, 35, 50, 'ak', 3) + B(24, 41, 66, 'ak', 3) + row(8, 54, 104, {}); },
        'cluster-off': function () { return page() + rows(8, 5, 104, 4); },
        'discover-on': function () { return page() + R(8, 5, 104, 24, 'as', 4) + _.map(_.range(4), function (i) { return R(13 + i * 25, 9, 20, 16, 'al', 3); }).join('') + rows(8, 33, 104, 2); },
        'discover-off': function () { return page() + rows(8, 5, 104, 4); },

        // ----- Stories -----

        'view-page': function () { return page() + R(0, 0, 120, 16, 'ad', 0) + B(8, 6, 26, 'aw') + R(8, 22, 68, 30, 'al', 2) + text(8, 58, 68, 2) + R(84, 22, 28, 48, 'as', 2); },
        'view-feed': function () { return page() + story(0, 120, { lines: 4 }) + R(0, 50, 120, 12, 'as', 0) + B(6, 54, 50, 'ab') + text(6, 67, 108, 1); },
        'view-text': function () { return page() + B(20, 10, 60, 'ab', 5) + text(20, 22, 80, 7, { c: 'ak' }); },
        'view-story': function () { return page() + R(0, 0, 120, 12, 'ad', 0) + B(6, 4, 22, 'aw') + B(20, 20, 62, 'ab', 5) + R(20, 30, 80, 22, 'al', 2) + text(20, 58, 80, 2); },
        // Two stories side by side, the left one shared by a friend. A shortened story fades out
        // over a button that opens the rest of it.
        'truncate-social': function () { return page() + tall(4, true, true) + tall(62, false, false); },
        'truncate-all': function () { return page() + tall(4, true, true) + tall(62, true, false); },
        'truncate-none': function () { return page() + tall(4, false, true) + tall(62, false, false); },
        'link-same': function () { return page() + R(14, 12, 92, 54, 'as', 4) + R(14, 12, 92, 11, 'al', 4) + text(22, 30, 60, 2) + B(22, 46, 34, 'aa') + arrow(62, 48, 84, 48); },
        'link-new': function () { return page() + R(8, 18, 70, 50, 'as', 4) + R(8, 18, 70, 10, 'al', 4) + text(14, 34, 40, 2) + B(14, 50, 26, 'aa') + R(46, 8, 66, 44, 'ap ashadow', 4) + R(46, 8, 66, 10, 'aa', 4) + text(52, 26, 54, 3); },
        'highlight-on': function () { return page() + text(10, 10, 100, 2) + R(10, 24, 62, 7, 'ay', 2) + B(10, 26, 62, 'ak', 3) + B(76, 26, 34, 'al', 3) + text(10, 36, 100, 2) + R(26, 44, 36, 16, 'ad', 5) + C(36, 52, 4, 'ay') + B(44, 50, 12, 'aw'); },
        'highlight-off': function () { return page() + text(10, 10, 100, 8); },
        'captions-on': function () { return page() + R(10, 8, 100, 60, 'ad', 5) + P('M54 30l16 9l-16 9z', 'aw') + R(28, 52, 64, 9, 'ap', 3) + B(33, 55, 54, 'ab', 3); },
        'captions-off': function () { return page() + R(10, 8, 100, 60, 'ad', 5) + P('M54 30l16 9l-16 9z', 'aw'); },
        'buttons-bottom': function () { return page() + B(12, 9, 60, 'ab', 5) + text(12, 21, 96, 4) + _.map(_.range(4), function (i) { return R(12 + i * 25, 54, 21, 12, 'aa', 4); }).join(''); },
        'buttons-right': function () { return page() + B(12, 9, 50, 'ab', 5) + text(12, 21, 70, 7) + _.map(_.range(4), function (i) { return R(92, 12 + i * 15, 18, 11, 'aa', 4); }).join(''); },
        'social-on': function () { return page() + text(10, 9, 100, 3) + R(10, 34, 100, 36, 'as', 4) + C(22, 46, 6, 'aa') + B(34, 42, 40, 'ab') + B(34, 49, 60, 'al', 3) + C(22, 61, 4, 'ao') + B(34, 59, 50, 'al', 3); },
        'social-off': function () { return page() + text(10, 9, 100, 9); },
        'comments-all': function () { return page() + _.map(['aa', 'ao', 'ag', 'ar'], function (c, i) { return C(18, 14 + i * 17, 6, c) + B(32, 10 + i * 17, 34 + (i % 2) * 14, 'ab') + B(32, 17 + i * 17, 60 - (i % 3) * 8, 'al', 3); }).join(''); },
        'comments-friends': function () { return page() + _.map(['aa', 'ag'], function (c, i) { return C(18, 14 + i * 17, 6, c) + B(32, 10 + i * 17, 34 + (i % 2) * 14, 'ab') + B(32, 17 + i * 17, 60 - (i % 3) * 8, 'al', 3); }).join(''); },

        // ----- Behavior -----

        'read-now': function () { return page() + rows(8, 5, 104, 4, { sel: 1, read: [1], preview: false, h: 14 }) + cursor(52, 26) + check(100, 28); },
        'read-delay': function () { return page() + rows(8, 5, 104, 4, { sel: 1, preview: false, h: 14 }) + C(98, 28, 7, 'ap') + C(98, 28, 6, 'astrokeonly') + P('M98 24l0 4l3 2', 'aline'); },
        'read-click': function () { return page() + B(12, 9, 60, 'ab', 5) + text(12, 21, 96, 6) + cursor(58, 36) + check(100, 12); },
        'read-keys': function () { return page() + rows(8, 5, 104, 2, { sel: 0, preview: false, h: 14 }) + key(34, 46, 'u') + key(68, 46, 'm'); },
        'scroll-read': function () { return page() + rows(8, 5, 96, 4, { read: [0, 1], preview: false, h: 14 }) + R(110, 6, 4, 64, 'al', 2) + R(110, 30, 4, 22, 'ak', 2) + arrow(102, 10, 102, 34); },
        'scroll-keep': function () { return page() + rows(8, 5, 96, 4, { preview: false, h: 14 }) + R(110, 6, 4, 64, 'al', 2) + R(110, 30, 4, 22, 'ak', 2) + arrow(102, 10, 102, 34); },
        'confirm-all': function () { return reader(R(46, 16, 64, 42, 'ap ashadow', 5) + B(54, 24, 40, 'ab') + R(54, 40, 22, 11, 'al', 4) + R(80, 40, 22, 11, 'ag', 4), { sel: 1, counts: [1, 3] }); },
        'confirm-folders': function () { return reader(R(46, 16, 64, 42, 'ap ashadow', 5) + B(54, 24, 40, 'ab') + R(54, 40, 22, 11, 'al', 4) + R(80, 40, 22, 11, 'ag', 4), { sel: 0, folders: [0, 3], counts: [0, 3] }); },
        'confirm-never': function () { return reader(rows(40, 5, 78, 4, { read: [0, 1, 2, 3], preview: false, h: 14 }), { sel: 1 }); },
        'after-next': function () { return page() + R(0, 0, 60, 76, 'as', 0) + B(8, 12, 36, 'al') + B(8, 24, 30, 'al') + R(3, 33, 54, 12, 'ay', 3) + B(8, 37, 34, 'ab') + B(8, 52, 28, 'al') + arrow(74, 20, 74, 40) + check(96, 22); },
        'after-stay': function () { return page() + R(0, 0, 60, 76, 'as', 0) + B(8, 12, 36, 'al') + R(3, 20, 54, 12, 'ay', 3) + B(8, 24, 30, 'ab') + B(8, 39, 34, 'al') + B(8, 52, 28, 'al') + check(96, 26); },
        'open-first': function () { return reader(rows(36, 4, 38, 4, { h: 15, sel: 0 }) + R(74, 0, 1, 76, 'al', 0) + B(80, 7, 30, 'ab') + text(80, 17, 34, 7), { sel: 1 }); },
        'open-list': function () { return reader(rows(40, 5, 78, 4), { sel: 1 }); },
        'dbl-open': function () { return page() + sidebar({ sel: 1 }) + R(48, 10, 66, 48, 'ap ashadow', 4) + R(48, 10, 66, 10, 'aa', 4) + text(54, 28, 54, 3) + cursor(24, 20); },
        'dbl-open-read': function () { return page() + sidebar({ sel: 1 }) + R(48, 10, 66, 48, 'ap ashadow', 4) + R(48, 10, 66, 10, 'aa', 4) + text(54, 28, 54, 3) + cursor(24, 20) + check(104, 64); },
        'dbl-nothing': function () { return page() + sidebar({ sel: 1, counts: [1, 3, 4] }) + rows(40, 5, 78, 4, { preview: false, h: 14 }); },
        'dblcount-read': function () { return page() + sidebar({ sel: 1, counts: [3, 4] }) + rows(40, 5, 78, 4, { read: [0, 1, 2, 3], preview: false, h: 14 }) + cursor(27, 18) + check(104, 64); },

        // ----- Keyboard -----

        'keys-views': function () { return page() + _.map(_.range(4), function (i) { return R(8 + i * 27, 12, 23, 14, i == 1 ? 'aa' : 'al', 4); }).join('') + arrow(34, 48, 86, 48) + arrow(86, 48, 34, 48); },
        'keys-sites': function () { return page() + sidebar({ sel: 2, w: 60, widths: [36, 28, 40, 24, 34, 26] }) + arrow(90, 22, 90, 54); },
        'keys-stories': function () { return page() + rows(8, 5, 84, 4, { sel: 1, preview: false, h: 14 }) + arrow(106, 18, 106, 58); },
        'keys-scroll': function () { return page() + B(12, 9, 50, 'ab', 5) + text(12, 21, 82, 7) + R(106, 6, 4, 64, 'al', 2) + R(106, 22, 4, 22, 'ak', 2) + arrow(98, 30, 98, 58); },
        'space-bottom': function () { return page() + text(10, 6, 100, 5) + R(0, 44, 120, 2, 'aa', 0) + B(10, 54, 60, 'ab', 5) + text(10, 65, 100, 1); },
        'space-half': function () { return page() + text(10, 6, 100, 3) + R(0, 30, 120, 2, 'aa', 0) + B(10, 40, 60, 'ab', 5) + text(10, 51, 100, 3); },
        'space-scroll': function () { return page() + B(12, 9, 50, 'ab', 5) + text(12, 21, 82, 7) + R(106, 6, 4, 64, 'al', 2) + R(106, 30, 4, 26, 'ak', 2) + arrow(98, 14, 98, 60); }

    };

    return {
        // reader_preferences_art.js: the drawing for one card, as an inline SVG string.
        draw: function (name) {
            var shapes = art[name] ? art[name]() : page();
            return '<svg class="NB-pref-art-svg" viewBox="0 0 120 76" preserveAspectRatio="xMidYMid slice" aria-hidden="true" focusable="false">' + shapes + '</svg>';
        },
        has: function (name) { return !!art[name]; }
    };

})();
