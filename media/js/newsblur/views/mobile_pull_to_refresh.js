// mobile_pull_to_refresh.js: pull-to-refresh for the phone layout's scrolling lists
// (views/mobile_layout_view.js). Pulling down past the top of the list slides it down over a
// spinner; letting go past the threshold runs options.refresh(done) and holds the spinner until
// done is called. Styles are in media/css/reader/mobile.css.
NEWSBLUR.Views.MobilePullToRefresh = Backbone.View.extend({

    THRESHOLD: 70,
    HOLD_OFFSET: 56,
    MIN_SPIN_MS: 600,
    MAX_SPIN_MS: 15000,

    initialize: function (options) {
        _.bindAll(this, 'handle_touchstart', 'handle_touchmove', 'handle_touchend');
        this.scroller = options.scroller;
        this.refresh = options.refresh;
        this.is_enabled = options.is_enabled || function () { return true; };
        this.refreshing = false;

        this.$indicator = $.make('div', { className: 'NB-mobile-ptr' }, [
            $.make('div', { className: 'NB-mobile-ptr-spinner' })
        ]);
        $(this.scroller).before(this.$indicator);

        this.scroller.addEventListener('touchstart', this.handle_touchstart, { passive: true });
        this.scroller.addEventListener('touchmove', this.handle_touchmove, { passive: false });
        this.scroller.addEventListener('touchend', this.handle_touchend, { passive: true });
        this.scroller.addEventListener('touchcancel', this.handle_touchend, { passive: true });
    },

    handle_touchstart: function (e) {
        this.pull = null;
        if (this.refreshing || e.touches.length !== 1 || !this.is_enabled()) return;
        if (this.scroller.scrollTop > 0) return;
        this.pull = {
            start_x: e.touches[0].clientX,
            start_y: e.touches[0].clientY,
            distance: 0,
            active: false
        };
    },

    handle_touchmove: function (e) {
        var pull = this.pull;
        if (!pull) return;
        var dx = e.touches[0].clientX - pull.start_x;
        var dy = e.touches[0].clientY - pull.start_y;
        if (!pull.active) {
            var axis = NEWSBLUR.mobile_utils.gesture_axis(dx, dy);
            if (!axis) return;
            if (axis !== 'vertical' || dy <= 0 || this.scroller.scrollTop > 0) {
                this.pull = null;
                return;
            }
            pull.active = true;
            $(this.scroller).addClass('NB-mobile-ptr-dragging');
            this.$indicator.addClass('NB-mobile-ptr-visible');
        }
        e.preventDefault();
        // Resist the further it goes, the way a native list does.
        pull.distance = Math.max(0, dy) * 0.5;
        this.render(pull.distance);
    },

    handle_touchend: function () {
        var pull = this.pull;
        this.pull = null;
        if (!pull || !pull.active) return;
        $(this.scroller).removeClass('NB-mobile-ptr-dragging');
        if (pull.distance >= this.THRESHOLD) {
            this.start_refresh();
        } else {
            this.settle(0);
        }
    },

    render: function (distance) {
        this.scroller.style.transform = 'translate3d(0, ' + distance + 'px, 0)';
        var progress = Math.min(1, distance / this.THRESHOLD);
        this.$indicator.css({
            opacity: progress,
            transform: 'rotate(' + Math.round(progress * 270) + 'deg) scale(' + (0.6 + progress * 0.4) + ')'
        });
        this.$indicator.toggleClass('NB-mobile-ptr-armed', progress >= 1);
    },

    settle: function (distance, complete) {
        var $scroller = $(this.scroller);
        $scroller.addClass('NB-mobile-ptr-settling');
        this.scroller.style.transform = distance ? 'translate3d(0, ' + distance + 'px, 0)' : '';
        if (!distance) {
            this.$indicator.css({ opacity: 0 });
        }
        var self = this;
        setTimeout(function () {
            $scroller.removeClass('NB-mobile-ptr-settling');
            if (!distance) {
                self.$indicator.removeClass('NB-mobile-ptr-visible NB-mobile-ptr-armed NB-mobile-ptr-spinning')
                    .css({ transform: '' });
            }
            if (complete) complete();
        }, 300);
    },

    start_refresh: function () {
        this.refreshing = true;
        this.$indicator.addClass('NB-mobile-ptr-spinning').css({ opacity: 1, transform: '' });
        this.settle(this.HOLD_OFFSET);
        var started = Date.now();
        var finished = false;
        var self = this;
        var done = function () {
            if (finished) return;
            finished = true;
            clearTimeout(give_up);
            var wait = Math.max(0, self.MIN_SPIN_MS - (Date.now() - started));
            setTimeout(function () {
                self.settle(0, function () {
                    self.refreshing = false;
                });
            }, wait);
        };
        // A refresh that never reports back still lets go of the list eventually.
        var give_up = setTimeout(done, this.MAX_SPIN_MS);
        this.refresh(done);
    }

});
