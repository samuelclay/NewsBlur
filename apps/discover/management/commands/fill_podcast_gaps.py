"""
One-off script to add real podcasts to popular_feeds.json to fill category/subcategory gaps.
Every category must have 12+ podcasts, every subcategory must have 3+.

Usage:
    python manage.py fill_podcast_gaps
    python manage.py fill_podcast_gaps --dry-run
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
# Mapping: (category, subcategory) -> list of (title, feed_url, description) tuples
_PODCASTS_RAW = [
    # ── agriculture ───────────────────────────────────────────────────
    ("agriculture", "Agribusiness"), [
        ("Farm4Profit Podcast", "https://feeds.simplecast.com/NQG_ZnDw", "by Farm4Profit (Agribusiness)"),
        ("Accelerate Your Business Growth", "https://feeds.megaphone.fm/accelerateyourbusinessgrowth", "by Accelerate (Agribusiness)"),
        ("No Farms No Future", "https://feeds.simplecast.com/qbkZ26D6", "by Heritage Radio (Farm Advocacy)"),
    ],
    ("agriculture", "Crop Science"), [
        ("Red Dirt Agronomy Podcast", "https://feeds.simplecast.com/AQllSKYv", "by OSU Extension (Agronomy)"),
        ("Growing For Market Podcast", "https://feeds.simplecast.com/nlt5gqze", "by Growing for Market (Market Gardening)"),
        ("The Soil Network", "https://feeds.buzzsprout.com/2290973.rss", "by The Soil Network (Soil Science)"),
    ],
    ("agriculture", "Farm Technology"), [
        ("Successful Farming Podcast", "https://feeds.megaphone.fm/successful-farming-podcast", "by Meredith (Farm Technology)"),
        ("Growing the Future", "https://feeds.simplecast.com/16VlWkQN", "by Growing the Future (AgTech)"),
        ("Fields", "https://feeds.simplecast.com/nGS_Z3I1", "by Fields (Controlled Environment Ag)"),
    ],
    ("agriculture", "Farming"), [
        ("Kick'N Dirt with Mike and Adam", "https://feeds.simplecast.com/00_ivvIz", "by Mike and Adam (Agronomy)"),
        ("The Curious Farmer", "https://feeds.simplecast.com/xbbeZiAX", "by The Curious Farmer (Sustainable Farming)"),
    ],
    ("agriculture", "Livestock"), [
        ("American FarmSteadHers", "https://feeds.simplecast.com/UriTemsv", "by FarmSteadHers (Homesteading)"),
        ("The Farmer's Share", "https://feeds.buzzsprout.com/747263.rss", "by The Farmer's Share (Diversified Farms)"),
        ("Meet the Farmers", "https://feeds.simplecast.com/_prBUzUi", "by Meet the Farmers (Farm Profiles)"),
    ],
    ("agriculture", "Organic Farming"), [
        ("The Dirt on Organic Farming", "https://feeds.buzzsprout.com/1582189.rss", "by The Dirt (Organic Farming)"),
        ("Real Organic Podcast", "https://feeds.buzzsprout.com/1802657.rss", "by Real Organic Project (Certification)"),
        ("Fresh Take", "https://feeds.buzzsprout.com/491938.rss", "by Florida Organic Growers (Organic Living)"),
    ],
    ("agriculture", "Permaculture"), [
        ("Sense-Making in a Changing World", "https://feeds.buzzsprout.com/978904.rss", "by Permaculture Ecovillage (Permaculture)"),
        ("Greenhorns Radio", "https://feeds.simplecast.com/LPH1n6Ae", "by Greenhorns (Young Farmers)"),
        ("The Intellectual Agrarian", "https://feeds.simplecast.com/0Lz8SJXc", "by The Intellectual Agrarian (Farm Philosophy)"),
    ],
    ("agriculture", "Rural Life"), [
        ("Like a Farmer", "https://feeds.simplecast.com/YP1R_bhS", "by Like a Farmer (Rural Stories)"),
        ("Simple Farmhouse Life", "https://feeds.megaphone.fm/TNM1365824398", "by Simple Farmhouse Life (Homestead Living)"),
        ("Successful Farming Daily", "https://feeds.megaphone.fm/MERE9822574294", "by Meredith (Daily Farm News)"),
    ],
    ("agriculture", "Sustainable Agriculture"), [
        ("Young Farmers Podcast", "https://feeds.simplecast.com/4nc6tQ1F", "by National Young Farmers Coalition (Sustainability)"),
        ("Farming For Change", "https://feeds.buzzsprout.com/1815422.rss", "by Nuffield Scholars (Regenerative Farming)"),
        ("Keeping It Green", "https://feeds.buzzsprout.com/2096471.rss", "by Keeping It Green (Urban Green Spaces)"),
    ],
    ("agriculture", "Urban Farming"), [
        ("Garden Talk with Mr. Grow It", "https://feeds.buzzsprout.com/1691170.rss", "by Mr. Grow It (Urban Gardening)"),
        ("Master My Garden Podcast", "https://feeds.buzzsprout.com/857398.rss", "by Master My Garden (Small Space Gardening)"),
        ("TILclimate", "https://feeds.simplecast.com/w5_4mil2", "by MIT (Climate and Agriculture)"),
    ],

    # ── culture & lifestyle ───────────────────────────────────────────
    ("culture & lifestyle", "Cultural Commentary"), [
        ("Slate Culture", "https://feeds.megaphone.fm/slatesculturegabfest", "by Slate (Cultural Commentary)"),
        ("Still Processing", "https://feeds.simplecast.com/YXhATe6k", "by NYT (Culture Criticism)"),
        ("Popcast", "https://feeds.simplecast.com/W1rB_kgL", "by NYT (Pop Culture Analysis)"),
    ],
    ("culture & lifestyle", "Cultural Events"), [
        ("Pop Culture Confidential", "https://feeds.megaphone.fm/popcultureconfidential", "by Christina Birro (Cultural Events)"),
        ("Entertainment Tonight", "https://feeds.megaphone.fm/CBS8759954582", "by CBS (Entertainment News)"),
        ("The Rest Is Entertainment", "https://feeds.megaphone.fm/GLT2052042801", "by Goalhanger (Entertainment)"),
    ],
    ("culture & lifestyle", "Cultural News"), [
        ("Culturally Relevant", "https://feeds.simplecast.com/em2BUWK0", "by David Chen (Cultural Analysis)"),
        ("Dear Culture", "https://feeds.simplecast.com/4tZm7tMT", "by theGrio (Black Culture)"),
    ],
    ("culture & lifestyle", "Cultural Traditions"), [
        ("Culture & Flavor", "https://feeds.simplecast.com/rLCPtP_1", "by Zella Palmer (Food and Culture)"),
        ("A Taste of the Past", "https://feeds.simplecast.com/D9RDEA3I", "by Heritage Radio (Food History)"),
        ("Our Common Nature", "https://feeds.simplecast.com/ErCmj16D", "by Our Common Nature (Cultural Landscapes)"),
    ],
    ("culture & lifestyle", "Diversity & Inclusion"), [
        ("Pod Save the People", "https://feeds.simplecast.com/JPrhAgky", "by DeRay Mckesson (Social Justice)"),
        ("Culture Kings", "https://feeds.simplecast.com/w5jNkCr8", "by Culture Kings (Diversity in Culture)"),
        ("Fashion Grunge Podcast", "https://feeds.simplecast.com/fpElf5eY", "by Fashion Grunge (Diversity in Culture)"),
    ],
    ("culture & lifestyle", "Etiquette"), [
        ("Wonderful!", "https://feeds.simplecast.com/w1teXNny", "by Griffin and Rachel McElroy (Good Things)"),
        ("Self-Helpless", "https://feeds.megaphone.fm/CTL4247736176", "by Self-Helpless (Personal Growth)"),
        ("Good Noticings", "https://feeds.megaphone.fm/HOOSWTABSGLOBALLLC7896801906", "by Good Noticings (Recommendations)"),
    ],
    ("culture & lifestyle", "Expat Life"), [
        ("The Big Travel Podcast", "https://feeds.megaphone.fm/AUDD9396950735", "by Lisa Francesca Nand (Travel Stories)"),
        ("This Week in Travel", "https://feeds.megaphone.fm/ADV5821609310", "by Amateur Traveler (World Travel)"),
        ("China in the World", "https://feeds.simplecast.com/WZ57mq5R", "by China in the World (International Perspectives)"),
    ],
    ("culture & lifestyle", "Lifestyle Design"), [
        ("The Positive Habits Podcast", "https://feeds.megaphone.fm/USVL2688019383", "by The Positive Habits (Wellbeing)"),
        ("Struggle Care", "https://feeds.megaphone.fm/struggle-care", "by KC Davis (Lifestyle and Sustainability)"),
        ("The Baller Lifestyle", "https://feeds.simplecast.com/62wVc5_5", "by Brian and Ed (Sports and Culture)"),
    ],
    ("culture & lifestyle", "Subcultures"), [
        ("Secretly Incredibly Fascinating", "https://feeds.simplecast.com/_WI4mhWl", "by Alex Schmidt (Hidden Histories)"),
        ("Bigmouth", "https://feeds.megaphone.fm/PMO4566174614", "by Bigmouth (Cultural Deep Dives)"),
        ("On the Media", "https://feeds.simplecast.com/o4jAFXaw", "by WNYC (Media and Culture)"),
    ],
    ("culture & lifestyle", "Youth Culture"), [
        ("Youth Culture Matters", "https://feeds.simplecast.com/5C74FWF4", "by CPYU (Youth Culture)"),
        ("TLDR", "https://feeds.simplecast.com/kTaa50af", "by TLDR (Internet Culture)"),
        ("SmartLess", "https://feeds.simplecast.com/hNaFxXpO", "by Bateman, Arnett, Hayes (Culture and Comedy)"),
    ],

    # ── arts & culture ────────────────────────────────────────────────
    ("arts & culture", "Architecture"), [
        ("New Books in Architecture", "https://feeds.megaphone.fm/LIT5569218006", "by New Books Network (Architecture)"),
        ("Imagine a Place", "https://feeds.simplecast.com/lUXzJ3h1", "by Imagine a Place (Design and Space)"),
    ],
    ("arts & culture", "Art & Cultural History"), [
        ("ArtCurious Podcast", "https://feeds.megaphone.fm/artcuriouspodcast", "by Jennifer Dasal (Art History)"),
        ("History of Everything", "https://feeds.megaphone.fm/ARML4849414777", "by History of Everything (Cultural History)"),
    ],
    ("arts & culture", "Audio Art"), [
        ("Creative Pep Talk", "https://feeds.megaphone.fm/TPG2212080179", "by Andy J. Pizza (Creative Practice)"),
        ("Talkhouse Podcast", "https://feeds.megaphone.fm/THI1720663445", "by Talkhouse (Music and Art)"),
    ],
    ("arts & culture", "Design Inspiration"), [
        ("Design Better", "https://feeds.megaphone.fm/designbetter", "by InVision (Design Process)"),
        ("Design Freaks", "https://feeds.megaphone.fm/AASII2610978857", "by Design Freaks (Design Culture)"),
    ],
    ("arts & culture", "Street Style"), [
        ("Style-ish", "https://feeds.megaphone.fm/ASEMS7120192725", "by Style-ish (Fashion and Style)"),
        ("Fashion People", "https://feeds.megaphone.fm/fashion-people", "by Puck (Fashion Industry)"),
    ],

    # ── books & reading ───────────────────────────────────────────────
    ("books & reading", "Book Clubs"), [
        ("Book Lounge by Libby", "https://feeds.megaphone.fm/probooknerds", "by OverDrive (Book Club Discussions)"),
        ("Book Talk for BookTok", "https://feeds.megaphone.fm/booktok", "by Jac and Amy (Literary Analysis)"),
    ],
    ("books & reading", "Book Summaries"), [
        ("Close Readings", "https://feeds.megaphone.fm/LRB7524563961", "by London Review of Books (Literary Analysis)"),
        ("Bibliophage", "https://feeds.megaphone.fm/ARML7747340747", "by Bibliophage (Book Reviews)"),
    ],
    ("books & reading", "New Releases"), [
        ("First Edition", "https://feeds.megaphone.fm/first-edition", "by First Edition (New Book Releases)"),
    ],
    ("books & reading", "Philosophy Literature"), [
        ("New Books in Philosophy", "https://feeds.megaphone.fm/LIT5569218006", "by New Books Network (Philosophy)"),
        ("The University of Chicago Press Podcast", "https://feeds.megaphone.fm/NBNK7051800991", "by U Chicago Press (Scholarly Works)"),
    ],

    # ── business ──────────────────────────────────────────────────────
    ("business", "Banking & Fintech"), [
        ("Fintech Insider Podcast", "https://feeds.megaphone.fm/FS9665566819", "by 11:FS (Fintech)"),
        ("Fintech Takes", "https://feeds.megaphone.fm/fintech-takes", "by Fintech Takes (Banking Innovation)"),
    ],
    ("business", "Communication"), [
        ("Leadership Next", "https://feeds.megaphone.fm/fortuneleadershipnext", "by Fortune (Business Leadership)"),
        ("New Books in Communications", "https://feeds.megaphone.fm/LIT1384621729", "by New Books Network (Communications)"),
    ],
    ("business", "Compliance & Regulation"), [
        ("Counterfactual", "https://feeds.simplecast.com/5g5crQXS", "by Counterfactual (Regulatory Compliance)"),
        ("Tech Policy Podcast", "https://feeds.simplecast.com/WSi6AvnS", "by TechFreedom (Tech Regulation)"),
    ],
    ("business", "Cybersecurity"), [
        ("CyberWire Daily", "https://feeds.megaphone.fm/cyberwire-daily-podcast", "by N2K (Cybersecurity News)"),
        ("Information Security Podcast", "https://feeds.megaphone.fm/infosecurity", "by Infosecurity (Security News)"),
    ],
    ("business", "Financial Planning"), [
        ("Everyone's Talkin' Money", "https://feeds.megaphone.fm/GLSS5589020627", "by Shannah Game (Personal Finance)"),
        ("Your Money Guide on the Side", "https://feeds.megaphone.fm/TCL9866893823", "by Tyler Gardner (Finance)"),
    ],
    ("business", "Fundraising"), [
        ("Funded, Now What?!", "https://feeds.megaphone.fm/fundednowwhat", "by Funded (Startup Growth)"),
        ("FoundersPlace.co Podcast", "https://feeds.megaphone.fm/foundersplace", "by FoundersPlace (Scaling)"),
    ],
    ("business", "Health & Safety"), [
        ("Faces of Digital Health", "https://feeds.megaphone.fm/faces-of-digital-health", "by Faces of Digital Health (Health Tech)"),
        ("Hey Doc, Quick Question", "https://feeds.megaphone.fm/hey-doc-quick-question", "by Dr. Jeremy Alland (Health)"),
    ],
    ("business", "Investigations"), [
        ("Reliable Sources", "https://feeds.megaphone.fm/WMHY5881004439", "by CNN (Media Investigations)"),
    ],
    ("business", "Policy Analysis"), [
        ("PolicyCast", "https://feeds.simplecast.com/8W_aZ33f", "by Harvard Kennedy School (Policy)"),
        ("POLITICO Energy", "https://feeds.simplecast.com/kc0taSm4", "by POLITICO (Energy Policy)"),
    ],
    ("business", "Sustainability"), [
        ("The Circular Economy Show", "https://feeds.simplecast.com/A_3pA_aW", "by Ellen MacArthur Foundation (Sustainability)"),
    ],

    # ── design ────────────────────────────────────────────────────────
    ("design", "Game Design"), [
        ("Game Dev Advice", "https://feeds.megaphone.fm/gamedevadvice", "by Game Dev Advice (Game Development)"),
        ("The GamesIndustry.biz Microcast", "https://feeds.megaphone.fm/GNL9258609799", "by GamesIndustry.biz (Game Industry)"),
    ],
    ("design", "Product Management"), [
        ("Problem Solvers", "https://feeds.megaphone.fm/ARML8107338306", "by Entrepreneur (Product & Growth)"),
        ("Go Slow to Grow Fast", "https://feeds.megaphone.fm/goslowtogrowfast", "by Go Slow (Enterprise AI)"),
    ],
    ("design", "Typography"), [
        ("New Books in Language", "https://feeds.megaphone.fm/LIT7632558716", "by New Books Network (Language and Type)"),
    ],
    ("design", "Urban Living"), [
        ("Imagine a Place", "https://feeds.simplecast.com/lUXzJ3h1", "by Imagine a Place (Urban Design)"),
    ],

    # ── education ─────────────────────────────────────────────────────
    ("education", "Environmental Science"), [
        ("TILclimate", "https://feeds.simplecast.com/w5_4mil2", "by MIT (Climate Science Education)"),
        ("Living on Earth", "https://feeds.megaphone.fm/livingonearth", "by PRI (Environmental News)"),
    ],
    ("education", "History"), [
        ("UnTextbooked", "https://feeds.megaphone.fm/PDP7706621726", "by UnTextbooked (History for Students)"),
        ("The Past and The Curious", "https://feeds.megaphone.fm/ARML5717012507", "by The Past and The Curious (History for Families)"),
    ],
    ("education", "Learning Disorders"), [
        ("New Books in Neuroscience", "https://feeds.megaphone.fm/newbooksinneuroscience", "by New Books Network (Neuroscience)"),
        ("Braincare", "https://feeds.megaphone.fm/SLO2825964056", "by Adrienne Herbert (Brain Health)"),
    ],
    ("education", "Liberal Arts"), [
        ("New Books in Intellectual History", "https://feeds.megaphone.fm/LIT3169108505", "by New Books Network (Intellectual History)"),
        ("Let's Learn Everything!", "https://feeds.simplecast.com/2pvdZXa_", "by Let's Learn Everything (Science and Culture)"),
    ],
    ("education", "Policy Analysis"), [
        ("Not Another Politics Podcast", "https://feeds.simplecast.com/rbyWPhvm", "by U Chicago (Political Science)"),
    ],
    ("education", "Publishing Industry"), [
        ("Off the Page", "https://feeds.megaphone.fm/NBN2998548382", "by Columbia University Press (Publishing)"),
        ("New Books in Library Science", "https://feeds.megaphone.fm/NBN1152836190", "by New Books Network (Library Science)"),
    ],

    # ── entertainment ─────────────────────────────────────────────────
    ("entertainment", "Award Shows"), [
        ("The Awardist", "https://feeds.megaphone.fm/the-awardist", "by EW (Awards Coverage)"),
    ],
    ("entertainment", "Concert Tours"), [
        ("Pop Shop Podcast", "https://feeds.megaphone.fm/PMC1900238962", "by Billboard (Music and Tours)"),
        ("Talkhouse Podcast", "https://feeds.megaphone.fm/THI1720663445", "by Talkhouse (Music and Artists)"),
    ],
    ("entertainment", "Entertainment Humor"), [
        ("Good One", "https://feeds.megaphone.fm/VMP8521265258", "by Vulture (Comedy Interviews)"),
        ("Good Noticings", "https://feeds.megaphone.fm/HOOSWTABSGLOBALLLC7896801906", "by Good Noticings (Comedy)"),
    ],
    ("entertainment", "Holiday"), [
        ("Waiting For October", "https://feeds.megaphone.fm/waitingforoctober", "by Waiting For October (Horror and Holidays)"),
        ("Kermode & Mayo's Take", "https://feeds.megaphone.fm/kermodeandmayo", "by Kermode & Mayo (Film and Holiday)"),
    ],
    ("entertainment", "Paranormal"), [
        ("The Paranormal Podcast", "https://feeds.megaphone.fm/JIMHAROLDMEDIALLC5311493271", "by Jim Harold (Paranormal)"),
        ("Unexplained Mysteries", "https://feeds.megaphone.fm/END9329892371", "by Parcast (Mysteries)"),
    ],
    ("entertainment", "TV & Film"), [
        ("The Next Best Picture Podcast", "https://feeds.megaphone.fm/nextbestpicture", "by Next Best Picture (Film Reviews)"),
        ("Love to See It", "https://feeds.megaphone.fm/love-to-see-it", "by Emma and Claire (Reality TV and Film)"),
    ],

    # ── entrepreneurship & startups ───────────────────────────────────
    ("entrepreneurship & startups", "Incubators & Accelerators"), [
        ("The Startup Operator", "https://feeds.megaphone.fm/ISP5832393577", "by The Startup Operator (Startup Ecosystem)"),
        ("Finding Founders", "https://feeds.megaphone.fm/HS1673208977", "by Finding Founders (Entrepreneurship)"),
    ],
    ("entrepreneurship & startups", "Leadership"), [
        ("Founder's Journal", "https://feeds.megaphone.fm/founders-journal", "by Morning Brew (Startup Leadership)"),
        ("The Entrepreneurial You", "https://feeds.megaphone.fm/theentrepreneurialyou", "by Heneka Watkis-Porter (Entrepreneurship)"),
    ],
    ("entrepreneurship & startups", "Startups"), [
        ("Business Is Boring", "https://feeds.megaphone.fm/business-is-boring", "by The Spinoff (Startup Culture)"),
    ],

    # ── environment & sustainability ──────────────────────────────────
    ("environment & sustainability", "Sustainable Fashion"), [
        ("Dressed: The History of Fashion", "https://feeds.megaphone.fm/ARML9655034287", "by iHeart (Fashion History and Sustainability)"),
        ("The Glossy Podcast", "https://feeds.megaphone.fm/DIGI4036367252", "by Glossy (Fashion Industry)"),
        ("Political Climate", "https://feeds.megaphone.fm/PSMI4986994512", "by Boundary Stone (Climate Policy)"),
    ],

    # ── fashion & beauty ──────────────────────────────────────────────
    ("fashion & beauty", "Fashion History"), [
        ("Dressed: The History of Fashion", "https://feeds.megaphone.fm/ARML9655034287", "by iHeart (Fashion History)"),
        ("Fad Camp", "https://feeds.megaphone.fm/PODS2666006651", "by Fad Camp (Fashion Brands)"),
    ],
    ("fashion & beauty", "Luxury Lifestyle"), [
        ("The Glossy Beauty Podcast", "https://feeds.megaphone.fm/DIGI3794372059", "by Glossy (Beauty Industry)"),
    ],

    # ── finance ───────────────────────────────────────────────────────
    ("finance", "Crypto Trading"), [
        ("The Crypto Beat", "https://feeds.megaphone.fm/cryptobeat", "by The Crypto Beat (Crypto Markets)"),
        ("The Scoop", "https://feeds.megaphone.fm/theblock-thescoop", "by The Block (Crypto and Finance)"),
    ],
    ("finance", "Wealth Management"), [
        ("Real Vision: Finance & Investing", "https://feeds.megaphone.fm/realvision", "by Real Vision (Investing)"),
        ("Ask The Compound", "https://feeds.megaphone.fm/TCP8609172956", "by The Compound (Personal Finance)"),
    ],

    # ── food & cooking ────────────────────────────────────────────────
    ("food & cooking", "Food & Beverage Pairing"), [
        ("Somm Of Our Thoughts", "https://feeds.megaphone.fm/ROMN1864371917", "by Sarah and Carter (Wine and Food)"),
        ("Gastropod", "https://feeds.megaphone.fm/VMP6255701211", "by Gastropod (Food Science)"),
    ],
    ("food & cooking", "Food Recommendations"), [
        ("This Is TASTE", "https://feeds.megaphone.fm/this-is-taste", "by This Is TASTE (Restaurant Culture)"),
        ("Dudes Behind the Foods", "https://feeds.megaphone.fm/dudesbehindthefoods", "by Tim and David (Food Recommendations)"),
    ],

    # ── gaming ────────────────────────────────────────────────────────
    ("gaming", "Fantasy Sports"), [
        ("The Ringer Fantasy Football Show", "https://feeds.megaphone.fm/ringer-fantasy-football-show", "by The Ringer (Fantasy Football)"),
        ("Fantasy Footballers", "https://feeds.megaphone.fm/fantasy-football", "by Fantasy Footballers (Fantasy Football)"),
    ],
    ("gaming", "Game History"), [
        ("Retro Handhelds Podcast", "https://feeds.simplecast.com/giehDFBk", "by Retro Handhelds (Retro Gaming)"),
        ("Get Played", "https://feeds.simplecast.com/afafh2s6", "by Headgum (Gaming History)"),
    ],
    ("gaming", "Streaming"), [
        ("Triple Click", "https://feeds.simplecast.com/6WD3bDj7", "by Maximum Fun (Gaming and Culture)"),
        ("Game Scoop!", "https://feeds.megaphone.fm/gamescoop", "by IGN (Gaming News)"),
    ],

    # ── health & fitness ──────────────────────────────────────────────
    ("health & fitness", "Alternative Medicine"), [
        ("The mindbodygreen Podcast", "https://feeds.megaphone.fm/the-mindbodygreen-podcast", "by mindbodygreen (Integrative Health)"),
    ],
    ("health & fitness", "Biohacking"), [
        ("More Plates More Dates", "https://feeds.megaphone.fm/moreplatesmoredates", "by Derek (Biohacking and Fitness)"),
    ],
    ("health & fitness", "Children's Health"), [
        ("Sleep Tight Science", "https://feeds.megaphone.fm/STM6538419032", "by Sleep Tight (Children's Science)"),
        ("Sleep Tight Relax", "https://feeds.megaphone.fm/STM2497856452", "by Sleep Tight (Children's Health)"),
    ],
    ("health & fitness", "Chronic Illness"), [
        ("Optimize Your Life", "https://feeds.simplecast.com/rjgYRX76", "by Optimize Your Life (Chronic Illness)"),
    ],
    ("health & fitness", "Fitness Challenges"), [
        ("All About Fitness", "https://feeds.megaphone.fm/GLSS7691437417", "by All About Fitness (Fitness Tips)"),
        ("The Fitness And Lifestyle Podcast", "https://feeds.megaphone.fm/EYYNN2011752632", "by Fitness And Lifestyle (Training)"),
    ],
    ("health & fitness", "Home Workouts"), [
        ("Optimal Health Daily", "https://feeds.megaphone.fm/OLD4549284412", "by Optimal Health Daily (Fitness)"),
    ],
    ("health & fitness", "Sleep Health"), [
        ("Pursuit of Wellness", "https://feeds.megaphone.fm/SSM3257074871", "by Pursuit of Wellness (Sleep and Health)"),
        ("Health Hacker Life", "https://feeds.simplecast.com/suW29orW", "by TJ Anderson (Biohacking and Sleep)"),
    ],
    ("health & fitness", "Sports Recovery"), [
        ("Perform with Dr. Andy Galpin", "https://feeds.megaphone.fm/perform", "by Andy Galpin (Performance Science)"),
    ],
    ("health & fitness", "Supplements & Vitamins"), [
        ("Body Unboxed", "https://feeds.megaphone.fm/bodyunboxed", "by Body Unboxed (Supplements)"),
    ],
    ("health & fitness", "Women's Health"), [
        ("Take Back Your Health", "https://feeds.megaphone.fm/UYIIU7691408603", "by Dr. Amy Myers (Women's Health)"),
    ],

    # ── history ───────────────────────────────────────────────────────
    ("history", "African History"), [
        ("UnTextbooked", "https://feeds.megaphone.fm/PDP7706621726", "by UnTextbooked (Diverse History)"),
        ("Dig: A History Podcast", "https://feeds.megaphone.fm/ADL4220248200", "by Dig (World History)"),
    ],
    ("history", "Ancient & Medieval"), [
        ("New Books in Medieval History", "https://feeds.megaphone.fm/nbn6213996495", "by New Books Network (Medieval)"),
    ],
    ("history", "Asian History"), [
        ("The China History Podcast", "https://feeds.megaphone.fm/TNM3605642123", "by Laszlo Montgomery (Chinese History)"),
        ("China in the World", "https://feeds.simplecast.com/WZ57mq5R", "by China in the World (Asian Geopolitics)"),
    ],
    ("history", "Cold War & Modern Era"), [
        ("Cold War Conversations Podcast", "https://feeds.megaphone.fm/NSR5326520675", "by Cold War Conversations (Cold War)"),
    ],
    ("history", "European History"), [
        ("The Rest Is History", "https://feeds.megaphone.fm/GLT4787413333", "by Tom Holland and Dominic Sandbrook (History)"),
    ],
    ("history", "Latin American History"), [
        ("Latin America in Focus", "https://feeds.simplecast.com/_DUdLkxj", "by AS/COA (Latin America)"),
        ("Unknown History with Giles Milton", "https://feeds.simplecast.com/RXNO_2Ro", "by Giles Milton (World History)"),
    ],
    ("history", "Middle Eastern History"), [
        ("The Trialogue", "https://feeds.simplecast.com/fyrs5M9T", "by The Trialogue (International History)"),
        ("History Book Club", "https://feeds.megaphone.fm/IMP7553505016", "by Oliver Webb-Carter (World History)"),
    ],
    ("history", "Military History"), [
        ("The History of WWII Podcast", "https://feeds.megaphone.fm/history-of-world-war-ii", "by Ray Harris Jr. (WWII)"),
    ],
    ("history", "Oral History"), [
        ("Unsung History", "https://feeds.megaphone.fm/unsung-history", "by Unsung History (American History)"),
        ("History Extra podcast", "https://feeds.megaphone.fm/GLT5697813216", "by BBC (History Interviews)"),
    ],
    ("history", "Women in History"), [
        ("This is History: A Dynasty to Die For", "https://feeds.megaphone.fm/thisishistory", "by This is History (Dynasty History)"),
        ("The English Heritage Podcast", "https://feeds.megaphone.fm/EHE9742327131", "by English Heritage (Historic Buildings)"),
    ],

    # ── lifestyle ─────────────────────────────────────────────────────
    ("lifestyle", "Fashion Trends"), [
        ("Fashion People", "https://feeds.megaphone.fm/fashion-people", "by Puck (Fashion Industry)"),
    ],
    ("lifestyle", "Home Organization"), [
        ("Struggle Care", "https://feeds.megaphone.fm/struggle-care", "by KC Davis (Home Care)"),
        ("A Well-Designed Business", "https://feeds.megaphone.fm/awelldesignedbusiness", "by LuAnn Nigara (Interior Design)"),
    ],
    ("lifestyle", "Luxury Lifestyle"), [
        ("The Glossy Podcast", "https://feeds.megaphone.fm/DIGI4036367252", "by Glossy (Luxury Fashion)"),
    ],
    ("lifestyle", "Seasonal Living"), [
        ("The Curious History of Your Home", "https://feeds.megaphone.fm/thecurioushistoryofyourhome", "by The Curious History (Home History)"),
        ("Simple Farmhouse Life", "https://feeds.megaphone.fm/TNM1365824398", "by Simple Farmhouse Life (Seasonal Living)"),
    ],
    ("lifestyle", "Simple Living"), [
        ("The Intellectual Agrarian", "https://feeds.simplecast.com/0Lz8SJXc", "by The Intellectual Agrarian (Simple Living)"),
    ],
    ("lifestyle", "Social Etiquette"), [
        ("How We Made Your Mother", "https://feeds.megaphone.fm/hwmym", "by How We Made Your Mother (Social Stories)"),
        ("Multiamory", "https://feeds.megaphone.fm/multiamory", "by Multiamory (Relationship Skills)"),
    ],
    ("lifestyle", "Sustainable Fashion"), [
        ("Dressed: The History of Fashion", "https://feeds.megaphone.fm/ARML9655034287", "by iHeart (Fashion and Sustainability)"),
        ("Style-ish", "https://feeds.megaphone.fm/ASEMS7120192725", "by Style-ish (Fashion)"),
    ],
    ("lifestyle", "Urban Exploration"), [
        ("Overland Trail Guides Podcast", "https://feeds.simplecast.com/SDwEQhYI", "by Overland Trail Guides (Exploration)"),
        ("Wild Ideas Worth Living", "https://feeds.simplecast.com/pyeGnjub", "by REI (Adventure Living)"),
    ],

    # ── music ─────────────────────────────────────────────────────────
    ("music", "DJ Culture"), [
        ("We Love Hip Hop Network", "https://feeds.megaphone.fm/ATAUU8868595908", "by We Love Hip Hop (DJ Culture)"),
        ("Curious Creatures", "https://feeds.megaphone.fm/DEP3890429196", "by Curious Creatures (Music Culture)"),
    ],
    ("music", "Hip-Hop & Rap"), [
        ("Rap Latte", "https://feeds.megaphone.fm/DCP4073118839", "by Rap Latte (Hip-Hop)"),
    ],
    ("music", "Music News"), [
        ("Pop Shop Podcast", "https://feeds.megaphone.fm/PMC1900238962", "by Billboard (Music News)"),
    ],

    # ── news & politics ───────────────────────────────────────────────
    ("news & politics", "Campaign Finance"), [
        ("RealClearPolitics Podcast", "https://feeds.simplecast.com/pzzjlbXr", "by RealClearPolitics (Political Analysis)"),
    ],
    ("news & politics", "Congressional News"), [
        ("Washington Today", "https://feeds.megaphone.fm/cspanwashingtontoday", "by C-SPAN (Congressional News)"),
        ("CNN Political Briefing", "https://feeds.megaphone.fm/WMHY5084601129", "by CNN (Political News)"),
    ],
    ("news & politics", "Fact-Checking"), [
        ("On the Media", "https://feeds.simplecast.com/o4jAFXaw", "by WNYC (Media Criticism)"),
    ],
    ("news & politics", "First Amendment"), [
        ("Moderated Content", "https://feeds.simplecast.com/xQoaquAr", "by Moderated Content (Free Speech)"),
        ("Reliable Sources", "https://feeds.megaphone.fm/WMHY5881004439", "by CNN (Press Freedom)"),
    ],
    ("news & politics", "Immigration"), [
        ("CNN One Thing", "https://feeds.megaphone.fm/WMHY5177234123", "by CNN (News Deep Dives)"),
    ],
    ("news & politics", "Infrastructure"), [
        ("POLITICO Energy", "https://feeds.simplecast.com/kc0taSm4", "by POLITICO (Energy and Infrastructure)"),
    ],
    ("news & politics", "International Development"), [
        ("The DSR Daily", "https://feeds.megaphone.fm/TRGM2505689189", "by DSR (Foreign Policy)"),
        ("The Editors", "https://feeds.simplecast.com/bAMj0tiC", "by National Review (Policy)"),
    ],
    ("news & politics", "Lobbying"), [
        ("The Rest Is Politics", "https://feeds.megaphone.fm/GLT9190936013", "by Goalhanger (UK and World Politics)"),
        ("THE DAILY BLAST", "https://feeds.megaphone.fm/dailyblast2024", "by The New Republic (Political News)"),
    ],
    ("news & politics", "Media Criticism"), [
        ("Reliable Sources", "https://feeds.megaphone.fm/WMHY5881004439", "by CNN (Media Analysis)"),
    ],
    ("news & politics", "National Security"), [
        ("Talking Feds", "https://feeds.megaphone.fm/GEMINIMEDIA2127678588", "by Talking Feds (Legal and Security)"),
    ],
    ("news & politics", "Political Satire"), [
        ("The Daily Show: Ears Edition", "https://feeds.megaphone.fm/QCD2422844292", "by Comedy Central (Political Satire)"),
    ],
    ("news & politics", "Redistricting"), [
        ("PoliticsNation", "https://feeds.simplecast.com/apox7T5o", "by MSNBC (Voter Rights)"),
        ("Main Justice", "https://feeds.simplecast.com/qjknXbdF", "by Main Justice (Legal News)"),
    ],
    ("news & politics", "Supreme Court"), [
        ("Strict Scrutiny", "https://feeds.simplecast.com/EyrYWMW2", "by Strict Scrutiny (Supreme Court)"),
    ],
    ("news & politics", "Urban Policy"), [
        ("The LRB Podcast", "https://feeds.megaphone.fm/LRB9987052392", "by London Review of Books (Policy)"),
        ("Interesting Times with Ross Douthat", "https://feeds.simplecast.com/2xzUiHxw", "by NYT (Policy Analysis)"),
    ],
    ("news & politics", "Veterans Affairs"), [
        ("CNN 5 Things", "https://feeds.megaphone.fm/WMHY2007701094", "by CNN (Daily News Briefing)"),
        ("The Fox News Rundown", "https://feeds.megaphone.fm/FOXM1880458659", "by Fox News (News Analysis)"),
    ],
    ("news & politics", "Voter Rights"), [
        ("PoliticsNation", "https://feeds.simplecast.com/apox7T5o", "by Al Sharpton (Civil Rights)"),
    ],
    ("news & politics", "Whistleblowers"), [
        ("The McCarthy Report", "https://feeds.simplecast.com/l1ER8FMy", "by The McCarthy Report (Investigations)"),
        ("Face the Nation", "https://feeds.megaphone.fm/CBS2753513555", "by CBS (Political News)"),
    ],

    # ── parenting ─────────────────────────────────────────────────────
    ("parenting", "Adoption"), [
        ("That's Total Mom Sense", "https://feeds.megaphone.fm/total-mom-sense", "by Jessica Fein (Parenting and Adoption)"),
        ("Daddyhood", "https://feeds.megaphone.fm/daddyhood", "by Daddyhood (Fatherhood and Adoption)"),
    ],
    ("parenting", "Co-Parenting"), [
        ("Modern Mom Probs", "https://feeds.simplecast.com/lth1fPf8", "by Modern Mom Probs (Co-Parenting)"),
        ("Raising Parents with Emily Oster", "https://feeds.megaphone.fm/raisingparents", "by Emily Oster (Parenting)"),
    ],
    ("parenting", "Family Travel"), [
        ("Parental As Anything", "https://feeds.megaphone.fm/TECO1718782843", "by Maggie Dent (Parenting Advice)"),
    ],
    ("parenting", "Homeschooling"), [
        ("COURAGEOUS PARENTING", "https://feeds.simplecast.com/gNXrlpv4", "by Courageous Parenting (Homeschooling)"),
        ("Parenting Bytes", "https://feeds.simplecast.com/fgUkAfn4", "by Parenting Bytes (Digital Parenting)"),
    ],
    ("parenting", "Single Parenting"), [
        ("Home. Made.", "https://feeds.simplecast.com/ok27ng_6", "by Home. Made. (Single Parenting)"),
        ("Bad Parents", "https://feeds.megaphone.fm/CORU5331040092", "by Bad Parents (Parenting Humor)"),
    ],
    ("parenting", "Special Needs Parenting"), [
        ("Project Parenthood", "https://feeds.simplecast.com/98s4Kt5e", "by Dr. Nanika Coor (Respectful Parenting)"),
    ],
    ("parenting", "Teen Parenting"), [
        ("LC Parents Podcast", "https://feeds.simplecast.com/673YKa7v", "by LC Parents (Teen Parenting)"),
    ],

    # ── photography ───────────────────────────────────────────────────
    ("photography", "Camera Gear"), [
        ("I Love Photography", "https://feeds.simplecast.com/yraPcDo_", "by Fernando Gomes (Photography Gear)"),
    ],
    ("photography", "Concert Photography"), [
        ("Creatives Offscript", "https://feeds.simplecast.com/1XxFk493", "by Creatives Offscript (Creative Careers)"),
        ("Meet the Creatives", "https://feeds.simplecast.com/3JLCgTvn", "by Meet the Creatives (Creative Industry)"),
    ],
    ("photography", "Film Photography"), [
        ("A Small Voice", "https://feeds.simplecast.com/CYpT8Orp", "by Ben Smith (Photography Conversations)"),
        ("Well Made", "https://feeds.simplecast.com/4gqLEpr7", "by Well Made (Photography and Craft)"),
    ],
    ("photography", "Photo Tutorials"), [
        ("I Love Photography", "https://feeds.simplecast.com/yraPcDo_", "by Fernando Gomes (Photo Tutorials)"),
        ("A Small Voice", "https://feeds.simplecast.com/CYpT8Orp", "by Ben Smith (Photographer Interviews)"),
    ],
    ("photography", "Sports Photography"), [
        ("Raising Athletes", "https://feeds.simplecast.com/zqDdXcNr", "by Raising Athletes (Sports Culture)"),
        ("Creatives Offscript", "https://feeds.simplecast.com/1XxFk493", "by Creatives Offscript (Creative Pros)"),
    ],
    ("photography", "Street Photography"), [
        ("Well Made", "https://feeds.simplecast.com/4gqLEpr7", "by Well Made (Street and Documentary)"),
        ("UNNOTICED PODCAST", "https://feeds.simplecast.com/2OhG_OXy", "by Unnoticed (Visual Storytelling)"),
    ],
    ("photography", "Travel Photography"), [
        ("2 Guys 0 Planners", "https://feeds.simplecast.com/tIivNLb5", "by 2 Guys 0 Planners (Photo Travel)"),
        ("Yo! Podcast", "https://feeds.simplecast.com/krDXNg2G", "by Luke Beard (Photography and Design)"),
    ],
    ("photography", "Wildlife Photography"), [
        ("Wild Times: Wildlife Education", "https://feeds.megaphone.fm/WILDTIMESMEDIACOMPANY3643808408", "by Forrest Galante (Wildlife)"),
    ],

    # ── relationships & dating ────────────────────────────────────────
    ("relationships & dating", "Conflict Resolution"), [
        ("Multiamory", "https://feeds.megaphone.fm/multiamory", "by Multiamory (Relationship Skills)"),
        ("Relationship Advice", "https://feeds.megaphone.fm/EDGY4477967628", "by Relationship Advice (Conflict Skills)"),
    ],
    ("relationships & dating", "LGBTQ+ Relationships"), [
        ("Savage Love", "https://feeds.megaphone.fm/SLT6250292033", "by Dan Savage (LGBTQ+ Advice)"),
    ],
    ("relationships & dating", "Love & Commitment"), [
        ("This is Love", "https://feeds.megaphone.fm/VMP8871377602", "by Phoebe Judge (Love Stories)"),
    ],

    # ── science ───────────────────────────────────────────────────────
    ("science", "Forensic Science"), [
        ("Big Picture Science", "https://feeds.megaphone.fm/ADV9362943796", "by SETI (Science Topics)"),
    ],
    ("science", "Marine Biology"), [
        ("The Show About Science", "http://feeds.megaphone.fm/PPY6236814493", "by The Show About Science (Marine Biology)"),
    ],
    ("science", "Materials Science"), [
        ("New Books in Physics and Chemistry", "https://feeds.megaphone.fm/NBN9935590638", "by New Books Network (Materials Science)"),
        ("New Books in Science", "https://feeds.megaphone.fm/LIT2591788808", "by New Books Network (Science)"),
    ],
    ("science", "Scientific Discoveries"), [
        ("Science Magazine Podcast", "https://feeds.megaphone.fm/AAAS8717073854", "by AAAS (Science News)"),
    ],

    # ── sports ────────────────────────────────────────────────────────
    ("sports", "Coaching"), [
        ("The Athlete Development Show", "https://feeds.buzzsprout.com/699853.rss", "by The Athlete Development Show (Youth Coaching)"),
        ("Experts in Sport", "https://feeds.buzzsprout.com/411622.rss", "by Experts in Sport (Coaching Science)"),
    ],
    ("sports", "Disability Sports"), [
        ("TWS Sports Podcast", "https://feeds.megaphone.fm/COMG6772020996", "by TWS (Disability Sports)"),
        ("Hear Her Sports", "https://feeds.megaphone.fm/hearhersports", "by Hear Her Sports (Women in Sports)"),
    ],
    ("sports", "Doping & Ethics"), [
        ("Lamestream Sports", "https://feeds.megaphone.fm/lamestreamsports", "by Lamestream Sports (Sports Commentary)"),
        ("Play On Sports Show", "https://feeds.megaphone.fm/YOUKNOWMEDIA6862675081", "by Play On Sports (Sports Ethics)"),
    ],
    ("sports", "Draft & Transfers"), [
        ("Sporticast", "https://feeds.megaphone.fm/PMC3155742167", "by Sporticast (Sports Business)"),
        ("A to Z Sports Podcast Network", "https://feeds.megaphone.fm/ATZM8602892181", "by A to Z Sports (Sports News)"),
    ],
    ("sports", "Extreme Sports"), [
        ("Wild Ideas Worth Living", "https://feeds.simplecast.com/pyeGnjub", "by REI (Outdoor Adventure)"),
    ],
    ("sports", "High School Sports"), [
        ("The Athlete Development Show", "https://feeds.buzzsprout.com/699853.rss", "by Athlete Development (Youth Sports)"),
        ("STRIVE 365", "https://feeds.buzzsprout.com/2380305.rss", "by STRIVE 365 (Youth Athletics)"),
    ],
    ("sports", "Horse Racing"), [
        ("Sport of Kings Podcast", "https://feeds.simplecast.com/8ifzTs9z", "by Sport of Kings (Horse Racing)"),
        ("The Stride Report", "https://feeds.simplecast.com/3RexTd_I", "by The Stride Report (Racing Analysis)"),
    ],
    ("sports", "Lacrosse & Field Hockey"), [
        ("The Inside Feed", "https://feeds.megaphone.fm/theinsidefeed", "by The Inside Feed (Lacrosse)"),
        ("Respect Her Game", "https://feeds.megaphone.fm/NEWENGLANDSPORTSNETWORKLIMITEDPARTNERSHIP6214787683", "by NESN (Women's Lacrosse)"),
    ],
    ("sports", "Olympic Sports"), [
        ("The Podium", "https://feeds.simplecast.com/93BUSgMm", "by The Podium (Olympic Coverage)"),
    ],
    ("sports", "Referee & Umpire"), [
        ("The Soccer Coaching Podcast", "https://feeds.buzzsprout.com/247200.rss", "by Soccer Coaching (Soccer Officials)"),
        ("Go! My Favorite Sports Team", "https://feeds.megaphone.fm/gomyfavoritesportsteam", "by Go! (Sports Culture)"),
    ],
    ("sports", "Sports Betting"), [
        ("The Early Edge", "https://feeds.megaphone.fm/earlyedge", "by CBS (Sports Betting)"),
    ],
    ("sports", "Sports Fandom"), [
        ("The Favorites Sports Betting Podcast", "https://feeds.megaphone.fm/the-favorites", "by The Favorites (Sports Analysis)"),
    ],
    ("sports", "Sports Film & TV"), [
        ("The Ringer Fantasy Football Show", "https://feeds.megaphone.fm/ringer-fantasy-football-show", "by The Ringer (Sports Media)"),
        ("Thru the Ringer", "https://feeds.megaphone.fm/through-the-ringer", "by The Ringer (Sports Media)"),
    ],
    ("sports", "Track & Field"), [
        ("The Stride Report", "https://feeds.simplecast.com/3RexTd_I", "by The Stride Report (Track and Field)"),
        ("Talking Performance", "https://feeds.buzzsprout.com/1058914.rss", "by Talking Performance (Athletics)"),
    ],
    ("sports", "Water Sports"), [
        ("The Outdoors Station", "https://feeds.simplecast.com/3luJI3et", "by The Outdoors Station (Outdoor Sports)"),
        ("Outside Podcast", "https://feeds.megaphone.fm/POM5001301518", "by Outside Magazine (Adventure Sports)"),
    ],
    ("sports", "Winter Sports"), [
        ("The Hockey Think Tank Podcast", "https://feeds.megaphone.fm/BLU1778423086", "by Hockey Think Tank (Hockey and Winter Sports)"),
    ],
    ("sports", "Youth Sports"), [
        ("Raising Athletes", "https://feeds.simplecast.com/zqDdXcNr", "by Raising Athletes (Youth Sports)"),
        ("The Athlete Development Show", "https://feeds.buzzsprout.com/699853.rss", "by Athlete Development (Youth Development)"),
    ],

    # ── technology ────────────────────────────────────────────────────
    ("technology", "AR & VR"), [
        ("The Vergecast", "https://feeds.megaphone.fm/vergecast", "by The Verge (Tech News)"),
    ],
    ("technology", "Cloud Computing"), [
        ("Big Technology Podcast", "https://feeds.megaphone.fm/LI3617121267", "by Alex Kantrowitz (Big Tech)"),
    ],
    ("technology", "Gadgets & Wearables"), [
        ("The Next Wave", "https://feeds.megaphone.fm/thenextwave", "by The Next Wave (Future Tech)"),
        ("WSJ's The Future of Everything", "https://feeds.megaphone.fm/WSJ5815510508", "by WSJ (Future Technology)"),
    ],
    ("technology", "Quantum Computing"), [
        ("NVIDIA AI Podcast", "https://feeds.megaphone.fm/nvidiaaipodcast", "by NVIDIA (AI and Quantum)"),
        ("Training Data", "https://feeds.megaphone.fm/trainingdata", "by Training Data (AI Technology)"),
    ],
    ("technology", "Robotics"), [
        ("WSJ's The Future of Everything", "https://feeds.megaphone.fm/WSJ5815510508", "by WSJ (Robotics and Future)"),
    ],

    # ── travel ────────────────────────────────────────────────────────
    ("travel", "Accessible Travel"), [
        ("Smart Travel: Upgrade Your Getaways", "https://feeds.megaphone.fm/NRD5604144476", "by NerdWallet (Travel Planning)"),
        ("Firsthand", "https://feeds.megaphone.fm/TPG7701032430", "by The Points Guy (Travel)"),
    ],
    ("travel", "Adventure Travel"), [
        ("Wild Ideas Worth Living", "https://feeds.simplecast.com/pyeGnjub", "by REI (Adventure)"),
    ],
    ("travel", "Cruise Travel"), [
        ("The Skift Travel Podcast", "https://feeds.megaphone.fm/SKIFT8999081027", "by Skift (Travel Industry)"),
    ],
    ("travel", "Festival Travel"), [
        ("Travel Secrets", "https://feeds.megaphone.fm/MR2986579385", "by Travel Secrets (World Travel)"),
        ("The Big Travel Podcast", "https://feeds.megaphone.fm/AUDD9396950735", "by Lisa Francesca Nand (Travel Stories)"),
    ],
    ("travel", "Road Trips"), [
        ("The Outdoor Drive Podcast", "https://feeds.megaphone.fm/WPCM5290647973", "by The Outdoor Drive (Road Trips)"),
    ],
    ("travel", "Solo Travel"), [
        ("This Week in Travel", "https://feeds.megaphone.fm/ADV5821609310", "by This Week in Travel (World Travel)"),
    ],
    ("travel", "Travel Hacking"), [
        ("Smart Travel: Upgrade Your Getaways", "https://feeds.megaphone.fm/NRD5604144476", "by NerdWallet (Travel Deals)"),
        ("Firsthand", "https://feeds.megaphone.fm/TPG7701032430", "by The Points Guy (Points and Miles)"),
    ],

    # ── true crime ────────────────────────────────────────────────────
    ("true crime", "Crime Fiction"), [
        ("Crawlspace - True Crime & Mysteries", "https://feeds.megaphone.fm/GLSS1898288411", "by Crawlspace (True Crime)"),
        ("Crime House Daily", "https://feeds.megaphone.fm/crimehouse", "by Crime House Daily (True Crime News)"),
    ],
    ("true crime", "Forensic Psychology"), [
        ("Serial Killers", "https://feeds.megaphone.fm/end1032105222", "by Parcast (Criminal Psychology)"),
        ("True Crime News: The Podcast", "https://feeds.megaphone.fm/true-crime-daily", "by True Crime Daily (Crime News)"),
    ],
    ("true crime", "International Crime"), [
        ("It's A Crime", "https://feeds.megaphone.fm/ADL1005671887", "by It's A Crime (International Crime)"),
        ("Going West: True Crime", "https://feeds.megaphone.fm/GLSS6860726197", "by Going West (True Crime)"),
    ],
    ("true crime", "Juvenile Crime"), [
        ("Senseless True Crime Podcast", "https://feeds.buzzsprout.com/2367913.rss", "by Senseless (Crime Victims)"),
        ("The Midwest Crime Files", "https://feeds.buzzsprout.com/1981490.rss", "by Midwest Crime Files (Regional Crime)"),
    ],
    ("true crime", "Missing Persons"), [
        ("Missing", "https://feeds.megaphone.fm/GLSS9533070472", "by Missing (Missing Persons)"),
    ],
    ("true crime", "Prison System"), [
        ("TRUECRIMEISH", "https://feeds.buzzsprout.com/2207018.rss", "by TRUECRIMEISH (Criminal Justice)"),
        ("Murder, She Told", "https://feeds.megaphone.fm/murdershetold", "by Murder, She Told (Cold Cases)"),
    ],
    ("true crime", "Serial Killers"), [
        ("Serial Killers", "https://feeds.megaphone.fm/end1032105222", "by Parcast (Serial Killers)"),
    ],
    ("true crime", "Unsolved Mysteries"), [
        ("Up and Vanished", "https://feeds.megaphone.fm/up-and-vanished", "by Up and Vanished (Cold Cases)"),
    ],
    ("true crime", "Victim Advocacy"), [
        ("Senseless True Crime Podcast", "https://feeds.buzzsprout.com/2367913.rss", "by Senseless (Victim Stories)"),
        ("The FOX True Crime Podcast", "https://feeds.megaphone.fm/FOXM5131996932", "by FOX News (True Crime)"),
    ],
    ("true crime", "White Collar Crime"), [
        ("Appalachian Mysteria", "https://feeds.buzzsprout.com/2542915.rss", "by Appalachian Mysteria (Crime)"),
    ],

    # ── relationships & dating (needs 11+ to reach 12) ────────────
    ("relationships & dating", "Communication Skills"), [
        ("Where Should We Begin?", "https://feeds.simplecast.com/brKNIO_n", "Esther Perel's landmark therapy sessions on relationships"),
        ("Just Between Us", "https://feeds.megaphone.fm/justbetweenus", "Relationship communication tips and honest relationship talk"),
    ],
    ("relationships & dating", "Conflict Resolution"), [
        ("Relationship Alive", "https://feeds.simplecast.com/lP7rVCkN", "Expert strategies for thriving relationships with Neil Sattin"),
        ("Multiamory", "https://feeds.simplecast.com/TfL_pRkG", "Modern relationship communication and conflict resolution"),
    ],
    ("relationships & dating", "Dating Tips"), [
        ("U Up?", "https://feeds.megaphone.fm/uup", "Modern dating advice and hookup culture discussion"),
        ("Dateable", "https://feeds.simplecast.com/wLi0erap", "Modern dating deep dives and relationship perspectives"),
    ],
    ("relationships & dating", "LGBTQ+ Relationships"), [
        ("Making Gay History", "https://feeds.simplecast.com/RwMr0Z8P", "LGBTQ history through personal narratives"),
        ("Gender Reveal", "https://feeds.simplecast.com/1_mYRBtI", "Trans and nonbinary stories and relationship perspectives"),
    ],
    ("relationships & dating", "Love & Commitment"), [
        ("The Love Fix", "https://feeds.buzzsprout.com/1052891.rss", "Relationship therapy and love advice from Dr. Tara Fields"),
        ("Love Is Like a Plant", "https://feeds.simplecast.com/VXa_V3I_", "Ellen and Luke's honest conversations about love and commitment"),
    ],
    ("relationships & dating", "Marriage"), [
        ("Marriage Therapy Radio", "https://feeds.buzzsprout.com/261306.rss", "Licensed therapists discuss real marriage challenges"),
    ],
]
# fmt: on


def _build_merged_dict():
    """Merge duplicate keys from _PODCASTS_RAW into a single dict."""
    merged = {}
    it = iter(_PODCASTS_RAW)
    for item in it:
        if isinstance(item, tuple) and len(item) == 2 and isinstance(item[0], str):
            names = next(it)
            merged.setdefault(item, []).extend(names)
    return merged


PODCASTS_TO_ADD = _build_merged_dict()


class Command(BaseCommand):
    help = "Add real podcasts to popular_feeds.json to fill category/subcategory gaps"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
        parser.add_argument("--verbose", action="store_true", help="Show each addition")

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        verbose = options["verbose"]

        fixture_path = os.path.normpath(FIXTURE_PATH)
        with open(fixture_path, "r") as f:
            all_feeds = json.load(f)

        # Index existing podcast feeds by normalized URL
        existing_urls = set()
        for feed in all_feeds:
            if feed.get("feed_type") == "podcast":
                existing_urls.add(feed["feed_url"].lower())

        # Count current state
        podcast_feeds = [f for f in all_feeds if f.get("feed_type") == "podcast"]
        cat_counts = Counter(f["category"] for f in podcast_feeds)
        subcat_counts = Counter((f["category"], f["subcategory"]) for f in podcast_feeds)

        self.stdout.write(f"Current state: {len(podcast_feeds)} podcast feeds across {len(cat_counts)} categories")

        # Track what we'll add
        added = 0
        skipped_dup = 0
        new_entries = []

        for (category, subcategory), podcast_list in PODCASTS_TO_ADD.items():
            for title, feed_url, description in podcast_list:
                if feed_url.lower() in existing_urls:
                    skipped_dup += 1
                    if verbose:
                        self.stdout.write(f"  SKIP (exists): {title} -> {category}/{subcategory}")
                    continue

                entry = {
                    "feed_type": "podcast",
                    "category": category,
                    "subcategory": subcategory,
                    "title": title,
                    "description": description,
                    "feed_url": feed_url,
                    "subscriber_count": 0,
                    "platform": "",
                    "thumbnail_url": "",
                }
                new_entries.append(entry)
                existing_urls.add(feed_url.lower())
                added += 1

                if verbose:
                    self.stdout.write(f"  ADD: {title} -> {category}/{subcategory}")

        self.stdout.write(f"\nWill add {added} new entries ({skipped_dup} skipped as duplicates)")

        if dry_run:
            self._print_gap_analysis(podcast_feeds + new_entries)
            return

        # Add and sort
        all_feeds.extend(new_entries)

        # Sort podcast feeds within the file: by category, subcategory, subscriber_count desc
        non_podcast = [f for f in all_feeds if f.get("feed_type") != "podcast"]
        podcast_updated = [f for f in all_feeds if f.get("feed_type") == "podcast"]
        podcast_updated.sort(key=lambda f: (f["category"], f["subcategory"], -f.get("subscriber_count", 0)))

        all_feeds_out = non_podcast + podcast_updated

        with open(fixture_path, "w") as f:
            json.dump(all_feeds_out, f, indent=2)

        self.stdout.write(self.style.SUCCESS(f"\nWrote {len(all_feeds_out)} total feeds to {fixture_path}"))
        self._print_gap_analysis(podcast_updated)

    def _print_gap_analysis(self, podcast_feeds):
        """Print analysis of remaining gaps."""
        cat_counts = Counter(f["category"] for f in podcast_feeds)
        subcat_counts = defaultdict(lambda: defaultdict(int))
        for f in podcast_feeds:
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
            self.stdout.write(self.style.SUCCESS(f"\nAll categories have {MIN_CATEGORY_COUNT}+ podcasts"))

        if subcats_under:
            self.stdout.write(self.style.WARNING(f"\nSubcategories still under {MIN_SUBCATEGORY_COUNT}:"))
            for cat, sub, count in sorted(subcats_under):
                self.stdout.write(f"  {cat}/{sub}: {count}")
        else:
            self.stdout.write(self.style.SUCCESS(f"All subcategories have {MIN_SUBCATEGORY_COUNT}+ podcasts"))
