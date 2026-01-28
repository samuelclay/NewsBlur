NEWSBLUR.Views.AddSiteView = Backbone.View.extend({

    className: "NB-add-site-view",

    events: {
        "click .NB-add-site-tab": "switch_tab",
        "click .NB-add-site-view-toggle": "toggle_view_mode",
        "input .NB-add-site-search-input": "handle_search_input",
        "keypress .NB-add-site-search-input": "handle_search_keypress",
        "click .NB-add-site-search-clear": "clear_search",
        "click .NB-add-site-subscribe-btn": "subscribe_to_feed",
        "click .NB-add-site-open-btn": "open_subscribed_feed",
        "change .NB-add-site-folder-select": "handle_folder_change",
        // YouTube tab events
        "click .NB-add-site-youtube-tab .NB-add-site-tab-search-btn": "perform_youtube_search",
        "keypress .NB-add-site-youtube-search": "handle_youtube_search_keypress",
        // Reddit tab events
        "click .NB-add-site-reddit-tab .NB-add-site-tab-search-btn": "perform_reddit_search",
        "keypress .NB-add-site-reddit-search": "handle_reddit_search_keypress",
        // Newsletter tab events
        "click .NB-add-site-newsletters-tab .NB-add-site-tab-search-btn": "perform_newsletter_convert",
        "keypress .NB-add-site-newsletters-search": "handle_newsletter_search_keypress",
        // Podcast tab events
        "click .NB-add-site-podcasts-tab .NB-add-site-tab-search-btn": "perform_podcast_search",
        "keypress .NB-add-site-podcasts-search": "handle_podcast_search_keypress",
        // Google News events
        "click .NB-add-site-google-news-topic": "handle_google_news_topic_click",
        "click .NB-add-site-google-news-subscribe-btn": "handle_google_news_subscribe",
        "input .NB-add-site-google-news-search-input": "handle_google_news_input",
        "keypress .NB-add-site-google-news-search-input": "handle_google_news_search_keypress",
        // Trending tab events
        "change .NB-add-site-trending-days": "handle_trending_days_change",
        // Categories tab events
        "click .NB-add-site-category-card": "handle_category_click",
        "click .NB-add-site-category-back": "go_back_to_categories",
        // Discovery navigation events
        "click .NB-add-site-source-pill": "handle_source_pill_click",
        "click .NB-add-site-section-link": "handle_section_link_click",
        // Filter pill events
        "click .NB-add-site-filter-pill": "handle_filter_pill_click",
        // Category pill events (from search tab)
        "click .NB-add-site-category-pill": "handle_category_pill_click"
    },

    TABS: [
        { id: 'search', label: 'Search', icon: '/media/img/icons/nouns/search.svg' },
        { id: 'youtube', label: 'YouTube', icon: '/media/img/reader/youtube_play.png' },
        { id: 'reddit', label: 'Reddit', icon: '/media/img/reader/reddit.png' },
        { id: 'newsletters', label: 'Newsletters', icon: '/media/img/reader/newsletters_folder.png' },
        { id: 'podcasts', label: 'Podcasts', icon: '/media/img/icons/nouns/activity.svg' },
        { id: 'google-news', label: 'Google News', icon: '/media/img/icons/nouns/world.svg' }
    ],

    GOOGLE_NEWS_TOPICS: [
        { id: 'WORLD', name: 'World', icon: '\ud83c\udf0d' },
        { id: 'NATION', name: 'Nation', icon: '\ud83c\udfdb\ufe0f' },
        { id: 'BUSINESS', name: 'Business', icon: '\ud83d\udcbc' },
        { id: 'TECHNOLOGY', name: 'Technology', icon: '\ud83d\udcbb' },
        { id: 'ENTERTAINMENT', name: 'Entertainment', icon: '\ud83c\udfac' },
        { id: 'SPORTS', name: 'Sports', icon: '\u26bd' },
        { id: 'SCIENCE', name: 'Science', icon: '\ud83d\udd2c' },
        { id: 'HEALTH', name: 'Health', icon: '\ud83c\udfe5' }
    ],

    NEWSLETTER_PLATFORMS: {
        'substack': 'Substack',
        'medium': 'Medium',
        'ghost': 'Ghost',
        'buttondown': 'Buttondown',
        'beehiiv': 'Beehiiv',
        'convertkit': 'ConvertKit',
        'revue': 'Revue',
        'generic': 'Newsletter',
        'direct': 'RSS Feed'
    },

    YOUTUBE_CATEGORIES: [
        { id: 'all', name: 'All' },
        { id: 'tech', name: 'Tech' },
        { id: 'science', name: 'Science' },
        { id: 'gaming', name: 'Gaming' },
        { id: 'education', name: 'Education' },
        { id: 'news', name: 'News' },
        { id: 'entertainment', name: 'Entertainment' },
        { id: 'music', name: 'Music' }
    ],

    PODCAST_CATEGORIES: [
        { id: 'all', name: 'All' },
        { id: 'news', name: 'News' },
        { id: 'tech', name: 'Tech' },
        { id: 'comedy', name: 'Comedy' },
        { id: 'truecrime', name: 'True Crime' },
        { id: 'business', name: 'Business' },
        { id: 'education', name: 'Education' },
        { id: 'science', name: 'Science' }
    ],

    POPULAR_PODCASTS: [
        { name: 'The Daily', artist: 'The New York Times', genre: 'News', category: 'news', feed_url: 'https://feeds.simplecast.com/54nAGcIl', artwork: 'https://image.simplecastcdn.com/images/bdb43d4d-bd1c-4064-9531-5391a6e6e5e1/1d1dbe3d-4e99-4200-97ae-39d8f6b7f6d4/3000x3000/uploads_2f1615832653772-qxxi1vxge2o-3c8e6c2fe685b30fc38696d0e71dc11a_2fthe-daily-album-art-original.jpg' },
        { name: 'Serial', artist: 'Serial Productions', genre: 'True Crime', category: 'truecrime', feed_url: 'https://feeds.simplecast.com/xl36XBC2' },
        { name: 'This American Life', artist: 'Chicago Public Media', genre: 'Society', category: 'news', feed_url: 'https://www.thisamericanlife.org/podcast/rss.xml' },
        { name: 'Radiolab', artist: 'WNYC Studios', genre: 'Science', category: 'science', feed_url: 'https://feeds.simplecast.com/EmVW7VGp' },
        { name: 'Planet Money', artist: 'NPR', genre: 'Business', category: 'business', feed_url: 'https://feeds.npr.org/510289/podcast.xml' },
        { name: 'How I Built This', artist: 'NPR', genre: 'Business', category: 'business', feed_url: 'https://feeds.npr.org/510313/podcast.xml' },
        { name: 'Freakonomics Radio', artist: 'Freakonomics', genre: 'Business', category: 'business', feed_url: 'https://feeds.simplecast.com/Y8lFbOT4' },
        { name: 'Acquired', artist: 'Ben Gilbert and David Rosenthal', genre: 'Technology', category: 'tech', feed_url: 'https://feeds.simplecast.com/JBiZ0WnY' },
        { name: 'Lex Fridman Podcast', artist: 'Lex Fridman', genre: 'Technology', category: 'tech', feed_url: 'https://lexfridman.com/feed/podcast/' },
        { name: 'All-In Podcast', artist: 'Jason Calacanis', genre: 'Technology', category: 'tech', feed_url: 'https://feeds.simplecast.com/4MVDEgRM' },
        { name: 'The Vergecast', artist: 'The Verge', genre: 'Technology', category: 'tech', feed_url: 'https://feeds.megaphone.fm/vergecast' },
        { name: 'Conan O\'Brien Needs a Friend', artist: 'Team Coco', genre: 'Comedy', category: 'comedy', feed_url: 'https://feeds.simplecast.com/dHoohVNH' },
        { name: 'SmartLess', artist: 'Jason Bateman, Sean Hayes, Will Arnett', genre: 'Comedy', category: 'comedy', feed_url: 'https://feeds.simplecast.com/xs0YcAjq' },
        { name: 'Stuff You Should Know', artist: 'iHeartPodcasts', genre: 'Education', category: 'education', feed_url: 'https://feeds.megaphone.fm/stuffyoushouldknow' },
        { name: 'Hidden Brain', artist: 'NPR', genre: 'Science', category: 'science', feed_url: 'https://feeds.npr.org/510308/podcast.xml' },
        { name: 'Crime Junkie', artist: 'audiochuck', genre: 'True Crime', category: 'truecrime', feed_url: 'https://feeds.simplecast.com/qm_9xx0g' },
        { name: 'My Favorite Murder', artist: 'Exactly Right', genre: 'True Crime', category: 'truecrime', feed_url: 'https://feeds.simplecast.com/GLTi1Mcb' },
        { name: 'TED Radio Hour', artist: 'NPR', genre: 'Education', category: 'education', feed_url: 'https://feeds.npr.org/510298/podcast.xml' },
        { name: 'The Joe Rogan Experience', artist: 'Joe Rogan', genre: 'Society', category: 'comedy', feed_url: 'https://feeds.megaphone.fm/GLT1412515089' },
        { name: 'Hardcore History', artist: 'Dan Carlin', genre: 'History', category: 'education', feed_url: 'https://feeds.feedburner.com/dancarlin/history' }
    ],

    POPULAR_NEWSLETTERS: [
        // Substack
        { title: 'The Hustle', platform: 'substack', url: 'thehustle.co', description: 'Business and tech news', feed_url: 'https://thehustle.co/feed/', subscribers: '2.5M' },
        { title: 'Lenny\'s Newsletter', platform: 'substack', url: 'lennysnewsletter.com', description: 'Product management and growth', feed_url: 'https://www.lennysnewsletter.com/feed', subscribers: '500K' },
        { title: 'Stratechery', platform: 'substack', url: 'stratechery.com', description: 'Technology strategy analysis', feed_url: 'https://stratechery.com/feed/', subscribers: '100K' },
        { title: 'The Pragmatic Engineer', platform: 'substack', url: 'pragmaticengineer.com', description: 'Software engineering insights', feed_url: 'https://newsletter.pragmaticengineer.com/feed', subscribers: '400K' },
        { title: 'Platformer', platform: 'substack', url: 'platformer.news', description: 'Tech and democracy', feed_url: 'https://www.platformer.news/feed', subscribers: '200K' },
        { title: 'Money Stuff', platform: 'substack', url: 'bloomberg.com/opinion/authors/ARbTQlRLRjE/matthew-s-levine', description: 'Finance explained by Matt Levine', feed_url: 'https://www.bloomberg.com/opinion/authors/ARbTQlRLRjE/matthew-s-levine.rss', subscribers: '150K' },
        // Medium
        { title: 'Towards Data Science', platform: 'medium', url: 'towardsdatascience.com', description: 'Data science and ML articles', feed_url: 'https://towardsdatascience.com/feed', subscribers: '700K' },
        { title: 'Better Programming', platform: 'medium', url: 'betterprogramming.pub', description: 'Programming tutorials and tips', feed_url: 'https://betterprogramming.pub/feed', subscribers: '500K' },
        { title: 'OneZero', platform: 'medium', url: 'onezero.medium.com', description: 'Tech and science stories', feed_url: 'https://onezero.medium.com/feed', subscribers: '200K' },
        // Ghost
        { title: 'CSS-Tricks', platform: 'ghost', url: 'css-tricks.com', description: 'Web development tips and tricks', feed_url: 'https://css-tricks.com/feed/', subscribers: '350K' },
        { title: 'Smashing Magazine', platform: 'ghost', url: 'smashingmagazine.com', description: 'Web design and development', feed_url: 'https://www.smashingmagazine.com/feed/', subscribers: '400K' },
        // Other
        { title: 'Morning Brew', platform: 'generic', url: 'morningbrew.com', description: 'Daily business news digest', feed_url: 'https://www.morningbrew.com/daily/rss', subscribers: '4M' },
        { title: 'The Verge', platform: 'direct', url: 'theverge.com', description: 'Technology news and reviews', feed_url: 'https://www.theverge.com/rss/index.xml', subscribers: '3M' },
        { title: 'Ars Technica', platform: 'direct', url: 'arstechnica.com', description: 'Tech news and analysis', feed_url: 'https://feeds.arstechnica.com/arstechnica/index', subscribers: '1M' },
        { title: 'Hacker News', platform: 'direct', url: 'news.ycombinator.com', description: 'Tech and startup news', feed_url: 'https://news.ycombinator.com/rss', subscribers: '500K' }
    ],

    REDDIT_CATEGORIES: [
        { id: 'all', name: 'All' },
        { id: 'news', name: 'News' },
        { id: 'tech', name: 'Tech' },
        { id: 'gaming', name: 'Gaming' },
        { id: 'entertainment', name: 'Entertainment' },
        { id: 'sports', name: 'Sports' },
        { id: 'science', name: 'Science' },
        { id: 'funny', name: 'Funny' }
    ],

    POPULAR_YOUTUBE_CHANNELS: [
        { id: 'UCBcRF18a7Qf58cCRy5xuWwQ', title: 'MKBHD', description: 'Quality tech videos', subscriber_count: '19M', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCBcRF18a7Qf58cCRy5xuWwQ' },
        { id: 'UCXuqSBlHAE6Xw-yeJA0Tunw', title: 'Linus Tech Tips', description: 'Tech tips, reviews, and more', subscriber_count: '16M', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCXuqSBlHAE6Xw-yeJA0Tunw' },
        { id: 'UC6nSFpj9HTCZ5t-N3Rm3-HA', title: 'Vsauce', description: 'Mind-bending science and curiosities', subscriber_count: '20M', category: 'science', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC6nSFpj9HTCZ5t-N3Rm3-HA' },
        { id: 'UCsXVk37bltHxD1rDPwtNM8Q', title: 'Kurzgesagt', description: 'Science and philosophy animations', subscriber_count: '22M', category: 'science', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCsXVk37bltHxD1rDPwtNM8Q' },
        { id: 'UCHnyfMqiRRG1u-2MsSQLbXA', title: 'Veritasium', description: 'Science and engineering videos', subscriber_count: '15M', category: 'science', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCHnyfMqiRRG1u-2MsSQLbXA' },
        { id: 'UCWX3bGDLdJ8y_E7n2ghDbTQ', title: 'Tom Scott', description: 'Amazing places and interesting things', subscriber_count: '6M', category: 'education', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCWX3bGDLdJ8y_E7n2ghDbTQ' },
        { id: 'UC9-y-6csu5WGm29I7JiwpnA', title: 'Computerphile', description: 'Computer science topics', subscriber_count: '2.5M', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC9-y-6csu5WGm29I7JiwpnA' },
        { id: 'UCy0tKL1T7wFoYcxCe0xjN6Q', title: 'Technology Connections', description: 'How everyday technology works', subscriber_count: '2M', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCy0tKL1T7wFoYcxCe0xjN6Q' },
        { id: 'UCVHFbqXqoYvEWM1Ddxl0QKg', title: 'Bloomberg Technology', description: 'Technology news and analysis', subscriber_count: '1M', category: 'news', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCVHFbqXqoYvEWM1Ddxl0QKg' },
        { id: 'UCeY0bbntWzzVIaj2z3QigXg', title: 'NBC News', description: 'Breaking news and top stories', subscriber_count: '6M', category: 'news', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCeY0bbntWzzVIaj2z3QigXg' },
        { id: 'UCupvZG-5ko_eiXAupbDfxWw', title: 'CNN', description: 'News, original shows and video', subscriber_count: '15M', category: 'news', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCupvZG-5ko_eiXAupbDfxWw' },
        { id: 'UCYfdidRxbB8Qhf0Nx7ioOYw', title: 'The Verge', description: 'Technology, science, art, and culture', subscriber_count: '3M', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCYfdidRxbB8Qhf0Nx7ioOYw' },
        { id: 'UCddiUEpeqJcYeBxX1IVBKvQ', title: 'Wired', description: 'Future trends and tech culture', subscriber_count: '14M', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCddiUEpeqJcYeBxX1IVBKvQ' },
        { id: 'UCBJycsmduvYEL83R_U4JriQ', title: 'Marques Brownlee', description: 'Tech reviews and podcasts', subscriber_count: '3M', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCBJycsmduvYEL83R_U4JriQ' },
        { id: 'UCVls1GmFKf6WlTraIb_IaJg', title: 'DistroTube', description: 'Linux and open source software', subscriber_count: '300K', category: 'tech', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCVls1GmFKf6WlTraIb_IaJg' },
        { id: 'UCX6OQ3DkcsbYNE6H8uQQuVA', title: 'MrBeast', description: 'Challenges and philanthropy', subscriber_count: '300M', category: 'entertainment', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCX6OQ3DkcsbYNE6H8uQQuVA' },
        { id: 'UC-lHJZR3Gqxm24_Vd_AJ5Yw', title: 'PewDiePie', description: 'Gaming and entertainment', subscriber_count: '111M', category: 'gaming', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC-lHJZR3Gqxm24_Vd_AJ5Yw' },
        { id: 'UCq-Fj5jknLsUf-MWSy4_brA', title: '3Blue1Brown', description: 'Math visualizations and explanations', subscriber_count: '6M', category: 'education', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCq-Fj5jknLsUf-MWSy4_brA' },
        { id: 'UCYO_jab_esuFRV4b17AJtAw', title: '3Blue1Brown', description: 'Animated math explanations', subscriber_count: '6M', category: 'education', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCYO_jab_esuFRV4b17AJtAw' },
        { id: 'UC2C_jShtL725hvbm1arSV9w', title: 'CGP Grey', description: 'Educational explanations', subscriber_count: '6M', category: 'education', feed_url: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC2C_jShtL725hvbm1arSV9w' }
    ],

    initialize: function (options) {
        this.options = options || {};
        this.model = NEWSBLUR.assets;
        this.active_tab = this.options.initial_tab || 'search';
        this.view_mode = 'grid';
        this.search_query = '';
        this.search_debounced = _.debounce(_.bind(this.perform_search, this), 300);
        this.search_version = 0;  // Track search version to cancel stale responses

        this.init_tab_states();
        this.render();
    },

    init_tab_states: function () {
        var default_search_state = {
            results: [],
            page: 1,
            has_more: true,
            is_loading: false,
            query: ''
        };

        this.search_state = _.extend({}, default_search_state, {
            trending_feeds_collection: new NEWSBLUR.Collections.TrendingFeeds(),
            trending_feeds: [],
            trending_loaded: false,
            trending_page: 1,
            trending_days: 7,
            trending_has_more: true
        });
        this.youtube_state = _.extend({}, default_search_state, {
            selected_category: 'all'
        });
        this.reddit_state = _.extend({}, default_search_state, {
            popular_subreddits: [],
            popular_loaded: false,
            selected_category: 'all'
        });
        this.newsletters_state = _.extend({}, default_search_state);
        this.podcasts_state = _.extend({}, default_search_state, {
            selected_category: 'all'
        });

        this.trending_state = {
            feeds: [],
            page: 1,
            days: 7,
            has_more: true,
            is_loading: false
        };

        this.categories_state = {
            categories: [],
            selected_category: null,
            feeds: [],
            feeds_data: {},  // Cache of all feeds from /categories/ API
            is_loading: false
        };

        this.google_news_state = {
            is_loading: false,
            is_subscribed: false,
            query: '',
            selected_topic: null,
            language: 'en',
            feed_url: null,
            feed_id: null
        };
    },

    close: function () {
        this.$el.remove();
    },

    // =============
    // = Rendering =
    // =============

    render: function () {
        var self = this;

        this.$el.html($.make('div', { className: 'NB-add-site-container' }, [
            this.render_header(),
            $.make('div', { className: 'NB-add-site-tab-content' },
                _.map(this.TABS, function(tab) {
                    return $.make('div', {
                        className: 'NB-add-site-tab-pane NB-add-site-' + tab.id + '-tab' +
                                   (self.active_tab === tab.id ? ' NB-active' : '')
                    });
                })
            )
        ]));

        this.render_active_tab();
        this.$el.data('view', this);

        return this;
    },

    render_header: function () {
        var self = this;

        return $.make('div', { className: 'NB-add-site-header' }, [
            $.make('div', { className: 'NB-add-site-tabs-row' }, [
                $.make('div', { className: 'NB-add-site-tabs' },
                    _.map(this.TABS, function(tab) {
                        return $.make('div', {
                            className: 'NB-add-site-tab' + (self.active_tab === tab.id ? ' NB-active' : ''),
                            'data-tab': tab.id
                        }, [
                            $.make('img', { src: tab.icon, className: 'NB-add-site-tab-icon' }),
                            $.make('span', { className: 'NB-add-site-tab-label' }, tab.label)
                        ]);
                    })
                ),
                $.make('div', { className: 'NB-add-site-view-toggles' }, [
                    this.make_view_toggle('grid', 'Grid view', '/media/img/icons/nouns/layout-grid.svg'),
                    this.make_view_toggle('list', 'List view', '/media/img/icons/nouns/layout-list.svg')
                ])
            ])
        ]);
    },

    make_view_toggle: function (mode, title, icon) {
        var label = mode === 'grid' ? 'Grid' : 'List';
        return $.make('div', {
            className: 'NB-add-site-view-toggle' + (this.view_mode === mode ? ' NB-active' : ''),
            'data-mode': mode,
            title: title
        }, [
            $.make('img', { src: icon }),
            $.make('span', { className: 'NB-add-site-view-toggle-label' }, label)
        ]);
    },

    render_active_tab: function () {
        var tab_renderers = {
            'search': 'render_search_tab',
            'youtube': 'render_youtube_tab',
            'reddit': 'render_reddit_tab',
            'newsletters': 'render_newsletters_tab',
            'podcasts': 'render_podcasts_tab',
            'google-news': 'render_google_news_tab',
            'trending': 'render_trending_tab',
            'categories': 'render_categories_tab'
        };

        var renderer = tab_renderers[this.active_tab];
        if (renderer && this[renderer]) {
            this[renderer]();
        }
    },

    // ==============
    // = Search Tab =
    // ==============

    render_search_tab: function (options) {
        options = options || {};
        var $tab = this.$('.NB-add-site-search-tab');
        var state = this.search_state;

        // Check if we can do a partial update (results only) to preserve input focus
        var $existing_results = $tab.find('.NB-add-site-tab-results');
        var can_update_results_only = options.results_only && $existing_results.length > 0;

        var $content;

        if (state.is_loading && state.results.length === 0) {
            $content = this.make_loading_indicator();
        } else if (state.results.length === 0 && !this.search_query) {
            $content = this.render_search_empty_state();
        } else if (state.results.length === 0 && this.search_query) {
            if (this.is_url(this.search_query)) {
                $content = this.render_url_subscribe_card(this.search_query);
            } else {
                $content = this.make_no_results_message(
                    '\ud83d\udd0d',
                    'No feeds found',
                    'Try a different search term or paste a URL directly.'
                );
            }
        } else {
            var $results = this.make_results_container();
            _.each(state.results, function(feed) {
                $results.append(this.render_feed_card(feed));
            }, this);

            if (state.is_loading) {
                $results.append(this.make_loading_indicator());
            }
            $content = $results;
        }

        if (can_update_results_only) {
            // Only update results, preserving search input focus
            $existing_results.html($content);
        } else {
            // Full render needed
            var $search_bar = this.render_tab_search_bar({
                input_class: 'NB-add-site-search-input',
                placeholder: 'Search for feeds or paste a URL...',
                value: this.search_query
            });

            $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
                $search_bar,
                $.make('div', { className: 'NB-add-site-tab-results' }, [$content])
            ]));
        }
    },

    render_tab_search_bar: function (config) {
        return $.make('div', { className: 'NB-add-site-tab-search-bar' }, [
            $.make('div', { className: 'NB-add-site-search-wrapper' }, [
                $.make('img', {
                    src: '/media/img/icons/lucide/search.svg',
                    className: 'NB-add-site-search-icon'
                }),
                $.make('input', {
                    type: 'text',
                    className: config.input_class,
                    placeholder: config.placeholder,
                    value: config.value || ''
                }),
                $.make('div', {
                    className: 'NB-add-site-search-clear' + (config.value ? '' : ' NB-hidden')
                }, '\u00d7')
            ])
        ]);
    },

    render_search_empty_state: function () {
        var self = this;
        var state = this.search_state;

        // Load trending feeds if not already loaded
        if (!state.trending_loaded && state.trending_feeds_collection.length === 0) {
            this.fetch_search_trending_feeds();
        }

        var $container = $.make('div', { className: 'NB-add-site-discover-container' });

        // Trending Feeds Section
        var $trending_section = $.make('div', { className: 'NB-add-site-section NB-add-site-trending-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, [
                    $.make('img', { src: '/media/img/icons/nouns/pulse.svg', className: 'NB-add-site-section-icon' }),
                    'Trending Feeds'
                ])
            ]),
            $.make('div', { className: 'NB-add-site-section-content NB-add-site-trending-content' })
        ]);

        // Render trending feeds based on view mode
        var $trending_content = $trending_section.find('.NB-add-site-trending-content');
        if (state.trending_feeds_collection.length > 0) {
            $trending_content.append(this.render_trending_feeds());
        } else if (state.trending_loaded) {
            $trending_content.append(this.make_no_results_message(
                '',
                'No trending feeds available',
                'Check back later for popular feeds being added by NewsBlur users.'
            ));
        } else {
            $trending_content.append(this.make_loading_indicator());
        }

        $container.append($trending_section);

        // Browse by Category Section
        var $categories_section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, [
                    $.make('img', { src: '/media/img/icons/nouns/folder-closed.svg', className: 'NB-add-site-section-icon' }),
                    'Browse by Category'
                ])
            ]),
            $.make('div', { className: 'NB-add-site-section-content' }, [
                $.make('div', { className: 'NB-add-site-category-pills' }, [
                    this.make_category_pill('tech', 'Technology', '/media/img/icons/nouns/ai-brain.svg'),
                    this.make_category_pill('news', 'News', '/media/img/icons/nouns/world.svg'),
                    this.make_category_pill('business', 'Business', '/media/img/icons/nouns/dialog-statistics.svg'),
                    this.make_category_pill('science', 'Science', '/media/img/icons/nouns/activity.svg'),
                    this.make_category_pill('entertainment', 'Entertainment', '/media/img/icons/nouns/image.svg'),
                    this.make_category_pill('sports', 'Sports', '/media/img/icons/nouns/pulse.svg')
                ])
            ])
        ]);

        $container.append($categories_section);

        // Tips Section
        var $tips_section = $.make('div', { className: 'NB-add-site-section NB-add-site-section-tips' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, [
                    $.make('img', { src: '/media/img/icons/nouns/dialog-tips.svg', className: 'NB-add-site-section-icon' }),
                    'Quick Tips'
                ])
            ]),
            $.make('div', { className: 'NB-add-site-tips-grid' }, [
                this.make_tip_card('/media/img/icons/nouns/link.svg', 'Paste any URL', 'Paste any website URL to automatically find its RSS feed'),
                this.make_tip_card('/media/img/icons/nouns/search.svg', 'Search by name', 'Search for blogs, news sites, or publications by name'),
                this.make_tip_card('/media/img/icons/nouns/folder-closed.svg', 'Browse categories', 'Explore curated collections of feeds by topic')
            ])
        ]);

        $container.append($tips_section);

        return $container;
    },

    render_trending_feeds: function () {
        var self = this;
        var state = this.search_state;
        var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');

        if (this.view_mode === 'grid') {
            // Grid view: Show feed badges only (like cards)
            var $grid = $.make('div', { className: 'NB-trending-feed-grid' });
            state.trending_feeds_collection.each(function (trending_feed) {
                var $badge = $.make('div', { className: 'NB-trending-feed-card' });
                new NEWSBLUR.Views.FeedBadge({
                    el: $badge,
                    model: trending_feed.get("feed"),
                    show_folders: true,
                    in_add_site_view: self,
                    load_feed_after_add: false
                });
                $grid.append($badge);
            });
            return $grid;
        } else {
            // List view: Show feed badges with story titles (like TrendingSitesView)
            var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor });
            state.trending_feeds_collection.each(function (trending_feed) {
                var $story_titles = $.make('div', { className: 'NB-story-titles' });
                var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                    el: $story_titles,
                    collection: trending_feed.get("stories"),
                    $story_titles: $story_titles,
                    override_layout: 'split',
                    pane_anchor: pane_anchor,
                    on_trending_feed: trending_feed,
                    in_add_site_view: self
                });
                var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, [
                    new NEWSBLUR.Views.FeedBadge({
                        model: trending_feed.get("feed"),
                        show_folders: true,
                        in_add_site_view: self,
                        load_feed_after_add: false
                    }),
                    story_titles_view.render().el
                ]);
                $list.append($badge);
            });
            return $list;
        }
    },

    fetch_search_trending_feeds: function () {
        var self = this;
        var state = this.search_state;

        state.trending_feeds_collection.fetch({
            data: { page: state.trending_page, days: state.trending_days },
            success: function () {
                state.trending_loaded = true;
                state.trending_has_more = state.trending_feeds_collection.has_more;
                // Re-render if still on search tab with empty query
                if (self.active_tab === 'search' && !self.search_query) {
                    self.render_search_tab();
                }
            },
            error: function () {
                state.trending_loaded = true;
                // Re-render to show error state
                if (self.active_tab === 'search' && !self.search_query) {
                    self.render_search_tab();
                }
            }
        });
    },

    make_source_pill: function (tab_id, label, icon) {
        return $.make('div', {
            className: 'NB-add-site-source-pill',
            'data-tab': tab_id
        }, [
            $.make('img', { src: icon, className: 'NB-add-site-source-pill-icon' }),
            $.make('span', label)
        ]);
    },

    make_category_pill: function (category_id, label, icon) {
        return $.make('div', {
            className: 'NB-add-site-category-pill',
            'data-category': category_id
        }, [
            $.make('img', { src: icon, className: 'NB-add-site-category-pill-icon' }),
            $.make('span', label)
        ]);
    },

    handle_category_pill_click: function (e) {
        var self = this;
        var category_id = $(e.currentTarget).data('category');

        // Map category pill IDs to category API names
        var category_map = {
            'technology': 'Tech',
            'news': 'News',
            'business': 'Business',
            'science': 'Science',
            'entertainment': 'Entertainment',
            'sports': 'Sports'
        };

        var category_name = category_map[category_id] || category_id;

        // Find or create category object
        var category = _.find(this.categories_state.categories, function(c) {
            return c.id === category_id || c.name === category_name ||
                   c.name.toLowerCase() === category_id.toLowerCase();
        });

        if (!category) {
            // Create a temporary category object if not found in cache
            category = { id: category_id, name: category_name };
        }

        this.categories_state.selected_category = category;
        this.render_search_category_feeds();
    },

    render_search_category_feeds: function () {
        var self = this;
        var state = this.categories_state;
        var category = state.selected_category;

        if (!category) return;

        var $back_btn = $.make('div', { className: 'NB-add-site-category-back' }, [
            $.make('img', { src: '/media/img/icons/lucide/arrow-left.svg' }),
            'Back to Search'
        ]);

        var $content = $.make('div', { className: 'NB-add-site-search-category-view' }, [
            $back_btn,
            $.make('div', { className: 'NB-add-site-section' }, [
                $.make('div', { className: 'NB-add-site-section-header' }, [
                    $.make('img', { src: '/media/img/icons/nouns/folder-closed.svg', className: 'NB-add-site-section-icon' }),
                    $.make('span', { className: 'NB-add-site-section-title' }, category.name)
                ]),
                $.make('div', { className: 'NB-add-site-category-feeds-results' })
            ])
        ]);

        this.$('.NB-add-site-search-tab').html($content);

        // Bind back button click
        $back_btn.on('click', function () {
            self.categories_state.selected_category = null;
            self.render_search_tab();
        });

        // Fetch category feeds
        this.fetch_search_category_feeds(category);
    },

    fetch_search_category_feeds: function (category) {
        var self = this;
        var $results = this.$('.NB-add-site-category-feeds-results');

        $results.html(this.make_loading_indicator());

        // First check if we have cached feeds data
        if (this.categories_state.feeds_data && Object.keys(this.categories_state.feeds_data).length > 0) {
            this.render_search_category_feed_results(category);
            return;
        }

        // Fetch categories to get feeds data
        this.model.make_request('/categories/', {}, function(data) {
            if (data && data.categories) {
                self.categories_state.feeds_data = data.feeds || {};
                self.categories_state.categories = data.categories;

                // Find the actual category object now that we have data
                var actual_category = _.find(data.categories, function(c) {
                    return c.name.toLowerCase() === category.name.toLowerCase() ||
                           c.id === category.id;
                });

                if (actual_category) {
                    self.categories_state.selected_category = actual_category;
                }

                self.render_search_category_feed_results(actual_category || category);
            }
        });
    },

    render_search_category_feed_results: function (category) {
        var self = this;
        var $results = this.$('.NB-add-site-category-feeds-results');
        var feeds_data = this.categories_state.feeds_data || {};
        var feed_ids = category.feed_ids || [];

        if (feed_ids.length === 0) {
            $results.html($.make('div', { className: 'NB-add-site-empty-state' }, [
                $.make('div', { className: 'NB-add-site-empty-text' }, 'No feeds found in this category.')
            ]));
            return;
        }

        var $grid = $.make('div', { className: 'NB-trending-feed-grid' });

        _.each(feed_ids.slice(0, 30), function(feed_id) {
            var feed_data = feeds_data[feed_id];
            if (feed_data) {
                var $card = $.make('div', { className: 'NB-trending-feed-card' });
                var feed_model = new NEWSBLUR.Models.Feed(feed_data);
                new NEWSBLUR.Views.FeedBadge({
                    el: $card,
                    model: feed_model,
                    show_folders: true,
                    in_add_site_view: self,
                    load_feed_after_add: false
                });
                $grid.append($card);
            }
        });

        $results.html($grid);
    },

    make_tip_card: function (icon, title, description) {
        return $.make('div', { className: 'NB-add-site-tip-card' }, [
            $.make('img', { src: icon, className: 'NB-add-site-tip-card-icon' }),
            $.make('div', { className: 'NB-add-site-tip-card-content' }, [
                $.make('div', { className: 'NB-add-site-tip-card-title' }, title),
                $.make('div', { className: 'NB-add-site-tip-card-desc' }, description)
            ])
        ]);
    },

    make_tip: function (icon, text) {
        return $.make('div', { className: 'NB-add-site-tip' }, [
            $.make('span', { className: 'NB-add-site-tip-icon' }, icon),
            $.make('span', text)
        ]);
    },

    // ===========================
    // = Source Tabs (Shared UI) =
    // ===========================

    render_source_tab: function (config) {
        var $tab = this.$('.NB-add-site-' + config.tab_id + '-tab');
        var state = this[config.state_key];

        var $content = $.make('div', { className: 'NB-add-site-source-tab' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-' + config.tab_id }, [
                    $.make('img', { src: config.icon })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, config.title),
                    $.make('div', { className: 'NB-add-site-source-desc' }, config.description)
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-search' }, [
                $.make('input', {
                    type: 'text',
                    className: 'NB-add-site-tab-search-input NB-add-site-' + config.tab_id + '-search',
                    placeholder: config.placeholder
                }),
                $.make('div', { className: 'NB-add-site-tab-search-btn' }, config.button_text)
            ]),
            $.make('div', { className: 'NB-add-site-source-results' }, config.extra_content || [])
        ]);

        $tab.html($content);

        if (state.results.length > 0) {
            config.render_results.call(this);
        }
    },

    // ===============
    // = YouTube Tab =
    // ===============

    render_youtube_tab: function () {
        var self = this;
        var state = this.youtube_state;
        var $tab = this.$('.NB-add-site-youtube-tab');

        // Build category pills
        var $category_pills = $.make('div', { className: 'NB-add-site-filter-pills' },
            _.map(this.YOUTUBE_CATEGORIES, function(cat) {
                return $.make('div', {
                    className: 'NB-add-site-filter-pill' + (state.selected_category === cat.id ? ' NB-active' : ''),
                    'data-category': cat.id,
                    'data-source': 'youtube'
                }, cat.name);
            })
        );

        var $content = $.make('div', { className: 'NB-add-site-source-tab' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-youtube' }, [
                    $.make('img', { src: '/media/img/reader/youtube.png' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'YouTube Channels'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Subscribe to YouTube channels and playlists as RSS feeds.')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-search' }, [
                $.make('input', {
                    type: 'text',
                    className: 'NB-add-site-tab-search-input NB-add-site-youtube-search',
                    placeholder: 'Search YouTube channels...'
                }),
                $.make('div', { className: 'NB-add-site-tab-search-btn' }, 'Search')
            ]),
            $category_pills,
            $.make('div', { className: 'NB-add-site-source-results' })
        ]);

        $tab.html($content);

        // Show search results or popular channels
        if (state.results.length > 0) {
            this.render_youtube_results();
        } else {
            this.render_youtube_popular();
        }
    },

    render_youtube_results: function () {
        var $results = this.$('.NB-add-site-youtube-tab .NB-add-site-source-results');
        var state = this.youtube_state;

        $results.empty();

        if (state.is_loading && state.results.length === 0) {
            $results.html(this.make_loading_indicator());
            return;
        }

        var $grid = this.make_results_container();
        _.each(state.results, function(channel) {
            $grid.append(this.render_youtube_card(channel));
        }, this);

        $results.html($grid);
    },

    render_youtube_popular: function () {
        var self = this;
        var state = this.youtube_state;
        var $results = this.$('.NB-add-site-youtube-tab .NB-add-site-source-results');

        // Filter channels by category
        var channels = this.POPULAR_YOUTUBE_CHANNELS;
        if (state.selected_category && state.selected_category !== 'all') {
            channels = _.filter(channels, function(ch) {
                return ch.category === state.selected_category;
            });
        }

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Channels')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = $.make('div', { className: 'NB-add-site-results NB-add-site-results-' + this.view_mode });
        _.each(channels, function(channel) {
            $grid.append(self.render_youtube_card(channel));
        });

        $section.find('.NB-add-site-section-content').append($grid);
        $results.html($section);
    },

    render_youtube_card: function (channel) {
        var meta_parts = [channel.subscriber_count || ''];
        if (channel.video_count) {
            meta_parts.push(channel.video_count + ' videos');
        }

        return this.make_source_card({
            card_class: 'NB-add-site-youtube-card',
            icon: channel.thumbnail || '/media/img/reader/youtube.png',
            title: channel.title,
            meta: meta_parts.filter(Boolean).join(' \u2022 '),
            description: channel.description,
            feed_url: channel.feed_url
        });
    },

    // ==============
    // = Reddit Tab =
    // ==============

    render_reddit_tab: function () {
        var self = this;
        var state = this.reddit_state;
        var $tab = this.$('.NB-add-site-reddit-tab');

        // Build category pills
        var $category_pills = $.make('div', { className: 'NB-add-site-filter-pills' },
            _.map(this.REDDIT_CATEGORIES, function(cat) {
                return $.make('div', {
                    className: 'NB-add-site-filter-pill' + (state.selected_category === cat.id ? ' NB-active' : ''),
                    'data-category': cat.id,
                    'data-source': 'reddit'
                }, cat.name);
            })
        );

        var $content = $.make('div', { className: 'NB-add-site-source-tab' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-reddit' }, [
                    $.make('img', { src: '/media/img/reader/reddit.png' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Reddit Subreddits'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Subscribe to subreddits as RSS feeds.')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-search' }, [
                $.make('input', {
                    type: 'text',
                    className: 'NB-add-site-tab-search-input NB-add-site-reddit-search',
                    placeholder: 'Search subreddits (e.g., programming, news, gaming)...'
                }),
                $.make('div', { className: 'NB-add-site-tab-search-btn' }, 'Search')
            ]),
            $category_pills,
            $.make('div', { className: 'NB-add-site-source-results' })
        ]);

        $tab.html($content);

        // Show search results or popular subreddits
        if (state.results.length > 0) {
            this.render_reddit_results();
        } else {
            this.render_reddit_popular();
        }
    },

    render_reddit_results: function () {
        var $results = this.$('.NB-add-site-reddit-tab .NB-add-site-source-results');
        var state = this.reddit_state;

        $results.empty();

        if (state.is_loading && state.results.length === 0) {
            $results.html(this.make_loading_indicator());
            return;
        }

        var $grid = this.make_results_container();
        _.each(state.results, function(subreddit) {
            $grid.append(this.render_reddit_card(subreddit));
        }, this);

        $results.html($grid);
    },

    render_reddit_popular: function () {
        var self = this;
        var state = this.reddit_state;
        var $results = this.$('.NB-add-site-reddit-tab .NB-add-site-source-results');

        // Load popular subreddits if not loaded
        if (!state.popular_loaded) {
            $results.html(this.make_loading_indicator());
            this.fetch_reddit_popular();
            return;
        }

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Subreddits')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = $.make('div', { className: 'NB-add-site-results NB-add-site-results-' + this.view_mode });
        _.each(state.popular_subreddits, function(subreddit) {
            $grid.append(self.render_reddit_card(subreddit));
        });

        $section.find('.NB-add-site-section-content').append($grid);
        $results.html($section);
    },

    fetch_reddit_popular: function () {
        var self = this;
        var state = this.reddit_state;

        this.model.make_request('/discover/reddit/popular', { limit: 30 }, function(data) {
            state.popular_loaded = true;
            if (data && data.results) {
                state.popular_subreddits = data.results;
            }
            // Re-render if still on reddit tab
            if (self.active_tab === 'reddit' && state.results.length === 0) {
                self.render_reddit_popular();
            }
        }, function() {
            state.popular_loaded = true;
            state.popular_subreddits = [];
            self.render_reddit_popular();
        }, { request_type: 'GET' });
    },

    render_reddit_card: function (subreddit) {
        var subscriber_text = this.format_subscriber_count(subreddit.subscribers);

        return this.make_source_card({
            card_class: 'NB-add-site-reddit-card',
            icon: subreddit.icon || '/media/img/reader/reddit.png',
            fallback_icon: '/media/img/reader/reddit.png',
            title: 'r/' + subreddit.name,
            meta: subscriber_text,
            description: subreddit.description,
            feed_url: subreddit.feed_url
        });
    },

    format_subscriber_count: function (subscribers) {
        if (!subscribers) return '';

        if (subscribers >= 1000000) {
            return (subscribers / 1000000).toFixed(1) + 'M members';
        }
        if (subscribers >= 1000) {
            return (subscribers / 1000).toFixed(0) + 'K members';
        }
        return subscribers + ' members';
    },

    // ===================
    // = Newsletters Tab =
    // ===================

    render_newsletters_tab: function () {
        var self = this;
        var state = this.newsletters_state;
        var $tab = this.$('.NB-add-site-newsletters-tab');

        var platform_hints = $.make('div', { className: 'NB-add-site-platform-hints' }, [
            this.make_platform_hint('Substack:', 'newsletter.substack.com'),
            this.make_platform_hint('Medium:', 'medium.com/@username'),
            this.make_platform_hint('Buttondown:', 'buttondown.email/username'),
            this.make_platform_hint('Ghost:', 'newsletter.ghost.io')
        ]);

        var $content = $.make('div', { className: 'NB-add-site-source-tab' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-newsletters' }, [
                    $.make('img', { src: '/media/img/reader/newsletters_folder.png' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Newsletters & Substack'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Subscribe to newsletters from Substack, Medium, Ghost, Buttondown, and more.')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-search' }, [
                $.make('input', {
                    type: 'text',
                    className: 'NB-add-site-tab-search-input NB-add-site-newsletters-search',
                    placeholder: 'Paste newsletter URL (e.g., example.substack.com)...'
                }),
                $.make('div', { className: 'NB-add-site-tab-search-btn' }, 'Find Feed')
            ]),
            platform_hints,
            $.make('div', { className: 'NB-add-site-source-results' })
        ]);

        $tab.html($content);

        // Show search results or popular newsletters
        if (state.results.length > 0) {
            this.render_newsletter_results();
        } else {
            this.render_newsletters_popular();
        }
    },

    make_platform_hint: function (label, example) {
        return $.make('div', { className: 'NB-add-site-platform-hint' }, [
            $.make('span', { className: 'NB-add-site-platform-label' }, label),
            $.make('span', { className: 'NB-add-site-platform-example' }, example)
        ]);
    },

    render_newsletter_results: function () {
        var $results = this.$('.NB-add-site-newsletters-tab .NB-add-site-source-results');
        var state = this.newsletters_state;

        $results.empty();

        if (state.is_loading) {
            $results.html(this.make_loading_indicator());
            return;
        }

        var $grid = this.make_results_container();
        _.each(state.results, function(newsletter) {
            $grid.append(this.render_newsletter_card(newsletter));
        }, this);

        $results.html($grid);
    },

    render_newsletters_popular: function () {
        var self = this;
        var $results = this.$('.NB-add-site-newsletters-tab .NB-add-site-source-results');

        // Group newsletters by platform
        var by_platform = _.groupBy(this.POPULAR_NEWSLETTERS, 'platform');
        var platform_order = ['substack', 'medium', 'ghost', 'generic', 'direct'];

        var $container = $.make('div', { className: 'NB-add-site-newsletters-popular' });

        _.each(platform_order, function(platform) {
            var newsletters = by_platform[platform];
            if (!newsletters || newsletters.length === 0) return;

            var platform_name = self.NEWSLETTER_PLATFORMS[platform] || platform;

            var $section = $.make('div', { className: 'NB-add-site-section' }, [
                $.make('div', { className: 'NB-add-site-section-header' }, [
                    $.make('div', { className: 'NB-add-site-section-title' }, platform_name + ' Examples')
                ]),
                $.make('div', { className: 'NB-add-site-section-content' })
            ]);

            var $grid = $.make('div', { className: 'NB-add-site-results NB-add-site-results-' + self.view_mode });
            _.each(newsletters, function(newsletter) {
                $grid.append(self.render_popular_newsletter_card(newsletter));
            });

            $section.find('.NB-add-site-section-content').append($grid);
            $container.append($section);
        });

        $results.html($container);
    },

    render_popular_newsletter_card: function (newsletter) {
        var platform_label = this.NEWSLETTER_PLATFORMS[newsletter.platform] || 'Newsletter';

        return $.make('div', { className: 'NB-add-site-card NB-add-site-newsletter-card' }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('div', {
                    className: 'NB-add-site-card-icon NB-add-site-platform-icon NB-platform-' + newsletter.platform
                }, [
                    $.make('img', { src: newsletter.icon || '/media/img/reader/email_icon.png' })
                ]),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' }, newsletter.title),
                    $.make('div', { className: 'NB-add-site-card-meta' }, [
                        $.make('span', { className: 'NB-add-site-platform-badge' }, platform_label),
                        newsletter.subscribers ? ' \u2022 ' + newsletter.subscribers + ' subscribers' : ''
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-add-site-card-desc' }, newsletter.description),
            $.make('div', { className: 'NB-add-site-card-actions' }, [
                this.make_folder_selector(),
                $.make('div', {
                    className: 'NB-add-site-card-subscribe NB-add-site-subscribe-btn',
                    'data-feed-url': newsletter.feed_url
                }, 'Subscribe')
            ])
        ].filter(Boolean));
    },

    render_newsletter_card: function (newsletter) {
        var platform_label = this.NEWSLETTER_PLATFORMS[newsletter.platform] || 'Newsletter';
        var title = newsletter.title || this.extract_domain(newsletter.original_url);

        return $.make('div', { className: 'NB-add-site-card NB-add-site-newsletter-card' }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('div', {
                    className: 'NB-add-site-card-icon NB-add-site-platform-icon NB-platform-' + newsletter.platform
                }, [
                    $.make('img', { src: newsletter.icon || '/media/img/reader/email_icon.png' })
                ]),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' }, title),
                    $.make('div', { className: 'NB-add-site-card-meta' }, [
                        $.make('span', { className: 'NB-add-site-platform-badge' }, platform_label)
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-add-site-card-desc' },
                'Subscribe to ' + title + ' via RSS'),
            $.make('div', { className: 'NB-add-site-card-url' }, newsletter.feed_url),
            $.make('div', { className: 'NB-add-site-card-actions' }, [
                this.make_folder_selector(),
                $.make('div', {
                    className: 'NB-add-site-card-subscribe NB-add-site-subscribe-btn',
                    'data-feed-url': newsletter.feed_url
                }, 'Subscribe')
            ])
        ].filter(Boolean));
    },

    extract_domain: function (url) {
        if (!url) return 'Newsletter';
        try {
            var hostname = new URL(url).hostname;
            return hostname.replace('www.', '').split('.')[0];
        } catch (e) {
            return url.split('/')[0];
        }
    },

    // ================
    // = Podcasts Tab =
    // ================

    render_podcasts_tab: function () {
        var self = this;
        var state = this.podcasts_state;
        var $tab = this.$('.NB-add-site-podcasts-tab');

        // Build category pills
        var $category_pills = $.make('div', { className: 'NB-add-site-filter-pills' },
            _.map(this.PODCAST_CATEGORIES, function(cat) {
                return $.make('div', {
                    className: 'NB-add-site-filter-pill' + (state.selected_category === cat.id ? ' NB-active' : ''),
                    'data-category': cat.id,
                    'data-source': 'podcasts'
                }, cat.name);
            })
        );

        var $content = $.make('div', { className: 'NB-add-site-source-tab' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-podcasts' }, [
                    $.make('img', { src: '/media/img/icons/nouns/activity.svg' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Podcasts'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Subscribe to podcasts via RSS. Search by name or paste a feed URL.')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-search' }, [
                $.make('input', {
                    type: 'text',
                    className: 'NB-add-site-tab-search-input NB-add-site-podcasts-search',
                    placeholder: 'Search podcasts (e.g., "technology", "true crime", "comedy")...'
                }),
                $.make('div', { className: 'NB-add-site-tab-search-btn' }, 'Search')
            ]),
            $category_pills,
            $.make('div', { className: 'NB-add-site-source-results' })
        ]);

        $tab.html($content);

        // Show search results or popular podcasts
        if (state.results.length > 0) {
            this.render_podcast_results();
        } else {
            this.render_podcasts_popular();
        }
    },

    render_podcast_results: function () {
        var $results = this.$('.NB-add-site-podcasts-tab .NB-add-site-source-results');
        var state = this.podcasts_state;

        $results.empty();

        if (state.is_loading) {
            $results.html(this.make_loading_indicator());
            return;
        }

        var $grid = this.make_results_container();
        _.each(state.results, function(podcast) {
            $grid.append(this.render_podcast_card(podcast));
        }, this);

        $results.html($grid);
    },

    render_podcasts_popular: function () {
        var self = this;
        var state = this.podcasts_state;
        var $results = this.$('.NB-add-site-podcasts-tab .NB-add-site-source-results');

        // Filter podcasts by category
        var podcasts = this.POPULAR_PODCASTS;
        if (state.selected_category && state.selected_category !== 'all') {
            podcasts = _.filter(podcasts, function(p) {
                return p.category === state.selected_category;
            });
        }

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Podcasts')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = $.make('div', { className: 'NB-add-site-results NB-add-site-results-' + self.view_mode });
        _.each(podcasts, function(podcast) {
            $grid.append(self.render_podcast_card(podcast));
        });

        $section.find('.NB-add-site-section-content').append($grid);
        $results.html($section);
    },

    render_podcast_card: function (podcast) {
        var meta_parts = [];
        if (podcast.artist) meta_parts.push(podcast.artist);
        if (podcast.track_count) meta_parts.push(podcast.track_count + ' episodes');

        var genre_element = null;
        if (podcast.genre) {
            genre_element = $.make('div', { className: 'NB-add-site-card-genre' }, [
                $.make('span', { className: 'NB-add-site-genre-badge' }, podcast.genre)
            ]);
        }

        return $.make('div', { className: 'NB-add-site-card NB-add-site-podcast-card' }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('img', {
                    src: podcast.artwork || '/media/img/icons/lucide/podcast.svg',
                    className: 'NB-add-site-card-icon NB-add-site-podcast-artwork',
                    onerror: "this.src='/media/img/icons/lucide/podcast.svg'"
                }),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' }, podcast.name),
                    $.make('div', { className: 'NB-add-site-card-meta' },
                        meta_parts.join(' \u2022 ')
                    )
                ])
            ]),
            genre_element,
            $.make('div', { className: 'NB-add-site-card-actions' }, [
                this.make_folder_selector(),
                $.make('div', {
                    className: 'NB-add-site-card-subscribe NB-add-site-subscribe-btn',
                    'data-feed-url': podcast.feed_url
                }, 'Subscribe')
            ])
        ].filter(Boolean));
    },

    // ===================
    // = Google News Tab =
    // ===================

    render_google_news_tab: function () {
        var $tab = this.$('.NB-add-site-google-news-tab');
        var state = this.google_news_state;

        var $content = $.make('div', { className: 'NB-add-site-source-tab' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-google-news' }, [
                    $.make('img', { src: '/media/img/icons/nouns/world.svg' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Google News'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Subscribe to Google News feeds by topic or custom keywords.')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-results' }, [
                $.make('div', { className: 'NB-add-site-google-news-unified' }, [
                    $.make('div', { className: 'NB-add-site-google-news-input-row' }, [
                        $.make('input', {
                            type: 'text',
                            className: 'NB-add-site-tab-search-input NB-add-site-google-news-search-input',
                            placeholder: 'Enter a topic or keywords (e.g., "climate change", "AI startups")...',
                            value: state.query || ''
                        })
                    ]),
                    $.make('div', { className: 'NB-add-site-google-news-topics-label' }, 'Or choose a topic:'),
                    $.make('div', { className: 'NB-add-site-google-news-topics' },
                        _.map(this.GOOGLE_NEWS_TOPICS, function (topic) {
                            var is_selected = state.selected_topic === topic.id;
                            return $.make('div', {
                                className: 'NB-add-site-google-news-topic' + (is_selected ? ' NB-selected' : ''),
                                'data-topic-id': topic.id,
                                'data-topic-name': topic.name
                            }, [
                                $.make('span', { className: 'NB-add-site-topic-icon' }, topic.icon),
                                $.make('span', { className: 'NB-add-site-topic-name' }, topic.name)
                            ]);
                        })
                    ),
                    $.make('div', { className: 'NB-add-site-google-news-subscribe-row' }, [
                        this.make_folder_selector(),
                        $.make('select', { className: 'NB-add-site-google-news-language' }, [
                            $.make('option', { value: 'en' }, 'English'),
                            $.make('option', { value: 'es' }, 'Spanish'),
                            $.make('option', { value: 'fr' }, 'French'),
                            $.make('option', { value: 'de' }, 'German'),
                            $.make('option', { value: 'pt' }, 'Portuguese'),
                            $.make('option', { value: 'ja' }, 'Japanese'),
                            $.make('option', { value: 'zh' }, 'Chinese')
                        ]),
                        $.make('div', {
                            className: 'NB-add-site-google-news-subscribe-btn' +
                                (state.is_subscribed ? ' NB-subscribed' : '') +
                                (state.is_loading ? ' NB-loading' : '')
                        }, state.is_subscribed ? 'Open Site' : (state.is_loading ? 'Subscribing...' : 'Subscribe'))
                    ])
                ])
            ])
        ]);

        $tab.html($content);

        // Restore language selection if we have one
        if (state.language) {
            $tab.find('.NB-add-site-google-news-language').val(state.language);
        }
    },

    // ================
    // = Trending Tab =
    // ================

    render_trending_tab: function () {
        var state = this.trending_state;

        var $content = $.make('div', { className: 'NB-add-site-source-tab NB-add-site-source-tab-wide' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-trending' }, [
                    $.make('img', { src: '/media/img/icons/nouns/pulse.svg' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Trending Sites'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Discover the most popular feeds being added by NewsBlur users.')
                ]),
                $.make('div', { className: 'NB-add-site-source-filter' }, [
                    $.make('select', { className: 'NB-add-site-trending-days' }, [
                        $.make('option', { value: '1' }, 'Today'),
                        $.make('option', { value: '7', selected: state.days === 7 }, 'This Week'),
                        $.make('option', { value: '30' }, 'This Month')
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-results NB-add-site-trending-results' })
        ]);

        this.$('.NB-add-site-trending-tab').html($content);

        if (state.feeds.length === 0 && !state.is_loading) {
            this.fetch_trending_feeds();
        } else {
            this.render_trending_results();
        }
    },

    fetch_trending_feeds: function () {
        var self = this;
        var state = this.trending_state;

        state.is_loading = true;
        this.$('.NB-add-site-trending-results').html(this.make_loading_indicator());

        this.model.make_request('/discover/trending', {
            page: state.page,
            days: state.days
        }, function (data) {
            state.is_loading = false;
            if (data && data.trending_feeds) {
                // Convert trending_feeds object to array for easier rendering
                var feeds_array = _.map(data.trending_feeds, function(item) {
                    return {
                        feed: item.feed,
                        stories: item.stories,
                        trending_score: item.trending_score
                    };
                });
                // Sort by trending score (highest first)
                feeds_array = _.sortBy(feeds_array, function(item) {
                    return -item.trending_score;
                });
                state.feeds = state.feeds.concat(feeds_array);
                state.has_more = data.has_more;
            }
            self.render_trending_results();
        }, function () {
            state.is_loading = false;
            self.$('.NB-add-site-trending-results').html(
                self.make_error_message('Failed to load trending sites')
            );
        }, { request_type: 'GET' });
    },

    render_trending_results: function () {
        var self = this;
        var $results = this.$('.NB-add-site-trending-results');
        var state = this.trending_state;

        if (state.feeds.length === 0) {
            $results.html($.make('div', { className: 'NB-add-site-no-results' }, 'No trending sites found'));
            return;
        }

        var $grid = this.make_results_container();
        _.each(state.feeds, function(item) {
            var feed = item.feed || item;
            var stories = item.stories || [];
            $grid.append(self.render_feed_card(feed, stories));
        });

        $results.html($grid);
    },

    handle_trending_days_change: function (e) {
        var new_days = parseInt($(e.currentTarget).val(), 10);
        var state = this.trending_state;

        if (new_days !== state.days) {
            state.days = new_days;
            state.page = 1;
            state.feeds = [];
            state.has_more = true;
            this.fetch_trending_feeds();
        }
    },

    // ==================
    // = Categories Tab =
    // ==================

    render_categories_tab: function () {
        var state = this.categories_state;

        if (state.selected_category) {
            this.render_category_feeds();
            return;
        }

        var $content = $.make('div', { className: 'NB-add-site-source-tab NB-add-site-source-tab-wide' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-categories' }, [
                    $.make('img', { src: '/media/img/icons/nouns/folder-closed.svg' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Browse by Category'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Discover feeds organized by topic and interest.')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-source-results NB-add-site-categories-grid' })
        ]);

        this.$('.NB-add-site-categories-tab').html($content);

        if (state.categories.length === 0 && !state.is_loading) {
            this.fetch_categories();
        } else {
            this.render_categories_grid();
        }
    },

    fetch_categories: function () {
        var self = this;
        var state = this.categories_state;

        state.is_loading = true;
        this.$('.NB-add-site-categories-grid').html(this.make_loading_indicator());

        this.model.make_request('/categories/', {}, function(data) {
            state.is_loading = false;

            if (data && data.categories) {
                // Store feeds data for later use
                state.feeds_data = data.feeds || {};

                // Map categories to display format with feed counts and icons
                state.categories = _.map(data.categories, function(cat) {
                    return {
                        id: cat.title.toLowerCase().replace(/\s+/g, '-'),
                        name: cat.title,
                        description: cat.description,
                        feed_ids: cat.feed_ids || [],
                        feed_count: (cat.feed_ids || []).length,
                        slug: cat.title.toLowerCase().replace(/\s+/g, '-'),
                        icon: self.get_category_icon(cat.title)
                    };
                });
            } else {
                state.categories = [];
            }

            self.render_categories_grid();
        }, function() {
            state.is_loading = false;
            state.categories = [];
            self.render_categories_grid();
        }, { request_type: 'GET' });
    },

    get_category_icon: function(title) {
        // Map category titles to SVG icons
        var icon_map = {
            'technology': '/media/img/icons/nouns/computer.svg',
            'news': '/media/img/icons/nouns/news.svg',
            'science': '/media/img/icons/nouns/flask.svg',
            'business': '/media/img/icons/nouns/briefcase.svg',
            'sports': '/media/img/icons/nouns/trophy.svg',
            'entertainment': '/media/img/icons/nouns/tv.svg',
            'gaming': '/media/img/icons/nouns/gaming.svg',
            'health': '/media/img/icons/nouns/heart.svg',
            'programming': '/media/img/icons/nouns/code.svg',
            'design': '/media/img/icons/nouns/brush.svg',
            'finance': '/media/img/icons/nouns/chart.svg',
            'politics': '/media/img/icons/nouns/building.svg',
            'music': '/media/img/icons/nouns/music.svg',
            'food': '/media/img/icons/nouns/food.svg',
            'travel': '/media/img/icons/nouns/plane.svg',
            'photography': '/media/img/icons/nouns/camera.svg',
            'environment': '/media/img/icons/nouns/world.svg',
            'ai': '/media/img/icons/nouns/ai.svg',
            'startups': '/media/img/icons/nouns/rocket.svg',
            'security': '/media/img/icons/nouns/shield.svg'
        };

        var key = title.toLowerCase().replace(/[^a-z]/g, '');
        return icon_map[key] || '/media/img/icons/nouns/folder-closed.svg';
    },

    get_placeholder_categories: function () {
        return [
            { id: 1, name: 'Technology', icon: '\ud83d\udcbb', feed_count: 245, slug: 'technology' },
            { id: 2, name: 'News', icon: '\ud83d\udcf0', feed_count: 189, slug: 'news' },
            { id: 3, name: 'Science', icon: '\ud83d\udd2c', feed_count: 156, slug: 'science' },
            { id: 4, name: 'Business', icon: '\ud83d\udcbc', feed_count: 134, slug: 'business' },
            { id: 5, name: 'Sports', icon: '\u26bd', feed_count: 178, slug: 'sports' },
            { id: 6, name: 'Entertainment', icon: '\ud83c\udfac', feed_count: 201, slug: 'entertainment' },
            { id: 7, name: 'Gaming', icon: '\ud83c\udfae', feed_count: 167, slug: 'gaming' },
            { id: 8, name: 'Health', icon: '\ud83c\udfe5', feed_count: 98, slug: 'health' },
            { id: 9, name: 'Programming', icon: '\ud83d\udc68\u200d\ud83d\udcbb', feed_count: 223, slug: 'programming' },
            { id: 10, name: 'Design', icon: '\ud83c\udfa8', feed_count: 87, slug: 'design' },
            { id: 11, name: 'Finance', icon: '\ud83d\udcc8', feed_count: 145, slug: 'finance' },
            { id: 12, name: 'Politics', icon: '\ud83c\udfdb\ufe0f', feed_count: 112, slug: 'politics' },
            { id: 13, name: 'Music', icon: '\ud83c\udfb5', feed_count: 134, slug: 'music' },
            { id: 14, name: 'Food', icon: '\ud83c\udf55', feed_count: 89, slug: 'food' },
            { id: 15, name: 'Travel', icon: '\u2708\ufe0f', feed_count: 76, slug: 'travel' },
            { id: 16, name: 'Photography', icon: '\ud83d\udcf7', feed_count: 65, slug: 'photography' },
            { id: 17, name: 'Environment', icon: '\ud83c\udf0d', feed_count: 54, slug: 'environment' },
            { id: 18, name: 'AI & ML', icon: '\ud83e\udd16', feed_count: 178, slug: 'ai-ml' },
            { id: 19, name: 'Startups', icon: '\ud83d\ude80', feed_count: 123, slug: 'startups' },
            { id: 20, name: 'Security', icon: '\ud83d\udd10', feed_count: 98, slug: 'security' }
        ];
    },

    render_categories_grid: function () {
        var $grid = this.$('.NB-add-site-categories-grid');
        var state = this.categories_state;

        $grid.empty();

        if (state.categories.length === 0) {
            $grid.html($.make('div', { className: 'NB-add-site-empty-state' },
                'No categories available. Categories will appear here once they are configured.'));
            return;
        }

        _.each(state.categories, function(category) {
            var $icon;
            if (category.icon && category.icon.indexOf('/') === 0) {
                // SVG icon path
                $icon = $.make('img', {
                    src: category.icon,
                    className: 'NB-add-site-category-icon-img'
                });
            } else {
                // Emoji fallback
                $icon = category.icon || '';
            }

            $grid.append($.make('div', {
                className: 'NB-add-site-category-card',
                'data-category-id': category.id,
                'data-category-slug': category.slug,
                'data-category-name': category.name
            }, [
                $.make('div', { className: 'NB-add-site-category-icon' }, $icon),
                $.make('div', { className: 'NB-add-site-category-info' }, [
                    $.make('div', { className: 'NB-add-site-category-name' }, category.name),
                    $.make('div', { className: 'NB-add-site-category-count' }, category.feed_count + ' feeds')
                ])
            ]));
        });
    },

    render_category_feeds: function () {
        var state = this.categories_state;
        var category = state.selected_category;

        // Build category icon element
        var $category_icon;
        if (category.icon && category.icon.indexOf('/') === 0) {
            $category_icon = $.make('img', {
                src: category.icon,
                className: 'NB-add-site-category-feeds-icon-img'
            });
        } else {
            $category_icon = $.make('span', { className: 'NB-add-site-category-feeds-icon' }, category.icon);
        }

        var $content = $.make('div', { className: 'NB-add-site-category-feeds-container' }, [
            $.make('div', { className: 'NB-add-site-category-feeds-header' }, [
                $.make('div', { className: 'NB-add-site-category-back' }, [
                    $.make('img', { src: '/media/img/icons/lucide/arrow-left.svg' }),
                    'Back to Categories'
                ]),
                $.make('div', { className: 'NB-add-site-category-feeds-title' }, [
                    $category_icon,
                    category.name
                ])
            ]),
            $.make('div', { className: 'NB-add-site-category-feeds-results' })
        ]);

        this.$('.NB-add-site-categories-tab').html($content);
        this.fetch_category_feeds(category);
    },

    fetch_category_feeds: function (category) {
        var self = this;
        var state = this.categories_state;

        this.$('.NB-add-site-category-feeds-results').html(this.make_loading_indicator());

        // Get feeds from cached data
        var feed_ids = category.feed_ids || [];
        var feeds = [];

        _.each(feed_ids, function(feed_id) {
            var feed = state.feeds_data[feed_id];
            if (feed) {
                feeds.push(feed);
            }
        });

        // Sort by subscriber count
        feeds = _.sortBy(feeds, function(f) {
            return -(f.num_subscribers || 0);
        });

        state.feeds = feeds;

        var $results = this.$('.NB-add-site-category-feeds-results');
        $results.empty();

        if (feeds.length === 0) {
            $results.html($.make('div', { className: 'NB-add-site-empty-state' },
                'No feeds found in this category.'));
            return;
        }

        // Render feed cards in a grid
        var $grid = $.make('div', { className: 'NB-add-site-results NB-add-site-results-' + self.view_mode });
        _.each(feeds, function(feed) {
            $grid.append(self.render_feed_card(feed));
        });
        $results.html($grid);
    },

    handle_category_click: function (e) {
        var $card = $(e.currentTarget);
        var category_name = $card.data('category-name');
        var category_id = $card.data('category-id');

        // Find the full category object
        var category = _.find(this.categories_state.categories, function(c) {
            return c.id === category_id || c.name === category_name;
        });

        if (category) {
            this.categories_state.selected_category = category;
            this.render_categories_tab();
        }
    },

    go_back_to_categories: function () {
        this.categories_state.selected_category = null;
        this.render_categories_tab();
    },

    handle_source_pill_click: function (e) {
        var tab_id = $(e.currentTarget).data('tab');
        if (tab_id) {
            this.active_tab = tab_id;
            this.render();
        }
    },

    handle_section_link_click: function (e) {
        var tab_id = $(e.currentTarget).data('tab');
        if (tab_id) {
            this.active_tab = tab_id;
            this.render();
        }
    },

    handle_filter_pill_click: function (e) {
        var $pill = $(e.currentTarget);
        var category = $pill.data('category');
        var source = $pill.data('source');

        // Handle different sources
        if (source === 'youtube') {
            this.youtube_state.selected_category = category;
            this.youtube_state.results = [];  // Clear to show popular
            this.render_youtube_tab();
        } else if (source === 'reddit') {
            this.reddit_state.selected_category = category;
            this.render_reddit_tab();
        } else if (source === 'podcasts') {
            this.podcasts_state.selected_category = category;
            this.render_podcasts_tab();
        }
    },

    // ==================
    // = Shared Methods =
    // ==================

    render_feed_card: function (feed, stories) {
        stories = stories || [];

        var $stories_preview = null;
        if (stories.length > 0) {
            $stories_preview = $.make('div', { className: 'NB-add-site-card-stories' },
                _.map(stories.slice(0, 3), function(story) {
                    return $.make('div', { className: 'NB-add-site-card-story' }, [
                        $.make('div', { className: 'NB-add-site-card-story-title' },
                            story.story_title || story.title || 'Untitled')
                    ]);
                })
            );
        }

        var meta_parts = [];
        if (feed.num_subscribers) meta_parts.push(feed.num_subscribers + ' subscribers');
        if (feed.average_stories_per_month) meta_parts.push(feed.average_stories_per_month + '/mo');

        return $.make('div', {
            className: 'NB-add-site-card',
            'data-feed-id': feed.id || feed.feed_id
        }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('img', {
                    src: feed.favicon_url || feed.favicon || '/media/img/icons/lucide/rss.svg',
                    className: 'NB-add-site-card-icon',
                    onerror: "this.src='/media/img/icons/lucide/rss.svg'"
                }),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' },
                        feed.feed_title || feed.title || 'Unknown Feed'),
                    $.make('div', { className: 'NB-add-site-card-meta' },
                        meta_parts.join(' \u2022 ')
                    )
                ])
            ]),
            feed.tagline ? $.make('div', { className: 'NB-add-site-card-desc' },
                this.truncate_text(feed.tagline, 150)
            ) : null,
            $stories_preview,
            $.make('div', { className: 'NB-add-site-card-actions' }, [
                this.make_folder_selector(feed),
                $.make('div', {
                    className: 'NB-add-site-card-subscribe NB-add-site-subscribe-btn',
                    'data-feed-id': feed.id || feed.feed_id,
                    'data-feed-url': feed.feed_address || feed.address
                }, 'Subscribe')
            ])
        ].filter(Boolean));
    },

    make_source_card: function (config) {
        var description_el = null;
        if (config.description) {
            description_el = $.make('div', { className: 'NB-add-site-card-desc' },
                this.truncate_text(config.description, 150)
            );
        }

        var icon_attrs = {
            src: config.icon,
            className: 'NB-add-site-card-icon'
        };
        if (config.fallback_icon) {
            icon_attrs.onerror = "this.src='" + config.fallback_icon + "'";
        }

        return $.make('div', { className: 'NB-add-site-card ' + config.card_class }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('img', icon_attrs),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' }, config.title),
                    $.make('div', { className: 'NB-add-site-card-meta' }, config.meta || '')
                ])
            ]),
            description_el,
            $.make('div', { className: 'NB-add-site-card-actions' }, [
                this.make_folder_selector(),
                $.make('div', {
                    className: 'NB-add-site-card-subscribe NB-add-site-subscribe-btn',
                    'data-feed-url': config.feed_url
                }, 'Subscribe')
            ])
        ].filter(Boolean));
    },

    make_folder_selector: function () {
        var folders = NEWSBLUR.utils.make_folders();
        var $select = $(folders).addClass('NB-add-site-folder-select');
        $select.append($.make('option', { value: '__new__' }, '+ New Folder...'));
        return $select;
    },

    make_loading_indicator: function () {
        return $.make('div', { className: 'NB-add-site-loading' }, [
            $.make('div', { className: 'NB-loading NB-active' })
        ]);
    },

    make_results_container: function () {
        return $.make('div', {
            className: 'NB-add-site-results NB-add-site-results-' + this.view_mode
        });
    },

    make_error_message: function (message) {
        return $.make('div', { className: 'NB-add-site-error' }, message);
    },

    make_error_with_icon: function (message) {
        return $.make('div', { className: 'NB-add-site-error' }, [
            $.make('div', { className: 'NB-add-site-error-icon' }, '\u26a0\ufe0f'),
            $.make('div', { className: 'NB-add-site-error-message' }, message)
        ]);
    },

    make_no_results_message: function (icon, title, desc) {
        return $.make('div', { className: 'NB-add-site-no-results' }, [
            $.make('div', { className: 'NB-add-site-no-results-icon' }, icon),
            $.make('div', { className: 'NB-add-site-no-results-title' }, title),
            $.make('div', { className: 'NB-add-site-no-results-desc' }, desc)
        ]);
    },

    truncate_text: function (text, max_length) {
        if (!text || text.length <= max_length) return text;
        return text.substring(0, max_length) + '...';
    },

    is_url: function (str) {
        if (!str) return false;
        return /^(https?:\/\/|www\.)/i.test(str) ||
               /\.(com|org|net|io|co|me|tv|blog|news|rss|xml|feed)(\/.*)?\s*$/i.test(str);
    },

    render_url_subscribe_card: function (url) {
        var normalized_url = url;
        if (!/^https?:\/\//i.test(url)) {
            normalized_url = 'https://' + url.replace(/^www\./i, '');
        }

        var domain = normalized_url.replace(/^https?:\/\//i, '').split('/')[0];

        return $.make('div', { className: 'NB-add-site-url-subscribe' }, [
            $.make('div', { className: 'NB-add-site-url-card NB-add-site-card' }, [
                $.make('div', { className: 'NB-add-site-card-header' }, [
                    $.make('div', { className: 'NB-add-site-card-icon NB-add-site-url-icon' }, [
                        $.make('img', { src: '/media/img/icons/nouns/add.svg' })
                    ]),
                    $.make('div', { className: 'NB-add-site-card-info' }, [
                        $.make('div', { className: 'NB-add-site-card-title' }, 'Subscribe to ' + domain),
                        $.make('div', { className: 'NB-add-site-card-meta' }, normalized_url)
                    ])
                ]),
                $.make('div', { className: 'NB-add-site-card-desc' },
                    'NewsBlur will automatically find the RSS feed for this site.'),
                $.make('div', { className: 'NB-add-site-card-actions' }, [
                    this.make_folder_selector(),
                    $.make('div', {
                        className: 'NB-add-site-card-subscribe NB-add-site-subscribe-btn',
                        'data-feed-url': normalized_url
                    }, 'Subscribe')
                ])
            ])
        ]);
    },

    // ===========
    // = Actions =
    // ===========

    switch_tab: function (e) {
        var $tab = $(e.currentTarget);
        var tab_id = $tab.data('tab');

        if (tab_id === this.active_tab) return;

        this.active_tab = tab_id;

        this.$('.NB-add-site-tab').removeClass('NB-active');
        $tab.addClass('NB-active');

        this.$('.NB-add-site-tab-pane').removeClass('NB-active');
        this.$('.NB-add-site-' + tab_id + '-tab').addClass('NB-active');

        this.render_active_tab();
    },

    toggle_view_mode: function (e) {
        var $toggle = $(e.currentTarget);
        var mode = $toggle.data('mode');

        if (mode === this.view_mode) return;

        this.view_mode = mode;

        this.$('.NB-add-site-view-toggle').removeClass('NB-active');
        $toggle.addClass('NB-active');

        this.$('.NB-add-site-results')
            .removeClass('NB-add-site-results-grid NB-add-site-results-list')
            .addClass('NB-add-site-results-' + mode);

        // Re-render the search tab to update trending feeds view
        if (this.active_tab === 'search' && !this.search_query) {
            this.render_search_tab();
        }
    },

    handle_search_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        this.search_query = query;

        this.$('.NB-add-site-search-clear').toggleClass('NB-hidden', query.length === 0);
        this.search_debounced();
    },

    handle_search_keypress: function (e) {
        if (e.which === 13) {
            this.perform_search();
        }
    },

    clear_search: function () {
        this.$('.NB-add-site-search-input').val('');
        this.$('.NB-add-site-search-clear').addClass('NB-hidden');
        this.search_query = '';
        this.search_state.results = [];
        this.render_search_tab();
    },

    perform_search: function () {
        var self = this;
        var query = this.search_query;

        if (!query || query.length < 2) {
            this.search_state.results = [];
            this.render_search_tab({ results_only: true });
            return;
        }

        // Increment search version to track this request
        this.search_version++;
        var current_version = this.search_version;

        this.search_state.is_loading = true;
        this.search_state.results = [];
        this.render_search_tab({ results_only: true });

        this.model.make_request('/discover/autocomplete', {
            query: query,
            format: 'full',
            v: 2
        }, function (data) {
            // Ignore stale responses from previous searches
            if (current_version !== self.search_version) {
                return;
            }
            self.search_state.is_loading = false;
            if (data && _.isArray(data)) {
                self.search_state.results = data;
            } else if (data && data.feeds) {
                self.search_state.results = data.feeds;
            }
            self.render_search_tab({ results_only: true });
        }, function () {
            // Ignore stale error responses
            if (current_version !== self.search_version) {
                return;
            }
            self.search_state.is_loading = false;
            self.render_search_tab({ results_only: true });
        }, { request_type: 'GET' });
    },

    subscribe_to_feed: function (e) {
        var $btn = $(e.currentTarget);
        var $card = $btn.closest('.NB-add-site-card');
        var $folder_select = $card.find('.NB-add-site-folder-select');
        var feed_url = $btn.data('feed-url');
        var folder = $folder_select.val() || '';

        if (!feed_url) {
            console.log('No feed URL found');
            return;
        }

        $btn.addClass('NB-loading').text('Subscribing...');

        NEWSBLUR.assets.save_add_url(feed_url, folder, function (data) {
            if (data.code > 0 || data.feed) {
                $card.addClass('NB-subscribed');

                // Refresh feed list without opening the feed
                NEWSBLUR.assets.load_feeds();

                // Convert button to "Open Site" with feed ID stored for later
                $btn.removeClass('NB-loading NB-add-site-subscribe-btn')
                    .addClass('NB-add-site-open-btn')
                    .text('Open Site')
                    .data('feed-id', data.feed ? data.feed.id : null);
            } else {
                $btn.removeClass('NB-loading').addClass('NB-error').text('Error');
                console.log('Subscribe error:', data.message);
                setTimeout(function () {
                    $btn.removeClass('NB-error').text('Subscribe');
                }, 2000);
            }
        });
    },

    open_subscribed_feed: function (e) {
        var $btn = $(e.currentTarget);
        var feed_id = $btn.data('feed-id');

        if (feed_id) {
            NEWSBLUR.reader.open_feed(feed_id);
        }
    },

    handle_folder_change: function (e) {
        var $select = $(e.currentTarget);
        var value = $select.val();

        if (value === '__new__') {
            var folder_name = prompt('Enter new folder name:');
            if (folder_name && folder_name.trim()) {
                NEWSBLUR.assets.save_add_folder(folder_name.trim(), '', function (data) {
                    if (data && !data.message) {
                        var folders = NEWSBLUR.utils.make_folders();
                        var $new_select = $(folders).addClass('NB-add-site-folder-select');
                        $new_select.append($.make('option', { value: '__new__' }, '+ New Folder...'));
                        $new_select.val(folder_name.trim());
                        $select.replaceWith($new_select);
                    }
                });
            } else {
                $select.val('');
            }
        }
    },

    // =========================
    // = Source Search Actions =
    // =========================

    handle_youtube_search_keypress: function (e) {
        if (e.which === 13) this.perform_youtube_search();
    },

    handle_reddit_search_keypress: function (e) {
        if (e.which === 13) this.perform_reddit_search();
    },

    handle_newsletter_search_keypress: function (e) {
        if (e.which === 13) this.perform_newsletter_convert();
    },

    handle_podcast_search_keypress: function (e) {
        if (e.which === 13) this.perform_podcast_search();
    },

    perform_source_search: function (config) {
        var self = this;
        var query = this.$('.' + config.input_class).val().trim();
        var state = this[config.state_key];

        if (!query || query.length < config.min_length) {
            return;
        }

        state.query = query;
        state.is_loading = true;
        state.results = [];

        var $results = this.$('.' + config.results_selector);
        $results.html(this.make_loading_indicator());

        this.model.make_request(config.endpoint, config.params(query), function (data) {
            state.is_loading = false;
            if (data && data.code === 1 && data.results) {
                state.results = data.results;
                config.render_results.call(self);
            } else {
                var message = (data && data.message) ? data.message : 'Search failed';
                $results.html(self.make_error_with_icon(message));
            }
        }, function () {
            state.is_loading = false;
            $results.html(self.make_error_message(config.error_message));
        }, { request_type: 'GET' });
    },

    perform_youtube_search: function () {
        this.perform_source_search({
            input_class: 'NB-add-site-youtube-search',
            state_key: 'youtube_state',
            results_selector: 'NB-add-site-youtube-tab .NB-add-site-source-results',
            endpoint: '/discover/youtube/search',
            min_length: 2,
            params: function(query) {
                return { query: query, type: 'channel', limit: 15 };
            },
            render_results: this.render_youtube_results,
            error_message: 'Failed to search YouTube'
        });
    },

    perform_reddit_search: function () {
        this.perform_source_search({
            input_class: 'NB-add-site-reddit-search',
            state_key: 'reddit_state',
            results_selector: 'NB-add-site-reddit-tab .NB-add-site-source-results',
            endpoint: '/discover/reddit/search',
            min_length: 2,
            params: function(query) {
                return { query: query, limit: 15 };
            },
            render_results: this.render_reddit_results,
            error_message: 'Failed to search Reddit'
        });
    },

    perform_podcast_search: function () {
        this.perform_source_search({
            input_class: 'NB-add-site-podcasts-search',
            state_key: 'podcasts_state',
            results_selector: 'NB-add-site-podcasts-tab .NB-add-site-source-results',
            endpoint: '/discover/podcast/search',
            min_length: 2,
            params: function(query) {
                return { query: query, limit: 20 };
            },
            render_results: this.render_podcast_results,
            error_message: 'Failed to search podcasts'
        });
    },

    perform_newsletter_convert: function () {
        var self = this;
        var url = this.$('.NB-add-site-newsletters-search').val().trim();
        var state = this.newsletters_state;

        if (!url || url.length < 3) {
            return;
        }

        if (!url.match(/^https?:\/\//i)) {
            url = 'https://' + url;
        }

        state.is_loading = true;
        state.results = [];

        var $results = this.$('.NB-add-site-newsletters-tab .NB-add-site-source-results');
        $results.html(this.make_loading_indicator());

        this.model.make_request('/discover/newsletter/convert', {
            url: url
        }, function (data) {
            state.is_loading = false;
            if (data && data.code === 1 && data.feed_url) {
                state.results = [{
                    feed_url: data.feed_url,
                    platform: data.platform,
                    title: data.title,
                    original_url: data.original_url
                }];
                self.render_newsletter_results();
            } else {
                var message = (data && data.message) ? data.message : 'Could not find RSS feed for this URL';
                $results.html(self.make_error_with_icon(message));
            }
        }, function () {
            state.is_loading = false;
            $results.html(self.make_error_message('Failed to convert newsletter URL'));
        }, { request_type: 'GET' });
    },

    // ==========================
    // = Google News Actions =
    // ==========================

    handle_google_news_topic_click: function (e) {
        var $topic = $(e.currentTarget);
        var topic_id = $topic.data('topic-id');
        var topic_name = $topic.data('topic-name');
        var state = this.google_news_state;

        // Toggle selection
        if ($topic.hasClass('NB-selected')) {
            // Deselect
            $topic.removeClass('NB-selected');
            state.selected_topic = null;
            state.query = '';
            this.$('.NB-add-site-google-news-search-input').val('');
        } else {
            // Select this topic
            this.$('.NB-add-site-google-news-topic.NB-selected').removeClass('NB-selected');
            $topic.addClass('NB-selected');
            state.selected_topic = topic_id;
            state.query = topic_name;
            this.$('.NB-add-site-google-news-search-input').val(topic_name);
        }

        // Reset subscription state when changing topic
        state.is_subscribed = false;
        state.feed_url = null;
        state.feed_id = null;
        this.update_google_news_subscribe_button();
    },

    handle_google_news_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        var state = this.google_news_state;

        state.query = query;
        // Clear topic selection when user types custom query
        if (state.selected_topic) {
            var topic = _.find(this.GOOGLE_NEWS_TOPICS, function(t) { return t.id === state.selected_topic; });
            if (!topic || topic.name.toLowerCase() !== query.toLowerCase()) {
                state.selected_topic = null;
                this.$('.NB-add-site-google-news-topic.NB-selected').removeClass('NB-selected');
            }
        }

        // Reset subscription state when query changes
        state.is_subscribed = false;
        state.feed_url = null;
        state.feed_id = null;
        this.update_google_news_subscribe_button();
    },

    handle_google_news_search_keypress: function (e) {
        if (e.which === 13) {
            this.handle_google_news_subscribe();
        }
    },

    update_google_news_subscribe_button: function () {
        var state = this.google_news_state;
        var $btn = this.$('.NB-add-site-google-news-subscribe-btn');

        $btn.removeClass('NB-loading NB-subscribed NB-disabled');

        if (state.is_subscribed) {
            $btn.addClass('NB-subscribed').text('Open Site');
        } else if (state.is_loading) {
            $btn.addClass('NB-loading NB-disabled').text('Subscribing...');
        } else {
            $btn.text('Subscribe');
        }
    },

    handle_google_news_subscribe: function () {
        var self = this;
        var state = this.google_news_state;
        var $btn = this.$('.NB-add-site-google-news-subscribe-btn');

        // If already subscribed, open the feed
        if (state.is_subscribed && state.feed_id) {
            NEWSBLUR.reader.open_feed(state.feed_id);
            return;
        }

        var query = this.$('.NB-add-site-google-news-search-input').val().trim();
        var language = this.$('.NB-add-site-google-news-language').val();
        var folder = this.$('.NB-add-site-google-news-subscribe-row .NB-add-site-folder-select').val() || '';

        if (!query || query.length < 2) {
            return;
        }

        state.is_loading = true;
        state.language = language;
        this.update_google_news_subscribe_button();

        // Build request params
        var params = {
            language: language,
            region: 'US'
        };

        // Use topic ID if a quick topic is selected, otherwise use query
        if (state.selected_topic) {
            params.topic = state.selected_topic;
        } else {
            params.query = query;
        }

        // First get the feed URL from Google News
        this.model.make_request('/discover/google-news/feed', params, function (data) {
            if (data && data.code === 1 && data.feed_url) {
                state.feed_url = data.feed_url;

                // Now subscribe to the feed
                NEWSBLUR.assets.save_add_url(data.feed_url, folder, function (sub_data) {
                    state.is_loading = false;

                    if (sub_data.code > 0 || sub_data.feed) {
                        state.is_subscribed = true;
                        state.feed_id = sub_data.feed ? sub_data.feed.id : null;

                        // Refresh feed list
                        NEWSBLUR.assets.load_feeds();

                        self.update_google_news_subscribe_button();
                    } else {
                        self.show_google_news_error(sub_data.message || 'Failed to subscribe');
                    }
                });
            } else {
                state.is_loading = false;
                var message = (data && data.message) ? data.message : 'Failed to create feed';
                self.show_google_news_error(message);
            }
        }, function () {
            state.is_loading = false;
            self.show_google_news_error('Failed to create Google News feed');
        }, { request_type: 'GET' });
    },

    show_google_news_error: function (message) {
        var $btn = this.$('.NB-add-site-google-news-subscribe-btn');
        $btn.removeClass('NB-loading NB-disabled').addClass('NB-error').text('Error');

        setTimeout(function () {
            $btn.removeClass('NB-error').text('Subscribe');
        }, 2000);
    }

});
