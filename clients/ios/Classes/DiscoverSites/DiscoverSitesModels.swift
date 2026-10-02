//
//  DiscoverSitesModels.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import Foundation

enum DiscoverSitesFeedViewMode: String {
    case grid
    case list
}

enum DiscoverTab: String, CaseIterable, Identifiable {
    case search
    case webFeed
    case popular
    case youtube
    case reddit
    case newsletters
    case podcasts
    case googleNews

    var id: String { rawValue }

    var label: String {
        switch self {
        case .search: return "Search"
        case .webFeed: return "Web Feed"
        case .popular: return "Popular"
        case .youtube: return "YouTube"
        case .reddit: return "Reddit"
        case .newsletters: return "Newsletters"
        case .podcasts: return "Podcasts"
        case .googleNews: return "Google News"
        }
    }

    var sfSymbol: String {
        switch self {
        case .search: return "magnifyingglass"
        case .webFeed: return "globe"
        case .popular: return "flame.fill"
        case .youtube: return "play.rectangle.fill"
        case .reddit: return "bubble.left.and.bubble.right.fill"
        case .newsletters: return "envelope.fill"
        case .podcasts: return "mic.fill"
        case .googleNews: return "newspaper.fill"
        }
    }

    var feedType: String {
        switch self {
        case .youtube: return "youtube"
        case .reddit: return "reddit"
        case .newsletters: return "newsletter"
        case .podcasts: return "podcast"
        case .popular: return "all"
        default: return "all"
        }
    }
}

struct DiscoverPopularFeed: Identifiable {
    let id: String
    let feedTitle: String
    let feedAddress: String
    let feedLink: String
    let numSubscribers: Int
    let averageStoriesPerMonth: Int
    let faviconUrl: String?
    let faviconData: String?
    let stories: [DiscoverStory]
    let rawFeedDict: [String: Any]

    init(feedId: String, feedDict: [String: Any], storiesArray: [[String: Any]] = []) {
        self.id = feedId
        self.feedTitle = feedDict["feed_title"] as? String ?? ""
        self.feedAddress = feedDict["feed_address"] as? String ?? ""
        self.feedLink = feedDict["feed_link"] as? String ?? ""
        self.numSubscribers = feedDict["num_subscribers"] as? Int ?? feedDict["subs"] as? Int ?? 0
        self.averageStoriesPerMonth = feedDict["average_stories_per_month"] as? Int ?? 0
        self.faviconUrl = feedDict["favicon_url"] as? String
        self.faviconData = feedDict["favicon"] as? String
        var canonical = feedDict
        if let numericID = Int(feedId) { canonical["id"] = numericID }
        else { canonical["id"] = feedId }
        self.rawFeedDict = canonical
        self.stories = storiesArray.compactMap { DiscoverStory(dict: $0) }
    }

    init(autocompleteResult result: AutocompleteResult) {
        self.init(feedId: result.id, feedDict: [
            "feed_title": result.label, "feed_address": result.value, "feed_link": result.value,
            "num_subscribers": result.numSubscribers, "favicon": result.favicon ?? "",
            "last_story_date": result.lastStoryDate ?? ""
        ])
    }

    func freshness(now: Date = Date(), locale: Locale = .current, timeZone: TimeZone = .current) -> DiscoverFeedFreshness? {
        DiscoverFeedFreshness(lastStoryDate: rawFeedDict["last_story_date"], now: now, locale: locale, timeZone: timeZone)
    }
}

struct DiscoverFeedFreshness: Equatable {
    enum Status {
        case active
        case stale
        case noStories
    }

    let status: Status
    let label: String

    init?(lastStoryDate: Any?, now: Date = Date(), showEmpty: Bool = true,
          locale: Locale = .current, timeZone: TimeZone = .current) {
        let missing = lastStoryDate == nil || lastStoryDate is NSNull ||
            (lastStoryDate as? String) == "" || (lastStoryDate as? NSNumber)?.doubleValue == 0
        if missing {
            guard showEmpty else { return nil }
            status = .noStories
            label = "No stories yet"
            return
        }
        guard let date = Self.parseDate(lastStoryDate, timeZone: timeZone) else { return nil }
        // DiscoverSitesModels.swift matches add_site_view.js elapsed-day thresholds, including future dates.
        let days = floor(now.timeIntervalSince(date) / 86400)
        if days < 365 {
            status = .active
            if days < 1 { label = "Updated today" }
            else if days < 7 {
                let count = Int(days)
                label = "Updated \(count) \(count == 1 ? "day" : "days") ago"
            } else if days < 30 {
                let count = Int(days / 7)
                label = "Updated \(count) \(count == 1 ? "week" : "weeks") ago"
            } else {
                let count = Int(days / 30)
                label = "Updated \(count) \(count == 1 ? "month" : "months") ago"
            }
        } else {
            status = .stale
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
            label = "Stale — last story \(formatter.string(from: date))"
        }
    }

    private static func parseDate(_ value: Any?, timeZone: TimeZone) -> Date? {
        if let number = value as? NSNumber {
            let milliseconds = number.doubleValue
            guard milliseconds.isFinite, abs(milliseconds) <= 8_640_000_000_000_000 else { return nil }
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        guard let string = value as? String else { return nil }
        // DiscoverSitesModels.swift rejects trailing junk that ISO8601DateFormatter otherwise ignores.
        let timestampPattern = #"\A\d{4}-\d{2}-\d{2}(?:[Tt ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[Zz]|[+-]\d{2}:?\d{2})?)?\z"#
        guard string.range(of: timestampPattern, options: .regularExpression) != nil else { return nil }
        let normalized = string.uppercased().replacingOccurrences(of: " ", with: "T")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: normalized) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: normalized) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.isLenient = false
        // DiscoverSitesModels.swift treats unzoned timestamps as local time, as JavaScript Date does.
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) { return date }
        }
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

struct DiscoverCategory: Identifiable, Equatable {
    let id: String
    let name: String
    let feedCount: Int
    let subcategories: [DiscoverSubcategory]

    static func == (lhs: DiscoverCategory, rhs: DiscoverCategory) -> Bool {
        lhs.id == rhs.id
    }
}

struct DiscoverSubcategory: Identifiable, Equatable {
    let id: String
    let name: String
    let feedCount: Int

    static func == (lhs: DiscoverSubcategory, rhs: DiscoverSubcategory) -> Bool {
        lhs.id == rhs.id
    }
}

struct GoogleNewsTopic: Identifiable {
    let id: String
    let name: String

    var sfSymbol: String {
        switch id {
        case "WORLD": return "globe.americas.fill"
        case "NATION": return "building.columns.fill"
        case "BUSINESS": return "briefcase.fill"
        case "TECHNOLOGY": return "cpu.fill"
        case "ENTERTAINMENT": return "film.fill"
        case "SPORTS": return "trophy.fill"
        case "SCIENCE": return "flask.fill"
        case "HEALTH": return "heart.fill"
        default: return "newspaper.fill"
        }
    }
}

struct GoogleNewsCategory: Identifiable {
    let id: String
    let name: String
    let subcategories: [String]
}

struct WebFeedVariant: Identifiable {
    let id: Int
    let label: String
    let storyContainerXpath: String
    let titleXpath: String
    let linkXpath: String
    let contentXpath: String
    let imageXpath: String
    let authorXpath: String
    let dateXpath: String
    let stories: [WebFeedPreviewStory]

    init(index: Int, dict: [String: Any]) {
        self.id = index
        self.label = dict["label"] as? String ?? "Variant \(index + 1)"
        self.storyContainerXpath = dict["story_container"] as? String ?? dict["story_container_xpath"] as? String ?? ""
        self.titleXpath = dict["title"] as? String ?? dict["title_xpath"] as? String ?? ""
        self.linkXpath = dict["link"] as? String ?? dict["link_xpath"] as? String ?? ""
        self.contentXpath = dict["content"] as? String ?? dict["content_xpath"] as? String ?? ""
        self.imageXpath = dict["image"] as? String ?? dict["image_xpath"] as? String ?? ""
        self.authorXpath = dict["author"] as? String ?? dict["author_xpath"] as? String ?? ""
        self.dateXpath = dict["date"] as? String ?? dict["date_xpath"] as? String ?? ""
        let storiesArray = dict["preview_stories"] as? [[String: Any]] ?? dict["stories"] as? [[String: Any]] ?? []
        self.stories = storiesArray.enumerated().map { WebFeedPreviewStory(index: $0, dict: $1) }
    }
}

struct WebFeedPreviewStory: Identifiable {
    let id: Int
    let title: String
    let link: String
    let imageUrl: String?

    init(index: Int, dict: [String: Any]) {
        self.id = index
        self.title = dict["title"] as? String ?? ""
        self.link = dict["link"] as? String ?? ""
        self.imageUrl = dict["image"] as? String
    }
}

struct SearchTabState {
    var query: String = ""
    var results: [AutocompleteResult] = []
    var trendingFeeds: [DiscoverPopularFeed] = []
    var isSearching: Bool = false
    var isTrendingLoading: Bool = false
    var isTrendingLoaded: Bool = false
    var errorMessage: String?
    var trendingErrorMessage: String?
}

struct WebFeedTabState {
    var url: String = ""
    var analyzedURL: String = ""
    var detectedFeedURL: String?
    var isAnalyzing: Bool = false
    var progressMessage: String = ""
    var errorMessage: String?
    var requestId: String?
    var variants: [WebFeedVariant] = []
    var selectedVariantIndex: Int?
    var htmlHash: String = ""
    var faviconUrl: String = ""
    var stalenessDays: Double = 30
    var markUnreadOnChange: Bool = false
    var feedTitle: String = ""
    var isSubscribing: Bool = false
}

struct CategoryTabState {
    var feeds: [DiscoverPopularFeed] = []
    var categories: [DiscoverCategory] = []
    var selectedCategory: DiscoverCategory?
    var selectedSubcategory: DiscoverSubcategory?
    var searchQuery: String = ""
    var searchResults: [DiscoverPopularFeed] = []
    var submittedQuery: String = ""
    var hasSearched: Bool = false
    var errorMessage: String?
    var isLoading: Bool = false
    var isSearching: Bool = false
    var offset: Int = 0
    var hasMore: Bool = true
    var isCategoriesLoaded: Bool = false
    var hasLoadedStories: Bool = false
    var platformFilter: String?
    var platformCounts: [String: Int] = [:]
}

struct GoogleNewsTabState {
    var topics: [GoogleNewsTopic] = []
    var categories: [GoogleNewsCategory] = []
    var selectedTopic: GoogleNewsTopic?
    var selectedCategory: GoogleNewsCategory?
    var selectedSubcategory: String?
    var searchQuery: String = ""
    var language: String = "en"
    var isLoading: Bool = false
    var isDataLoaded: Bool = false
    var isSubscribing: Bool = false
    var errorMessage: String?
}

// DiscoverSitesModels.swift: mirrors apps/discover/constants.py and the web discovery topic picker.
enum DiscoverGoogleNewsCatalog {
    static let topics: [GoogleNewsTopic] = [
        GoogleNewsTopic(id: "WORLD", name: "World"),
        GoogleNewsTopic(id: "NATION", name: "Nation"),
        GoogleNewsTopic(id: "BUSINESS", name: "Business"),
        GoogleNewsTopic(id: "TECHNOLOGY", name: "Technology"),
        GoogleNewsTopic(id: "ENTERTAINMENT", name: "Entertainment"),
        GoogleNewsTopic(id: "SPORTS", name: "Sports"),
        GoogleNewsTopic(id: "SCIENCE", name: "Science"),
        GoogleNewsTopic(id: "HEALTH", name: "Health"),
    ]

    static let categories: [GoogleNewsCategory] = [
        GoogleNewsCategory(id: "Anime & Manga", name: "Anime & Manga", subcategories: ["Anime Awards", "Anime Conventions", "Anime Dubs", "Anime Fan Art", "Anime Figurines", "Anime Film Releases", "Anime Gaming", "Anime Industry", "Anime Merchandise", "Anime Movie Box Office", "Anime Season Preview", "Anime Soundtrack", "Anime Streaming News", "Anime Studio News", "Anime Voice Actors", "Cosplay", "Fantasy Anime", "Horror Manga", "Isekai Anime", "Josei Manga", "Light Novel Adaptations", "Magical Girl Anime", "Manga Adaptations", "Manga Artists", "Manga Collectors", "Manga Sales Charts", "Manhwa", "Mecha Anime", "Romance Manga", "Sci-Fi Anime", "Seinen Anime", "Shojo Manga", "Shonen Anime", "Shonen Jump", "Slice of Life Anime", "Sports Anime", "Webtoon"]),
        GoogleNewsCategory(id: "Architecture", name: "Architecture", subcategories: ["3D Printed Buildings", "Adaptive Reuse", "Affordable Housing Design", "Airport Architecture", "Architectural Photography", "Architectural Visualization", "Art Deco Architecture", "Biophilic Design", "Brutalist Architecture", "Building Information Modeling", "Deconstructivism", "Floating Architecture", "Gothic Architecture", "Green Building Design", "Historic Preservation", "Interior Architecture", "Landscape Architecture", "LEED Certification", "Mass Timber Construction", "Modernist Architecture", "Modular Construction", "Museum Architecture", "Net Zero Buildings", "Parametric Design", "Passive House Design", "Prefab Architecture", "Residential Architecture", "Sacred Architecture", "Skyscraper Design", "Smart Buildings", "Stadium Design", "Sustainable Architecture", "Tiny House Design", "Urban Planning", "Vernacular Architecture"]),
        GoogleNewsCategory(id: "Arts & Culture", name: "Arts & Culture", subcategories: ["Animation & Motion Graphics", "Art Auctions", "Art Criticism", "Art Exhibitions", "Art History", "Art Market", "Art Restoration", "Art Theft & Repatriation", "Arts Education", "Arts Funding & Grants", "Ballet & Dance", "Biennials & Art Fairs", "Ceramics & Pottery", "Contemporary Art", "Cultural Heritage", "Cultural Policy", "Digital Art & NFTs", "Film Festivals", "Folk Art & Crafts", "Galleries", "Illustration & Comics", "Indigenous Art", "Literary Fiction", "Museum News", "Opera", "Performing Arts", "Poetry", "Public Art & Murals", "Sculpture", "Street Art & Graffiti", "Textile Arts", "Theater & Broadway"]),
        GoogleNewsCategory(id: "Automotive", name: "Automotive", subcategories: ["Auto Shows", "Automotive Industry", "Autonomous Vehicles", "BMW", "Budget Cars", "BYD", "Car Design", "Car Insurance", "Car Maintenance Tips", "Car Reviews", "Car Safety Recalls", "Car Technology", "Connected Cars", "Electric Trucks", "Electric Vehicles", "Ferrari", "Ford", "Formula 1", "Fuel Economy", "Honda", "Hybrid Vehicles", "Hyundai", "Luxury Cars", "Mercedes-Benz", "Minivans", "Motorcycle News", "NASCAR", "Off-Road Vehicles", "Pickup Trucks", "Porsche", "Rivian", "Self-Driving Cars", "Sports Cars", "SUVs", "Tesla", "Toyota", "Used Cars"]),
        GoogleNewsCategory(id: "Books & Reading", name: "Books & Reading", subcategories: ["Audiobooks", "Author Interviews", "Bestsellers", "Book Adaptations", "Book Bans and Censorship", "Book Clubs", "Book Fairs and Festivals", "Book Recommendations", "Book Reviews", "Bookstores", "Children's Books", "Classic Literature", "Comic Books", "Ebooks and Digital Reading", "Fantasy Books", "Graphic Novels", "Historical Fiction", "Horror Books", "Indie Publishing", "Libraries", "Literary Awards", "Literary Fiction", "Memoir and Autobiography", "Mystery Books", "New Book Releases", "Nonfiction Books", "Poetry", "Publishing Industry", "Reading and Literacy", "Romance Books", "Science Fiction Books", "Self-Help Books", "Self-Publishing", "Thriller Books", "True Crime Books", "Young Adult Books"]),
        GoogleNewsCategory(id: "Business", name: "Business", subcategories: ["B2B", "Bankruptcy", "Branding", "Business Analytics", "Business Development", "Business Ethics", "Business Intelligence", "Business Law", "Commercial Real Estate", "Competitive Analysis", "Consulting", "Corporate Finance", "Corporate Governance", "Corporate Social Responsibility", "Corporate Strategy", "Digital Transformation", "E-Commerce", "Executive Leadership", "Family Business", "Franchising", "Human Resources", "IPO", "Logistics", "Management", "Market Research", "Mergers and Acquisitions", "Outsourcing", "Private Equity", "Procurement", "Retail", "Revenue Growth", "Risk Management", "Sales Strategy", "Small Business", "Supply Chain", "Venture Capital", "Workplace Culture"]),
        GoogleNewsCategory(id: "Career & Job Market", name: "Career & Job Market", subcategories: ["AI Replacing Jobs", "Apprenticeship Programs", "Career Change Advice", "Career Coaching", "Diversity Hiring", "Employee Benefits Trends", "Employment Law Changes", "Four Day Work Week", "Freelancing Opportunities", "Gig Economy", "Hiring Trends", "Industry Job Growth", "Internship Opportunities", "Job Interview Tips", "Job Market for Graduates", "Job Market Outlook", "Job Search Strategies", "Labor Market Data", "LinkedIn Networking", "Minimum Wage Debate", "Professional Certifications", "Quiet Quitting", "Remote Work Trends", "Resume Writing Tips", "Return to Office", "Salary Negotiation", "Side Hustle Ideas", "Skills Development", "Startup Hiring", "Tech Layoffs", "Unemployment Rate", "Union Labor News", "Upskilling and Reskilling", "Work-Life Balance", "Worker Burnout", "Workplace AI Tools", "Workplace Culture", "Workplace Harassment", "Workplace Mental Health"]),
        GoogleNewsCategory(id: "Comedy & Humor", name: "Comedy & Humor", subcategories: ["Absurdist Humor", "Comedian News", "Comedy Awards", "Comedy Clubs", "Comedy Festivals", "Comedy Movies", "Comedy Podcasts", "Comedy Roasts", "Comedy Specials", "Comedy Streaming", "Comedy Tours", "Comedy Variety Shows", "Comedy Writing", "Comic Strips", "Dark Humor", "Funny Videos", "Improv Comedy", "Late Night TV", "Memes", "Musical Comedy", "Parody", "Political Satire", "Romantic Comedy", "Satire", "Sitcoms", "Sketch Comedy", "Slapstick Comedy", "SNL Saturday Night Live", "Stand-Up Comedy", "Web Comedy Series"]),
        GoogleNewsCategory(id: "Cryptocurrency & Web3", name: "Cryptocurrency & Web3", subcategories: ["Airdrop Token Launch", "Avalanche AVAX", "Bitcoin", "Bitcoin ETF", "Bitcoin Halving", "Bitcoin Mining", "Blockchain Technology", "Cardano", "Central Bank Digital Currency", "Chainlink", "Cross Chain Interoperability", "Crypto Lending", "Crypto Regulation", "Crypto Scam Fraud", "Crypto Venture Capital", "Crypto Wallet Security", "Cryptocurrency Exchange", "Cryptocurrency Tax", "DAO Governance", "Decentralized Exchange", "DeFi", "Dogecoin", "Ethereum", "Ethereum Staking", "GameFi", "Layer 2 Scaling", "Meme Coins", "Metaverse Crypto", "NFT Market", "Polkadot", "Polygon MATIC", "Proof of Stake", "Smart Contracts", "Solana", "Stablecoins", "Tokenization", "Web3 Development", "XRP Ripple", "Yield Farming", "Zero Knowledge Proofs"]),
        GoogleNewsCategory(id: "DIY & Crafts", name: "DIY & Crafts", subcategories: ["3D Printing", "Basket Weaving", "Calligraphy", "Candle Making", "Ceramics", "CNC Machining", "Crochet", "Cross Stitch", "Electronics Projects", "Embroidery", "Epoxy Projects", "Furniture Building", "Gardening DIY", "Home Improvement", "Home Renovation", "Jewelry Making", "Knitting", "Laser Cutting", "Leatherwork", "Macrame", "Metalworking", "Mosaic Art", "Origami", "Painting Techniques", "Paper Crafts", "Pottery", "Pyrography", "Quilting", "Resin Art", "Scrapbooking", "Sewing", "Soap Making", "Stained Glass", "Textile Dyeing", "Upcycling", "Weaving", "Welding Projects", "Woodworking"]),
        GoogleNewsCategory(id: "Data Science & Analytics", name: "Data Science & Analytics", subcategories: ["A/B Testing", "Anomaly Detection", "AutoML", "Bayesian Statistics", "Big Data Analytics", "Business Intelligence", "Causal Inference", "Computer Vision", "Data Engineering", "Data Governance", "Data Lakehouse", "Data Mining", "Data Visualization", "Data Warehousing", "Deep Learning", "Edge AI", "ETL Pipelines", "Feature Engineering", "Federated Learning", "Generative AI", "Graph Neural Networks", "Image Recognition", "Large Language Models", "Machine Learning", "MLOps", "Natural Language Processing", "Neural Networks", "Predictive Analytics", "Real-Time Analytics", "Recommendation Systems", "Reinforcement Learning", "Responsible AI", "Speech Recognition", "Statistical Modeling", "Synthetic Data", "Text Mining", "Time Series Analysis", "Vector Databases"]),
        GoogleNewsCategory(id: "Design", name: "Design", subcategories: ["3D Design", "Accessibility Design", "Animation Design", "Automotive Design", "Branding", "Color Theory", "Data Visualization", "Design Leadership", "Design Systems", "Design Thinking", "Design Tools", "Environmental Design", "Fashion Design", "Figma", "Furniture Design", "Game Design", "Graphic Design", "Illustration", "Industrial Design", "Information Architecture", "Interaction Design", "Interior Design", "Logo Design", "Material Design", "Motion Graphics", "Package Design", "Print Design", "Product Design", "Responsive Design", "Service Design", "Sound Design", "Sustainable Design", "Typography", "UI Design", "UX Design", "UX Research", "Visual Design", "Web Design"]),
        GoogleNewsCategory(id: "Economics", name: "Economics", subcategories: ["Antitrust Economics", "Behavioral Economics", "Central Banking", "Consumer Spending", "Cost of Living", "Deglobalization", "Development Economics", "Economic Forecasting", "Economic Mobility", "Economic Recession", "Economic Sanctions", "Emerging Markets", "Federal Reserve", "Fiscal Policy", "GDP Growth", "Gig Economy", "Government Spending", "Green Economy", "Housing Market Economics", "Income Inequality", "Industrial Policy", "Inflation", "Interest Rates", "International Trade", "Labor Economics", "Macroeconomics", "Microeconomics", "Monetary Policy", "National Debt", "Public Finance", "Stagflation", "Supply Chain Economics", "Tariffs", "Tax Policy", "Trade Policy", "Unemployment", "Wage Growth", "Wealth Gap"]),
        GoogleNewsCategory(id: "Education", name: "Education", subcategories: ["Adult Education", "Charter Schools", "Classroom Technology", "College Admissions", "Community College", "Curriculum Development", "Distance Learning", "Early Childhood Education", "EdTech", "Education Equity", "Education Funding", "Education Policy", "Education Reform", "Education Technology", "Financial Aid", "Graduate School", "Higher Education", "Homeschooling", "K-12 Education", "Literacy", "Online Learning", "Private Schools", "Public Schools", "School Board", "School Choice", "School Safety", "Special Education", "Standardized Testing", "STEM Education", "Student Loans", "Student Mental Health", "Study Abroad", "Teacher Shortage", "Teaching Methods", "Trade Schools", "Tutoring", "University Research", "Vocational Training"]),
        GoogleNewsCategory(id: "Entertainment", name: "Entertainment", subcategories: ["Animation", "Awards Shows", "Bollywood", "Box Office", "Broadway", "Casting News", "Celebrity Gossip", "Celebrity News", "Concert Tours", "Disney Plus", "Documentaries", "Emmy Awards", "Entertainment Industry", "Film Festivals", "Golden Globes", "Grammy Awards", "HBO", "Hollywood", "K-Drama", "Late Night TV", "Movie Reviews", "Movie Trailers", "Movies", "Music Videos", "Netflix", "Oscars", "Reality TV", "Red Carpet", "Stand-Up Comedy", "Streaming", "Talk Shows", "Theme Parks", "TV Ratings", "TV Shows", "Variety Shows"]),
        GoogleNewsCategory(id: "Entrepreneurship & Startups", name: "Entrepreneurship & Startups", subcategories: ["AI Startups", "Angel Investors", "Bootstrapped Startups", "Climate Tech Startups", "Corporate Venture Capital", "Customer Acquisition", "Deep Tech Startups", "Fintech Startups", "Growth Hacking", "Healthtech Startups", "Indie Hackers", "Lean Startup Methodology", "Pitch Deck Tips", "Product-Market Fit", "Remote Startup Teams", "SaaS Startups", "Scaling Startups", "Seed Round Funding", "Series A Funding", "Solopreneur", "Startup Accelerators", "Startup Acquisitions", "Startup Competitions", "Startup Culture", "Startup Equity and Vesting", "Startup Exit Strategies", "Startup Failure Post-Mortems", "Startup Founder Stories", "Startup Fundraising", "Startup Incubators", "Startup IPO", "Startup Layoffs", "Startup Metrics and KPIs", "Startup Pivots", "Startup Valuations", "Techstars", "Venture Capital Funding", "Y Combinator"]),
        GoogleNewsCategory(id: "Environment & Sustainability", name: "Environment & Sustainability", subcategories: ["Air Pollution", "Arctic Ice", "Biodiversity", "Carbon Capture", "Carbon Emissions", "Circular Economy", "Climate Change", "Climate Policy", "Coral Reefs", "Deforestation", "Drought", "Endangered Species", "Environmental Justice", "Environmental Policy", "ESG Investing", "Food Waste", "Geothermal Energy", "Global Warming", "Green Energy Storage", "Green Technology", "Hydroelectric Power", "Net Zero", "Ocean Conservation", "Organic Farming", "Paris Agreement", "Plastic Pollution", "Recycling", "Reforestation", "Renewable Energy", "Sea Level Rise", "Solar Energy", "Sustainable Agriculture", "Sustainable Fashion", "Waste Management", "Water Conservation", "Water Pollution", "Wildfires", "Wind Energy"]),
        GoogleNewsCategory(id: "Fashion & Beauty", name: "Fashion & Beauty", subcategories: ["Anti-Aging Skincare", "Athleisure", "Beauty Influencers", "Beauty Tech", "Bridal Fashion", "Celebrity Style", "Clean Beauty", "Cosmetic Surgery", "Denim Trends", "Fashion Designers", "Fashion E-Commerce", "Fashion Photography", "Fashion Sustainability", "Fashion Week", "Fast Fashion", "Fragrance and Perfume", "Hair Care", "Hair Color Trends", "Handbags and Accessories", "Haute Couture", "Jewelry Trends", "K-Beauty", "Luxury Fashion Brands", "Makeup Trends", "Men's Fashion", "Nail Art", "Plus Size Fashion", "Red Carpet Fashion", "Skincare Routine", "Sneaker Culture", "Streetwear", "Sunglasses and Eyewear", "Sustainable Fashion", "Textile Innovation", "Thrift and Resale Fashion", "Vintage Fashion", "Watch Collecting", "Women's Fashion"]),
        GoogleNewsCategory(id: "Finance", name: "Finance", subcategories: ["401k", "Banking", "Bonds", "Budgeting", "Commodities", "Corporate Earnings", "Credit Cards", "Credit Scores", "Cryptocurrency", "Day Trading", "Estate Planning", "ETFs", "Federal Reserve", "Financial Planning", "Financial Regulation", "Financial Technology", "Fintech", "Foreign Exchange", "Hedge Funds", "Index Funds", "Inflation", "Insurance", "Interest Rates", "Investing", "IPOs", "Mergers and Acquisitions", "Mortgages", "Mutual Funds", "Personal Finance", "Private Equity", "Real Estate Investing", "Retirement Planning", "Robo-Advisors", "Small Business Finance", "Stock Market", "Student Loans", "Taxes", "Venture Capital", "Wall Street", "Wealth Management"]),
        GoogleNewsCategory(id: "Food & Cooking", name: "Food & Cooking", subcategories: ["Baking and Pastry", "Bread Baking", "Celebrity Chefs", "Cheese and Cheesemaking", "Chinese Cuisine", "Chocolate and Confections", "Cocktails and Mixology", "Coffee Culture", "Comfort Food", "Cooking Techniques", "Craft Beer and Brewing", "Desserts and Sweets", "Farm to Table", "Fermentation and Pickling", "Food Photography", "Food Preservation and Canning", "Food Safety and Nutrition", "Food Science", "Food Trucks", "French Cuisine", "Grilling and BBQ", "Indian Cuisine", "Italian Cuisine", "Japanese Cuisine", "Korean Cuisine", "Meal Prep", "Mediterranean Cuisine", "Mexican Cuisine", "Middle Eastern Cuisine", "Plant-Based Cooking", "Restaurant Industry", "Seafood", "Sourdough", "Spices and Seasoning", "Street Food", "Tea Culture", "Thai Cuisine", "Vegan Recipes", "Wine and Sommelier"]),
        GoogleNewsCategory(id: "Gaming", name: "Gaming", subcategories: ["Battle Royale Games", "Cloud Gaming", "Co-op Games", "Competitive Gaming", "Console Gaming", "Esports", "Fighting Games", "FPS Games", "Free to Play Games", "Game Deals", "Game Design", "Game Emulation", "Game Modding", "Game Reviews", "Game Soundtracks", "Game Streaming", "Gaming Accessories", "Gaming Hardware", "Horror Games", "Indie Games", "MMOs", "Mobile Gaming", "Nintendo", "Open World Games", "PC Gaming", "PlayStation", "Racing Games", "Retro Gaming", "Roguelike Games", "RPGs", "Simulation Games", "Speedrunning", "Sports Games", "Steam", "Strategy Games", "Survival Games", "Tabletop RPGs", "VR Gaming", "Xbox"]),
        GoogleNewsCategory(id: "Health & Fitness", name: "Health & Fitness", subcategories: ["Addiction Recovery", "Bodybuilding", "Cardio Fitness", "Clinical Trials", "CrossFit", "Cycling & Biking", "Diabetes Prevention", "Functional Fitness", "Gut Health & Microbiome", "Heart Health", "HIIT Workouts", "Immune System", "Intermittent Fasting", "Keto Diet", "Marathon Training", "Meditation & Mindfulness", "Mental Health & Wellness", "Nutrition & Diet", "Outdoor Fitness & Hiking", "Physical Therapy", "Pilates", "Plant-Based Diet", "Protein & Muscle Recovery", "Public Health Policy", "Running & Jogging", "Senior Fitness", "Sleep & Recovery", "Sports Medicine", "Stretching & Mobility", "Supplements & Vitamins", "Swimming", "Wearable Fitness Technology", "Weight Loss", "Weightlifting", "Women's Health", "Yoga"]),
        GoogleNewsCategory(id: "History", name: "History", subcategories: ["African Kingdoms", "Age of Exploration", "American Revolution", "Ancient China", "Ancient Egypt", "Ancient Greece", "Ancient India", "Ancient Mesopotamia", "Ancient Rome", "Archaeology", "Art History", "British Empire", "Byzantine Empire", "Civil Rights Movement", "Civil War", "Cold War", "Colonial History", "Crusades", "Feudal Japan", "French Revolution", "Historical Preservation", "History of Religion", "History of Science", "Holocaust", "Industrial Revolution", "Korean War", "Latin American History", "Medieval Europe", "Mesoamerican Civilizations", "Military History", "Naval History", "Oral History", "Ottoman Empire", "Renaissance", "Russian Revolution", "Silk Road", "Vietnam War", "Viking Age", "World War I", "World War II"]),
        GoogleNewsCategory(id: "Hobbies & Collections", name: "Hobbies & Collections", subcategories: ["Amateur Radio", "Antique Collecting", "Aquariums and Fishkeeping", "Beekeeping", "Birdwatching", "Board Games", "Card Games", "Coin Collecting", "Comic Books", "Cosplay", "Drone Flying", "Fishing", "Gardening", "Geocaching", "Hiking", "Homebrewing", "Jigsaw Puzzles", "Leatherworking", "LEGO Building", "Metal Detecting", "Miniature Painting", "Model Building", "Pen Collecting", "Pottery and Ceramics", "RC Vehicles", "Rock Collecting", "Stamp Collecting", "Tabletop RPGs", "Trading Card Games", "Train Sets", "Vinyl Records", "Wargaming", "Watch Collecting"]),
        GoogleNewsCategory(id: "Home & Garden", name: "Home & Garden", subcategories: ["Backyard Design", "Bathroom Renovation", "Composting", "Container Gardening", "Curb Appeal", "Deck and Porch", "DIY Home Improvement", "Farmhouse Style", "Flooring Ideas", "Flower Gardening", "Furniture Design", "Home Automation", "Home Decor", "Home Energy Efficiency", "Home Office Design", "Home Organization", "Home Security Systems", "Home Storage Solutions", "Houseplants", "Indoor Herb Garden", "Interior Design", "Kitchen Remodel", "Landscaping", "Lawn Care", "Lighting Design", "Minimalist Home", "Organic Gardening", "Outdoor Living", "Patio Design", "Raised Bed Gardening", "Small Space Living", "Smart Home", "Sustainable Living", "Vegetable Gardening", "Window Treatments"]),
        GoogleNewsCategory(id: "Internet Culture & Social Media", name: "Internet Culture & Social Media", subcategories: ["AI-Generated Content", "Bluesky Social", "Cancel Culture", "Content Creation", "Content Moderation", "Creator Economy", "Deepfakes", "Digital Privacy", "Digital Wellness", "Discord Servers", "Fan Culture", "Influencer Marketing", "Instagram Reels", "Internet Celebrities", "Livestreaming", "Mastodon Fediverse", "Online Communities", "Online Harassment", "Online Memes", "Online Misinformation", "Podcasting", "Reddit Communities", "Screen Time", "Social Media Algorithms", "Social Media Influencers", "Social Media Marketing", "Social Media Regulation", "Substack Newsletters", "Threads App", "TikTok Trends", "Twitch Streaming", "Viral Videos", "Virtual Influencers", "YouTube Creators", "YouTube Shorts"]),
        GoogleNewsCategory(id: "Law & Legal", name: "Law & Legal", subcategories: ["AI Regulation", "Antitrust Law", "Bankruptcy Law", "Civil Rights Law", "Class Action Lawsuits", "Constitutional Law", "Consumer Protection", "Copyright Law", "Corporate Law", "Criminal Justice Reform", "Criminal Law", "Cybersecurity Law", "Data Privacy", "Death Penalty", "Election Law", "Employment Law", "Environmental Law", "Family Law", "First Amendment", "Healthcare Law", "Human Rights Law", "Immigration Law", "Intellectual Property", "International Law", "Judicial Nominations", "Legal Technology", "Maritime Law", "Military Law", "Patent Law", "Police Reform", "Privacy Law", "Real Estate Law", "Securities Law", "Supreme Court", "Tax Law", "Tech Regulation", "Trade Law", "Trademark Law", "White Collar Crime"]),
        GoogleNewsCategory(id: "Lifestyle", name: "Lifestyle", subcategories: ["City Living", "Cottagecore", "Cozy Living", "Dating", "Decluttering", "Digital Detox", "Digital Nomad", "Downsizing", "Expat Life", "Frugal Living", "Home Organization", "Homesteading", "Hygge", "Intentional Living", "Life Hacks", "Life Transitions", "Luxury Lifestyle", "Mindful Living", "Minimalism", "Minimalist Wardrobe", "Morning Routines", "Off-Grid Living", "Personal Development", "Relationships", "Remote Work Lifestyle", "Retirement Living", "Rural Living", "Self-Improvement", "Simple Living", "Slow Living", "Solo Living", "Suburban Living", "Sustainable Living", "Tiny Houses", "Van Life", "Work-Life Balance", "Zero Waste Living"]),
        GoogleNewsCategory(id: "Military & Defense", name: "Military & Defense", subcategories: ["Air Defense Systems", "Arms Trade and Weapons Sales", "Coast Guard", "Counter-Terrorism", "Cybersecurity Defense", "Defense Budget and Spending", "Defense Contractors", "Defense Industry News", "Defense Policy and Strategy", "Electronic Warfare", "Fighter Jets and Combat Aircraft", "Homeland Security", "Hypersonic Weapons", "Military Artificial Intelligence", "Military Cyber Operations", "Military Drones and UAVs", "Military Intelligence", "Military Recruitment", "Military Technology", "Military Veterans", "Missile Defense", "National Guard", "NATO Alliance", "Naval Warfare", "Nuclear Weapons and Deterrence", "Pentagon News", "Space Force", "Special Operations Forces", "Submarines and Undersea Warfare", "U.S. Air Force", "U.S. Army", "U.S. Marine Corps", "U.S. Navy", "Veterans Affairs and Benefits", "War and Conflict Updates"]),
        GoogleNewsCategory(id: "Music", name: "Music", subcategories: ["Album Reviews", "Alternative Music", "Band Interviews", "Blues Music", "Classical Music", "Concert Tours", "Country Music", "DJing", "Electronic Music", "Film Scores", "Folk Music", "Grammy Awards", "Guitar", "Heavy Metal Music", "Hip-Hop Music", "Indie Music", "Jazz Music", "K-Pop", "Latin Music", "Music Charts", "Music Education", "Music Festivals", "Music Industry News", "Music Production", "Music Streaming", "Music Technology", "Music Videos", "New Music Releases", "Opera", "Piano", "Pop Music", "Punk Music", "R&B Music", "Reggae Music", "Rock Music", "Songwriting", "Soul Music", "Vinyl Records", "World Music"]),
        GoogleNewsCategory(id: "News & Politics", name: "News & Politics", subcategories: ["Asia Pacific Politics", "Civil Rights", "Climate Policy", "Congress", "Defense Policy", "Diplomacy", "Economic Policy", "Education Policy", "Elections", "European Politics", "Foreign Policy", "Geopolitics", "Government Accountability", "Gun Policy", "Healthcare Policy", "House of Representatives", "Immigration", "Intelligence Community", "Investigative Journalism", "Labor Politics", "Local News", "Media Criticism", "Middle East Politics", "Midterm Elections", "National Security", "NATO", "Policy Analysis", "Political Campaigns", "Political Corruption", "Polling", "Presidential Elections", "Senate", "State Politics", "Supreme Court", "Trade Policy", "United Nations", "US Politics", "White House", "World News"]),
        GoogleNewsCategory(id: "Parenting", name: "Parenting", subcategories: ["ADHD in Children", "Adoption and Foster Care", "Baby Sleep Training", "Back to School", "Blended Families", "Breastfeeding", "Bullying Prevention", "Child Custody", "Child Development Milestones", "Child Nutrition", "Child Safety", "Childhood Anxiety", "Childhood Vaccinations", "Children and Reading", "Co-Parenting", "Daycare and Childcare", "Discipline and Positive Parenting", "Family Activities", "Family Travel with Kids", "Homeschooling", "Kids and Sports", "Newborn Care", "Parental Mental Health", "Parenting Teens and Social Media", "Postpartum Depression", "Potty Training", "Pregnancy and Prenatal Care", "Preschool Readiness", "Preteen Parenting", "School-Age Children", "Screen Time and Kids", "Sibling Rivalry", "Single Parenting", "Special Needs Parenting", "Teenage Parenting", "Toddler Development", "Work-Life Balance for Parents"]),
        GoogleNewsCategory(id: "Pets & Animals", name: "Pets & Animals", subcategories: ["Animal Rescue & Shelters", "Animal Rights", "Animal Science & Research", "Animal Welfare", "Backyard Chickens", "Cat Behavior", "Cats", "Coral Reefs & Marine Conservation", "Dog Breeds", "Dog Training", "Dogs", "Endangered Species", "Exotic Pets", "Freshwater Aquarium Fish", "Horses & Equestrian", "Insects & Pollinators", "Livestock & Farm Animals", "Marine Life", "Pet Adoption", "Pet Birds", "Pet Grooming", "Pet Health", "Pet Industry & Products", "Pet Insurance", "Pet Nutrition", "Pet Travel", "Rabbits", "Reptiles & Amphibians", "Service Animals & Therapy Pets", "Small Pets & Rodents", "Veterinary Medicine", "Wildlife Conservation", "Wildlife Photography", "Zoos & Aquariums"]),
        GoogleNewsCategory(id: "Philosophy", name: "Philosophy", subcategories: ["Absurdism", "Aesthetics", "AI Ethics", "Analytic Philosophy", "Ancient Philosophy", "Bioethics", "Buddhism Philosophy", "Confucianism", "Consciousness Studies", "Continental Philosophy", "Critical Theory", "Eastern Philosophy", "Environmental Ethics", "Epistemology", "Ethics", "Existentialism", "Feminist Philosophy", "Free Will", "Hermeneutics", "Logic", "Metaphysics", "Moral Philosophy", "Nihilism", "Phenomenology", "Philosophy of Education", "Philosophy of History", "Philosophy of Language", "Philosophy of Law", "Philosophy of Mind", "Philosophy of Religion", "Philosophy of Science", "Philosophy of Technology", "Political Philosophy", "Postmodernism", "Pragmatism", "Social Justice Philosophy", "Stoicism", "Taoism", "Utilitarianism", "Virtue Ethics"]),
        GoogleNewsCategory(id: "Photography", name: "Photography", subcategories: ["Abstract Photography", "Adobe Lightroom", "Analog Photography", "Architecture Photography", "Astrophotography", "Black and White Photography", "Camera Gear", "Candid Photography", "Concert Photography", "Darkroom Printing", "Documentary Photography", "Drone Photography", "DSLR Cameras", "Fashion Photography", "Film Photography", "Fine Art Photography", "Food Photography", "Landscape Photography", "Macro Photography", "Mirrorless Cameras", "Mobile Photography", "Nature Photography", "Night Photography", "Photo Contests", "Photo Editing", "Photography Composition", "Photography Exhibitions", "Photojournalism", "Portrait Photography", "Product Photography", "Sports Photography", "Street Photography", "Studio Lighting", "Travel Photography", "Underwater Photography", "Wedding Photography", "Wildlife Photography"]),
        GoogleNewsCategory(id: "Productivity & Organization", name: "Productivity & Organization", subcategories: ["Atomic Habits", "Bullet Journaling", "Calendar Management", "Deep Work", "Digital Minimalism", "Digital Productivity Tools", "Eisenhower Matrix", "Email Management", "Focus Techniques", "Getting Things Done", "Goal Setting", "Habit Building", "Habit Tracking", "Inbox Zero", "Kanban Board", "Mind Mapping", "Morning Routine", "Note-Taking Apps", "Notion", "Obsidian", "Personal Automation", "Personal Knowledge Management", "Pomodoro Technique", "Productivity Apps", "Project Planning", "Roam Research", "Second Brain", "Task Management", "Time Management", "Timeboxing", "Todoist", "Weekly Review", "Workflow Automation", "Zapier"]),
        GoogleNewsCategory(id: "Psychology & Mental Health", name: "Psychology & Mental Health", subcategories: ["Addiction Recovery", "ADHD Research", "Adolescent Mental Health", "Anxiety Disorders", "Autism Spectrum", "Behavioral Psychology", "Bipolar Disorder", "Burnout Prevention", "Child Psychology", "Clinical Psychology", "Cognitive Behavioral Therapy", "Couples Therapy", "Depression Treatment", "Developmental Psychology", "Eating Disorders", "Emotional Intelligence", "Grief Counseling", "Mental Health Apps", "Mental Health Policy", "Mental Health Stigma", "Mindfulness Meditation", "Neuropsychology", "Neuroscience Research", "Obsessive Compulsive Disorder", "Perinatal Mental Health", "Personality Disorders", "Positive Psychology", "Psychopharmacology", "Psychotherapy Techniques", "PTSD Recovery", "Schizophrenia Research", "Sleep Psychology", "Social Psychology", "Stress Management", "Substance Abuse Treatment", "Trauma Therapy", "Workplace Mental Health"]),
        GoogleNewsCategory(id: "Real Estate", name: "Real Estate", subcategories: ["Affordable Housing", "Commercial Real Estate", "Condo Market", "First Time Home Buyers", "Foreclosures", "Green Building", "Home Appraisal", "Home Buying Tips", "Home Inspections", "Home Insurance", "Home Prices", "Home Renovations", "Homebuilders", "House Flipping", "Housing Market Trends", "Industrial Real Estate", "Luxury Real Estate", "Mortgage Rates", "Multifamily Housing", "Office Real Estate", "Property Management", "Property Taxes", "Real Estate Agents", "Real Estate Auctions", "Real Estate Crowdfunding", "Real Estate Development", "Real Estate Investing", "Real Estate Law", "Real Estate Market Forecast", "Real Estate Technology", "REITs", "Rental Market", "Reverse Mortgages", "Senior Housing", "Short Term Rentals", "Tiny Homes", "Vacation Rentals", "Zoning and Land Use"]),
        GoogleNewsCategory(id: "Religion & Spirituality", name: "Religion & Spirituality", subcategories: ["Atheism & Agnosticism", "Biblical Studies", "Buddhism", "Catholicism", "Christianity", "Church & State", "Evangelical Christianity", "Hinduism", "Indigenous & Folk Religions", "Interfaith Dialogue", "Islam", "Jainism", "Judaism", "Kabbalah", "Meditation & Mindfulness", "New Age Spirituality", "Orthodox Christianity", "Pilgrimage & Holy Sites", "Prayer & Devotion", "Religion & Science", "Religious Education", "Religious Freedom", "Religious History", "Religious Holidays & Festivals", "Religious Leadership", "Shia Islam", "Shintoism", "Sikhism", "Spirituality", "Sufism", "Sunni Islam", "Taoism", "Theology", "Tibetan Buddhism", "Zen Buddhism"]),
        GoogleNewsCategory(id: "Science", name: "Science", subcategories: ["Astrobiology", "Astrophysics", "Biochemistry", "Biophysics", "Botany", "Cell Biology", "Climate Science", "Computational Biology", "CRISPR Gene Editing", "Ecology", "Epidemiology", "Evolutionary Biology", "Genetics", "Genomics", "Geology", "Immunology", "Marine Biology", "Materials Science", "Microbiology", "Molecular Biology", "Nanotechnology", "Neuroscience", "Nuclear Physics", "Oceanography", "Organic Chemistry", "Paleontology", "Particle Physics", "Pharmacology", "Quantum Mechanics", "Seismology", "Stem Cell Research", "Synthetic Biology", "Virology", "Volcanology", "Zoology"]),
        GoogleNewsCategory(id: "Space & Astronomy", name: "Space & Astronomy", subcategories: ["Artemis Program", "Asteroid Mining", "Black Holes", "Blue Origin", "Chinese Space Program", "Cosmology", "Dark Energy", "Dark Matter", "Europa Clipper", "Exoplanets", "Galaxy Formation", "Gravitational Waves", "Hubble Telescope", "Indian Space Program ISRO", "International Space Station", "James Webb Space Telescope", "Lunar Gateway", "Mars Exploration", "Moon Exploration", "NASA", "Neutron Stars", "Planetary Science", "Radio Astronomy", "Rocket Launches", "Satellite Technology", "Solar Flares", "Solar System", "Space Debris", "Space Telescopes", "Space Tourism", "Space Weather", "SpaceX", "Starlink Satellites", "Starship Rocket", "Supernovae"]),
        GoogleNewsCategory(id: "Sports", name: "Sports", subcategories: ["Archery", "Badminton", "Baseball", "Basketball", "BMX", "Bobsled", "Boxing", "Cricket", "CrossFit", "Curling", "Cycling", "Diving", "Esports", "Fencing", "Field Hockey", "Figure Skating", "Football", "Formula 1", "Golf", "Gymnastics", "Handball", "Hockey", "Horse Racing", "IndyCar", "Lacrosse", "Marathon Running", "MMA", "Motocross", "NASCAR", "Pickleball", "Polo", "Rally Racing", "Rock Climbing", "Rowing", "Rugby", "Sailing", "Skateboarding", "Skiing", "Snowboarding", "Soccer", "Surfing", "Swimming", "Table Tennis", "Tennis", "Track and Field", "Triathlon", "Volleyball", "Water Polo", "Weightlifting", "Wrestling"]),
        GoogleNewsCategory(id: "Technology", name: "Technology", subcategories: ["3D Printing", "5G Networks", "Artificial Intelligence", "Augmented Reality", "Big Data", "Biotechnology", "Blockchain", "Cloud Computing", "Computer Vision", "Cybersecurity", "Data Science", "Deep Learning", "DevOps", "Digital Privacy", "Drones", "Edge Computing", "Electric Vehicles", "Fintech", "Gaming Technology", "Generative AI", "Internet of Things", "Laptops", "Linux", "Machine Learning", "Mobile App Development", "Nanotechnology", "Natural Language Processing", "Net Neutrality", "Open Source Software", "Programming Languages", "Quantum Computing", "Robotics", "Satellite Internet", "Self-Driving Cars", "Semiconductors", "Smart Home", "Smartphones", "Social Media Platforms", "Software Engineering", "Space Technology", "Streaming Services", "Tech Policy and Regulation", "Tech Startups", "Virtual Reality", "Wearables", "Web Development"]),
        GoogleNewsCategory(id: "Travel", name: "Travel", subcategories: ["Accessible Travel", "Adventure Travel", "Airlines", "Backpacking", "Beach Vacations", "Budget Travel", "Camping", "City Breaks", "Cruises", "Cultural Tourism", "Digital Nomad", "Eco Tourism", "Family Travel", "Food Tourism", "Hiking Travel", "Hotels", "Island Travel", "Luxury Travel", "Mountain Travel", "National Parks", "Passport and Visa", "Pet Friendly Travel", "Road Trips", "Safari Travel", "Ski Travel", "Solo Travel", "Sustainable Travel", "Train Travel", "Travel Deals", "Travel Gear", "Travel Hacking", "Travel Insurance", "Travel Photography", "Travel Safety", "Travel Technology", "Travel Tips", "Van Life", "Volunteer Travel", "Weekend Getaways", "Wellness Travel"]),
        GoogleNewsCategory(id: "True Crime", name: "True Crime", subcategories: ["Arson Investigation", "Cold Cases", "Court Trials", "Crime Documentary", "Crime Scene Investigation", "Crime Statistics", "Criminal Appeals", "Criminal Investigations", "Criminal Profiling", "Criminal Psychology", "Cybercrime", "Death Row", "DNA Evidence", "Domestic Violence Cases", "Drug Trafficking", "Evidence Tampering", "FBI Investigations", "Financial Fraud", "Forensic Psychology", "Forensic Science", "Gang Violence", "Hate Crimes", "Heists and Robberies", "Human Trafficking", "Identity Theft", "Jury Trials", "Kidnapping Cases", "Missing Persons", "Organized Crime", "Parole and Probation", "Police Misconduct", "Prison Life", "Serial Killers", "True Crime Podcasts", "Unsolved Murders", "Victim Advocacy", "White Collar Crime", "Witness Protection", "Wrongful Convictions"]),
        GoogleNewsCategory(id: "Weather & Climate", name: "Weather & Climate", subcategories: ["Air Quality and Smog", "Arctic Ice and Polar Weather", "Atmospheric Science", "Avalanche Warnings", "Blizzards and Ice Storms", "Climate Change Science", "Climate Data and Records", "Climate Policy", "Coastal Storm Surge", "Drought Conditions", "El Nino and La Nina", "Extreme Heat Waves", "Flash Flooding", "Hurricane Tracking", "Jet Stream Patterns", "Lightning and Hail", "Meteorology Research", "Monsoon Season", "Ocean Temperature Anomalies", "Rainfall and Precipitation", "Record Breaking Temperatures", "Sea Level Rise", "Seasonal Allergy Forecasts", "Severe Thunderstorms", "Tornado Outbreaks", "Tropical Storms", "UV Index and Solar Radiation", "Weather and Aviation Safety", "Weather Emergency Preparedness", "Weather Forecasting", "Weather Radar Technology", "Weather Satellites", "Wildfire Weather", "Wind Storms and Derechos", "Winter Storms"]),
        GoogleNewsCategory(id: "Wellness & Self-Care", name: "Wellness & Self-Care", subcategories: ["Acupuncture", "Aromatherapy", "Ayurveda", "Body Positivity", "Breathwork", "Burnout Recovery", "Chronic Pain Management", "Cold Plunge & Ice Bath", "Digital Detox", "Emotional Wellness", "Fitness Recovery", "Float Therapy", "Forest Bathing", "Gratitude Practice", "Gut Health", "Herbal Remedies", "Holistic Health", "Journaling", "Meditation", "Mental Health Awareness", "Mindful Movement", "Mindfulness", "Nutrition & Clean Eating", "Pilates", "Positive Psychology", "Reiki & Energy Healing", "Sauna Therapy", "Self-Care Routines", "Skin Care Rituals", "Sleep Health", "Sleep Hygiene", "Sound Healing", "Spa & Wellness", "Stress Management", "Stretching & Mobility", "Tai Chi", "Wellness Retreats", "Wellness Technology", "Work-Life Balance", "Yoga"]),
    ]
}
