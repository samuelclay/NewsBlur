NEWSBLUR.ReaderNewsletters = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderNewsletters.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderNewsletters.prototype.constructor = NEWSBLUR.ReaderNewsletters;

_.extend(NEWSBLUR.ReaderNewsletters.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-newsletters NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Email Newsletters',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            
            $.make('fieldset', [
                $.make('legend', 'Forwarding email address')
            ]),
            $.make('div', { className: 'NB-newsletters-group' }, [
                $.make('input', { type: 'text', value: 'x@y.com' })
            ]),
            
            $.make('fieldset', [
                $.make('legend', 'Setup instructions')
            ])
        ]);
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
            var host = [
                document.location.protocol,
                '//',
                document.location.host,
                '/'
            ].join('');
            navigator.registerContentHandler("application/vnd.mozilla.maybe.feed",
                                             host + "?url=%s",
                                             "NewsBlur");
            navigator.registerContentHandler("application/atom+xml",
                                             host + "?url=%s",
                                             "NewsBlur");
            navigator.registerContentHandler("application/rss+xml",
                                             host + "?url=%s",
                                             "NewsBlur");
        });

        $.targetIs(e, { tagSelector: '.NB-goodies-custom-input' }, function($t, $p) {
            e.preventDefault();
            $t.select();
        });
    }
    
});