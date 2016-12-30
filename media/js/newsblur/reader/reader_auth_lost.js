NEWSBLUR.ReaderAuthLost = function(options) {
    var defaults = {
        'overlayClose': false,
        'height': 100
    };
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderAuthLost.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderAuthLost.prototype.constructor = NEWSBLUR.ReaderAuthLost;

_.extend(NEWSBLUR.ReaderAuthLost.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-authlost NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Your cookie has expired — Please login again'
            ]),
            $.make('div', { className: 'NB-authlost-group' }, [
                $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green' }, 'Reload NewsBlur')
            ])
        ]);
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-button' }, function($t, $p) {
            e.preventDefault();
            
            window.location.href = "/";
        });

    }
    
});