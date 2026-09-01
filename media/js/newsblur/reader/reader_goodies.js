NEWSBLUR.ReaderGoodies = function (options) {
  var defaults = {
    width: 840
  };

  this.options = $.extend({}, defaults, options);
  this.model = NEWSBLUR.assets;
  this.runner();
};

NEWSBLUR.ReaderGoodies.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderGoodies.prototype.constructor = NEWSBLUR.ReaderGoodies;

_.extend(NEWSBLUR.ReaderGoodies.prototype, {

  runner: function () {
    this.make_modal();
    this.open_modal();

    this.$modal.bind('click', $.rescope(this.handle_click, this));
  },

  // Every entry on this page was link-checked and verified to still advertise
  // NewsBlur support (store listings re-audited August 2026). Keep it that way
  // when adding new apps: verify the listing mentions NewsBlur before listing it.
  make_modal: function () {
    var self = this;

    this.$modal = $.make('div', { className: 'NB-modal-goodies NB-modal' }, [
      $.make('div', { className: 'NB-modal-tabs' }, [
        $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-ios' }, 'iPhone &amp; iPad'),
        $.make('div', { className: 'NB-modal-tab NB-modal-tab-android' }, 'Android'),
        $.make('div', { className: 'NB-modal-tab NB-modal-tab-mac' }, 'Mac'),
        $.make('div', { className: 'NB-modal-tab NB-modal-tab-windows' }, 'Windows &amp; Linux'),
        $.make('div', { className: 'NB-modal-tab NB-modal-tab-browser' }, 'Browser'),
        $.make('div', { className: 'NB-modal-tab NB-modal-tab-extras' }, 'Extras')
      ]),
      $.make('h2', { className: 'NB-modal-title' }, [
        $.make('div', { className: 'NB-icon' }),
        'Goodies &amp; Extras',
        $.make('div', { className: 'NB-icon-dropdown' })
      ]),
      this.make_ios_tab(),
      this.make_android_tab(),
      this.make_mac_tab(),
      this.make_windows_tab(),
      this.make_browser_tab(),
      this.make_extras_tab()
    ]);
  },

  goodies_image: function (filename) {
    return NEWSBLUR.Globals.MEDIA_URL + 'img/goodies/' + filename;
  },

  // Official app spotlight: big icon, blurb, and a strip of store screenshots.
  make_hero: function (options) {
    var self = this;
    return $.make('div', { className: 'NB-goodies-hero' }, [
      $.make('div', { className: 'NB-goodies-hero-header' }, [
        $.make('img', { className: 'NB-goodies-hero-icon', src: this.goodies_image(options.key + '-icon.png') }),
        $.make('div', { className: 'NB-goodies-hero-info' }, [
          $.make('div', { className: 'NB-goodies-hero-name' }, options.name),
          $.make('div', { className: 'NB-goodies-hero-meta' }, options.meta)
        ]),
        $.make('a', {
          className: 'NB-goodies-app-button NB-modal-submit-button NB-modal-submit-green',
          href: options.url,
          target: '_blank'
        }, options.button)
      ]),
      $.make('div', { className: 'NB-goodies-hero-shots' }, _.map(options.shots, function (shot) {
        return $.make('img', { src: self.goodies_image(shot) });
      }))
    ]);
  },

  // Third-party app card: header row of icon, name, and store button, with a
  // strip of screenshot thumbnails below. Cards flow two-up in NB-goodies-apps.
  make_app_row: function (options) {
    var self = this;
    return $.make('div', { className: 'NB-goodies-app' }, [
      $.make('div', { className: 'NB-goodies-app-header' }, [
        options.icon !== false && $.make('img', {
          className: 'NB-goodies-app-icon',
          src: this.goodies_image((options.icon || options.key) + '-icon.png')
        }),
        $.make('div', { className: 'NB-goodies-app-info' }, [
          $.make('div', { className: 'NB-goodies-app-name' }, options.name),
          $.make('div', { className: 'NB-goodies-app-meta' }, options.meta)
        ]),
        $.make('a', {
          className: 'NB-goodies-app-button NB-modal-submit-button NB-modal-submit-green',
          href: options.url,
          target: '_blank'
        }, options.button || 'App Store')
      ]),
      options.thumbs && $.make('div', { className: 'NB-goodies-app-thumbs' }, _.map(options.thumbs, function (thumb) {
        return $.make('img', { src: self.goodies_image(thumb) });
      }))
    ]);
  },

  // Two-column grid of app cards; pass full: true for a single full-width column.
  make_app_grid: function (rows, options) {
    options = options || {};
    return $.make('div', {
      className: 'NB-goodies-apps' + (options.full ? ' NB-goodies-apps-full' : '')
    }, rows);
  },

  make_section_title: function (title) {
    return $.make('div', { className: 'NB-goodies-section-title' }, title);
  },

  make_ios_tab: function () {
    return $.make('div', { className: 'NB-tab NB-tab-ios NB-active' }, [
      this.make_hero({
        key: 'newsblur-ios',
        name: 'Official NewsBlur iPhone/iPad App',
        meta: 'Free · Made by NewsBlur',
        url: 'https://apps.apple.com/us/app/newsblur/id463981119',
        button: 'App Store',
        shots: ['newsblur-ios-1.jpg', 'newsblur-ios-2.jpg', 'newsblur-ios-3.jpg', 'newsblur-ios-4.jpg']
      }),
      this.make_section_title('Third-party apps that sync with NewsBlur'),
      this.make_app_grid([
        this.make_app_row({
          key: 'reeder-classic',
        name: 'Reeder Classic',
        meta: '$4.99 · iPhone &amp; iPad',
        url: 'https://apps.apple.com/us/app/reeder-classic/id1529445840',
        thumbs: ['reeder-classic-1.jpg', 'reeder-classic-2.jpg']
        }),
        this.make_app_row({
        key: 'unread',
        name: 'Unread',
        meta: 'Free + subscription · iPhone, iPad &amp; Mac',
        url: 'https://www.goldenhillsoftware.com/unread/',
        button: 'Download',
        thumbs: ['unread-1.jpg', 'unread-2.jpg']
        }),
        this.make_app_row({
        key: 'netnewswire',
        name: 'NetNewsWire',
        meta: 'Free, open source · iPhone, iPad &amp; Mac',
        url: 'https://apps.apple.com/us/app/netnewswire-rss-reader/id1480640210',
        thumbs: ['netnewswire-2.jpg', 'netnewswire-3.jpg']
        }),
        this.make_app_row({
        key: 'readkit',
        name: 'ReadKit',
        meta: 'Free + subscription · iPhone, iPad &amp; Mac',
        url: 'https://readkit.app/',
        button: 'Download',
        thumbs: ['readkit-1.jpg']
        }),
        this.make_app_row({
        key: 'lire',
        name: 'lire',
        meta: '$9.99 · iPhone &amp; iPad',
        url: 'https://apps.apple.com/us/app/lire-rss-reader/id1531976425',
        thumbs: ['lire-1.jpg', 'lire-2.jpg']
        }),
        this.make_app_row({
        key: 'fiery-feeds',
        name: 'Fiery Feeds',
        meta: 'Free + subscription · iPhone, iPad &amp; Mac',
        url: 'https://apps.apple.com/us/app/fiery-feeds-news-reader/id1158763303',
        thumbs: ['fiery-feeds-1.jpg', 'fiery-feeds-2.jpg']
        }),
        this.make_app_row({
        key: 'slow-feeds',
        name: 'Slow Feeds',
        meta: 'Free · iPhone, iPad &amp; Mac',
        url: 'https://apps.apple.com/us/app/slow-feeds/id1366946855',
        thumbs: ['slow-feeds-1.jpg', 'slow-feeds-2.jpg']
        }),
        this.make_app_row({
        key: 'powereader',
        name: 'PoweReader',
        meta: 'Free · iPhone, iPad &amp; Mac',
        url: 'https://apps.apple.com/us/app/powereader-ai-rss-reader/id6479644903',
        thumbs: ['powereader-1.jpg', 'powereader-2.jpg']
        }),
        this.make_app_row({
        key: 'current',
        name: 'Current',
        meta: '$9.99 · iPhone, iPad &amp; Mac',
        url: 'https://apps.apple.com/us/app/current-rss-feed-reader/id6758530974',
        thumbs: ['current-1.jpg', 'current-2.jpg']
        }),
        this.make_app_row({
        key: 'feedler',
        name: 'Feedler',
        meta: 'Free beta · iPhone, iPad &amp; Mac',
        url: 'https://feedlerapp.com/',
        button: 'TestFlight',
        thumbs: ['feedler-1.jpg', 'feedler-2.jpg']
        }),
        this.make_app_row({
        key: 'feedit',
        name: 'Feedit',
        meta: 'Free · iPhone &amp; iPad',
        url: 'https://apps.apple.com/us/app/feedit/id6444137580',
        thumbs: ['feedit-1.jpg', 'feedit-2.jpg']
        }),
        this.make_app_row({
        key: 'watch-feeds',
        name: 'Watch Feeds',
        meta: 'Free · Apple Watch, iPhone &amp; iPad',
        url: 'https://apps.apple.com/us/app/watch-feeds/id1480741074',
        thumbs: ['watch-feeds-1.jpg', 'watch-feeds-2.jpg']
        }),
        this.make_app_row({
        key: 'smartrss',
        name: 'SmartRSS',
        meta: 'Free · iPhone, iPad, Mac &amp; Android',
        url: 'https://apps.apple.com/us/app/smartrss-rss-reader-podcast/id6749771900',
        thumbs: ['smartrss-1.jpg', 'smartrss-2.jpg']
        }),
        this.make_app_row({
        key: 'web-subscriber',
        name: 'Web Subscriber',
        meta: 'Free · iPhone &amp; iPad',
        url: 'https://apps.apple.com/us/app/web-subscriber/id511900080',
        thumbs: ['web-subscriber-1.jpg', 'web-subscriber-2.jpg']
        })
      ])
    ]);
  },

  make_android_tab: function () {
    return $.make('div', { className: 'NB-tab NB-tab-android' }, [
      this.make_hero({
        key: 'newsblur-android',
        name: 'Official NewsBlur Android App',
        meta: 'Free · Made by NewsBlur',
        url: 'https://play.google.com/store/apps/details?id=com.newsblur',
        button: 'Google Play',
        shots: ['newsblur-android-1.jpg', 'newsblur-android-2.jpg', 'newsblur-android-3.jpg', 'newsblur-android-4.jpg']
      }),
      this.make_section_title('Third-party apps that sync with NewsBlur'),
      this.make_app_grid([
        this.make_app_row({
          key: 'smartrss',
          name: 'SmartRSS',
          meta: 'Free · Android, iPhone, iPad &amp; Mac',
          url: 'https://play.google.com/store/apps/details?id=com.vinsonguo.flutter_rss_reader',
          button: 'Google Play',
          thumbs: ['smartrss-1.jpg', 'smartrss-2.jpg']
        })
      ])
    ]);
  },

  make_mac_tab: function () {
    return $.make('div', { className: 'NB-tab NB-tab-mac' }, [
      this.make_hero({
        key: 'newsblur-macos',
        name: 'Official NewsBlur macOS App',
        meta: 'Free · Made by NewsBlur',
        url: 'https://apps.apple.com/us/app/newsblur/id463981119?platform=mac',
        button: 'Mac App Store',
        shots: ['newsblur-macos-1.jpg', 'newsblur-macos-2.jpg']
      }),
      this.make_section_title('Third-party apps that sync with NewsBlur'),
      this.make_app_grid([
        this.make_app_row({
          key: 'netnewswire',
          name: 'NetNewsWire',
          meta: 'Free, open source · Mac, iPhone &amp; iPad',
        url: 'https://netnewswire.com/',
        button: 'Download',
        thumbs: ['netnewswire-1.jpg']
        }),
        this.make_app_row({
        key: 'readkit',
        name: 'ReadKit',
        meta: 'Free + subscription · Mac, iPhone &amp; iPad',
        url: 'https://readkit.app/',
        button: 'Download',
        thumbs: ['readkit-1.jpg']
        }),
        this.make_app_row({
        key: 'reeder-classic',
        icon: 'reeder-classic-mac',
        name: 'Reeder Classic',
        meta: '$9.99 · Mac',
        url: 'https://apps.apple.com/us/app/reeder-classic/id1529448980',
        thumbs: ['reeder-classic-3.jpg']
        }),
        this.make_app_row({
        key: 'unread',
        name: 'Unread',
        meta: 'Free + subscription · Mac, iPhone &amp; iPad',
        url: 'https://www.goldenhillsoftware.com/unread/',
        button: 'Download',
        thumbs: ['unread-1.jpg', 'unread-2.jpg']
        }),
        this.make_app_row({
        key: 'lire',
        name: 'lire',
        meta: '$9.99 · Mac',
        url: 'https://apps.apple.com/us/app/lire-rss-reader/id1482527526',
        thumbs: ['lire-1.jpg', 'lire-2.jpg']
        }),
        this.make_app_row({
        key: 'fiery-feeds',
        name: 'Fiery Feeds',
        meta: 'Free + subscription · Mac, iPhone &amp; iPad',
        url: 'https://apps.apple.com/us/app/fiery-feeds-news-reader/id1158763303',
        thumbs: ['fiery-feeds-1.jpg', 'fiery-feeds-2.jpg']
        }),
        this.make_app_row({
        key: 'feedler',
        name: 'Feedler',
        meta: 'Free beta · Mac, iPhone &amp; iPad',
        url: 'https://feedlerapp.com/',
        button: 'TestFlight',
        thumbs: ['feedler-1.jpg', 'feedler-2.jpg']
        }),
        this.make_app_row({
        key: 'newsflow',
        name: 'Newsflow',
        meta: '$4.99 · Menu bar news ticker for Mac',
        url: 'https://apps.apple.com/us/app/newsflow-the-no-1-news-ticker/id890805912',
        thumbs: ['newsflow-1.jpg']
        }),
        this.make_app_row({
        key: 'leaf',
        name: 'Leaf',
        meta: '$9.99 · Mac',
        url: 'https://apps.apple.com/us/app/leaf-rss-news-reader/id576338668',
        thumbs: ['leaf-1.jpg']
        })
      ])
    ]);
  },

  make_windows_tab: function () {
    return $.make('div', { className: 'NB-tab NB-tab-windows' }, [
      this.make_section_title('Windows'),
      this.make_app_grid([
        this.make_app_row({
          key: 'rsstracker',
          name: 'RSS Tracker',
          meta: 'Free · Windows 10 &amp; 11',
          url: 'https://apps.microsoft.com/detail/9n85pv1rjd6v',
          button: 'Microsoft Store',
          thumbs: ['rsstracker-1.jpg', 'rsstracker-3.jpg']
        })
      ], { full: true }),
      this.make_section_title('Linux'),
      this.make_app_grid([
        this.make_app_row({
          key: 'newsflash',
          name: 'Newsflash',
          meta: 'Free, open source · GNOME/Flathub',
          url: 'https://flathub.org/apps/io.gitlab.news_flash.NewsFlash',
          button: 'Flathub',
          thumbs: ['newsflash-1.jpg']
        }),
        this.make_app_row({
          key: 'newsboat',
          name: 'Newsboat',
          meta: 'Free, open source · Terminal (Linux, macOS, BSD)',
          url: 'https://newsboat.org/',
          button: 'Download',
          thumbs: ['newsboat-1.jpg']
        })
      ]),
      this.make_section_title('Even geekier'),
      this.make_app_grid([
        this.make_app_row({
          key: 'koreader',
          icon: false,
          name: 'KOReader RSS plugin',
          meta: 'Free, open source · E-ink devices (Kobo, Kindle, PocketBook)',
          url: 'https://github.com/omer-faruq/rssreader.koplugin',
          button: 'GitHub'
        }),
        this.make_app_row({
          key: 'elfeed-protocol',
          icon: false,
          name: 'elfeed-protocol',
          meta: 'Free, open source · Emacs',
          url: 'https://github.com/fasheng/elfeed-protocol',
          button: 'GitHub'
        })
      ])
    ]);
  },

  make_browser_tab: function () {
    return $.make('div', { className: 'NB-tab NB-tab-browser' }, [
      this.make_section_title('Firefox'),
      this.make_app_grid([
        this.make_app_row({
          key: 'firefox-notifier',
          name: 'NewsBlur Notifier',
          meta: 'Shows a toolbar button with your unread count',
          url: 'https://addons.mozilla.org/en-US/firefox/addon/newsblurcom-notifier/',
          button: 'Add to Firefox'
        }),
        $.make('div', { className: 'NB-goodies-tip' }, [
          $.make('div', { className: 'NB-goodies-app-name' }, 'Open links in a background tab'),
          $.make('div', { className: 'NB-goodies-app-meta' }, [
            'In a new tab, open ',
            $.make('b', 'about:config'),
            ', search for ',
            $.make('b', 'browser.tabs.loadDivertedInBackground'),
            ', and set it to ',
            $.make('b', 'true'),
            '. Stories opened with \'o\' will then load in the background.'
          ])
        ])
      ]),
      this.make_section_title('Chrome'),
      this.make_app_grid([
        this.make_app_row({
          key: 'chrome-rss-sub',
          name: 'RSS Subscription Extension',
          meta: 'One-click subscribe on any site with a feed. Use the custom add site URL from the Extras tab.',
          url: 'https://chromewebstore.google.com/detail/rss-subscription-extensio/nlbjncdgjeocebhnmkbbbdekmmmcbfjd',
          button: 'Add to Chrome'
        }),
        this.make_app_row({
          key: 'chrome-bg-tab',
          name: 'Background Tab for NewsBlur',
          meta: 'Opens stories in a background tab with a customizable hotkey',
          url: 'https://chromewebstore.google.com/detail/background-tab-for-newsbl/ieeimmkgocgaaabphkgjdkophaejfnlk',
          button: 'Add to Chrome'
        })
      ]),
      this.make_section_title('Safari'),
      this.make_app_grid([
        this.make_app_row({
          key: 'safari-helper',
          icon: false,
          name: 'NewsBlur Helper',
          meta: 'Safari App Extension that lets \'o\' open stories in a background tab. Download the app from the Releases appcast in the repo.',
          url: 'https://github.com/nriley/NewsBlur-Helper',
          button: 'GitHub'
        })
      ])
    ]);
  },

  make_extras_tab: function () {
    return $.make('div', { className: 'NB-tab NB-tab-extras' }, [
      this.make_section_title('Bookmarklet'),
      this.make_app_grid([
        $.make('div', { className: 'NB-goodies-app' }, [
          $.make('div', { className: 'NB-goodies-app-header' }, [
            $.make('div', { className: 'NB-goodies-app-info' }, [
              $.make('div', { className: 'NB-goodies-app-name' }, 'Add Site &amp; Share Story Bookmarklet'),
              $.make('div', { className: 'NB-goodies-app-meta' }, 'Drag the button to your bookmark toolbar. On any site, it subscribes to the feed or shares the story you\'re reading.')
            ]),
            NEWSBLUR.generate_bookmarklet()
          ])
        ])
      ], { full: true }),
      this.make_section_title('Custom URLs'),
      this.make_app_grid([
        $.make('div', { className: 'NB-goodies-app' }, [
          $.make('div', { className: 'NB-goodies-app-header' }, [
            $.make('div', { className: 'NB-goodies-app-info' }, [
              $.make('div', { className: 'NB-goodies-app-name' }, 'Custom Add Site URL'),
              $.make('div', { className: 'NB-goodies-app-meta' }, 'Use this URL template in browser extensions and feed readers to subscribe on NewsBlur.')
            ]),
            $.make('input', {
              className: 'NB-goodies-custom-input',
              value: 'https://www.newsblur.com/?url=BLOG_URL_GOES_HERE'
            })
          ])
        ])
      ], { full: true })
    ]);
  },

  switch_tab: function (newtab) {
    var $modal_tabs = $('.NB-modal-tab', this.$modal);
    var $tabs = $('.NB-tab', this.$modal);

    $modal_tabs.removeClass('NB-active');
    $tabs.removeClass('NB-active');

    $modal_tabs.filter('.NB-modal-tab-' + newtab).addClass('NB-active');
    $tabs.filter('.NB-tab-' + newtab).addClass('NB-active');

    this.resize();
  },

  // ===========
  // = Actions =
  // ===========

  handle_click: function (elem, e) {
    var self = this;

    $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function ($t, $p) {
      e.preventDefault();
      var newtab;
      if ($t.hasClass('NB-modal-tab-ios')) {
        newtab = 'ios';
      } else if ($t.hasClass('NB-modal-tab-android')) {
        newtab = 'android';
      } else if ($t.hasClass('NB-modal-tab-mac')) {
        newtab = 'mac';
      } else if ($t.hasClass('NB-modal-tab-windows')) {
        newtab = 'windows';
      } else if ($t.hasClass('NB-modal-tab-browser')) {
        newtab = 'browser';
      } else if ($t.hasClass('NB-modal-tab-extras')) {
        newtab = 'extras';
      }
      self.switch_tab(newtab);
    });

    $.targetIs(e, { tagSelector: '.NB-goodies-bookmarklet-button' }, function ($t, $p) {
      e.preventDefault();

      alert('Drag this button to your bookmark toolbar.');
    });

    $.targetIs(e, { tagSelector: '.NB-goodies-custom-input' }, function ($t, $p) {
      e.preventDefault();
      $t.select();
    });
  }

});
