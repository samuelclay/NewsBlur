/* nav_dropdown.js - Hover-intent dropdown menus for splash page navigation */

$(document).ready(function () {
    var $dropdowns = $('.NB-splash-nav-has-dropdown');
    if (!$dropdowns.length) return;

    var open_timer = null;
    var close_timer = null;
    var $active = null;

    $dropdowns.on('mouseenter', function () {
        var $this = $(this);
        clearTimeout(close_timer);
        clearTimeout(open_timer);

        if ($active && $active[0] !== $this[0]) {
            $active.removeClass('NB-splash-nav-dropdown-open');
        }

        open_timer = setTimeout(function () {
            $this.addClass('NB-splash-nav-dropdown-open');
            $active = $this;
        }, 150);
    });

    $dropdowns.on('mouseleave', function () {
        var $this = $(this);
        clearTimeout(open_timer);

        close_timer = setTimeout(function () {
            $this.removeClass('NB-splash-nav-dropdown-open');
            if ($active && $active[0] === $this[0]) {
                $active = null;
            }
        }, 300);
    });

    $(document).on('click', function (e) {
        if ($active && !$(e.target).closest('.NB-splash-nav-has-dropdown').length) {
            $active.removeClass('NB-splash-nav-dropdown-open');
            $active = null;
        }
    });

    $(document).on('keydown', function (e) {
        if (e.key === 'Escape' && $active) {
            $active.removeClass('NB-splash-nav-dropdown-open');
            $active = null;
        }
    });
});
