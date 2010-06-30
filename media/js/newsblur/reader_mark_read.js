NEWSBLUR.ReaderMarkRead = function(options) {
    var defaults = {
        'days': 1
    };
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner();
};

NEWSBLUR.ReaderMarkRead.prototype = {
    
    runner: function() {
        this.make_modal();
        this.load_slider();
        this.generate_explanation(this.options['days']);
        this.handle_cancel();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-markread NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Mark old stories as read'),
            $.make('form', { className: 'NB-markread-form' }, [
                $.make('div', { className: 'NB-markread-slider'}),
                $.make('div', { className: 'NB-markread-explanation'}),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', className: '', value: 'Do it' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save_mark_read();
                return false;
            })
        ]);
    },
    
    open_modal: function() {
        var self = this;

        var $holder = $.make('div', { className: 'NB-modal-holder' }).append(this.$modal).appendTo('body').css({'visibility': 'hidden', 'display': 'block', 'width': 600});
        var height = $('.NB-add', $holder).outerHeight(true);
        $holder.css({'visibility': 'visible', 'display': 'none'});
        
        var w = $.modal.impl.getDimensions();
        if (height > w[0] - 70) {
            height = w[0] - 70;
        }
        
        this.$modal.modal({
            'minWidth': 600,
            'maxHeight': height,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px').css({'width': 600, 'height': height});
                // $('.NB-classifier-tag', self.$modal).corner('4px');
            },
            'onClose': function(dialog) {
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(200, function() {
                    dialog.overlay.empty().remove();
                    $.modal.close();
                });
                $('.NB-modal-holder').empty().remove();
            }
        });
    },
    
    load_slider: function() {
        var self = this;
        var $slider = $('.NB-markread-slider', this.$modal);
        
        $slider.slider({
            range: 'min',
            min: 0,
            max: 7,
            step: 1,
            value: this.options['days'],
            slide: function(e, ui) {
                var value = ui.value;
                self.update_dayofweek(value);
                self.generate_explanation(value);
            },
            stop: function(e, ui) {
                
            }
        });

    },
    
    update_dayofweek: function(value) {
        
    },
    
    generate_explanation: function(value) {
        var $explanation = $('.NB-markread-explanation', this.$modal);
        var explanation;
        
        if (value == 0) {
            explanation = "Mark <b>every story</b> as read.";
        } else if (value >= 1) {
            explanation = "Mark all stories older than <b>" + value + " day" + (value==1?'':'s') + " old</b> as read.";
        }
        
        $explanation.html(explanation);
    },
    
    save_mark_read: function() {
        var $save = $('.NB-modal input[type=submit]');
        var $slider = $('.NB-markread-slider', this.$modal);
        var days = $slider.slider('option', 'value');
        
        $save.attr('value', 'Marking as read...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_mark_read(days, function() {
            NEWSBLUR.reader.force_feed_refresh(function() {
                $.modal.close();
            });
        });
    },
            
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-add-url-submit' }, function($t, $p) {
            e.preventDefault();
        });
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    }
    
};