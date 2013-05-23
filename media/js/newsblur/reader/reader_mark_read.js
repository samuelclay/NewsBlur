NEWSBLUR.ReaderMarkRead = function(options) {
    var defaults = {
        days: 1,
        modal_container_class: "NB-full-container"
    };
    
    this.flags = {};
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderMarkRead.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderMarkRead.prototype.constructor = NEWSBLUR.ReaderMarkRead;

_.extend(NEWSBLUR.ReaderMarkRead.prototype, {
    
    runner: function() {
        this.make_modal();
        this.load_slider();
        this.generate_explanation(this.options['days']);
        this.handle_cancel();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        $(document).bind('keydown.mark_read', 'return', _.bind(this.save_mark_read, this));
        $(document).bind('keydown.mark_read', 'ctrl+return', _.bind(this.save_mark_read, this));
        $(document).bind('keydown.mark_read', 'meta+return', _.bind(this.save_mark_read, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-markread NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Mark old stories as read',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('form', { className: 'NB-markread-form' }, [
                $.make('div', { className: 'NB-markread-slider'}),
                $.make('div', { className: 'NB-markread-explanation'}),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', className: 'NB-modal-submit-button NB-modal-submit-green', value: 'Do it' })
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save_mark_read();
                return false;
            })
        ]);
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
        var $button = $('.NB-modal-submit-button', this.$modal);
        var explanation;
        
        if (value == 0) {
            explanation = "Mark every story as read";
        } else if (value >= 1) {
            explanation = "Mark all stories older than " + value + " day" + (value==1?'':'s') + " old as read";
        }
        
        $button.val(explanation);
    },
    
    save_mark_read: function() {
        if (this.flags.saving) return;
        
        var $save = $('.NB-modal input[type=submit]');
        var $slider = $('.NB-markread-slider', this.$modal);
        var days = $slider.slider('option', 'value');
        
        this.flags.saving = true;
        $save.attr('value', 'Marking as read...').addClass('NB-disabled').attr('disabled', true);
        if (NEWSBLUR.Globals.is_authenticated) {
            this.model.save_mark_read(days, _.bind(function() {
                NEWSBLUR.reader.start_count_unreads_after_import();
                $.modal.close();
                NEWSBLUR.reader.force_feeds_refresh(function() {
                    NEWSBLUR.reader.finish_count_unreads_after_import();
                }, true);
                this.flags.saving = false;
            }, this));
        } else {
            this.flags.saving = false;
            $.modal.close();
        }
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
    
});