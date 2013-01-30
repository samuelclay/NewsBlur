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
    },
    
    render: function($content) {
        var self = this;
        this._open = true;
        console.log(["popover render", this.$el, this.options.animate]);
        this.$popover = $.make("div", { className: "NB-popover popover fade" }, [
            $.make('div', { className: "arrow" }),
            $.make('div', { className: "popover-inner" }, [
                $.make('div', { className: "popover-content" }, $content || this.$el)
            ])
        ]);
        
        this.$overlay = $.make('div', { className: 'NB-overlay fade ' + (this.options.overlay_top && "NB-top") });
        $('body').append(this.$overlay);
        
        this.$popover.width(this.options.width);
        
        $('body').append(this.$popover);
        
        this.$popover.addClass(this.options.placement.replace('-', '').replace(' ', '-'));
        this.$popover.addClass(this.options.popover_class);
        this.$popover.align(this.anchor(), this.options.placement, this.options.offset);
        this.autohide = this.$popover.autohide({
            clickable: true,
            onHide: _.bind(this.close, this)
        });
        
        if (this.options.animate) {
            this.$popover.addClass("in");
            this.$overlay.addClass("in");
        }
        
        return this;
    },
    
    close: function(e, hide_callback) {
        var $el = window.a = this.$popover;
        var self = this;
        if (_.isFunction(e)) hide_callback = e;
        hide_callback = hide_callback || $.noop;
        this.$popover.removeClass('in');
        this.$overlay.removeClass('in');
        this.options.on_hide && this.options.on_hide();

        function removeWithAnimation() {
            var timeout = setTimeout(function () {
                $el.off($.support.transition.end);
                if (!self._open) return;
                self._open = false;
                $el.remove();
                self.$overlay.remove();
                self.autohide.removeHide();
                self.remove();
                hide_callback();
            }, 500);

            $el.one($.support.transition.end, function () {
                clearTimeout(timeout);
                if (!self._open) return;
                self._open = false;
                $el.remove();
                self.$overlay.remove();
                self.autohide.removeHide();
                self.remove();
                hide_callback();
            });
        }

        if ($.support.transition && this.$popover.hasClass('fade')) {
            removeWithAnimation();
        } else {
            this._open = false;
            this.$popover.remove();
            this.$overlay.remove();
            this.autohide.removeHide();
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
        
    },
    
    close: function() {
        if (this._popover && this._popover._open) {
            this._popover.close();
        }
    }
    
});