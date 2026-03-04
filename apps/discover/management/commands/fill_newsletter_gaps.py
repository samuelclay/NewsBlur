"""
One-off script to add real newsletters to popular_feeds.json to fill category/subcategory gaps.
Every category must have 12+ feeds, every subcategory must have 3+.

Usage:
    python manage.py fill_newsletter_gaps
    python manage.py fill_newsletter_gaps --dry-run
"""

import json
import os
from collections import Counter, defaultdict

from django.core.management.base import BaseCommand

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "../../fixtures")
FIXTURE_PATH = os.path.join(FIXTURE_DIR, "popular_feeds.json")

MIN_CATEGORY_COUNT = 12
MIN_SUBCATEGORY_COUNT = 3

# fmt: off
# Mapping: (category, subcategory) -> list of (title, feed_url, description, platform)
# Platform is one of: "substack", "medium", "ghost", "beehiiv", "buttondown", "web", ""
_NEWSLETTERS_RAW = [
    # ── gaming ────────────────────────────────────────────────────────
    # Category needs 11+ newsletters. Only has "Board Games" subcategory.
    ("gaming", "Board Games"), [
        ("Shut Up & Sit Down", "https://www.shutupandsitdown.com/feed/", "Board game reviews, news, and videos from the internet's favorite board game reviewers", "web"),
        ("The Indie RPG Newsletter", "https://ttrpg.substack.com/feed", "Curated weekly list of indie tabletop games, articles, and podcasts", "substack"),
    ],
    ("gaming", "Console Gaming"), [
        ("Crossplay", "https://www.crossplay.news/feed", "In-depth coverage of console and video games from a parent's perspective by Patrick Klepek", "substack"),
        ("Post Games", "https://postgame.substack.com/feed", "A video game newsletter for everybody covering console games and gaming culture", "substack"),
        ("Story Mode", "https://storymodeinfo.substack.com/feed", "Coverage and analysis of the latest console and video game releases", "substack"),
    ],
    ("gaming", "Esports"), [
        ("Ultimate Esports Newsletter", "https://esports.substack.com/feed", "Multi-game esports news and data coverage from the competitive gaming world", "substack"),
        ("Push to Talk", "https://www.pushtotalk.gg/feed", "Marketing, games, and insider perspectives from a game industry veteran", "substack"),
        ("Ollie Ring Esports", "https://olliering.substack.com/feed", "No-holds-barred opinions on the business world of esports", "substack"),
    ],
    ("gaming", "Game Design"), [
        ("GameDev Reports", "https://gamedevreports.substack.com/feed", "In-depth analysis of game development trends, tools, and industry insights", "substack"),
        ("GameMakers", "https://www.gamemakers.com/feed", "Interviews and deep dives into game design and development", "substack"),
        ("Elite Game Developers", "https://elitegamedevelopers.substack.com/feed", "Game development intricacies and career advice for game developers", "substack"),
    ],
    ("gaming", "Game Reviews"), [
        ("The Pause Button", "https://pausebutton.substack.com/feed", "Anything and everything about video games with thoughtful reviews and analysis", "substack"),
        ("Good Game Lobby", "https://goodgamelobby.substack.com/feed", "Weekly indie game picks, reviews, crowdfunding games, and soundtracks", "substack"),
        ("Save Spot", "https://savespot.substack.com/feed", "Personal work from a reporter covering the business and culture of video games", "substack"),
    ],
    ("gaming", "Gaming Industry"), [
        ("Game File", "https://www.gamefile.news/feed", "Gaming industry news, scoops, and cultural insights from veteran reporter Stephen Totilo", "substack"),
        ("Hit Points", "https://hitpoints.substack.com/feed", "Daily analysis of the video games industry from former Edge editor Nathan Brown", "substack"),
        ("Video Games Industry Memo", "https://www.videogamesindustrymemo.com/feed", "Expert analysis and exclusive data on the global video game industry", "substack"),
    ],
    ("gaming", "Indie Gaming"), [
        ("Adventures in Indie Gaming", "https://indiegames.substack.com/feed", "Regular previews and reviews of indie games and hidden gems", "substack"),
        ("The GameDiscoverCo Newsletter", "https://newsletter.gamediscover.co/feed", "Analysis, data, and insight about how people find and buy video games", "substack"),
        ("GameDiscoverCo Plus", "https://gamediscoverco.substack.com/feed", "Deep dives into game discoverability, store algorithms, and player behavior", "substack"),
    ],
    ("gaming", "Mobile Gaming"), [
        ("MobileGamer.biz", "https://mobilegamer.substack.com/feed", "Data and reporting on the free-to-play mobile game market", "substack"),
        ("Deconstructor of Fun", "https://www.deconstructoroffun.com/feed", "Analysis of free-to-play game design, monetization, and mobile gaming trends", "web"),
        ("Game World Observer", "https://gameworldobserver.substack.com/feed", "Daily mobile gaming industry news, data, and analysis", "substack"),
    ],
    ("gaming", "PC Gaming"), [
        ("Joost van Dreunen", "https://joostvandreunen.substack.com/feed", "Weekly analysis of gaming, tech, and entertainment from a business professor", "substack"),
        ("Chris Dring", "https://chrisdring.substack.com/feed", "Expert analysis and in-depth interviews on the global video game industry", "substack"),
        ("PC Gamer Newsletter", "https://www.pcgamer.com/rss/", "The latest PC gaming news, reviews, and features from the world's top PC gaming magazine", "web"),
    ],
    ("gaming", "Retro Gaming"), [
        ("Retro Gaming Weekly News", "https://retrogamingnews.substack.com/feed", "Weekly retro gaming finds, hardware news, and nostalgia-driven coverage", "substack"),
        ("Time Extension", "https://www.timeextension.com/feeds/latest", "Retro and legacy gaming coverage from the team behind Nintendo Life", "web"),
        ("The Video Game History Foundation", "https://gamehistory.org/feed/", "News and articles about preserving and celebrating video game history", "web"),
    ],

    # ── arts & culture ────────────────────────────────────────────────
    ("arts & culture", "Art Criticism"), [
        ("The Gen Z Art Critic", "https://jenniferbraun.substack.com/feed", "Weekly exhibition reviews from a Gen Z art historian based in Venice and Cologne", "substack"),
        ("Hyperallergic", "https://hyperallergic.com/feed/", "Serious, playful, and radical perspectives on art and culture in the world today", "web"),
    ],
    ("arts & culture", "Visual Arts"), [
        ("The Arts Stack", "https://rosiemillard.substack.com/feed", "Weekly insight into arts and culture from former BBC arts correspondent Rosie Millard", "substack"),
    ],

    # ── books & reading ───────────────────────────────────────────────
    ("books & reading", "Author News"), [
        ("Counter Craft", "https://countercraft.substack.com/feed", "Smart and surprising writing guidance from author Lincoln Michel", "substack"),
        ("CRAFT TALK", "https://jamiattenberg.substack.com/feed", "Weekly newsletter about writing, creativity, and productivity from author Jami Attenberg", "substack"),
    ],
    ("books & reading", "Publishing Industry"), [
        ("Publishing Confidential", "https://kathleenschmidt.substack.com/feed", "Weekly Q&As and interviews about publicity, platform, and book sales", "substack"),
        ("Delivery and Acceptance", "https://deliveryandacceptance.substack.com/feed", "Industry advice and insights from literary agent Alia Hanna Habib", "substack"),
    ],

    # ── business ──────────────────────────────────────────────────────
    ("business", "Corporate News"), [
        ("Big Technology", "https://www.bigtechnology.com/feed", "Weekly newsletter covering the intersection of technology and big business by Alex Kantrowitz", "substack"),
        ("The Sociology of Business", "https://andjelicaaa.substack.com/feed", "How brands connect business with culture through cultural intelligence and market mood", "substack"),
    ],
    ("business", "Industry Analysis"), [
        ("OnlyCFO", "https://www.onlycfo.io/feed", "Deep-dive analysis into SaaS, technology companies, and industry metrics", "substack"),
        ("Stratechery", "https://stratechery.com/feed/", "Analysis of the strategy and business side of technology and media by Ben Thompson", "web"),
    ],
    ("business", "Management & Leadership"), [
        ("The Looking Glass", "https://lg.substack.com/feed", "Leadership, management, and career advice from a former VP of Design at Facebook", "substack"),
        ("The Skip", "https://theskip.substack.com/feed", "Practical advice on management and leadership from Nikhyl Singhal", "substack"),
    ],
    ("business", "Startups & VC"), [
        ("The VC Corner", "https://www.thevccorner.com/feed", "Weekly guide through startups and venture capital with curated news and insights", "substack"),
    ],

    # ── cryptocurrency & web3 ─────────────────────────────────────────
    ("cryptocurrency & web3", "Crypto News"), [
        ("The Pomp Letter", "https://pomp.substack.com/feed", "Commentary on Bitcoin, markets, and macroeconomic trends from Anthony Pompliano", "substack"),
        ("Milk Road", "https://www.milkroad.com/feed", "Daily crypto developments delivered in an engaging, educational style for newcomers and experts", "web"),
    ],
    ("cryptocurrency & web3", "NFTs & Digital Assets"), [
        ("Zima Red", "https://andrewsteinwold.substack.com/feed", "Comprehensive coverage of NFTs, digital assets, and the metaverse", "substack"),
        ("Bankless", "https://www.bankless.com/rss/", "Ethereum-focused news, DeFi strategies, DAO governance, and Web3 commentary", "web"),
    ],

    # ── design ────────────────────────────────────────────────────────
    ("design", "Design Inspiration"), [
        ("Dense Discovery", "https://www.densediscovery.com/feed/", "Weekly curated links across design, tech, culture, and sustainability", "web"),
        ("Creative Boom", "https://www.creativeboom.com/feed/", "Creative inspiration, business advice, and features on emerging designers and studios", "web"),
    ],
    ("design", "Graphic Design"), [
        ("I Love Typography", "https://ilovetypography.com/feed/", "History of letterforms, font releases, and interviews with type designers", "web"),
        ("Logo Archive", "https://logoarchive.substack.com/feed", "Deep dives into vintage and modernist logo design", "substack"),
    ],

    # ── entertainment ─────────────────────────────────────────────────
    ("entertainment", "Pop Culture"), [
        ("Hung Up", "https://hungerharris.substack.com/feed", "Movies, TV, the celebrity industrial complex, and personal pop culture obsessions", "substack"),
        ("The Culture Journalist", "https://theculturejournalist.substack.com/feed", "Cultural news and analysis covering entertainment, media, and pop culture trends", "substack"),
    ],
    ("entertainment", "Streaming"), [
        ("The Entertainment Strategy Guy", "https://entertainment.substack.com/feed", "Analysis of entertainment strategy with weekly streaming ratings reports", "substack"),
        ("Streaming Made Easy", "https://streamingmadeeasy.substack.com/feed", "Deep dives into the European streaming market and global entertainment industry", "substack"),
    ],

    # ── entrepreneurship & startups ───────────────────────────────────
    ("entrepreneurship & startups", "Incubators & Accelerators"), [
        ("Y Combinator Blog", "https://www.ycombinator.com/blog/rss/", "News and insights from the world's most prominent startup accelerator", "web"),
        ("Techstars Newsletter", "https://www.techstars.com/blog/feed", "Updates from one of the leading startup accelerator programs worldwide", "web"),
    ],
    ("entrepreneurship & startups", "Product Management"), [
        ("Lenny's Newsletter", "https://www.lennysnewsletter.com/feed", "Weekly advice on building product, driving growth, and accelerating your career", "substack"),
    ],
    ("entrepreneurship & startups", "Venture Capital"), [
        ("Not Boring", "https://www.notboring.co/feed", "Stories behind ambitious startups with deep dives on investing and technology", "substack"),
        ("Newcomer", "https://www.newcomer.co/feed", "In-depth insights into the intersection of technology and venture capital by Eric Newcomer", "substack"),
    ],

    # ── environment & sustainability ──────────────────────────────────
    ("environment & sustainability", "Climate Change"), [
        ("The Crucial Years", "https://billmckibben.substack.com/feed", "Twice-weekly deep dives into climate and environmental stories by Bill McKibben", "substack"),
        ("HEATED", "https://heated.world/feed", "Exposing the forces behind inaction on climate change by journalist Emily Atkin", "substack"),
    ],

    # ── food & cooking ────────────────────────────────────────────────
    ("food & cooking", "Baking"), [
        ("ZoeBakes", "https://zoefrancois.substack.com/feed", "Easy baking recipes, useful tips and tricks from a bestselling cookbook author", "substack"),
        ("Bake Chats", "https://ibakemistakes.substack.com/feed", "Sweet recipes, monthly favorites, baking tips, and finding inspiration", "substack"),
    ],
    ("food & cooking", "Comfort Food"), [
        ("What to Cook", "https://whattocook.substack.com/feed", "One impressive complete-meal recipe every Saturday that is quick and easy", "substack"),
        ("Alison Roman", "https://anewsletter.alisoneroman.com/feed", "Recipes, stories, and food writing from bestselling cookbook author Alison Roman", "substack"),
    ],
    ("food & cooking", "Food Science"), [
        ("Ruhlman's Newsletter", "https://ruhlman.substack.com/feed", "Food writing exploring cooking techniques, food science, and culinary traditions", "substack"),
    ],
    ("food & cooking", "International Cuisine"), [
        ("Pass the Fish Sauce", "https://andreangnguyen.substack.com/feed", "Andrea Nguyen documents and demystifies Asian home cooking", "substack"),
        ("Ottolenghi", "https://ottolenghi.substack.com/feed", "Vibrant recipes celebrating Middle Eastern cuisine from Yotam Ottolenghi", "substack"),
    ],
    ("food & cooking", "Recipe Collections"), [
        ("Dorie Greenspan", "https://doriegreenspan.substack.com/feed", "Recipes and food stories from the award-winning cookbook author Dorie Greenspan", "substack"),
        ("David Lebovitz", "https://davidlebovitz.substack.com/feed", "Recipes, Paris food tips, and personal stories from pastry chef David Lebovitz", "substack"),
    ],
    ("food & cooking", "Restaurant Reviews"), [
        ("The Lo Times", "https://www.thelotimes.com/feed", "Restaurant reviews, best-of lists, and dining recommendations from food critic Ryan Sutton", "substack"),
    ],

    # ── gaming (extra subcategories already covered above) ────────────

    # ── health & fitness ──────────────────────────────────────────────
    ("health & fitness", "Diet & Nutrition"), [
        ("Your Local Epidemiologist", "https://yourlocalepidemiologist.substack.com/feed", "Evidence-based health and nutrition information from Dr. Katelyn Jetelina", "substack"),
        ("Physiologically Speaking", "https://www.physiologicallyspeaking.com/feed", "Science-based insights on nutrition, exercise physiology, and health", "substack"),
    ],
    ("health & fitness", "Running & Endurance"), [
        ("The Half Marathoner", "https://www.thehalfmarathoner.com/feed", "Weekly digest of running information covering training, nutrition, shoes, and injury prevention", "substack"),
    ],
    ("health & fitness", "Weight Training"), [
        ("LIFT", "https://annemariechaker.substack.com/feed", "Science-backed strength training insights from WSJ reporter-turned-professional bodybuilder", "substack"),
        ("Strength for Longevity", "https://strengthforlongevity.substack.com/feed", "Strength training for longevity with exercise scientist Pete McCall", "substack"),
    ],

    # ── lifestyle ─────────────────────────────────────────────────────
    ("lifestyle", "City Living"), [
        ("London Centric", "https://londoncentric.substack.com/feed", "Modern newspaper for London providing investigations, original journalism, and local news", "substack"),
        ("The Travelogue", "https://travelogue.substack.com/feed", "City guides, restaurant recommendations, culture picks, and travel inspiration", "substack"),
    ],
    ("lifestyle", "Luxury Lifestyle"), [
        ("The Love List", "https://www.thelovelist.wtf/feed", "Curated recommendations for the best in food, travel, culture, and luxury living", "substack"),
        ("Morning Person", "https://www.morningpersonnewsletter.com/feed", "Lifestyle and culture recommendations from Leslie Stephens", "substack"),
    ],
    ("lifestyle", "Personal Development"), [
        ("The Profile", "https://theprofile.substack.com/feed", "Longform profiles of the most interesting people and companies driving culture forward", "substack"),
        ("The Marginalian", "https://www.themarginalian.org/feed/", "Reflections on the meaning of life, art, science, and creativity by Maria Popova", "web"),
    ],
    ("lifestyle", "Urban Living"), [
        ("Curbed", "https://www.curbed.com/rss/index.xml", "Obsessive coverage of city living including real estate, architecture, and urban design", "web"),
        ("CityLab", "https://www.bloomberg.com/citylab/feed", "Urban life and city planning news and analysis from Bloomberg", "web"),
    ],

    # ── news & politics ───────────────────────────────────────────────
    ("news & politics", "Investigative"), [
        ("Popular Information", "https://popular.info/feed", "Investigative journalism holding corporations and politicians accountable by Judd Legum", "substack"),
        ("The Lever", "https://www.levernews.com/rss/", "Investigative journalism that exposes corruption and holds the powerful accountable", "ghost"),
    ],
    ("news & politics", "Local News"), [
        ("The City", "https://www.thecity.nyc/feed/", "Nonprofit investigative newsroom for New York City covering local government and policy", "web"),
        ("Baltimore Banner", "https://www.thebaltimorebanner.com/arc/outboundfeeds/rss/", "Independent local news for the Baltimore area", "web"),
    ],
    ("news & politics", "National News"), [
        ("Letters from an American", "https://heathercoxrichardson.substack.com/feed", "Daily current affairs newsletter from historian Heather Cox Richardson", "substack"),
        ("Zeteo", "https://zeteo.com/feed", "News and analysis seeking answers for the questions that really matter from Mehdi Hasan", "web"),
    ],
    ("news & politics", "Opinion & Editorials"), [
        ("The Free Press", "https://www.thefp.com/feed", "Independent journalism and opinion covering culture, politics, and current events", "web"),
        ("Slow Boring", "https://www.slowboring.com/feed", "Center-left policy analysis and political commentary by Matthew Yglesias", "substack"),
    ],
    ("news & politics", "Policy Analysis"), [
        ("Noahpinion", "https://www.noahpinion.blog/feed", "Economics, policy analysis, and social commentary from Noah Smith", "substack"),
        ("The Liberal Patriot", "https://www.liberalpatriot.com/feed", "Center-left policy analysis and political commentary from Ruy Teixeira", "substack"),
    ],

    # ── parenting ─────────────────────────────────────────────────────
    ("parenting", "Parenting Advice"), [
        ("Now What", "https://melindawmoyer.substack.com/feed", "Science-based parenting advice that challenges fear-mongering by Melinda Wenner Moyer", "substack"),
        ("Parenting Translator", "https://parentingtranslator.substack.com/feed", "Child psychologist translates research on parenting and child development for parents", "substack"),
    ],

    # ── photography ───────────────────────────────────────────────────
    ("photography", "Photography News"), [
        ("Process On Photography", "https://wesley.substack.com/feed", "Leading weekly photography newsletter with practical insights for 18,000+ photographers", "substack"),
        ("FlakPhoto Digest", "https://flakphoto.substack.com/feed", "Books, photographs, and creative thoughts from a long-running photography community", "substack"),
    ],

    # ── sports ────────────────────────────────────────────────────────
    ("sports", "Baseball"), [
        ("The Cycle", "https://cyclenewsletter.substack.com/feed", "Major League Baseball coverage from a former lead baseball writer at SI.com", "substack"),
        ("Codify Baseball", "https://codifybaseball.substack.com/feed", "Data-driven baseball analysis and pitching insights", "substack"),
    ],
    ("sports", "Football"), [
        ("Go Long", "https://www.golongtd.com/feed", "Independent NFL longform journalism with deep dives and player profiles by Tyler Dunne", "substack"),
        ("MatchQuarters", "https://www.matchquarters.com/feed", "Schematic football analysis covering strategy, game planning, and Xs and Os", "substack"),
    ],
    ("sports", "Horse Racing"), [
        ("Horse Racing Fans", "https://horseracingfans.substack.com/feed", "News, analysis, and previews for horse racing enthusiasts", "substack"),
        ("FormBet Horse Racing", "https://formbet.substack.com/feed", "Horse racing ratings, systems, and previews for bettors and fans", "substack"),
    ],
    ("sports", "MMA & Boxing"), [
        ("Knockout News", "https://knockoutnews.substack.com/feed", "Weekly newsletter covering updates and analysis in boxing and MMA", "substack"),
    ],
    ("sports", "Rugby"), [
        ("Rugby Journal", "https://rugbyjournal.substack.com/feed", "In-depth rugby coverage with analysis and features", "substack"),
        ("For The Love Of Rugby", "https://loveofrugby.substack.com/feed", "Rugby analysis, previews, and interviews covering international rugby", "substack"),
    ],
    ("sports", "Tennis"), [
        ("The Tennis Letter", "https://thetennisletter.substack.com/feed", "Free weekly newsletter for true tennis enthusiasts covering tournaments and rankings", "substack"),
        ("Tennis Brainfood", "https://tennisbrainfood.substack.com/feed", "Weekly curated tennis content to help improve your game and follow the sport", "substack"),
    ],

    # ── technology ────────────────────────────────────────────────────
    ("technology", "Cybersecurity"), [
        ("Venture in Security", "https://ventureinsecurity.net/feed", "Cybersecurity trends, business models, and venture capital in the security industry", "substack"),
        ("Resilient Cyber", "https://www.resilientcyber.io/feed", "Insights on cybersecurity resilience, cloud security, and emerging threats", "substack"),
    ],
    ("technology", "Startups"), [
        ("The Pragmatic Engineer", "https://newsletter.pragmaticengineer.com/feed", "The number-one technology newsletter covering tech industry trends and engineering culture", "substack"),
        ("TLDR Newsletter", "https://tldr.tech/rss", "Daily byte-sized summaries of the most interesting tech, startup, and programming stories", "web"),
    ],

    # ── travel ────────────────────────────────────────────────────────
    ("travel", "Accessible Travel"), [
        ("Accessible Travel Press", "https://accessibletravel.substack.com/feed", "News, guides, and resources for travelers with disabilities", "substack"),
        ("Curb Free with Cory Lee", "https://curbfreewithcorylee.com/feed/", "Wheelchair travel blog covering accessible destinations worldwide", "web"),
    ],
    ("travel", "Road Trips"), [
        ("The Weekly Traveller", "https://theweeklytraveller.substack.com/feed", "Road trip guides, destination highlights, and unique travel experiences", "substack"),
        ("Roadtrippers Magazine", "https://magazine.roadtrippers.com/feed/", "Road trip stories, route recommendations, and travel inspiration across America", "web"),
    ],

    # ── additional fills for remaining subcategory gaps ──────────────
    ("books & reading", "Author News"), [
        ("Electric Literature", "https://electricliterature.com/feed/", "Author interviews, essays, and original fiction", "web"),
    ],
    ("books & reading", "Publishing Industry"), [
        ("Publishers Weekly", "https://www.publishersweekly.com/rss/", "Book deals, industry news, and publishing trends", "web"),
    ],
    ("business", "Corporate News"), [
        ("Fortune Term Sheet", "https://fortune.com/section/term-sheet/feed/", "The biggest deals and dealmakers in corporate America", "web"),
        ("Quartz Daily Brief", "https://qz.com/feed", "Essential business and economic news for the global economy", "web"),
    ],
    ("business", "Industry Analysis"), [
        ("Not Boring", "https://notboring.co/feed", "Deep dives into interesting companies and industry trends", "substack"),
    ],
    ("business", "Startups & VC"), [
        ("Newcomer", "https://newcomer.co/feed", "Scoops and analysis from the world of venture capital", "substack"),
    ],
    ("cryptocurrency & web3", "Crypto News"), [
        ("The Defiant", "https://thedefiant.io/feed", "DeFi and crypto news, analysis, and education", "web"),
    ],
    ("entertainment", "Streaming"), [
        ("Cord Cutter News", "https://cordcuttersnews.com/feed/", "Streaming service news, reviews, and cord-cutting guides", "web"),
    ],
    ("entrepreneurship & startups", "Incubators & Accelerators"), [
        ("Techstars Insights", "https://www.techstars.com/blog/feed", "News and insights from Techstars accelerator programs", "web"),
    ],
    ("entrepreneurship & startups", "Product Management"), [
        ("Department of Product", "https://departmentofproduct.substack.com/feed", "Product management strategies and career growth advice", "substack"),
    ],
    ("entrepreneurship & startups", "Venture Capital"), [
        ("StrictlyVC", "https://www.strictlyvc.com/feed/", "Daily venture capital and startup news", "web"),
        ("AVC", "https://avc.com/feed/", "Fred Wilson on venture capital and tech insights", "web"),
    ],
    ("environment & sustainability", "Climate Change"), [
        ("Drilled News", "https://drilled.media/feed", "Investigative climate journalism and accountability reporting", "web"),
        ("Heatmap News", "https://heatmap.news/feed", "News and analysis about climate change, energy, and sustainability", "web"),
    ],
    ("food & cooking", "Baking"), [
        ("King Arthur Baking Blog", "https://www.kingarthurbaking.com/blog/feed", "Baking tips, recipes, and techniques", "web"),
        ("Bake from Scratch", "https://bakefromscratch.com/feed/", "Artisan baking recipes and inspiration", "web"),
    ],
    ("food & cooking", "Comfort Food"), [
        ("Smitten Kitchen", "https://smittenkitchen.com/feed/", "Comfort food recipes from a tiny NYC kitchen", "web"),
    ],
    ("food & cooking", "International Cuisine"), [
        ("Woks of Life", "https://thewoksoflife.com/feed/", "Authentic Chinese and Asian recipes from a family kitchen", "web"),
    ],
    ("food & cooking", "Recipe Collections"), [
        ("Budget Bytes", "https://www.budgetbytes.com/feed/", "Delicious recipes that won't break the budget", "web"),
        ("Half Baked Harvest", "https://www.halfbakedharvest.com/feed/", "Creative comfort food recipes with a healthy twist", "web"),
    ],
    ("gaming", "Indie Gaming"), [
        ("Indie Game Digest", "https://indiegamedigest.substack.com/feed", "Reviews and previews of indie games and hidden gems", "substack"),
    ],
    ("health & fitness", "Diet & Nutrition"), [
        ("Examine Research Digest", "https://examine.com/blog/feed/", "Evidence-based nutrition and supplement information", "web"),
        ("Precision Nutrition Blog", "https://www.precisionnutrition.com/feed", "Science-based nutrition coaching advice", "web"),
    ],
    ("health & fitness", "Running & Endurance"), [
        ("Outside Run", "https://www.outsideonline.com/run/feed/", "Running news, training tips, and race coverage", "web"),
    ],
    ("lifestyle", "Luxury Lifestyle"), [
        ("Robb Report", "https://robbreport.com/feed/", "The definitive voice of the luxury lifestyle", "web"),
        ("Monocle Magazine", "https://monocle.com/feed/", "Global briefing on affairs, business, culture, and design", "web"),
    ],
    ("news & politics", "Investigative"), [
        ("ProPublica", "https://feeds.propublica.org/propublica/main", "Nonprofit investigative journalism in the public interest", "web"),
        ("The Intercept", "https://theintercept.com/feed/?rss", "Investigative journalism on politics, war, and surveillance", "web"),
    ],
    ("news & politics", "National News"), [
        ("Puck News", "https://puck.news/feed/", "Inside scoops on power, money, and ego from insiders", "web"),
        ("Axios AM/PM", "https://www.axios.com/feeds/feed.rss", "Smart brevity news on politics, tech, business, and media", "web"),
    ],
    ("news & politics", "Opinion & Editorials"), [
        ("Persuasion", "https://www.persuasion.community/feed", "Forum for diverse ideas and spirited debate on politics", "substack"),
        ("The Contrarian", "https://thecontrarian.substack.com/feed", "Skeptical takes on politics and culture from Nelson Lund", "substack"),
    ],
    ("news & politics", "Policy Analysis"), [
        ("Full Stack Economics", "https://fullstackeconomics.com/feed", "Deep policy analysis on economics, tech, and regulation", "substack"),
    ],
    ("parenting", "Parenting Advice"), [
        ("Parent Data", "https://parentdata.org/feed", "Data-driven parenting from economist Emily Oster", "substack"),
    ],
    ("photography", "Photography News"), [
        ("PetaPixel", "https://petapixel.com/feed/", "Photography news, camera reviews, and tips", "web"),
    ],
    ("sports", "Football"), [
        ("The Athletic NFL", "https://theathletic.com/feeds/rss/news/?tag_id=5", "In-depth NFL coverage from The Athletic", "web"),
        ("Football Outsiders", "https://www.footballoutsiders.com/rss.xml", "Analytical football coverage with advanced stats", "web"),
    ],
    ("technology", "Cybersecurity"), [
        ("Risky Business News", "https://riskybiznews.substack.com/feed", "Cybersecurity news for security professionals", "substack"),
    ],
    ("technology", "Startups"), [
        ("Equity Newsletter", "https://techcrunch.com/tag/equity-podcast/feed/", "Weekly startup and VC news from TechCrunch", "web"),
    ],

    # ── final fixes for last 3 gaps ──────────────
    ("entrepreneurship & startups", "Incubators & Accelerators"), [
        ("500 Global Insights", "https://500.co/blog/feed", "Startup and accelerator insights from 500 Global", "web"),
    ],
    ("entrepreneurship & startups", "Product Management"), [
        ("Product Habits", "https://producthabits.substack.com/feed", "Weekly product management insights and case studies", "substack"),
    ],
    ("news & politics", "Opinion & Editorials"), [
        ("The Bulwark Newsletter", "https://www.thebulwark.com/feed/", "Center-right political analysis and opinion", "web"),
    ],
]
# fmt: on


def _build_merged_dict():
    """Merge duplicate keys from _NEWSLETTERS_RAW into a single dict."""
    merged = {}
    it = iter(_NEWSLETTERS_RAW)
    for item in it:
        if isinstance(item, tuple) and len(item) == 2 and isinstance(item[0], str):
            names = next(it)
            merged.setdefault(item, []).extend(names)
    return merged


NEWSLETTERS_TO_ADD = _build_merged_dict()


class Command(BaseCommand):
    help = "Add real newsletters to popular_feeds.json to fill category/subcategory gaps"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
        parser.add_argument("--verbose", action="store_true", help="Show each addition")

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        verbose = options["verbose"]

        fixture_path = os.path.normpath(FIXTURE_PATH)
        with open(fixture_path, "r") as f:
            all_feeds = json.load(f)

        # Index existing newsletter feeds by normalized URL
        existing_urls = set()
        for feed in all_feeds:
            if feed.get("feed_type") == "newsletter":
                existing_urls.add(feed["feed_url"].lower())

        # Count current state
        newsletter_feeds = [f for f in all_feeds if f.get("feed_type") == "newsletter"]
        cat_counts = Counter(f["category"] for f in newsletter_feeds)
        subcat_counts = Counter((f["category"], f["subcategory"]) for f in newsletter_feeds)

        self.stdout.write(f"Current state: {len(newsletter_feeds)} newsletter feeds across {len(cat_counts)} categories")

        # Track what we'll add
        added = 0
        skipped_dup = 0
        new_entries = []

        for (category, subcategory), newsletters in NEWSLETTERS_TO_ADD.items():
            for title, feed_url, description, platform in newsletters:
                if feed_url.lower() in existing_urls:
                    skipped_dup += 1
                    if verbose:
                        self.stdout.write(f"  SKIP (exists): {title} -> {category}/{subcategory}")
                    continue

                entry = {
                    "feed_type": "newsletter",
                    "category": category,
                    "subcategory": subcategory,
                    "title": title,
                    "description": description,
                    "feed_url": feed_url,
                    "subscriber_count": 0,
                    "platform": platform,
                    "thumbnail_url": "",
                }
                new_entries.append(entry)
                existing_urls.add(feed_url.lower())
                added += 1

                if verbose:
                    self.stdout.write(f"  ADD: {title} -> {category}/{subcategory}")

        self.stdout.write(f"\nWill add {added} new entries ({skipped_dup} skipped as duplicates)")

        if dry_run:
            self._print_gap_analysis(newsletter_feeds + new_entries)
            return

        # Add and sort
        all_feeds.extend(new_entries)

        # Sort newsletter feeds within the file: by category, subcategory, subscriber_count desc
        non_newsletter = [f for f in all_feeds if f.get("feed_type") != "newsletter"]
        newsletter_updated = [f for f in all_feeds if f.get("feed_type") == "newsletter"]
        newsletter_updated.sort(key=lambda f: (f["category"], f["subcategory"], -f.get("subscriber_count", 0)))

        all_feeds_out = non_newsletter + newsletter_updated

        with open(fixture_path, "w") as f:
            json.dump(all_feeds_out, f, indent=2)

        self.stdout.write(self.style.SUCCESS(f"\nWrote {len(all_feeds_out)} total feeds to {fixture_path}"))
        self._print_gap_analysis(newsletter_updated)

    def _print_gap_analysis(self, newsletter_feeds):
        """Print analysis of remaining gaps."""
        cat_counts = Counter(f["category"] for f in newsletter_feeds)
        subcat_counts = defaultdict(lambda: defaultdict(int))
        for f in newsletter_feeds:
            subcat_counts[f["category"]][f["subcategory"]] += 1

        cats_under = [(cat, count) for cat, count in cat_counts.items() if count < MIN_CATEGORY_COUNT]
        subcats_under = []
        for cat, subs in subcat_counts.items():
            for sub, count in subs.items():
                if count < MIN_SUBCATEGORY_COUNT:
                    subcats_under.append((cat, sub, count))

        if cats_under:
            self.stdout.write(self.style.WARNING(f"\nCategories still under {MIN_CATEGORY_COUNT}:"))
            for cat, count in sorted(cats_under, key=lambda x: x[1]):
                self.stdout.write(f"  {cat}: {count}")
        else:
            self.stdout.write(self.style.SUCCESS(f"\nAll categories have {MIN_CATEGORY_COUNT}+ newsletters"))

        if subcats_under:
            self.stdout.write(self.style.WARNING(f"\nSubcategories still under {MIN_SUBCATEGORY_COUNT}:"))
            for cat, sub, count in sorted(subcats_under):
                self.stdout.write(f"  {cat}/{sub}: {count}")
        else:
            self.stdout.write(self.style.SUCCESS(f"All subcategories have {MIN_SUBCATEGORY_COUNT}+ newsletters"))
