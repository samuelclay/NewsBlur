(function($) {

    $(document).ready(function() {
        if($('.NB-paypal-return').length) {
            NEWSBLUR.paypal_return = new NEWSBLUR.PaypalReturn();
        }
    });

    NEWSBLUR.PaypalReturn = function() {
        this.retries = 0;
        _.delay(_.bind(function () {
            if (_.string.include(window.location.pathname, 'paypal_archive')) {
                this.detect_premium_archive();
                setInterval(_.bind(function() { this.detect_premium_archive(); }, this), 2000);
            } else {
                this.detect_premium();
                setInterval(_.bind(function() { this.detect_premium(); }, this), 2000);
            }
        }, this), 2000);
    };

    NEWSBLUR.PaypalReturn.prototype = {

        detect_premium: function() {
            $.ajax({
                'url'      : '/profile/is_premium', 
                'data'     : {'retries': this.retries}, 
                'dataType' : 'json',
                'success'  : _.bind(function(resp) {
                    // NEWSBLUR.log(['resp', resp]);
                    if (resp.code < 0) {
                        this.homepage();
                    } else if ((resp.activated_subs >= resp.total_subs && resp.is_premium)) {
                        this.homepage();
                    } else if (resp.activated_subs != resp.total_subs || !resp.is_premium) {
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

        detect_premium_archive: function() {
            $.ajax({
                'url'      : '/profile/is_premium_archive', 
                'data'     : {'retries': this.retries}, 
                'dataType' : 'json',
                'success'  : _.bind(function(resp) {
                    // NEWSBLUR.log(['resp', resp]);
                    if (resp.code < 0) {
                        this.homepage();
                    } else if ((resp.activated_subs >= resp.total_subs && resp.is_premium_archive)) {
                        this.homepage();
                    } else if (resp.activated_subs != resp.total_subs || !resp.is_premium_archive) {
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
