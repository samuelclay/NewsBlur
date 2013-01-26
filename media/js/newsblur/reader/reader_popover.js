NEWSBLUR.ReaderPopover = Backbone.View.extend({
    
    _open: false,
    
    events: {
        "click .NB-modal-cancel": "close"
    },
    
    initialize: function(options) {
        this.options = _.extend({}, {
            width: 236,
            animate: true,
            offset: {
                top: 0,
                left: 0
            }
        }, this.options, options);
        this.render();
    },
    
    render: function() {
        var self = this;
        this._open = true;

        var $popover = $.make("div", { className: "NB-popover popover fade" }, [
            $.make('div', { className: "arrow" }),
            $.make('div', { className: "popover-inner" }, [
                $.make('div', { className: "popover-content" }, [
                    this.$el
                ])
            ])
        ]);
        this.setElement($popover);
        
        this.$el.width(this.options.width);
        
        $('body').append(this.$el);
        
        this.$el.addClass(this.options.placement.replace('-', '').replace(' ', '-'));
        this.$el.align(this.anchor(), this.options.placement, this.options.offset);
        this.$el.autohide({
            clickable: true,
            onHide: _.bind(this.close, this)
        });
        
        if (this.options.animate) {
            this.$el.addClass("in");
        }
        
        return this;
    },
    
    close: function(e, hide_callback) {
        var $el = this.$el;
        var self = this;
        if (_.isFunction(e)) hide_callback = e;
        hide_callback = hide_callback || $.noop;
        this.$el.removeClass('in');
        this.options.on_hide && this.options.on_hide();

        function removeWithAnimation() {
            var timeout = setTimeout(function () {
                $el.off($.support.transition.end);
                self._open = false;
                self.remove();
                hide_callback();
            }, 500);

            $el.one($.support.transition.end, function () {
                clearTimeout(timeout);
                self._open = false;
                self.remove();
                hide_callback();
            });
        }

        if ($.support.transition && this.$el.hasClass('fade')) {
            removeWithAnimation();
        } else {
            this._open = false;
            this.remove();
            hide_callback();
        }
        
        return false;
    },
    
    anchor: function() {
        if (_.isFunction(this.options.anchor)) {
            return this.options.anchor();
        } else {
            return $(this.options.anchor);
        }
    }
    
}, {
    
    create: function(options) {
        
        if (this._popover && this._popover._open) {
            this._popover.close();
        } else {
            this._popover = new this(options);
        }
        
    }
    
});