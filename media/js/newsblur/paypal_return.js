(function($) {

    $(document).ready(function() {
        if($('.NB-paypal-return').length) {
            NEWSBLUR.paypal_return = new NEWSBLUR.PaypalReturn();
        }
    });

    NEWSBLUR.PaypalReturn = function() {
        this.retries = 0;
        this.detect_premium();
        setInterval(_.bind(function() { this.detect_premium(); }, this), 1500);
    };

    NEWSBLUR.PaypalReturn.prototype = {

        detect_premium: function() {
            $.ajax({
                'url'      : '/profile/is_premium', 
                'data'     : {'retries': this.retries}, 
                'dataType' : 'json',
                'success'  : _.bind(function(resp) {
                    // NEWSBLUR.log(['resp', resp]);
                    if ((resp.activated_subs >= resp.total_subs || resp.code < 0)) {
                        this.homepage();
                    } else if (resp.activated_subs != resp.total_subs) {
                        this.retries += 1;
                        $('.NB-paypal-return-loading').progressbar({
                            value: (resp.activated_subs / resp.total_subs) * 100
                        });
                    }
                }, this),
                'error'    : _.bind(function() {
                    this.retries += 1;
                    if (this.retries > 30) {
                        this.homepage();
                    }
                }, this)
            });
        },
        
        homepage: function() {
            window.location.href = '/';
        }

    };
    
})(jQuery);