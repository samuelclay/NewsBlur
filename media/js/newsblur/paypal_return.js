(function($) {

    $(document).ready(function() {
        NEWSBLUR.paypal_return = new NEWSBLUR.PaypalReturn();
    });

    NEWSBLUR.PaypalReturn = function() {
        this.retries = 0;
        _.delay(_.bind(function() { this.detect_premium(); }, this), 1500);
    };

    NEWSBLUR.PaypalReturn.prototype = {

        detect_premium: function() {
            $.get('/profile/is_premium', {'retries': this.retries}, _.bind(function(resp) {
                if (resp.activated_subs == resp.total_subs || resp.code < 0) {
                    window.location.href = '/';
                } else if (resp.activated_subs != resp.total_subs) {
                    this.retries += 1;
                    _.delay(_.bind(function() {
                        this.detect_premium();
                    }, this), 2000);
                    $('.NB-paypal-return-loading').progressbar({
                        value: (resp.activated_subs / resp.total_subs) * 100
                    });
                }
            }, this));
        }

    };
    
})(jQuery);