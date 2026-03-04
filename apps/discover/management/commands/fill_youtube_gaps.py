"""
One-off script to add real YouTube channels to popular_feeds.json to fill category/subcategory gaps.
Every category must have 12+ channels, every subcategory must have 3+.

Usage:
    python manage.py fill_youtube_gaps
    python manage.py fill_youtube_gaps --dry-run
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
# List of (category, subcategory) keys interleaved with channel lists.
# Using a flat list instead of a dict to allow duplicate keys that get merged.
# Each pair is: (category, subcategory), [(channel_name, channel_id, description), ...]
# All channel IDs verified via vidIQ, Social Blade, HypeAuditor, or NoxInfluencer.
_CHANNELS_RAW = [
    # ── automobiles ──────────────────────────────────────────────────
    ("automobiles", "Car Reviews"), [
        ("Doug DeMuro", "UCsqjHFMB_JYTaEnf_vmTNqg", "Quirky car reviews with the Doug Score rating system"),
        ("Throttle House", "UCyXiDU5qjfOPxgOPeFWGwKw", "Car reviews featuring entertaining comparisons and tests"),
        ("savagegeese", "UCgUvk6jVaf-1uKOqG8XNcaQ", "In-depth car reviews focused on engineering and value"),
        ("carwow", "UCUhFaUpnq31m6TNX2VKVSVA", "Car reviews with drag races, group tests, and comparisons"),
    ],
    ("automobiles", "Automotive News"), [
        ("MotorTrend Channel", "UCsAegdhiYLEoaFGuJFVrqFQ", "Head 2 Head comparisons and automotive news from MotorTrend"),
        ("Supercar Blondie", "UCKSVUHI9rbbkXhvAXK-2uxA", "Reviews of the world's most exotic and expensive cars"),
        ("Donut", "UCL6JmiMXKoXS6bpP1D3bk8g", "Car culture and automotive content with an entertainment focus"),
    ],
    ("automobiles", "Classic Cars"), [
        ("Jay Leno's Garage", "UCQMELFlXQL38KPm8kM-4Adg", "Classic and vintage car showcases from Jay Leno's collection"),
        ("Petrolicious", "UCgyJPixJl95X1ut3E9K99KA", "Cinematic short films celebrating classic car culture"),
        ("Hagerty", "UCLgEVx4mzk3T3mzgbKG54Eg", "Classic car valuations, barn finds, and collector car culture"),
    ],
    ("automobiles", "Electric Vehicles"), [
        ("Fully Charged Show", "UCzz4CoEgSgWNs9ZAvRMhW2A", "Electric vehicles and renewable energy reviews"),
        ("Engineering Explained", "UClqhvGmHcvWL9w3R48t9QXQ", "Science-based explanations of automotive engineering"),
        ("Out of Spec Reviews", "UCVRZKu68-4tQIk7_3CJ_wKA", "Real-world EV reviews, road trips, and charging tests"),
    ],
    ("automobiles", "Car Modifications"), [
        ("ChrisFix", "UCes1EvRjcKU4sY_UEavndBw", "DIY car maintenance and modification tutorials"),
        ("Hoonigan", "UCXlfi8sf6cKGQ8sOd0-yRuw", "Car builds, burnouts, and automotive culture"),
        ("Gears and Gasoline", "UCqE3IQPWUDA9PZGaT6BDAKw", "Automotive storytelling and car build adventures"),
    ],
    ("automobiles", "Automotive Engineering"), [
        ("Engineering Explained", "UClqhvGmHcvWL9w3R48t9QXQ", "Science-based explanations of how cars work"),
        ("Weber Auto", "UCtr07mdKhsUwVJjL8Kw_q5A", "Detailed automotive engineering and technology lectures"),
        ("Technology Connections", "UCy0tKL1T7wFoYcxCe0xjN6Q", "Deep dives into how everyday technology works"),
    ],
    # Extra channels for Automotive Engineering gap
    ("automobiles", "Automotive Engineering"), [
        ("Scotty Kilmer", "UCuxpxCCevIlF-k-K5YU8XPA", "Veteran mechanic sharing car engineering tips and repair knowledge"),
    ],
    ("automobiles", "Motorcycle Culture"), [
        ("FortNine", "UCNSMdQtn1SuFzCZjfK2C7dQ", "Motorcycle reviews, gear analysis, and riding culture"),
        ("RevZilla", "UCLQZTXj_AnL7fDC8sLrTGMw", "Motorcycle gear reviews, tips, and rider community"),
        ("Yammie Noob", "UCkegEsZItEPQNItECCZA_pw", "Motorcycle entertainment, reviews, and riding stories"),
    ],
    ("automobiles", "Racing & Motorsport"), [
        ("FORMULA 1", "UCB_qr75-ydFVKSF9Dmo6izg", "Official Formula 1 race highlights and behind-the-scenes"),
        ("Driver61", "UCtbLA0YM6EpwUQhFUyPQU9Q", "Professional racing analysis and driver coaching"),
        ("Kym Illman", "UCZqNme_MY-jl_1ziSr2VMjA", "F1 photography and behind-the-scenes paddock access"),
    ],
    ("automobiles", "Car Buying"), [
        ("Straight Pipes", "UC86SBFIAgnYL3ll2ZDgmsuA", "Honest car reviews with a focus on the buying decision"),
        ("Edmunds", "UCF8e8zKZ_yk7cL9DvvWGSEw", "Expert car buying advice, reviews, and comparisons"),
        ("Alex on Autos", "UC3qM33hHgedfi7qTKKgIApg", "Detailed new car reviews and buyer guides"),
    ],
    # Extra channels for Car Buying gap
    ("automobiles", "Car Buying"), [
        ("Kelley Blue Book", "UCj9yUGuMVVdm2DqyvJPUeUQ", "Trusted car valuation, reviews, and buying guides"),
    ],
    ("automobiles", "Off-Road & Adventure"), [
        ("Matt's Off Road Recovery", "UCwdVOry0oNF9WIe_3uCfz9Q", "Off-road vehicle recoveries in the Utah desert"),
        ("Trail Recon", "UCEEgz9PD6iTRSB0VXNbWvRw", "Off-road trail guides and adventure driving"),
        ("Ronny Dahl", "UChz00vupzP_mNPIYD8GSmBw", "4x4 off-road adventures and vehicle modifications"),
    ],

    # ── entertainment & comedy ───────────────────────────────────────
    ("entertainment & comedy", "Stand-Up Comedy"), [
        ("Just For Laughs", "UCpsSadsgX_Qk9i6i_bJoUwQ", "Comedy festival highlights and stand-up performances"),
        ("Dry Bar Comedy", "UCvlVuntLjdURVD3b3Hx7kxw", "Clean stand-up comedy specials and clips"),
        ("Gabriel Iglesias", "UCUxc0iEpV8wZV4WLOui0RwQ", "Stand-up specials and behind-the-scenes from Fluffy"),
    ],
    # Extra channels for Stand-Up Comedy gap
    ("entertainment & comedy", "Stand-Up Comedy"), [
        ("Sebastian Maniscalco", "UCxPmXKxJcDAhuYVHeFFyGTA", "Physical comedy and observational humor stand-up specials"),
    ],
    ("entertainment & comedy", "Comedy Sketches"), [
        ("Saturday Night Live", "UCqFzWxSCi39LnW1JKFR3efg", "Sketches, clips, and behind-the-scenes from SNL"),
        ("Key & Peele", "UCdN4aXTrHAtfgbVG9HjBmxQ", "Comedy sketches from Keegan-Michael Key and Jordan Peele"),
        ("Studio C", "UCsZXuHKonP9utl5q2hFCkgA", "Family-friendly comedy sketches and parodies"),
    ],
    # Extra channels for Comedy Sketches gap
    ("entertainment & comedy", "Comedy Sketches"), [
        ("CalebCity", "UCI1XS_GkLGDOgf8YLaaXNRA", "Solo comedy skits about everyday situations and anime parodies"),
    ],
    ("entertainment & comedy", "Late Night"), [
        ("The Late Show with Stephen Colbert", "UCMtFAi84ehTSYSE9XoHefig", "Monologues, interviews, and comedy from The Late Show"),
        ("The Tonight Show Starring Jimmy Fallon", "UC8-Th83bH_thdKZDJCrn88g", "Comedy sketches, games, and celebrity interviews"),
        ("Jimmy Kimmel Live", "UCa6vGFO9ty8v5KZJXQxdhaw", "Mean Tweets, comedy bits, and celebrity interviews"),
        ("Late Night with Seth Meyers", "UCVTyTA7-g9nopHeHbeuvpRA", "A Closer Look segments and late-night comedy"),
    ],
    ("entertainment & comedy", "Meme Culture"), [
        ("Memenade", "UCCWp4CCmI2JmIaoAuv0ocEA", "Daily meme compilations and internet humor"),
        ("MemerMan", "UCOjc2LTXq55J0HNUMvNhvYw", "Curated meme content and internet culture commentary"),
        ("Daily Dose Of Internet", "UCdC0An4ZPNr_YiFiYoVbwaw", "Viral videos and internet moments compiled daily"),
    ],
    ("entertainment & comedy", "Parody"), [
        ("Weird Al Yankovic", "UCDBrVr0ttWpoRY-_yZajp2Q", "Official channel of music parodist Weird Al Yankovic"),
        ("Bad Lip Reading", "UC67f2Qf7FYhtoUIF4Sf29cA", "Hilarious dubbed-over dialogue from movies and politics"),
        ("The Key of Awesome", "UCEmCXnbNYz-MOtXi3lZ7W1Q", "Music video parodies and pop culture comedy"),
    ],
    ("entertainment & comedy", "Satire"), [
        ("The Onion", "UCfAOh2t5DpxVrgS9NQKjC7A", "Satirical news and comedy from America's Finest News Source"),
        ("Babylon Bee", "UCyl5V3-J_Bsy3x-EBCJwepg", "Satirical takes on current events and culture"),
        ("Aunty Donna", "UC_mneEC0wc29EGGmIsN_xLA", "Australian sketch comedy troupe with absurdist humor"),
    ],
    ("entertainment & comedy", "Variety Shows"), [
        ("The Try Guys", "UCpi8TJfiA4lKGkaXs__YdBA", "Comedy group trying new challenges and experiences"),
        ("Dude Perfect", "UCRijo3ddMTht_IHyNSNXpNQ", "Trick shots, stunts, and competitive challenges"),
        ("Smosh", "UCY30JRSgfhYXA6i6xX1erWg", "Comedy sketches, challenges, and gaming content"),
    ],
    ("entertainment & comedy", "Comedy Podcasts"), [
        ("H3 Podcast", "UCLtREJY21xRfCuEKvdki1Kw", "Comedy podcast covering internet culture and current events"),
        ("Good Mythical Morning", "UC4PooiX37Pld1T8J5SYT-SQ", "Daily comedy show featuring food experiments and games"),
        ("Conan O'Brien Needs A Friend", "UCo3nWXH_6vVJ5-xbF3bKb3Q", "Comedy interviews and travel content from Conan O'Brien"),
    ],
    ("entertainment & comedy", "Comedy News"), [
        ("Last Week Tonight", "UC3XTzVzaHQEd30rQbuvCtTQ", "John Oliver's deep dives into news and politics with comedy"),
        ("Some More News", "UCvlj0IzjSnNoduQF0l3VGng", "Satirical news commentary and political analysis"),
        ("The Daily Show", "UCwWhs_6x42TyRM4Wstoq8HA", "Comedy Central's satirical take on daily news and politics"),
    ],

    # ── film & television ────────────────────────────────────────────
    ("film & television", "Film Reviews"), [
        ("Chris Stuckmann", "UCCqEeDAUf4Mg0GgEN658tkA", "Movie reviews and film analysis"),
        ("Jeremy Jahns", "UC7v3-2K1N84V67IF-WTRG-Q", "Entertaining quick-hit movie and show reviews"),
        ("CineFix - IGN Movies and TV", "UCVtL1edhT8qqY-j2JIndMzg", "Top movie lists and deep dives into cinema"),
    ],
    # Extra channels for Film Reviews gap
    ("film & television", "Film Reviews"), [
        ("YourMovieSucksDOTorg", "UCSc16oMxxlcJSb9SXkjwMjA", "In-depth analytical movie reviews and video essays"),
        ("Filmento", "UCG_nvdTLdijiAAuPKxtvBjA", "Film analysis exploring what makes movies succeed or fail"),
    ],
    ("film & television", "TV Reviews"), [
        ("Nerdwriter1", "UCJkMlOu7faDgqh4PfzbpLdg", "Video essays on art, culture, film, and TV"),
        ("NewRockstars", "UC7yRILFFJ2QZCykymr8LPwA", "Breakdowns and easter egg analysis for TV and film"),
        ("ScreenCrush", "UCgMJGv4cQl8-q71AyFeFmtg", "Movie and TV news, reviews, and breakdowns"),
    ],
    ("film & television", "Cinematography & Filmmaking"), [
        ("Corridor Crew", "UCSpFnDQr88xCZ80N-X7t0nQ", "VFX artists react to movie effects and filmmaking"),
        ("StudioBinder", "UCUFoQUaVRt3MVFxqwPUMLCQ", "Filmmaking tutorials on cinematography and directing"),
        ("Indy Mogul", "UCGZ0LgTmAJn9Banetdr_ZFg", "Indie filmmaking techniques and DIY production"),
    ],
    ("film & television", "Film Theory"), [
        ("Lessons from the Screenplay", "UCErSSa3CaP_GJxmFpdjG9Jw", "Analyzing movie scripts and storytelling techniques"),
        ("The Take", "UCVjsbqKtxkLt7bal4NWRjJQ", "Video essays exploring deeper meanings in movies and TV"),
        ("Thomas Flight", "UCUyvQV2JsICeLZP4c_h40kA", "Video essays on the art of filmmaking and visual storytelling"),
    ],
    ("film & television", "Movie News"), [
        ("Screen Junkies", "UCOpcACMWblDls9Z6GERVi1A", "Honest Trailers, movie fights, and film news"),
        ("Collider Videos", "UC5hX0jtOEAobccb2dvSnYbw", "Movie and TV news, reviews, and interviews"),
        ("Emergency Awesome", "UCDiFRMQWpcp8_KD4vwIVicw", "Comic book, superhero, and genre film news and analysis"),
    ],
    ("film & television", "Classic Cinema"), [
        ("CinemaTyler", "UC7GV-3hrA9kDKrren0QMKMg", "Video essays on classic and contemporary cinema"),
        ("Be Kind Rewind", "UCNiolZNLiJplmCCzqk9-czQ", "Deep dives into classic Hollywood films and actors"),
        ("The Cinema Cartography", "UCL5kBJmBUVFLYBDiSiK1VDw", "Exploring the geography and locations of classic films"),
    ],
    ("film & television", "Documentary"), [
        ("VICE", "UCn8zNIfYAQNdrFRrr8oibKw", "Award-winning documentary content on global topics"),
        ("ColdFusion", "UC4QZ_LsYcvcq7qOsOhpAI4A", "Mini-documentaries on technology, business, and science"),
        ("Vox", "UCLXo7UDZvByw2ixzpQCufnA", "Explanatory journalism and documentary videos"),
    ],
    ("film & television", "Screenwriting"), [
        ("Lessons from the Screenplay", "UCErSSa3CaP_GJxmFpdjG9Jw", "Script analysis and writing craft for screenwriters"),
        ("Tyler Mowery", "UCFnskmQu5NjjJ2rooCSF7tw", "Screenwriting tips, film analysis, and story structure"),
        ("Just Write", "UCx0L2ZdYfiq-tsAXb8IXpQg", "Video essays on writing for film and television"),
    ],
    # Extra channels for Screenwriting gap
    ("film & television", "Screenwriting"), [
        ("Film Theorists", "UC3sznuotAs2ohg_U__Jzj_Q", "Film theory and storytelling analysis from the Theorist brand"),
    ],
    ("film & television", "Animation"), [
        ("Cartoon Hangover", "UCIA9jUDnKVMYc4SmqTxcwqg", "Independent animation and original animated series"),
        ("BaM Animation", "UC4Qvpti1dS1KKC7PLyLl__g", "Animation process breakdowns and behind-the-scenes"),
        ("Drawfee", "UCoal_hpPIPAnWlG-kWHLheA", "Comedy drawing show with animators and artists"),
    ],

    # ── finance & business ───────────────────────────────────────────
    ("finance & business", "Personal Finance"), [
        ("Graham Stephan", "UCa-ckhlKL98F8YXKQ-BALiw", "Real estate, investing, and personal finance advice"),
        ("The Ramsey Show", "UCzpwkXk_GlfmWntZ9v4l3Tg", "Debt-free strategies and financial planning with Dave Ramsey"),
        ("Minority Mindset", "UCT3EznhW_CNFcfOlyDNTLLw", "Financial literacy and money management education"),
    ],
    ("finance & business", "Investing"), [
        ("Andrei Jikh", "UCGy7SkBjcIAgTiwkXEtPnYg", "Investing strategies, stock analysis, and financial education"),
        ("Meet Kevin", "UCUvvj5lwue7PspotMDjk5UA", "Real estate investing, stock market, and economic analysis"),
        ("Ben Felix", "UCDXTQ8nWmx_EhZ2v-kp7QxA", "Evidence-based investing and personal finance"),
    ],
    ("finance & business", "Business Strategy"), [
        ("Harvard Business Review", "UCWo4IA01TXzBeGJJKWHOG9g", "Business strategy, management, and leadership insights"),
        ("Patrick Boyle", "UCASM0cgfkJxQ1ICmRilfHLQ", "Finance industry analysis with dry wit and deep knowledge"),
        ("The Swedish Investor", "UCAeAB8ABXGoGMbXuYPmiu2A", "Book summaries and business strategy breakdowns"),
    ],
    ("finance & business", "Entrepreneurship"), [
        ("GaryVee", "UCctXZhXmG-kf3tlIXgVZUlw", "Entrepreneurship motivation and digital marketing advice"),
        ("Ali Abdaal", "UCoOae5nYA7VqaXzerajD0lg", "Productivity tips and building online businesses"),
        ("Noah Kagan", "UCF2v8v8te3_u4xhIQ8tGy1g", "Business experiments and practical startup advice"),
    ],
    # Extra channels for Entrepreneurship gap
    ("finance & business", "Entrepreneurship"), [
        ("Nate O'Brien", "UCO3tlaeZ6Z0ZN5frMZI3-uQ", "Personal finance and entrepreneurship for millennials"),
    ],
    ("finance & business", "Financial Markets"), [
        ("Bloomberg Originals", "UCUMZ7gohGI9HcU9VNsr2FJQ", "Financial markets coverage and business documentaries"),
        ("CNBC", "UCvJJ_dzjViJCoLf5uKUTwoA", "Stock market news, financial analysis, and business coverage"),
        ("Yahoo Finance", "UCEAZeUIeJs0IjQiqTCdVSIg", "Market news, stock analysis, and economic trends"),
    ],
    ("finance & business", "Tax Planning"), [
        ("Karlton Dennis", "UCEc3bAbOtPEUIgpNkViF_PQ", "Tax strategies and wealth-building through tax planning"),
        ("Mark J Kohler", "UCHYeaAH3D-wzQyDiXndSfMA", "Tax reduction strategies and legal advice for business owners"),
        ("Navi Maraj", "UC4kOk-e0A6VyBU63b5BbCQg", "Canadian tax tips and financial planning"),
    ],
    ("finance & business", "Real Estate Investing"), [
        ("BiggerPockets", "UCVWDbXqQ8cupuVpotWNt2eg", "Real estate investing education, podcasts, and strategies"),
        ("Graham Stephan", "UCa-ckhlKL98F8YXKQ-BALiw", "Real estate and personal finance from a millennial agent"),
        ("Ken McElroy", "UCiFOL6V9KbvxfXvzdFSsqCw", "Real estate investing and property management advice"),
    ],
    # Extra channels for Real Estate Investing gap
    ("finance & business", "Real Estate Investing"), [
        ("Ryan Serhant", "UCG98giOsUxIlXV0rNUhxLew", "Real estate sales strategies and luxury property tours"),
        ("Grant Cardone", "UCdlNK1xcy-Sn8liq7feNxWw", "Real estate investing, sales training, and wealth building"),
    ],
    ("finance & business", "Economic Analysis"), [
        ("Economics Explained", "UCZ4AMrDcNrfy3X6nsU8-rPg", "Accessible explanations of complex economic topics"),
        ("Money & Macro", "UCCKpicnIwBP3VPxBAZWDeNA", "Economic analysis and monetary policy deep dives"),
        ("How Money Works", "UCkCGANrihzExmu9QiqZpPlQ", "Exploring how money, economics, and business really work"),
    ],
    # Extra channels for Economic Analysis gap
    ("finance & business", "Economic Analysis"), [
        ("Principles by Ray Dalio", "UCqvaXJ1K3HheTPNjH-KpwXQ", "Economic principles and macro analysis from Bridgewater founder"),
        ("Wall Street Millennial", "UCUyH4QfXX-5NOT0bULqG6lQ", "Financial and economic analysis of markets and companies"),
    ],
    ("finance & business", "Corporate Finance"), [
        ("Aswath Damodaran", "UCLvnJL8htRR1T9cbSccaoVw", "Corporate finance and valuation from an NYU professor"),
        ("The Plain Bagel", "UCFCEuCsyWP0YkP3CZ3Mr01Q", "Investment analysis and financial concept explanations"),
        ("Patrick Boyle", "UCASM0cgfkJxQ1ICmRilfHLQ", "Hedge fund manager's take on finance and markets"),
    ],
    # Extra channels for Corporate Finance gap
    ("finance & business", "Corporate Finance"), [
        ("Corporate Finance Institute", "UCGtbVv_ACgV7difdVZ92NMw", "Financial modeling and corporate finance education"),
    ],
    ("finance & business", "Accounting"), [
        ("Accounting Stuff", "UCYJLdSmyKoXCbnd-pklMn5Q", "Accounting education made accessible and entertaining"),
        ("The Financial Controller", "UC_nhE8RYGlOzdwckSY0pLjA", "Finance and accounting career advice and tutorials"),
        ("Tony Bell", "UCNFClg6mzfZ5ixpuH9c7f1A", "CPA exam prep and accounting career guidance"),
    ],

    # ── news & current events ────────────────────────────────────────
    ("news & current events", "Breaking News"), [
        ("CNN", "UCupvZG-5ko_eiXAupbDfxWw", "24-hour breaking news and in-depth reporting"),
        ("BBC News", "UC16niRr50-MSBwiO3YDb3RA", "Global breaking news and journalism from the BBC"),
        ("NBC News", "UCeY0bbntWzzVIaj2z3QigXg", "Breaking news, top stories, and live reporting"),
    ],
    # Extra channels for Breaking News gap
    ("news & current events", "Breaking News"), [
        ("ABC News", "UCBi2mrWuNuyYy4gbM6fU18Q", "Breaking news coverage and in-depth reporting from ABC"),
        ("Sky News", "UCoMdktPbSTixAyNGwb-UYkQ", "24-hour international breaking news from Sky"),
    ],
    ("news & current events", "Political Analysis"), [
        ("MSNBC", "UCaXkIU1QidjPwiAYu6GcHjg", "Political analysis and news commentary"),
        ("PBS NewsHour", "UC6ZFN9Tx6xh-skXCuRHCDpQ", "In-depth political reporting and balanced analysis"),
        ("Vox", "UCLXo7UDZvByw2ixzpQCufnA", "Explanatory journalism on politics and policy"),
    ],
    ("news & current events", "Investigative Journalism"), [
        ("FRONTLINE PBS", "UC3ScyryU9Oy9Wse3a8OAmYQ", "Award-winning investigative documentary series"),
        ("60 Minutes", "UCsN32BtMd0IoByjJRNF12cw", "Classic investigative journalism and in-depth interviews"),
        ("Al Jazeera English", "UCNye-wNBqNL5ZzHSJj3l8Bg", "International investigative journalism and features"),
    ],
    ("news & current events", "International News"), [
        ("DW News", "UCknLrEdhRCp1aegoMqRaCZg", "International news from Germany's public broadcaster"),
        ("France 24 English", "UCQfwfsi5VrQ8yKZ-UWmAEFg", "International news from French perspective"),
        ("Channel 4 News", "UCTrQ7HXWRRxr7OsOtodr2_w", "UK and international news coverage"),
    ],
    ("news & current events", "Media Analysis"), [
        ("Mediaite", "UCGJNv0jLqnkp9VbEXTbRd5w", "Media news and analysis covering political journalism"),
        ("Breaking Points", "UCDRIjKy6eZOvKtOELtTdeUA", "Independent news and media criticism"),
        ("Zeteo", "UCVG72F2Q5yCmLQfctNK6M2A", "Independent news and media analysis from Mehdi Hasan"),
    ],
    ("news & current events", "Policy Analysis"), [
        ("Brookings Institution", "UCi7jxgIOxcRaF4Q54U7lF3g", "Public policy research and analysis"),
        ("Council on Foreign Relations", "UCL_A4jkwvKuMyToAPy3FQKQ", "Foreign policy analysis and expert discussions"),
        ("CSIS", "UCLpKumtKuUyJ0Y_zLoIye6A", "Strategic and international studies analysis"),
    ],
    ("news & current events", "Social Issues"), [
        ("NowThis News", "UCn4sPeUomNGIr26bElVdDYg", "Progressive news coverage of social issues"),
        ("AJ+", "UCV3Nm3T-XAgVhKH9jT0ViRg", "Social justice and current events coverage"),
        ("The Economist", "UC0p5jTq6Xx_DosDFxVXnWaQ", "Economic and social analysis from The Economist"),
    ],
    ("news & current events", "Fact-Checking"), [
        ("PolitiFact", "UCfyYK3GqcotDIAjcoReK3Hg", "Political fact-checking and truth ratings"),
        ("Channel 5 with Andrew Callaghan", "UC-AQKm7HUNMmxjdS371MSwg", "On-the-ground journalism and interviews"),
        ("Philip DeFranco", "UClFSU9_bUb4Rc6OYfTt5SPw", "News commentary and media analysis"),
    ],

    # ── education ────────────────────────────────────────────────────
    ("education", "Languages"), [
        ("Langfocus", "UCNhX3WQEkraW3VHPyup8jkQ", "Exploring world languages and linguistics"),
        ("Easy Languages", "UCqcBu0YyEJH4vfKR--97cng", "Street interviews for learning languages naturally"),
    ],
    ("education", "Test Prep & Certifications"), [
        ("Professor Leonard", "UCoHhuummRZaIVX7bD4t2czg", "University-level math lectures for exam preparation"),
    ],
    ("education", "Tutorials & How-To"), [
        ("Khan Academy", "UC4a-Gbdw7vOaccHmFo40b9g", "Free educational tutorials across all subjects"),
        ("TED-Ed", "UCsooa4yRKGN_zEE8iknghZA", "Animated educational lessons on diverse topics"),
    ],
    # Extra channels for Tutorials & How-To gap
    ("education", "Tutorials & How-To"), [
        ("Howcast", "UCSpVHeDGr9UbREhRca0qwsA", "Practical how-to video tutorials across diverse everyday topics"),
        ("BRIGHT SIDE", "UC4rlAVgAK0SGk-yTfe48Qpw", "Educational explainers on science, history, and life tips"),
    ],

    # ── gaming ───────────────────────────────────────────────────────
    ("gaming", "Gaming Commentary"), [
        ("videogamedunkey", "UCsvn_Po0SmunchJYOWpOxMg", "Humorous video game reviews and commentary"),
    ],
    # Extra channels for Gaming Commentary gap
    ("gaming", "Gaming Commentary"), [
        ("AngryJoeShow", "UCsgv2QHkT2ljEixyulzOnUQ", "Passionate game reviews with skits and in-depth analysis"),
    ],
    ("gaming", "Indie Games"), [
        ("SplatterCatGaming", "UC8nZUXCwCTffxthKLtOp6ng", "Daily coverage of new and obscure indie games"),
        ("NakeyJakey", "UCSdma21fnJzgmPodhC9SJ3g", "Video essays on gaming and internet culture"),
    ],

    # ── music ────────────────────────────────────────────────────────
    ("music", "Live Performances"), [
        ("NPR Music", "UC4eYXhJI4-7wSWc8UNRwD4A", "Tiny Desk Concerts and live music sessions"),
    ],
    # Extra channels for Live Performances gap
    ("music", "Live Performances"), [
        ("Audiotree", "UCWjmAUHmajb1-eo5WKk_22A", "Live in-studio music sessions and artist discovery"),
        ("Cercle", "UCPKT_csvP72boVX0XrMtagQ", "DJ sets and live performances filmed at cultural heritage sites"),
    ],
    ("music", "Music Covers"), [
        ("Postmodern Jukebox", "UCORIeT1hk6tYBuntEXsguLg", "Popular songs reimagined in vintage musical styles"),
        ("KEXP", "UC3I2GFN_F8WudD_2jUZbojA", "Live in-studio music sessions from artists worldwide"),
    ],
    # Extra channels for Music Covers gap
    ("music", "Music Covers"), [
        ("Pomplamoose", "UCSiPjfAJBgbFlIUsxOWpK0w", "Creative music covers and originals from a husband-wife duo"),
    ],
    ("music", "Music Production"), [
        ("Andrew Huang", "UCdcemy56JtVTrsFIOoqvV8g", "Creative music production and experimental compositions"),
    ],
    # Extra channels for Music Production gap
    ("music", "Music Production"), [
        ("Dylan Tallchief", "UCIu2Fj4x_VMn2dgSB1bFyQA", "Music production tutorials and electronic music compositions"),
    ],
    ("music", "Music Reviews"), [
        ("theneedledrop", "UCt7fwAhXDy3oNFTAzF2o8Pw", "In-depth album reviews from the internet's busiest music nerd"),
        ("Rick Beato", "UCJquYOG5EL82sKTfH9aMA9Q", "Music theory, song analysis, and musician interviews"),
    ],
    # Extra channels for Music Reviews gap
    ("music", "Music Reviews"), [
        ("Todd in the Shadows", "UCaTSjmqzOO-P8HmtVW3t7sA", "Pop music reviews and one-hit-wonder retrospectives"),
    ],

    # ── science ──────────────────────────────────────────────────────
    ("science", "Biology"), [
        ("Journey to the Microcosmos", "UCBbnbBWJtwsf0jLGUwX5Q3g", "Microscopic life exploration with Hank Green"),
    ],
    ("science", "Chemistry"), [
        ("NileRed", "UCFhXFikryT4aFcLkLw2LBLA", "Chemistry experiments and synthesis procedures"),
    ],
    ("science", "Earth Sciences"), [
        ("MinuteEarth", "UCeiYXex_fwgYDonaTcSIk6w", "Short animated explanations of earth and environmental science"),
    ],

    # ── sports ───────────────────────────────────────────────────────
    ("sports", "Baseball & Cricket"), [
        ("Jomboy Media", "UCl9E4Zxa8CVr2LBLD0_TaNg", "Baseball breakdowns, podcasts, and sports comedy"),
        ("Foolish Baseball", "UCbW12JIVAdi5NugdakbU33A", "Deep dives into baseball history and statistics"),
    ],
    ("sports", "Basketball"), [
        ("JxmyHighroller", "UC3L9XPe0_FGfRG-CMGtBvFg", "NBA analysis, history, and basketball deep dives"),
        ("KOT4Q", "UCu9sYmfPNydPJFqLLTdmxvA", "Basketball trivia, analysis, and entertaining NBA content"),
    ],
    ("sports", "Extreme Sports"), [
        ("Red Bull", "UCblfuW_4rakIf2h6aqANefA", "Extreme sports action and athlete features"),
    ],
    # Extra channels for Extreme Sports gap
    ("sports", "Extreme Sports"), [
        ("X Games", "UCxFt75OIIvoN4AaL7lJxtTg", "Official extreme sports competition highlights and coverage"),
    ],
    ("sports", "Fitness Sports & Training"), [
        ("GoPro", "UCqhnX4jA0A5paNd1v-zEysw", "POV action sports and adventure footage"),
    ],
    ("sports", "Sports Commentary"), [
        ("Secret Base", "UCDRmGMSgrtZkOsh_NQl4_xw", "Long-form sports storytelling from SB Nation"),
        ("The Athletic", "UCqYaVuSy3gX-qqBKirfzJjw", "In-depth sports journalism and analysis"),
    ],

    # ── technology ───────────────────────────────────────────────────
    ("technology", "AI & Machine Learning"), [
        ("Two Minute Papers", "UCbfYPyITQ-7l4upoX8nvctg", "AI and graphics research explained in short videos"),
        ("Yannic Kilcher", "UCZHmQk67mSJgfCCTn7xBfew", "Machine learning paper reviews and AI discussion"),
    ],
    ("technology", "Product Reviews"), [
        ("MKBHD", "UCBJycsmduvYEL83R_U4JriQ", "High-quality tech reviews and gadget analysis"),
        ("Linus Tech Tips", "UCXuqSBlHAE6Xw-yeJA0Tunw", "Tech reviews, builds, and computing content"),
    ],
    # Extra channels for Product Reviews gap
    ("technology", "Product Reviews"), [
        ("Dave2D", "UCVYamHliCI9rw1tHR1xbkfw", "Clean and minimalist tech reviews and comparisons"),
        ("Unbox Therapy", "UCsTcErHg8oDvUnTzoqsYeNw", "Tech product unboxing and gadget showcases"),
    ],
    ("technology", "Programming & Coding"), [
        ("Traversy Media", "UC29ju8bIPH5as8OGnQzwJyA", "Web development tutorials for all levels"),
        ("Fireship", "UCsBjURrPoezykLs9EqgamOA", "Fast-paced programming tutorials and tech news"),
    ],
    # Extra channels for Programming & Coding gap
    ("technology", "Programming & Coding"), [
        ("The Coding Train", "UCvjgXvBlbQiydffZU7m1_aw", "Creative coding tutorials with Daniel Shiffman"),
    ],
    ("technology", "Software Development"), [
        ("ThePrimeagen", "UC8ENHE5xdFSwx71u3fDH5Xw", "Software engineering discussions and programming culture"),
        ("t3dotgg", "UCbRP3c757lWg9M-U7TyEkXA", "Full-stack web development and tech commentary"),
    ],
]
# fmt: on


def _build_merged_dict():
    """Merge duplicate keys from _CHANNELS_RAW into a single dict."""
    merged = {}
    it = iter(_CHANNELS_RAW)
    for item in it:
        if isinstance(item, tuple) and len(item) == 2 and isinstance(item[0], str):
            names = next(it)
            merged.setdefault(item, []).extend(names)
    return merged


CHANNELS_TO_ADD = _build_merged_dict()


class Command(BaseCommand):
    help = "Add real YouTube channels to popular_feeds.json to fill category/subcategory gaps"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
        parser.add_argument("--verbose", action="store_true", help="Show each addition")

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        verbose = options["verbose"]

        fixture_path = os.path.normpath(FIXTURE_PATH)
        with open(fixture_path, "r") as f:
            all_feeds = json.load(f)

        # Index existing youtube feeds by normalized URL
        existing_urls = set()
        for feed in all_feeds:
            if feed.get("feed_type") == "youtube":
                existing_urls.add(feed["feed_url"].lower())

        # Count current state
        youtube_feeds = [f for f in all_feeds if f.get("feed_type") == "youtube"]
        cat_counts = Counter(f["category"] for f in youtube_feeds)
        subcat_counts = Counter((f["category"], f["subcategory"]) for f in youtube_feeds)

        self.stdout.write(f"Current state: {len(youtube_feeds)} youtube feeds across {len(cat_counts)} categories")

        # Track what we'll add
        added = 0
        skipped_dup = 0
        new_entries = []

        for (category, subcategory), channels in CHANNELS_TO_ADD.items():
            for channel_name, channel_id, description in channels:
                feed_url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
                if feed_url.lower() in existing_urls:
                    skipped_dup += 1
                    if verbose:
                        self.stdout.write(f"  SKIP (exists): {channel_name} -> {category}/{subcategory}")
                    continue

                entry = {
                    "feed_type": "youtube",
                    "category": category,
                    "subcategory": subcategory,
                    "title": channel_name,
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
                    self.stdout.write(f"  ADD: {channel_name} -> {category}/{subcategory}")

        self.stdout.write(f"\nWill add {added} new entries ({skipped_dup} skipped as duplicates)")

        if dry_run:
            self._print_gap_analysis(youtube_feeds + new_entries)
            return

        # Add and sort
        all_feeds.extend(new_entries)

        # Sort youtube feeds within the file: by category, subcategory, subscriber_count desc
        non_youtube = [f for f in all_feeds if f.get("feed_type") != "youtube"]
        youtube_updated = [f for f in all_feeds if f.get("feed_type") == "youtube"]
        youtube_updated.sort(key=lambda f: (f["category"], f["subcategory"], -f.get("subscriber_count", 0)))

        all_feeds_out = non_youtube + youtube_updated

        with open(fixture_path, "w") as f:
            json.dump(all_feeds_out, f, indent=2)

        self.stdout.write(self.style.SUCCESS(f"\nWrote {len(all_feeds_out)} total feeds to {fixture_path}"))
        self._print_gap_analysis(youtube_updated)

    def _print_gap_analysis(self, youtube_feeds):
        """Print analysis of remaining gaps."""
        cat_counts = Counter(f["category"] for f in youtube_feeds)
        subcat_counts = defaultdict(lambda: defaultdict(int))
        for f in youtube_feeds:
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
            self.stdout.write(self.style.SUCCESS(f"\nAll categories have {MIN_CATEGORY_COUNT}+ channels"))

        if subcats_under:
            self.stdout.write(self.style.WARNING(f"\nSubcategories still under {MIN_SUBCATEGORY_COUNT}:"))
            for cat, sub, count in sorted(subcats_under):
                self.stdout.write(f"  {cat}/{sub}: {count}")
        else:
            self.stdout.write(self.style.SUCCESS(f"All subcategories have {MIN_SUBCATEGORY_COUNT}+ channels"))
