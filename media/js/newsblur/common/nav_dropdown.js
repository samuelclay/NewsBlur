/* nav_dropdown.js - Hover-intent dropdown menus for splash page navigation.
   Dropdowns are moved to <body> so they sit outside the header's
   backdrop-filter stacking context, allowing their own backdrop-filter
   to render correctly. */

$(document).ready(function () {
    var $triggers = $('.NB-splash-nav-has-dropdown');
    if (!$triggers.length) return;

    var open_timer = null;
    var close_timer = null;
    var $active_trigger = null;
    var $active_dropdown = null;

    // Move each dropdown out of its <li> and into <body>.
    // Store references so trigger ↔ dropdown can find each other.
    $triggers.each(function () {
        var $trigger = $(this);
        var $dropdown = $trigger.children('.NB-splash-dropdown');
        if (!$dropdown.length) return;

        // Give each pair a shared key
        var key = 'dropdown-' + Math.random().toString(36).slice(2, 9);
        $trigger.attr('data-dropdown-key', key);
        $dropdown.attr('data-dropdown-key', key);

        // Move to body
        $dropdown.appendTo('body');
    });

    function get_dropdown($trigger) {
        var key = $trigger.attr('data-dropdown-key');
        return $('.NB-splash-dropdown[data-dropdown-key="' + key + '"]');
    }

    function position_dropdown($trigger, $dropdown) {
        var trigger_rect = $trigger[0].getBoundingClientRect();
        var dropdown_width = $dropdown.outerWidth();
        var left = trigger_rect.left + (trigger_rect.width / 2) - (dropdown_width / 2);

        // Keep within viewport
        var max_left = window.innerWidth - dropdown_width - 16;
        if (left < 16) left = 16;
        if (left > max_left) left = max_left;

        $dropdown.css({
            position: 'fixed',
            top: trigger_rect.bottom + 'px',
            left: left + 'px',
            zIndex: 10000
        });
    }

    function open($trigger) {
        var $dropdown = get_dropdown($trigger);
        if (!$dropdown.length) return;

        // Close any previously active dropdown
        if ($active_trigger && $active_trigger[0] !== $trigger[0]) {
            close($active_trigger);
        }

        position_dropdown($trigger, $dropdown);
        $trigger.addClass('NB-splash-nav-dropdown-open');
        $dropdown.addClass('NB-splash-nav-dropdown-open');
        $active_trigger = $trigger;
        $active_dropdown = $dropdown;
    }

    function close($trigger) {
        if (!$trigger) return;
        var $dropdown = get_dropdown($trigger);
        $trigger.removeClass('NB-splash-nav-dropdown-open');
        $dropdown.removeClass('NB-splash-nav-dropdown-open');
        if ($active_trigger && $active_trigger[0] === $trigger[0]) {
            $active_trigger = null;
            $active_dropdown = null;
        }
    }

    // Trigger hover
    $triggers.on('mouseenter', function () {
        var $trigger = $(this);
        clearTimeout(close_timer);
        clearTimeout(open_timer);

        open_timer = setTimeout(function () {
            open($trigger);
        }, 150);
    });

    $triggers.on('mouseleave', function () {
        var $trigger = $(this);
        clearTimeout(open_timer);

        close_timer = setTimeout(function () {
            close($trigger);
        }, 300);
    });

    // Dropdown hover (keep open while mouse is over the detached dropdown)
    $(document).on('mouseenter', '.NB-splash-dropdown', function () {
        clearTimeout(close_timer);
        clearTimeout(open_timer);
    });

    $(document).on('mouseleave', '.NB-splash-dropdown', function () {
        var $dropdown = $(this);
        var key = $dropdown.attr('data-dropdown-key');
        var $trigger = $('.NB-splash-nav-has-dropdown[data-dropdown-key="' + key + '"]');

        close_timer = setTimeout(function () {
            close($trigger);
        }, 300);
    });

    // Click outside closes
    $(document).on('click', function (e) {
        if ($active_trigger &&
            !$(e.target).closest('.NB-splash-nav-has-dropdown').length &&
            !$(e.target).closest('.NB-splash-dropdown').length) {
            close($active_trigger);
        }
    });

    // Escape closes
    $(document).on('keydown', function (e) {
        if (e.key === 'Escape' && $active_trigger) {
            close($active_trigger);
        }
    });

    // Reposition on scroll/resize
    $(window).on('scroll resize', function () {
        if ($active_trigger && $active_dropdown) {
            position_dropdown($active_trigger, $active_dropdown);
        }
    });
});
