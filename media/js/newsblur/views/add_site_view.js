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
        "click .NB-add-site-search-tab .NB-add-site-search-btn": "force_search",
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
        "click .NB-add-site-webfeed-folder-add-icon": "toggle_webfeed_folder_input",
        "click .NB-add-site-webfeed-folder-submit": "save_webfeed_folder",
        "keypress .NB-add-site-webfeed-folder-name": "handle_webfeed_folder_keypress",
        // YouTube tab events
        "input .NB-add-site-youtube-search": "handle_youtube_search_input",
        "click .NB-add-site-youtube-tab .NB-add-site-tab-search-btn": "perform_youtube_search",
        "keypress .NB-add-site-youtube-search": "handle_youtube_search_keypress",
        // Reddit tab events
        "input .NB-add-site-reddit-search": "handle_reddit_search_input",
        "click .NB-add-site-reddit-tab .NB-add-site-tab-search-btn": "perform_reddit_combined_search",
        "keypress .NB-add-site-reddit-search": "handle_reddit_search_keypress",
        // Newsletter tab events
        "input .NB-add-site-newsletters-search": "handle_newsletter_search_input",
        "click .NB-add-site-newsletters-tab .NB-add-site-tab-search-btn": "perform_newsletter_search_or_convert",
        "keypress .NB-add-site-newsletters-search": "handle_newsletter_search_keypress",
        // Inline section search events
        "input .NB-add-site-popular-search": "handle_popular_search_input",
        "click .NB-add-site-popular-tab .NB-add-site-section-search-clear": "clear_popular_search",
        "click .NB-add-site-youtube-tab .NB-add-site-section-search-clear": "clear_youtube_search",
        "click .NB-add-site-reddit-tab .NB-add-site-section-search-clear": "clear_reddit_search",
        "click .NB-add-site-newsletters-tab .NB-add-site-section-search-clear": "clear_newsletter_search",
        "click .NB-add-site-podcasts-tab .NB-add-site-section-search-clear": "clear_podcast_search",
        // Filter badge close
        "click .NB-add-site-section-filter-badge-close": "clear_active_tab_filter",
        // Podcast tab events
        "input .NB-add-site-podcasts-search": "handle_podcast_search_input",
        "click .NB-add-site-podcasts-tab .NB-add-site-tab-search-btn": "perform_podcast_search",
        "keypress .NB-add-site-podcasts-search": "handle_podcast_search_keypress",
        // Google News events
        "click .NB-add-site-google-news-subscribe-btn": "handle_google_news_subscribe",
        "input .NB-add-site-google-news-search-input": "handle_google_news_input",
        "keypress .NB-add-site-google-news-search-input": "handle_google_news_search_keypress",
        "click .NB-add-site-google-news-folder-add-icon": "toggle_google_news_folder_input",
        "click .NB-add-site-google-news-folder-submit": "save_google_news_folder",
        "keypress .NB-add-site-google-news-folder-name": "handle_google_news_folder_keypress",
        // Trending tab events
        "change .NB-add-site-trending-days": "handle_trending_days_change",
        "click .NB-add-site-trending-pill": "handle_trending_category_change",
        // Categories tab events
        "click .NB-add-site-category-card": "handle_category_click",
        "click .NB-add-site-category-back": "go_back_to_categories",
        // Web Feed tab events
        "click .NB-add-site-web-feed-tab .NB-add-site-tab-search-btn": "perform_webfeed_analyze",
        "keypress .NB-add-site-web-feed-search": "handle_webfeed_search_keypress",
        "click .NB-add-site-webfeed-variant-card:not(.NB-add-site-webfeed-hint-card)": "select_webfeed_variant",
        "click .NB-add-site-webfeed-hint-btn": "perform_webfeed_refine",
        "keypress .NB-add-site-webfeed-hint-input": "handle_webfeed_hint_keypress",
        "click .NB-add-site-webfeed-subscribe-btn": "subscribe_webfeed",
        "click .NB-add-site-webfeed-archive-banner": "open_webfeed_upgrade_modal",
        "input .NB-add-site-webfeed-staleness-slider": "update_webfeed_staleness",
        "change .NB-add-site-webfeed-unread-radio": "toggle_webfeed_unread",
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
        { id: 'web-feed', label: 'Web Feed', icon: '/media/img/icons/nouns/web-feed.svg', mono: true },
        { id: 'popular', label: 'Popular', icon: '/media/img/icons/heroicons-solid/fire.svg', mono: true },
        { id: 'youtube', label: 'YouTube', icon: '/media/img/icons/lucide/youtube.svg', mono: true },
        { id: 'reddit', label: 'Reddit', icon: '/media/img/icons/phosphor-fill/reddit-logo-fill.svg', mono: true },
        { id: 'newsletters', label: 'Newsletters', icon: '/media/img/icons/lucide/mail.svg', mono: true },
        { id: 'podcasts', label: 'Podcasts', icon: '/media/img/icons/lucide/podcast.svg', mono: true },
        { id: 'google-news', label: 'Google News', icon: '/media/img/icons/lucide/newspaper.svg', mono: true }
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

    GOOGLE_NEWS_CATEGORIES: [
        { name: 'Anime & Manga', subcategories: [{name:'Anime Awards'},{name:'Anime Conventions'},{name:'Anime Dubs'},{name:'Anime Fan Art'},{name:'Anime Figurines'},{name:'Anime Film Releases'},{name:'Anime Gaming'},{name:'Anime Industry'},{name:'Anime Merchandise'},{name:'Anime Movie Box Office'},{name:'Anime Season Preview'},{name:'Anime Soundtrack'},{name:'Anime Streaming News'},{name:'Anime Studio News'},{name:'Anime Voice Actors'},{name:'Cosplay'},{name:'Fantasy Anime'},{name:'Horror Manga'},{name:'Isekai Anime'},{name:'Josei Manga'},{name:'Light Novel Adaptations'},{name:'Magical Girl Anime'},{name:'Manga Adaptations'},{name:'Manga Artists'},{name:'Manga Collectors'},{name:'Manga Sales Charts'},{name:'Manhwa'},{name:'Mecha Anime'},{name:'Romance Manga'},{name:'Sci-Fi Anime'},{name:'Seinen Anime'},{name:'Shojo Manga'},{name:'Shonen Anime'},{name:'Shonen Jump'},{name:'Slice of Life Anime'},{name:'Sports Anime'},{name:'Webtoon'}] },
        { name: 'Architecture', subcategories: [{name:'3D Printed Buildings'},{name:'Adaptive Reuse'},{name:'Affordable Housing Design'},{name:'Airport Architecture'},{name:'Architectural Photography'},{name:'Architectural Visualization'},{name:'Art Deco Architecture'},{name:'Biophilic Design'},{name:'Brutalist Architecture'},{name:'Building Information Modeling'},{name:'Deconstructivism'},{name:'Floating Architecture'},{name:'Gothic Architecture'},{name:'Green Building Design'},{name:'Historic Preservation'},{name:'Interior Architecture'},{name:'Landscape Architecture'},{name:'LEED Certification'},{name:'Mass Timber Construction'},{name:'Modernist Architecture'},{name:'Modular Construction'},{name:'Museum Architecture'},{name:'Net Zero Buildings'},{name:'Parametric Design'},{name:'Passive House Design'},{name:'Prefab Architecture'},{name:'Residential Architecture'},{name:'Sacred Architecture'},{name:'Skyscraper Design'},{name:'Smart Buildings'},{name:'Stadium Design'},{name:'Sustainable Architecture'},{name:'Tiny House Design'},{name:'Urban Planning'},{name:'Vernacular Architecture'}] },
        { name: 'Arts & Culture', subcategories: [{name:'Animation & Motion Graphics'},{name:'Art Auctions'},{name:'Art Criticism'},{name:'Art Exhibitions'},{name:'Art History'},{name:'Art Market'},{name:'Art Restoration'},{name:'Art Theft & Repatriation'},{name:'Arts Education'},{name:'Arts Funding & Grants'},{name:'Ballet & Dance'},{name:'Biennials & Art Fairs'},{name:'Ceramics & Pottery'},{name:'Contemporary Art'},{name:'Cultural Heritage'},{name:'Cultural Policy'},{name:'Digital Art & NFTs'},{name:'Film Festivals'},{name:'Folk Art & Crafts'},{name:'Galleries'},{name:'Illustration & Comics'},{name:'Indigenous Art'},{name:'Literary Fiction'},{name:'Museum News'},{name:'Opera'},{name:'Performing Arts'},{name:'Poetry'},{name:'Public Art & Murals'},{name:'Sculpture'},{name:'Street Art & Graffiti'},{name:'Textile Arts'},{name:'Theater & Broadway'}] },
        { name: 'Automotive', subcategories: [{name:'Auto Shows'},{name:'Automotive Industry'},{name:'Autonomous Vehicles'},{name:'BMW'},{name:'Budget Cars'},{name:'BYD'},{name:'Car Design'},{name:'Car Insurance'},{name:'Car Maintenance Tips'},{name:'Car Reviews'},{name:'Car Safety Recalls'},{name:'Car Technology'},{name:'Connected Cars'},{name:'Electric Trucks'},{name:'Electric Vehicles'},{name:'Ferrari'},{name:'Ford'},{name:'Formula 1'},{name:'Fuel Economy'},{name:'Honda'},{name:'Hybrid Vehicles'},{name:'Hyundai'},{name:'Luxury Cars'},{name:'Mercedes-Benz'},{name:'Minivans'},{name:'Motorcycle News'},{name:'NASCAR'},{name:'Off-Road Vehicles'},{name:'Pickup Trucks'},{name:'Porsche'},{name:'Rivian'},{name:'Self-Driving Cars'},{name:'Sports Cars'},{name:'SUVs'},{name:'Tesla'},{name:'Toyota'},{name:'Used Cars'}] },
        { name: 'Books & Reading', subcategories: [{name:'Audiobooks'},{name:'Author Interviews'},{name:'Bestsellers'},{name:'Book Adaptations'},{name:'Book Bans and Censorship'},{name:'Book Clubs'},{name:'Book Fairs and Festivals'},{name:'Book Recommendations'},{name:'Book Reviews'},{name:'Bookstores'},{name:'Children\'s Books'},{name:'Classic Literature'},{name:'Comic Books'},{name:'Ebooks and Digital Reading'},{name:'Fantasy Books'},{name:'Graphic Novels'},{name:'Historical Fiction'},{name:'Horror Books'},{name:'Indie Publishing'},{name:'Libraries'},{name:'Literary Awards'},{name:'Literary Fiction'},{name:'Memoir and Autobiography'},{name:'Mystery Books'},{name:'New Book Releases'},{name:'Nonfiction Books'},{name:'Poetry'},{name:'Publishing Industry'},{name:'Reading and Literacy'},{name:'Romance Books'},{name:'Science Fiction Books'},{name:'Self-Help Books'},{name:'Self-Publishing'},{name:'Thriller Books'},{name:'True Crime Books'},{name:'Young Adult Books'}] },
        { name: 'Business', subcategories: [{name:'B2B'},{name:'Bankruptcy'},{name:'Branding'},{name:'Business Analytics'},{name:'Business Development'},{name:'Business Ethics'},{name:'Business Intelligence'},{name:'Business Law'},{name:'Commercial Real Estate'},{name:'Competitive Analysis'},{name:'Consulting'},{name:'Corporate Finance'},{name:'Corporate Governance'},{name:'Corporate Social Responsibility'},{name:'Corporate Strategy'},{name:'Digital Transformation'},{name:'E-Commerce'},{name:'Executive Leadership'},{name:'Family Business'},{name:'Franchising'},{name:'Human Resources'},{name:'IPO'},{name:'Logistics'},{name:'Management'},{name:'Market Research'},{name:'Mergers and Acquisitions'},{name:'Outsourcing'},{name:'Private Equity'},{name:'Procurement'},{name:'Retail'},{name:'Revenue Growth'},{name:'Risk Management'},{name:'Sales Strategy'},{name:'Small Business'},{name:'Supply Chain'},{name:'Venture Capital'},{name:'Workplace Culture'}] },
        { name: 'Career & Job Market', subcategories: [{name:'AI Replacing Jobs'},{name:'Apprenticeship Programs'},{name:'Career Change Advice'},{name:'Career Coaching'},{name:'Diversity Hiring'},{name:'Employee Benefits Trends'},{name:'Employment Law Changes'},{name:'Four Day Work Week'},{name:'Freelancing Opportunities'},{name:'Gig Economy'},{name:'Hiring Trends'},{name:'Industry Job Growth'},{name:'Internship Opportunities'},{name:'Job Interview Tips'},{name:'Job Market for Graduates'},{name:'Job Market Outlook'},{name:'Job Search Strategies'},{name:'Labor Market Data'},{name:'LinkedIn Networking'},{name:'Minimum Wage Debate'},{name:'Professional Certifications'},{name:'Quiet Quitting'},{name:'Remote Work Trends'},{name:'Resume Writing Tips'},{name:'Return to Office'},{name:'Salary Negotiation'},{name:'Side Hustle Ideas'},{name:'Skills Development'},{name:'Startup Hiring'},{name:'Tech Layoffs'},{name:'Unemployment Rate'},{name:'Union Labor News'},{name:'Upskilling and Reskilling'},{name:'Work-Life Balance'},{name:'Worker Burnout'},{name:'Workplace AI Tools'},{name:'Workplace Culture'},{name:'Workplace Harassment'},{name:'Workplace Mental Health'}] },
        { name: 'Comedy & Humor', subcategories: [{name:'Absurdist Humor'},{name:'Comedian News'},{name:'Comedy Awards'},{name:'Comedy Clubs'},{name:'Comedy Festivals'},{name:'Comedy Movies'},{name:'Comedy Podcasts'},{name:'Comedy Roasts'},{name:'Comedy Specials'},{name:'Comedy Streaming'},{name:'Comedy Tours'},{name:'Comedy Variety Shows'},{name:'Comedy Writing'},{name:'Comic Strips'},{name:'Dark Humor'},{name:'Funny Videos'},{name:'Improv Comedy'},{name:'Late Night TV'},{name:'Memes'},{name:'Musical Comedy'},{name:'Parody'},{name:'Political Satire'},{name:'Romantic Comedy'},{name:'Satire'},{name:'Sitcoms'},{name:'Sketch Comedy'},{name:'Slapstick Comedy'},{name:'SNL Saturday Night Live'},{name:'Stand-Up Comedy'},{name:'Web Comedy Series'}] },
        { name: 'Cryptocurrency & Web3', subcategories: [{name:'Airdrop Token Launch'},{name:'Avalanche AVAX'},{name:'Bitcoin'},{name:'Bitcoin ETF'},{name:'Bitcoin Halving'},{name:'Bitcoin Mining'},{name:'Blockchain Technology'},{name:'Cardano'},{name:'Central Bank Digital Currency'},{name:'Chainlink'},{name:'Cross Chain Interoperability'},{name:'Crypto Lending'},{name:'Crypto Regulation'},{name:'Crypto Scam Fraud'},{name:'Crypto Venture Capital'},{name:'Crypto Wallet Security'},{name:'Cryptocurrency Exchange'},{name:'Cryptocurrency Tax'},{name:'DAO Governance'},{name:'Decentralized Exchange'},{name:'DeFi'},{name:'Dogecoin'},{name:'Ethereum'},{name:'Ethereum Staking'},{name:'GameFi'},{name:'Layer 2 Scaling'},{name:'Meme Coins'},{name:'Metaverse Crypto'},{name:'NFT Market'},{name:'Polkadot'},{name:'Polygon MATIC'},{name:'Proof of Stake'},{name:'Smart Contracts'},{name:'Solana'},{name:'Stablecoins'},{name:'Tokenization'},{name:'Web3 Development'},{name:'XRP Ripple'},{name:'Yield Farming'},{name:'Zero Knowledge Proofs'}] },
        { name: 'DIY & Crafts', subcategories: [{name:'3D Printing'},{name:'Basket Weaving'},{name:'Calligraphy'},{name:'Candle Making'},{name:'Ceramics'},{name:'CNC Machining'},{name:'Crochet'},{name:'Cross Stitch'},{name:'Electronics Projects'},{name:'Embroidery'},{name:'Epoxy Projects'},{name:'Furniture Building'},{name:'Gardening DIY'},{name:'Home Improvement'},{name:'Home Renovation'},{name:'Jewelry Making'},{name:'Knitting'},{name:'Laser Cutting'},{name:'Leatherwork'},{name:'Macrame'},{name:'Metalworking'},{name:'Mosaic Art'},{name:'Origami'},{name:'Painting Techniques'},{name:'Paper Crafts'},{name:'Pottery'},{name:'Pyrography'},{name:'Quilting'},{name:'Resin Art'},{name:'Scrapbooking'},{name:'Sewing'},{name:'Soap Making'},{name:'Stained Glass'},{name:'Textile Dyeing'},{name:'Upcycling'},{name:'Weaving'},{name:'Welding Projects'},{name:'Woodworking'}] },
        { name: 'Data Science & Analytics', subcategories: [{name:'A/B Testing'},{name:'Anomaly Detection'},{name:'AutoML'},{name:'Bayesian Statistics'},{name:'Big Data Analytics'},{name:'Business Intelligence'},{name:'Causal Inference'},{name:'Computer Vision'},{name:'Data Engineering'},{name:'Data Governance'},{name:'Data Lakehouse'},{name:'Data Mining'},{name:'Data Visualization'},{name:'Data Warehousing'},{name:'Deep Learning'},{name:'Edge AI'},{name:'ETL Pipelines'},{name:'Feature Engineering'},{name:'Federated Learning'},{name:'Generative AI'},{name:'Graph Neural Networks'},{name:'Image Recognition'},{name:'Large Language Models'},{name:'Machine Learning'},{name:'MLOps'},{name:'Natural Language Processing'},{name:'Neural Networks'},{name:'Predictive Analytics'},{name:'Real-Time Analytics'},{name:'Recommendation Systems'},{name:'Reinforcement Learning'},{name:'Responsible AI'},{name:'Speech Recognition'},{name:'Statistical Modeling'},{name:'Synthetic Data'},{name:'Text Mining'},{name:'Time Series Analysis'},{name:'Vector Databases'}] },
        { name: 'Design', subcategories: [{name:'3D Design'},{name:'Accessibility Design'},{name:'Animation Design'},{name:'Automotive Design'},{name:'Branding'},{name:'Color Theory'},{name:'Data Visualization'},{name:'Design Leadership'},{name:'Design Systems'},{name:'Design Thinking'},{name:'Design Tools'},{name:'Environmental Design'},{name:'Fashion Design'},{name:'Figma'},{name:'Furniture Design'},{name:'Game Design'},{name:'Graphic Design'},{name:'Illustration'},{name:'Industrial Design'},{name:'Information Architecture'},{name:'Interaction Design'},{name:'Interior Design'},{name:'Logo Design'},{name:'Material Design'},{name:'Motion Graphics'},{name:'Package Design'},{name:'Print Design'},{name:'Product Design'},{name:'Responsive Design'},{name:'Service Design'},{name:'Sound Design'},{name:'Sustainable Design'},{name:'Typography'},{name:'UI Design'},{name:'UX Design'},{name:'UX Research'},{name:'Visual Design'},{name:'Web Design'}] },
        { name: 'Economics', subcategories: [{name:'Antitrust Economics'},{name:'Behavioral Economics'},{name:'Central Banking'},{name:'Consumer Spending'},{name:'Cost of Living'},{name:'Deglobalization'},{name:'Development Economics'},{name:'Economic Forecasting'},{name:'Economic Mobility'},{name:'Economic Recession'},{name:'Economic Sanctions'},{name:'Emerging Markets'},{name:'Federal Reserve'},{name:'Fiscal Policy'},{name:'GDP Growth'},{name:'Gig Economy'},{name:'Government Spending'},{name:'Green Economy'},{name:'Housing Market Economics'},{name:'Income Inequality'},{name:'Industrial Policy'},{name:'Inflation'},{name:'Interest Rates'},{name:'International Trade'},{name:'Labor Economics'},{name:'Macroeconomics'},{name:'Microeconomics'},{name:'Monetary Policy'},{name:'National Debt'},{name:'Public Finance'},{name:'Stagflation'},{name:'Supply Chain Economics'},{name:'Tariffs'},{name:'Tax Policy'},{name:'Trade Policy'},{name:'Unemployment'},{name:'Wage Growth'},{name:'Wealth Gap'}] },
        { name: 'Education', subcategories: [{name:'Adult Education'},{name:'Charter Schools'},{name:'Classroom Technology'},{name:'College Admissions'},{name:'Community College'},{name:'Curriculum Development'},{name:'Distance Learning'},{name:'Early Childhood Education'},{name:'EdTech'},{name:'Education Equity'},{name:'Education Funding'},{name:'Education Policy'},{name:'Education Reform'},{name:'Education Technology'},{name:'Financial Aid'},{name:'Graduate School'},{name:'Higher Education'},{name:'Homeschooling'},{name:'K-12 Education'},{name:'Literacy'},{name:'Online Learning'},{name:'Private Schools'},{name:'Public Schools'},{name:'School Board'},{name:'School Choice'},{name:'School Safety'},{name:'Special Education'},{name:'Standardized Testing'},{name:'STEM Education'},{name:'Student Loans'},{name:'Student Mental Health'},{name:'Study Abroad'},{name:'Teacher Shortage'},{name:'Teaching Methods'},{name:'Trade Schools'},{name:'Tutoring'},{name:'University Research'},{name:'Vocational Training'}] },
        { name: 'Entertainment', subcategories: [{name:'Animation'},{name:'Awards Shows'},{name:'Bollywood'},{name:'Box Office'},{name:'Broadway'},{name:'Casting News'},{name:'Celebrity Gossip'},{name:'Celebrity News'},{name:'Concert Tours'},{name:'Disney Plus'},{name:'Documentaries'},{name:'Emmy Awards'},{name:'Entertainment Industry'},{name:'Film Festivals'},{name:'Golden Globes'},{name:'Grammy Awards'},{name:'HBO'},{name:'Hollywood'},{name:'K-Drama'},{name:'Late Night TV'},{name:'Movie Reviews'},{name:'Movie Trailers'},{name:'Movies'},{name:'Music Videos'},{name:'Netflix'},{name:'Oscars'},{name:'Reality TV'},{name:'Red Carpet'},{name:'Stand-Up Comedy'},{name:'Streaming'},{name:'Talk Shows'},{name:'Theme Parks'},{name:'TV Ratings'},{name:'TV Shows'},{name:'Variety Shows'}] },
        { name: 'Entrepreneurship & Startups', subcategories: [{name:'AI Startups'},{name:'Angel Investors'},{name:'Bootstrapped Startups'},{name:'Climate Tech Startups'},{name:'Corporate Venture Capital'},{name:'Customer Acquisition'},{name:'Deep Tech Startups'},{name:'Fintech Startups'},{name:'Growth Hacking'},{name:'Healthtech Startups'},{name:'Indie Hackers'},{name:'Lean Startup Methodology'},{name:'Pitch Deck Tips'},{name:'Product-Market Fit'},{name:'Remote Startup Teams'},{name:'SaaS Startups'},{name:'Scaling Startups'},{name:'Seed Round Funding'},{name:'Series A Funding'},{name:'Solopreneur'},{name:'Startup Accelerators'},{name:'Startup Acquisitions'},{name:'Startup Competitions'},{name:'Startup Culture'},{name:'Startup Equity and Vesting'},{name:'Startup Exit Strategies'},{name:'Startup Failure Post-Mortems'},{name:'Startup Founder Stories'},{name:'Startup Fundraising'},{name:'Startup Incubators'},{name:'Startup IPO'},{name:'Startup Layoffs'},{name:'Startup Metrics and KPIs'},{name:'Startup Pivots'},{name:'Startup Valuations'},{name:'Techstars'},{name:'Venture Capital Funding'},{name:'Y Combinator'}] },
        { name: 'Environment & Sustainability', subcategories: [{name:'Air Pollution'},{name:'Arctic Ice'},{name:'Biodiversity'},{name:'Carbon Capture'},{name:'Carbon Emissions'},{name:'Circular Economy'},{name:'Climate Change'},{name:'Climate Policy'},{name:'Coral Reefs'},{name:'Deforestation'},{name:'Drought'},{name:'Endangered Species'},{name:'Environmental Justice'},{name:'Environmental Policy'},{name:'ESG Investing'},{name:'Food Waste'},{name:'Geothermal Energy'},{name:'Global Warming'},{name:'Green Energy Storage'},{name:'Green Technology'},{name:'Hydroelectric Power'},{name:'Net Zero'},{name:'Ocean Conservation'},{name:'Organic Farming'},{name:'Paris Agreement'},{name:'Plastic Pollution'},{name:'Recycling'},{name:'Reforestation'},{name:'Renewable Energy'},{name:'Sea Level Rise'},{name:'Solar Energy'},{name:'Sustainable Agriculture'},{name:'Sustainable Fashion'},{name:'Waste Management'},{name:'Water Conservation'},{name:'Water Pollution'},{name:'Wildfires'},{name:'Wind Energy'}] },
        { name: 'Fashion & Beauty', subcategories: [{name:'Anti-Aging Skincare'},{name:'Athleisure'},{name:'Beauty Influencers'},{name:'Beauty Tech'},{name:'Bridal Fashion'},{name:'Celebrity Style'},{name:'Clean Beauty'},{name:'Cosmetic Surgery'},{name:'Denim Trends'},{name:'Fashion Designers'},{name:'Fashion E-Commerce'},{name:'Fashion Photography'},{name:'Fashion Sustainability'},{name:'Fashion Week'},{name:'Fast Fashion'},{name:'Fragrance and Perfume'},{name:'Hair Care'},{name:'Hair Color Trends'},{name:'Handbags and Accessories'},{name:'Haute Couture'},{name:'Jewelry Trends'},{name:'K-Beauty'},{name:'Luxury Fashion Brands'},{name:'Makeup Trends'},{name:'Men\'s Fashion'},{name:'Nail Art'},{name:'Plus Size Fashion'},{name:'Red Carpet Fashion'},{name:'Skincare Routine'},{name:'Sneaker Culture'},{name:'Streetwear'},{name:'Sunglasses and Eyewear'},{name:'Sustainable Fashion'},{name:'Textile Innovation'},{name:'Thrift and Resale Fashion'},{name:'Vintage Fashion'},{name:'Watch Collecting'},{name:'Women\'s Fashion'}] },
        { name: 'Finance', subcategories: [{name:'401k'},{name:'Banking'},{name:'Bonds'},{name:'Budgeting'},{name:'Commodities'},{name:'Corporate Earnings'},{name:'Credit Cards'},{name:'Credit Scores'},{name:'Cryptocurrency'},{name:'Day Trading'},{name:'Estate Planning'},{name:'ETFs'},{name:'Federal Reserve'},{name:'Financial Planning'},{name:'Financial Regulation'},{name:'Financial Technology'},{name:'Fintech'},{name:'Foreign Exchange'},{name:'Hedge Funds'},{name:'Index Funds'},{name:'Inflation'},{name:'Insurance'},{name:'Interest Rates'},{name:'Investing'},{name:'IPOs'},{name:'Mergers and Acquisitions'},{name:'Mortgages'},{name:'Mutual Funds'},{name:'Personal Finance'},{name:'Private Equity'},{name:'Real Estate Investing'},{name:'Retirement Planning'},{name:'Robo-Advisors'},{name:'Small Business Finance'},{name:'Stock Market'},{name:'Student Loans'},{name:'Taxes'},{name:'Venture Capital'},{name:'Wall Street'},{name:'Wealth Management'}] },
        { name: 'Food & Cooking', subcategories: [{name:'Baking and Pastry'},{name:'Bread Baking'},{name:'Celebrity Chefs'},{name:'Cheese and Cheesemaking'},{name:'Chinese Cuisine'},{name:'Chocolate and Confections'},{name:'Cocktails and Mixology'},{name:'Coffee Culture'},{name:'Comfort Food'},{name:'Cooking Techniques'},{name:'Craft Beer and Brewing'},{name:'Desserts and Sweets'},{name:'Farm to Table'},{name:'Fermentation and Pickling'},{name:'Food Photography'},{name:'Food Preservation and Canning'},{name:'Food Safety and Nutrition'},{name:'Food Science'},{name:'Food Trucks'},{name:'French Cuisine'},{name:'Grilling and BBQ'},{name:'Indian Cuisine'},{name:'Italian Cuisine'},{name:'Japanese Cuisine'},{name:'Korean Cuisine'},{name:'Meal Prep'},{name:'Mediterranean Cuisine'},{name:'Mexican Cuisine'},{name:'Middle Eastern Cuisine'},{name:'Plant-Based Cooking'},{name:'Restaurant Industry'},{name:'Seafood'},{name:'Sourdough'},{name:'Spices and Seasoning'},{name:'Street Food'},{name:'Tea Culture'},{name:'Thai Cuisine'},{name:'Vegan Recipes'},{name:'Wine and Sommelier'}] },
        { name: 'Gaming', subcategories: [{name:'Battle Royale Games'},{name:'Cloud Gaming'},{name:'Co-op Games'},{name:'Competitive Gaming'},{name:'Console Gaming'},{name:'Esports'},{name:'Fighting Games'},{name:'FPS Games'},{name:'Free to Play Games'},{name:'Game Deals'},{name:'Game Design'},{name:'Game Emulation'},{name:'Game Modding'},{name:'Game Reviews'},{name:'Game Soundtracks'},{name:'Game Streaming'},{name:'Gaming Accessories'},{name:'Gaming Hardware'},{name:'Horror Games'},{name:'Indie Games'},{name:'MMOs'},{name:'Mobile Gaming'},{name:'Nintendo'},{name:'Open World Games'},{name:'PC Gaming'},{name:'PlayStation'},{name:'Racing Games'},{name:'Retro Gaming'},{name:'Roguelike Games'},{name:'RPGs'},{name:'Simulation Games'},{name:'Speedrunning'},{name:'Sports Games'},{name:'Steam'},{name:'Strategy Games'},{name:'Survival Games'},{name:'Tabletop RPGs'},{name:'VR Gaming'},{name:'Xbox'}] },
        { name: 'Health & Fitness', subcategories: [{name:'Addiction Recovery'},{name:'Bodybuilding'},{name:'Cardio Fitness'},{name:'Clinical Trials'},{name:'CrossFit'},{name:'Cycling & Biking'},{name:'Diabetes Prevention'},{name:'Functional Fitness'},{name:'Gut Health & Microbiome'},{name:'Heart Health'},{name:'HIIT Workouts'},{name:'Immune System'},{name:'Intermittent Fasting'},{name:'Keto Diet'},{name:'Marathon Training'},{name:'Meditation & Mindfulness'},{name:'Mental Health & Wellness'},{name:'Nutrition & Diet'},{name:'Outdoor Fitness & Hiking'},{name:'Physical Therapy'},{name:'Pilates'},{name:'Plant-Based Diet'},{name:'Protein & Muscle Recovery'},{name:'Public Health Policy'},{name:'Running & Jogging'},{name:'Senior Fitness'},{name:'Sleep & Recovery'},{name:'Sports Medicine'},{name:'Stretching & Mobility'},{name:'Supplements & Vitamins'},{name:'Swimming'},{name:'Wearable Fitness Technology'},{name:'Weight Loss'},{name:'Weightlifting'},{name:'Women\'s Health'},{name:'Yoga'}] },
        { name: 'History', subcategories: [{name:'African Kingdoms'},{name:'Age of Exploration'},{name:'American Revolution'},{name:'Ancient China'},{name:'Ancient Egypt'},{name:'Ancient Greece'},{name:'Ancient India'},{name:'Ancient Mesopotamia'},{name:'Ancient Rome'},{name:'Archaeology'},{name:'Art History'},{name:'British Empire'},{name:'Byzantine Empire'},{name:'Civil Rights Movement'},{name:'Civil War'},{name:'Cold War'},{name:'Colonial History'},{name:'Crusades'},{name:'Feudal Japan'},{name:'French Revolution'},{name:'Historical Preservation'},{name:'History of Religion'},{name:'History of Science'},{name:'Holocaust'},{name:'Industrial Revolution'},{name:'Korean War'},{name:'Latin American History'},{name:'Medieval Europe'},{name:'Mesoamerican Civilizations'},{name:'Military History'},{name:'Naval History'},{name:'Oral History'},{name:'Ottoman Empire'},{name:'Renaissance'},{name:'Russian Revolution'},{name:'Silk Road'},{name:'Vietnam War'},{name:'Viking Age'},{name:'World War I'},{name:'World War II'}] },
        { name: 'Hobbies & Collections', subcategories: [{name:'Amateur Radio'},{name:'Antique Collecting'},{name:'Aquariums and Fishkeeping'},{name:'Beekeeping'},{name:'Birdwatching'},{name:'Board Games'},{name:'Card Games'},{name:'Coin Collecting'},{name:'Comic Books'},{name:'Cosplay'},{name:'Drone Flying'},{name:'Fishing'},{name:'Gardening'},{name:'Geocaching'},{name:'Hiking'},{name:'Homebrewing'},{name:'Jigsaw Puzzles'},{name:'Leatherworking'},{name:'LEGO Building'},{name:'Metal Detecting'},{name:'Miniature Painting'},{name:'Model Building'},{name:'Pen Collecting'},{name:'Pottery and Ceramics'},{name:'RC Vehicles'},{name:'Rock Collecting'},{name:'Stamp Collecting'},{name:'Tabletop RPGs'},{name:'Trading Card Games'},{name:'Train Sets'},{name:'Vinyl Records'},{name:'Wargaming'},{name:'Watch Collecting'}] },
        { name: 'Home & Garden', subcategories: [{name:'Backyard Design'},{name:'Bathroom Renovation'},{name:'Composting'},{name:'Container Gardening'},{name:'Curb Appeal'},{name:'Deck and Porch'},{name:'DIY Home Improvement'},{name:'Farmhouse Style'},{name:'Flooring Ideas'},{name:'Flower Gardening'},{name:'Furniture Design'},{name:'Home Automation'},{name:'Home Decor'},{name:'Home Energy Efficiency'},{name:'Home Office Design'},{name:'Home Organization'},{name:'Home Security Systems'},{name:'Home Storage Solutions'},{name:'Houseplants'},{name:'Indoor Herb Garden'},{name:'Interior Design'},{name:'Kitchen Remodel'},{name:'Landscaping'},{name:'Lawn Care'},{name:'Lighting Design'},{name:'Minimalist Home'},{name:'Organic Gardening'},{name:'Outdoor Living'},{name:'Patio Design'},{name:'Raised Bed Gardening'},{name:'Small Space Living'},{name:'Smart Home'},{name:'Sustainable Living'},{name:'Vegetable Gardening'},{name:'Window Treatments'}] },
        { name: 'Internet Culture & Social Media', subcategories: [{name:'AI-Generated Content'},{name:'Bluesky Social'},{name:'Cancel Culture'},{name:'Content Creation'},{name:'Content Moderation'},{name:'Creator Economy'},{name:'Deepfakes'},{name:'Digital Privacy'},{name:'Digital Wellness'},{name:'Discord Servers'},{name:'Fan Culture'},{name:'Influencer Marketing'},{name:'Instagram Reels'},{name:'Internet Celebrities'},{name:'Livestreaming'},{name:'Mastodon Fediverse'},{name:'Online Communities'},{name:'Online Harassment'},{name:'Online Memes'},{name:'Online Misinformation'},{name:'Podcasting'},{name:'Reddit Communities'},{name:'Screen Time'},{name:'Social Media Algorithms'},{name:'Social Media Influencers'},{name:'Social Media Marketing'},{name:'Social Media Regulation'},{name:'Substack Newsletters'},{name:'Threads App'},{name:'TikTok Trends'},{name:'Twitch Streaming'},{name:'Viral Videos'},{name:'Virtual Influencers'},{name:'YouTube Creators'},{name:'YouTube Shorts'}] },
        { name: 'Law & Legal', subcategories: [{name:'AI Regulation'},{name:'Antitrust Law'},{name:'Bankruptcy Law'},{name:'Civil Rights Law'},{name:'Class Action Lawsuits'},{name:'Constitutional Law'},{name:'Consumer Protection'},{name:'Copyright Law'},{name:'Corporate Law'},{name:'Criminal Justice Reform'},{name:'Criminal Law'},{name:'Cybersecurity Law'},{name:'Data Privacy'},{name:'Death Penalty'},{name:'Election Law'},{name:'Employment Law'},{name:'Environmental Law'},{name:'Family Law'},{name:'First Amendment'},{name:'Healthcare Law'},{name:'Human Rights Law'},{name:'Immigration Law'},{name:'Intellectual Property'},{name:'International Law'},{name:'Judicial Nominations'},{name:'Legal Technology'},{name:'Maritime Law'},{name:'Military Law'},{name:'Patent Law'},{name:'Police Reform'},{name:'Privacy Law'},{name:'Real Estate Law'},{name:'Securities Law'},{name:'Supreme Court'},{name:'Tax Law'},{name:'Tech Regulation'},{name:'Trade Law'},{name:'Trademark Law'},{name:'White Collar Crime'}] },
        { name: 'Lifestyle', subcategories: [{name:'City Living'},{name:'Cottagecore'},{name:'Cozy Living'},{name:'Dating'},{name:'Decluttering'},{name:'Digital Detox'},{name:'Digital Nomad'},{name:'Downsizing'},{name:'Expat Life'},{name:'Frugal Living'},{name:'Home Organization'},{name:'Homesteading'},{name:'Hygge'},{name:'Intentional Living'},{name:'Life Hacks'},{name:'Life Transitions'},{name:'Luxury Lifestyle'},{name:'Mindful Living'},{name:'Minimalism'},{name:'Minimalist Wardrobe'},{name:'Morning Routines'},{name:'Off-Grid Living'},{name:'Personal Development'},{name:'Relationships'},{name:'Remote Work Lifestyle'},{name:'Retirement Living'},{name:'Rural Living'},{name:'Self-Improvement'},{name:'Simple Living'},{name:'Slow Living'},{name:'Solo Living'},{name:'Suburban Living'},{name:'Sustainable Living'},{name:'Tiny Houses'},{name:'Van Life'},{name:'Work-Life Balance'},{name:'Zero Waste Living'}] },
        { name: 'Military & Defense', subcategories: [{name:'Air Defense Systems'},{name:'Arms Trade and Weapons Sales'},{name:'Coast Guard'},{name:'Counter-Terrorism'},{name:'Cybersecurity Defense'},{name:'Defense Budget and Spending'},{name:'Defense Contractors'},{name:'Defense Industry News'},{name:'Defense Policy and Strategy'},{name:'Electronic Warfare'},{name:'Fighter Jets and Combat Aircraft'},{name:'Homeland Security'},{name:'Hypersonic Weapons'},{name:'Military Artificial Intelligence'},{name:'Military Cyber Operations'},{name:'Military Drones and UAVs'},{name:'Military Intelligence'},{name:'Military Recruitment'},{name:'Military Technology'},{name:'Military Veterans'},{name:'Missile Defense'},{name:'National Guard'},{name:'NATO Alliance'},{name:'Naval Warfare'},{name:'Nuclear Weapons and Deterrence'},{name:'Pentagon News'},{name:'Space Force'},{name:'Special Operations Forces'},{name:'Submarines and Undersea Warfare'},{name:'U.S. Air Force'},{name:'U.S. Army'},{name:'U.S. Marine Corps'},{name:'U.S. Navy'},{name:'Veterans Affairs and Benefits'},{name:'War and Conflict Updates'}] },
        { name: 'Music', subcategories: [{name:'Album Reviews'},{name:'Alternative Music'},{name:'Band Interviews'},{name:'Blues Music'},{name:'Classical Music'},{name:'Concert Tours'},{name:'Country Music'},{name:'DJing'},{name:'Electronic Music'},{name:'Film Scores'},{name:'Folk Music'},{name:'Grammy Awards'},{name:'Guitar'},{name:'Heavy Metal Music'},{name:'Hip-Hop Music'},{name:'Indie Music'},{name:'Jazz Music'},{name:'K-Pop'},{name:'Latin Music'},{name:'Music Charts'},{name:'Music Education'},{name:'Music Festivals'},{name:'Music Industry News'},{name:'Music Production'},{name:'Music Streaming'},{name:'Music Technology'},{name:'Music Videos'},{name:'New Music Releases'},{name:'Opera'},{name:'Piano'},{name:'Pop Music'},{name:'Punk Music'},{name:'R&B Music'},{name:'Reggae Music'},{name:'Rock Music'},{name:'Songwriting'},{name:'Soul Music'},{name:'Vinyl Records'},{name:'World Music'}] },
        { name: 'News & Politics', subcategories: [{name:'Asia Pacific Politics'},{name:'Civil Rights'},{name:'Climate Policy'},{name:'Congress'},{name:'Defense Policy'},{name:'Diplomacy'},{name:'Economic Policy'},{name:'Education Policy'},{name:'Elections'},{name:'European Politics'},{name:'Foreign Policy'},{name:'Geopolitics'},{name:'Government Accountability'},{name:'Gun Policy'},{name:'Healthcare Policy'},{name:'House of Representatives'},{name:'Immigration'},{name:'Intelligence Community'},{name:'Investigative Journalism'},{name:'Labor Politics'},{name:'Local News'},{name:'Media Criticism'},{name:'Middle East Politics'},{name:'Midterm Elections'},{name:'National Security'},{name:'NATO'},{name:'Policy Analysis'},{name:'Political Campaigns'},{name:'Political Corruption'},{name:'Polling'},{name:'Presidential Elections'},{name:'Senate'},{name:'State Politics'},{name:'Supreme Court'},{name:'Trade Policy'},{name:'United Nations'},{name:'US Politics'},{name:'White House'},{name:'World News'}] },
        { name: 'Parenting', subcategories: [{name:'ADHD in Children'},{name:'Adoption and Foster Care'},{name:'Baby Sleep Training'},{name:'Back to School'},{name:'Blended Families'},{name:'Breastfeeding'},{name:'Bullying Prevention'},{name:'Child Custody'},{name:'Child Development Milestones'},{name:'Child Nutrition'},{name:'Child Safety'},{name:'Childhood Anxiety'},{name:'Childhood Vaccinations'},{name:'Children and Reading'},{name:'Co-Parenting'},{name:'Daycare and Childcare'},{name:'Discipline and Positive Parenting'},{name:'Family Activities'},{name:'Family Travel with Kids'},{name:'Homeschooling'},{name:'Kids and Sports'},{name:'Newborn Care'},{name:'Parental Mental Health'},{name:'Parenting Teens and Social Media'},{name:'Postpartum Depression'},{name:'Potty Training'},{name:'Pregnancy and Prenatal Care'},{name:'Preschool Readiness'},{name:'Preteen Parenting'},{name:'School-Age Children'},{name:'Screen Time and Kids'},{name:'Sibling Rivalry'},{name:'Single Parenting'},{name:'Special Needs Parenting'},{name:'Teenage Parenting'},{name:'Toddler Development'},{name:'Work-Life Balance for Parents'}] },
        { name: 'Pets & Animals', subcategories: [{name:'Animal Rescue & Shelters'},{name:'Animal Rights'},{name:'Animal Science & Research'},{name:'Animal Welfare'},{name:'Backyard Chickens'},{name:'Cat Behavior'},{name:'Cats'},{name:'Coral Reefs & Marine Conservation'},{name:'Dog Breeds'},{name:'Dog Training'},{name:'Dogs'},{name:'Endangered Species'},{name:'Exotic Pets'},{name:'Freshwater Aquarium Fish'},{name:'Horses & Equestrian'},{name:'Insects & Pollinators'},{name:'Livestock & Farm Animals'},{name:'Marine Life'},{name:'Pet Adoption'},{name:'Pet Birds'},{name:'Pet Grooming'},{name:'Pet Health'},{name:'Pet Industry & Products'},{name:'Pet Insurance'},{name:'Pet Nutrition'},{name:'Pet Travel'},{name:'Rabbits'},{name:'Reptiles & Amphibians'},{name:'Service Animals & Therapy Pets'},{name:'Small Pets & Rodents'},{name:'Veterinary Medicine'},{name:'Wildlife Conservation'},{name:'Wildlife Photography'},{name:'Zoos & Aquariums'}] },
        { name: 'Philosophy', subcategories: [{name:'Absurdism'},{name:'Aesthetics'},{name:'AI Ethics'},{name:'Analytic Philosophy'},{name:'Ancient Philosophy'},{name:'Bioethics'},{name:'Buddhism Philosophy'},{name:'Confucianism'},{name:'Consciousness Studies'},{name:'Continental Philosophy'},{name:'Critical Theory'},{name:'Eastern Philosophy'},{name:'Environmental Ethics'},{name:'Epistemology'},{name:'Ethics'},{name:'Existentialism'},{name:'Feminist Philosophy'},{name:'Free Will'},{name:'Hermeneutics'},{name:'Logic'},{name:'Metaphysics'},{name:'Moral Philosophy'},{name:'Nihilism'},{name:'Phenomenology'},{name:'Philosophy of Education'},{name:'Philosophy of History'},{name:'Philosophy of Language'},{name:'Philosophy of Law'},{name:'Philosophy of Mind'},{name:'Philosophy of Religion'},{name:'Philosophy of Science'},{name:'Philosophy of Technology'},{name:'Political Philosophy'},{name:'Postmodernism'},{name:'Pragmatism'},{name:'Social Justice Philosophy'},{name:'Stoicism'},{name:'Taoism'},{name:'Utilitarianism'},{name:'Virtue Ethics'}] },
        { name: 'Photography', subcategories: [{name:'Abstract Photography'},{name:'Adobe Lightroom'},{name:'Analog Photography'},{name:'Architecture Photography'},{name:'Astrophotography'},{name:'Black and White Photography'},{name:'Camera Gear'},{name:'Candid Photography'},{name:'Concert Photography'},{name:'Darkroom Printing'},{name:'Documentary Photography'},{name:'Drone Photography'},{name:'DSLR Cameras'},{name:'Fashion Photography'},{name:'Film Photography'},{name:'Fine Art Photography'},{name:'Food Photography'},{name:'Landscape Photography'},{name:'Macro Photography'},{name:'Mirrorless Cameras'},{name:'Mobile Photography'},{name:'Nature Photography'},{name:'Night Photography'},{name:'Photo Contests'},{name:'Photo Editing'},{name:'Photography Composition'},{name:'Photography Exhibitions'},{name:'Photojournalism'},{name:'Portrait Photography'},{name:'Product Photography'},{name:'Sports Photography'},{name:'Street Photography'},{name:'Studio Lighting'},{name:'Travel Photography'},{name:'Underwater Photography'},{name:'Wedding Photography'},{name:'Wildlife Photography'}] },
        { name: 'Productivity & Organization', subcategories: [{name:'Atomic Habits'},{name:'Bullet Journaling'},{name:'Calendar Management'},{name:'Deep Work'},{name:'Digital Minimalism'},{name:'Digital Productivity Tools'},{name:'Eisenhower Matrix'},{name:'Email Management'},{name:'Focus Techniques'},{name:'Getting Things Done'},{name:'Goal Setting'},{name:'Habit Building'},{name:'Habit Tracking'},{name:'Inbox Zero'},{name:'Kanban Board'},{name:'Mind Mapping'},{name:'Morning Routine'},{name:'Note-Taking Apps'},{name:'Notion'},{name:'Obsidian'},{name:'Personal Automation'},{name:'Personal Knowledge Management'},{name:'Pomodoro Technique'},{name:'Productivity Apps'},{name:'Project Planning'},{name:'Roam Research'},{name:'Second Brain'},{name:'Task Management'},{name:'Time Management'},{name:'Timeboxing'},{name:'Todoist'},{name:'Weekly Review'},{name:'Workflow Automation'},{name:'Zapier'}] },
        { name: 'Psychology & Mental Health', subcategories: [{name:'Addiction Recovery'},{name:'ADHD Research'},{name:'Adolescent Mental Health'},{name:'Anxiety Disorders'},{name:'Autism Spectrum'},{name:'Behavioral Psychology'},{name:'Bipolar Disorder'},{name:'Burnout Prevention'},{name:'Child Psychology'},{name:'Clinical Psychology'},{name:'Cognitive Behavioral Therapy'},{name:'Couples Therapy'},{name:'Depression Treatment'},{name:'Developmental Psychology'},{name:'Eating Disorders'},{name:'Emotional Intelligence'},{name:'Grief Counseling'},{name:'Mental Health Apps'},{name:'Mental Health Policy'},{name:'Mental Health Stigma'},{name:'Mindfulness Meditation'},{name:'Neuropsychology'},{name:'Neuroscience Research'},{name:'Obsessive Compulsive Disorder'},{name:'Perinatal Mental Health'},{name:'Personality Disorders'},{name:'Positive Psychology'},{name:'Psychopharmacology'},{name:'Psychotherapy Techniques'},{name:'PTSD Recovery'},{name:'Schizophrenia Research'},{name:'Sleep Psychology'},{name:'Social Psychology'},{name:'Stress Management'},{name:'Substance Abuse Treatment'},{name:'Trauma Therapy'},{name:'Workplace Mental Health'}] },
        { name: 'Real Estate', subcategories: [{name:'Affordable Housing'},{name:'Commercial Real Estate'},{name:'Condo Market'},{name:'First Time Home Buyers'},{name:'Foreclosures'},{name:'Green Building'},{name:'Home Appraisal'},{name:'Home Buying Tips'},{name:'Home Inspections'},{name:'Home Insurance'},{name:'Home Prices'},{name:'Home Renovations'},{name:'Homebuilders'},{name:'House Flipping'},{name:'Housing Market Trends'},{name:'Industrial Real Estate'},{name:'Luxury Real Estate'},{name:'Mortgage Rates'},{name:'Multifamily Housing'},{name:'Office Real Estate'},{name:'Property Management'},{name:'Property Taxes'},{name:'Real Estate Agents'},{name:'Real Estate Auctions'},{name:'Real Estate Crowdfunding'},{name:'Real Estate Development'},{name:'Real Estate Investing'},{name:'Real Estate Law'},{name:'Real Estate Market Forecast'},{name:'Real Estate Technology'},{name:'REITs'},{name:'Rental Market'},{name:'Reverse Mortgages'},{name:'Senior Housing'},{name:'Short Term Rentals'},{name:'Tiny Homes'},{name:'Vacation Rentals'},{name:'Zoning and Land Use'}] },
        { name: 'Religion & Spirituality', subcategories: [{name:'Atheism & Agnosticism'},{name:'Biblical Studies'},{name:'Buddhism'},{name:'Catholicism'},{name:'Christianity'},{name:'Church & State'},{name:'Evangelical Christianity'},{name:'Hinduism'},{name:'Indigenous & Folk Religions'},{name:'Interfaith Dialogue'},{name:'Islam'},{name:'Jainism'},{name:'Judaism'},{name:'Kabbalah'},{name:'Meditation & Mindfulness'},{name:'New Age Spirituality'},{name:'Orthodox Christianity'},{name:'Pilgrimage & Holy Sites'},{name:'Prayer & Devotion'},{name:'Religion & Science'},{name:'Religious Education'},{name:'Religious Freedom'},{name:'Religious History'},{name:'Religious Holidays & Festivals'},{name:'Religious Leadership'},{name:'Shia Islam'},{name:'Shintoism'},{name:'Sikhism'},{name:'Spirituality'},{name:'Sufism'},{name:'Sunni Islam'},{name:'Taoism'},{name:'Theology'},{name:'Tibetan Buddhism'},{name:'Zen Buddhism'}] },
        { name: 'Science', subcategories: [{name:'Astrobiology'},{name:'Astrophysics'},{name:'Biochemistry'},{name:'Biophysics'},{name:'Botany'},{name:'Cell Biology'},{name:'Climate Science'},{name:'Computational Biology'},{name:'CRISPR Gene Editing'},{name:'Ecology'},{name:'Epidemiology'},{name:'Evolutionary Biology'},{name:'Genetics'},{name:'Genomics'},{name:'Geology'},{name:'Immunology'},{name:'Marine Biology'},{name:'Materials Science'},{name:'Microbiology'},{name:'Molecular Biology'},{name:'Nanotechnology'},{name:'Neuroscience'},{name:'Nuclear Physics'},{name:'Oceanography'},{name:'Organic Chemistry'},{name:'Paleontology'},{name:'Particle Physics'},{name:'Pharmacology'},{name:'Quantum Mechanics'},{name:'Seismology'},{name:'Stem Cell Research'},{name:'Synthetic Biology'},{name:'Virology'},{name:'Volcanology'},{name:'Zoology'}] },
        { name: 'Space & Astronomy', subcategories: [{name:'Artemis Program'},{name:'Asteroid Mining'},{name:'Black Holes'},{name:'Blue Origin'},{name:'Chinese Space Program'},{name:'Cosmology'},{name:'Dark Energy'},{name:'Dark Matter'},{name:'Europa Clipper'},{name:'Exoplanets'},{name:'Galaxy Formation'},{name:'Gravitational Waves'},{name:'Hubble Telescope'},{name:'Indian Space Program ISRO'},{name:'International Space Station'},{name:'James Webb Space Telescope'},{name:'Lunar Gateway'},{name:'Mars Exploration'},{name:'Moon Exploration'},{name:'NASA'},{name:'Neutron Stars'},{name:'Planetary Science'},{name:'Radio Astronomy'},{name:'Rocket Launches'},{name:'Satellite Technology'},{name:'Solar Flares'},{name:'Solar System'},{name:'Space Debris'},{name:'Space Telescopes'},{name:'Space Tourism'},{name:'Space Weather'},{name:'SpaceX'},{name:'Starlink Satellites'},{name:'Starship Rocket'},{name:'Supernovae'}] },
        { name: 'Sports', subcategories: [{name:'Archery'},{name:'Badminton'},{name:'Baseball'},{name:'Basketball'},{name:'BMX'},{name:'Bobsled'},{name:'Boxing'},{name:'Cricket'},{name:'CrossFit'},{name:'Curling'},{name:'Cycling'},{name:'Diving'},{name:'Esports'},{name:'Fencing'},{name:'Field Hockey'},{name:'Figure Skating'},{name:'Football'},{name:'Formula 1'},{name:'Golf'},{name:'Gymnastics'},{name:'Handball'},{name:'Hockey'},{name:'Horse Racing'},{name:'IndyCar'},{name:'Lacrosse'},{name:'Marathon Running'},{name:'MMA'},{name:'Motocross'},{name:'NASCAR'},{name:'Pickleball'},{name:'Polo'},{name:'Rally Racing'},{name:'Rock Climbing'},{name:'Rowing'},{name:'Rugby'},{name:'Sailing'},{name:'Skateboarding'},{name:'Skiing'},{name:'Snowboarding'},{name:'Soccer'},{name:'Surfing'},{name:'Swimming'},{name:'Table Tennis'},{name:'Tennis'},{name:'Track and Field'},{name:'Triathlon'},{name:'Volleyball'},{name:'Water Polo'},{name:'Weightlifting'},{name:'Wrestling'}] },
        { name: 'Technology', subcategories: [{name:'3D Printing'},{name:'5G Networks'},{name:'Artificial Intelligence'},{name:'Augmented Reality'},{name:'Big Data'},{name:'Biotechnology'},{name:'Blockchain'},{name:'Cloud Computing'},{name:'Computer Vision'},{name:'Cybersecurity'},{name:'Data Science'},{name:'Deep Learning'},{name:'DevOps'},{name:'Digital Privacy'},{name:'Drones'},{name:'Edge Computing'},{name:'Electric Vehicles'},{name:'Fintech'},{name:'Gaming Technology'},{name:'Generative AI'},{name:'Internet of Things'},{name:'Laptops'},{name:'Linux'},{name:'Machine Learning'},{name:'Mobile App Development'},{name:'Nanotechnology'},{name:'Natural Language Processing'},{name:'Net Neutrality'},{name:'Open Source Software'},{name:'Programming Languages'},{name:'Quantum Computing'},{name:'Robotics'},{name:'Satellite Internet'},{name:'Self-Driving Cars'},{name:'Semiconductors'},{name:'Smart Home'},{name:'Smartphones'},{name:'Social Media Platforms'},{name:'Software Engineering'},{name:'Space Technology'},{name:'Streaming Services'},{name:'Tech Policy and Regulation'},{name:'Tech Startups'},{name:'Virtual Reality'},{name:'Wearables'},{name:'Web Development'}] },
        { name: 'Travel', subcategories: [{name:'Accessible Travel'},{name:'Adventure Travel'},{name:'Airlines'},{name:'Backpacking'},{name:'Beach Vacations'},{name:'Budget Travel'},{name:'Camping'},{name:'City Breaks'},{name:'Cruises'},{name:'Cultural Tourism'},{name:'Digital Nomad'},{name:'Eco Tourism'},{name:'Family Travel'},{name:'Food Tourism'},{name:'Hiking Travel'},{name:'Hotels'},{name:'Island Travel'},{name:'Luxury Travel'},{name:'Mountain Travel'},{name:'National Parks'},{name:'Passport and Visa'},{name:'Pet Friendly Travel'},{name:'Road Trips'},{name:'Safari Travel'},{name:'Ski Travel'},{name:'Solo Travel'},{name:'Sustainable Travel'},{name:'Train Travel'},{name:'Travel Deals'},{name:'Travel Gear'},{name:'Travel Hacking'},{name:'Travel Insurance'},{name:'Travel Photography'},{name:'Travel Safety'},{name:'Travel Technology'},{name:'Travel Tips'},{name:'Van Life'},{name:'Volunteer Travel'},{name:'Weekend Getaways'},{name:'Wellness Travel'}] },
        { name: 'True Crime', subcategories: [{name:'Arson Investigation'},{name:'Cold Cases'},{name:'Court Trials'},{name:'Crime Documentary'},{name:'Crime Scene Investigation'},{name:'Crime Statistics'},{name:'Criminal Appeals'},{name:'Criminal Investigations'},{name:'Criminal Profiling'},{name:'Criminal Psychology'},{name:'Cybercrime'},{name:'Death Row'},{name:'DNA Evidence'},{name:'Domestic Violence Cases'},{name:'Drug Trafficking'},{name:'Evidence Tampering'},{name:'FBI Investigations'},{name:'Financial Fraud'},{name:'Forensic Psychology'},{name:'Forensic Science'},{name:'Gang Violence'},{name:'Hate Crimes'},{name:'Heists and Robberies'},{name:'Human Trafficking'},{name:'Identity Theft'},{name:'Jury Trials'},{name:'Kidnapping Cases'},{name:'Missing Persons'},{name:'Organized Crime'},{name:'Parole and Probation'},{name:'Police Misconduct'},{name:'Prison Life'},{name:'Serial Killers'},{name:'True Crime Podcasts'},{name:'Unsolved Murders'},{name:'Victim Advocacy'},{name:'White Collar Crime'},{name:'Witness Protection'},{name:'Wrongful Convictions'}] },
        { name: 'Weather & Climate', subcategories: [{name:'Air Quality and Smog'},{name:'Arctic Ice and Polar Weather'},{name:'Atmospheric Science'},{name:'Avalanche Warnings'},{name:'Blizzards and Ice Storms'},{name:'Climate Change Science'},{name:'Climate Data and Records'},{name:'Climate Policy'},{name:'Coastal Storm Surge'},{name:'Drought Conditions'},{name:'El Nino and La Nina'},{name:'Extreme Heat Waves'},{name:'Flash Flooding'},{name:'Hurricane Tracking'},{name:'Jet Stream Patterns'},{name:'Lightning and Hail'},{name:'Meteorology Research'},{name:'Monsoon Season'},{name:'Ocean Temperature Anomalies'},{name:'Rainfall and Precipitation'},{name:'Record Breaking Temperatures'},{name:'Sea Level Rise'},{name:'Seasonal Allergy Forecasts'},{name:'Severe Thunderstorms'},{name:'Tornado Outbreaks'},{name:'Tropical Storms'},{name:'UV Index and Solar Radiation'},{name:'Weather and Aviation Safety'},{name:'Weather Emergency Preparedness'},{name:'Weather Forecasting'},{name:'Weather Radar Technology'},{name:'Weather Satellites'},{name:'Wildfire Weather'},{name:'Wind Storms and Derechos'},{name:'Winter Storms'}] },
        { name: 'Wellness & Self-Care', subcategories: [{name:'Acupuncture'},{name:'Aromatherapy'},{name:'Ayurveda'},{name:'Body Positivity'},{name:'Breathwork'},{name:'Burnout Recovery'},{name:'Chronic Pain Management'},{name:'Cold Plunge & Ice Bath'},{name:'Digital Detox'},{name:'Emotional Wellness'},{name:'Fitness Recovery'},{name:'Float Therapy'},{name:'Forest Bathing'},{name:'Gratitude Practice'},{name:'Gut Health'},{name:'Herbal Remedies'},{name:'Holistic Health'},{name:'Journaling'},{name:'Meditation'},{name:'Mental Health Awareness'},{name:'Mindful Movement'},{name:'Mindfulness'},{name:'Nutrition & Clean Eating'},{name:'Pilates'},{name:'Positive Psychology'},{name:'Reiki & Energy Healing'},{name:'Sauna Therapy'},{name:'Self-Care Routines'},{name:'Skin Care Rituals'},{name:'Sleep Health'},{name:'Sleep Hygiene'},{name:'Sound Healing'},{name:'Spa & Wellness'},{name:'Stress Management'},{name:'Stretching & Mobility'},{name:'Tai Chi'},{name:'Wellness Retreats'},{name:'Wellness Technology'},{name:'Work-Life Balance'},{name:'Yoga'}] }
    ],

    NEWSLETTER_PLATFORMS: {
        'substack': 'Substack',
        'medium': 'Medium',
        'ghost': 'Ghost',
        'buttondown': 'Buttondown',
        'beehiiv': 'Beehiiv',
        'convertkit': 'ConvertKit',
        'revue': 'Revue',
        'independent': 'Independent',
        'generic': 'Newsletter',
        'direct': 'RSS Feed'
    },

    PLATFORM_FAVICONS: {
        'substack': 'https://substack.com/favicon.ico',
        'medium': 'https://miro.medium.com/v2/1*m-R_BkNf1Qjr1YbyOIJY2w.png',
        'ghost': 'https://ghost.org/favicon.ico',
        'buttondown': 'https://www.google.com/s2/favicons?domain=buttondown.com&sz=32',
        'beehiiv': 'https://www.google.com/s2/favicons?domain=beehiiv.com&sz=32',
        'convertkit': 'https://www.google.com/s2/favicons?domain=convertkit.com&sz=32',
        'independent': '/media/img/icons/heroicons-solid/rss.svg'
    },

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

    // add_site_view.js - Feed type/source maps used across multiple methods
    // Maps feed types (from API) to state property names and render method names
    FEED_TYPE_MAP: {
        'rss':        { state: 'popular_state',      render: 'render_popular_popular' },
        'youtube':    { state: 'youtube_state',       render: 'render_youtube_popular' },
        'reddit':     { state: 'reddit_state',        render: 'render_reddit_popular' },
        'newsletter': { state: 'newsletters_state',   render: 'render_newsletters_popular' },
        'podcast':    { state: 'podcasts_state',      render: 'render_podcasts_popular' }
    },

    // Maps source/tab names (used by pill clicks) to the same structure
    SOURCE_MAP: {
        'popular':     { state: 'popular_state',      render: 'render_popular_popular' },
        'youtube':     { state: 'youtube_state',       render: 'render_youtube_popular' },
        'reddit':      { state: 'reddit_state',        render: 'render_reddit_popular' },
        'newsletters': { state: 'newsletters_state',   render: 'render_newsletters_popular' },
        'podcasts':    { state: 'podcasts_state',      render: 'render_podcasts_popular' },
        'google-news': { state: 'google_news_state',   render: 'render_google_news_tab' }
    },

    // add_site_view.js - TAB_SEARCH_CONFIG: maps tab names to search/state/render config
    TAB_SEARCH_CONFIG: {
        'popular': { input_suffix: 'popular', tab_suffix: 'popular', state_key: 'popular_state', render_popular: 'render_popular_popular' },
        'youtube': { input_suffix: 'youtube', tab_suffix: 'youtube', state_key: 'youtube_state', render_popular: 'render_youtube_popular' },
        'reddit': { input_suffix: 'reddit', tab_suffix: 'reddit', state_key: 'reddit_state', render_popular: 'render_reddit_popular' },
        'newsletters': { input_suffix: 'newsletters', tab_suffix: 'newsletters', state_key: 'newsletters_state', render_popular: 'render_newsletters_popular' },
        'podcasts': { input_suffix: 'podcasts', tab_suffix: 'podcasts', state_key: 'podcasts_state', render_popular: 'render_podcasts_popular' }
    },

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

    initialize: function (options) {
        this.options = options || {};
        this.model = NEWSBLUR.assets;
        this.active_tab = this.options.initial_tab || 'search';
        if (this.active_tab === 'trending') this.active_tab = 'search';
        this.view_mode = NEWSBLUR.assets.preference('add_site_view_mode') || 'grid';
        this.search_query = '';
        this.search_debounced = _.debounce(_.bind(this.perform_search, this), 300);
        this.newsletter_search_debounced = _.debounce(_.bind(this.perform_newsletter_search, this), 300);
        this.reddit_search_debounced = _.debounce(_.bind(this.perform_reddit_popular_search, this), 300);
        this.reddit_api_search_debounced = _.debounce(_.bind(this.perform_reddit_api_search, this), 500);
        this.podcast_search_debounced = _.debounce(_.bind(this.perform_podcast_popular_search, this), 300);
        this.youtube_search_debounced = _.debounce(_.bind(this.perform_youtube_popular_search, this), 300);
        this.popular_search_debounced = _.debounce(_.bind(this.perform_popular_search, this), 300);
        this.search_version = 0;  // Track search version to cancel stale responses
        this.overflow_tabs = [];  // Tabs currently in overflow menu

        this.init_tab_states();

        // Apply initial category/subcategory from URL routing
        if (this.options.initial_category) {
            this.apply_initial_category_state(
                this.active_tab,
                this.options.initial_category,
                this.options.initial_subcategory
            );
        }

        // Pre-fill URL or search query from popover redirect
        if (this.options.initial_url) {
            this.webfeed_state.url = this.options.initial_url;
        }
        if (this.options.initial_query) {
            this.search_query = this.options.initial_query;
        }

        this.render();

        // Auto-trigger analysis or search if pre-filled from popover
        if (this.options.initial_url && this.active_tab === 'web-feed') {
            _.defer(_.bind(this.perform_webfeed_analyze, this));
        }
        if (this.options.initial_query && this.active_tab === 'search') {
            _.defer(_.bind(this.perform_search, this));
        }

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
            trending_category: 'popular',
            trending_has_more: true,
            trending_is_loading: false,
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
            api_results: [],
            api_loading: false,
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
            query: '',
            selected_category: 'all',
            selected_subcategory: 'all'
        });
        this.webfeed_state = {
            url: '',
            is_analyzing: false,
            is_refining: false,
            story_hint: '',
            variants: null,
            selected_variant: null,
            staleness_days: 30,
            mark_unread_on_change: false,
            error: null,
            request_id: null,
            html_hash: '',
            subscribed_feed: null
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
            selected_category: 'all',
            selected_subcategory: 'all',
            grouped_categories: this.GOOGLE_NEWS_CATEGORIES,
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
        if (!_.contains(['subscribers', 'stories', 'name'], sort_order)) sort_order = 'subscribers';

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
            'web-feed': 'render_webfeed_tab',
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
        var state = this.search_state;

        // Load trending feeds if not already loaded
        if (!state.trending_loaded && state.trending_feeds_collection.length === 0) {
            this.fetch_search_trending_feeds();
        }

        var $container = $.make('div', { className: 'NB-add-site-discover-container' });

        // Trending Sites Section
        var trending_categories = [
            { id: 'popular', label: 'Popular', description: 'Most subscribed-to feeds this week' },
            { id: 'rising', label: 'Rising', description: 'Small feeds with the fastest-growing subscriber base' },
            { id: 'hidden_gems', label: 'Hidden Gems', description: 'Feeds with deeply engaged readers, not yet widely known' },
            { id: 'new_arrivals', label: 'New Arrivals', description: 'Recently added feeds that are gaining subscribers' }
        ];
        var $trending_pills = $.make('div', { className: 'NB-add-site-trending-pills' },
            _.map(trending_categories, function (cat) {
                var active = (cat.id === state.trending_category) ? ' NB-active' : '';
                return $.make('div', {
                    className: 'NB-add-site-trending-pill' + active,
                    'data-category': cat.id
                }, cat.label);
            })
        );
        var active_cat = _.find(trending_categories, function (c) { return c.id === state.trending_category; });
        var $trending_description = $.make('div', { className: 'NB-add-site-trending-description' }, active_cat.description);

        var $trending_section = $.make('div', { className: 'NB-add-site-section NB-add-site-trending-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, [
                    $.make('img', { src: '/media/img/icons/nouns/pulse.svg', className: 'NB-add-site-section-icon' }),
                    'Trending Sites'
                ]),
                $.make('select', { className: 'NB-add-site-trending-days' }, [
                    $.make('option', { value: '1', selected: state.trending_days === 1 }, 'Today'),
                    $.make('option', { value: '7', selected: state.trending_days === 7 }, 'This Week'),
                    $.make('option', { value: '30', selected: state.trending_days === 30 }, 'This Month')
                ])
            ]),
            $trending_pills,
            $trending_description,
            $.make('div', { className: 'NB-add-site-section-content NB-add-site-trending-content' })
        ]);

        // Render trending feeds based on view mode
        var $trending_content = $trending_section.find('.NB-add-site-trending-content');
        if (state.trending_feeds_collection.length > 0) {
            $trending_content.append(this.render_trending_feeds());
        } else if (state.trending_loaded) {
            $trending_content.append(this.make_no_results_message(
                '',
                'No trending sites available',
                'Check back later for popular sites being added by NewsBlur users.'
            ));
        } else {
            $trending_content.append(this.make_loading_indicator());
        }

        $container.append($trending_section);

        return $container;
    },

    render_trending_feeds: function () {
        var self = this;
        var state = this.search_state;

        if (this.view_mode === 'grid') {
            var $grid = this.make_results_container();
            state.trending_feeds_collection.each(function (trending_feed) {
                var feed = trending_feed.get("feed");
                var feed_data = feed.toJSON ? feed.toJSON() : feed;
                $grid.append(self.render_feed_card(feed_data));
            });
            return $grid;
        } else {
            return this.render_list_view_feeds(state.trending_feeds_collection, { feed_key: 'on_trending_feed' });
        }
    },

    fetch_search_trending_feeds: function (append) {
        var self = this;
        var state = this.search_state;

        if (state.trending_is_loading) return;
        state.trending_is_loading = true;

        state.trending_feeds_collection.fetch({
            data: { page: state.trending_page, days: state.trending_days, category: state.trending_category },
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
        var page_size = 20;  // Match backend page size
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

    fetch_popular_channels: function (channel_type) {
        var self = this;
        var config = this.SOURCE_MAP[channel_type];
        if (!config) return;
        var state = this[config.state];
        var render_method = config.render;

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
            self[render_method]();
        }, function () {
            state.popular_feeds_loaded = true;
            state.popular_feeds_collection = new NEWSBLUR.Collections.TrendingFeeds([]);
            self[render_method]();
        }, { request_type: 'GET' });
    },

    // apps/discover/views.py - fetch_popular_feeds
    fetch_popular_feeds: function (feed_type, options) {
        var self = this;
        options = options || {};
        var type_config = this.FEED_TYPE_MAP[feed_type];
        if (!type_config) return;
        var state = this[type_config.state];
        var render_method = type_config.render;

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
            include_stories: 'true'
        };
        if (platform && platform !== 'all') {
            params.platform = platform;
        }
        if (state.query) {
            params.query = state.query;
        }

        this.model.make_request('/discover/popular_feeds', params, function (data) {
            if (data && data.feeds) {
                // Sort feeds with stories before feeds without, preserving
                // subscriber-count order within each group.
                var sorted_feeds = _.sortBy(data.feeds, function (f) {
                    var linked = f.feed || {};
                    return (linked.last_story_date || f.last_story_date) ? 0 : 1;
                });
                if (is_load_more) {
                    state.popular_feeds = state.popular_feeds.concat(sorted_feeds);
                } else {
                    state.popular_feeds = sorted_feeds;
                }
                state.popular_offset = offset + data.feeds.length;
                state.popular_has_more = data.has_more;
                if (data.total !== undefined) {
                    state.popular_total = data.total;
                }
                if (data.categories && data.categories.length > 0) {
                    state.available_categories = data.categories;
                }
                if (data.platform_counts) {
                    var had_platform_counts = state.platform_counts && _.keys(state.platform_counts).length > 0;
                    state.platform_counts = data.platform_counts;
                    if (!had_platform_counts && feed_type === 'newsletter') {
                        var $existing_pills = self.$('.NB-add-site-newsletters-tab .NB-add-site-filter-pills');
                        if ($existing_pills.length) {
                            $existing_pills.replaceWith(self.make_platform_pills(state));
                        }
                    }
                }
                if (data.grouped_categories && data.grouped_categories.length > 0) {
                    var had_categories = state.grouped_categories && state.grouped_categories.length > 0;
                    state.grouped_categories = data.grouped_categories;

                    // Resolve pending URL slugs now that real category names are available
                    if (state._pending_category_slug) {
                        var resolved = self._resolve_from_grouped(state._pending_category_slug, data.grouped_categories, 'category');
                        if (resolved !== state.selected_category) {
                            state.selected_category = resolved;
                        }
                        state._pending_category_slug = null;
                    }
                    var needs_refetch = false;
                    if (state._pending_subcategory_slug) {
                        var resolved_sub = self._resolve_from_grouped(state._pending_subcategory_slug, data.grouped_categories, 'subcategory');
                        if (resolved_sub !== state.selected_subcategory) {
                            state.selected_subcategory = resolved_sub;
                            needs_refetch = true;
                        }
                        state._pending_subcategory_slug = null;
                    }

                    // Only rebuild pills on first load when categories arrive;
                    // subsequent fetches (category/subcategory filter changes) keep
                    // existing pills to avoid re-render flash.
                    if (!had_categories) {
                        self.update_category_pills(feed_type);
                    }

                    // Re-fetch if slug resolution changed the subcategory after
                    // the initial request already returned with wrong results
                    if (needs_refetch) {
                        state.popular_feeds_loaded = false;
                        state.popular_feeds = [];
                        state.popular_feeds_collection = null;
                        state.popular_offset = 0;
                        if (render_method) {
                            self[render_method]();
                        }
                        return;
                    }
                }

                // Always build collection so grid→list toggle is instant
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
            state.popular_feeds_loaded = true;
            state.popular_loading_more = false;
            self[render_method]();
        }, function () {
            state.popular_feeds_loaded = true;
            state.popular_loading_more = false;
            state.popular_feeds = state.popular_feeds || [];
            self[render_method]();
        }, { request_type: 'GET' });
    },

    load_more_popular_feeds: function (feed_type) {
        var type_config = this.FEED_TYPE_MAP[feed_type];
        if (!type_config) return;
        var state = this[type_config.state];
        if (!state || state.popular_loading_more || !state.popular_has_more) return;
        this.fetch_popular_feeds(feed_type, { load_more: true });
    },

    make_scroll_loading_indicator: function () {
        var $fragment = $(document.createDocumentFragment());
        for (var i = 0; i < 2; i++) {
            $fragment.append(this.make_skeleton_card());
        }
        return $fragment;
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
    // add_site_view.js - Maps feed_type (API) to tab/source name (UI)
    feed_type_to_source: function (feed_type) {
        return { 'rss': 'popular', 'newsletter': 'newsletters', 'podcast': 'podcasts' }[feed_type] || feed_type;
    },

    update_category_pills: function (feed_type) {
        var source = this.feed_type_to_source(feed_type);
        var type_config = this.FEED_TYPE_MAP[feed_type];
        if (!type_config) return;
        var state = this[type_config.state];
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
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Discover Sites'),
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

        // Ensure the persistent section wrapper with header + search exists.
        // Only the .NB-add-site-section-content inside it gets replaced on
        // each render so the search input retains focus and typed text.
        var $section = $results.find('.NB-add-site-section');
        if (!$section.length) {
            $section = this.make_persistent_section({
                state: state,
                default_title: 'Discover Sites',
                type_label: 'Sites',
                search_class: 'NB-add-site-popular-search',
                placeholder: 'Filter sites...'
            });
            $results.html($section);
        }

        // Update title (with category name) and count badge in the existing header
        this.update_section_header('.NB-add-site-popular-tab', state, 'Discover Sites', 'Sites');

        var $content = $section.find('.NB-add-site-section-content');

        // List view with linked Feed objects
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var $list = this.render_list_view_feeds(state.popular_feeds_collection);

            // Also render unfetched feeds as cards below the list view feeds
            var unfetched = _.filter(state.popular_feeds, function (f) { return !f.feed; });
            if (unfetched.length > 0) {
                var $grid = self.make_results_container();
                _.each(unfetched, function (feed) {
                    $grid.append(self.render_popular_card(feed));
                });
                $list.append($grid);
            }

            if (state.popular_loading_more) {
                $list.append(self.make_scroll_loading_indicator());
            }
            $content.html($list);
            return;
        }

        // Fetch from API if not loaded
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('rss');
            $content.html(this.make_loading_indicator());
            return;
        }

        var feeds = state.popular_feeds;
        if (!feeds || feeds.length === 0) {
            var empty_msg = state.query ? 'No sites found matching your filter.' : 'No sites found.';
            $content.html($.make('div', { className: 'NB-add-site-empty-state' }, empty_msg));
            return;
        }

        var $grid = this.make_results_container();
        _.each(feeds, function(feed) {
            $grid.append(self.render_popular_card(feed));
        });

        if (state.popular_loading_more) {
            $grid.append(self.make_scroll_loading_indicator());
        }

        $content.html($grid);
    },

    make_persistent_section: function (config) {
        var state = config.state;
        var title_text = this.get_section_title(state, config.default_title, config.type_label);
        var title_parts = [].concat(title_text);
        if (state.popular_total !== undefined) {
            title_parts.push(' ');
            title_parts.push($.make('span', { className: 'NB-add-site-section-count' },
                this.format_count(state.popular_total, config.type_label.toLowerCase())));
        }
        return $.make('div', { className: 'NB-add-site-section' }, [
            $.make('div', { className: 'NB-add-site-section-header' }, [
                $.make('div', { className: 'NB-add-site-section-title' }, title_parts),
                $.make('div', { className: 'NB-add-site-section-search' }, [
                    $.make('img', {
                        src: '/media/img/icons/lucide/search.svg',
                        className: 'NB-add-site-section-search-icon'
                    }),
                    $.make('input', {
                        type: 'text',
                        className: config.search_class + ' NB-add-site-section-search-input',
                        placeholder: config.placeholder,
                        value: state.query || ''
                    }),
                    $.make('div', {
                        className: 'NB-add-site-section-search-clear' + (state.query ? '' : ' NB-hidden')
                    }, '\u00d7')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-section-content' })
        ]);
    },

    get_section_title: function (state, default_title, type_label) {
        var category = state.selected_category;
        if (!category || category === 'all') return default_title;

        // Find the display name from grouped_categories
        var grouped = state.grouped_categories || [];
        var group = _.find(grouped, function(g) { return g.name === category; });
        var display_name = group ? group.name : category;
        // Title-case each word (e.g. "fitness & health" → "Fitness & Health")
        display_name = display_name.replace(/\b\w/g, function(c) { return c.toUpperCase(); });

        var parts = [display_name];
        var subcategory = state.selected_subcategory;
        if (subcategory && subcategory !== 'all') {
            var sub_display = subcategory.replace(/\b\w/g, function(c) { return c.toUpperCase(); });
            parts.push($.make('span', { className: 'NB-add-site-section-title-sep' }, ' \u203a '));
            parts.push(sub_display);
        }
        parts.push(' ' + type_label);

        return parts;
    },

    update_section_header: function (tab_selector, state, default_title, type_label) {
        var $title = this.$(tab_selector + ' .NB-add-site-section-title');
        if (!$title.length) return;

        // Update title text and separator
        var title_parts = this.get_section_title(state, default_title, type_label);
        var $count = $title.find('.NB-add-site-section-count');
        $title.contents().filter(function() { return this.nodeType === 3; }).remove();
        $title.find('.NB-add-site-section-title-sep').remove();
        var parts = [].concat(title_parts);
        for (var i = parts.length - 1; i >= 0; i--) {
            if (typeof parts[i] === 'string') {
                $title.prepend(document.createTextNode(parts[i]));
            } else {
                $title.prepend(parts[i]);
            }
        }

        // Update count badge
        if (state.popular_total !== undefined) {
            var count_text = this.format_count(state.popular_total, type_label.toLowerCase());
            if ($count.length) {
                $count.text(count_text);
            } else {
                $title.append(' ');
                $title.append($.make('span', { className: 'NB-add-site-section-count' }, count_text));
            }
        } else {
            $count.remove();
        }

        // Update filter badge: only exists in DOM when actively filtering
        var $badge = this.$(tab_selector + ' .NB-add-site-section-filter-badge');
        var trimmed_query = (state.query || '').trim();
        if (trimmed_query.length > 0) {
            if (!$badge.length) {
                $badge = $.make('div', { className: 'NB-add-site-section-filter-badge' }, [
                    $.make('span', { className: 'NB-add-site-section-filter-badge-label' }, 'Filtering for '),
                    $.make('span', { className: 'NB-add-site-section-filter-badge-query' }),
                    $.make('span', { className: 'NB-add-site-section-filter-badge-close' }, '\u00d7')
                ]);
                this.$(tab_selector + ' .NB-add-site-section-header').after($badge);
            }
            $badge.find('.NB-add-site-section-filter-badge-query').text('\u201c' + trimmed_query + '\u201d');
        } else {
            $badge.remove();
        }
    },

    render_popular_card: function (feed) {
        var linked = feed.feed || {};
        var sub_count = feed.subscriber_count || '';
        if (typeof sub_count === 'number') {
            sub_count = this.format_subscriber_count(sub_count).replace(' members', ' subscribers');
        }
        var meta_parts = [sub_count];

        return this.make_source_card({
            card_class: 'NB-add-site-popular-card',
            icon: feed.thumbnail_url || linked.favicon_url || linked.favicon || '/media/img/icons/heroicons-solid/rss.svg',
            fallback_icon: '/media/img/icons/heroicons-solid/rss.svg',
            title: feed.title,
            meta: meta_parts.filter(Boolean).join(' \u2022 '),
            description: feed.description,
            feed_url: feed.feed_url,
            feed_id: feed.feed_id || linked.id || null,
            popular_feed_id: feed.id,
            last_story_date: linked.last_story_date || feed.last_story_date,
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
                    $.make('img', { src: '/media/img/icons/lucide/youtube.svg' })
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

        var $section = $results.find('.NB-add-site-section');
        if (!$section.length) {
            $section = this.make_persistent_section({
                state: state,
                default_title: 'Discover Channels',
                type_label: 'Channels',
                search_class: 'NB-add-site-youtube-search',
                placeholder: 'Filter channels...'
            });
            $results.html($section);
        }

        this.update_section_header('.NB-add-site-youtube-tab', state, 'Discover Channels', 'Channels');

        var $content = $section.find('.NB-add-site-section-content');

        // List view with linked Feed objects: Use FeedBadge + StoryTitlesView
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var $list = this.render_list_view_feeds(state.popular_feeds_collection);

            var unfetched = _.filter(state.popular_feeds, function (f) { return !f.feed; });
            if (unfetched.length > 0) {
                var $grid = self.make_results_container();
                _.each(unfetched, function (channel) {
                    $grid.append(self.render_youtube_card(channel));
                });
                $list.append($grid);
            }

            if (state.popular_loading_more) {
                $list.append(self.make_scroll_loading_indicator());
            }
            $content.html($list);
            return;
        }

        // Fetch from API if not loaded (both grid and list views)
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('youtube');
            $content.html(this.make_loading_indicator());
            return;
        }

        // Card view: render feed cards from API data (grid view, or list view without linked Feed objects)
        var channels = state.popular_feeds;
        if (!channels || channels.length === 0) {
            var empty_msg = state.query ? 'No channels found matching your filter.' : 'No channels found.';
            $content.html($.make('div', { className: 'NB-add-site-empty-state' }, empty_msg));
            return;
        }

        var $grid = this.make_results_container();
        _.each(channels, function(channel) {
            $grid.append(self.render_youtube_card(channel));
        });

        if (state.popular_loading_more) {
            $grid.append(self.make_scroll_loading_indicator());
        }

        $content.html($grid);
    },

    render_youtube_card: function (channel) {
        var linked = channel.feed || {};
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
            feed_id: channel.feed_id || linked.id || null,
            popular_feed_id: channel.id,
            last_story_date: linked.last_story_date || channel.last_story_date,
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
                    $.make('img', { src: '/media/img/icons/phosphor-fill/reddit-logo-fill.svg' })
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

        this.render_reddit_popular();
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

        // Append direct-subscribe card below results
        if (state.query) {
            $grid.append(this.render_reddit_direct_add_card(state.query, state.results.length === 0));
        }

        $results.html($grid);
    },

    render_reddit_direct_add_card: function (query, no_results) {
        // Clean up query: strip r/ prefix, trim, remove spaces
        var name = query.replace(/^\/?r\//, '').trim().replace(/\s+/g, '');
        if (!name) return '';

        var feed_url = 'https://www.reddit.com/r/' + name + '/.rss';

        // Check if already subscribed
        var existing_feed = NEWSBLUR.assets.feeds.find(function (feed) {
            return feed.get('feed_address') === feed_url;
        });
        var subscribed = !!existing_feed;
        var feed_id = existing_feed ? existing_feed.id : null;

        var description = no_results
            ? 'No results found, but you can subscribe directly if you know the subreddit name.'
            : "Don't see your subreddit? Subscribe directly by name.";

        var $actions;
        if (subscribed) {
            $actions = $.make('div', { className: 'NB-add-site-card-actions NB-add-site-card-actions-subscribed' }, [
                $.make('div', { className: 'NB-subscribed-badge' }, [
                    $.make('span', { className: 'NB-subscribed-badge-check' }, '\u2713'),
                    ' Subscribed'
                ]),
                $.make('div', { className: 'NB-add-site-card-actions-row' }, [
                    $.make('div', {
                        className: 'NB-add-site-open-btn NB-modal-submit-button NB-modal-submit-green',
                        'data-feed-id': feed_id
                    }, 'Open')
                ])
            ]);
        } else {
            $actions = $.make('div', { className: 'NB-add-site-card-actions' }, [
                $.make('div', { className: 'NB-add-site-card-add-group' }, [
                    this.make_folder_selector(),
                    $.make('div', {
                        className: 'NB-add-site-subscribe-btn NB-modal-submit-button NB-modal-submit-grey',
                        'data-feed-url': feed_url
                    }, 'Add')
                ])
            ]);
        }

        return $.make('div', {
            className: 'NB-add-site-card NB-add-site-reddit-direct-card' + (subscribed ? ' NB-add-site-card-subscribed' : ''),
            'data-feed-url': feed_url,
            'data-feed-id': feed_id
        }, [
            $.make('div', { className: 'NB-add-site-card-header' }, [
                $.make('img', {
                    src: '/media/img/icons/phosphor-fill/reddit-logo-fill.svg',
                    className: 'NB-add-site-card-icon'
                }),
                $.make('div', { className: 'NB-add-site-card-info' }, [
                    $.make('div', { className: 'NB-add-site-card-title' }, 'Subscribe to r/' + name),
                    $.make('div', { className: 'NB-add-site-card-meta' }, feed_url)
                ])
            ]),
            $.make('div', { className: 'NB-add-site-card-desc' }, description),
            $actions
        ]);
    },

    render_reddit_popular: function () {
        var self = this;
        var state = this.reddit_state;
        var $results = this.$('.NB-add-site-reddit-tab .NB-add-site-source-results');

        var $section = $results.find('.NB-add-site-section');
        if (!$section.length) {
            $section = this.make_persistent_section({
                state: state,
                default_title: 'Discover Subreddits',
                type_label: 'Subreddits',
                search_class: 'NB-add-site-reddit-search',
                placeholder: 'Filter subreddits...'
            });
            $results.html($section);
        }

        this.update_section_header('.NB-add-site-reddit-tab', state, 'Discover Subreddits', 'Subreddits');

        var $content = $section.find('.NB-add-site-section-content');

        // List view with linked Feed objects
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var $list = this.render_list_view_feeds(state.popular_feeds_collection);

            var unfetched = _.filter(state.popular_feeds, function (f) { return !f.feed; });
            if (unfetched.length > 0) {
                var $grid = self.make_results_container();
                _.each(unfetched, function (subreddit) {
                    $grid.append(self.render_reddit_card(subreddit));
                });
                $list.append($grid);
            }

            if (state.popular_loading_more) {
                $list.append(self.make_scroll_loading_indicator());
            }
            $content.html($list);
            return;
        }

        // Try API-backed popular feeds first
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('reddit');
            $content.html(this.make_loading_indicator());
            return;
        }

        // Use API results if available, otherwise fall back to Reddit API
        var subreddits = state.popular_feeds;
        if (!subreddits || subreddits.length === 0) {
            // Fallback to Reddit API
            if (!state.popular_loaded) {
                $content.html(this.make_loading_indicator());
                this.fetch_reddit_popular();
                return;
            }
            subreddits = state.popular_subreddits;
        }

        var $grid = self.make_results_container();
        _.each(subreddits, function(subreddit) {
            $grid.append(self.render_reddit_card(subreddit));
        });

        if (state.popular_loading_more) {
            $grid.append(self.make_scroll_loading_indicator());
        }

        $content.html($grid);

        // Prepend direct-add card and append API results if searching
        if (state.query) {
            var $results = this.$('.NB-add-site-reddit-tab .NB-add-site-source-results');
            $results.find('.NB-add-site-reddit-direct-card').remove();
            var no_results = !subreddits || subreddits.length === 0;
            $results.prepend(this.render_reddit_direct_add_card(state.query, no_results));

            if (state.api_results.length > 0) {
                this.render_reddit_api_results();
            }
        }
    },

    render_reddit_api_results: function () {
        var self = this;
        var state = this.reddit_state;
        var $results = this.$('.NB-add-site-reddit-tab .NB-add-site-source-results');

        // Remove any previous API results section and direct-add card
        $results.find('.NB-add-site-reddit-api-section').remove();
        $results.find('.NB-add-site-reddit-direct-card').remove();

        if (!state.query) return;

        // Collect feed_urls already shown in popular feeds for deduplication
        var shown_urls = {};
        $results.find('.NB-add-site-reddit-card').each(function () {
            var url = $(this).data('feed-url');
            if (url) shown_urls[url] = true;
        });

        // Filter API results to only show new ones
        var new_results = _.filter(state.api_results, function (r) {
            return !shown_urls[r.feed_url];
        });

        if (new_results.length > 0) {
            var $section = $.make('div', { className: 'NB-add-site-reddit-api-section' }, [
                $.make('div', { className: 'NB-add-site-reddit-api-header' }, 'More from Reddit')
            ]);
            var $grid = this.make_results_container();
            _.each(new_results, function (subreddit) {
                $grid.append(self.render_reddit_card(subreddit));
            });
            $section.append($grid);
            $results.append($section);
        }

        // Prepend direct-add card at the top
        if (state.query) {
            var no_results = (!state.popular_feeds || state.popular_feeds.length === 0) && new_results.length === 0;
            $results.prepend(this.render_reddit_direct_add_card(state.query, no_results));
        }
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
        var linked = subreddit.feed || {};
        var subscribers = subreddit.subscribers || subreddit.subscriber_count;
        var subscriber_text = this.format_subscriber_count(subscribers);
        var title = subreddit.name ? ('r/' + subreddit.name) : subreddit.title;

        return this.make_source_card({
            card_class: 'NB-add-site-reddit-card',
            icon: subreddit.icon || subreddit.thumbnail_url || '/media/img/reader/reddit.png',
            fallback_icon: '/media/img/reader/reddit.png',
            title: title,
            meta: subscriber_text,
            description: subreddit.description,
            feed_url: subreddit.feed_url,
            feed_id: subreddit.feed_id || linked.id || null,
            popular_feed_id: subreddit.id,
            last_story_date: linked.last_story_date || subreddit.last_story_date,
            show_empty_freshness: true
        });
    },

    format_count: function (count, label) {
        if (count === 1) {
            label = label.replace(/ies$/, 'y').replace(/([^y])s$/, '$1');
        }
        return count.toLocaleString() + ' ' + label;
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

    make_platform_pills: function (state) {
        var self = this;
        var platform_counts = state.platform_counts || {};
        var selected = state.selected_platform || 'all';

        // Build platform list dynamically from data
        var platforms = [{ id: 'all', name: 'All', icon: '/media/img/icons/bootstrap-fill/grid-fill.svg' }];
        var platform_order = ['substack', 'medium', 'ghost', 'buttondown', 'beehiiv', 'convertkit', 'independent'];
        _.each(platform_order, function (pid) {
            if (platform_counts[pid]) {
                platforms.push({
                    id: pid,
                    name: self.NEWSLETTER_PLATFORMS[pid] || pid,
                    favicon: self.PLATFORM_FAVICONS[pid],
                    count: platform_counts[pid]
                });
            }
        });
        // Add any remaining platforms not in the ordered list
        _.each(platform_counts, function (count, pid) {
            if (pid && !_.find(platforms, function (p) { return p.id === pid; })) {
                platforms.push({
                    id: pid,
                    name: self.NEWSLETTER_PLATFORMS[pid] || pid,
                    favicon: self.PLATFORM_FAVICONS[pid],
                    count: count
                });
            }
        });

        return $.make('div', { className: 'NB-add-site-filter-pills' },
            _.map(platforms, function (platform) {
                var pill_content = [];
                if (platform.favicon) {
                    pill_content.push($.make('img', { src: platform.favicon, className: 'NB-add-site-filter-pill-favicon' }));
                } else if (platform.icon) {
                    pill_content.push($.make('img', { src: platform.icon, className: 'NB-add-site-filter-pill-icon' }));
                }
                pill_content.push($.make('span', platform.name));
                if (platform.count) {
                    pill_content.push($.make('span', { className: 'NB-add-site-filter-pill-count' }, '' + platform.count));
                }
                return $.make('div', {
                    className: 'NB-add-site-filter-pill' + (selected === platform.id ? ' NB-active' : ''),
                    'data-category': platform.id,
                    'data-source': 'newsletters-platform'
                }, pill_content);
            })
        );
    },

    render_newsletters_tab: function () {
        var state = this.newsletters_state;
        var $tab = this.$('.NB-add-site-newsletters-tab');

        var $platform_pills = this.make_platform_pills(state);

        var $category_pills = this.make_category_pills('newsletters', state);

        var $search_bar = this.render_tab_search_bar({
            input_class: 'NB-add-site-tab-search-input NB-add-site-newsletters-search',
            placeholder: 'Search newsletters or paste URL...',
            value: state.query || ''
        });

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-newsletters' }, [
                    $.make('img', { src: '/media/img/icons/lucide/mail.svg' })
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

        var $section = $results.find('.NB-add-site-section');
        if (!$section.length) {
            $section = this.make_persistent_section({
                state: state,
                default_title: 'Discover Newsletters',
                type_label: 'Newsletters',
                search_class: 'NB-add-site-newsletters-search',
                placeholder: 'Filter newsletters...'
            });
            $results.html($section);
        }

        this.update_section_header('.NB-add-site-newsletters-tab', state, 'Discover Newsletters', 'Newsletters');

        var $content = $section.find('.NB-add-site-section-content');

        // List view with linked Feed objects: Use FeedBadge + StoryTitlesView
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var $list = this.render_list_view_feeds(state.popular_feeds_collection);

            var unfetched = _.filter(state.popular_feeds, function (f) { return !f.feed; });
            if (unfetched.length > 0) {
                var $grid = self.make_results_container();
                _.each(unfetched, function (newsletter) {
                    $grid.append(self.render_newsletter_card(newsletter));
                });
                $list.append($grid);
            }

            if (state.popular_loading_more) {
                $list.append(self.make_scroll_loading_indicator());
            }
            $content.html($list);
            return;
        }

        // Fetch from API if not loaded (both grid and list views)
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('newsletter');
            $content.html(this.make_loading_indicator());
            return;
        }

        var newsletters = state.popular_feeds;
        if (!newsletters || newsletters.length === 0) {
            var empty_msg = state.query ? 'No newsletters found matching your filter.' : 'No newsletters found.';
            $content.html($.make('div', { className: 'NB-add-site-empty-state' }, empty_msg));
            return;
        }

        var $grid = self.make_results_container();
        _.each(newsletters, function(newsletter) {
            $grid.append(self.render_newsletter_card(newsletter));
        });

        if (state.popular_loading_more) {
            $grid.append(self.make_scroll_loading_indicator());
        }

        $content.html($grid);
    },

    // add_site_view.js - render_newsletter_card
    render_newsletter_card: function (newsletter) {
        var linked = newsletter.feed || {};
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
            feed_id: newsletter.feed_id || linked.id || null,
            popular_feed_id: newsletter.id,
            last_story_date: linked.last_story_date || newsletter.last_story_date,
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
                    $.make('img', { src: '/media/img/icons/lucide/podcast.svg' })
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

        var $section = $results.find('.NB-add-site-section');
        if (!$section.length) {
            $section = this.make_persistent_section({
                state: state,
                default_title: 'Discover Podcasts',
                type_label: 'Podcasts',
                search_class: 'NB-add-site-podcasts-search',
                placeholder: 'Filter podcasts...'
            });
            $results.html($section);
        }

        this.update_section_header('.NB-add-site-podcasts-tab', state, 'Discover Podcasts', 'Podcasts');

        var $content = $section.find('.NB-add-site-section-content');

        // List view with linked Feed objects: Use FeedBadge + StoryTitlesView
        if (this.view_mode === 'list' && state.popular_feeds_collection && state.popular_feeds_collection.length > 0) {
            var $list = this.render_list_view_feeds(state.popular_feeds_collection);

            var unfetched = _.filter(state.popular_feeds, function (f) { return !f.feed; });
            if (unfetched.length > 0) {
                var $grid = self.make_results_container();
                _.each(unfetched, function (podcast) {
                    $grid.append(self.render_podcast_card(podcast));
                });
                $list.append($grid);
            }

            if (state.popular_loading_more) {
                $list.append(self.make_scroll_loading_indicator());
            }
            $content.html($list);
            return;
        }

        // Fetch from API if not loaded (both grid and list views)
        if (!state.popular_feeds_loaded) {
            this.fetch_popular_feeds('podcast');
            $content.html(this.make_loading_indicator());
            return;
        }

        var podcasts = state.popular_feeds;
        if (!podcasts || podcasts.length === 0) {
            var empty_msg = state.query ? 'No podcasts found matching your filter.' : 'No podcasts found.';
            $content.html($.make('div', { className: 'NB-add-site-empty-state' }, empty_msg));
            return;
        }

        var $grid = self.make_results_container();
        _.each(podcasts, function(podcast) {
            $grid.append(self.render_podcast_card(podcast));
        });

        if (state.popular_loading_more) {
            $grid.append(self.make_scroll_loading_indicator());
        }

        $content.html($grid);
    },

    render_podcast_card: function (podcast) {
        var linked = podcast.feed || {};
        var meta_parts = [];
        if (podcast.artist) meta_parts.push(podcast.artist);
        var episodes = podcast.track_count || podcast.subscriber_count;
        if (episodes) meta_parts.push(episodes + ' episodes');

        var description = podcast.description || podcast.genre || '';

        return this.make_source_card({
            card_class: 'NB-add-site-podcast-card',
            icon: podcast.artwork || podcast.thumbnail_url || '/media/img/icons/lucide/podcast.svg',
            fallback_icon: '/media/img/icons/lucide/podcast.svg',
            title: podcast.name || podcast.title,
            meta: meta_parts.join(' \u2022 '),
            description: description,
            feed_url: podcast.feed_url,
            feed_id: podcast.feed_id || linked.id || null,
            popular_feed_id: podcast.id,
            last_story_date: linked.last_story_date || podcast.last_story_date,
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
                    $.make('img', { src: '/media/img/icons/lucide/newspaper.svg' })
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
                        this.make_category_pills('google-news', state),
                        $.make('div', { className: 'NB-add-site-google-news-controls' }, [
                            $.make('div', { className: 'NB-add-site-google-news-input-row' }, [
                                $.make('div', { className: 'NB-add-site-google-news-field NB-add-site-google-news-field-search' }, [
                                    $.make('label', { className: 'NB-add-site-google-news-label' }, 'Search keywords'),
                                    $.make('div', { className: 'NB-add-site-google-news-search-wrapper' }, [
                                        $.make('img', {
                                            src: '/media/img/icons/nouns/search.svg',
                                            className: 'NB-add-site-google-news-search-icon'
                                        }),
                                        $.make('input', {
                                            type: 'text',
                                            className: 'NB-add-site-tab-search-input NB-add-site-google-news-search-input',
                                            placeholder: 'Enter a topic or keywords...',
                                            value: state.query || ''
                                        })
                                    ])
                                ]),
                                $.make('div', { className: 'NB-add-site-google-news-field NB-add-site-google-news-field-folder' }, [
                                    $.make('label', { className: 'NB-add-site-google-news-label' }, 'Folder'),
                                    $.make('div', { className: 'NB-add-site-google-news-folder-row' }, [
                                        this.make_folder_selector(),
                                        $.make('div', { className: 'NB-add-site-google-news-folder-add-icon', title: 'New folder', role: 'button' }, '+')
                                    ])
                                ]),
                                $.make('div', { className: 'NB-add-site-google-news-field' }, [
                                    $.make('label', { className: 'NB-add-site-google-news-label' }, 'Language'),
                                    $.make('select', { className: 'NB-add-site-google-news-language' }, [
                                        $.make('option', { value: 'en' }, 'English'),
                                        $.make('option', { value: 'es' }, 'Spanish'),
                                        $.make('option', { value: 'fr' }, 'French'),
                                        $.make('option', { value: 'de' }, 'German'),
                                        $.make('option', { value: 'pt' }, 'Portuguese'),
                                        $.make('option', { value: 'ja' }, 'Japanese'),
                                        $.make('option', { value: 'zh' }, 'Chinese')
                                    ])
                                ]),
                                $.make('div', {
                                    className: 'NB-add-site-google-news-subscribe-btn' +
                                        (state.is_subscribed ? ' NB-subscribed' : '') +
                                        (state.is_loading ? ' NB-loading' : '')
                                }, state.is_subscribed ? 'Open Site' : (state.is_loading ? 'Subscribing...' : 'Subscribe'))
                            ]),
                            $.make('div', { className: 'NB-add-site-google-news-folder-input NB-hidden' }, [
                                $.make('div', { className: 'NB-add-site-google-news-folder-input-row' }, [
                                    $.make('input', {
                                        type: 'text',
                                        className: 'NB-add-site-google-news-folder-name',
                                        placeholder: 'New folder name...'
                                    }),
                                    $.make('div', { className: 'NB-loading' }),
                                    $.make('div', { className: 'NB-add-site-google-news-folder-submit' }, 'Add Folder')
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ]));

        if (state.language) {
            $tab.find('.NB-add-site-google-news-language').val(state.language);
        }
    },

    // =================
    // = Web Feed Tab =
    // =================

    render_webfeed_tab: function () {
        var state = this.webfeed_state;
        var $tab = this.$('.NB-add-site-web-feed-tab');

        var $search_bar = this.render_tab_search_bar({
            input_class: 'NB-add-site-tab-search-input NB-add-site-web-feed-search',
            placeholder: 'Paste any website URL...',
            value: state.url || '',
            is_loading: state.is_analyzing
        });

        if (state.is_analyzing) {
            $search_bar.find('.NB-add-site-search-btn').addClass('NB-disabled');
            $search_bar.find('.NB-add-site-web-feed-search').prop('disabled', true);
        }

        var $content_area = $.make('div', { className: 'NB-add-site-webfeed-content' });

        if (state.error) {
            $content_area.html($.make('div', { className: 'NB-add-site-webfeed-error' }, [
                $.make('div', { className: 'NB-add-site-webfeed-error-icon' }, '\u26a0'),
                $.make('div', { className: 'NB-add-site-webfeed-error-text' }, state.error)
            ]));
        } else if (state.is_analyzing && !state.variants) {
            $content_area.html($.make('div', { className: 'NB-add-site-webfeed-analyzing' }, [
                $.make('div', { className: 'NB-add-site-webfeed-analyzing-spinner NB-spinner' }),
                $.make('div', { className: 'NB-add-site-webfeed-analyzing-text' },
                    state.analyze_stage || 'Analyzing page to find story patterns...')
            ]));
        } else if (state.subscribe_stage) {
            $content_area.html(this.render_webfeed_subscribed(state));
        } else if (state.variants) {
            $content_area.html(this.render_webfeed_variants());
            if (!state._variants_animated) {
                state._variants_animated = true;
                var $cards = $content_area.find('.NB-add-site-webfeed-variant-card');
                var delay_per_card = Math.min(800, 4000 / Math.max($cards.length, 1));
                $cards.each(function (i) {
                    var $card = $(this);
                    setTimeout(function () { $card.addClass('NB-animate-in'); }, i * delay_per_card + 50);
                });
                var $subscribe = $content_area.find('.NB-add-site-webfeed-subscribe-section');
                if ($subscribe.length) {
                    setTimeout(function () { $subscribe.addClass('NB-animate-in'); }, $cards.length * delay_per_card + 50);
                }
            } else {
                $content_area.find('.NB-add-site-webfeed-variant-card, .NB-add-site-webfeed-subscribe-section').addClass('NB-animate-in');
            }
        } else {
            $content_area.html(this.render_webfeed_empty());
            if (!state._empty_animated) {
                state._empty_animated = true;
                var $cards = $content_area.find('.NB-add-site-webfeed-explainer-card');
                $cards.each(function (i) {
                    var $card = $(this);
                    setTimeout(function () { $card.addClass('NB-animate-in'); }, i * 200 + 100);
                });
            } else {
                $content_area.find('.NB-add-site-webfeed-explainer-card')
                    .addClass('NB-animate-in');
            }
        }

        $tab.html($.make('div', { className: 'NB-add-site-tab-with-search' }, [
            $.make('div', { className: 'NB-add-site-source-header' }, [
                $.make('div', { className: 'NB-add-site-source-icon NB-webfeed' }, [
                    $.make('img', { src: '/media/img/icons/nouns/web-feed.svg' })
                ]),
                $.make('div', { className: 'NB-add-site-source-info' }, [
                    $.make('div', { className: 'NB-add-site-source-title' }, 'Web Feed'),
                    $.make('div', { className: 'NB-add-site-source-desc' },
                        'Create a feed for any website, even without RSS.')
                ])
            ]),
            $search_bar,
            $content_area
        ]));
    },

    render_webfeed_empty: function () {
        var explainer_cards = [
            {
                icon: '/media/img/icons/nouns/web-feed-any-site.svg',
                title: 'Works on any website',
                desc: 'Paste any URL and NewsBlur creates a feed from the page, even without RSS.',
                detail: 'The page HTML is fetched and parsed to extract content structure.'
            },
            {
                icon: '/media/img/icons/nouns/web-feed-ai-analyze.svg',
                title: 'AI finds the stories',
                desc: 'You\'re presented with multiple story pattern options to choose from.',
                detail: 'XPath patterns identify story blocks, headlines, links, and images.'
            },
            {
                icon: '/media/img/icons/nouns/web-feed-refine.svg',
                title: 'Refine with a hint',
                desc: 'If none of the options match, type a story title you see on the page and we\'ll re-analyze.',
                detail: 'A second pass uses your hint to find the right pattern on the page.'
            },
            {
                icon: '/media/img/icons/nouns/web-feed-updates.svg',
                title: 'Updates come to you',
                desc: 'NewsBlur checks for changes and delivers new stories to your feed.',
                detail: 'Pages are re-checked on a configurable schedule and diffed for new content.'
            }
        ];

        var $cards = $.make('div', { className: 'NB-add-site-webfeed-explainer' },
            _.map(explainer_cards, function (card) {
                return $.make('div', { className: 'NB-add-site-webfeed-explainer-card' }, [
                    $.make('div', { className: 'NB-add-site-webfeed-explainer-illustration' }, [
                        $.make('img', {
                            src: card.icon,
                            className: 'NB-add-site-webfeed-explainer-img'
                        })
                    ]),
                    $.make('div', { className: 'NB-add-site-webfeed-explainer-title' }, card.title),
                    $.make('div', { className: 'NB-add-site-webfeed-explainer-desc' }, card.desc),
                    $.make('div', { className: 'NB-add-site-webfeed-explainer-detail' }, card.detail)
                ]);
            })
        );

        return $.make('div', { className: 'NB-add-site-webfeed-empty' }, [
            $cards
        ]);
    },

    render_webfeed_variants: function () {
        var self = this;
        var state = this.webfeed_state;
        var variants = state.variants || [];
        var base_url = state.url || '';
        var selected_variant = state.selected_variant !== null ? variants[state.selected_variant] : null;
        var page_title = state.page_title || base_url.split('//').pop().split('/')[0];

        // -- Hint card (first item, not selectable) --
        var $hint_card = $.make('div', {
            className: 'NB-add-site-webfeed-variant-card NB-add-site-webfeed-hint-card NB-animate-in'
        }, [
            $.make('div', { className: 'NB-add-site-webfeed-hint-header' }, [
                $.make('div', { className: 'NB-add-site-webfeed-hint-info' }, [
                    $.make('div', { className: 'NB-add-site-webfeed-hint-title' },
                        'Not seeing the right stories?'),
                    $.make('div', { className: 'NB-add-site-webfeed-hint-desc' },
                        'Describe a story you\'re looking for and we\'ll re-analyze the page to find it.')
                ])
            ]),
            $.make('div', { className: 'NB-add-site-webfeed-hint-form' }, [
                $.make('input', {
                    type: 'text',
                    className: 'NB-add-site-webfeed-hint-input',
                    placeholder: 'Type a story title you see on the page',
                    value: state.story_hint || ''
                }),
                $.make('div', {
                    className: 'NB-add-site-webfeed-hint-btn' + (state.is_refining ? ' NB-disabled' : '')
                }, state.is_refining ? [
                    $.make('div', { className: 'NB-add-site-webfeed-hint-spinner NB-spinner' }),
                    'Re-analyzing\u2026'
                ] : 'Re-analyze')
            ])
        ]);

        // -- Variants section --
        var $variants_section = $.make('div', { className: 'NB-add-site-webfeed-variants-section' }, [
            $.make('div', { className: 'NB-add-site-webfeed-section-header' }, [
                $.make('div', { className: 'NB-add-site-webfeed-section-title' },
                    'Choose a story pattern'),
                $.make('div', { className: 'NB-add-site-webfeed-section-subtitle' },
                    'Found ' + variants.length + ' patterns. Select the one that best matches the stories you want.')
            ]),
            $.make('div', { className: 'NB-add-site-webfeed-variant-cards' + (state.is_refining ? ' NB-refining' : '') },
                [$hint_card].concat(_.map(variants, function (variant, index) {
                    var is_selected = state.selected_variant === index;
                    var story_count = (variant.preview_stories || []).length;
                    var $preview_stories = $.make('div', { className: 'NB-add-site-webfeed-preview-stories' },
                        _.map(variant.preview_stories || [], function (story) {
                            var $story_elements = [];
                            var img_src = story.image;
                            if (img_src && img_src.indexOf('background-image') !== -1) {
                                var bg_match = img_src.match(/background-image\s*:\s*url\(\s*['"]?(.*?)['"]?\s*\)/i);
                                img_src = bg_match ? bg_match[1] : null;
                            }
                            if (img_src && !img_src.match(/^https?:\/\//)) {
                                try {
                                    img_src = new URL(img_src, base_url).href;
                                } catch (e) {
                                    img_src = null;
                                }
                            }
                            if (img_src) {
                                $story_elements.push($.make('img', {
                                    className: 'NB-add-site-webfeed-preview-story-image',
                                    src: img_src,
                                    loading: 'lazy'
                                }));
                            }
                            var $text = $.make('div', { className: 'NB-add-site-webfeed-preview-story-text' }, [
                                $.make('div', { className: 'NB-add-site-webfeed-preview-story-title' },
                                    story.title || '(no title)'),
                                story.content ? $.make('div', {
                                    className: 'NB-add-site-webfeed-preview-story-content'
                                }, story.content.substring(0, 100) + (story.content.length > 100 ? '...' : '')) : null
                            ]);
                            $story_elements.push($text);
                            return $.make('div', {
                                className: 'NB-add-site-webfeed-preview-story' + (img_src ? ' NB-has-image' : '')
                            }, $story_elements);
                        })
                    );

                    return $.make('div', {
                        className: 'NB-add-site-webfeed-variant-card' + (is_selected ? ' NB-active' : ''),
                        'data-variant-index': index
                    }, [
                        $.make('div', { className: 'NB-add-site-webfeed-variant-card-header' }, [
                            $.make('div', { className: 'NB-add-site-webfeed-variant-radio' + (is_selected ? ' NB-selected' : '') }),
                            $.make('div', { className: 'NB-add-site-webfeed-variant-card-info' }, [
                                $.make('div', { className: 'NB-add-site-webfeed-variant-label' },
                                    variant.label || 'Variant ' + (index + 1)),
                                $.make('div', { className: 'NB-add-site-webfeed-variant-desc' }, variant.description || '')
                            ]),
                            $.make('div', { className: 'NB-add-site-webfeed-variant-count' },
                                story_count + (story_count === 1 ? ' story' : ' stories'))
                        ]),
                        $preview_stories
                    ]);
                }))
            )
        ]);

        // -- Subscribe section (only shown when variant selected) --
        var favicon_src = state.favicon_url || '';
        if (favicon_src && !favicon_src.match(/^https?:\/\//)) {
            try { favicon_src = new URL(favicon_src, base_url).href; } catch (e) { favicon_src = ''; }
        }

        var $feed_badge = $.make('div', { className: 'NB-add-site-webfeed-feed-badge' }, [
            $.make('div', { className: 'NB-add-site-webfeed-feed-badge-icon' }, [
                favicon_src
                    ? $.make('img', { src: favicon_src, className: 'NB-add-site-webfeed-feed-badge-favicon' })
                    : $.make('img', { src: '/media/img/icons/nouns/web-feed.svg', className: 'NB-add-site-webfeed-feed-badge-favicon NB-default-icon' })
            ]),
            $.make('div', { className: 'NB-add-site-webfeed-feed-badge-info' }, [
                $.make('div', { className: 'NB-add-site-webfeed-feed-badge-title' }, page_title),
                $.make('div', { className: 'NB-add-site-webfeed-feed-badge-url' }, base_url),
                selected_variant
                    ? $.make('div', { className: 'NB-add-site-webfeed-feed-badge-pattern' },
                        'Pattern: ' + (selected_variant.label || ''))
                    : null
            ])
        ]);

        var $options = $.make('div', {
            className: 'NB-add-site-webfeed-subscribe-section' + (state.selected_variant !== null ? '' : ' NB-hidden')
        }, [
            $.make('div', { className: 'NB-add-site-webfeed-section-header' }, [
                $.make('div', { className: 'NB-add-site-webfeed-section-title' }, 'Subscribe')
            ]),
            $feed_badge,
            $.make('div', { className: 'NB-add-site-webfeed-options' }, [
                $.make('div', { className: 'NB-add-site-webfeed-option' }, [
                    $.make('label', { className: 'NB-add-site-webfeed-option-label' },
                        'Alert after ' + state.staleness_days + (state.staleness_days === 1 ? ' day' : ' days') + ' without new stories'),
                    $.make('input', {
                        type: 'range',
                        className: 'NB-add-site-webfeed-staleness-slider',
                        min: '1',
                        max: '365',
                        value: String(state.staleness_days)
                    })
                ]),
                $.make('div', { className: 'NB-add-site-webfeed-option' }, [
                    $.make('label', { className: 'NB-add-site-webfeed-option-label' }, 'When story content changes'),
                    $.make('div', { className: 'NB-add-site-webfeed-radio-group' }, [
                        $.make('label', {
                            className: 'NB-add-site-webfeed-radio-option' + (!state.mark_unread_on_change ? ' NB-selected' : '')
                        }, [
                            $.make('input', {
                                type: 'radio',
                                name: 'webfeed_unread_behavior',
                                className: 'NB-add-site-webfeed-unread-radio',
                                value: 'keep',
                                checked: !state.mark_unread_on_change
                            }),
                            $.make('span', { className: 'NB-add-site-webfeed-radio-label' }, 'Keep read status')
                        ]),
                        $.make('label', {
                            className: 'NB-add-site-webfeed-radio-option' + (state.mark_unread_on_change ? ' NB-selected' : '')
                        }, [
                            $.make('input', {
                                type: 'radio',
                                name: 'webfeed_unread_behavior',
                                className: 'NB-add-site-webfeed-unread-radio',
                                value: 'unread',
                                checked: state.mark_unread_on_change
                            }),
                            $.make('span', { className: 'NB-add-site-webfeed-radio-label' }, 'Mark as unread')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-add-site-webfeed-option' }, [
                    $.make('label', { className: 'NB-add-site-webfeed-option-label' }, 'Add to folder'),
                    $.make('div', { className: 'NB-add-site-webfeed-folder-row' }, [
                        self.make_folder_selector(),
                        $.make('div', { className: 'NB-add-site-webfeed-folder-add-icon', title: 'New folder', role: 'button' }, '+')
                    ]),
                    $.make('div', { className: 'NB-add-site-webfeed-folder-input NB-hidden' }, [
                        $.make('div', { className: 'NB-add-site-webfeed-folder-input-row' }, [
                            $.make('input', {
                                type: 'text',
                                className: 'NB-add-site-webfeed-folder-name',
                                placeholder: 'New folder name...'
                            }),
                            $.make('div', { className: 'NB-loading' }),
                            $.make('div', { className: 'NB-add-site-webfeed-folder-submit' }, 'Add Folder')
                        ])
                    ])
                ])
            ]),
            !NEWSBLUR.Globals.is_archive ? $.make('div', { className: 'NB-add-site-webfeed-archive-banner' }, [
                $.make('div', { className: 'NB-add-site-webfeed-archive-banner-content' }, [
                    $.make('div', { className: 'NB-add-site-webfeed-archive-banner-icon' }),
                    $.make('div', { className: 'NB-add-site-webfeed-archive-banner-text' }, [
                        $.make('div', { className: 'NB-add-site-webfeed-archive-banner-title' }, [
                            'Web Feeds',
                            $.make('span', { className: 'NB-archive-badge' }, 'Premium Archive')
                        ]),
                        $.make('div', { className: 'NB-add-site-webfeed-archive-banner-body' },
                            'Subscribe to any website as a feed, even without RSS. Upgrade to Premium Archive to unlock Web Feeds.')
                    ])
                ]),
                $.make('div', { className: 'NB-add-site-webfeed-archive-banner-cta' },
                    'Upgrade to Premium Archive')
            ]) : null,
            $.make('div', {
                className: 'NB-add-site-webfeed-subscribe-btn NB-modal-submit-button NB-modal-submit-green' +
                    (!NEWSBLUR.Globals.is_archive ? ' NB-disabled' : '')
            }, 'Subscribe to ' + page_title)
        ]);

        return $.make('div', { className: 'NB-add-site-webfeed-results' }, [$variants_section, $options]);
    },

    render_webfeed_subscribed: function (state) {
        var stage = state.subscribe_stage;
        var feed = state.subscribed_feed;
        var feed_title = (feed && feed.feed_title) || state.page_title || 'Web Feed';

        var stage_labels = {
            'subscribed': 'Subscribed! Fetching stories...',
            'fetching': 'Fetching page...',
            'processing': 'Processing stories...',
            'complete': 'Done!',
            'error': 'Fetch error: ' + (state.subscribe_error || 'Unknown error')
        };
        var status_text = stage_labels[stage] || 'Subscribing...';
        var is_done = (stage === 'complete');
        var is_error = (stage === 'error');
        var is_loading = !is_done && !is_error;

        var $status_items = [];
        if (is_loading) {
            $status_items.push(
                $.make('div', { className: 'NB-add-site-webfeed-subscribe-progress' }, [
                    $.make('div', { className: 'NB-add-site-webfeed-analyzing-spinner NB-spinner' }),
                    $.make('div', { className: 'NB-add-site-webfeed-subscribe-status' }, status_text)
                ])
            );
        } else if (is_error) {
            $status_items.push(
                $.make('div', { className: 'NB-add-site-webfeed-subscribe-status NB-error' }, status_text)
            );
        }

        return $.make('div', { className: 'NB-add-site-webfeed-subscribed' }, [
            $.make('div', { className: 'NB-add-site-webfeed-subscribed-icon' }, is_done ? '\u2713' : (is_error ? '\u26a0' : '\u2713')),
            $.make('div', { className: 'NB-add-site-webfeed-subscribed-text' }, [
                $.make('div', { className: 'NB-add-site-webfeed-subscribed-title' },
                    is_done ? 'Subscribed!' : (is_error ? 'Subscribed with errors' : 'Subscribed!')),
                $.make('div', { className: 'NB-add-site-webfeed-subscribed-desc' },
                    is_done ? 'Feed "' + feed_title + '" is ready.' :
                    'Feed "' + feed_title + '" has been created.'),
                $.make('div', { className: 'NB-add-site-webfeed-subscribe-stages' }, $status_items)
            ])
        ]);
    },

    perform_webfeed_analyze: function () {
        if (this.webfeed_state.is_analyzing) return;

        var $input = this.$('.NB-add-site-web-feed-search');
        var url = ($input.val() || '').trim();

        if (!url) return;
        if (!url.match(/^https?:\/\//)) {
            url = 'https://' + url;
            $input.val(url);
        }

        var request_id = 'wf_' + Date.now() + '_' + Math.random().toString(36).substr(2, 8);

        this.webfeed_state.url = url;
        this.webfeed_state.is_analyzing = true;
        this.webfeed_state.variants = null;
        this.webfeed_state.selected_variant = null;
        this.webfeed_state.error = null;
        this.webfeed_state.request_id = request_id;
        this.webfeed_state.subscribed_feed = null;
        this.webfeed_state._variants_animated = false;
        this.webfeed_state._empty_animated = false;
        this.webfeed_state.analyze_stage = null;

        this.render_webfeed_tab();

        if (this._webfeed_timeout) clearTimeout(this._webfeed_timeout);
        this._webfeed_timeout = setTimeout(_.bind(function () {
            if (this.webfeed_state.is_analyzing && this.webfeed_state.request_id === request_id) {
                this.webfeed_state.is_analyzing = false;
                this.webfeed_state.error = 'Analysis timed out. Please try again.';
                this.render_webfeed_tab();
            }
        }, this), 60000);

        NEWSBLUR.assets.analyze_webfeed(url, request_id, _.bind(function (data) {
            if (data.code < 0) {
                if (this._webfeed_timeout) clearTimeout(this._webfeed_timeout);
                this.webfeed_state.is_analyzing = false;
                this.webfeed_state.error = data.message;
                this.render_webfeed_tab();
            }
        }, this));
    },

    handle_webfeed_search_keypress: function (e) {
        if (e.which === 13) {
            this.perform_webfeed_analyze();
        }
    },

    handle_webfeed_hint_keypress: function (e) {
        if (e.which === 13) {
            this.perform_webfeed_refine();
        }
    },

    perform_webfeed_refine: function () {
        if (this.webfeed_state.is_refining || this.webfeed_state.is_analyzing) return;

        var hint = this.$('.NB-add-site-webfeed-hint-input').val().trim();
        if (!hint) return;

        var url = this.webfeed_state.url;
        var request_id = 'wf_' + Date.now() + '_' + Math.random().toString(36).substr(2, 8);

        this.webfeed_state.story_hint = hint;
        this.webfeed_state.is_refining = true;
        this.webfeed_state.selected_variant = null;
        this.webfeed_state.request_id = request_id;
        this.webfeed_state._variants_animated = true;

        this.render_webfeed_tab();

        if (this._webfeed_timeout) clearTimeout(this._webfeed_timeout);
        this._webfeed_timeout = setTimeout(_.bind(function () {
            if (this.webfeed_state.is_refining && this.webfeed_state.request_id === request_id) {
                this.webfeed_state.is_refining = false;
                this.webfeed_state.error = 'Re-analysis timed out. Please try again.';
                this.render_webfeed_tab();
            }
        }, this), 60000);

        NEWSBLUR.assets.analyze_webfeed(url, request_id, _.bind(function (data) {
            if (data.code < 0) {
                if (this._webfeed_timeout) clearTimeout(this._webfeed_timeout);
                this.webfeed_state.is_refining = false;
                this.webfeed_state.error = data.message;
                this.render_webfeed_tab();
            }
        }, this), hint);
    },

    handle_webfeed_start: function (data) {
        if (data.request_id !== this.webfeed_state.request_id) return;
        this.webfeed_state.analyze_stage = 'Starting analysis...';
        this.update_webfeed_progress();
    },

    handle_webfeed_progress: function (data) {
        if (data.request_id !== this.webfeed_state.request_id) return;
        this.webfeed_state.analyze_stage = data.message;
        this.update_webfeed_progress();
    },

    update_webfeed_progress: function () {
        var $text = this.$('.NB-add-site-webfeed-analyzing-text');
        if ($text.length && this.webfeed_state.analyze_stage) {
            $text.text(this.webfeed_state.analyze_stage);
        }
    },

    handle_webfeed_variants: function (data) {
        if (data.request_id !== this.webfeed_state.request_id) return;
        if (this._webfeed_timeout) clearTimeout(this._webfeed_timeout);

        this.webfeed_state.is_analyzing = false;
        this.webfeed_state.is_refining = false;
        this.webfeed_state.variants = data.variants;
        this.webfeed_state.html_hash = data.html_hash || '';
        this.webfeed_state.page_title = data.page_title || '';
        this.webfeed_state.favicon_url = data.favicon_url || '';
        this.webfeed_state.error = null;
        this.webfeed_state._variants_animated = false;
        this.webfeed_state._empty_animated = false;
        this.render_webfeed_tab();
    },

    handle_webfeed_complete: function (data) {
        if (data.request_id !== this.webfeed_state.request_id) return;
        if (this._webfeed_timeout) clearTimeout(this._webfeed_timeout);

        if (this.webfeed_state.is_analyzing || this.webfeed_state.is_refining) {
            this.webfeed_state.is_analyzing = false;
            this.webfeed_state.is_refining = false;
            if (!this.webfeed_state.variants) {
                this.webfeed_state.error = 'No story patterns found on this page.';
            }
            this.render_webfeed_tab();
        }
    },

    handle_webfeed_error: function (data) {
        if (data.request_id !== this.webfeed_state.request_id) return;
        if (this._webfeed_timeout) clearTimeout(this._webfeed_timeout);

        this.webfeed_state.is_analyzing = false;
        this.webfeed_state.is_refining = false;
        this.webfeed_state.error = data.error || 'An error occurred during analysis.';
        this.render_webfeed_tab();
    },

    select_webfeed_variant: function (e) {
        var $card = $(e.currentTarget);
        var index = parseInt($card.data('variant-index'), 10);
        var state = this.webfeed_state;
        var variant = (state.variants || [])[index];

        state.selected_variant = index;

        // Update card active states in place
        this.$('.NB-add-site-webfeed-variant-card').removeClass('NB-active');
        $card.addClass('NB-active');
        this.$('.NB-add-site-webfeed-variant-radio').removeClass('NB-selected');
        $card.find('.NB-add-site-webfeed-variant-radio').addClass('NB-selected');

        // Show subscribe section and update pattern label
        var $subscribe = this.$('.NB-add-site-webfeed-subscribe-section');
        $subscribe.removeClass('NB-hidden');
        this.$('.NB-add-site-webfeed-feed-badge-pattern').text(
            'Pattern: ' + (variant ? variant.label || '' : ''));

        // Scroll subscribe section into view
        setTimeout(_.bind(function () {
            var $scrollable = this.$('.NB-add-site-webfeed-content');
            if ($scrollable.length && $subscribe.length) {
                $scrollable.animate({ scrollTop: $scrollable[0].scrollHeight }, 2000, 'swing');
            }
        }, this), 50);
    },

    update_webfeed_staleness: function (e) {
        var value = parseInt($(e.target).val(), 10);
        this.webfeed_state.staleness_days = value;
        $(e.target).closest('.NB-add-site-webfeed-option').find('.NB-add-site-webfeed-option-label').text(
            'Alert after ' + value + (value === 1 ? ' day' : ' days') + ' without new stories'
        );
    },

    toggle_webfeed_unread: function (e) {
        this.webfeed_state.mark_unread_on_change = $(e.target).val() === 'unread';
        this.$('.NB-add-site-webfeed-radio-option').removeClass('NB-selected');
        $(e.target).closest('.NB-add-site-webfeed-radio-option').addClass('NB-selected');
    },

    open_webfeed_upgrade_modal: function (e) {
        e.preventDefault();
        e.stopPropagation();
        NEWSBLUR.reader.open_premium_upgrade_modal();
    },

    subscribe_webfeed: function () {
        var state = this.webfeed_state;
        if (state.selected_variant === null || !state.variants) return;

        var variant = state.variants[state.selected_variant];
        var folder = this.$('.NB-add-site-webfeed-subscribe-section .NB-add-site-folder-select').val() || '';

        var $btn = this.$('.NB-add-site-webfeed-subscribe-btn');
        $btn.text('Subscribing...').addClass('NB-disabled');

        NEWSBLUR.assets.subscribe_webfeed(state.url, state.selected_variant, folder, {
            'story_container_xpath': variant.story_container,
            'title_xpath': variant.title,
            'link_xpath': variant.link,
            'content_xpath': variant.content || '',
            'image_xpath': variant.image || '',
            'author_xpath': variant.author || '',
            'date_xpath': variant.date || '',
            'html_hash': state.html_hash,
            'feed_title': state.page_title || '',
            'staleness_days': state.staleness_days,
            'mark_unread_on_change': state.mark_unread_on_change ? 'true' : 'false'
        }, _.bind(function (data) {
            if (data.code > 0) {
                var feed_id = data.feed ? data.feed.id : null;
                this.webfeed_state.subscribed_feed = data.feed;
                this.webfeed_state.subscribe_feed_id = feed_id;
                this.webfeed_state.subscribe_stage = 'subscribed';
                this.render_webfeed_tab();
                NEWSBLUR.assets.load_feeds();
            } else {
                var page_title = state.page_title || 'Web Feed';
                $btn.text('Subscribe to ' + page_title).removeClass('NB-disabled');
                this.webfeed_state.error = data.message;
                this.render_webfeed_tab();
            }
        }, this));
    },

    handle_webfeed_subscribe_update: function (data) {
        var state = this.webfeed_state;
        if (!state.subscribe_feed_id || data.feed_id != state.subscribe_feed_id) return;

        state.subscribe_stage = data.stage;
        if (data.stage === 'complete') {
            if (data.feed) {
                state.subscribed_feed = data.feed;
            }
            NEWSBLUR.assets.load_feeds(_.bind(function () {
                if (state.subscribe_feed_id) {
                    NEWSBLUR.reader.open_feed(state.subscribe_feed_id);
                }
            }, this));
        } else if (data.stage === 'error') {
            state.subscribe_stage = 'error';
            state.subscribe_error = data.error;
        }
        this.render_webfeed_tab();
    },

    handle_trending_days_change: function (e) {
        var new_days = parseInt($(e.currentTarget).val(), 10);
        var state = this.search_state;

        if (new_days !== state.trending_days) {
            state.trending_days = new_days;
            state.trending_page = 1;
            state.trending_has_more = true;
            state.trending_feeds_collection.reset();
            state.trending_loaded = false;
            this.fetch_search_trending_feeds();
        }
    },

    handle_trending_category_change: function (e) {
        var $pill = $(e.currentTarget);
        var category = $pill.data('category');
        var state = this.search_state;

        if (category === state.trending_category) return;

        state.trending_category = category;
        state.trending_page = 1;
        state.trending_has_more = true;
        state.trending_feeds_collection.reset();
        state.trending_loaded = false;

        $pill.siblings().removeClass('NB-active');
        $pill.addClass('NB-active');

        var descriptions = {
            'popular': 'Most subscribed-to feeds this week',
            'rising': 'Small feeds with the fastest-growing subscriber base',
            'hidden_gems': 'Feeds with deeply engaged readers, not yet widely known',
            'new_arrivals': 'Recently added feeds that are gaining subscribers'
        };
        var $section = $pill.closest('.NB-add-site-trending-section');
        $section.find('.NB-add-site-trending-description').text(descriptions[category]);
        $section.find('.NB-add-site-trending-content').html(this.make_loading_indicator());

        this.fetch_search_trending_feeds();
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
            // Original categories
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
            'security': '/media/img/icons/heroicons-solid/shield-check.svg',
            // Popular feeds categories
            'animemanga': '/media/img/icons/heroicons-solid/sparkles.svg',
            'architecture': '/media/img/icons/heroicons-solid/building-office.svg',
            'artsculture': '/media/img/icons/lucide/palette.svg',
            'automotive': '/media/img/icons/phosphor-fill/car-fill.svg',
            'booksreading': '/media/img/icons/heroicons-solid/book-open.svg',
            'careerjobmarket': '/media/img/icons/heroicons-solid/identification.svg',
            'comedyhumor': '/media/img/icons/heroicons-solid/face-smile.svg',
            'cryptocurrencyweb': '/media/img/icons/phosphor-fill/coins-fill.svg',
            'datascienceanalytics': '/media/img/icons/heroicons-solid/chart-bar-square.svg',
            'diycrafts': '/media/img/icons/heroicons-solid/scissors.svg',
            'economics': '/media/img/icons/heroicons-solid/banknotes.svg',
            'education': '/media/img/icons/heroicons-solid/academic-cap.svg',
            'entrepreneurshipstartups': '/media/img/icons/heroicons-solid/rocket-launch.svg',
            'environmentsustainability': '/media/img/icons/heroicons-solid/globe-americas.svg',
            'fashionbeauty': '/media/img/icons/phosphor-fill/sparkle-fill.svg',
            'foodcooking': '/media/img/icons/phosphor-fill/cooking-pot-fill.svg',
            'healthfitness': '/media/img/icons/heroicons-solid/heart.svg',
            'history': '/media/img/icons/heroicons-solid/clock.svg',
            'hobbiescollections': '/media/img/icons/heroicons-solid/squares-plus.svg',
            'homegarden': '/media/img/icons/heroicons-solid/home.svg',
            'internetculturesocialmedia': '/media/img/icons/heroicons-solid/at-symbol.svg',
            'lawlegal': '/media/img/icons/phosphor-fill/scales-fill.svg',
            'lifestyle': '/media/img/icons/heroicons-solid/sun.svg',
            'militarydefense': '/media/img/icons/phosphor-fill/shield-star-fill.svg',
            'newspolitics': '/media/img/icons/heroicons-solid/newspaper.svg',
            'parenting': '/media/img/icons/phosphor-fill/baby-fill.svg',
            'petsanimals': '/media/img/icons/phosphor-fill/paw-print-fill.svg',
            'philosophy': '/media/img/icons/heroicons-solid/light-bulb.svg',
            'productivityorganization': '/media/img/icons/heroicons-solid/clipboard-document-check.svg',
            'psychologymentalhealth': '/media/img/icons/lucide/brain.svg',
            'realestate': '/media/img/icons/heroicons-solid/home-modern.svg',
            'relationshipsdating': '/media/img/icons/heroicons-solid/chat-bubble-left-right.svg',
            'religionspirituality': '/media/img/icons/phosphor-fill/cross-fill.svg',
            'spaceastronomy': '/media/img/icons/lucide/telescope.svg',
            'sportsrecreation': '/media/img/icons/phosphor-fill/bicycle-fill.svg',
            'weatherclimate': '/media/img/icons/phosphor-fill/cloud-sun-fill.svg',
            'wellnessselfcare': '/media/img/icons/phosphor-fill/flower-lotus-fill.svg',
            // Cross-type categories (youtube, reddit, newsletter, podcast)
            'aimachinelearning': '/media/img/icons/heroicons-solid/cpu-chip.svg',
            'artdesign': '/media/img/icons/lucide/palette.svg',
            'automobiles': '/media/img/icons/phosphor-fill/car-fill.svg',
            'businessentrepreneurship': '/media/img/icons/heroicons-solid/briefcase.svg',
            'comedy': '/media/img/icons/heroicons-solid/face-smile.svg',
            'cookingfood': '/media/img/icons/phosphor-fill/cooking-pot-fill.svg',
            'culture': '/media/img/icons/phosphor-fill/mask-happy-fill.svg',
            'culturesociety': '/media/img/icons/phosphor-fill/mask-happy-fill.svg',
            'diyhobbies': '/media/img/icons/heroicons-solid/wrench-screwdriver.svg',
            'diyhowto': '/media/img/icons/heroicons-solid/wrench-screwdriver.svg',
            'educationlearning': '/media/img/icons/heroicons-solid/academic-cap.svg',
            'entertainmentcomedy': '/media/img/icons/heroicons-solid/face-smile.svg',
            'fictionstorytelling': '/media/img/icons/phosphor-fill/book-open-fill.svg',
            'filmtelevision': '/media/img/icons/heroicons-solid/film.svg',
            'financebusiness': '/media/img/icons/heroicons-solid/chart-bar.svg',
            'fitnesshealth': '/media/img/icons/heroicons-solid/heart.svg',
            'healthwellness': '/media/img/icons/heroicons-solid/heart.svg',
            'lifestyleculture': '/media/img/icons/heroicons-solid/sparkles.svg',
            'mediaentertainment': '/media/img/icons/heroicons-solid/film.svg',
            'newscurrentevents': '/media/img/icons/heroicons-solid/newspaper.svg',
            'politicsnews': '/media/img/icons/heroicons-solid/building-library.svg',
            'traveladventure': '/media/img/icons/heroicons-solid/globe-alt.svg',
            'travellifestyle': '/media/img/icons/heroicons-solid/globe-alt.svg',
            'truecrime': '/media/img/icons/phosphor-fill/detective-fill.svg'
        };

        var key = title.toLowerCase().replace(/[^a-z]/g, '');
        return icon_map[key] || '/media/img/icons/nouns/folder-closed.svg';
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
            this.update_url();
        }
    },

    go_back_to_categories: function () {
        this.categories_state.selected_category = null;
        this.render_categories_tab();
        this.update_url();
    },

    handle_source_pill_click: function (e) {
        var tab_id = $(e.currentTarget).data('tab');
        if (tab_id) {
            this.active_tab = tab_id;
            this.render();
            this.update_url();
        }
    },

    handle_section_link_click: function (e) {
        var tab_id = $(e.currentTarget).data('tab');
        if (tab_id) {
            this.active_tab = tab_id;
            this.render();
            this.update_url();
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
            this.newsletters_state.selected_category = 'all';
            this.newsletters_state.selected_subcategory = 'all';
            this.newsletters_state.popular_feeds_loaded = false;
            this.newsletters_state.popular_feeds = [];
            this.newsletters_state.popular_feeds_collection = null;
            this.newsletters_state.popular_offset = 0;
            this.newsletters_state.grouped_categories = [];
            // Clear search when platform pill is clicked (mutual exclusivity)
            this._clear_top_search_for_tab('newsletters');
            this.render_newsletters_tab();
        }
    },

    // Handle clicks on the two-level category/subcategory pill system
    // add_site_view.js - _handle_two_level_pill_click
    _handle_two_level_pill_click: function ($pill, source, level, category, subcategory) {
        var source_config = this.SOURCE_MAP[source];
        if (!source_config) return;
        var state = this[source_config.state];
        var render_method = source_config.render;

        // Source-specific pill click handler
        var custom_handler = '_handle_' + source.replace(/-/g, '_') + '_pill_click';
        if (this[custom_handler]) {
            this[custom_handler]($pill, source, level, category, subcategory, source_config, state);
            return;
        }

        // Clear top search bar when category pill is clicked (search and category are mutually exclusive)
        this._clear_top_search_for_tab(source);

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
            this[render_method]();
            this._scroll_popular_to_top();
            this.update_url();

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
            this[render_method]();
            this._scroll_popular_to_top();
            this.update_url();
        }
    },

    _scroll_popular_to_top: function () {
        var $scrollable = this.$('.NB-add-site-tab-results');
        if ($scrollable.length) {
            $scrollable.scrollTop(0);
        }
    },

    // add_site_view.js - _clear_top_search_for_tab: clear search when category pill is selected
    _clear_top_search_for_tab: function (source) {
        var config = this.TAB_SEARCH_CONFIG[source];
        if (!config) return;
        var state = this[config.state_key];
        if (!state.query) return;

        var $tab = this.$('.NB-add-site-' + config.tab_suffix + '-tab');
        var $top_input = $tab.find('.NB-add-site-search-wrapper .NB-add-site-' + config.input_suffix + '-search');

        // If no top search bar exists (e.g., Popular tab), don't clear
        if (!$top_input.length) return;

        state.query = '';
        state.results = [];

        // Clear the top search bar input and hide its clear button
        $top_input.val('');
        $tab.find('.NB-add-site-search-wrapper .NB-add-site-search-clear').addClass('NB-hidden');

        // Clear the inline filter input and its clear button + filter badge
        var $inline_input = $tab.find('.NB-add-site-section-search .NB-add-site-' + config.input_suffix + '-search');
        $inline_input.val('');
        $tab.find('.NB-add-site-section-search-clear').addClass('NB-hidden');
        $tab.find('.NB-add-site-section-filter-badge').remove();
    },

    // add_site_view.js - _reset_category_to_all: reset category pills when top search bar is used
    _reset_category_to_all: function (source) {
        var source_config = this.SOURCE_MAP[source];
        if (!source_config) return;
        var state = this[source_config.state];

        if (state.selected_category === 'all' && state.selected_subcategory === 'all') return;

        state.selected_category = 'all';
        state.selected_subcategory = 'all';

        // Visually reset pills: deactivate all, activate 'All'
        var $tab = this.$('.NB-add-site-' + source + '-tab');
        var $container = $tab.find('.NB-add-site-category-pills-container');
        $container.find('.NB-add-site-cat-pill').removeClass('NB-active');
        $container.find('.NB-add-site-cat-pill[data-category="all"]').addClass('NB-active');
        $container.find('.NB-add-site-subcat-pills-row').removeClass('NB-visible').empty();

        this.update_url();
    },

    // ==================
    // = Shared Methods =
    // ==================

    // add_site_view.js - render_list_view_feeds: shared FeedBadge + StoryTitlesView renderer
    // Used by render_trending_feeds, render_popular_popular, render_youtube_popular,
    // render_newsletters_popular, render_podcasts_popular, and append_trending_feeds
    render_list_view_feeds: function (collection, options) {
        var self = this;
        options = options || {};
        var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
        var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
        var $list = $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor + ' NB-image-preview-' + image_preview });
        var stories_limit = this.get_stories_limit();
        var feed_key = options.feed_key || 'on_popular_feed';

        collection.each(function (feed_model) {
            var $badge_content = [
                new NEWSBLUR.Views.FeedBadge({
                    model: feed_model.get("feed"),
                    show_folders: true,
                    in_add_site_view: self,
                    load_feed_after_add: false
                })
            ];

            if (stories_limit > 0) {
                var $story_titles = $.make('div', { className: 'NB-story-titles' });
                var limited_stories = self.limit_stories(feed_model.get("stories"));
                var story_opts = {
                    el: $story_titles,
                    collection: limited_stories,
                    $story_titles: $story_titles,
                    override_layout: 'split',
                    pane_anchor: pane_anchor,
                    in_add_site_view: self
                };
                story_opts[feed_key] = feed_model;
                var story_titles_view = new NEWSBLUR.Views.StoryTitlesView(story_opts);
                $badge_content.push(story_titles_view.render().el);
            }

            var $badge = $.make('div', { className: 'NB-trending-feed-badge' }, $badge_content);
            $list.append($badge);
        });

        return $list;
    },

    render_feed_card: function (feed, stories) {
        var self = this;
        stories = stories || [];

        // Check if already subscribed. Use feed.feed (actual Feed FK from popular_feeds API)
        // or feed.feed_id (from search results), NOT feed.id (which may be PopularFeed PK).
        // Only check feeds collection, not temp_feeds (which contains try feeds).
        var feed_id = feed.feed || feed.feed_id || feed.id;
        var feed_model = feed_id && NEWSBLUR.assets.feeds.get(feed_id);
        var subscribed = feed_model && !feed_model.get('temp');

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
            var subscriber_count = Math.max(0, parseInt(feed.num_subscribers, 10));
            if (subscriber_count > 0) {
                var subscriber_label = subscriber_count === 1 ? 'subscriber' : 'subscribers';
                meta_parts.push(subscriber_count.toLocaleString() + ' ' + subscriber_label);
            }
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

        // Check if already subscribed (exclude temp feeds from try view)
        var feed_id = config.feed_id;
        var feed_model = feed_id && NEWSBLUR.assets.feeds.get(feed_id);
        var subscribed = feed_model && !feed_model.get('temp');

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
        var card_attrs = {
            className: 'NB-add-site-card ' + config.card_class + (subscribed ? ' NB-add-site-card-subscribed' : ''),
            'data-feed-id': feed_id
        };
        if (config.popular_feed_id) {
            card_attrs['data-popular-feed-id'] = config.popular_feed_id;
        }
        if (config.feed_url) {
            card_attrs['data-feed-url'] = config.feed_url;
        }
        return $.make('div', card_attrs, [
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

    make_folder_selector: function (selected_folder) {
        var folders = NEWSBLUR.utils.make_folders(selected_folder);
        var $select = $(folders).addClass('NB-add-site-folder-select');
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
        this.update_url();
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
            this.update_url();
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
        var $wrapper = $input.closest('.NB-add-site-search-wrapper');
        if ($wrapper.length) {
            $wrapper.find('.NB-add-site-search-clear').toggleClass('NB-hidden', query.length === 0);
        } else {
            $input.closest('.NB-add-site-section-search')
                .find('.NB-add-site-section-search-clear').toggleClass('NB-hidden', query.length === 0);
        }
    },

    // add_site_view.js - clear_tab_search (consolidated from clear_youtube/reddit/newsletter/podcast_search)
    clear_tab_search: function (tab_name) {
        var config = this.TAB_SEARCH_CONFIG[tab_name];
        if (!config) return;
        this.$('.NB-add-site-' + config.input_suffix + '-search').val('');
        this.$('.NB-add-site-' + config.tab_suffix + '-tab .NB-add-site-search-clear').addClass('NB-hidden');
        this.$('.NB-add-site-' + config.tab_suffix + '-tab .NB-add-site-section-search-clear').addClass('NB-hidden');
        this.$('.NB-add-site-' + config.tab_suffix + '-tab .NB-add-site-section-filter-badge').remove();
        var state = this[config.state_key];
        state.results = [];
        state.query = '';
        state.popular_feeds_loaded = false;
        state.popular_feeds = [];
        state.popular_feeds_collection = null;
        state.popular_offset = 0;
        this[config.render_popular]();
    },

    clear_active_tab_filter: function () {
        var tab = this.active_tab;
        if (tab === 'popular') {
            this.clear_popular_search();
        } else {
            this.clear_tab_search(tab);
        }
    },

    clear_popular_search: function () {
        this.$('.NB-add-site-popular-search').val('');
        this.$('.NB-add-site-popular-tab .NB-add-site-section-search-clear').addClass('NB-hidden');
        this.$('.NB-add-site-popular-tab .NB-add-site-section-filter-badge').remove();
        var state = this.popular_state;
        state.results = [];
        state.query = '';
        state.popular_feeds_loaded = false;
        state.popular_feeds = [];
        state.popular_feeds_collection = null;
        state.popular_offset = 0;
        this.render_popular_popular();
    },
    clear_youtube_search: function () { this.clear_tab_search('youtube'); },
    clear_reddit_search: function () { this.clear_tab_search('reddit'); },
    clear_newsletter_search: function () { this.clear_tab_search('newsletters'); },
    clear_podcast_search: function () { this.clear_tab_search('podcasts'); },

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
            include_stories: 'true'
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
        var discover_origin = this.get_discover_origin();
        var $card = $btn.closest('.NB-add-site-card');
        var feed_data = {
            feed_title: $card.find('.NB-add-site-card-title').text(),
            favicon_url: $card.find('.NB-add-site-card-icon').attr('src')
        };

        if (feed_id) {
            NEWSBLUR.reader.load_feed_in_tryfeed_view(feed_id, {
                discover_origin: discover_origin,
                feed: feed_data
            });
        } else {
            this.link_popular_feed($btn, function (linked_feed_id) {
                NEWSBLUR.reader.load_feed_in_tryfeed_view(linked_feed_id, {
                    discover_origin: discover_origin,
                    feed: feed_data
                });
            });
        }
    },

    get_discover_origin: function () {
        var tab = this.active_tab;
        var tab_info = _.find(this.TABS, function (t) { return t.id === tab; });
        var tab_label = tab_info ? tab_info.label : tab;
        var origin = { tab: tab, tab_label: tab_label };

        var tab_config = this.TAB_SEARCH_CONFIG[tab];
        if (tab_config) {
            var state = this[tab_config.state_key];
            if (state) {
                if (state.selected_category && state.selected_category !== 'all') {
                    origin.category = state.selected_category;
                }
                if (state.selected_subcategory && state.selected_subcategory !== 'all') {
                    origin.subcategory = state.selected_subcategory;
                }
                if (state.query) {
                    origin.query = state.query;
                }
            }
        }

        return origin;
    },

    link_popular_feed: function ($btn, callback) {
        var $card = $btn.closest('.NB-add-site-card');
        var popular_feed_id = $card.data('popular-feed-id');
        var feed_url = $card.data('feed-url');
        if (!popular_feed_id && !feed_url) return;

        $btn.text('Loading...');
        var params = {};
        if (popular_feed_id) params.id = popular_feed_id;
        if (feed_url) params.feed_url = feed_url;
        this.model.make_request('/discover/link_popular_feed', params, function (data) {
            if (data.code > 0 && data.feed_id) {
                $btn.text($btn.hasClass('NB-add-site-try-btn') ? 'Try' : 'Stats');
                $card.find('[data-feed-id]').each(function () {
                    $(this).data('feed-id', data.feed_id).attr('data-feed-id', data.feed_id);
                });
                $card.data('feed-id', data.feed_id).attr('data-feed-id', data.feed_id);
                if (callback) callback(data.feed_id);
            } else {
                $btn.text('Error');
                setTimeout(function () {
                    $btn.text($btn.hasClass('NB-add-site-try-btn') ? 'Try' : 'Stats');
                }, 2000);
            }
        }, function () {
            $btn.text('Error');
            setTimeout(function () {
                $btn.text($btn.hasClass('NB-add-site-try-btn') ? 'Try' : 'Stats');
            }, 2000);
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
        } else {
            this.link_popular_feed($btn, function (linked_feed_id) {
                NEWSBLUR.assets.load_canonical_feed(linked_feed_id, function () {
                    NEWSBLUR.reader.open_feed_statistics_modal(linked_feed_id);
                });
            });
        }
    },

    toggle_webfeed_folder_input: function () {
        var $input_row = this.$('.NB-add-site-webfeed-folder-input');
        var $icon = this.$('.NB-add-site-webfeed-folder-add-icon');

        if ($input_row.hasClass('NB-hidden')) {
            $input_row.removeClass('NB-hidden').hide().slideDown(200);
            $icon.addClass('NB-active');
            this.$('.NB-add-site-webfeed-folder-name').focus();
        } else {
            $input_row.slideUp(200, function () {
                $(this).addClass('NB-hidden');
            });
            $icon.removeClass('NB-active');
        }
    },

    handle_webfeed_folder_keypress: function (e) {
        if (e.keyCode === 13) {
            e.preventDefault();
            this.save_webfeed_folder();
        }
    },

    save_webfeed_folder: function () {
        var self = this;
        var folder_name = this.$('.NB-add-site-webfeed-folder-name').val().trim();
        if (!folder_name) return;

        var $submit = this.$('.NB-add-site-webfeed-folder-submit');
        var $loading = this.$('.NB-add-site-webfeed-folder-input .NB-loading');

        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').text('Adding...');

        var parent_folder = this.$('.NB-add-site-webfeed-folder-row .NB-add-site-folder-select').val() || '';
        NEWSBLUR.assets.save_add_folder(folder_name, parent_folder, function (data) {
            $loading.removeClass('NB-active');
            $submit.removeClass('NB-disabled');

            if (data && !data.message) {
                $submit.text('Added!');
                NEWSBLUR.assets.load_feeds(function () {
                    var $new_select = self.make_folder_selector(folder_name);
                    self.$('.NB-add-site-webfeed-folder-row .NB-add-site-folder-select').replaceWith($new_select);
                    self.$('.NB-add-site-webfeed-folder-name').val('');
                    self.$('.NB-add-site-webfeed-folder-input').slideUp(200, function () {
                        $(this).addClass('NB-hidden');
                    });
                    self.$('.NB-add-site-webfeed-folder-add-icon').removeClass('NB-active');
                    $submit.text('Add Folder');
                });
            } else {
                $submit.text('Add Folder');
            }
        });
    },

    // ================================
    // = Popular Tab Inline Search   =
    // ================================

    handle_popular_search_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        var $clear = $(e.currentTarget).closest('.NB-add-site-section-search')
            .find('.NB-add-site-section-search-clear');
        $clear.toggleClass('NB-hidden', query.length === 0);
        this.popular_state.query = query;

        if (!query) {
            this.popular_state.popular_feeds_loaded = false;
            this.popular_state.popular_feeds = [];
            this.popular_state.popular_feeds_collection = null;
            this.popular_state.popular_offset = 0;
            this.render_popular_popular();
            return;
        }

        this.popular_search_debounced();
    },

    perform_popular_search: function () {
        var state = this.popular_state;
        if (!state.query || state.query.length < 2) {
            this.render_popular_popular();
            return;
        }
        state.popular_feeds_loaded = false;
        state.popular_feeds = [];
        state.popular_feeds_collection = null;
        state.popular_offset = 0;
        this.render_popular_popular();
    },

    // =========================
    // = Source Search Actions =
    // =========================

    handle_youtube_search_keypress: function (e) {
        if (e.which === 13) this.perform_youtube_search();
    },

    handle_youtube_search_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        var $wrapper = $(e.currentTarget).closest('.NB-add-site-search-wrapper');
        if ($wrapper.length) {
            $wrapper.find('.NB-add-site-search-clear').toggleClass('NB-hidden', query.length === 0);
            // Top bar search clears category selection (mutual exclusivity)
            if (query) this._reset_category_to_all('youtube');
        } else {
            $(e.currentTarget).closest('.NB-add-site-section-search')
                .find('.NB-add-site-section-search-clear').toggleClass('NB-hidden', query.length === 0);
        }
        this.youtube_state.query = query;

        if (!query) {
            this.youtube_state.popular_feeds_loaded = false;
            this.youtube_state.popular_feeds = [];
            this.youtube_state.popular_feeds_collection = null;
            this.youtube_state.popular_offset = 0;
            this.render_youtube_popular();
            return;
        }

        this.youtube_search_debounced();
    },

    perform_youtube_popular_search: function () {
        var state = this.youtube_state;
        if (!state.query || state.query.length < 2) {
            this.render_youtube_popular();
            return;
        }
        state.popular_feeds_loaded = false;
        state.popular_feeds = [];
        state.popular_feeds_collection = null;
        state.popular_offset = 0;
        this.render_youtube_popular();
    },

    handle_reddit_search_keypress: function (e) {
        if (e.which === 13) this.perform_reddit_combined_search();
    },

    handle_reddit_search_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        var $wrapper = $(e.currentTarget).closest('.NB-add-site-search-wrapper');
        if ($wrapper.length) {
            $wrapper.find('.NB-add-site-search-clear').toggleClass('NB-hidden', query.length === 0);
            // Top bar search clears category selection (mutual exclusivity)
            if (query) this._reset_category_to_all('reddit');
        } else {
            $(e.currentTarget).closest('.NB-add-site-section-search')
                .find('.NB-add-site-section-search-clear').toggleClass('NB-hidden', query.length === 0);
        }
        this.reddit_state.query = query;

        if (!query) {
            this.reddit_state.results = [];
            this.reddit_state.api_results = [];
            this.reddit_state.api_loading = false;
            this.reddit_state.popular_feeds_loaded = false;
            this.reddit_state.popular_feeds = [];
            this.reddit_state.popular_feeds_collection = null;
            this.reddit_state.popular_offset = 0;
            this.render_reddit_popular();
            return;
        }

        this.reddit_search_debounced();
        this.reddit_api_search_debounced();
    },

    perform_reddit_combined_search: function () {
        this.perform_reddit_popular_search();
        this.perform_reddit_api_search();
    },

    perform_reddit_popular_search: function () {
        var query = this.reddit_state.query;
        var state = this.reddit_state;

        if (!query || query.length < 2) {
            state.results = [];
            this.render_reddit_popular();
            return;
        }

        state.popular_feeds_loaded = false;
        state.popular_feeds = [];
        state.popular_feeds_collection = null;
        state.popular_offset = 0;
        this.render_reddit_popular();
    },

    perform_reddit_api_search: function () {
        var self = this;
        var state = this.reddit_state;
        var query = state.query;

        if (!query || query.length < 2) return;

        state.api_loading = true;

        this.model.make_request('/discover/reddit/search', { query: query, limit: 15 }, function (data) {
            state.api_loading = false;
            if (data && data.code === 1 && data.results) {
                state.api_results = data.results;
            } else {
                state.api_results = [];
            }
            if (self.active_tab === 'reddit') {
                self.render_reddit_api_results();
            }
        }, function () {
            state.api_loading = false;
            state.api_results = [];
        }, { request_type: 'GET' });
    },

    handle_newsletter_search_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        var $wrapper = $(e.currentTarget).closest('.NB-add-site-search-wrapper');
        if ($wrapper.length) {
            $wrapper.find('.NB-add-site-search-clear').toggleClass('NB-hidden', query.length === 0);
            // Top bar search clears category selection (mutual exclusivity)
            if (query) this._reset_category_to_all('newsletters');
        } else {
            $(e.currentTarget).closest('.NB-add-site-section-search')
                .find('.NB-add-site-section-search-clear').toggleClass('NB-hidden', query.length === 0);
        }
        this.newsletters_state.query = query;

        if (!query) {
            this.newsletters_state.results = [];
            this.newsletters_state.popular_feeds_loaded = false;
            this.newsletters_state.popular_feeds = [];
            this.newsletters_state.popular_feeds_collection = null;
            this.newsletters_state.popular_offset = 0;
            this.render_newsletters_popular();
            return;
        }

        this.newsletter_search_debounced();
    },

    handle_newsletter_search_keypress: function (e) {
        if (e.which === 13) this.perform_newsletter_search_or_convert();
    },

    handle_podcast_search_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        var $wrapper = $(e.currentTarget).closest('.NB-add-site-search-wrapper');
        if ($wrapper.length) {
            $wrapper.find('.NB-add-site-search-clear').toggleClass('NB-hidden', query.length === 0);
            // Top bar search clears category selection (mutual exclusivity)
            if (query) this._reset_category_to_all('podcasts');
        } else {
            $(e.currentTarget).closest('.NB-add-site-section-search')
                .find('.NB-add-site-section-search-clear').toggleClass('NB-hidden', query.length === 0);
        }
        this.podcasts_state.query = query;

        if (!query) {
            this.podcasts_state.results = [];
            this.podcasts_state.popular_feeds_loaded = false;
            this.podcasts_state.popular_feeds = [];
            this.podcasts_state.popular_feeds_collection = null;
            this.podcasts_state.popular_offset = 0;
            this.render_podcasts_popular();
            return;
        }

        this.podcast_search_debounced();
    },

    perform_podcast_popular_search: function () {
        var query = this.podcasts_state.query;
        var state = this.podcasts_state;

        if (!query || query.length < 2) {
            state.results = [];
            this.render_podcasts_popular();
            return;
        }

        state.popular_feeds_loaded = false;
        state.popular_feeds = [];
        state.popular_feeds_collection = null;
        state.popular_offset = 0;
        this.render_podcasts_popular();
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
        this._reset_category_to_all('youtube');
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
        this._reset_category_to_all('reddit');
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
        this._reset_category_to_all('podcasts');
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

    perform_newsletter_search: function () {
        var query = this.newsletters_state.query;
        var state = this.newsletters_state;

        if (!query || query.length < 2) {
            state.results = [];
            this.render_newsletters_popular();
            return;
        }

        state.popular_feeds_loaded = false;
        state.popular_feeds = [];
        state.popular_feeds_collection = null;
        state.popular_offset = 0;
        this.render_newsletters_popular();
    },

    perform_newsletter_search_or_convert: function () {
        this._reset_category_to_all('newsletters');
        var query = this.$('.NB-add-site-newsletters-search').val().trim();
        if (query && query.match(/\.\w{2,}/) && !query.match(/\s/)) {
            this.perform_newsletter_convert();
        } else {
            this.newsletters_state.query = query;
            this.perform_newsletter_search();
        }
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

    // add_site_view.js - _handle_google_news_pill_click: custom two-level pill handler for Google News
    _handle_google_news_pill_click: function ($pill, source, level, category, subcategory, source_config, state) {
        var $container = $pill.closest('.NB-add-site-category-pills-container');

        // Reset subscription state on any pill click
        state.is_subscribed = false;
        state.feed_url = null;
        state.feed_id = null;

        if (level === 'category') {
            $container.find('.NB-add-site-cat-pill').removeClass('NB-active');
            $pill.addClass('NB-active');

            state.selected_category = category || 'all';
            state.selected_subcategory = 'all';

            var $subcat_row = $container.find('.NB-add-site-subcat-pills-row');
            if (category && category !== 'all') {
                state.query = category;
                this.$('.NB-add-site-google-news-search-input').val(category);

                var grouped = state.grouped_categories || [];
                var active_group = _.find(grouped, function(g) { return g.name === category; });
                if (active_group && active_group.subcategories && active_group.subcategories.length > 0) {
                    this._populate_subcat_row($subcat_row, active_group, source, 'all');
                    $subcat_row.addClass('NB-visible');
                } else {
                    $subcat_row.removeClass('NB-visible').empty();
                }
            } else {
                state.query = '';
                this.$('.NB-add-site-google-news-search-input').val('');
                $subcat_row.removeClass('NB-visible').empty();
            }
        } else if (level === 'subcategory') {
            $container.find('.NB-add-site-subcat-pill').removeClass('NB-active');
            $pill.addClass('NB-active');

            state.selected_subcategory = subcategory || 'all';

            if (subcategory && subcategory !== 'all') {
                state.query = subcategory;
                this.$('.NB-add-site-google-news-search-input').val(subcategory);
            } else {
                // "All" subcategory - revert to category name
                state.query = state.selected_category !== 'all' ? state.selected_category : '';
                this.$('.NB-add-site-google-news-search-input').val(state.query);
            }
        }

        this._sync_google_news_topic_from_query(state);
        this.update_google_news_subscribe_button();
        this.update_url();
    },

    // add_site_view.js - _sync_google_news_topic_from_query: match query to GOOGLE_NEWS_TOPICS
    _sync_google_news_topic_from_query: function (state) {
        var query = (state.query || '').toLowerCase();
        var matched = _.find(this.GOOGLE_NEWS_TOPICS, function(t) {
            return t.name.toLowerCase() === query;
        });
        state.selected_topic = matched ? matched.id : null;
    },

    handle_google_news_input: function (e) {
        var query = $(e.currentTarget).val().trim();
        var state = this.google_news_state;

        state.query = query;

        // Check if typed text still matches a pill - if not, reset pills to "All"
        var matches_category = query && (
            (state.selected_category !== 'all' && state.selected_category.toLowerCase() === query.toLowerCase()) ||
            (state.selected_subcategory !== 'all' && state.selected_subcategory.toLowerCase() === query.toLowerCase())
        );

        if (!matches_category) {
            var $container = this.$('.NB-add-site-category-pills-container[data-source="google-news"]');
            if ($container.length) {
                $container.find('.NB-add-site-cat-pill').removeClass('NB-active');
                $container.find('.NB-add-site-cat-pill[data-category="all"]').addClass('NB-active');
                $container.find('.NB-add-site-subcat-pills-row').removeClass('NB-visible').empty();
                state.selected_category = 'all';
                state.selected_subcategory = 'all';
            }
        }

        this._sync_google_news_topic_from_query(state);

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
        var folder = this.$('.NB-add-site-google-news-input-row .NB-add-site-folder-select').val() || '';

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

                        // Refresh feed list, then open the feed
                        NEWSBLUR.assets.load_feeds(function () {
                            if (state.feed_id) {
                                NEWSBLUR.reader.open_feed(state.feed_id);
                            }
                        });
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
    },

    toggle_google_news_folder_input: function () {
        var $input_row = this.$('.NB-add-site-google-news-folder-input');
        var $icon = this.$('.NB-add-site-google-news-folder-add-icon');

        if ($input_row.hasClass('NB-hidden')) {
            $input_row.removeClass('NB-hidden').hide().slideDown(200);
            $icon.addClass('NB-active');
            this.$('.NB-add-site-google-news-folder-name').focus();
        } else {
            $input_row.slideUp(200, function () {
                $(this).addClass('NB-hidden');
            });
            $icon.removeClass('NB-active');
        }
    },

    handle_google_news_folder_keypress: function (e) {
        if (e.keyCode === 13) {
            e.preventDefault();
            this.save_google_news_folder();
        }
    },

    save_google_news_folder: function () {
        var self = this;
        var folder_name = this.$('.NB-add-site-google-news-folder-name').val().trim();
        if (!folder_name) return;

        var $submit = this.$('.NB-add-site-google-news-folder-submit');
        var $loading = this.$('.NB-add-site-google-news-folder-input .NB-loading');

        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').text('Adding...');

        var parent_folder = this.$('.NB-add-site-google-news-folder-row .NB-add-site-folder-select').val() || '';
        NEWSBLUR.assets.save_add_folder(folder_name, parent_folder, function (data) {
            $loading.removeClass('NB-active');
            $submit.removeClass('NB-disabled');

            if (data && !data.message) {
                $submit.text('Added!');
                NEWSBLUR.assets.load_feeds(function () {
                    var $new_select = self.make_folder_selector(folder_name);
                    self.$('.NB-add-site-google-news-folder-row .NB-add-site-folder-select').replaceWith($new_select);
                    self.$('.NB-add-site-google-news-folder-name').val('');
                    self.$('.NB-add-site-google-news-folder-input').slideUp(200, function () {
                        $(this).addClass('NB-hidden');
                    });
                    self.$('.NB-add-site-google-news-folder-add-icon').removeClass('NB-active');
                    $submit.text('Add Folder');
                });
            } else {
                $submit.text('Add Folder');
            }
        });
    },

    // ================
    // = URL Routing  =
    // ================

    // add_site_view.js - slugify/deslugify for URL-friendly category names
    _slugify: function (str) {
        return str.replace(/[^a-zA-Z0-9\s-]/g, '').replace(/\s+/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '').toLowerCase();
    },

    _deslugify: function (str) {
        return str.replace(/-/g, ' ').toLowerCase();
    },

    // add_site_view.js - _normalize: convert to comparable form (hyphens→spaces, strip special chars)
    _normalize: function (str) {
        return str.replace(/[-]/g, ' ').replace(/[^a-zA-Z0-9\s]/g, '').replace(/\s+/g, ' ').trim().toLowerCase();
    },

    // add_site_view.js - _resolve_from_grouped: find real category/subcategory name by matching slug
    _resolve_from_grouped: function (slug, grouped, field) {
        if (!slug || !grouped || !grouped.length) return slug;
        var normalized_slug = this._normalize(slug);
        if (field === 'category') {
            var match = _.find(grouped, function (g) {
                return g.name.replace(/[-]/g, ' ').replace(/[^a-zA-Z0-9\s]/g, '').replace(/\s+/g, ' ').trim().toLowerCase() === normalized_slug;
            });
            return match ? match.name : slug;
        } else if (field === 'subcategory') {
            // Search all groups for a matching subcategory
            for (var i = 0; i < grouped.length; i++) {
                var subcats = grouped[i].subcategories || [];
                for (var j = 0; j < subcats.length; j++) {
                    var subcat_name = (typeof subcats[j] === 'string') ? subcats[j] : subcats[j].name;
                    if (subcat_name.replace(/[-]/g, ' ').replace(/[^a-zA-Z0-9\s]/g, '').replace(/\s+/g, ' ').trim().toLowerCase() === normalized_slug) {
                        return subcat_name;
                    }
                }
            }
            return slug;
        }
        return slug;
    },

    // add_site_view.js - update_url: push current tab/category/subcategory state into the URL
    update_url: function () {
        var parts = ['add'];

        if (this.active_tab && this.active_tab !== 'search') {
            parts.push(this.active_tab);

            var source_config = this.SOURCE_MAP[this.active_tab];
            if (source_config) {
                var state = this[source_config.state];
                if (state && state.selected_category && state.selected_category !== 'all') {
                    parts.push(this._slugify(state.selected_category));
                    if (state.selected_subcategory && state.selected_subcategory !== 'all') {
                        parts.push(this._slugify(state.selected_subcategory));
                    }
                }
            }
        }

        var url = '/' + parts.join('/');
        NEWSBLUR.router.navigate(url);
    },

    // add_site_view.js - navigate_to_state: called on back/forward when view is already open
    navigate_to_state: function (tab, category, subcategory) {
        var target_tab = tab || 'search';
        if (target_tab === 'trending') target_tab = 'search';
        var deslug_cat = category ? this._deslugify(category) : null;
        var deslug_sub = subcategory ? this._deslugify(subcategory) : null;

        if (target_tab !== this.active_tab) {
            this.active_tab = target_tab;

            this.$('.NB-add-site-tab').removeClass('NB-active');
            this.$('.NB-add-site-tab[data-tab="' + target_tab + '"]').addClass('NB-active');

            this.$('.NB-add-site-tab-pane').removeClass('NB-active');
            this.$('.NB-add-site-' + target_tab + '-tab').addClass('NB-active');
        }

        // Apply category/subcategory state
        var source_config = this.SOURCE_MAP[target_tab];
        if (source_config) {
            var state = this[source_config.state];
            var grouped = state.grouped_categories || [];
            if (deslug_cat) {
                state.selected_category = this._resolve_from_grouped(deslug_cat, grouped, 'category');
                state.selected_subcategory = deslug_sub ? this._resolve_from_grouped(deslug_sub, grouped, 'subcategory') : 'all';
                // Store pending slugs for resolution when categories load from API
                state._pending_category_slug = deslug_cat;
                state._pending_subcategory_slug = deslug_sub;
            } else {
                state.selected_category = 'all';
                state.selected_subcategory = 'all';
                state._pending_category_slug = null;
                state._pending_subcategory_slug = null;
            }
            state.popular_feeds_loaded = false;
            state.popular_feeds = [];
            state.popular_feeds_collection = null;
            state.popular_offset = 0;

            // Google News: sync query and topic from restored category/subcategory
            if (target_tab === 'google-news') {
                if (state.selected_subcategory && state.selected_subcategory !== 'all') {
                    state.query = state.selected_subcategory;
                } else if (state.selected_category && state.selected_category !== 'all') {
                    state.query = state.selected_category;
                } else {
                    state.query = '';
                }
                this._sync_google_news_topic_from_query(state);
            }
        }

        this.render_active_tab();
        this.bind_scroll_handler();
        this.update_tab_overflow();
        this.update_url();
    },

    // add_site_view.js - apply_initial_category_state: set category/subcategory on tab state during init
    apply_initial_category_state: function (tab, category, subcategory) {
        var source_config = this.SOURCE_MAP[tab];
        if (!source_config) return;

        var state = this[source_config.state];
        if (!state) return;

        var deslug_cat = this._deslugify(category);
        var grouped = state.grouped_categories || [];

        // If grouped_categories already loaded (e.g. Google News constants), resolve immediately
        if (grouped.length) {
            state.selected_category = this._resolve_from_grouped(deslug_cat, grouped, 'category');
            if (subcategory) {
                var deslug_sub = this._deslugify(subcategory);
                state.selected_subcategory = this._resolve_from_grouped(deslug_sub, grouped, 'subcategory');
            }
        } else {
            state.selected_category = deslug_cat || 'all';
            if (subcategory) {
                var deslug_sub = this._deslugify(subcategory);
                state.selected_subcategory = deslug_sub;
            }
        }
        // Store pending slug for resolution when grouped_categories arrive from API
        state._pending_category_slug = deslug_cat;
        state._pending_subcategory_slug = subcategory ? this._deslugify(subcategory) : null;

        // Google News: sync query and topic from initial URL category/subcategory
        if (tab === 'google-news') {
            if (state.selected_subcategory && state.selected_subcategory !== 'all') {
                state.query = state.selected_subcategory;
            } else if (state.selected_category && state.selected_category !== 'all') {
                state.query = state.selected_category;
            } else {
                state.query = '';
            }
            this._sync_google_news_topic_from_query(state);
        }
    }

});
