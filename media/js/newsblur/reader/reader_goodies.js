NEWSBLUR.ReaderGoodies = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
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
              $.make('div', { className: 'NB-goodies-title' }, 'Add Site &amp; Share Story Bookmarklet')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-firefox-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add to Firefox'),
              $.make('div', { className: 'NB-goodies-firefox' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Firefox: Register Newsblur as an RSS reader')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-chrome-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add to Chrome'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chrome: NewsBlur Chrome Web App')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-safari-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add to Safari'),
              $.make('div', { className: 'NB-goodies-safari' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Safari: Register Newsblur as an RSS reader'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                'To use this extension, extract and move the NewsBlur Safari Helper.app ',
                'to your Applications folder. Then in ',
                $.make('b', 'Safari > Settings > RSS'),
                ' choose the new NewsBlur Safari Helper.app. Then clicking on the RSS button in ',
                'Safari will open the feed in NewsBlur. Simple!'
              ])
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('input', {
                  className: 'NB-goodies-custom-input',
                  value: 'http://www.newsblur.com/?url=BLOG_URL_GOES_HERE'
              }),
              $.make('div', { className: 'NB-goodies-custom' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Custom Add Site URL')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-chrome-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/nnbhbdncokmmjheldobdfbmfpamelojh'
              }, 'Chrome Notifier'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Chrome address bar button that shows unread counts')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: '/iphone/'
              }, 'See the iPhone App'),
              $.make('div', { className: 'NB-goodies-iphone' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Official NewsBlur iPhone App')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://market.android.com/details?id=bitwrit.Blar'
              }, 'View in Android Market'),
              $.make('div', { className: 'NB-goodies-android' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Blar: User-Created Android App')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://projects.developer.nokia.com/feed_reader'
              }, 'View in Nokia Store'),
              $.make('div', { className: 'NB-goodies-nokia' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Web Feeds: User-Created MeeGo App')
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
                    setTimeout(function() {
                        $(window).resize();
                    });
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

        $.targetIs(e, { tagSelector: '.NB-goodies-safari-link' }, function($t, $p) {
            e.preventDefault();

            window.location.href = NEWSBLUR.Globals.MEDIA_URL + 'extensions/NewsBlur Safari Helper.app.zip';
        });

        $.targetIs(e, { tagSelector: '.NB-goodies-chrome-link' }, function($t, $p) {
            e.preventDefault();

            window.location.href = 'https://chrome.google.com/webstore/detail/gchdledhagjbhhodjjhiclbnaioljomj';
        });

        $.targetIs(e, { tagSelector: '.NB-goodies-custom-input' }, function($t, $p) {
            e.preventDefault();
            $t.select();
        });
    }
    
};