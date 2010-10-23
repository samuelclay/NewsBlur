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
                if (resp.is_premium || resp.code < 0) {
                    window.location.href = '/';
                } else if (!resp.is_premium) {
                    this.retries += 1;
                    _.delay(_.bind(function() {
                        this.detect_premium();
                    }, this), 3000);
                }
            }, this));
        }

    };
    
})(jQuery);