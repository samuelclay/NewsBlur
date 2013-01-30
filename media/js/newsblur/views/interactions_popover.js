NEWSBLUR.InteractionsPopover = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-interactions-popover",
    
    options: {
        'width': 336,
        'anchor': '.NB-feeds-header-user-interactions',
        'placement': 'bottom',
        'overlay_top': true,
        offset: {
            top: -8,
            left: -1
        }
    },
    
    events: {
    },
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        this.model = NEWSBLUR.assets;
        this.make_modal();
        
        NEWSBLUR.ReaderPopover.prototype.initialize.apply(this);
        
        $(".NB-feeds-header-user-notifications").addClass('NB-active');
    },
    
    close: function() {
        $(".NB-feeds-header-user-notifications").removeClass('NB-active');
        NEWSBLUR.ReaderPopover.prototype.close.apply(this);
    },

    make_modal: function() {
        var self = this;
        
        this.$el.html($.make('div', [
            'Interactions!'
        ]));
        
        return this;
    }
    
    // ==========
    // = Events =
    // ==========
    
    
});