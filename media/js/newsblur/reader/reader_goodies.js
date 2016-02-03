NEWSBLUR.ReaderGoodies = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderGoodies.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderGoodies.prototype.constructor = NEWSBLUR.ReaderGoodies;

_.extend(NEWSBLUR.ReaderGoodies.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-goodies NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Goodies &amp; Extras',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            
            $.make('fieldset', [
                $.make('legend', 'Bookmarklet')
            ]),
            $.make('div', { className: 'NB-goodies-group' }, [
              NEWSBLUR.generate_bookmarklet(),
              $.make('div', { className: 'NB-goodies-title' }, 'Add Site &amp; Share Story Bookmarklet')
            ]),
            
            $.make('fieldset', [
                $.make('legend', 'Mobile Apps for NewsBlur')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: '/ios/'
              }, 'See the iOS App'),
              $.make('div', { className: 'NB-goodies-ios' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Official NewsBlur iPhone/iPad App')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: '/android/'
              }, 'See the Android App'),
              $.make('div', { className: 'NB-goodies-android' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Official NewsBlur Android App')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://reederapp.com/ios'
              }, 'Download for iPhone and iPad'),
              $.make('div', { className: 'NB-goodies-reeder-ios' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Reeder for iOS')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://supertop.co/unread/'
              }, 'Download for iPhone and iPad'),
              $.make('div', { className: 'NB-goodies-unread-ios' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Unread for iOS')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://addmyfeed.cubesoft.fr'
              }, 'Download for iPhone'),
              $.make('div', { className: 'NB-goodies-ios' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Add My Feed for iOS')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://market.android.com/details?id=bitwrit.Blar'
              }, 'View in Android Market'),
              $.make('div', { className: 'NB-goodies-android' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Blar')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://www.microsoft.com/en-us/store/apps/hypersonic/9nblggh5wnb6'
              }, 'View in Windows Store'),
              $.make('div', { className: 'NB-goodies-windows' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Hypersonic for Windows 10 &amp; Phone')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://windowsphone.com/s?appid=900e67fd-9934-e011-854c-00237de2db9e'
              }, 'View in Windows Phone Store'),
              $.make('div', { className: 'NB-goodies-windows' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Feed Me')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://windowsphone.com/s?appid=2585d348-0894-41b6-8c26-77aeb257f9d8'
              }, 'View in Windows Phone Store'),
              $.make('div', { className: 'NB-goodies-windows' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Metroblur')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://www.windowsphone.com/s?appid=f001b025-94d7-4769-a33d-7dd34778141c'
              }, 'View in Windows Phone Store'),
              $.make('div', { className: 'NB-goodies-windows' }),
              $.make('div', { className: 'NB-goodies-title' }, 'NewsSpot')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://www.windowsphone.com/s?appid=5bef74a6-9ccc-df11-9eae-00237de2db9e'
              }, 'View in Windows Phone Store'),
              $.make('div', { className: 'NB-goodies-windows' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Feed Reader')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://www.windowsphone.com/en-us/store/app/swift-reader/e1e672a1-dd3a-483d-8457-81d3ca4a13ef'
              }, 'View in Windows Phone Store'),
              $.make('div', { className: 'NB-goodies-windows' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Swift Reader')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://projects.developer.nokia.com/feed_reader'
              }, 'View in Nokia Store'),
              $.make('div', { className: 'NB-goodies-nokia' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Web Feeds')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://github.com/jrutila/harbour-newsblur'
              }, 'View in Sailfish OS'),
              $.make('div', { className: 'NB-goodies-sailfish' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Sailblur')
            ]),
            $.make('fieldset', [
                $.make('legend', 'Native Apps for NewsBlur')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://readkitapp.com'
              }, 'Download ReadKit for Mac'),
              $.make('div', { className: 'NB-goodies-readkit' }),
              $.make('div', { className: 'NB-goodies-title' }, 'ReadKit')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://reederapp.com/mac'
              }, 'Download Reeder for Mac'),
              $.make('div', { className: 'NB-goodies-reeder-mac' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Reeder for Mac')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&ved=0CB8QFjAAahUKEwio9f6u_bDHAhXLOIgKHdRdAuY&url=https%3A%2F%2Fitunes.apple.com%2Fus%2Fapp%2Fleaf-rss-news-reader%2Fid576338668%3Fmt%3D12&ei=IUfSVejgIcvxoATUu4mwDg&usg=AFQjCNGAqtn9qxkLqh5LfjPUZ0QFKr1mLg&sig2=yreuovrI2rRrWvzUkB4ydw&bvm=bv.99804247,d.cGU'
              }, 'Download Leaf for Mac'),
              $.make('div', { className: 'NB-goodies-leaf' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Leaf for Mac')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://www.tafitiapp.com/mx/'
              }, 'Download Tafiti for Windows 8'),
              $.make('div', { className: 'NB-goodies-tafiti' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Tafiti')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'http://apps.microsoft.com/windows/en-us/app/bluree/35b1d32a-5abb-479a-8fd1-bbed4fa0172e'
              }, 'Download Bluree for Windows 8'),
              $.make('div', { className: 'NB-goodies-bluree' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Bluree')
            ]),
            $.make('fieldset', [
                $.make('legend', 'Browser Extensions for NewsBlur')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-firefox-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add to Firefox'),
              $.make('div', { className: 'NB-goodies-firefox' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Firefox: Register NewsBlur as an RSS reader')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://addons.mozilla.org/en-US/firefox/addon/newsblurcom-notifier/'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-firefox' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Firefox: NewsBlur Notifier'),
              $.make('div', { className: 'NB-goodies-subtitle' }, 'Shows a button with the number of unread articles.')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('div', { className: 'NB-goodies-firefox' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Firefox: Open links to background tab'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                  $.make('ul', [
                      $.make('li', [
                          'Open a new tab, enter ',
                          $.make('a', { href: 'about:config', target: '_blank' }, 'about:config')
                      ]),
                      $.make('li', [
                          'Search for ',
                          $.make('b', 'browser.tabs.loadDivertedInBackground')
                      ]),
                      $.make('li', 'Double click on \'false\' to set \'Value\' to \'true\''),
                      $.make('li', 'Go to NewsBlur and open a story with \'o\' and see it load in the background')
                  ])
              ])
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/rss-subscription-extensio/nlbjncdgjeocebhnmkbbbdekmmmcbfjd/details?hl=en'
              }, 'Add to Chrome'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chrome: Register NewsBlur as an RSS reader'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                'To use this extension, use the custom add site URL below.'
              ])
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/rss-subscription-extensio/bmjffnfcokiodbeiamclanljnaheeoke'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chrome: NewsBlur Chrome Web App'),
              $.make('div', { className: 'NB-goodies-subtitle'}, 'Adds one-click subscription to your toolbar.')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/nnbhbdncokmmjheldobdfbmfpamelojh'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Chrome: NewsBlur unread count notifier'),
              $.make('div', { className: 'NB-goodies-subtitle' }, 'Shows the unread count from your NewsBlur account.')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/ieeimmkgocgaaabphkgjdkophaejfnlk/'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chrome: Open links in background tab'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                'This extension allows you to open a link in a background tab by pressing a customizable hotkey (default \'o\' or \'v\').  This feature used to work without an extension, but it broke starting with Chrome 41.'
              ])
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/unofficial-newsblur-reade/hnegmjknmfninedmmlhndnjlblopjgad?utm_campaign=en&utm_source=en-ha-na-us-bk-webstr&utm_medium=ha'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chrome: Unofficial browser extension'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                'This extension displays all of your unread stories and unread counts.'
              ])
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: NEWSBLUR.Globals.MEDIA_URL + 'extensions/NewsBlur Safari Helper.app.zip'
              }, 'Add to Safari'),
              $.make('div', { className: 'NB-goodies-safari' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Safari: Register NewsBlur as an RSS reader'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                'To use this extension, extract and move the NewsBlur Safari Helper.app ',
                'to your Applications folder. Then in ',
                $.make('b', 'Safari > Settings > RSS'),
                ' choose the new NewsBlur Safari Helper.app. If you don\'t have an RSS chooser, ',
                'you will have to use ',
                $.make('a', { href: 'http://www.rubicode.com/Software/RCDefaultApp/', className: 'NB-splash-link' }, 'RCDefaultApp'),
                ' to select the NewsBlur Safari Helper as your RSS reader. Then loading an RSS ',
                'feed in Safari will open the feed in NewsBlur. Simple!'
              ])
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-safari-notifier NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://github.com/anaconda/NewsBlur-Counter'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-safari' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Safari: NewsBlur unread count notifier'),
              $.make('div', { className: 'NB-goodies-subtitle' }, 'Safari extension to show on the toolbar how many unread stories are waiting for you on NewsBlur.')
            ]),
            
            $.make('fieldset', [
                $.make('legend', 'Custom URLs')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('input', {
                  className: 'NB-goodies-custom-input',
                  value: 'http://www.newsblur.com/?url=BLOG_URL_GOES_HERE'
              }),
              $.make('div', { className: 'NB-goodies-custom' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Custom Add Site URL')
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