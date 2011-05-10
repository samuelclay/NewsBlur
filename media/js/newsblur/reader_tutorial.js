NEWSBLUR.ReaderTutorial = function(options) {
    var defaults = {};
    
    _.bindAll(this, 'close');

    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.AssetModel.reader();

    this.runner();
};

NEWSBLUR.ReaderTutorial.prototype = _.extend({}, NEWSBLUR.Modal.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-email NB-modal' }, [
            $.make('span', { className: 'NB-modal-loading NB-spinner'}),
            $.make('h2', { className: 'NB-modal-title' }, 'Learn to use NewsBlur')
        ]);
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-save' }, function($t, $p) {
            e.preventDefault();
            
            self.save();
            return false;
        });
    }
    
});