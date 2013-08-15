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
                '浏览器插件 &amp; 移动客户端',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            
            $.make('fieldset', [
                $.make('legend', '书签小工具')
            ]),
            $.make('div', { className: 'NB-goodies-group' }, [
              NEWSBLUR.generate_bookmarklet(),
              $.make('div', { className: 'NB-goodies-title' }, '添加站点和分享文章的书签小工具')
            ]),
            
            $.make('fieldset', [
                $.make('legend', 'NewsZeit 的移动客户端')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: '/ios/'
              }, '查看 iOS App'),
              $.make('div', { className: 'NB-goodies-iphone' }),
              $.make('div', { className: 'NB-goodies-title' }, 'NewsZeit 的官方 iPhone/iPad App')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-mobile-link NB-modal-submit-button NB-modal-submit-green',
                  href: '/android/'
              }, '查看 Android App'),
              $.make('div', { className: 'NB-goodies-android' }),
              $.make('div', { className: 'NB-goodies-title' }, 'NewsZeit 的官方Android App')
            ]),
/*
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
                  href: 'http://projects.developer.nokia.com/feed_reader'
              }, 'View in Nokia Store'),
              $.make('div', { className: 'NB-goodies-nokia' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Web Feeds')
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
                  href: 'http://www.tafitiapp.com/mx/'
              }, 'Download Tafiti for Windows 8'),
              $.make('div', { className: 'NB-goodies-tafiti' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Tafiti')
            ]),
*/
            $.make('fieldset', [
                $.make('legend', 'NewsZeit的浏览器插件')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-firefox-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, '添加到 Firefox'),
              $.make('div', { className: 'NB-goodies-firefox' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Firefox: 将 NewsZeit 注册为一个 RSS 阅读器')
            ]),
/*
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-chrome-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chrome: NewsBlur Chrome Web App')
            ]),*/
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/rss-subscription-extensio/nlbjncdgjeocebhnmkbbbdekmmmcbfjd/details?hl=en'
              }, '添加到 Chrome'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chrome: 将 NewsZeit 注册为一个 RSS 阅读器'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                '使用此插件时，请使用URL: https://www.newszeit.com/?url=%s'
              ])
            ]),
/*
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
                  href: 'https://menakite.eu/~anaconda/safari/NewsBlur-Counter/NewsBlur-Counter.safariextz'
              }, 'Download'),
              $.make('div', { className: 'NB-goodies-safari' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Safari: NewsBlur unread count notifier')
            ]),*/
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-chrome-link NB-modal-submit-button NB-modal-submit-green',
                  href: 'https://chrome.google.com/webstore/detail/cpabkifmcgjibbmglicdajkanagmjdic'
              }, '下载'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Chrome: NewsZeit 未读文章数提示器')
            ]),
            
            $.make('fieldset', [
                $.make('legend', '自定义 URL')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('input', {
                  className: 'NB-goodies-custom-input',
                  value: 'https://www.newszeit.com/?url=站点的 RSS 地址'
              }),
              $.make('div', { className: 'NB-goodies-custom' }),
              $.make('div', { className: 'NB-goodies-title' }, '自定义用于订阅站点的 URL')
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
                                             "NewsZeit");
            navigator.registerContentHandler("application/atom+xml",
                                             host + "?url=%s",
                                             "NewsZeit");
            navigator.registerContentHandler("application/rss+xml",
                                             host + "?url=%s",
                                             "NewsZeit");
        });
/*
        $.targetIs(e, { tagSelector: '.NB-goodies-chrome-link' }, function($t, $p) {
            e.preventDefault();

            window.location.href = 'https://chrome.google.com/webstore/detail/rss-subscription-extensio/bmjffnfcokiodbeiamclanljnaheeoke';
        });
*/
        $.targetIs(e, { tagSelector: '.NB-goodies-custom-input' }, function($t, $p) {
            e.preventDefault();
            $t.select();
        });
    }
    
});
