// payment_return.js: drives templates/reader/payment_return.xhtml. Polls the account until the plan
// its page is waiting for is on (profile_is_premium in apps/profile/views.py), lights up the
// account's sites as they are turned on, then opens the reader.
(function ($) {

    $(document).ready(function () {
        var $el = $('.NB-payment-return');
        if ($el.length) {
            NEWSBLUR.payment_return = new NEWSBLUR.PaymentReturn($el);
        }
    });

    NEWSBLUR.PaymentReturn = function ($el) {
        this.$el = $el;
        this.plan = $el.data('plan') || '';
        // ?test=return plays this page without an account being upgraded and stays on it, and
        // ?test=slow shows it for an account that never catches up (Test Query Parameters in CLAUDE.md).
        var test = $.getQueryString('test');
        this.test = _.contains(['return', 'slow'], test) ? test : null;
        this.retries = 0;
        this.activated_subs = null;
        this.lights_finish_at = 0;
        this.check_status();
    };

    NEWSBLUR.PaymentReturn.prototype = {

        // Most accounts are ready within a second or two, so the first polls come quickly.
        FAST_POLLS: 5,
        FAST_DELAY: 1000,
        SLOW_DELAY: 2000,
        // PAYMENT_RETURN_LAST_RETRY in apps/profile/views.py: the poll on which the server stops waiting.
        LAST_RETRY: 30,
        // Milliseconds between one site lighting up and the next.
        LIGHT_STAGGER: 12,
        // How long a site takes to light up (the transitions in media/css/pages/payments.css).
        LIGHT_DURATION: 500,
        // How long the finished page stays up before the reader opens.
        READY_PAUSE: 900,

        check_status: function () {
            if (this.test) {
                this.handle_status(this.test_status());
                return;
            }

            var data = { 'retries': this.retries, 'plan': this.plan };
            if (this.activated_subs !== null) {
                // The server compares this with the current count to tell when sites stop turning on.
                data['activated'] = this.activated_subs;
            }
            $.ajax({
                'url': '/profile/is_premium',
                'data': data,
                'dataType': 'json',
                'success': _.bind(this.handle_status, this),
                'error': _.bind(this.handle_error, this)
            });
        },

        handle_status: function (resp) {
            this.light_sites(resp.active_feed_ids || []);
            this.update_count(resp.activated_subs, resp.total_subs);
            this.activated_subs = resp.activated_subs;

            if (resp.ready || (resp.code < 0 && resp.plan_active)) {
                this.finish();
            } else if (resp.code < 0) {
                this.show_slow();
            } else {
                this.wait_and_check();
            }
        },

        handle_error: function () {
            if (this.retries >= this.LAST_RETRY) {
                this.show_slow();
            } else {
                this.wait_and_check();
            }
        },

        wait_and_check: function () {
            this.retries += 1;
            var delay = this.retries <= this.FAST_POLLS ? this.FAST_DELAY : this.SLOW_DELAY;
            _.delay(_.bind(this.check_status, this), delay);
        },

        light_sites: function (active_feed_ids) {
            var active = {};
            _.each(active_feed_ids, function (feed_id) { active[feed_id] = true; });

            var newly_lit = 0;
            var stagger = this.LIGHT_STAGGER;
            this.$el.find('.NB-payment-return-site').each(function () {
                var $site = $(this);
                var is_on = !!active[$site.data('feed-id')];
                if (is_on == $site.hasClass('NB-on')) return;

                var delay = (is_on ? newly_lit * stagger : 0) + 'ms';
                if (is_on) newly_lit += 1;
                $site.css({ 'transition-delay': delay, 'animation-delay': delay });
                $site.find('img').css('transition-delay', delay);
                $site.toggleClass('NB-on', is_on);
            });

            if (newly_lit) {
                this.lights_finish_at = Date.now() + newly_lit * stagger + this.LIGHT_DURATION;
            }
        },

        update_count: function (activated_subs, total_subs) {
            if (!total_subs) return;

            var count = interpolate(ngettext(
                "%(turned_on)s of %(total)s site turned on",
                "%(turned_on)s of %(total)s sites turned on",
                total_subs
            ), { turned_on: '<b>' + activated_subs + '</b>', total: total_subs }, true);
            this.$el.find('.NB-payment-return-count').html(count);
        },

        finish: function () {
            this.$el.addClass('NB-ready');
            // Let the last sites finish lighting up before leaving.
            var pause = Math.max(this.READY_PAUSE, this.lights_finish_at - Date.now() + this.READY_PAUSE / 2);
            _.delay(_.bind(this.open_reader, this), pause);
        },

        show_slow: function () {
            this.$el.addClass('NB-slow');
        },

        open_reader: function () {
            if (this.test) return;
            window.location.href = '/';
        },

        // What check_status would get from the server, made up from the sites on the page: a quarter
        // more of them turned on with each poll, or a few and then nothing more for ?test=slow.
        test_status: function () {
            var feed_ids = this.$el.find('.NB-payment-return-site').map(function () {
                return $(this).data('feed-id');
            }).get();
            var slow = this.test == 'slow';
            var turned_on = Math.round(feed_ids.length * (slow ? 0.15 : Math.min(1, (this.retries + 1) / 4)));

            return {
                'code': slow && this.retries >= 2 ? -1 : 0,
                'ready': !slow && turned_on >= feed_ids.length,
                'plan_active': !slow,
                'activated_subs': turned_on,
                'total_subs': feed_ids.length,
                'active_feed_ids': feed_ids.slice(0, turned_on)
            };
        }

    };

})(jQuery);
