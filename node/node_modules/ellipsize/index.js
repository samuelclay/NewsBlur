'use strict';

var defaults = {
    ellipse: '…',
    chars: [' ', '-'],
    max: 140,
    truncate: true
};

function ellipsize(str, max, ellipse, chars, truncate) {
    if (str.length < max) return str;

    var last = 0,
        c = '',
        midMax = Math.floor(max / 2),
        computedMax = truncate === 'middle' ? midMax : max;

    for (var i = 0, len = str.length; i < len; i++) {
        c = str.charAt(i);

        if (chars.indexOf(c) !== -1 && truncate !== 'middle') {
            last = i;
        }

        if (i < computedMax) continue;
        if (last === 0) {
            return !truncate ? 
                '' : 
                str.substring(0, computedMax - 1) + ellipse + (
                    truncate === 'middle' ? 
                    str.substring(str.length - midMax, str.length) : 
                    ''
                );
        }

        return str.substring(0, last) + ellipse;
    }

    return str;
}

module.exports = function(str, max, opts) {
    if (typeof str !== 'string' || str.length === 0) return '';
    if (max === 0) return '';

    opts = opts || {};

    for (var key in defaults) {
        if (opts[key] === null || typeof opts[key] === 'undefined') {
            opts[key] = defaults[key];
        }
    }

    opts.max = max || opts.max;

    return ellipsize(str, opts.max, opts.ellipse, opts.chars, opts.truncate);
};
