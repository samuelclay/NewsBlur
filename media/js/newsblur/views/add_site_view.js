NEWSBLUR.Views.AddSiteView = Backbone.View.extend({

    className: "NB-add-site-view",

    events: {
        "click .NB-add-site-tab": "switch_tab",
        "click .NB-add-site-tabs-overflow-button": "toggle_overflow_menu",
        "click .NB-add-site-tabs-overflow-item": "select_overflow_tab",
        "click .NB-add-site-view-toggle": "toggle_view_mode",
        "click .NB-add-site-style-button": "open_style_popover",
        "input .NB-add-site-search-input": "handle_search_input",
        "keypress .NB-add-site-search-input": "handle_search_keypress",
        "click .NB-add-site-search-tab .NB-add-site-search-clear": "clear_search",
        "click .NB-add-site-search-btn": "force_search",
        // Source tab search clear buttons
        "input .NB-add-site-tab-search-input": "handle_source_search_input",
        "click .NB-add-site-youtube-tab .NB-add-site-search-clear": "clear_youtube_search",
        "click .NB-add-site-reddit-tab .NB-add-site-search-clear": "clear_reddit_search",
        "click .NB-add-site-newsletters-tab .NB-add-site-search-clear": "clear_newsletter_search",
        "click .NB-add-site-podcasts-tab .NB-add-site-search-clear": "clear_podcast_search",
        "click .NB-add-site-try-btn": "try_feed",
        "click .NB-add-site-subscribe-btn": "subscribe_to_feed",
        "click .NB-add-site-open-btn": "open_subscribed_feed",
        "click .NB-add-site-stats-btn": "open_feed_stats",
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
        // Note: scroll events don't bubble, so infinite scroll is bound directly
        // in bind_scroll_handler() rather than via Backbone delegated events.
        // Discovery navigation events
        "click .NB-add-site-source-pill": "handle_source_pill_click",
        "click .NB-add-site-section-link": "handle_section_link_click",
        // Filter pill events
        "click .NB-add-site-filter-pill": "handle_filter_pill_click",
        // Two-level category/subcategory pill events
        "click .NB-add-site-cat-pill": "handle_filter_pill_click",
        "click .NB-add-site-subcat-pill": "handle_filter_pill_click",
        // Category pill events (from search tab)
        "click .NB-add-site-category-pill": "handle_category_pill_click"
    },

    TABS: [
        { id: 'search', label: 'Search', icon: '/media/img/icons/nouns/search.svg', mono: true },
        { id: 'popular', label: 'Popular', icon: '/media/img/icons/heroicons-solid/fire.svg', mono: true },
        { id: 'youtube', label: 'YouTube', icon: '/media/img/reader/youtube_play.png' },
        { id: 'reddit', label: 'Reddit', icon: '/media/img/reader/reddit.png' },
        { id: 'newsletters', label: 'Newsletters', icon: '/media/img/reader/newsletters_folder.png' },
        { id: 'podcasts', label: 'Podcasts', icon: '/media/img/icons/nouns/activity.svg', mono: true },
        { id: 'google-news', label: 'Google News', icon: '/media/img/icons/nouns/world.svg', mono: true }
    ],

    GOOGLE_NEWS_TOPICS: [
        { id: 'WORLD', name: 'World', icon: '/media/img/icons/heroicons-solid/globe-alt.svg' },
        { id: 'NATION', name: 'Nation', icon: '/media/img/icons/heroicons-solid/building-library.svg' },
        { id: 'BUSINESS', name: 'Business', icon: '/media/img/icons/heroicons-solid/briefcase.svg' },
        { id: 'TECHNOLOGY', name: 'Technology', icon: '/media/img/icons/heroicons-solid/cpu-chip.svg' },
        { id: 'ENTERTAINMENT', name: 'Entertainment', icon: '/media/img/icons/heroicons-solid/film.svg' },
        { id: 'SPORTS', name: 'Sports', icon: '/media/img/icons/heroicons-solid/trophy.svg' },
        { id: 'SCIENCE', name: 'Science', icon: '/media/img/icons/heroicons-solid/beaker.svg' },
        { id: 'HEALTH', name: 'Health', icon: '/media/img/icons/heroicons-solid/heart.svg' }
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

    SEARCH_CATEGORIES: [
        { id: 'all', name: 'All', icon: '/media/img/icons/heroicons-solid/squares-2x2.svg' },
        { id: 'tech', name: 'Tech', icon: '/media/img/icons/heroicons-solid/cpu-chip.svg' },
        { id: 'science', name: 'Science', icon: '/media/img/icons/heroicons-solid/beaker.svg' },
        { id: 'news', name: 'News', icon: '/media/img/icons/heroicons-solid/newspaper.svg' },
        { id: 'education', name: 'Education', icon: '/media/img/icons/heroicons-solid/academic-cap.svg' },
        { id: 'business', name: 'Business', icon: '/media/img/icons/heroicons-solid/briefcase.svg' },
        { id: 'entertainment', name: 'Entertainment', icon: '/media/img/icons/heroicons-solid/film.svg' },
        { id: 'gaming', name: 'Gaming', icon: '/media/img/icons/heroicons-solid/puzzle-piece.svg' },
        { id: 'programming', name: 'Programming', icon: '/media/img/icons/heroicons-solid/code-bracket.svg' },
        { id: 'finance', name: 'Finance', icon: '/media/img/icons/heroicons-solid/chart-bar.svg' },
        { id: 'sports', name: 'Sports', icon: '/media/img/icons/heroicons-solid/trophy.svg' },
        { id: 'culture', name: 'Culture', icon: '/media/img/icons/heroicons-solid/paint-brush.svg' },
        { id: 'health', name: 'Health', icon: '/media/img/icons/heroicons-solid/heart.svg' }
    ],

    YOUTUBE_CATEGORIES: [
        { id: 'all', name: 'All', icon: '/media/img/icons/heroicons-solid/squares-2x2.svg' },
        { id: 'tech', name: 'Tech', icon: '/media/img/icons/heroicons-solid/cpu-chip.svg' },
        { id: 'science', name: 'Science', icon: '/media/img/icons/heroicons-solid/beaker.svg' },
        { id: 'gaming', name: 'Gaming', icon: '/media/img/icons/heroicons-solid/puzzle-piece.svg' },
        { id: 'education', name: 'Education', icon: '/media/img/icons/heroicons-solid/academic-cap.svg' },
        { id: 'news', name: 'News', icon: '/media/img/icons/heroicons-solid/newspaper.svg' },
        { id: 'entertainment', name: 'Entertainment', icon: '/media/img/icons/heroicons-solid/film.svg' },
        { id: 'music', name: 'Music', icon: '/media/img/icons/heroicons-solid/musical-note.svg' }
    ],

    PODCAST_CATEGORIES: [
        { id: 'all', name: 'All', icon: '/media/img/icons/remix-fill/apps-fill.svg' },
        { id: 'news', name: 'News', icon: '/media/img/icons/remix-fill/newspaper-fill.svg' },
        { id: 'tech', name: 'Tech', icon: '/media/img/icons/remix-fill/computer-fill.svg' },
        { id: 'comedy', name: 'Comedy', icon: '/media/img/icons/remix-fill/emotion-laugh-fill.svg' },
        { id: 'truecrime', name: 'True Crime', icon: '/media/img/icons/remix-fill/spy-fill.svg' },
        { id: 'business', name: 'Business', icon: '/media/img/icons/remix-fill/briefcase-4-fill.svg' },
        { id: 'education', name: 'Education', icon: '/media/img/icons/remix-fill/graduation-cap-fill.svg' },
        { id: 'science', name: 'Science', icon: '/media/img/icons/remix-fill/flask-fill.svg' }
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

    NEWSLETTER_CATEGORIES: [
        { id: 'all', name: 'All', icon: '/media/img/icons/bootstrap-fill/grid-fill.svg' },
        { id: 'tech', name: 'Tech', icon: '/media/img/icons/bootstrap-fill/cpu-fill.svg' },
        { id: 'business', name: 'Business', icon: '/media/img/icons/bootstrap-fill/briefcase-fill.svg' },
        { id: 'finance', name: 'Finance', icon: '/media/img/icons/bootstrap-fill/bar-chart-line-fill.svg' },
        { id: 'programming', name: 'Programming', icon: '/media/img/icons/bootstrap-fill/terminal-fill.svg' },
        { id: 'ai', name: 'AI', icon: '/media/img/icons/bootstrap-fill/lightning-charge-fill.svg' },
        { id: 'science', name: 'Science', icon: '/media/img/icons/bootstrap-fill/flask-fill.svg' },
        { id: 'politics', name: 'Politics', icon: '/media/img/icons/bootstrap-fill/building-fill.svg' },
        { id: 'culture', name: 'Culture', icon: '/media/img/icons/bootstrap-fill/palette-fill.svg' },
        { id: 'design', name: 'Design', icon: '/media/img/icons/bootstrap-fill/brush-fill.svg' },
        { id: 'health', name: 'Health', icon: '/media/img/icons/bootstrap-fill/heart-pulse-fill.svg' },
        { id: 'media', name: 'Media', icon: '/media/img/icons/bootstrap-fill/megaphone-fill.svg' },
        { id: 'startup', name: 'Startup', icon: '/media/img/icons/bootstrap-fill/rocket-takeoff-fill.svg' }
    ],

    REDDIT_CATEGORIES: [
        { id: 'all', name: 'All', icon: '/media/img/icons/phosphor-fill/squares-four-fill.svg' },
        { id: 'news', name: 'News', icon: '/media/img/icons/phosphor-fill/newspaper-fill.svg' },
        { id: 'tech', name: 'Tech', icon: '/media/img/icons/phosphor-fill/desktop-fill.svg' },
        { id: 'gaming', name: 'Gaming', icon: '/media/img/icons/phosphor-fill/game-controller-fill.svg' },
        { id: 'entertainment', name: 'Entertainment', icon: '/media/img/icons/phosphor-fill/popcorn-fill.svg' },
        { id: 'sports', name: 'Sports', icon: '/media/img/icons/phosphor-fill/trophy-fill.svg' },
        { id: 'science', name: 'Science', icon: '/media/img/icons/phosphor-fill/flask-fill.svg' },
        { id: 'funny', name: 'Funny', icon: '/media/img/icons/phosphor-fill/smiley-fill.svg' },
        { id: 'programming', name: 'Programming', icon: '/media/img/icons/phosphor-fill/code-fill.svg' },
        { id: 'finance', name: 'Finance', icon: '/media/img/icons/phosphor-fill/chart-line-up-fill.svg' },
        { id: 'worldnews', name: 'World News', icon: '/media/img/icons/phosphor-fill/globe-fill.svg' },
        { id: 'politics', name: 'Politics', icon: '/media/img/icons/phosphor-fill/bank-fill.svg' },
        { id: 'health', name: 'Health', icon: '/media/img/icons/phosphor-fill/heart-fill.svg' },
        { id: 'food', name: 'Food', icon: '/media/img/icons/phosphor-fill/cooking-pot-fill.svg' },
        { id: 'diy', name: 'DIY', icon: '/media/img/icons/phosphor-fill/wrench-fill.svg' },
        { id: 'education', name: 'Education', icon: '/media/img/icons/phosphor-fill/graduation-cap-fill.svg' },
        { id: 'photography', name: 'Photography', icon: '/media/img/icons/phosphor-fill/camera-fill.svg' }
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
        this.view_mode = NEWSBLUR.assets.preference('add_site_view_mode') || 'grid';
        this.search_query = '';
        this.search_debounced = _.debounce(_.bind(this.perform_search, this), 300);
        this.search_version = 0;  // Track search version to cancel stale responses
        this.overflow_tabs = [];  // Tabs currently in overflow menu

        this.init_tab_states();
        this.render();

        // Set up resize handler for tab overflow
        this.resize_handler = _.debounce(_.bind(this.update_tab_overflow, this), 100);
        $(window).on('resize.add_site_view', this.resize_handler);

        // Initial overflow calculation after DOM is ready
        _.defer(_.bind(this.update_tab_overflow, this));
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
            trending_has_more: true,
            trending_is_loading: false,
            // Curated popular feeds for Search tab empty state
            curated_feeds: [],
            curated_feeds_loaded: false,
            curated_offset: 0,
            curated_has_more: false,
            curated_loading_more: false,
            curated_category: 'all'
        });
        var default_popular_state = {
            popular_feeds: [],
            popular_feeds_loaded: false,
            popular_feeds_collection: null,
            available_categories: [],
            grouped_categories: [],
            popular_offset: 0,
            popular_has_more: false,
            popular_loading_more: false
        };
        this.youtube_state = _.extend({}, default_search_state, default_popular_state, {
            selected_category: 'all',
            selected_subcategory: 'all'
        });
        this.reddit_state = _.extend({}, default_search_state, default_popular_state, {
            popular_subreddits: [],
            popular_loaded: false,
            selected_category: 'all',
            selected_subcategory: 'all'
        });
        this.newsletters_state = _.extend({}, default_search_state, default_popular_state, {
            selected_category: 'all',
            selected_subcategory: 'all',
            selected_platform: 'all'
        });
        this.podcasts_state = _.extend({}, default_search_state, default_popular_state, {
            selected_category: 'all',
            selected_subcategory: 'all'
        });
        this.popular_state = _.extend({}, default_popular_state, {
            selected_category: 'all',
            selected_subcategory: 'all'
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
                $.make('div', { className: 'NB-add-site-tabs-container' }, [
                    $.make('div', { className: 'NB-add-site-tabs' },
                        _.map(this.TABS, function(tab) {
                            return $.make('div', {
                                className: 'NB-add-site-tab' + (self.active_tab === tab.id ? ' NB-active' : ''),
                                'data-tab': tab.id
                            }, [
                                $.make('img', { src: tab.icon, className: 'NB-add-site-tab-icon' + (tab.mono ? ' NB-mono' : '') }),
                                $.make('span', { className: 'NB-add-site-tab-label' }, tab.label)
                            ]);
                        })
                    ),
                    $.make('div', { className: 'NB-add-site-tabs-overflow NB-hidden' }, [
                        $.make('div', { className: 'NB-add-site-tabs-overflow-button' }, [
                            $.make('span', 'More'),
                            $.make('span', { className: 'NB-add-site-tabs-overflow-arrow' }, '\u25BC')
                        ]),
                        $.make('div', { className: 'NB-add-site-tabs-overflow-menu NB-hidden' })
                    ])
                ]),
                $.make('div', { className: 'NB-add-site-controls' }, [
                    $.make('div', { className: 'NB-add-site-view-toggles' }, [
                        this.make_view_toggle('grid', 'Grid view', '/media/img/icons/nouns/layout-grid.svg'),
                        this.make_view_toggle('list', 'List view', '/media/img/icons/nouns/layout-list.svg')
                    ]),
                    $.make('div', {
                        className: 'NB-add-site-style-button',
                        title: 'Display options'
                    }, [
                        $.make('img', { src: '/media/img/icons/nouns/settings.svg' }),
                        $.make('span', { className: 'NB-add-site-style-label' }, 'Style')
                    ])
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

    get_stories_limit: function () {
        var limit = NEWSBLUR.assets.preference('add_site_stories_count');
        if (limit === undefined || limit === null) {
            return 3; // Default
        }
        return parseInt(limit, 10);
    },

    limit_stories: function (stories_collection) {
        var limit = this.get_stories_limit();
        if (limit === 0) {
            return new Backbone.Collection([]);
        }
        if (stories_collection && stories_collection.models) {
            return new Backbone.Collection(stories_collection.models.slice(0, limit));
        }
        return stories_collection;
    },

    sort_feeds: function (feeds) {
        var sort_order = NEWSBLUR.assets.preference('add_site_sort_order') || 'subscribers';

        return _.sortBy(feeds, function(feed) {
            if (sort_order === 'subscribers') {
                return -(feed.num_subscribers || 0);
            } else if (sort_order === 'stories') {
                return -(feed.average_stories_per_month || 0);
            } else if (sort_order === 'name') {
                return (feed.feed_title || feed.title || '').toLowerCase();
            }
            return 0;
        });
    },

    render_active_tab: function () {
        var tab_renderers = {
            'search': 'render_search_tab',
            'popular': 'render_popular_tab',
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
            // Sort results based on user preference before rendering
            var sorted_results = this.sort_feeds(state.results);

            // List view with stories
            if (this.view_mode === 'list' && sorted_results.length > 0 && sorted_results[0].stories) {
                var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
                var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
                var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });

                _.each(sorted_results, function(feed_data) {
                    // Create a TrendingFeed-like model for consistency
                    var feed_model = new NEWSBLUR.Models.TrendingFeed({
                        id: feed_data.id,
                        feed: feed_data,
                        stories: feed_data.stories || []
                    });

                    var stories_limit = this.get_stories_limit();
                    var $badge_content = [
                        new NEWSBLUR.Views.FeedBadge({
                            model: feed_model.get("feed"),
                            show_folders: true,
                            in_add_site_view: this,
                            load_feed_after_add: false
                        })
                    ];

                    if (stories_limit > 0) {
                        var $story_titles = $.make('div', { className: 'NB-story-titles' });
                        var limited_stories = this.limit_stories(feed_model.get("stories"));
                        var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                            el: $story_titles,
                            collection: limited_stories,
                            $story_titles: $story_titles,
                            override_layout: 'split',
                            pane_anchor: pane_anchor,
                            on_search_feed: feed_model,
                            in_add_site_view: this
                        });
                        $badge_content.push(story_titles_view.render().el);
                    }

                    var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
                    $list.append($badge);
                }, this);

                if (state.is_loading) {
                    $list.append(this.make_loading_indicator());
                }
                $content = $list;
            } else {
                // Grid view - render feed cards
                var $results = this.make_results_container();
                _.each(sorted_results, function(feed) {
                    $results.append(this.render_feed_card(feed));
                }, this);

                if (state.is_loading) {
                    $results.append(this.make_loading_indicator());
                }
                $content = $results;
            }
        }

        if (can_update_results_only) {
            // Only update results, preserving search input focus
            $existing_results.html($content);
            // Update spinner visibility
            $tab.find('.NB-add-site-search-spinner').toggleClass('NB-hidden', !state.is_loading);
        } else {
            // Full render needed
            var $search_bar = this.render_tab_search_bar({
                input_class: 'NB-add-site-search-input',
                placeholder: 'Search by name, keyword, or paste a URL...',
                value: this.search_query,
                is_loading: state.is_loading
            });

            $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
                $search_bar,
                $.make('div', { className: 'NB-add-site-tab-results' }, [$content])
            ]));

            // Bind scroll event for infinite scroll (needs direct binding since element is dynamic)
            this.bind_scroll_handler();
        }
    },

    bind_scroll_handler: function () {
        var self = this;
        // Bind to all tab results containers for infinite scroll
        var $results = this.$('.NB-add-site-tab-results');
        if ($results.length) {
            $results.off('scroll.infinite').on('scroll.infinite', function (e) {
                self.handle_tab_scroll(e);
            });
        }
    },

    render_tab_search_bar: function (config) {
        var is_loading = config.is_loading || false;
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
                    className: 'NB-add-site-search-spinner' + (is_loading ? '' : ' NB-hidden')
                }),
                $.make('div', {
                    className: 'NB-add-site-search-clear' + (config.value ? '' : ' NB-hidden')
                }, '\u00d7')
            ]),
            $.make('div', { className: 'NB-add-site-search-btn NB-add-site-tab-search-btn' }, 'Search')
        ]);
    },

    render_search_empty_state: function () {
        var self = this;
        var state = this.search_state;

        // Load trending feeds if not already loaded
        if (!state.trending_loaded && state.trending_feeds_collection.length === 0) {
            this.fetch_search_trending_feeds();
        }

        // Load curated popular feeds if not already loaded
        if (!state.curated_feeds_loaded && state.curated_feeds.length === 0) {
            this.fetch_search_curated_feeds();
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

        // Curated Popular Feeds Section
        var $curated_section = $.make('div', { className: 'NB-add-site-section NB-add-site-curated-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, [
                    $.make('img', { src: '/media/img/icons/nouns/all-stories.svg', className: 'NB-add-site-section-icon' }),
                    'Popular Feeds'
                ])
            ]),
            $.make('div', { className: 'NB-add-site-filter-pills NB-add-site-curated-pills' },
                _.map(this.SEARCH_CATEGORIES, function (cat) {
                    return $.make('div', {
                        className: 'NB-add-site-filter-pill' + (state.curated_category === cat.id ? ' NB-active' : ''),
                        'data-category': cat.id,
                        'data-source': 'search'
                    }, cat.icon ? [
                        $.make('img', { src: cat.icon, className: 'NB-add-site-filter-pill-icon' }),
                        $.make('span', cat.name)
                    ] : cat.name);
                })
            ),
            $.make('div', { className: 'NB-add-site-section-content NB-add-site-curated-content' })
        ]);

        var $curated_content = $curated_section.find('.NB-add-site-curated-content');
        if (state.curated_feeds.length > 0) {
            $curated_content.append(this.render_curated_feeds());
            if (state.curated_has_more) {
                $curated_content.append(this.make_load_more_button('search_curated'));
            }
        } else if (state.curated_feeds_loaded) {
            $curated_content.append(this.make_no_results_message(
                '',
                'No popular feeds available',
                'Check back later for curated feed recommendations.'
            ));
        } else {
            $curated_content.append(this.make_loading_indicator());
        }

        $container.append($curated_section);

        return $container;
    },

    render_trending_feeds: function () {
        var self = this;
        var state = this.search_state;
        var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');

        if (this.view_mode === 'grid') {
            // Grid view: Use same card layout as search results (no story previews)
            var $grid = this.make_results_container();
            state.trending_feeds_collection.each(function (trending_feed) {
                var feed = trending_feed.get("feed");
                // Convert Backbone model to plain object for render_feed_card
                var feed_data = feed.toJSON ? feed.toJSON() : feed;
                // Don't pass stories for grid view - only show feed info
                $grid.append(self.render_feed_card(feed_data));
            });
            return $grid;
        } else {
            // List view: Show feed badges with story titles (like TrendingSitesView)
            var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
            var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });
            var stories_limit = this.get_stories_limit();
            state.trending_feeds_collection.each(function (trending_feed) {
                var $badge_content = [
                    new NEWSBLUR.Views.FeedBadge({
                        model: trending_feed.get("feed"),
                        show_folders: true,
                        in_add_site_view: self,
                        load_feed_after_add: false
                    })
                ];

                if (stories_limit > 0) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var limited_stories = self.limit_stories(trending_feed.get("stories"));
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: limited_stories,
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        pane_anchor: pane_anchor,
                        on_trending_feed: trending_feed,
                        in_add_site_view: self
                    });
                    $badge_content.push(story_titles_view.render().el);
                }

                var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
                $list.append($badge);
            });
            return $list;
        }
    },

    fetch_search_trending_feeds: function (append) {
        var self = this;
        var state = this.search_state;

        if (state.trending_is_loading) return;
        state.trending_is_loading = true;

        state.trending_feeds_collection.fetch({
            data: { page: state.trending_page, days: state.trending_days },
            remove: !append,  // Don't remove existing models when appending
            success: function () {
                state.trending_loaded = true;
                state.trending_has_more = state.trending_feeds_collection.has_more;
                state.trending_is_loading = false;
                // Re-render if still on search tab with empty query
                if (self.active_tab === 'search' && !self.search_query) {
                    if (append) {
                        self.append_trending_feeds();
                    } else {
                        self.render_search_tab();
                    }
                }
            },
            error: function () {
                state.trending_loaded = true;
                state.trending_is_loading = false;
                // Re-render to show error state
                if (self.active_tab === 'search' && !self.search_query) {
                    self.render_search_tab();
                }
            }
        });
    },

    handle_tab_scroll: function (e) {
        var $target = $(e.currentTarget);
        var scrollTop = $target.scrollTop();
        var scrollHeight = $target[0].scrollHeight;
        var clientHeight = $target[0].clientHeight;

        // Check if scrolled near the bottom (within 200px)
        if (scrollTop + clientHeight >= scrollHeight - 200) {
            if (this.active_tab === 'search') {
                this.load_more_trending_feeds();
                if (!this.search_query) {
                    var state = this.search_state;
                    if (state.curated_has_more && !state.curated_loading_more) {
                        this.fetch_search_curated_feeds({ load_more: true });
                    }
                }
            } else {
                // Infinite scroll for Popular, YouTube, Reddit, Newsletters, Podcasts tabs
                var tab_to_type = {
                    'popular': 'rss',
                    'youtube': 'youtube',
                    'reddit': 'reddit',
                    'newsletters': 'newsletter',
                    'podcasts': 'podcast'
                };
                var feed_type = tab_to_type[this.active_tab];
                if (feed_type) {
                    this.load_more_popular_feeds(feed_type);
                }
            }
        }
    },

    load_more_trending_feeds: function () {
        var state = this.search_state;

        // Only load more if on search tab, has more pages, not loading, and no search query
        if (this.active_tab !== 'search') return;
        if (this.search_query) return;
        if (!state.trending_has_more) return;
        if (state.trending_is_loading) return;

        // Increment page and fetch
        state.trending_page += 1;
        this.fetch_search_trending_feeds(true);
    },

    append_trending_feeds: function () {
        var self = this;
        var state = this.search_state;
        var $container = this.$('.NB-add-site-trending-content');

        if (!$container.length) return;

        // Get the last page of feeds (they were added to the collection)
        var page_size = 10;  // Match backend page size
        var total_feeds = state.trending_feeds_collection.length;
        var start_index = total_feeds - page_size;
        if (start_index < 0) start_index = 0;

        var new_feeds = state.trending_feeds_collection.slice(start_index);
        var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');

        if (this.view_mode === 'grid') {
            var $grid = $container.find('.NB-add-site-results-container');
            if (!$grid.length) {
                $grid = this.make_results_container();
                $container.append($grid);
            }
            _.each(new_feeds, function (trending_feed) {
                var feed = trending_feed.get("feed");
                var feed_data = feed.toJSON ? feed.toJSON() : feed;
                $grid.append(self.render_feed_card(feed_data));
            });
        } else {
            var $list = $container.find('.NB-trending-feed-badges');
            if (!$list.length) {
                var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
                $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });
                $container.append($list);
            }
            var stories_limit = this.get_stories_limit();
            _.each(new_feeds, function (trending_feed) {
                var $badge_content = [
                    new NEWSBLUR.Views.FeedBadge({
                        model: trending_feed.get("feed"),
                        show_folders: true,
                        in_add_site_view: self,
                        load_feed_after_add: false
                    })
                ];

                if (stories_limit > 0) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var limited_stories = self.limit_stories(trending_feed.get("stories"));
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: limited_stories,
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        pane_anchor: pane_anchor,
                        on_trending_feed: trending_feed,
                        in_add_site_view: self
                    });
                    $badge_content.push(story_titles_view.render().el);
                }

                var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
                $list.append($badge);
            });
        }

        // Remove loading indicator if present
        $container.find('.NB-add-site-loading').remove();
        $container.find('.NB-add-site-skeleton-card').closest('.NB-add-site-results').remove();
    },

    // ========================================
    // = Search Tab: Curated Popular Feeds    =
    // ========================================

    fetch_search_curated_feeds: function (options) {
        var self = this;
        var state = this.search_state;
        options = options || {};

        var is_load_more = options.load_more;
        var offset = is_load_more ? state.curated_offset : 0;
        var limit = 50;

        if (is_load_more) {
            state.curated_loading_more = true;
        }

        this.model.make_request('/discover/popular_feeds', {
            type: 'all',
            category: state.curated_category || 'all',
            limit: limit,
            offset: offset
        }, function (data) {
            if (data && data.feeds) {
                if (is_load_more) {
                    state.curated_feeds = state.curated_feeds.concat(data.feeds);
                } else {
                    state.curated_feeds = data.feeds;
                }
                state.curated_offset = offset + data.feeds.length;
                state.curated_has_more = data.has_more;
            }
            state.curated_feeds_loaded = true;
            state.curated_loading_more = false;
            if (self.active_tab === 'search' && !self.search_query) {
                self.render_search_tab();
            }
        }, function () {
            state.curated_feeds_loaded = true;
            state.curated_loading_more = false;
            if (self.active_tab === 'search' && !self.search_query) {
                self.render_search_tab();
            }
        }, { request_type: 'GET' });
    },

    render_curated_feeds: function () {
        var self = this;
        var state = this.search_state;

        var $grid = this.make_results_container();
        _.each(state.curated_feeds, function (entry) {
            var feed_type = entry.feed_type;

            if (feed_type === 'rss') {
                $grid.append(self.render_popular_card(entry));
            } else if (feed_type === 'youtube') {
                $grid.append(self.render_youtube_card(entry));
            } else if (feed_type === 'reddit') {
                $grid.append(self.render_reddit_card(entry));
            } else if (feed_type === 'newsletter') {
                $grid.append(self.render_popular_newsletter_card(entry));
            } else if (feed_type === 'podcast') {
                $grid.append(self.render_podcast_card(entry));
            } else {
                // Generic feed card fallback
                if (entry.feed) {
                    $grid.append(self.render_feed_card(entry.feed, entry.stories || []));
                }
            }
        });
        return $grid;
    },

    fetch_popular_channels: function (channel_type) {
        var self = this;
        var state_map = {
            'youtube': this.youtube_state,
            'newsletters': this.newsletters_state,
            'podcasts': this.podcasts_state
        };
        var render_map = {
            'youtube': 'render_youtube_popular',
            'newsletters': 'render_newsletters_popular',
            'podcasts': 'render_podcasts_popular'
        };
        var state = state_map[channel_type];
        if (!state) return;

        this.model.make_request('/discover/popular_channels', {
            type: channel_type,
            limit: 20
        }, function (data) {
            if (data && data.channels) {
                // Convert to collection format matching trending feeds
                // TrendingFeed model will wrap feed/stories in proper Backbone models
                var feeds_array = _.map(data.channels, function(item, feed_id) {
                    return {
                        id: parseInt(feed_id, 10),
                        feed: item.feed,
                        stories: item.stories
                    };
                });
                state.popular_feeds_collection = new NEWSBLUR.Collections.TrendingFeeds(feeds_array);
            }
            state.popular_feeds_loaded = true;
            self[render_map[channel_type]]();
        }, function () {
            state.popular_feeds_loaded = true;
            state.popular_feeds_collection = new NEWSBLUR.Collections.TrendingFeeds([]);
            self[render_map[channel_type]]();
        }, { request_type: 'GET' });
    },

    // apps/discover/views.py - fetch_popular_feeds
    fetch_popular_feeds: function (feed_type, options) {
        var self = this;
        options = options || {};
        var state_map = {
            'rss': this.popular_state,
            'youtube': this.youtube_state,
            'reddit': this.reddit_state,
            'newsletter': this.newsletters_state,
            'podcast': this.podcasts_state
        };
        var render_map = {
            'rss': 'render_popular_popular',
            'youtube': 'render_youtube_popular',
            'reddit': 'render_reddit_popular',
            'newsletter': 'render_newsletters_popular',
            'podcast': 'render_podcasts_popular'
        };
        var state = state_map[feed_type];
        if (!state) return;

        var category = state.selected_category || 'all';
        var subcategory = state.selected_subcategory || 'all';
        var platform = state.selected_platform || 'all';
        var is_load_more = options.load_more;
        var offset = is_load_more ? state.popular_offset : 0;
        var limit = 50;

        if (is_load_more) {
            state.popular_loading_more = true;
        }

        var params = {
            type: feed_type,
            category: category,
            subcategory: subcategory,
            limit: limit,
            offset: offset,
            include_stories: this.view_mode === 'list' ? 'true' : 'false'
        };
        if (platform && platform !== 'all') {
            params.platform = platform;
        }

        this.model.make_request('/discover/popular_feeds', params, function (data) {
            if (data && data.feeds) {
                if (is_load_more) {
                    state.popular_feeds = state.popular_feeds.concat(data.feeds);
                } else {
                    state.popular_feeds = data.feeds;
                }
                state.popular_offset = offset + data.feeds.length;
                state.popular_has_more = data.has_more;
                if (data.categories && data.categories.length > 0) {
                    state.available_categories = data.categories;
                }
                if (data.grouped_categories && data.grouped_categories.length > 0) {
                    state.grouped_categories = data.grouped_categories;
                    // Race condition fix: update pills in-place when API data arrives
                    self.update_category_pills(feed_type);
                }

                // Build collection for list view
                if (self.view_mode === 'list') {
                    var feeds_array = _.chain(data.feeds)
                        .filter(function(f) { return f.feed; })
                        .map(function(f) {
                            return {
                                id: f.feed.id,
                                feed: f.feed,
                                stories: f.stories || []
                            };
                        }).value();

                    if (is_load_more && state.popular_feeds_collection) {
                        state.popular_feeds_collection.add(feeds_array);
                    } else {
                        state.popular_feeds_collection = new NEWSBLUR.Collections.TrendingFeeds(feeds_array);
                    }
                }
            }
            state.popular_feeds_loaded = true;
            state.popular_loading_more = false;
            self[render_map[feed_type]]();
        }, function () {
            state.popular_feeds_loaded = true;
            state.popular_loading_more = false;
            state.popular_feeds = state.popular_feeds || [];
            self[render_map[feed_type]]();
        }, { request_type: 'GET' });
    },

    load_more_popular_feeds: function (feed_type) {
        // Handle search_curated separately since it uses different state/fetch
        if (feed_type === 'search_curated') {
            var state = this.search_state;
            if (state.curated_loading_more || !state.curated_has_more) return;
            this.fetch_search_curated_feeds({ load_more: true });
            return;
        }
        var state_map = {
            'rss': this.popular_state,
            'youtube': this.youtube_state,
            'reddit': this.reddit_state,
            'newsletter': this.newsletters_state,
            'podcast': this.podcasts_state
        };
        var state = state_map[feed_type];
        if (!state || state.popular_loading_more || !state.popular_has_more) return;
        this.fetch_popular_feeds(feed_type, { load_more: true });
    },

    make_load_more_button: function (feed_type) {
        var self = this;
        var $button = $.make('div', { className: 'NB-add-site-load-more' }, [
            $.make('button', {
                className: 'NB-modal-submit-green NB-add-site-load-more-btn'
            }, 'Load More')
        ]);
        $button.find('.NB-add-site-load-more-btn').on('click', function () {
            $(this).text('Loading...').prop('disabled', true);
            self.load_more_popular_feeds(feed_type);
        });
        return $button;
    },

    // Two-level progressive disclosure pills: top-level categories + drill-down subcategories
    // add_site_view.js - make_category_pills
    make_category_pills: function (source, state) {
        var self = this;
        var selected_category = state.selected_category || 'all';
        var selected_subcategory = state.selected_subcategory || 'all';
        var grouped = state.grouped_categories || [];

        var $container = $.make('div', {
            className: 'NB-add-site-category-pills-container',
            'data-source': source
        });

        // Top-level category pills row
        var $cat_row = $.make('div', { className: 'NB-add-site-category-pills-row' });

        // "All" pill always first
        var all_active = (selected_category === 'all') ? ' NB-active' : '';
        $cat_row.append($.make('div', {
            className: 'NB-add-site-cat-pill' + all_active,
            'data-category': 'all',
            'data-level': 'category',
            'data-source': source
        }, 'All'));

        // One pill per category with icon and feed count
        _.each(grouped, function(group) {
            var display_name = group.name.charAt(0).toUpperCase() + group.name.slice(1);
            var icon_url = self.get_category_icon(group.name);
            var is_active = (selected_category === group.name) ? ' NB-active' : '';

            var pill_content = [
                $.make('img', { src: icon_url, className: 'NB-add-site-cat-pill-icon' }),
                $.make('span', { className: 'NB-add-site-cat-pill-name' }, display_name)
            ];

            // Show total feed count
            if (group.feed_count) {
                pill_content.push(
                    $.make('span', { className: 'NB-add-site-cat-pill-counts' }, '' + group.feed_count)
                );
            }

            $cat_row.append($.make('div', {
                className: 'NB-add-site-cat-pill' + is_active,
                'data-category': group.name,
                'data-level': 'category',
                'data-source': source
            }, pill_content));
        });

        $container.append($cat_row);

        // Subcategory pills row (hidden by default, shown when category selected)
        var $subcat_row = $.make('div', { className: 'NB-add-site-subcat-pills-row' });

        if (selected_category && selected_category !== 'all') {
            var active_group = _.find(grouped, function(g) { return g.name === selected_category; });
            if (active_group && active_group.subcategories && active_group.subcategories.length > 0) {
                this._populate_subcat_row($subcat_row, active_group, source, selected_subcategory);
                $subcat_row.addClass('NB-visible');
            }
        }

        $container.append($subcat_row);
        return $container;
    },

    // Populate subcategory pills row for a given category group
    // add_site_view.js - _populate_subcat_row
    _populate_subcat_row: function ($row, group, source, selected_subcategory) {
        var self = this;
        $row.empty();
        var display_name = group.name.charAt(0).toUpperCase() + group.name.slice(1);
        var icon_url = self.get_category_icon(group.name);
        var all_active = (!selected_subcategory || selected_subcategory === 'all') ? ' NB-active' : '';

        // Category label header with icon
        $row.append($.make('div', { className: 'NB-add-site-subcat-header' }, [
            $.make('img', { src: icon_url, className: 'NB-add-site-subcat-header-icon' }),
            $.make('span', display_name + ' topics')
        ]));

        // "All" pill for the category
        $row.append($.make('div', {
            className: 'NB-add-site-subcat-pill' + all_active,
            'data-category': group.name,
            'data-subcategory': 'all',
            'data-level': 'subcategory',
            'data-source': source
        }, 'All'));

        // Individual subcategory pills
        _.each(group.subcategories, function(subcat) {
            var subcat_name = (typeof subcat === 'string') ? subcat : subcat.name;
            var feed_count = (typeof subcat === 'object') ? subcat.feed_count : 0;
            var is_active = (selected_subcategory === subcat_name) ? ' NB-active' : '';

            var pill_content = [$.make('span', subcat_name)];
            if (feed_count) {
                pill_content.push(
                    $.make('span', { className: 'NB-add-site-subcat-pill-count' }, '' + feed_count)
                );
            }

            $row.append($.make('div', {
                className: 'NB-add-site-subcat-pill' + is_active,
                'data-category': group.name,
                'data-subcategory': subcat_name,
                'data-level': 'subcategory',
                'data-source': source
            }, pill_content));
        });
    },

    // Race condition fix: update pills in-place when API data arrives
    // add_site_view.js - update_category_pills
    update_category_pills: function (feed_type) {
        var source_map = {
            'rss': 'popular',
            'newsletter': 'newsletters',
            'podcast': 'podcasts'
        };
        var source = source_map[feed_type] || feed_type;
        var state_map = {
            'rss': this.popular_state,
            'youtube': this.youtube_state,
            'reddit': this.reddit_state,
            'newsletter': this.newsletters_state,
            'podcast': this.podcasts_state
        };
        var state = state_map[feed_type];
        if (!state || !state.grouped_categories || !state.grouped_categories.length) return;

        var $existing = this.$('.NB-add-site-category-pills-container[data-source="' + source + '"]');
        if (!$existing.length) return;

        var $new_pills = this.make_category_pills(source, state);
        $existing.replaceWith($new_pills);
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

        // Collect feeds and sort them
        var feeds = [];
        _.each(feed_ids, function(feed_id) {
            var feed_data = feeds_data[feed_id];
            if (feed_data) {
                feeds.push(feed_data);
            }
        });
        feeds = this.sort_feeds(feeds);

        var $grid = $.make('div', { className: 'NB-trending-feed-grid' });

        _.each(feeds.slice(0, 30), function(feed_data) {
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

        var $search_bar = this.render_tab_search_bar({
            input_class: 'NB-add-site-tab-search-input NB-add-site-' + config.tab_id + '-search',
            placeholder: config.placeholder,
            value: state.query || ''
        });

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-' + config.tab_id }, [
                    $.make('img', { src: config.icon })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, config.title),
                    $.make('div', { className: 'NB-add-site-source-desc' }, config.description)
                ])
            ]),
            $search_bar,
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results' }, config.extra_content || [])
            ])
        ]));

        this.bind_scroll_handler();

        if (state.results.length > 0) {
            config.render_results.call(this);
        }
    },

    // ===============
    // = Popular Tab =
    // ===============

    render_popular_tab: function () {
        var state = this.popular_state;
        var $tab = this.$('.NB-add-site-popular-tab');

        var $category_pills = this.make_category_pills('popular', state);

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-popular' }, [
                    $.make('img', { src: '/media/img/icons/heroicons-solid/fire.svg', className: 'NB-mono' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Popular Sites'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Browse popular blogs, news sites, and publications with RSS feeds.')
                ])
            ]),
            $category_pills,
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results' })
            ])
        ]));

        this.bind_scroll_handler();
        this.render_popular_popular();
    },

    // add_site_view.js - render_popular_popular
    render_popular_popular: function () {
        var self = this;
        var state = this.popular_state;
        var $results = this.$('.NB-add-site-popular-tab .NB-add-site-source-results');

        // List view with linked Feed objects
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
            var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
            var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });
            var stories_limit = this.get_stories_limit();

            state.popular_feeds_collection.each(function (popular_feed) {
                var $badge_content = [
                    new NEWSBLUR.Views.FeedBadge({
                        model: popular_feed.get("feed"),
                        show_folders: true,
                        in_add_site_view: self,
                        load_feed_after_add: false
                    })
                ];

                if (stories_limit > 0) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var limited_stories = self.limit_stories(popular_feed.get("stories"));
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: limited_stories,
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        pane_anchor: pane_anchor,
                        on_popular_feed: popular_feed,
                        in_add_site_view: self
                    });
                    $badge_content.push(story_titles_view.render().el);
                }

                var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
                $list.append($badge);
            });

            if (state.popular_has_more) {
                $list.append(self.make_load_more_button('rss'));
            }

            $results.html($list);
            return;
        }

        // Fetch from API if not loaded
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('rss');
            $results.html(this.make_loading_indicator());
            return;
        }

        var feeds = state.popular_feeds;
        if (!feeds || feeds.length === 0) {
            $results.html($.make('div', { className: 'NB-add-site-empty-state' },
                'No popular RSS feeds found. Run the bootstrap command to populate feeds.'
            ));
            return;
        }

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Sites')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = this.make_results_container();
        _.each(feeds, function(feed) {
            $grid.append(self.render_popular_card(feed));
        });

        $section.find('.NB-add-site-section-content').append($grid);

        if (state.popular_has_more) {
            $section.append(self.make_load_more_button('rss'));
        }

        $results.html($section);
    },

    render_popular_card: function (feed) {
        var sub_count = feed.subscriber_count || '';
        if (typeof sub_count === 'number') {
            sub_count = this.format_subscriber_count(sub_count).replace(' members', ' subscribers');
        }
        var meta_parts = [sub_count];

        return this.make_source_card({
            card_class: 'NB-add-site-popular-card',
            icon: feed.thumbnail_url || feed.favicon || '/media/img/icons/heroicons-solid/rss.svg',
            fallback_icon: '/media/img/icons/heroicons-solid/rss.svg',
            title: feed.title,
            meta: meta_parts.filter(Boolean).join(' \u2022 '),
            description: feed.description,
            feed_url: feed.feed_url,
            feed_id: feed.feed_id || feed.feed || null,
            last_story_date: feed.last_story_date,
            show_empty_freshness: true
        });
    },

    // ===============
    // = YouTube Tab =
    // ===============

    render_youtube_tab: function () {
        var state = this.youtube_state;
        var $tab = this.$('.NB-add-site-youtube-tab');

        var $category_pills = this.make_category_pills('youtube', state);

        var $search_bar = this.render_tab_search_bar({
            input_class: 'NB-add-site-tab-search-input NB-add-site-youtube-search',
            placeholder: 'Search YouTube channels...',
            value: state.query || ''
        });

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-youtube' }, [
                    $.make('img', { src: '/media/img/reader/youtube_play.png' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'YouTube Channels'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Subscribe to YouTube channels and playlists as RSS feeds.')
                ])
            ]),
            $search_bar,
            $category_pills,
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results' })
            ])
        ]));

        this.bind_scroll_handler();

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

        // List view with linked Feed objects: Use FeedBadge + StoryTitlesView
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
            var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
            var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });
            var stories_limit = this.get_stories_limit();

            state.popular_feeds_collection.each(function (popular_feed) {
                var $badge_content = [
                    new NEWSBLUR.Views.FeedBadge({
                        model: popular_feed.get("feed"),
                        show_folders: true,
                        in_add_site_view: self,
                        load_feed_after_add: false
                    })
                ];

                if (stories_limit > 0) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var limited_stories = self.limit_stories(popular_feed.get("stories"));
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: limited_stories,
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        pane_anchor: pane_anchor,
                        on_popular_feed: popular_feed,
                        in_add_site_view: self
                    });
                    $badge_content.push(story_titles_view.render().el);
                }

                var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
                $list.append($badge);
            });

            if (state.popular_has_more) {
                $list.append(self.make_load_more_button('youtube'));
            }

            $results.html($list);
            return;
        }

        // Fetch from API if not loaded (both grid and list views)
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('youtube');
            $results.html(this.make_loading_indicator());
            return;
        }

        // Card view: render feed cards from API data (grid view, or list view without linked Feed objects)
        var channels = state.popular_feeds;
        if (!channels || channels.length === 0) {
            channels = this.POPULAR_YOUTUBE_CHANNELS;
            if (state.selected_category && state.selected_category !== 'all') {
                channels = _.filter(channels, function(ch) {
                    return ch.category === state.selected_category;
                });
            }
        }

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Channels')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = this.make_results_container();
        _.each(channels, function(channel) {
            $grid.append(self.render_youtube_card(channel));
        });

        $section.find('.NB-add-site-section-content').append($grid);

        if (state.popular_has_more) {
            $section.append(self.make_load_more_button('youtube'));
        }

        $results.html($section);
    },

    render_youtube_card: function (channel) {
        var sub_count = channel.subscriber_count || '';
        if (typeof sub_count === 'number') {
            sub_count = this.format_subscriber_count(sub_count).replace(' members', ' subscribers');
        }
        var meta_parts = [sub_count];
        if (channel.video_count) {
            meta_parts.push(channel.video_count + ' videos');
        }

        return this.make_source_card({
            card_class: 'NB-add-site-youtube-card',
            icon: channel.thumbnail || channel.thumbnail_url || '/media/img/reader/youtube_play.png',
            fallback_icon: '/media/img/reader/youtube_play.png',
            title: channel.title,
            meta: meta_parts.filter(Boolean).join(' \u2022 '),
            description: channel.description,
            feed_url: channel.feed_url,
            feed_id: channel.feed_id || channel.feed || null,
            last_story_date: channel.last_story_date,
            show_empty_freshness: true
        });
    },

    // ==============
    // = Reddit Tab =
    // ==============

    render_reddit_tab: function () {
        var state = this.reddit_state;
        var $tab = this.$('.NB-add-site-reddit-tab');

        var $category_pills = this.make_category_pills('reddit', state);

        var $search_bar = this.render_tab_search_bar({
            input_class: 'NB-add-site-tab-search-input NB-add-site-reddit-search',
            placeholder: 'Search subreddits (e.g., programming, news, gaming)...',
            value: state.query || ''
        });

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
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
            $search_bar,
            $category_pills,
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results' })
            ])
        ]));

        this.bind_scroll_handler();

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

        // Try API-backed popular feeds first
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('reddit');
            $results.html(this.make_loading_indicator());
            return;
        }

        // Use API results if available, otherwise fall back to Reddit API
        var subreddits = state.popular_feeds;
        if (!subreddits || subreddits.length === 0) {
            // Fallback to Reddit API
            if (!state.popular_loaded) {
                $results.html(this.make_loading_indicator());
                this.fetch_reddit_popular();
                return;
            }
            subreddits = state.popular_subreddits;
        }

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Subreddits')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = self.make_results_container();
        _.each(subreddits, function(subreddit) {
            $grid.append(self.render_reddit_card(subreddit));
        });

        $section.find('.NB-add-site-section-content').append($grid);

        if (state.popular_has_more) {
            $section.append(self.make_load_more_button('reddit'));
        }

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
        var subscribers = subreddit.subscribers || subreddit.subscriber_count;
        var subscriber_text = this.format_subscriber_count(subscribers);
        var title = subreddit.name ? ('r/' + subreddit.name) : subreddit.title;

        return this.make_source_card({
            card_class: 'NB-add-site-reddit-card',
            icon: subreddit.icon || '/media/img/reader/reddit.png',
            fallback_icon: '/media/img/reader/reddit.png',
            title: title,
            meta: subscriber_text,
            description: subreddit.description,
            feed_url: subreddit.feed_url,
            feed_id: subreddit.feed_id || subreddit.feed || null,
            last_story_date: subreddit.last_story_date,
            show_empty_freshness: true
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
        var state = this.newsletters_state;
        var $tab = this.$('.NB-add-site-newsletters-tab');

        var platforms = [
            { id: 'all', name: 'All', icon: '/media/img/icons/bootstrap-fill/grid-fill.svg' },
            { id: 'substack', name: 'Substack', favicon: 'https://substack.com/favicon.ico' },
            { id: 'medium', name: 'Medium', favicon: 'https://miro.medium.com/v2/1*m-R_BkNf1Qjr1YbyOIJY2w.png' },
            { id: 'buttondown', name: 'Buttondown', favicon: 'https://buttondown.com/static/images/icons/icon@72.png' },
            { id: 'ghost', name: 'Ghost', favicon: 'https://ghost.org/favicon.ico' }
        ];
        var $platform_pills = $.make('div', { className: 'NB-add-site-filter-pills' },
            _.map(platforms, function(platform) {
                var pill_content;
                if (platform.favicon) {
                    pill_content = [
                        $.make('img', { src: platform.favicon, className: 'NB-add-site-filter-pill-favicon' }),
                        $.make('span', platform.name)
                    ];
                } else if (platform.icon) {
                    pill_content = [
                        $.make('img', { src: platform.icon, className: 'NB-add-site-filter-pill-icon' }),
                        $.make('span', platform.name)
                    ];
                } else {
                    pill_content = platform.name;
                }
                return $.make('div', {
                    className: 'NB-add-site-filter-pill' + (state.selected_platform === platform.id || (!state.selected_platform && platform.id === 'all') ? ' NB-active' : ''),
                    'data-category': platform.id,
                    'data-source': 'newsletters-platform'
                }, pill_content);
            })
        );

        var $category_pills = this.make_category_pills('newsletters', state);

        var $search_bar = this.render_tab_search_bar({
            input_class: 'NB-add-site-tab-search-input NB-add-site-newsletters-search',
            placeholder: 'Paste newsletter URL (e.g., example.substack.com)...',
            value: state.query || ''
        });

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
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
            $search_bar,
            $.make('div', { className: 'NB-add-site-newsletter-filters' }, [
                $.make('div', { className: 'NB-add-site-filter-group' }, [
                    $.make('div', { className: 'NB-add-site-filter-label' }, 'Platform'),
                    $platform_pills
                ]),
                $.make('div', { className: 'NB-add-site-filter-group' }, [
                    $.make('div', { className: 'NB-add-site-filter-label' }, 'Category'),
                    $category_pills
                ])
            ]),
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results' })
            ])
        ]));

        this.bind_scroll_handler();

        if (state.results.length > 0) {
            this.render_newsletter_results();
        } else {
            this.render_newsletters_popular();
        }
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
        var state = this.newsletters_state;
        var $results = this.$('.NB-add-site-newsletters-tab .NB-add-site-source-results');

        // List view with linked Feed objects: Use FeedBadge + StoryTitlesView
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
            var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
            var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });
            var stories_limit = this.get_stories_limit();

            state.popular_feeds_collection.each(function (popular_feed) {
                var $badge_content = [
                    new NEWSBLUR.Views.FeedBadge({
                        model: popular_feed.get("feed"),
                        show_folders: true,
                        in_add_site_view: self,
                        load_feed_after_add: false
                    })
                ];

                if (stories_limit > 0) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var limited_stories = self.limit_stories(popular_feed.get("stories"));
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: limited_stories,
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        pane_anchor: pane_anchor,
                        on_popular_feed: popular_feed,
                        in_add_site_view: self
                    });
                    $badge_content.push(story_titles_view.render().el);
                }

                var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
                $list.append($badge);
            });

            if (state.popular_has_more) {
                $list.append(self.make_load_more_button('newsletter'));
            }

            $results.html($list);
            return;
        }

        // Fetch from API if not loaded (both grid and list views)
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('newsletter');
            $results.html(this.make_loading_indicator());
            return;
        }

        var newsletters = state.popular_feeds;
        if (!newsletters || newsletters.length === 0) {
            // Fallback to inline data grouped by platform
            var by_platform = _.groupBy(this.POPULAR_NEWSLETTERS, 'platform');
            var platform_order = ['substack', 'medium', 'ghost', 'generic', 'direct'];
            newsletters = [];
            _.each(platform_order, function(platform) {
                if (by_platform[platform]) {
                    newsletters = newsletters.concat(by_platform[platform]);
                }
            });
        }

        var $container = $.make('div', { className: 'NB-add-site-newsletters-popular' });

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Newsletters')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = self.make_results_container();
        _.each(newsletters, function(newsletter) {
            $grid.append(self.render_popular_newsletter_card(newsletter));
        });

        $section.find('.NB-add-site-section-content').append($grid);

        if (state.popular_has_more) {
            $section.append(self.make_load_more_button('newsletter'));
        }

        $container.append($section);
        $results.html($container);
    },

    render_popular_newsletter_card: function (newsletter) {
        var platform_label = this.NEWSLETTER_PLATFORMS[newsletter.platform] || 'Newsletter';

        var meta_parts = [platform_label];
        var subscribers = newsletter.subscribers || newsletter.subscriber_count;
        if (subscribers) {
            var sub_text = typeof subscribers === 'number'
                ? this.format_subscriber_count(subscribers).replace(' members', ' subscribers')
                : subscribers + ' subscribers';
            meta_parts.push(sub_text);
        }

        return this.make_source_card({
            card_class: 'NB-add-site-newsletter-card',
            icon: newsletter.icon || '/media/img/reader/email_icon.png',
            fallback_icon: '/media/img/reader/email_icon.png',
            title: newsletter.title,
            meta: meta_parts.join(' \u2022 '),
            description: newsletter.description,
            feed_url: newsletter.feed_url,
            feed_id: newsletter.feed_id || newsletter.feed || null,
            last_story_date: newsletter.last_story_date,
            show_empty_freshness: true
        });
    },

    render_newsletter_card: function (newsletter) {
        var platform_label = this.NEWSLETTER_PLATFORMS[newsletter.platform] || 'Newsletter';
        var title = newsletter.title || this.extract_domain(newsletter.original_url);

        var meta_parts = [platform_label];
        var subscribers = newsletter.subscribers || newsletter.subscriber_count;
        if (subscribers) {
            var sub_text = typeof subscribers === 'number'
                ? this.format_subscriber_count(subscribers).replace(' members', ' subscribers')
                : subscribers + ' subscribers';
            meta_parts.push(sub_text);
        }

        return this.make_source_card({
            card_class: 'NB-add-site-newsletter-card',
            icon: newsletter.icon || '/media/img/reader/email_icon.png',
            fallback_icon: '/media/img/reader/email_icon.png',
            title: title,
            meta: meta_parts.join(' \u2022 '),
            description: newsletter.description || ('Subscribe to ' + title + ' via RSS'),
            feed_url: newsletter.feed_url,
            feed_id: newsletter.feed_id || newsletter.feed || null,
            last_story_date: newsletter.last_story_date,
            show_empty_freshness: true
        });
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
        var state = this.podcasts_state;
        var $tab = this.$('.NB-add-site-podcasts-tab');

        var $category_pills = this.make_category_pills('podcasts', state);

        var $search_bar = this.render_tab_search_bar({
            input_class: 'NB-add-site-tab-search-input NB-add-site-podcasts-search',
            placeholder: 'Search podcasts (e.g., "technology", "true crime", "comedy")...',
            value: state.query || ''
        });

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
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
            $search_bar,
            $category_pills,
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results' })
            ])
        ]));

        this.bind_scroll_handler();

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

        // List view with linked Feed objects: Use FeedBadge + StoryTitlesView
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
            var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
            var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });
            var stories_limit = this.get_stories_limit();

            state.popular_feeds_collection.each(function (popular_feed) {
                var $badge_content = [
                    new NEWSBLUR.Views.FeedBadge({
                        model: popular_feed.get("feed"),
                        show_folders: true,
                        in_add_site_view: self,
                        load_feed_after_add: false
                    })
                ];

                if (stories_limit > 0) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var limited_stories = self.limit_stories(popular_feed.get("stories"));
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: limited_stories,
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        pane_anchor: pane_anchor,
                        on_popular_feed: popular_feed,
                        in_add_site_view: self
                    });
                    $badge_content.push(story_titles_view.render().el);
                }

                var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
                $list.append($badge);
            });

            if (state.popular_has_more) {
                $list.append(self.make_load_more_button('podcast'));
            }

            $results.html($list);
            return;
        }

        // Fetch from API if not loaded (both grid and list views)
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('podcast');
            $results.html(this.make_loading_indicator());
            return;
        }

        var podcasts = state.popular_feeds;
        if (!podcasts || podcasts.length === 0) {
            // Fallback to inline data
            podcasts = this.POPULAR_PODCASTS;
            if (state.selected_category && state.selected_category !== 'all') {
                podcasts = _.filter(podcasts, function(p) {
                    return p.category === state.selected_category;
                });
            }
        }

        var $section = $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, 'Popular Podcasts')
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);

        var $grid = self.make_results_container();
        _.each(podcasts, function(podcast) {
            $grid.append(self.render_podcast_card(podcast));
        });

        $section.find('.NB-add-site-section-content').append($grid);

        if (state.popular_has_more) {
            $section.append(self.make_load_more_button('podcast'));
        }

        $results.html($section);
    },

    render_podcast_card: function (podcast) {
        var meta_parts = [];
        if (podcast.artist) meta_parts.push(podcast.artist);
        if (podcast.track_count) meta_parts.push(podcast.track_count + ' episodes');

        var description = podcast.description || podcast.genre || '';

        return this.make_source_card({
            card_class: 'NB-add-site-podcast-card',
            icon: podcast.artwork || '/media/img/icons/lucide/podcast.svg',
            fallback_icon: '/media/img/icons/lucide/podcast.svg',
            title: podcast.name || podcast.title,
            meta: meta_parts.join(' \u2022 '),
            description: description,
            feed_url: podcast.feed_url,
            feed_id: podcast.feed_id || podcast.feed || null,
            last_story_date: podcast.last_story_date,
            show_empty_freshness: true
        });
    },

    // ===================
    // = Google News Tab =
    // ===================

    render_google_news_tab: function () {
        var $tab = this.$('.NB-add-site-google-news-tab');
        var state = this.google_news_state;

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
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
            $.make('div', { className: 'NB-add-site-tab-results' }, [
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
                                    $.make('img', { src: topic.icon, className: 'NB-add-site-topic-icon' }),
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
            ])
        ]));

        if (state.language) {
            $tab.find('.NB-add-site-google-news-language').val(state.language);
        }
    },

    // ================
    // = Trending Tab =
    // ================

    render_trending_tab: function () {
        var state = this.trending_state;
        var $tab = this.$('.NB-add-site-trending-tab');

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search NB-add-site-source-tab-wide' }, [
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
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results NB-add-site-trending-results' })
            ])
        ]));

        this.bind_scroll_handler();

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
            // Check if we have real trending feeds (handle both array and object)
            var has_feeds = data && data.trending_feeds &&
                (_.isArray(data.trending_feeds) ? data.trending_feeds.length > 0 : Object.keys(data.trending_feeds).length > 0);

            if (has_feeds) {
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
            } else {
                // No trending feeds - show empty state
                state.has_more = false;
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

        var $tab = this.$('.NB-add-site-categories-tab');

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search NB-add-site-source-tab-wide' }, [
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
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-source-results NB-add-site-categories-grid' })
            ])
        ]));

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
        // Map category titles to SVG icons - add_site_view.js
        var icon_map = {
            'technology': '/media/img/icons/heroicons-solid/computer-desktop.svg',
            'news': '/media/img/icons/heroicons-solid/newspaper.svg',
            'science': '/media/img/icons/heroicons-solid/beaker.svg',
            'business': '/media/img/icons/heroicons-solid/briefcase.svg',
            'sports': '/media/img/icons/heroicons-solid/trophy.svg',
            'entertainment': '/media/img/icons/heroicons-solid/film.svg',
            'gaming': '/media/img/icons/heroicons-solid/puzzle-piece.svg',
            'health': '/media/img/icons/heroicons-solid/heart.svg',
            'programming': '/media/img/icons/heroicons-solid/code-bracket.svg',
            'design': '/media/img/icons/heroicons-solid/paint-brush.svg',
            'finance': '/media/img/icons/heroicons-solid/chart-bar.svg',
            'politics': '/media/img/icons/heroicons-solid/building-library.svg',
            'music': '/media/img/icons/heroicons-solid/musical-note.svg',
            'food': '/media/img/icons/phosphor-fill/cooking-pot-fill.svg',
            'travel': '/media/img/icons/heroicons-solid/globe-alt.svg',
            'photography': '/media/img/icons/heroicons-solid/camera.svg',
            'environment': '/media/img/icons/heroicons-solid/globe-americas.svg',
            'ai': '/media/img/icons/heroicons-solid/cpu-chip.svg',
            'aiml': '/media/img/icons/heroicons-solid/cpu-chip.svg',
            'startups': '/media/img/icons/heroicons-solid/rocket-launch.svg',
            'security': '/media/img/icons/heroicons-solid/shield-check.svg'
        };

        var key = title.toLowerCase().replace(/[^a-z]/g, '');
        return icon_map[key] || '/media/img/icons/nouns/folder-closed.svg';
    },

    get_placeholder_categories: function () {
        return [
            { id: 1, name: 'Technology', icon: '/media/img/icons/heroicons-solid/computer-desktop.svg', feed_count: 245, slug: 'technology' },
            { id: 2, name: 'News', icon: '/media/img/icons/heroicons-solid/newspaper.svg', feed_count: 189, slug: 'news' },
            { id: 3, name: 'Science', icon: '/media/img/icons/heroicons-solid/beaker.svg', feed_count: 156, slug: 'science' },
            { id: 4, name: 'Business', icon: '/media/img/icons/heroicons-solid/briefcase.svg', feed_count: 134, slug: 'business' },
            { id: 5, name: 'Sports', icon: '/media/img/icons/heroicons-solid/trophy.svg', feed_count: 178, slug: 'sports' },
            { id: 6, name: 'Entertainment', icon: '/media/img/icons/heroicons-solid/film.svg', feed_count: 201, slug: 'entertainment' },
            { id: 7, name: 'Gaming', icon: '/media/img/icons/heroicons-solid/puzzle-piece.svg', feed_count: 167, slug: 'gaming' },
            { id: 8, name: 'Health', icon: '/media/img/icons/heroicons-solid/heart.svg', feed_count: 98, slug: 'health' },
            { id: 9, name: 'Programming', icon: '/media/img/icons/heroicons-solid/code-bracket.svg', feed_count: 223, slug: 'programming' },
            { id: 10, name: 'Design', icon: '/media/img/icons/heroicons-solid/paint-brush.svg', feed_count: 87, slug: 'design' },
            { id: 11, name: 'Finance', icon: '/media/img/icons/heroicons-solid/chart-bar.svg', feed_count: 145, slug: 'finance' },
            { id: 12, name: 'Politics', icon: '/media/img/icons/heroicons-solid/building-library.svg', feed_count: 112, slug: 'politics' },
            { id: 13, name: 'Music', icon: '/media/img/icons/heroicons-solid/musical-note.svg', feed_count: 134, slug: 'music' },
            { id: 14, name: 'Food', icon: '/media/img/icons/phosphor-fill/cooking-pot-fill.svg', feed_count: 89, slug: 'food' },
            { id: 15, name: 'Travel', icon: '/media/img/icons/heroicons-solid/globe-alt.svg', feed_count: 76, slug: 'travel' },
            { id: 16, name: 'Photography', icon: '/media/img/icons/heroicons-solid/camera.svg', feed_count: 65, slug: 'photography' },
            { id: 17, name: 'Environment', icon: '/media/img/icons/heroicons-solid/globe-americas.svg', feed_count: 54, slug: 'environment' },
            { id: 18, name: 'AI & ML', icon: '/media/img/icons/heroicons-solid/cpu-chip.svg', feed_count: 178, slug: 'ai-ml' },
            { id: 19, name: 'Startups', icon: '/media/img/icons/heroicons-solid/rocket-launch.svg', feed_count: 123, slug: 'startups' },
            { id: 20, name: 'Security', icon: '/media/img/icons/heroicons-solid/shield-check.svg', feed_count: 98, slug: 'security' }
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

        this.$('.NB-add-site-categories-tab').html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
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
            $.make('div', { className: 'NB-add-site-tab-results' }, [
                $.make('div', { className: 'NB-add-site-category-feeds-results' })
            ])
        ]));
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

        // Sort feeds based on user preference
        feeds = this.sort_feeds(feeds);

        state.feeds = feeds;

        var $results = this.$('.NB-add-site-category-feeds-results');
        $results.empty();

        if (feeds.length === 0) {
            $results.html($.make('div', { className: 'NB-add-site-empty-state' },
                'No feeds found in this category.'));
            return;
        }

        // Render feed cards in a grid
        var $grid = self.make_results_container();
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
        var self = this;
        var $pill = $(e.currentTarget);
        var category = $pill.data('category');
        var subcategory = $pill.data('subcategory');
        var source = $pill.data('source');
        var level = $pill.data('level');

        // Two-level pill system (category/subcategory)
        if (level === 'category' || level === 'subcategory') {
            this._handle_two_level_pill_click($pill, source, level, category, subcategory);
            return;
        }

        // Legacy flat pill handling (platform pills, search pills)
        var $container = $pill.closest('.NB-add-site-filter-pills');
        $container.find('.NB-add-site-filter-pill').removeClass('NB-active');
        $pill.addClass('NB-active');

        if (source === 'newsletters-platform') {
            this.newsletters_state.selected_platform = category;
            this.newsletters_state.popular_feeds_loaded = false;
            this.newsletters_state.popular_feeds = [];
            this.newsletters_state.popular_feeds_collection = null;
            this.newsletters_state.popular_offset = 0;
            this.render_newsletters_popular();
        } else if (source === 'search') {
            this.search_state.curated_category = category;
            this.search_state.curated_feeds_loaded = false;
            this.search_state.curated_feeds = [];
            this.search_state.curated_offset = 0;
            this.render_search_tab();
        }
    },

    // Handle clicks on the two-level category/subcategory pill system
    // add_site_view.js - _handle_two_level_pill_click
    _handle_two_level_pill_click: function ($pill, source, level, category, subcategory) {
        var state_map = {
            'popular': this.popular_state,
            'youtube': this.youtube_state,
            'reddit': this.reddit_state,
            'newsletters': this.newsletters_state,
            'podcasts': this.podcasts_state
        };
        var render_map = {
            'popular': 'render_popular_popular',
            'youtube': 'render_youtube_popular',
            'reddit': 'render_reddit_popular',
            'newsletters': 'render_newsletters_popular',
            'podcasts': 'render_podcasts_popular'
        };
        var state = state_map[source];
        if (!state) return;

        var $container = $pill.closest('.NB-add-site-category-pills-container');

        if (level === 'category') {
            // Category pill clicked: highlight it, reset subcategory, show subcategory row
            $container.find('.NB-add-site-cat-pill').removeClass('NB-active');
            $pill.addClass('NB-active');

            state.selected_category = category || 'all';
            state.selected_subcategory = 'all';
            state.popular_feeds_loaded = false;
            state.popular_feeds = [];
            state.popular_feeds_collection = null;
            state.popular_offset = 0;

            // Update subcategory row
            var $subcat_row = $container.find('.NB-add-site-subcat-pills-row');
            if (category && category !== 'all') {
                var grouped = state.grouped_categories || [];
                var active_group = _.find(grouped, function(g) { return g.name === category; });
                if (active_group && active_group.subcategories && active_group.subcategories.length > 0) {
                    this._populate_subcat_row($subcat_row, active_group, source, 'all');
                    $subcat_row.addClass('NB-visible');
                } else {
                    $subcat_row.removeClass('NB-visible').empty();
                }
            } else {
                $subcat_row.removeClass('NB-visible').empty();
            }

            if (source === 'youtube') this.youtube_state.results = [];
            this[render_map[source]]();

        } else if (level === 'subcategory') {
            // Subcategory pill clicked: highlight it, refetch with subcategory filter
            $container.find('.NB-add-site-subcat-pill').removeClass('NB-active');
            $pill.addClass('NB-active');

            state.selected_subcategory = subcategory || 'all';
            state.popular_feeds_loaded = false;
            state.popular_feeds = [];
            state.popular_feeds_collection = null;
            state.popular_offset = 0;

            if (source === 'youtube') this.youtube_state.results = [];
            this[render_map[source]]();
        }
    },

    // ==================
    // = Shared Methods =
    // ==================

    render_feed_card: function (feed, stories) {
        var self = this;
        stories = stories || [];

        // Check if already subscribed. Use feed.feed (actual Feed FK from popular_feeds API)
        // or feed.feed_id (from search results), NOT feed.id (which may be PopularFeed PK).
        var feed_id = feed.feed || feed.feed_id || feed.id;
        var subscribed = feed_id && NEWSBLUR.assets.get_feed(feed_id);

        // Get display preferences
        var image_preview = NEWSBLUR.assets.preference('add_site_image_preview') || 'large';
        var content_preview = NEWSBLUR.assets.preference('add_site_content_preview') || 'medium';

        var $stories_preview = null;
        if (stories.length > 0) {
            $stories_preview = $.make('div', { className: 'NB-add-site-card-stories' },
                _.map(stories.slice(0, 3), function(story) {
                    var story_elements = [];

                    // Add story image if preference allows and image exists
                    if (image_preview !== 'none') {
                        var image_url = story.image_urls && story.image_urls.length > 0 ? story.image_urls[0] : null;
                        if (!image_url && story.story_content) {
                            // Try to extract first image from content
                            var img_match = story.story_content.match(/<img[^>]+src=["']([^"']+)["']/i);
                            if (img_match) image_url = img_match[1];
                        }
                        if (image_url) {
                            var image_class = 'NB-add-site-card-story-image';
                            if (image_preview === 'small') {
                                image_class += ' NB-image-small';
                            } else {
                                image_class += ' NB-image-large';
                            }
                            story_elements.push($.make('img', {
                                src: image_url,
                                className: image_class,
                                onerror: "this.style.display='none'"
                            }));
                        }
                    }

                    story_elements.push($.make('div', { className: 'NB-add-site-card-story-title' },
                        story.story_title || story.title || 'Untitled'));

                    // Add story content preview based on preference
                    if (content_preview !== 'title' && story.story_content) {
                        var content_text = self.strip_html(story.story_content);
                        if (content_text) {
                            var max_lines = content_preview === 'small' ? 1 : (content_preview === 'medium' ? 2 : 3);
                            var max_chars = max_lines * 80; // Approximate chars per line
                            var preview_text = self.truncate_text(content_text, max_chars);
                            var preview_class = 'NB-add-site-card-story-preview NB-preview-lines-' + max_lines;
                            story_elements.push($.make('div', { className: preview_class }, preview_text));
                        }
                    }

                    return $.make('div', { className: 'NB-add-site-card-story' }, story_elements);
                })
            );
        }

        var meta_parts = [];
        if (feed.num_subscribers) {
            var subscriber_count = parseInt(feed.num_subscribers, 10);
            var subscriber_label = subscriber_count === 1 ? 'subscriber' : 'subscribers';
            meta_parts.push(subscriber_count.toLocaleString() + ' ' + subscriber_label);
        }
        if (feed.average_stories_per_month) {
            var stories_count = parseInt(feed.average_stories_per_month, 10);
            var stories_label = stories_count === 1 ? 'story/month' : 'stories/month';
            meta_parts.push(stories_count.toLocaleString() + ' ' + stories_label);
        }
        var $freshness = this.make_freshness_indicator(feed.last_story_date, { show_empty: true });

        // Feed tagline/description always shown
        var $description = null;
        if (feed.tagline) {
            $description = $.make('div', { className: 'NB-add-site-card-desc' },
                this.truncate_text(feed.tagline, 150));
        }

        // Build actions based on subscription status
        var $actions;
        var $stats_btn = $.make('div', {
            className: 'NB-add-site-stats-btn NB-modal-submit-button NB-modal-submit-grey',
            'data-feed-id': feed_id
        }, [
            $.make('img', {
                src: '/media/embed/icons/nouns/dialog-statistics.svg',
                className: 'NB-add-site-stats-icon'
            }),
            'Stats'
        ]);

        if (subscribed) {
            $actions = $.make('div', { className: 'NB-add-site-card-actions NB-add-site-card-actions-subscribed' }, [
                $.make('div', { className: 'NB-subscribed-badge' }, [
                    $.make('span', { className: 'NB-subscribed-badge-check' }, '\u2713'),
                    ' Subscribed'
                ]),
                $.make('div', { className: 'NB-add-site-card-actions-row' }, [
                    $stats_btn,
                    $.make('div', {
                        className: 'NB-add-site-open-btn NB-modal-submit-button NB-modal-submit-green',
                        'data-feed-id': feed_id
                    }, 'Open')
                ])
            ]);
        } else {
            $actions = $.make('div', { className: 'NB-add-site-card-actions' }, [
                $.make('div', { className: 'NB-add-site-card-actions-row' }, [
                    $.make('div', {
                        className: 'NB-add-site-try-btn NB-modal-submit-button NB-modal-submit-green',
                        'data-feed-id': feed_id
                    }, 'Try'),
                    $stats_btn
                ]),
                $.make('div', { className: 'NB-add-site-card-add-group' }, [
                    this.make_folder_selector(feed),
                    $.make('div', {
                        className: 'NB-add-site-subscribe-btn NB-modal-submit-button NB-modal-submit-grey',
                        'data-feed-id': feed_id,
                        'data-feed-url': feed.feed_address || feed.address
                    }, 'Add')
                ])
            ]);
        }

        // Single DOM structure for both grid and list - CSS Grid handles layout
        return $.make('div', {
            className: 'NB-add-site-card' + (subscribed ? ' NB-add-site-card-subscribed' : ''),
            'data-feed-id': feed_id
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
                    ),
                    $freshness
                ].filter(Boolean))
            ]),
            $description,
            $stories_preview,
            $actions
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

        var show_empty = config.show_empty_freshness !== undefined ? config.show_empty_freshness : true;
        var $freshness = this.make_freshness_indicator(config.last_story_date, {
            show_empty: show_empty
        });

        // Check if already subscribed
        var feed_id = config.feed_id;
        var subscribed = feed_id && NEWSBLUR.assets.get_feed(feed_id);

        var $actions;
        var $stats_btn = $.make('div', {
            className: 'NB-add-site-stats-btn NB-modal-submit-button NB-modal-submit-grey',
            'data-feed-id': feed_id
        }, [
            $.make('img', {
                src: '/media/embed/icons/nouns/dialog-statistics.svg',
                className: 'NB-add-site-stats-icon'
            }),
            'Stats'
        ]);

        if (subscribed) {
            $actions = $.make('div', { className: 'NB-add-site-card-actions NB-add-site-card-actions-subscribed' }, [
                $.make('div', { className: 'NB-subscribed-badge' }, [
                    $.make('span', { className: 'NB-subscribed-badge-check' }, '\u2713'),
                    ' Subscribed'
                ]),
                $.make('div', { className: 'NB-add-site-card-actions-row' }, [
                    $stats_btn,
                    $.make('div', {
                        className: 'NB-add-site-open-btn NB-modal-submit-button NB-modal-submit-green',
                        'data-feed-id': feed_id
                    }, 'Open')
                ])
            ]);
        } else {
            $actions = $.make('div', { className: 'NB-add-site-card-actions' }, [
                $.make('div', { className: 'NB-add-site-card-actions-row' }, [
                    $.make('div', {
                        className: 'NB-add-site-try-btn NB-modal-submit-button NB-modal-submit-green',
                        'data-feed-id': feed_id
                    }, 'Try'),
                    $stats_btn
                ]),
                $.make('div', { className: 'NB-add-site-card-add-group' }, [
                    this.make_folder_selector(),
                    $.make('div', {
                        className: 'NB-add-site-subscribe-btn NB-modal-submit-button NB-modal-submit-grey',
                        'data-feed-id': feed_id,
                        'data-feed-url': config.feed_url
                    }, 'Add')
                ])
            ]);
        }

        // Single DOM structure for both grid and list - CSS handles layout
        return $.make('div', {
            className: 'NB-add-site-card ' + config.card_class + (subscribed ? ' NB-add-site-card-subscribed' : ''),
            'data-feed-id': feed_id
        }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('img', icon_attrs),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' }, config.title),
                    $.make('div', { className: 'NB-add-site-card-meta' }, config.meta || ''),
                    $freshness
                ].filter(Boolean))
            ]),
            description_el,
            $actions
        ].filter(Boolean));
    },

    make_folder_selector: function () {
        var folders = NEWSBLUR.utils.make_folders();
        var $select = $(folders).addClass('NB-add-site-folder-select');
        $select.append($.make('option', { value: '__new__' }, '+ New Folder...'));
        return $select;
    },

    make_loading_indicator: function () {
        return this.make_skeleton_cards();
    },

    make_skeleton_card: function () {
        return $.make('div', { className: 'NB-add-site-skeleton-card' }, [
            $.make('div', { className: 'NB-add-site-skeleton-header' }, [
                $.make('div', { className: 'NB-add-site-skeleton-icon' }),
                $.make('div', { className: 'NB-add-site-skeleton-info' }, [
                    $.make('div', { className: 'NB-add-site-skeleton-title' }),
                    $.make('div', { className: 'NB-add-site-skeleton-meta' })
                ])
            ]),
            $.make('div', { className: 'NB-add-site-skeleton-desc' }),
            $.make('div', { className: 'NB-add-site-skeleton-desc' }),
            $.make('div', { className: 'NB-add-site-skeleton-actions' }, [
                $.make('div', { className: 'NB-add-site-skeleton-btn' }),
                $.make('div', { className: 'NB-add-site-skeleton-btn' }),
                $.make('div', { className: 'NB-add-site-skeleton-btn NB-skeleton-wide' })
            ])
        ]);
    },

    make_skeleton_cards: function (count) {
        count = count || 6;
        var $container = this.make_results_container();
        for (var i = 0; i < count; i++) {
            $container.append(this.make_skeleton_card());
        }
        return $container;
    },

    make_results_container: function () {
        var columns = NEWSBLUR.assets.preference('add_site_grid_columns') || 'auto';
        var class_name = 'NB-add-site-results NB-add-site-results-' + this.view_mode;
        if (columns !== 'auto') {
            class_name += ' NB-add-site-columns-' + columns;
        }
        return $.make('div', { className: class_name });
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

    strip_html: function (html) {
        if (!html) return '';
        // Remove HTML tags and decode entities
        var tmp = document.createElement('div');
        tmp.innerHTML = html;
        var text = tmp.textContent || tmp.innerText || '';
        // Normalize whitespace
        return text.replace(/\s+/g, ' ').trim();
    },

    make_freshness_indicator: function (last_story_date, options) {
        options = options || {};
        var freshness_class = 'NB-add-site-card-freshness';
        var freshness_label;

        if (!last_story_date) {
            if (!options.show_empty) return null;
            freshness_class += ' NB-freshness-none';
            freshness_label = 'No stories yet';
            return $.make('div', { className: freshness_class }, [
                $.make('span', { className: 'NB-freshness-dot' }),
                $.make('span', { className: 'NB-freshness-label' }, freshness_label)
            ]);
        }

        var last_date = new Date(last_story_date);
        if (isNaN(last_date.getTime())) return null;

        var now = new Date();
        var days_ago = Math.floor((now - last_date) / (1000 * 60 * 60 * 24));
        var date_str = last_date.toLocaleDateString(undefined, {
            month: 'short', day: 'numeric', year: 'numeric'
        });

        if (days_ago < 365) {
            freshness_class += ' NB-freshness-active';
            if (days_ago < 1) {
                freshness_label = 'Updated today';
            } else if (days_ago < 7) {
                freshness_label = 'Updated ' + days_ago + (days_ago === 1 ? ' day ago' : ' days ago');
            } else if (days_ago < 30) {
                var weeks = Math.floor(days_ago / 7);
                freshness_label = 'Updated ' + weeks + (weeks === 1 ? ' week ago' : ' weeks ago');
            } else {
                var months = Math.floor(days_ago / 30);
                freshness_label = 'Updated ' + (months === 1 ? '1 month ago' : months + ' months ago');
            }
        } else {
            freshness_class += ' NB-freshness-stale';
            freshness_label = 'Stale \u2014 last story ' + date_str;
        }

        return $.make('div', { className: freshness_class }, [
            $.make('span', { className: 'NB-freshness-dot' }),
            $.make('span', { className: 'NB-freshness-label' }, freshness_label)
        ]);
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
        this.bind_scroll_handler();
        this.update_tab_overflow();
    },

    update_tab_overflow: function () {
        var self = this;
        var $container = this.$('.NB-add-site-tabs-container');
        var $tabs_wrapper = this.$('.NB-add-site-tabs');
        var $overflow = this.$('.NB-add-site-tabs-overflow');
        var $overflow_menu = this.$('.NB-add-site-tabs-overflow-menu');
        var $controls = this.$('.NB-add-site-controls');

        if (!$container.length || !$tabs_wrapper.length) return;

        // Get available width for tabs (container width minus controls and overflow button)
        var controls_width = $controls.length ? $controls.outerWidth(true) : 0;
        var overflow_button_width = 80; // Approximate width of "More" button
        var container_width = $container.parent().width() - controls_width - 32; // 32px padding

        // First, show all tabs and reset
        this.$('.NB-add-site-tab').removeClass('NB-overflow-hidden');
        $overflow.addClass('NB-hidden');
        $overflow_menu.empty();
        this.overflow_tabs = [];

        // Measure each tab and determine which fit
        var $tabs = this.$('.NB-add-site-tab');
        var cumulative_width = 0;
        var visible_tabs = [];
        var hidden_tabs = [];

        $tabs.each(function (index) {
            var $tab = $(this);
            var tab_width = $tab.outerWidth(true);
            var tab_id = $tab.data('tab');
            var is_active = $tab.hasClass('NB-active');

            // Active tab always stays visible
            if (is_active) {
                visible_tabs.push({ $tab: $tab, tab_id: tab_id, width: tab_width, is_active: true });
                cumulative_width += tab_width;
            } else {
                // Check if this tab fits
                if (cumulative_width + tab_width + overflow_button_width <= container_width) {
                    visible_tabs.push({ $tab: $tab, tab_id: tab_id, width: tab_width, is_active: false });
                    cumulative_width += tab_width;
                } else {
                    hidden_tabs.push({ $tab: $tab, tab_id: tab_id, width: tab_width, is_active: false });
                }
            }
        });

        // If we have hidden tabs, show overflow button and populate menu
        if (hidden_tabs.length > 0) {
            this.overflow_tabs = hidden_tabs;

            // Hide overflow tabs
            _.each(hidden_tabs, function (tab_info) {
                tab_info.$tab.addClass('NB-overflow-hidden');
            });

            // Populate overflow menu
            _.each(hidden_tabs, function (tab_info) {
                var tab_config = _.find(self.TABS, function (t) { return t.id === tab_info.tab_id; });
                if (tab_config) {
                    $overflow_menu.append($.make('div', {
                        className: 'NB-add-site-tabs-overflow-item',
                        'data-tab': tab_info.tab_id
                    }, [
                        $.make('img', { src: tab_config.icon, className: 'NB-add-site-tabs-overflow-item-icon' }),
                        $.make('span', tab_config.label)
                    ]));
                }
            });

            $overflow.removeClass('NB-hidden');
        }
    },

    toggle_overflow_menu: function (e) {
        e.stopPropagation();
        var $menu = this.$('.NB-add-site-tabs-overflow-menu');
        $menu.toggleClass('NB-hidden');

        // Close menu when clicking outside
        if (!$menu.hasClass('NB-hidden')) {
            var self = this;
            $(document).one('click.overflow_menu', function () {
                self.$('.NB-add-site-tabs-overflow-menu').addClass('NB-hidden');
            });
        }
    },

    select_overflow_tab: function (e) {
        e.stopPropagation();
        var $item = $(e.currentTarget);
        var tab_id = $item.data('tab');

        // Close menu
        this.$('.NB-add-site-tabs-overflow-menu').addClass('NB-hidden');

        // Find the tab element and trigger switch
        var $tab = this.$('.NB-add-site-tab[data-tab="' + tab_id + '"]');
        if ($tab.length) {
            // Manually switch to this tab
            this.active_tab = tab_id;

            this.$('.NB-add-site-tab').removeClass('NB-active');
            $tab.addClass('NB-active');

            this.$('.NB-add-site-tab-pane').removeClass('NB-active');
            this.$('.NB-add-site-' + tab_id + '-tab').addClass('NB-active');

            this.render_active_tab();
            this.update_tab_overflow();
        }
    },

    toggle_view_mode: function (e) {
        var $toggle = $(e.currentTarget);
        var mode = $toggle.data('mode');

        console.log('[AddSite] toggle_view_mode clicked, mode:', mode, 'current:', this.view_mode);

        if (!mode || mode === this.view_mode) return;

        this.view_mode = mode;

        // Save preference
        NEWSBLUR.assets.save_preferences({ 'add_site_view_mode': mode });

        this.$('.NB-add-site-view-toggle').removeClass('NB-active');
        $toggle.addClass('NB-active');

        // If switching to list mode on search tab with results, re-search to get stories
        if (mode === 'list' && this.active_tab === 'search' && this.search_query) {
            this.perform_search();
            return;
        }

        // Re-render the active tab to switch view mode
        this.render_active_tab();
    },

    open_style_popover: function (e) {
        e.preventDefault();
        e.stopPropagation();

        if (this.style_popover && this.style_popover.is_open) {
            this.style_popover.close();
            return;
        }

        this.style_popover = new NEWSBLUR.AddSiteStylePopover({
            anchor: this.$('.NB-add-site-style-button'),
            add_site_view: this
        });
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

    force_search: function () {
        this.search_query = this.$('.NB-add-site-search-input').val().trim();
        this.perform_search();
    },

    clear_search: function () {
        this.$('.NB-add-site-search-input').val('');
        this.$('.NB-add-site-search-tab .NB-add-site-search-clear').addClass('NB-hidden');
        this.search_query = '';
        this.search_state.results = [];
        this.render_search_tab();
    },

    handle_source_search_input: function (e) {
        var $input = $(e.currentTarget);
        var query = $input.val().trim();
        var $clear = $input.closest('.NB-add-site-search-wrapper').find('.NB-add-site-search-clear');
        $clear.toggleClass('NB-hidden', query.length === 0);
    },

    clear_youtube_search: function () {
        this.$('.NB-add-site-youtube-search').val('');
        this.$('.NB-add-site-youtube-tab .NB-add-site-search-clear').addClass('NB-hidden');
        this.youtube_state.results = [];
        this.youtube_state.query = '';
        this.render_youtube_popular();
    },

    clear_reddit_search: function () {
        this.$('.NB-add-site-reddit-search').val('');
        this.$('.NB-add-site-reddit-tab .NB-add-site-search-clear').addClass('NB-hidden');
        this.reddit_state.results = [];
        this.reddit_state.query = '';
        this.render_reddit_popular();
    },

    clear_newsletter_search: function () {
        this.$('.NB-add-site-newsletters-search').val('');
        this.$('.NB-add-site-newsletters-tab .NB-add-site-search-clear').addClass('NB-hidden');
        this.newsletters_state.results = [];
        this.newsletters_state.query = '';
        this.render_newsletters_popular();
    },

    clear_podcast_search: function () {
        this.$('.NB-add-site-podcasts-search').val('');
        this.$('.NB-add-site-podcasts-tab .NB-add-site-search-clear').addClass('NB-hidden');
        this.podcasts_state.results = [];
        this.podcasts_state.query = '';
        this.render_podcasts_popular();
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
            v: 2,
            include_stories: this.view_mode === 'list' ? 'true' : 'false'
        }, function (data) {
            // Ignore stale responses from previous searches
            if (current_version !== self.search_version) {
                return;
            }
            self.search_state.is_loading = false;
            var results = [];
            if (data && _.isArray(data)) {
                results = data;
            } else if (data && data.feeds) {
                results = data.feeds;
            }
            // Apply sort preference to search results
            self.search_state.results = self.sort_feeds(results);
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

    try_feed: function (e) {
        var $btn = $(e.currentTarget);
        var feed_id = $btn.data('feed-id');

        if (feed_id) {
            NEWSBLUR.reader.load_feed_in_tryfeed_view(feed_id);
        }
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

        $btn.addClass('NB-loading').text('Adding...');

        NEWSBLUR.assets.save_add_url(feed_url, folder, function (data) {
            if (data.code > 0 || data.feed) {
                $card.addClass('NB-subscribed');

                // Refresh feed list without opening the feed
                NEWSBLUR.assets.load_feeds();

                // Convert button to "Open Site" with feed ID stored for later
                $btn.removeClass('NB-loading NB-add-site-subscribe-btn NB-modal-submit-grey')
                    .addClass('NB-add-site-open-btn NB-modal-submit-green')
                    .text('Open Site')
                    .data('feed-id', data.feed ? data.feed.id : null);
            } else {
                $btn.removeClass('NB-loading').addClass('NB-error').text('Error');
                console.log('Subscribe error:', data.message);
                setTimeout(function () {
                    $btn.removeClass('NB-error').text('Add');
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

    open_feed_stats: function (e) {
        var $btn = $(e.currentTarget);
        var feed_id = $btn.data('feed-id');

        if (feed_id) {
            NEWSBLUR.assets.load_canonical_feed(feed_id, function () {
                NEWSBLUR.reader.open_feed_statistics_modal(feed_id);
            });
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
