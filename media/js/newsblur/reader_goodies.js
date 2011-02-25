NEWSBLUR.ReaderGoodies = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.runner();
};

NEWSBLUR.ReaderGoodies.prototype = {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-goodies NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Goodies &amp; Extras'),
            $.make('div', { className: 'NB-goodies-group' }, [
              NEWSBLUR.generate_bookmarklet(),
              $.make('div', { className: 'NB-goodies-title' }, 'Add Site Bookmarklet')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-firefox-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add NewsBlur'),
              $.make('div', { className: 'NB-goodies-firefox' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Firefox: Register Newsblur as an RSS reader')
            ])
        ]);
    },
    
    open_modal: function() {
        var self = this;
        
        this.$modal.modal({
            'minWidth': 600,
            'maxWidth': 600,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
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
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-goodies-bookmarklet-button' }, function($t, $p) {
            e.preventDefault();
            
            alert('Drag this button to your bookmark toolbar.');
        });

        $.targetIs(e, { tagSelector: '.NB-goodies-firefox-link' }, function($t, $p) {
            e.preventDefault();

            navigator.registerContentHandler("application/vnd.mozilla.maybe.feed",
                                             document.location +"?url=%s",
                                             "NewsBlur");
        });
    }
    
};