/* theme_toggle.js - Dark mode toggle for landing and static pages */

$(document).ready(function () {
    var $toggle = $('.NB-theme-toggle');
    if (!$toggle.length) return;

    var TTL_MS = 6 * 60 * 60 * 1000; // 6 hours

    function read_override() {
        try {
            var raw = localStorage.getItem('newsblur:theme');
            if (!raw) return null;
            var obj = JSON.parse(raw);
            if (obj && obj.theme && obj.ts && (Date.now() - obj.ts < TTL_MS)) {
                return obj.theme;
            }
            localStorage.removeItem('newsblur:theme');
        } catch (e) {
            try { localStorage.removeItem('newsblur:theme'); } catch (e2) {}
        }
        return null;
    }

    function system_theme() {
        return (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : 'light';
    }

    function get_theme() {
        return read_override() || system_theme();
    }

    // theme_toggle.js: a click fades between themes the way the reader does (reader_utils.js
    // switch_theme_classes). Loading the page and following the system change at once.
    function apply(theme, animate) {
        var is_dark = theme === 'dark';
        if (animate && window.NEWSBLUR && NEWSBLUR.utils && NEWSBLUR.utils.switch_theme_classes) {
            NEWSBLUR.utils.switch_theme_classes({ 'NB-dark': is_dark }, true);
        } else {
            $('body').toggleClass('NB-dark', is_dark);
        }
    }

    // Apply on load (covers static pages where reader.load_theme doesn't run)
    apply(get_theme());

    // Toggle click (whole container: icons + track)
    $toggle.on('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var next = (get_theme() === 'dark') ? 'light' : 'dark';
        try {
            localStorage.setItem('newsblur:theme', JSON.stringify({theme: next, ts: Date.now()}));
        } catch (e) {}
        apply(next, true);

        // Sync with reader if it exists (welcome page)
        if (window.NEWSBLUR && NEWSBLUR.reader && NEWSBLUR.reader.switch_theme) {
            NEWSBLUR.reader.switch_theme(next);
        }
    });

    // Listen for system theme changes when no manual override is active
    if (window.matchMedia) {
        var mq = window.matchMedia('(prefers-color-scheme: dark)');
        var on_system_change = function () {
            if (!read_override()) {
                apply(system_theme());
            }
        };
        try {
            mq.addEventListener('change', on_system_change);
        } catch (e1) {
            try { mq.addListener(on_system_change); } catch (e2) {}
        }
    }
});
