NEWSBLUR.Views.AddSiteView = Backbone.View.extend({

    className: "NB-add-site-view",

    events: {
        "click .NB-add-site-tab": "switch_tab",
        "click .NB-add-site-view-toggle": "toggle_view_mode",
        "input .NB-add-site-search-input": "handle_search_input",
        "keypress .NB-add-site-search-input": "handle_search_keypress",
        "click .NB-add-site-search-clear": "clear_search",
        "click .NB-add-site-subscribe-btn": "subscribe_to_feed",
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
        // Google News events (in Search tab)
        "click .NB-add-site-google-news-topic": "handle_google_news_topic_click",
        "click .NB-add-site-google-news-search-btn": "perform_google_news_search",
        "keypress .NB-add-site-google-news-search-input": "handle_google_news_search_keypress"
    },

    TABS: [
        { id: 'search', label: 'Search', icon: '/media/img/icons/nouns/search.svg' },
        { id: 'youtube', label: 'YouTube', icon: '/media/img/reader/youtube_play.png' },
        { id: 'reddit', label: 'Reddit', icon: '/media/img/reader/reddit.png' },
        { id: 'newsletters', label: 'Newsletters', icon: '/media/img/reader/newsletters_folder.png' },
        { id: 'podcasts', label: 'Podcasts', icon: '/media/img/icons/nouns/activity.svg' },
        { id: 'trending', label: 'Trending', icon: '/media/img/icons/nouns/all-stories.svg' },
        { id: 'categories', label: 'Categories', icon: '/media/img/icons/nouns/folder-closed.svg' }
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

    initialize: function (options) {
        this.options = options || {};
        this.model = NEWSBLUR.assets;
        this.active_tab = 'search';
        this.view_mode = 'grid';
        this.search_query = '';
        this.search_debounced = _.debounce(_.bind(this.perform_search, this), 300);

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

        this.search_state = _.extend({}, default_search_state);
        this.youtube_state = _.extend({}, default_search_state);
        this.reddit_state = _.extend({}, default_search_state);
        this.newsletters_state = _.extend({}, default_search_state);
        this.podcasts_state = _.extend({}, default_search_state);

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
            is_loading: false
        };

        this.google_news_state = {
            is_loading: false,
            result: null
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
            $.make('div', { className: 'NB-add-site-search-container' }, [
                $.make('div', { className: 'NB-add-site-search-wrapper' }, [
                    $.make('img', {
                        src: '/media/img/icons/lucide/search.svg',
                        className: 'NB-add-site-search-icon'
                    }),
                    $.make('input', {
                        type: 'text',
                        className: 'NB-add-site-search-input',
                        placeholder: 'Search for feeds, paste a URL, or explore by category...'
                    }),
                    $.make('div', { className: 'NB-add-site-search-clear NB-hidden' }, '\u00d7')
                ]),
                $.make('div', { className: 'NB-add-site-view-toggles' }, [
                    this.make_view_toggle('grid', 'Grid view', '/media/img/icons/nouns/layout-grid.svg'),
                    this.make_view_toggle('list', 'List view', '/media/img/icons/nouns/layout-list.svg')
                ])
            ]),
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
            )
        ]);
    },

    make_view_toggle: function (mode, title, icon) {
        return $.make('div', {
            className: 'NB-add-site-view-toggle' + (this.view_mode === mode ? ' NB-active' : ''),
            'data-mode': mode,
            title: title
        }, [
            $.make('img', { src: icon })
        ]);
    },

    render_active_tab: function () {
        var tab_renderers = {
            'search': 'render_search_tab',
            'youtube': 'render_youtube_tab',
            'reddit': 'render_reddit_tab',
            'newsletters': 'render_newsletters_tab',
            'podcasts': 'render_podcasts_tab',
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

    render_search_tab: function () {
        var $tab = this.$('.NB-add-site-search-tab');
        var state = this.search_state;

        if (state.is_loading && state.results.length === 0) {
            $tab.html(this.make_loading_indicator());
            return;
        }

        if (state.results.length === 0 && !this.search_query) {
            $tab.html(this.render_search_empty_state());
            return;
        }

        if (state.results.length === 0 && this.search_query) {
            if (this.is_url(this.search_query)) {
                $tab.html(this.render_url_subscribe_card(this.search_query));
            } else {
                $tab.html(this.make_no_results_message(
                    '\ud83d\udd0d',
                    'No feeds found',
                    'Try a different search term or paste a URL directly.'
                ));
            }
            return;
        }

        var $results = this.make_results_container();
        _.each(state.results, function(feed) {
            $results.append(this.render_feed_card(feed));
        }, this);

        if (state.is_loading) {
            $results.append(this.make_loading_indicator());
        }

        $tab.html($results);
    },

    render_search_empty_state: function () {
        return $.make('div', { className: 'NB-add-site-empty-state' }, [
            $.make('div', { className: 'NB-add-site-empty-icon' }, [
                $.make('img', { src: '/media/img/icons/lucide/rss.svg' })
            ]),
            $.make('div', { className: 'NB-add-site-empty-title' }, 'Subscribe to RSS Feeds'),
            $.make('div', { className: 'NB-add-site-empty-desc' },
                'Search for sites by name, paste a URL, or explore trending feeds and categories below.'),
            $.make('div', { className: 'NB-add-site-empty-tips' }, [
                this.make_tip('\ud83d\udd17', 'Paste any website URL to find its RSS feed'),
                this.make_tip('\ud83d\udcfa', 'Use the YouTube tab to subscribe to channels'),
                this.make_tip('\ud83c\udff7\ufe0f', 'Browse Categories to discover new content')
            ]),
            this.render_google_news_section()
        ]);
    },

    make_tip: function (icon, text) {
        return $.make('div', { className: 'NB-add-site-tip' }, [
            $.make('span', { className: 'NB-add-site-tip-icon' }, icon),
            $.make('span', text)
        ]);
    },

    render_google_news_section: function () {
        return $.make('div', { className: 'NB-add-site-google-news-section' }, [
            $.make('div', { className: 'NB-add-site-google-news-header' }, [
                $.make('img', {
                    src: '/media/img/icons/nouns/world.svg',
                    className: 'NB-add-site-google-news-logo'
                }),
                $.make('span', { className: 'NB-add-site-google-news-title' }, 'Google News Feeds')
            ]),
            $.make('div', { className: 'NB-add-site-google-news-desc' },
                'Subscribe to Google News topics or create custom news feeds based on keywords.'),
            $.make('div', { className: 'NB-add-site-google-news-topics' },
                _.map(this.GOOGLE_NEWS_TOPICS, function (topic) {
                    return $.make('div', {
                        className: 'NB-add-site-google-news-topic',
                        'data-topic-id': topic.id,
                        'data-topic-name': topic.name
                    }, [
                        $.make('span', { className: 'NB-add-site-topic-icon' }, topic.icon),
                        $.make('span', { className: 'NB-add-site-topic-name' }, topic.name)
                    ]);
                })
            ),
            $.make('div', { className: 'NB-add-site-google-news-custom' }, [
                $.make('div', { className: 'NB-add-site-google-news-custom-title' }, 'Custom News Feed'),
                $.make('div', { className: 'NB-add-site-google-news-search-row' }, [
                    $.make('input', {
                        type: 'text',
                        className: 'NB-add-site-google-news-search-input',
                        placeholder: 'Enter keywords (e.g., "climate change", "AI startups")...'
                    }),
                    $.make('select', { className: 'NB-add-site-google-news-language' }, [
                        $.make('option', { value: 'en' }, 'English'),
                        $.make('option', { value: 'es' }, 'Spanish'),
                        $.make('option', { value: 'fr' }, 'French'),
                        $.make('option', { value: 'de' }, 'German'),
                        $.make('option', { value: 'pt' }, 'Portuguese'),
                        $.make('option', { value: 'ja' }, 'Japanese'),
                        $.make('option', { value: 'zh' }, 'Chinese')
                    ]),
                    $.make('div', { className: 'NB-add-site-google-news-search-btn' }, 'Create Feed')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-google-news-result' })
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
        this.render_source_tab({
            tab_id: 'youtube',
            state_key: 'youtube_state',
            icon: '/media/img/reader/youtube.png',
            title: 'YouTube Channels',
            description: 'Subscribe to YouTube channels and playlists as RSS feeds.',
            placeholder: 'Search YouTube channels...',
            button_text: 'Search',
            render_results: this.render_youtube_results
        });
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

    render_youtube_card: function (channel) {
        var meta_parts = [channel.subscriber_count || ''];
        if (channel.video_count) {
            meta_parts.push(channel.video_count + ' videos');
        }

        return this.make_source_card({
            card_class: 'NB-add-site-youtube-card',
            icon: channel.thumbnail || '/media/img/icons/lucide/youtube.svg',
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
        this.render_source_tab({
            tab_id: 'reddit',
            state_key: 'reddit_state',
            icon: '/media/img/reader/reddit.png',
            title: 'Reddit Subreddits',
            description: 'Subscribe to subreddits as RSS feeds.',
            placeholder: 'Search subreddits (e.g., programming, news, gaming)...',
            button_text: 'Search',
            render_results: this.render_reddit_results
        });
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
        var platform_hints = $.make('div', { className: 'NB-add-site-platform-hints' }, [
            this.make_platform_hint('Substack:', 'newsletter.substack.com'),
            this.make_platform_hint('Medium:', 'medium.com/@username'),
            this.make_platform_hint('Buttondown:', 'buttondown.email/username'),
            this.make_platform_hint('Ghost:', 'newsletter.ghost.io')
        ]);

        this.render_source_tab({
            tab_id: 'newsletters',
            state_key: 'newsletters_state',
            icon: '/media/img/reader/newsletters_folder.png',
            title: 'Newsletters & Substack',
            description: 'Subscribe to newsletters from Substack, Medium, Ghost, Buttondown, and more.',
            placeholder: 'Paste newsletter URL (e.g., example.substack.com)...',
            button_text: 'Find Feed',
            render_results: this.render_newsletter_results,
            extra_content: [platform_hints]
        });
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

    render_newsletter_card: function (newsletter) {
        var platform_label = this.NEWSLETTER_PLATFORMS[newsletter.platform] || 'Newsletter';
        var title = newsletter.title || this.extract_domain(newsletter.original_url);

        return $.make('div', { className: 'NB-add-site-card NB-add-site-newsletter-card' }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('div', {
                    className: 'NB-add-site-card-icon NB-add-site-platform-icon NB-platform-' + newsletter.platform
                }, [
                    $.make('img', { src: '/media/img/reader/newsletters_folder.png' })
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
        this.render_source_tab({
            tab_id: 'podcasts',
            state_key: 'podcasts_state',
            icon: '/media/img/icons/lucide/podcast.svg',
            title: 'Podcasts',
            description: 'Subscribe to podcasts via RSS. Search by name or paste a feed URL.',
            placeholder: 'Search podcasts (e.g., "technology", "true crime", "comedy")...',
            button_text: 'Search',
            render_results: this.render_podcast_results
        });
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

    // ================
    // = Trending Tab =
    // ================

    render_trending_tab: function () {
        var state = this.trending_state;

        var $content = $.make('div', { className: 'NB-add-site-trending-container' }, [
            $.make('div', { className: 'NB-add-site-trending-header' }, [
                $.make('div', { className: 'NB-add-site-trending-title' }, [
                    $.make('img', { src: '/media/img/icons/nouns/pulse.svg', className: 'NB-add-site-trending-icon' }),
                    'Trending Sites'
                ]),
                $.make('div', { className: 'NB-add-site-trending-time-selector' }, [
                    $.make('select', { className: 'NB-add-site-trending-days' }, [
                        $.make('option', { value: '1' }, 'Today'),
                        $.make('option', { value: '7', selected: state.days === 7 }, 'This Week'),
                        $.make('option', { value: '30' }, 'This Month')
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-add-site-trending-results' })
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

        this.model.make_request('/rss_feeds/trending_sites', {
            page: state.page,
            days: state.days
        }, function (data) {
            state.is_loading = false;
            if (data && data.feeds) {
                state.feeds = state.feeds.concat(data.feeds);
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

    // ==================
    // = Categories Tab =
    // ==================

    render_categories_tab: function () {
        var state = this.categories_state;

        if (state.selected_category) {
            this.render_category_feeds();
            return;
        }

        var $content = $.make('div', { className: 'NB-add-site-categories-container' }, [
            $.make('div', { className: 'NB-add-site-categories-header' }, [
                $.make('div', { className: 'NB-add-site-categories-title' }, 'Browse by Category'),
                $.make('div', { className: 'NB-add-site-categories-desc' },
                    'Discover feeds organized by topic and interest.')
            ]),
            $.make('div', { className: 'NB-add-site-categories-grid' })
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

        // Placeholder categories until backend is implemented
        setTimeout(function() {
            state.is_loading = false;
            state.categories = self.get_placeholder_categories();
            self.render_categories_grid();
        }, 500);
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

        _.each(state.categories, function(category) {
            $grid.append($.make('div', {
                className: 'NB-add-site-category-card',
                'data-category-id': category.id,
                'data-category-slug': category.slug
            }, [
                $.make('div', { className: 'NB-add-site-category-icon' }, category.icon),
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

        var $content = $.make('div', { className: 'NB-add-site-category-feeds-container' }, [
            $.make('div', { className: 'NB-add-site-category-feeds-header' }, [
                $.make('div', { className: 'NB-add-site-category-back' }, [
                    $.make('img', { src: '/media/img/icons/lucide/arrow-left.svg' }),
                    'Back to Categories'
                ]),
                $.make('div', { className: 'NB-add-site-category-feeds-title' }, [
                    $.make('span', { className: 'NB-add-site-category-feeds-icon' }, category.icon),
                    category.name
                ])
            ]),
            $.make('div', { className: 'NB-add-site-category-feeds-results' })
        ]);

        this.$('.NB-add-site-categories-tab').html($content);
        this.fetch_category_feeds(category);
    },

    fetch_category_feeds: function (_category) {
        var self = this;
        var state = this.categories_state;

        this.$('.NB-add-site-category-feeds-results').html(this.make_loading_indicator());

        // Placeholder - will be replaced with actual API call
        setTimeout(function() {
            state.feeds = [];
            self.$('.NB-add-site-category-feeds-results').html(
                $.make('div', { className: 'NB-add-site-coming-soon' },
                    'Category feeds coming soon! This feature is under development.')
            );
        }, 500);
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
            this.render_search_tab();
            return;
        }

        this.search_state.is_loading = true;
        this.search_state.results = [];
        this.render_search_tab();

        this.model.make_request('/rss_feeds/feed_autocomplete', {
            query: query,
            format: 'full',
            v: 2
        }, function (data) {
            self.search_state.is_loading = false;
            if (data && _.isArray(data)) {
                self.search_state.results = data;
            } else if (data && data.feeds) {
                self.search_state.results = data.feeds;
            }
            self.render_search_tab();
        }, function () {
            self.search_state.is_loading = false;
            self.render_search_tab();
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
                $btn.removeClass('NB-loading').addClass('NB-subscribed').text('Subscribed!');
                $card.addClass('NB-subscribed');

                setTimeout(function () {
                    NEWSBLUR.reader.force_feeds_refresh(function () {
                        NEWSBLUR.reader.resize_feed_list();
                    });
                }, 500);
            } else {
                $btn.removeClass('NB-loading').addClass('NB-error').text('Error');
                console.log('Subscribe error:', data.message);
                setTimeout(function () {
                    $btn.removeClass('NB-error').text('Subscribe');
                }, 2000);
            }
        });
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
            endpoint: '/rss_feeds/youtube/search',
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
            endpoint: '/rss_feeds/reddit/search',
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
            endpoint: '/rss_feeds/podcast/search',
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

        this.model.make_request('/rss_feeds/newsletter/convert', {
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
        var self = this;
        var $topic = $(e.currentTarget);
        var topic_id = $topic.data('topic-id');
        var topic_name = $topic.data('topic-name');
        var state = this.google_news_state;

        $topic.addClass('NB-loading');
        state.is_loading = true;

        this.model.make_request('/rss_feeds/google-news/feed', {
            topic: topic_id,
            language: 'en',
            region: 'US'
        }, function (data) {
            state.is_loading = false;
            $topic.removeClass('NB-loading');

            if (data && data.code === 1 && data.feed_url) {
                state.result = {
                    feed_url: data.feed_url,
                    title: data.title || 'Google News - ' + topic_name,
                    topic: topic_name
                };
                self.render_google_news_result();
            } else {
                var message = (data && data.message) ? data.message : 'Failed to create feed';
                self.$('.NB-add-site-google-news-result').html(self.make_error_with_icon(message));
            }
        }, function () {
            state.is_loading = false;
            $topic.removeClass('NB-loading');
            self.$('.NB-add-site-google-news-result').html(
                self.make_error_message('Failed to create Google News feed')
            );
        }, { request_type: 'GET' });
    },

    handle_google_news_search_keypress: function (e) {
        if (e.which === 13) {
            this.perform_google_news_search();
        }
    },

    perform_google_news_search: function () {
        var self = this;
        var query = this.$('.NB-add-site-google-news-search-input').val().trim();
        var language = this.$('.NB-add-site-google-news-language').val();
        var state = this.google_news_state;

        if (!query || query.length < 2) {
            return;
        }

        state.is_loading = true;
        this.$('.NB-add-site-google-news-search-btn').addClass('NB-loading').text('Creating...');
        this.$('.NB-add-site-google-news-result').html(this.make_loading_indicator());

        this.model.make_request('/rss_feeds/google-news/feed', {
            query: query,
            language: language,
            region: 'US'
        }, function (data) {
            state.is_loading = false;
            self.$('.NB-add-site-google-news-search-btn').removeClass('NB-loading').text('Create Feed');

            if (data && data.code === 1 && data.feed_url) {
                state.result = {
                    feed_url: data.feed_url,
                    title: data.title || 'Google News - ' + query,
                    query: query
                };
                self.render_google_news_result();
            } else {
                var message = (data && data.message) ? data.message : 'Failed to create feed';
                self.$('.NB-add-site-google-news-result').html(self.make_error_with_icon(message));
            }
        }, function () {
            state.is_loading = false;
            self.$('.NB-add-site-google-news-search-btn').removeClass('NB-loading').text('Create Feed');
            self.$('.NB-add-site-google-news-result').html(
                self.make_error_message('Failed to create Google News feed')
            );
        }, { request_type: 'GET' });
    },

    render_google_news_result: function () {
        var state = this.google_news_state;
        var result = state.result;

        if (!result) {
            this.$('.NB-add-site-google-news-result').empty();
            return;
        }

        var description = result.query
            ? 'Custom news feed for: "' + result.query + '"'
            : 'Google News feed for the ' + result.topic + ' topic';

        var $card = $.make('div', { className: 'NB-add-site-card NB-add-site-google-news-card' }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('div', { className: 'NB-add-site-card-icon NB-add-site-google-icon' }, [
                    $.make('img', { src: '/media/img/icons/nouns/world.svg' })
                ]),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' }, result.title),
                    $.make('div', { className: 'NB-add-site-card-meta' }, [
                        $.make('span', { className: 'NB-add-site-google-badge' }, 'Google News')
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-add-site-card-desc' }, description),
            $.make('div', { className: 'NB-add-site-card-url' }, result.feed_url),
            $.make('div', { className: 'NB-add-site-card-actions' }, [
                this.make_folder_selector(),
                $.make('div', {
                    className: 'NB-add-site-card-subscribe NB-add-site-subscribe-btn',
                    'data-feed-url': result.feed_url
                }, 'Subscribe')
            ])
        ]);

        this.$('.NB-add-site-google-news-result').html($card);
    }

});
