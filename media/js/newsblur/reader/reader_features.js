// reader_features.js: The Features & Tips modal. Showcases the nine flagship
// features from the welcome page in a sidebar + detail pane layout. Replaces
// the old paged Tips & Tutorial modal.
NEWSBLUR.ReaderFeatures = function (options) {
    var defaults = {
        width: 1050,
        feature_id: 'training'
    };

    _.bindAll(this, 'close');

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.active_feature_id = this.options.feature_id;
    this.runner();
};

NEWSBLUR.ReaderFeatures.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderFeatures.prototype.constructor = NEWSBLUR.ReaderFeatures;

_.extend(NEWSBLUR.ReaderFeatures.prototype, {

    // Each feature owns a color that carries from the sidebar rail through the
    // detail pane. Icons live in /media/embed/icons/nouns/ and are tinted with
    // the same CSS filters as the splash nav's Features dropdown.
    FEATURES: [
        {
            id: 'training',
            name: 'Intelligence Training',
            icon: 'train.svg',
            color: 'blue',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'Train NewsBlur to show you what you want and hide what you don\'t. You\'re in control, not an algorithm.',
            screenshots: [
                { src: 'training.png', caption: 'Thumbs up and down on authors, tags, and titles' },
                { src: 'text-training.png', caption: 'Full-text training on the Archive plan' }
            ],
            steps: [
                'Open the trainer for any feed',
                'Thumbs up authors, tags, or title keywords you like',
                'Thumbs down what you don\'t want to see',
                'Stories are highlighted green (like) or hidden (dislike)',
                'Train across folders or globally on Premium Archive'
            ],
            tips: [
                'In the Feed view, click tags and authors right in the story header to train them. Each click rotates between like, dislike, and neutral.',
                'The intelligence slider in the bottom-left corner filters between all stories, unread stories, and focus stories.',
                'Title training matches phrases, so train just the words that matter and future stories with those words follow suit.'
            ],
            faqs: [
                { q: 'Is training free?', a: 'Yes. Training on authors, tags, and title keywords is free. Full-text training on story content requires Premium Archive.' },
                { q: 'Can I undo training?', a: 'Absolutely. Open the trainer and remove any thumbs up or down to reset it.' },
                { q: 'Does training work across all my feeds?', a: 'You can train per-feed for free, or per-folder and globally on Premium Archive.' }
            ],
            try_label: 'Open the Intelligence Trainer'
        },
        {
            id: 'ask-ai',
            name: 'Ask AI & Daily Briefing',
            icon: 'prompt.svg',
            color: 'coral',
            tier: 'Archive',
            tier_class: 'archive',
            subtitle: 'AI-powered story analysis and personalized daily summaries from your news feeds.',
            screenshots: [
                { src: 'ask-ai.png', caption: 'Ask AI with a choice of models' },
                { src: 'briefing.png', caption: 'Daily Briefing with story summaries' }
            ],
            steps: [
                'Select any story and click "Ask AI"',
                'Choose your preferred AI model: Claude, GPT, Gemini, or Grok',
                'Ask questions, get summaries, or request key points',
                'Enable Daily Briefing for an AI-generated summary of your top stories',
                'Customize briefing sections and delivery schedule'
            ],
            tips: [
                'Switch models per question. Each answer is labeled with the model that wrote it.',
                'The Daily Briefing appears at the top of your sidebar, with sections for top stories, long reads, and custom sections you define.',
                'Ask AI can transcribe a podcast or video first, then answer questions about it.'
            ],
            faqs: [
                { q: 'Which AI models are available?', a: 'Claude (Anthropic), GPT (OpenAI), Gemini (Google), and Grok (xAI). Switch between them at any time.' },
                { q: 'Does Ask AI work with audio and video?', a: 'Yes, it can transcribe audio and video content and then answer questions about it.' },
                { q: 'What is the Daily Briefing?', a: 'An AI-generated summary of your top stories, with sections for top stories, long reads, widely covered topics, and custom sections you define.' }
            ],
            try_label: 'Open your Daily Briefing'
        },
        {
            id: 'web-feeds',
            name: 'Web Feeds',
            icon: 'web-feed.svg',
            color: 'purple',
            tier: 'Archive',
            tier_class: 'archive',
            subtitle: 'Follow any website, even ones that don\'t publish an RSS feed.',
            screenshots: [
                { src: 'web-feeds.png', caption: 'Turning any page into a feed' }
            ],
            steps: [
                'Paste any URL into the "Add Site" dialog',
                'If no RSS feed is found, NewsBlur offers to create a Web Feed',
                'NewsBlur monitors the page for changes automatically',
                'New content appears in your feed just like regular RSS',
                'Works with social media profiles, job boards, product pages, and more'
            ],
            tips: [
                'Follow social profiles, job boards, changelogs, and product pages that never offered a feed.',
                'Web feeds train, search, and organize exactly like RSS feeds.',
                'Web feeds are checked on the same schedule as regular feeds, faster on higher plans.'
            ],
            faqs: [
                { q: 'What sites can I follow?', a: 'Any public web page: Twitter profiles, Reddit threads, GitHub repos, product pages, job boards, government sites, and more.' },
                { q: 'Is this different from RSS?', a: 'Yes. Web Feeds monitor a page\'s HTML for changes, while RSS reads a structured feed file. Web Feeds work even when sites don\'t offer RSS.' },
                { q: 'What plan do I need?', a: 'Web Feeds require Premium Archive or Premium Pro, since page-scraping is more resource-intensive than RSS fetching.' }
            ],
            try_label: 'Add a site'
        },
        {
            id: 'newsletters',
            name: 'Email Newsletters',
            icon: 'email.svg',
            color: 'pink',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'Read your email newsletters in your news reader, not your inbox.',
            screenshots: [
                { src: 'newsletters.png', caption: 'Newsletters appearing as feeds' }
            ],
            steps: [
                'Find your unique NewsBlur email address in the Email Newsletters dialog',
                'Forward or subscribe newsletters to that address',
                'Each newsletter sender becomes its own feed',
                'Train, tag, search, and organize newsletters like any feed',
                'Your inbox stays clean'
            ],
            tips: [
                'Subscribe to newsletters with your NewsBlur address directly and they never touch your inbox.',
                'Each sender becomes its own feed, so you can train away the newsletters that overstay their welcome.'
            ],
            faqs: [
                { q: 'Do I get a unique email address?', a: 'Yes, every NewsBlur account has a unique email address for receiving newsletters.' },
                { q: 'Can I train on newsletter content?', a: 'Yes, all intelligence training features work on newsletters just like regular feeds.' },
                { q: 'Is this available on the free plan?', a: 'Yes, email newsletters are a free feature.' }
            ],
            try_label: 'Set up newsletters'
        },
        {
            id: 'search',
            name: 'Full-Text Search',
            icon: 'search.svg',
            color: 'teal',
            tier: 'Premium',
            tier_class: 'premium',
            subtitle: 'Search across all your subscriptions with Elasticsearch-powered full-text search.',
            screenshots: [
                { src: 'search.jpg', caption: 'Search results across subscriptions' }
            ],
            steps: [
                'Press the search icon or hit the / key',
                'Type keywords, phrases, or combinations',
                'Search within a single feed, a folder, or across everything',
                'Results show matching stories with highlighted terms',
                'Save searches as feeds for ongoing monitoring'
            ],
            tips: [
                'Press / anywhere to jump straight to the search field.',
                'Save a search as a feed and it keeps collecting matches in your sidebar.',
                'On Premium Archive, search reaches every story ever archived, not just recent ones.'
            ],
            faqs: [
                { q: 'What plan do I need?', a: 'Full-text search requires Premium or higher.' },
                { q: 'Can I search saved stories?', a: 'Yes, saved stories and their tags are fully searchable.' },
                { q: 'How far back does search go?', a: 'On Premium, search covers your recent stories. On Premium Archive, every story ever archived is searchable.' }
            ],
            try_label: 'Search your stories'
        },
        {
            id: 'archive',
            name: 'Story Archive',
            icon: 'archive.svg',
            color: 'orange',
            tier: 'Archive',
            tier_class: 'archive',
            subtitle: 'Every story archived and searchable forever. Your personal knowledge base.',
            screenshots: [
                { src: 'archive.png', caption: 'Unread stories going back months' }
            ],
            steps: [
                'Subscribe to Premium Archive',
                'Every new story is archived permanently',
                'When you subscribe to a new feed, its history is back-filled',
                'Stories never expire or disappear',
                'Search your entire archive with full-text search'
            ],
            tips: [
                'Subscribe to a new feed and its entire available history back-fills automatically.',
                'Unread stories never expire, so read at your own pace.',
                'Paired with full-text search, the archive doubles as a personal knowledge base.'
            ],
            faqs: [
                { q: 'How far back does the archive go?', a: 'When you subscribe to a feed, NewsBlur back-fills its entire available history. Going forward, every story is kept forever.' },
                { q: 'What happens if I downgrade?', a: 'Your archived stories remain accessible, but new stories follow the standard retention policy.' },
                { q: 'Can I search the archive?', a: 'Yes, every archived story is fully searchable.' }
            ],
            try_label: 'Browse all your stories'
        },
        {
            id: 'saved',
            name: 'Saved Stories & Tags',
            icon: 'tag.svg',
            color: 'green',
            tier: 'Premium',
            tier_class: 'premium',
            subtitle: 'Save stories for later and organize them with custom tags. Your personal clipping library, searchable and shareable.',
            screenshots: [
                { src: 'saved.png', caption: 'Saved stories organized with custom tags' }
            ],
            steps: [
                'Save any story with one click or the s key',
                'Add custom tags to organize saved stories by topic',
                'Browse saved stories by tag in the sidebar',
                'Search across all saved stories and tags',
                'Each tag gets its own RSS feed for sharing or piping into other tools'
            ],
            tips: [
                'Press s to save the story you\'re reading.',
                'Every tag gets its own RSS feed. Share the link or pipe it into IFTTT or Zapier.',
                'Saved stories are kept forever, even from feeds you later unsubscribe from.'
            ],
            faqs: [
                { q: 'How many stories can I save?', a: 'There\'s no limit. Save as many stories as you want and they\'re kept forever.' },
                { q: 'Can I share tagged collections?', a: 'Yes. Every tag generates its own RSS feed, so you can subscribe to it from another reader or share the link.' },
                { q: 'What plan do I need?', a: 'Saving stories is available on all plans. Tags and tag RSS feeds require Premium or higher.' }
            ],
            try_label: 'Open your saved stories'
        },
        {
            id: 'native-apps',
            name: 'Native Apps',
            icon: 'dialog-goodies.svg',
            color: 'gold',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'First-class native apps built for each platform, not web wrappers. Everything you love about NewsBlur, on every device.',
            screenshots: [
                { src: 'native-apps.png', caption: 'NewsBlur on iOS with the full feature set' }
            ],
            steps: [
                'Download NewsBlur from the App Store or Google Play',
                'Sign in and your feeds, training, and saved stories sync instantly',
                'Read offline with automatic background refresh',
                'Train stories, search, share, and tag just like on the web',
                'Use widgets to see unread counts and stories at a glance'
            ],
            tips: [
                'Stories cache for offline reading with automatic background refresh.',
                'Home-screen widgets show unread counts and the latest stories at a glance.',
                'Prefer a third-party app? The open API powers Reeder, ReadKit, Unread, and dozens more.'
            ],
            faqs: [
                { q: 'Are the apps free?', a: 'Yes, both the iOS and Android apps are free. Premium features in the apps match your subscription on the web.' },
                { q: 'Do the apps work offline?', a: 'Yes. Stories are cached locally and background refresh keeps them up to date.' },
                { q: 'Are the apps open source?', a: 'Yes, both apps are open source and actively developed on GitHub.' }
            ],
            try_label: 'Get the apps'
        },
        {
            id: 'clustering',
            name: 'Story Clustering',
            icon: 'stack.svg',
            color: 'indigo',
            tier: 'Archive',
            tier_class: 'archive',
            subtitle: 'When multiple feeds cover the same story, NewsBlur groups them together so you only see it once.',
            screenshots: [
                { src: 'story-clustering-titles.png', caption: 'Clustered stories in the titles view' },
                { src: 'story-clustering-detail.png', caption: 'Rich cards for alternative sources' }
            ],
            steps: [
                'When a feed updates, NewsBlur checks for duplicates across all your subscriptions',
                'Title matching catches exact and fuzzy duplicates',
                'Semantic matching finds stories about the same topic with different headlines',
                'Duplicates fold underneath the highest-scoring version in your river',
                'Click any source to read that version instead, or mark all duplicates as read at once'
            ],
            tips: [
                'Control clustering per feed from the feed options popover, or globally in Preferences > Stories.',
                'Enable "mark all as read" so reading one version clears every duplicate.',
                'Click any source card on a clustered story to read that version instead.'
            ],
            faqs: [
                { q: 'How are duplicates detected?', a: 'Two layers: title matching normalizes headlines for exact and fuzzy matches, and semantic matching uses Elasticsearch to catch the same event under completely different headlines.' },
                { q: 'Can I turn clustering off?', a: 'Yes. Toggle "Keep stories separate" in the feed options popover or in Preferences.' },
                { q: 'What plan do I need?', a: 'All users see clustered stories on popular feeds. Premium Archive unlocks full control: toggles, display styles, and auto mark-as-read.' }
            ],
            try_label: 'Open clustering preferences'
        }
    ],

    // The secondary list mirrors the "More Features" column of the splash nav
    // dropdown. Lighter panes: description, screenshot, and tips. MCP and CLI
    // carry the fuller content from their own feature pages.
    MORE_FEATURES: [
        {
            id: 'river',
            name: 'River of News',
            icon: 'all-stories.svg',
            color: 'blue',
            tier: 'Premium',
            tier_class: 'premium',
            subtitle: 'Read all feeds in a folder as one scrollable stream, in chronological order. Combined with training, the river surfaces the best stories across your subscriptions.',
            screenshots: [
                { src: 'river.png', caption: 'A folder of feeds read as one stream' }
            ],
            tips: [
                'Open any folder title to read all of its feeds at once. All Site Stories is the river of everything.',
                'Sort the river oldest-first or newest-first from the feed options popover.'
            ],
            try_label: 'Open All Site Stories'
        },
        {
            id: 'notifications',
            name: 'Notifications',
            icon: 'dialog-notifications.svg',
            color: 'coral',
            tier: 'Premium',
            tier_class: 'premium',
            subtitle: 'Get notified the moment a feed publishes a new story. Per-feed notifications on web, email, iOS, and Android, filtered by your training.',
            screenshots: [
                { src: 'notifications.png', caption: 'Per-feed notification settings' }
            ],
            tips: [
                'Filter notifications to focus-only stories so your training decides what pings you.',
                'Each feed can notify a different way: browser push, email, iOS, or Android.'
            ],
            try_label: 'Set up notifications'
        },
        {
            id: 'text-view',
            name: 'Text View',
            icon: 'content-view-text.svg',
            color: 'purple',
            tier: 'Premium',
            tier_class: 'premium',
            subtitle: 'Many feeds only include a summary. Text view extracts the full story from the original website and displays it right in NewsBlur, with clean formatting and no clutter.',
            screenshots: [
                { src: 'text-view.png', caption: 'Full articles extracted from the original site' }
            ],
            tips: [
                'Press the Text tab on any story to fetch the full article.',
                'The view you pick is remembered per-site, so summary-only feeds can default to Text.'
            ]
        },
        {
            id: 'changes',
            name: 'Track Changes',
            icon: 'history.svg',
            color: 'green',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'See how a story evolves after it\'s first published. NewsBlur tracks revisions and shows you a diff of what changed, highlighted in green and red.',
            screenshots: [
                { src: 'changes.png', caption: 'A story diff with additions and deletions' }
            ],
            tips: [
                'Useful for developing news stories, corrected articles, and evolving product announcements.',
                'Green marks additions, red marks deletions.'
            ]
        },
        {
            id: 'themes',
            name: 'Themes & Customization',
            icon: 'menu-theme.svg',
            color: 'gold',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'Light, dark, and auto themes across web, iOS, and Android. Fonts, text sizes, line spacing, density, and image previews, all customizable per-feed.',
            screenshots: [
                { src: 'themes.png', caption: 'Dark mode and reading customization' }
            ],
            tips: [
                'Switch themes instantly from the bottom of the Manage menu.',
                'Auto theme follows your system\'s light and dark schedule.'
            ],
            try_label: 'Open preferences'
        },
        {
            id: 'shortcuts',
            name: 'Keyboard Shortcuts',
            icon: 'dialog-keyboard.svg',
            color: 'orange',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'Navigate everything without touching the mouse. Open feeds, scroll stories, mark as read, save, share, and train, all from the keyboard.',
            screenshots: [
                { src: 'shortcuts.png', caption: 'The full shortcut list' }
            ],
            tips: [
                'Press ? anytime to see the full shortcut list.',
                'j and k move through stories; n jumps to the next unread.',
                'Shift+u hides the sidebar for distraction-free reading.'
            ],
            try_label: 'See all shortcuts'
        },
        {
            id: 'integrations',
            name: 'IFTTT & Zapier',
            icon: 'link.svg',
            color: 'teal',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'Connect NewsBlur to hundreds of services. Save stories to Pocket, Instapaper, Evernote, or Notion; post shares to Slack; trigger custom workflows from your training.',
            screenshots: [
                { src: 'integrations.png', caption: 'NewsBlur connected to other services' }
            ],
            tips: [
                'Every saved-story tag has its own RSS feed, perfect for piping into IFTTT or Zapier.',
                'The full NewsBlur API is open and documented for custom integrations.'
            ],
            try_label: 'Browse goodies & integrations'
        },
        {
            id: 'blurblog',
            name: 'Shared Stories & Blurblog',
            icon: 'global-shares.svg',
            color: 'pink',
            tier: 'Free',
            tier_class: 'free',
            subtitle: 'Share stories with your own comments on your public blurblog. Follow friends to see what they\'re reading and sharing.',
            screenshots: [
                { src: 'blurblog.png', caption: 'A blurblog of shared stories' }
            ],
            tips: [
                'Share a story with a comment and it\'s published on your blurblog, followable via RSS or on the web.',
                'Premium users can make their blurblog private.'
            ],
            try_label: 'Set up your blurblog'
        },
        {
            id: 'mcp',
            name: 'MCP Server',
            icon: 'mcp-agent.svg',
            color: 'indigo',
            tier: 'Archive',
            tier_class: 'archive',
            subtitle: 'Connect AI agents to your NewsBlur account. Read feeds, triage stories, train classifiers, and manage subscriptions from Claude Code, Codex, or any MCP-compatible tool.',
            steps_title: 'What your agent can do',
            steps: [
                'Read your feeds: unread stories, folders, search, and saved stories by tag',
                'Get an AI-curated daily briefing with top stories and long reads',
                'Take action: mark as read, save with tags and notes, subscribe, share',
                'Train intelligence: like or dislike authors, tags, titles, and feeds',
                'Discover new feeds by topic and search your Reading Archive',
                'Use prompt templates for inbox triage, topic research, and feed audits'
            ],
            tips: [
                'Add it to Claude Code with: claude mcp add --transport http newsblur https://newsblur.com/mcp/',
                '28 tools are available, covering reading, actions, training, and discovery.'
            ],
            faqs: [
                { q: 'What is MCP?', a: 'The Model Context Protocol is an open standard for connecting AI agents to external tools and data. It lets Claude, Codex, and other AI assistants interact with NewsBlur on your behalf.' },
                { q: 'Is my data safe?', a: 'The MCP server uses OAuth, the same authentication as third-party apps. You authorize through your browser and can revoke access at any time.' },
                { q: 'What plan do I need?', a: 'MCP server access requires Premium Archive or Premium Pro.' }
            ]
        },
        {
            id: 'cli',
            name: 'CLI Tool',
            icon: 'cli-terminal.svg',
            color: 'cyan',
            tier: 'Archive',
            tier_class: 'archive',
            subtitle: 'Everything the MCP server can do, from your terminal. Read feeds, search stories, manage subscriptions, and train classifiers. Pipe to jq or script your workflows.',
            steps_title: 'Get started',
            steps: [
                'Install with: uv pip install newsblur-cli',
                'Run newsblur auth login to authorize via OAuth',
                'Read unread stories with: newsblur stories list',
                'Search everything with: newsblur stories search "machine learning"',
                'Give your AI agent the skill: npx skills add samuelclay/newsblur-cli-skill'
            ],
            tips: [
                'Commands output JSON you can pipe straight to jq.',
                'Point it at a self-hosted instance with --server or the NEWSBLUR_SERVER environment variable.'
            ],
            faqs: [
                { q: 'How does authentication work?', a: 'The login command opens your browser for OAuth authorization. Your token is stored locally and never sent anywhere except the NewsBlur API.' },
                { q: 'What\'s the difference between CLI and MCP?', a: 'The CLI is a standalone terminal tool you run directly. The MCP server lets AI agents connect on your behalf. Both use the same API and have the same capabilities.' },
                { q: 'What plan do I need?', a: 'CLI access requires Premium Archive or Premium Pro.' }
            ]
        }
    ],

    runner: function () {
        this.make_modal();
        this.open_modal();
        this.select_feature(this.active_feature_id, { skip_animation: true });

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },

    make_modal: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-features NB-modal' }, [
            $.make('div', { className: 'NB-features-header' }, [
                $.make('h2', { className: 'NB-modal-title' }, [
                    $.make('div', { className: 'NB-icon' }),
                    'Features & Tips',
                    $.make('div', { className: 'NB-icon-dropdown' })
                ]),
                $.make('div', { className: 'NB-features-header-subtitle' }, 'Everything NewsBlur can do, and how to try it')
            ]),
            $.make('div', { className: 'NB-features-body' }, [
                $.make('div', { className: 'NB-features-rail' }, this.make_rail_items()),
                $.make('div', { className: 'NB-features-detail' })
            ])
        ]);
    },

    make_rail_items: function () {
        var self = this;

        var make_item = function (feature, secondary) {
            return $.make('div', {
                className: 'NB-features-rail-item NB-features-rail-item-' + feature.id +
                    (secondary ? ' NB-features-rail-item-secondary' : ''),
                role: 'button',
                'data-feature': feature.id
            }, [
                $.make('div', { className: 'NB-features-icon-chip NB-features-chip-' + feature.color }, [
                    $.make('img', {
                        className: 'NB-features-icon NB-features-icon-' + feature.color,
                        src: NEWSBLUR.Globals.MEDIA_URL + '/embed/icons/nouns/' + feature.icon
                    })
                ]),
                $.make('div', { className: 'NB-features-rail-name' }, feature.name)
            ]);
        };

        var items = _.map(this.FEATURES, function (feature) {
            return make_item(feature, false);
        });
        items.push($.make('div', { className: 'NB-features-rail-divider' }, 'More Features'));
        _.each(this.MORE_FEATURES, function (feature) {
            items.push(make_item(feature, true));
        });

        return items;
    },

    make_detail: function (feature) {
        var $screenshots = _.map(feature.screenshots || [], function (screenshot) {
            return $.make('div', { className: 'NB-features-shot' }, [
                $.make('img', {
                    src: NEWSBLUR.Globals.MEDIA_URL + '/img/features/' + screenshot.src,
                    alt: screenshot.caption
                }),
                $.make('div', { className: 'NB-features-shot-caption' }, screenshot.caption)
            ]);
        });

        var $steps = _.map(feature.steps || [], function (step, i) {
            return $.make('li', { className: 'NB-features-step' }, [
                $.make('span', { className: 'NB-features-step-number NB-features-accent-' + feature.color }, '' + (i + 1)),
                $.make('span', { className: 'NB-features-step-text' }, step)
            ]);
        });

        var $tips = _.map(feature.tips, function (tip) {
            return $.make('li', { className: 'NB-features-tip' }, [
                $.make('span', { className: 'NB-features-tip-marker NB-features-accent-bg-' + feature.color }),
                $.make('span', { className: 'NB-features-tip-text' }, tip)
            ]);
        });

        var $faqs = _.map(feature.faqs || [], function (faq) {
            return $.make('div', { className: 'NB-features-faq-item' }, [
                $.make('div', { className: 'NB-features-faq-q' }, faq.q),
                $.make('div', { className: 'NB-features-faq-a' }, faq.a)
            ]);
        });

        return $.make('div', { className: 'NB-features-detail-inner' }, [
            $.make('div', { className: 'NB-features-detail-header' }, [
                $.make('div', { className: 'NB-features-icon-chip NB-features-icon-chip-large NB-features-chip-' + feature.color }, [
                    $.make('img', {
                        className: 'NB-features-icon NB-features-icon-' + feature.color,
                        src: NEWSBLUR.Globals.MEDIA_URL + '/embed/icons/nouns/' + feature.icon
                    })
                ]),
                $.make('div', { className: 'NB-features-detail-heading' }, [
                    $.make('div', { className: 'NB-features-detail-name-row' }, [
                        $.make('h3', { className: 'NB-features-detail-name' }, feature.name),
                        $.make('div', { className: 'NB-feature-section-badge NB-feature-badge-' + feature.tier_class }, feature.tier)
                    ]),
                    $.make('div', { className: 'NB-features-detail-subtitle' }, feature.subtitle)
                ])
            ]),
            ($screenshots.length && $.make('div', { className: 'NB-features-shots NB-features-shots-' + $screenshots.length }, $screenshots)),
            ($steps.length && $.make('div', { className: 'NB-features-section' }, [
                $.make('h4', { className: 'NB-features-section-title' }, feature.steps_title || 'How it works'),
                $.make('ol', { className: 'NB-features-steps' }, $steps)
            ])),
            $.make('div', { className: 'NB-features-section' }, [
                $.make('h4', { className: 'NB-features-section-title' }, 'Tips'),
                $.make('ul', { className: 'NB-features-tips' }, $tips)
            ]),
            ($faqs.length && $.make('div', { className: 'NB-features-section' }, [
                $.make('h4', { className: 'NB-features-section-title' }, 'Questions'),
                $.make('div', { className: 'NB-features-faq' }, $faqs)
            ])),
            (feature.try_label && $.make('div', { className: 'NB-features-try' }, [
                $.make('div', { className: 'NB-features-try-button NB-modal-submit-button NB-modal-submit-green' }, [
                    feature.try_label,
                    ' ',
                    $.make('span', { className: 'NB-raquo' }, '&raquo;')
                ])
            ]))
        ]);
    },

    select_feature: function (feature_id, options) {
        options = options || {};
        var feature = _.detect(this.FEATURES.concat(this.MORE_FEATURES), function (f) { return f.id == feature_id; });
        if (!feature) return;

        this.active_feature_id = feature_id;

        $('.NB-features-rail-item', this.$modal).removeClass('NB-active');
        $('.NB-features-rail-item-' + feature_id, this.$modal).addClass('NB-active');

        var $detail = $('.NB-features-detail', this.$modal);
        var $inner = this.make_detail(feature);

        $detail.empty().append($inner).scrollTop(0);

        if (!options.skip_animation) {
            $inner.addClass('NB-features-detail-entering');
            _.defer(function () {
                $inner.removeClass('NB-features-detail-entering');
            });
        }
    },

    // Each Try button closes the modal and drops the user directly into the
    // feature's own UI. Tier-gated features rely on their own upsells.
    try_feature: function (feature_id) {
        this.close();

        switch (feature_id) {
            case 'training':
                NEWSBLUR.reader.open_trainer_modal();
                break;
            case 'ask-ai':
                NEWSBLUR.reader.open_daily_briefing();
                break;
            case 'web-feeds':
                NEWSBLUR.reader.open_add_feed_modal();
                break;
            case 'newsletters':
                NEWSBLUR.reader.open_newsletters_modal();
                break;
            case 'search':
                NEWSBLUR.reader.open_river_stories();
                _.delay(function () {
                    if (NEWSBLUR.app.story_titles_header && NEWSBLUR.app.story_titles_header.search_view) {
                        NEWSBLUR.app.story_titles_header.search_view.focus();
                    }
                }, 750);
                break;
            case 'archive':
                NEWSBLUR.reader.open_river_stories();
                break;
            case 'saved':
                NEWSBLUR.reader.open_starred_stories();
                break;
            case 'native-apps':
                NEWSBLUR.reader.open_goodies_modal();
                break;
            case 'clustering':
                NEWSBLUR.reader.open_preferences_modal();
                break;
            case 'river':
                NEWSBLUR.reader.open_river_stories();
                break;
            case 'notifications':
                NEWSBLUR.reader.open_notifications_modal();
                break;
            case 'themes':
                NEWSBLUR.reader.open_preferences_modal();
                break;
            case 'shortcuts':
                NEWSBLUR.reader.open_keyboard_shortcuts_modal();
                break;
            case 'integrations':
                NEWSBLUR.reader.open_goodies_modal();
                break;
            case 'blurblog':
                NEWSBLUR.reader.open_friends_modal();
                break;
        }
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-features-rail-item' }, function ($t, $p) {
            e.preventDefault();

            self.select_feature($t.data('feature'));
        });
        $.targetIs(e, { tagSelector: '.NB-features-try-button' }, function ($t, $p) {
            e.preventDefault();

            self.try_feature(self.active_feature_id);
        });
    }

});
