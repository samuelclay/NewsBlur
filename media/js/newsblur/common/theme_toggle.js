/* theme_toggle.js - Dark mode toggle for landing and static pages */

$(document).ready(function () {
    var $toggle = $('.NB-theme-toggle');
    if (!$toggle.length) return;

    function get_theme() {
        var stored;
        try { stored = localStorage.getItem('newsblur:theme'); } catch (e) {}
        if (stored && stored !== 'auto') return stored;

        var pref = (window.NEWSBLUR && NEWSBLUR.Preferences) ? NEWSBLUR.Preferences.theme : 'auto';
        if (pref === 'auto' || !pref) {
            return (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : 'light';
        }
        return pref;
    }

    function apply(theme) {
        if (theme === 'dark') {
            $('body').addClass('NB-dark');
        } else {
            $('body').removeClass('NB-dark');
        }
    }

    // Apply on load (covers static pages where reader.load_theme doesn't run)
    apply(get_theme());

    // Toggle click (whole container: icons + track)
    $toggle.on('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var next = (get_theme() === 'dark') ? 'light' : 'dark';
        try { localStorage.setItem('newsblur:theme', next); } catch (e) {}
        apply(next);

        // Sync with reader if it exists (welcome page)
        if (window.NEWSBLUR && NEWSBLUR.reader && NEWSBLUR.reader.switch_theme) {
            NEWSBLUR.reader.switch_theme(next);
        }
    });

    // Listen for system theme changes when no explicit override is set
    if (window.matchMedia) {
        var mq = window.matchMedia('(prefers-color-scheme: dark)');
        var on_system_change = function () {
            var stored;
            try { stored = localStorage.getItem('newsblur:theme'); } catch (e) {}
            if (!stored || stored === 'auto') {
                apply(get_theme());
            }
        };
        try {
            mq.addEventListener('change', on_system_change);
        } catch (e1) {
            try { mq.addListener(on_system_change); } catch (e2) {}
        }
    }
});
