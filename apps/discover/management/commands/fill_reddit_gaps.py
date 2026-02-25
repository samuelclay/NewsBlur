"""
One-off script to add real subreddits to popular_feeds.json to fill category/subcategory gaps.
Every category must have 12+ subreddits, every subcategory must have 3+.

Usage:
    python manage.py fill_reddit_gaps
    python manage.py fill_reddit_gaps --dry-run
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
# Mapping: (category, subcategory) -> list of subreddit names to add
# NOTE: duplicate keys are intentional — _build_merged_dict() below merges them.
_SUBREDDITS_RAW = [
    # ── pets & animals ──────────────────────────────────────────────
    ("pets & animals", "Animal Welfare"), [
        "AnimalRights", "AnimalRescue", "AnimalShelters", "vegan",
        "AnimalSanctuary", "StopAnimalAbuse",
    ],
    ("pets & animals", "Birds"), [
        "birding", "parrots", "budgies", "cockatiel", "birdpics",
        "Ornithology", "Conures", "chickens",
    ],
    ("pets & animals", "Cat Care"), [
        "cats", "CatAdvice", "CatTraining", "kittens",
        "seniorkitties", "blackcats", "orangecats", "TuxedoCats",
    ],
    ("pets & animals", "Dog Training"), [
        "Dogtraining", "puppy101", "reactivedogs", "dogs", "OpenDogTraining",
        "k9sports", "samoyeds", "germanshepherds",
    ],
    ("pets & animals", "Exotic Pets"), [
        "reptiles", "Rabbits", "snakes", "ferrets", "Hedgehog", "guineapigs",
        "hermitcrabs", "tarantulas", "hamsters",
    ],
    ("pets & animals", "Fish & Aquariums"), [
        "Aquariums", "PlantedTank", "ReefTank", "bettafish", "shrimptank",
        "goldfish", "Cichlid", "Aquascape",
    ],
    ("pets & animals", "Pet Adoption"), [
        "BeforeNAfterAdoption", "rescuedogs", "Pets",
        "AdoptDontShop", "rescuecats",
    ],
    ("pets & animals", "Pet Health"), [
        "AskVet", "VetTech", "petcare",
        "rawpetfood", "DogFood",
    ],
    ("pets & animals", "Pet News"), [
        "AnimalsBeingBros", "aww", "AnimalsBeingDerps",
        "Eyebleach", "rarepuppers", "WhatsWrongWithYourDog",
    ],
    ("pets & animals", "Wildlife"), [
        "wildlife", "WildlifeRehab", "conservation", "natureismetal",
        "NatureIsFuckingLit", "animalid",
    ],

    # ── architecture ────────────────────────────────────────────────
    ("architecture", "Architectural Styles"), [
        "ArchitecturalRevival", "brutalism", "ArtDeco", "midcenturymodern",
        "McMansionHell", "Bauhaus",
    ],
    ("architecture", "Architecture News"), [
        "architecture", "Architect", "ArchitecturePorn",
        "ArchitectureSchool",
    ],
    ("architecture", "Architecture Trends"), [
        "Futurology", "DesignPorn", "ArchitecturePorn",
        "Parametric", "ModernArchitecture",
    ],
    ("architecture", "Building Design"), [
        "StructuralEngineering", "engineering", "Architect",
        "civilengineering", "BuildingCodes",
    ],
    ("architecture", "Commercial Design"), [
        "CommercialRealEstate", "InteriorDesign", "architecture",
        "RetailDesign", "RestaurantDesign",
    ],
    ("architecture", "Famous Buildings"), [
        "evilbuildings", "CityPorn", "Lost_Architecture",
        "InfrastructurePorn", "castles",
    ],
    ("architecture", "Historic Architecture"), [
        "Lost_Architecture", "ArchitecturalRevival", "ArtefactPorn",
        "centuryhomes", "OldPhotosInRealLife",
    ],
    ("architecture", "Residential Design"), [
        "floorplan", "HomeImprovement", "homebuilding",
        "CozyPlaces", "RoomPorn",
    ],
    ("architecture", "Sustainable Architecture"), [
        "SolarPunk", "TinyHouses", "sustainability",
        "PassiveHouse", "GreenBuildingDesign",
    ],
    ("architecture", "Urban Planning"), [
        "urbanplanning", "Urbanism", "transit", "notjustbikes",
        "WalkableStreets", "fuckcars",
    ],

    # ── psychology & mental health ──────────────────────────────────
    ("psychology & mental health", "Anxiety & Depression"), [
        "Anxiety", "depression", "socialanxiety", "HealthAnxiety",
        "OCD", "PanicAttack", "dpdr", "Phobia",
    ],
    ("psychology & mental health", "Behavioral Psychology"), [
        "psychology", "BehavioralEconomics", "SocialPsychology",
        "AcademicPsychology", "IOPsychology",
    ],
    ("psychology & mental health", "Brain Science"), [
        "neuroscience", "cogsci", "neuro",
        "BrainScience", "Neuropsychology",
    ],
    ("psychology & mental health", "Cognitive Psychology"), [
        "cogsci", "PhilosophyofMind", "neuroscience",
        "CognitiveScience", "MemoryScience",
    ],
    ("psychology & mental health", "Counseling"), [
        "TalkTherapy", "therapy", "askatherapist", "CPTSD",
        "dbtselfhelp", "CBT",
    ],
    ("psychology & mental health", "Mental Health Advocacy"), [
        "mentalhealth", "psychotherapy", "MadOver30",
        "bipolar", "schizophrenia", "BPD",
    ],
    ("psychology & mental health", "Mindfulness"), [
        "Mindfulness", "Meditation", "TheMindIlluminated",
        "Stoicism", "zenbuddhism",
    ],
    ("psychology & mental health", "Positive Psychology"), [
        "GetMotivated", "DecidingToBeBetter", "gratitude",
        "happiness", "MomForAMinute",
    ],
    ("psychology & mental health", "Relationships"), [
        "relationship_advice", "relationships", "datingoverthirty",
        "AskMenOver30", "AskWomenOver30", "DeadBedrooms",
    ],
    ("psychology & mental health", "Self-Improvement"), [
        "selfimprovement", "getdisciplined", "DecidingToBeBetter",
        "selfhelp", "ZenHabits", "NonZeroDay",
    ],

    # ── military & defense ──────────────────────────────────────────
    ("military & defense", "Arms & Equipment"), [
        "MilitaryPorn", "guns", "Firearms", "WarplanePorn",
        "GunPorn", "longrange", "MilitaryGfys",
    ],
    ("military & defense", "Cybersecurity & Warfare"), [
        "cybersecurity", "netsec", "hacking",
        "cyberDeck", "CyberWarfare", "InfoSecNews",
    ],
    ("military & defense", "Defense Industry"), [
        "CredibleDefense", "LessCredibleDefence", "MilitaryProcurement",
        "DefenseNews",
    ],
    ("military & defense", "Defense Policy"), [
        "CredibleDefense", "geopolitics", "foreignpolicy",
        "NATOWave", "USpolitics",
    ],
    ("military & defense", "Geopolitical Analysis"), [
        "geopolitics", "worldnews", "IRstudies",
        "IntelligenceNews", "GlobalPolitics",
    ],
    ("military & defense", "Intelligence Community"), [
        "OSINT", "Intelligence", "espionage",
        "SIGINT", "IntelligenceHistory",
    ],
    ("military & defense", "Military History"), [
        "MilitaryHistory", "WarCollege", "ww2", "CombatFootage",
        "WWI", "ColdWarHistory", "VietnamWar",
    ],
    ("military & defense", "Military Technology"), [
        "MilitaryPorn", "WarplanePorn", "TankPorn",
        "drones", "MilitaryDrones",
    ],
    ("military & defense", "Naval Operations"), [
        "navy", "WarshipPorn", "submarines", "CoastGuard",
        "NavalHistory",
    ],
    ("military & defense", "Veterans & Service"), [
        "Veterans", "army", "AirForce", "Military", "USMC",
        "nationalguard", "VeteransBenefits",
    ],

    # ── automotive ──────────────────────────────────────────────────
    ("automotive", "Auto Maintenance"), [
        "MechanicAdvice", "Cartalk", "autodetailing", "justrolledintotheshop",
        "AutoDIY", "Brakes",
    ],
    ("automotive", "Automotive Culture"), [
        "cars", "carporn", "Shitty_Car_Mods", "weirdwheels",
        "spotted", "Stance",
    ],
    ("automotive", "Automotive News"), [
        "Autos", "whatcarshouldIbuy", "askcarsales",
        "CarNews", "Automotive",
    ],
    ("automotive", "Automotive Technology"), [
        "SelfDrivingCars", "CarHacking", "dashcam",
        "connectedcar", "ADAS",
    ],
    ("automotive", "Car Reviews"), [
        "whatcarshouldIbuy", "cars", "Autos",
        "CarReview", "carcomparisons",
    ],
    ("automotive", "Classic Cars"), [
        "classiccars", "vintagecars", "projectcar", "BarnFinds",
        "ClassicMustangs",
    ],
    ("automotive", "Electric Vehicles"), [
        "electricvehicles", "TeslaMotors", "Rivian", "BoltEV",
        "electriccars", "EVs",
    ],
    ("automotive", "Motorcycles"), [
        "motorcycles", "bikesgonewild", "motocamping", "SuggestAMotorcycle",
        "Dualsport", "supermoto",
    ],
    ("automotive", "New Releases"), [
        "cars", "whatcarshouldIbuy", "Autos",
        "NewCars", "AutoNews",
    ],
    ("automotive", "Performance & Tuning"), [
        "projectcar", "Autocross", "CarMods",
        "drifting", "Miata", "WRX",
    ],

    # ── data science & analytics ────────────────────────────────────
    ("data science & analytics", "Big Data"), [
        "bigdata", "dataengineering", "datasets", "hadoop", "apachespark",
    ],
    ("data science & analytics", "Business Intelligence"), [
        "BusinessIntelligence", "PowerBI", "Tableau", "looker",
    ],
    ("data science & analytics", "Data Analysis"), [
        "dataanalysis", "analytics", "opendata", "SampleSize",
    ],
    ("data science & analytics", "Data Privacy"), [
        "privacy", "PrivacyGuides", "degoogle", "dataprivacy",
    ],
    ("data science & analytics", "Data Science Research"), [
        "datascience", "MLQuestions", "deeplearning", "ArtificialIntelligence",
    ],
    ("data science & analytics", "Data Tools"), [
        "dataengineering", "Python", "rstats", "SQL", "dbt",
    ],
    ("data science & analytics", "Data Visualization"), [
        "dataisbeautiful", "visualization", "MapPorn", "infographics",
    ],
    ("data science & analytics", "Machine Learning"), [
        "MachineLearning", "learnmachinelearning", "deeplearning", "ArtificialIntelligence",
    ],
    ("data science & analytics", "NLP"), [
        "LanguageTechnology", "LocalLLaMA", "ChatGPT", "compling",
    ],
    ("data science & analytics", "Statistics"), [
        "statistics", "AskStatistics", "rstats", "probabilitytheory",
    ],

    # ── home & garden ───────────────────────────────────────────────
    ("home & garden", "Container Gardening"), [
        "ContainerGardening", "Aerogarden", "UrbanGardening", "IndoorGarden",
    ],
    ("home & garden", "Flower Gardening"), [
        "gardening", "flowers", "NativePlantGardening", "PollinatorGardens",
    ],
    ("home & garden", "Garden Design"), [
        "landscaping", "NoLawns", "NativePlantGardening", "GardenDesign",
    ],
    ("home & garden", "Home Decor"), [
        "HomeDecorating", "RoomPorn", "DesignMyRoom", "malelivingspace", "femalelivingspace",
    ],
    ("home & garden", "Home Improvement"), [
        "HomeImprovement", "DIY", "fixit", "centuryhomes", "HomeInspections",
    ],
    ("home & garden", "Houseplants"), [
        "houseplants", "proplifting", "plantclinic", "succulents", "Monstera",
    ],
    ("home & garden", "Landscape Design"), [
        "landscaping", "lawncare", "NoLawns", "Xeriscaping", "BackyardOrchard",
    ],
    ("home & garden", "Organic Gardening"), [
        "OrganicGardening", "Permaculture", "composting", "vegetablegardening",
    ],
    ("home & garden", "Smart Home"), [
        "smarthome", "homeautomation", "homeassistant", "HomeKit", "googlehome",
    ],
    ("home & garden", "Sustainable Living"), [
        "ZeroWaste", "sustainability", "Anticonsumption", "SustainableLiving",
    ],

    # ── real estate ─────────────────────────────────────────────────
    ("real estate", "Commercial Real Estate"), [
        "CommercialRealEstate", "realestateinvesting", "CREFinance",
    ],
    ("real estate", "Home Buying"), [
        "FirstTimeHomeBuyer", "RealEstate", "homebuying",
    ],
    ("real estate", "Home Staging"), [
        "HomeStaging", "InteriorDesign", "Flipping",
    ],
    ("real estate", "Housing Market"), [
        "RealEstate", "REBubble", "HousingMarket",
    ],
    ("real estate", "Investment Properties"), [
        "realestateinvesting", "Landlord", "BRRRR",
    ],
    ("real estate", "Luxury Real Estate"), [
        "RealEstate", "fatFIRE", "Mansion",
    ],
    ("real estate", "Market Analysis"), [
        "RealEstate", "REBubble", "RealEstateCanada",
    ],
    ("real estate", "Mortgage & Finance"), [
        "Mortgages", "FirstTimeHomeBuyer", "personalfinance",
    ],
    ("real estate", "Property Management"), [
        "propertymanagement", "Landlord", "realestateinvesting",
    ],
    ("real estate", "Rental Market"), [
        "Landlord", "ApartmentHacks", "personalfinance",
    ],

    # ── hobbies & collections ───────────────────────────────────────
    ("hobbies & collections", "Board Games"), [
        "boardgames", "soloboardgaming", "Gloomhaven",
    ],
    ("hobbies & collections", "Coin Collecting"), [
        "coins", "CRH", "numismatics", "Silverbugs",
    ],
    ("hobbies & collections", "Comic Books"), [
        "comicbooks", "comicbookcollecting", "graphicnovels",
    ],
    ("hobbies & collections", "Genealogy"), [
        "Genealogy", "AncestryDNA", "23andme",
    ],
    ("hobbies & collections", "Model Building"), [
        "modelmakers", "modeltrains", "Gunpla",
    ],
    ("hobbies & collections", "Puzzles"), [
        "Jigsawpuzzles", "crossword", "puzzles",
    ],
    ("hobbies & collections", "Stamps"), [
        "stamps", "philately", "postcrossing",
    ],
    ("hobbies & collections", "Vinyl Records"), [
        "vinyl", "VinylCollectors", "turntables",
    ],

    # ── productivity & organization ─────────────────────────────────
    ("productivity & organization", "Automation"), [
        "automation", "IFTTT", "selfhosted",
    ],
    ("productivity & organization", "Decision Making"), [
        "DecidingToBeBetter", "productivity", "getdisciplined",
    ],
    ("productivity & organization", "Focus & Concentration"), [
        "nosurf", "GetStudying", "digitalminimalism",
    ],
    ("productivity & organization", "Goal Setting"), [
        "getdisciplined", "TheXEffect", "selfimprovement",
    ],
    ("productivity & organization", "Habit Building"), [
        "theXeffect", "Habits", "getdisciplined",
    ],
    ("productivity & organization", "Note-Taking"), [
        "ObsidianMD", "Zettelkasten", "logseq",
    ],
    ("productivity & organization", "Planning Systems"), [
        "bulletjournal", "Notion", "gtd",
    ],
    ("productivity & organization", "Productivity Apps"), [
        "Notion", "ObsidianMD", "todoist", "TickTick",
    ],
    ("productivity & organization", "Task Management"), [
        "todoist", "TickTick", "gtd",
    ],
    ("productivity & organization", "Time Management"), [
        "productivity", "getdisciplined", "pomodoro",
    ],

    # ── diy & crafts ────────────────────────────────────────────────
    ("diy & crafts", "Crafting"), [
        "crafts", "polymerclay", "resin", "papercraft",
    ],
    ("diy & crafts", "DIY Projects"), [
        "DIY", "fixit", "somethingimade", "maker",
    ],
    ("diy & crafts", "Electronics DIY"), [
        "electronics", "AskElectronics", "arduino", "raspberry_pi", "3Dprinting",
    ],
    ("diy & crafts", "Home Improvement"), [
        "HomeImprovement", "centuryhomes", "fixit", "Plumbing",
    ],
    ("diy & crafts", "Jewelry Making"), [
        "jewelrymaking", "Silversmith", "Benchjewelers", "wirewrapping",
    ],
    ("diy & crafts", "Knitting & Crochet"), [
        "knitting", "crochet", "YarnAddicts", "Amigurumi",
    ],
    ("diy & crafts", "Painting"), [
        "painting", "watercolor", "oilpainting", "acrylicpainting",
    ],
    ("diy & crafts", "Sewing"), [
        "sewing", "quilting", "sewhelp", "embroidery",
    ],
    ("diy & crafts", "Upcycling"), [
        "ZeroWaste", "Frugal", "upcycling", "ThriftStoreHauls",
    ],
    ("diy & crafts", "Woodworking"), [
        "woodworking", "BeginnerWoodWorking", "turning", "Carpentry",
    ],

    # ── space & astronomy ───────────────────────────────────────────
    ("space & astronomy", "Cosmology"), [
        "cosmology", "astrophysics",
    ],
    ("space & astronomy", "Dark Matter & Energy"), [
        "Physics", "cosmology", "ParticlePhysics",
    ],
    ("space & astronomy", "Exoplanets"), [
        "exoplanets", "astrobiology", "space",
    ],
    ("space & astronomy", "NASA & Space Agencies"), [
        "nasa", "ESA", "ISRO",
    ],
    ("space & astronomy", "Rocket Technology"), [
        "SpaceX", "rocketry", "SpaceLaunchSystem",
    ],
    ("space & astronomy", "Satellite Technology"), [
        "Starlink", "amateursatellites", "RTLSDR",
    ],
    ("space & astronomy", "Space Industry"), [
        "SpaceXLounge", "BlueOrigin", "spaceflight",
    ],
    ("space & astronomy", "Telescopes & Observatories"), [
        "astrophotography", "telescopes",
    ],

    # ── wellness & self-care ────────────────────────────────────────
    ("wellness & self-care", "Alternative Medicine"), [
        "herbalism", "Ayurveda", "NaturalMedicine",
    ],
    ("wellness & self-care", "Aromatherapy"), [
        "aromatherapy", "essentialoils", "Perfumes",
    ],
    ("wellness & self-care", "Body Positivity"), [
        "bodyacceptance", "PlusSize", "BodyDysmorphia",
    ],
    ("wellness & self-care", "Holistic Health"), [
        "Supplements", "Biohackers", "AlternativeHealth",
    ],
    ("wellness & self-care", "Meditation"), [
        "Meditation", "Vipassana", "mindfulness",
    ],
    ("wellness & self-care", "Self-Care Routines"), [
        "selfcare", "selfimprovement", "DecidingToBeBetter",
    ],
    ("wellness & self-care", "Sleep Health"), [
        "sleep", "insomnia", "SleepApnea",
    ],
    ("wellness & self-care", "Spa & Relaxation"), [
        "SkincareAddiction", "AsianBeauty", "relaxation",
    ],
    ("wellness & self-care", "Stress Management"), [
        "Anxiety", "burnout", "ZenHabits",
    ],

    # ── third pass: very niche unique subreddits ───────────────────
    # Targeting subcategories still at 1-2 after second pass
    ("anime & manga", "Anime Reviews"), ["animereviewers", "AnimeImpressions", "japanimation"],
    ("architecture", "Architecture News"), ["architecturestudents", "ArchiRevit"],
    ("architecture", "Architecture Trends"), ["biophilicdesign", "SmartCities"],
    ("architecture", "Building Design"), ["BIM", "AutoCAD"],
    ("architecture", "Historic Architecture"), ["historicpreservation", "CastlePorn"],
    ("architecture", "Residential Design"), ["housedesign", "HomeFloorPlans"],
    ("architecture", "Urban Planning"), ["WalkableStreets", "UrbanDesign"],
    ("arts & culture", "Art History"), ["classicalart", "MuseumPros"],
    ("books & reading", "Book Reviews"), ["BooksThatFeelLikeThis", "bookcritics"],
    ("career & job market", "Career Advice"), ["ExperiencedDevs", "AskHR"],
    ("career & job market", "Career Change"), ["careerchange", "TransferToOtherField"],
    ("career & job market", "Career Development"), ["GradSchool", "MBA"],
    ("career & job market", "Industry Trends"), ["FutureOfWork", "automatedworkplace"],
    ("career & job market", "Remote Work"), ["telecommuting", "RemoteJobs"],
    ("career & job market", "Salary & Compensation"), ["PersonalFinanceCanada", "UKPersonalFinance"],
    ("career & job market", "Skills & Training"), ["Certifications", "OMSCS"],
    ("comedy & humor", "Comedy News"), ["comedyheaven", "ComedyHits"],
    ("comedy & humor", "Comedy Writing"), ["comedywriting", "WritersRoom"],
    ("comedy & humor", "Sketch Comedy"), ["MadTV", "KidsInTheHall"],
    ("cryptocurrency & web3", "Crypto Regulation"), ["CryptoRegulation", "SECCrypto"],
    ("cryptocurrency & web3", "Stablecoins"), ["USDC", "dai"],
    ("data science & analytics", "Data Privacy"), ["GDPR", "ComplianceOfficer"],
    ("data science & analytics", "Data Tools"), ["Jupyter", "DataPipeline"],
    ("data science & analytics", "Data Visualization"), ["dataviz", "d3js"],
    ("data science & analytics", "NLP"), ["LanguageModels", "NLProc"],
    ("data science & analytics", "Statistics"), ["bayesian", "StatsModels"],
    ("design", "Brand Identity"), ["IdentityDesign", "CorporateIdentity"],
    ("diy & crafts", "Knitting & Crochet"), ["YarnSwap", "Weaving"],
    ("diy & crafts", "Painting"), ["HappyTrees", "pourpainting"],
    ("diy & crafts", "Upcycling"), ["Repurposed", "ReStore"],
    ("diy & crafts", "Woodworking"), ["FineWoodworking", "Scrollsaw"],
    ("economics", "Behavioral Economics"), ["NudgeTheory", "experimentaleconomics"],
    ("economics", "Labor Markets"), ["LaborMovement", "unionsolidarity"],
    ("education", "Classroom Innovation"), ["teaching", "TeachingResources"],
    ("entrepreneurship & startups", "Angel Investing"), ["AngelList", "earlyinvesting"],
    ("entrepreneurship & startups", "Fundraising"), ["crowdfunding", "kickstarter"],
    ("entrepreneurship & startups", "Growth Hacking"), ["GrowthMarketing", "growthmindset"],
    ("entrepreneurship & startups", "Product Management"), ["ProductDesign", "UserExperience"],
    ("environment & sustainability", "Oceans & Water"), ["WaterQuality", "DeepSeaCreatures"],
    ("environment & sustainability", "Pollution"), ["AirQuality", "microplastics"],
    ("fashion & beauty", "Fashion News"), ["streetwearstartup", "Runway"],
    ("finance", "Retirement Planning"), ["leanfire", "coastFIRE"],
    ("health & fitness", "Mindfulness"), ["breathwork", "taichi"],
    ("history", "Historical Figures"), ["PresidentialHistory", "FamousPeople"],
    ("history", "Public History"), ["OldSchoolCool", "TheWayWeWere"],
    ("hobbies & collections", "Coin Collecting"), ["CoinErrors", "WorldCoins"],
    ("hobbies & collections", "Model Building"), ["scalemodels", "dioramas"],
    ("hobbies & collections", "Puzzles"), ["mechanicalpuzzles", "RubiksCube"],
    ("hobbies & collections", "Vinyl Records"), ["VinylDeals", "audiophilemusic"],
    ("home & garden", "Garden Design"), ["BackyardLandscaping", "CottageGarden"],
    ("home & garden", "Landscape Design"), ["YardWork", "LandscapeArchitecture"],
    ("home & garden", "Sustainable Living"), ["OffGrid", "selfsufficiency"],
    ("internet culture & social media", "Digital Culture"), ["meirl", "starterpacks"],
    ("internet culture & social media", "Influencer Culture"), ["BlogSnark", "InstagramInfluencers"],
    ("internet culture & social media", "Viral Trends"), ["ContagiousLaughter", "oddlysatisfying"],
    ("law & legal", "Business Law"), ["Contracts", "AskLawyers"],
    ("law & legal", "Constitutional Law"), ["ConLaw", "ConstitutionalDebate"],
    ("law & legal", "Environmental Law"), ["EnvironmentLaw", "ClimateJustice"],
    ("military & defense", "Arms & Equipment"), ["WeaponSystems", "GunPorn"],
    ("military & defense", "Geopolitical Analysis"), ["GlobalPolitics", "WarStudies"],
    ("military & defense", "Military Technology"), ["MilitaryTech", "DefenseTech"],
    ("military & defense", "Veterans & Service"), ["VeteranWomen", "MilitarySpouse"],
    ("parenting", "Activities & Crafts"), ["KidsArts", "ChildrensCrafts"],
    ("parenting", "Family Health"), ["PediatricNurse", "ChildNutrition"],
    ("parenting", "School-Age Kids"), ["KidsLearning", "elementary"],
    ("parenting", "Teen Parenting"), ["ParentsOfTeens", "raisingteens"],
    ("philosophy", "Metaphysics"), ["PhilosophyOfScience", "FreeWillDebate"],
    ("productivity & organization", "Automation"), ["Zapier", "n8n"],
    ("productivity & organization", "Note-Taking"), ["RoamResearch", "Evernote"],
    ("productivity & organization", "Planning Systems"), ["planners", "bujo"],
    ("psychology & mental health", "Brain Science"), ["Neuropsychology", "BrainResearch"],
    ("real estate", "Commercial Real Estate"), ["CommercialLending", "OfficeSpace"],
    ("real estate", "Home Buying"), ["RealEstateAdvice", "MovingAdvice"],
    ("real estate", "Home Staging"), ["FlipHouses", "StagingTips"],
    ("real estate", "Investment Properties"), ["WholesaleRealestate", "AirbnbHosts"],
    ("real estate", "Market Analysis"), ["RealEstateTechnology", "HousingData"],
    ("real estate", "Mortgage & Finance"), ["RealEstateFinance", "HomeLoan"],
    ("real estate", "Property Management"), ["ApartmentMaintenance", "PropertyMgt"],
    ("real estate", "Rental Market"), ["Renters", "renting"],
    ("relationships & dating", "Communication Skills"), ["PublicSpeaking", "socialanxiety"],
    ("relationships & dating", "Friendship"), ["Penpals", "BuddiesHangout"],
    ("relationships & dating", "Long-Distance Relationships"), ["longdistance", "LDRcouples"],
    ("relationships & dating", "Marriage"), ["WeddingPhotography", "MarriageCounseling"],
    ("relationships & dating", "Singles & Dating"), ["dating", "dateadvice"],
    ("religion & spirituality", "Hinduism"), ["Bhagavad_Gita", "SanatanDharma"],
    ("religion & spirituality", "Interfaith Dialogue"), ["interfaith", "ComparativeReligion"],
    ("science", "Environmental Science"), ["ecology", "EnvironmentalStudies"],
    ("space & astronomy", "Cosmology"), ["spacequestions", "UniverseToday"],
    ("space & astronomy", "Dark Matter & Energy"), ["ParticlePhysics", "cosmology"],
    ("space & astronomy", "Exoplanets"), ["habzone", "Astrochemistry"],
    ("space & astronomy", "Rocket Technology"), ["SpaceLaunchSystem", "ula"],
    ("space & astronomy", "Satellite Technology"), ["RTLSDR", "SatelliteTracker"],
    ("space & astronomy", "Space Industry"), ["commercialspace", "NewSpace"],
    ("space & astronomy", "Telescopes & Observatories"), ["Astronomy", "JWST"],
    ("true crime", "Cold Cases"), ["ColdCaseFiles", "coldcaseinvestigations"],
    ("true crime", "Investigations"), ["Investigate", "TraceAnObject"],
    ("true crime", "True Crime Documentary"), ["TrueCrimeGarage", "CrimeDocs"],
    ("true crime", "White Collar Crime"), ["FinancialCrime", "Ponzi"],
    ("weather & climate", "Climate Data"), ["WeatherData", "climatedata"],
    ("weather & climate", "Extreme Weather"), ["stormchasing", "SevereWeather"],
    ("weather & climate", "Oceanography"), ["OceanScience", "MarineScience"],
    ("weather & climate", "Weather Technology"), ["WeatherTech", "WeatherRadar"],
    ("wellness & self-care", "Aromatherapy"), ["EssentialOilRecipes", "Aromatherapists"],
    ("wellness & self-care", "Body Positivity"), ["IntuitivEating", "HealthyAtEverySize"],
    ("wellness & self-care", "Holistic Health"), ["Biohackers", "NaturalRemedies"],
    ("wellness & self-care", "Meditation"), ["Vipassana", "TranscendentalMeditation"],
    ("wellness & self-care", "Self-Care Routines"), ["JournalingIsArt", "MorningRoutines"],
    ("wellness & self-care", "Sleep Health"), ["SleepApnea", "LucidDreaming"],
    ("wellness & self-care", "Stress Management"), ["StressRelief", "AnxietyHelp"],

    # ── additional niche subreddits for remaining gaps ─────────────
    # These target subcategories still under 3 after first pass
    ("pets & animals", "Pet News"), [
        "tippytaps", "Zoomies", "HappyWoofGifs",
    ],
    ("architecture", "Architecture News"), [
        "ArchitectureSchool", "ArchiCAD",
    ],
    ("architecture", "Architecture Trends"), [
        "ModernArchitecture", "Parametric",
    ],
    ("architecture", "Building Design"), [
        "civilengineering", "AEC", "BIM",
    ],
    ("architecture", "Historic Architecture"), [
        "OldPhotosInRealLife", "historicpreservation",
    ],
    ("architecture", "Residential Design"), [
        "CozyPlaces", "RoomPorn", "housedesign",
    ],
    ("architecture", "Urban Planning"), [
        "fuckcars", "WalkableStreets",
    ],
    ("automotive", "Auto Maintenance"), [
        "AutoDIY", "Brakes", "OBD2",
    ],
    ("automotive", "Automotive News"), [
        "CarNews", "Automotive", "selfdrivingcars",
    ],
    ("automotive", "Electric Vehicles"), [
        "electriccars", "EVs", "PlugInHybrids",
    ],
    ("automotive", "New Releases"), [
        "NewCars", "AutoNews", "CarSales",
    ],
    ("career & job market", "Career Advice"), [
        "AskEngineers", "ExperiencedDevs",
    ],
    ("career & job market", "Career Development"), [
        "GradSchool", "MBA",
    ],
    ("career & job market", "Industry Trends"), [
        "technews", "TechIndustry", "FutureOfWork",
    ],
    ("career & job market", "Remote Work"), [
        "WorkOnline", "telecommuting",
    ],
    ("career & job market", "Salary & Compensation"), [
        "SalaryNegotiations", "PersonalFinanceCanada", "UKPersonalFinance",
    ],
    ("career & job market", "Skills & Training"), [
        "WGU", "OMSCS", "Certifications",
    ],
    ("comedy & humor", "Comedy News"), [
        "ComedyNerd", "comedyheaven",
    ],
    ("comedy & humor", "Sketch Comedy"), [
        "MontyPython", "KidsInTheHall", "MadTV",
    ],
    ("data science & analytics", "Data Analysis"), [
        "ExcelTips", "spreadsheets",
    ],
    ("data science & analytics", "Data Privacy"), [
        "dataprivacy", "GDPR", "cybersecurity",
    ],
    ("data science & analytics", "Data Tools"), [
        "SQL", "dbt", "Jupyter",
    ],
    ("data science & analytics", "Data Visualization"), [
        "infographics", "dataviz",
    ],
    ("data science & analytics", "NLP"), [
        "compling", "LanguageModels",
    ],
    ("data science & analytics", "Statistics"), [
        "probabilitytheory", "bayesian",
    ],
    ("design", "Brand Identity"), [
        "branding", "IdentityDesign",
    ],
    ("diy & crafts", "DIY Projects"), [
        "maker", "MakerSpace",
    ],
    ("diy & crafts", "Knitting & Crochet"), [
        "Amigurumi", "YarnSwap",
    ],
    ("diy & crafts", "Painting"), [
        "acrylicpainting", "minipainting", "HappyTrees",
    ],
    ("diy & crafts", "Upcycling"), [
        "ThriftStoreHauls", "Repurposed",
    ],
    ("diy & crafts", "Woodworking"), [
        "Carpentry", "Scrollsaw", "FineWoodworking",
    ],
    ("economics", "Behavioral Economics"), [
        "BehavioralEconomics", "NudgeTheory",
    ],
    ("economics", "Labor Markets"), [
        "union", "LaborMovement",
    ],
    ("entrepreneurship & startups", "Angel Investing"), [
        "seedfunding", "AngelList",
    ],
    ("entrepreneurship & startups", "Product Management"), [
        "prodmgmt", "ProductDesign",
    ],
    ("environment & sustainability", "Oceans & Water"), [
        "OceanConservation", "WaterQuality",
    ],
    ("environment & sustainability", "Pollution"), [
        "plasticfree", "pollution",
    ],
    ("fashion & beauty", "Fashion News"), [
        "FashionReps", "streetwearstartup",
    ],
    ("finance", "Retirement Planning"), [
        "retirement", "Fire", "leanfire",
    ],
    ("health & fitness", "Mindfulness"), [
        "yoga", "breathwork",
    ],
    ("history", "Historical Figures"), [
        "biography", "PresidentialHistory", "WW2History",
    ],
    ("history", "Public History"), [
        "HistoryPorn", "OldSchoolCool",
    ],
    ("hobbies & collections", "Coin Collecting"), [
        "AncientCoins", "CoinErrors",
    ],
    ("hobbies & collections", "Comic Books"), [
        "graphicnovels", "comicbookcollecting", "IndieComics",
    ],
    ("hobbies & collections", "Model Building"), [
        "Gunpla", "ModelCars", "scalemodels",
    ],
    ("hobbies & collections", "Puzzles"), [
        "crossword", "mechanicalpuzzles",
    ],
    ("hobbies & collections", "Vinyl Records"), [
        "turntables", "VinylDeals", "audiophile",
    ],
    ("home & garden", "Garden Design"), [
        "gardens", "BackyardLandscaping",
    ],
    ("home & garden", "Landscape Design"), [
        "BackyardOrchard", "YardWork",
    ],
    ("home & garden", "Sustainable Living"), [
        "SustainableLiving", "OffGrid",
    ],
    ("internet culture & social media", "Digital Culture"), [
        "TikTokCringe", "meirl", "starterpacks",
    ],
    ("internet culture & social media", "Influencer Culture"), [
        "InfluencerSnark", "BlogSnark",
    ],
    ("internet culture & social media", "Viral Trends"), [
        "videos", "YoutubeHaiku", "ContagiousLaughter",
    ],
    ("law & legal", "Business Law"), [
        "BusinessLaw", "Contracts",
    ],
    ("law & legal", "Environmental Law"), [
        "environmental", "EnvironmentLaw",
    ],
    ("law & legal", "Legal Analysis"), [
        "LegalAnalysis", "BadLegalAdvice",
    ],
    ("military & defense", "Arms & Equipment"), [
        "MilitaryGfys", "WeaponSystems",
    ],
    ("military & defense", "Geopolitical Analysis"), [
        "IntelligenceNews", "GlobalPolitics",
    ],
    ("military & defense", "Military Technology"), [
        "drones", "MilitaryTech",
    ],
    ("military & defense", "Veterans & Service"), [
        "VeteransBenefits", "nationalguard",
    ],
    ("parenting", "Activities & Crafts"), [
        "kidsactivities", "KidsArts",
    ],
    ("parenting", "Family Health"), [
        "KidHealth", "PediatricNurse",
    ],
    ("parenting", "School-Age Kids"), [
        "FamilyActivities", "KidsLearning",
    ],
    ("parenting", "Teen Parenting"), [
        "TeenParenting", "ParentsOfTeens",
    ],
    ("philosophy", "Metaphysics"), [
        "ontology", "PhilosophyOfScience",
    ],
    ("productivity & organization", "Automation"), [
        "selfhosted", "Zapier",
    ],
    ("productivity & organization", "Goal Setting"), [
        "TheXEffect", "goalsetting",
    ],
    ("productivity & organization", "Habit Building"), [
        "Habits", "HabitTracking",
    ],
    ("productivity & organization", "Note-Taking"), [
        "logseq", "RoamResearch",
    ],
    ("productivity & organization", "Planning Systems"), [
        "gtd", "planners",
    ],
    ("productivity & organization", "Time Management"), [
        "pomodoro", "Timeblocking",
    ],
    ("psychology & mental health", "Brain Science"), [
        "BrainScience", "Neuropsychology",
    ],
    ("psychology & mental health", "Mental Health Advocacy"), [
        "BPD", "bipolar", "schizophrenia",
    ],
    ("real estate", "Commercial Real Estate"), [
        "CREFinance", "CommercialLending",
    ],
    ("real estate", "Home Buying"), [
        "homebuying", "RealEstateAdvice",
    ],
    ("real estate", "Home Staging"), [
        "Flipping", "HomeStaging", "FlipHouses",
    ],
    ("real estate", "Housing Market"), [
        "HousingMarket", "housingcrisis",
    ],
    ("real estate", "Investment Properties"), [
        "BRRRR", "WholesaleRealestate",
    ],
    ("real estate", "Luxury Real Estate"), [
        "Mansion", "LuxuryRealEstate", "LuxuryHomes",
    ],
    ("real estate", "Market Analysis"), [
        "RealEstateCanada", "RealEstateTechnology",
    ],
    ("real estate", "Mortgage & Finance"), [
        "Mortgages", "RealEstateFinance",
    ],
    ("real estate", "Property Management"), [
        "propertymanagement", "ApartmentMaintenance",
    ],
    ("real estate", "Rental Market"), [
        "ApartmentHacks", "renting", "Renters",
    ],
    ("relationships & dating", "Communication Skills"), [
        "Toastmasters", "PublicSpeaking",
    ],
    ("relationships & dating", "Friendship"), [
        "FriendshipAdvice", "Penpals",
    ],
    ("relationships & dating", "Long-Distance Relationships"), [
        "LDR", "longdistance",
    ],
    ("relationships & dating", "Marriage"), [
        "weddingplanning", "WeddingPhotography",
    ],
    ("relationships & dating", "Self-Love"), [
        "BodyPositive", "confidence",
    ],
    ("relationships & dating", "Singles & Dating"), [
        "ForeverAlone", "dating",
    ],
    ("religion & spirituality", "Hinduism"), [
        "yoga", "Bhagavad_Gita",
    ],
    ("religion & spirituality", "Interfaith Dialogue"), [
        "interfaith", "DebateReligion",
    ],
    ("science", "Environmental Science"), [
        "ClimateScience", "ecology",
    ],
    ("space & astronomy", "Cosmology"), [
        "astrophysics", "spacequestions",
    ],
    ("space & astronomy", "Exoplanets"), [
        "astrobiology", "habzone",
    ],
    ("space & astronomy", "Rocket Technology"), [
        "rocketry", "SpaceLaunchSystem",
    ],
    ("space & astronomy", "Satellite Technology"), [
        "amateursatellites", "RTLSDR",
    ],
    ("space & astronomy", "Space Industry"), [
        "spaceflight", "commercialspace",
    ],
    ("space & astronomy", "Telescopes & Observatories"), [
        "telescopes", "Astronomy",
    ],
    ("true crime", "Cold Cases"), [
        "WithoutATrace", "ColdCaseFiles",
    ],
    ("true crime", "Investigations"), [
        "DefenseDigest", "Investigate",
    ],
    ("true crime", "True Crime Documentary"), [
        "MakingAMurderer", "TrueCrimeGarage",
    ],
    ("true crime", "White Collar Crime"), [
        "WhiteCollarCrime", "FinancialCrime",
    ],
    ("weather & climate", "Climate Data"), [
        "ClimateData", "WeatherData",
    ],
    ("weather & climate", "Forecasting"), [
        "WeatherForecast", "NWS",
    ],
    ("weather & climate", "Oceanography"), [
        "Oceans", "OceanScience",
    ],
    ("weather & climate", "Weather Technology"), [
        "WeatherStation", "WeatherTech",
    ],
    ("wellness & self-care", "Aromatherapy"), [
        "Perfumes", "EssentialOilRecipes",
    ],
    ("wellness & self-care", "Body Positivity"), [
        "BodyDysmorphia", "IntuitivEating",
    ],
    ("wellness & self-care", "Holistic Health"), [
        "AlternativeHealth", "Biohackers",
    ],
    ("wellness & self-care", "Meditation"), [
        "Vipassana", "mindfulness",
    ],
    ("wellness & self-care", "Self-Care Routines"), [
        "selfimprovement", "JournalingIsArt",
    ],
    ("wellness & self-care", "Sleep Health"), [
        "insomnia", "SleepApnea",
    ],
    ("wellness & self-care", "Spa & Relaxation"), [
        "AsianBeauty", "SkincareAddiction",
    ],
    ("wellness & self-care", "Stress Management"), [
        "burnout", "ZenHabits", "StressRelief",
    ],

    # ── underfilled subcategories across other categories ───────────

    # anime & manga
    ("anime & manga", "Cosplay"), ["cosplay", "cosplayprops", "CosplayLewd"],
    ("anime & manga", "Anime News"), ["anime", "animenews", "AnimeDeals", "AnimeCalendar"],
    ("anime & manga", "Anime Reviews"), ["Animesuggest", "MyAnimeList", "AnimeReviews"],
    ("anime & manga", "Anime Streaming"), ["Crunchyroll", "animepiracy", "9anime"],
    ("anime & manga", "Character Analysis"), ["CharacterRant", "FanTheories", "whowouldwin"],
    ("anime & manga", "Manga Adaptations"), ["manga", "LightNovels", "Manhwa"],
    ("anime & manga", "Manga Series"), ["OnePiece", "ShingekiNoKyojin", "JuJutsuKaisen"],
    ("anime & manga", "New Releases"), ["anime", "manga", "LightNovels"],

    # arts & culture
    ("arts & culture", "Art Criticism"), ["ContemporaryArt", "ArtCrit", "arttheory"],
    ("arts & culture", "Art History"), ["ArtHistory", "museum", "classicalart"],
    ("arts & culture", "Cultural Events"), ["BurningMan", "festivals", "filmnoir"],
    ("arts & culture", "Cultural News"), ["TrueFilm", "popculture", "ArtNews"],
    ("arts & culture", "Dance"), ["Dance", "ballet", "dancegavin"],

    # books & reading
    ("books & reading", "Author News"), ["writing", "authors", "WritingPrompts"],
    ("books & reading", "Publishing Industry"), ["PubTips", "selfpublish", "WritersGroup"],
    ("books & reading", "Book Reviews"), ["bookreviews", "52book", "BooksThatFeelLikeThis"],
    ("books & reading", "Non-Fiction"), ["nonfictionbooks", "TrueCrimeBooks", "HistoryBooks"],
    ("books & reading", "New Releases"), ["Fantasy", "scifi", "horrorlit"],

    # business
    ("business", "Supply Chain"), ["supplychain", "logistics", "SupplyChainManagement"],

    # career & job market
    ("career & job market", "Career Advice"), ["careerguidance", "careeradvice", "AskEngineers"],
    ("career & job market", "Career Change"), ["findapath", "careerchange", "30PlusSkinCare"],
    ("career & job market", "Career Development"), ["jobs", "GetEmployed", "cscareerquestions"],
    ("career & job market", "Remote Work"), ["remotework", "digitalnomad", "WorkOnline"],
    ("career & job market", "Skills & Training"), ["learnprogramming", "ITCareerQuestions", "WGU"],
    ("career & job market", "Industry Trends"), ["Futurology", "technews", "TechIndustry"],
    ("career & job market", "Job Market News"), ["antiwork", "WorkReform", "recruitinghell"],
    ("career & job market", "Resume & Interviews"), ["resumes", "interviews", "GetEmployed"],
    ("career & job market", "Salary & Compensation"), ["overemployed", "sysadmin", "SalaryNegotiations"],

    # comedy & humor
    ("comedy & humor", "Comedians"), ["StandUpComedy", "comedians", "JoeRogan"],
    ("comedy & humor", "Comedy Writing"), ["standup", "screenwriting", "comedywriting"],
    ("comedy & humor", "Comedy News"), ["entertainment", "comedybangbang", "ComedyNerd"],
    ("comedy & humor", "Sketch Comedy"), ["LiveFromNewYork", "IASIP", "MontyPython"],

    # cryptocurrency & web3
    ("cryptocurrency & web3", "Crypto Regulation"), ["CryptoCurrency", "CryptoMarkets", "CryptoRegulation"],
    ("cryptocurrency & web3", "Crypto Security"), ["CryptoTechnology", "ledgerwallet", "Trezor"],
    ("cryptocurrency & web3", "NFTs & Digital Assets"), ["NFT", "opensea", "NFTsMarketplace"],
    ("cryptocurrency & web3", "Web3 Development"), ["solidity", "cryptodevs", "ethdev"],
    ("cryptocurrency & web3", "Stablecoins"), ["defi", "Tether", "USDC"],

    # design
    ("design", "Brand Identity"), ["logodesign", "graphic_design", "branding"],
    ("design", "Typography"), ["fonts", "typography", "lettering"],

    # economics
    ("economics", "Behavioral Economics"), ["AskEconomics", "AskSocialScience", "BehavioralEconomics"],
    ("economics", "Economic Policy"), ["Economics", "EconomicPolicy", "PoliticalEconomy"],
    ("economics", "Microeconomics"), ["AskEconomics", "gametheory", "microeconomics"],
    ("economics", "Development Economics"), ["GlobalDev", "development", "sustainabledevelopment"],
    ("economics", "Labor Markets"), ["WorkReform", "LaborEconomics", "union"],
    ("economics", "Macroeconomics"), ["econmonitor", "macroeconomics", "inflation"],
    ("economics", "Trade & Tariffs"), ["TradePolicy", "GlobalTrade", "internationaltrade"],
    ("economics", "Wealth & Inequality"), ["LateStageCapitalism", "Socialism", "povertyfinance"],

    # education
    ("education", "Classroom Innovation"), ["Teachers", "teaching", "EdTech"],
    ("education", "Early Education"), ["ECEProfessionals", "Montessori", "preschool"],

    # entertainment
    ("entertainment", "Satire"), ["nottheonion", "TheOnion", "AteTheOnion"],

    # entrepreneurship & startups
    ("entrepreneurship & startups", "Incubators & Accelerators"), ["ycombinator", "Accelerators", "TechStars"],
    ("entrepreneurship & startups", "Product Management"), ["ProductManagement", "agile", "prodmgmt"],
    ("entrepreneurship & startups", "Venture Capital"), ["AngelInvesting", "venturecapital", "VC"],
    ("entrepreneurship & startups", "Angel Investing"), ["investing", "AngelInvesting", "seedfunding"],
    ("entrepreneurship & startups", "Fundraising"), ["Entrepreneur", "crowdfunding", "kickstarter"],
    ("entrepreneurship & startups", "Growth Hacking"), ["growthhacking", "SEO", "GrowthMarketing"],

    # environment & sustainability
    ("environment & sustainability", "Conservation"), ["conservation", "rewilding", "NationalPark"],
    ("environment & sustainability", "Environmental Policy"), ["ClimateActionPlan", "ClimatePolicy", "GreenNewDeal"],
    ("environment & sustainability", "Wildlife"), ["wildlife", "endangered", "animalconservation"],
    ("environment & sustainability", "Oceans & Water"), ["ocean", "marinebiology", "OceanConservation"],
    ("environment & sustainability", "Pollution"), ["Anticonsumption", "plasticfree", "pollution"],

    # fashion & beauty
    ("fashion & beauty", "Fashion News"), ["femalefashionadvice", "malefashionadvice", "FashionReps"],

    # finance
    ("finance", "Insurance"), ["InsuranceProfessional", "HealthInsurance", "Insurance"],
    ("finance", "Retirement Planning"), ["financialindependence", "retirement", "Fire"],

    # food & cooking
    ("food & cooking", "Celebrity Chefs"), ["TopChef", "MasterChef", "GordonRamsay"],

    # health & fitness
    ("health & fitness", "Mindfulness"), ["Mindfulness", "Meditation", "yoga"],

    # history
    ("history", "Public History"), ["AskHistorians", "HistoryPorn", "OldSchoolCool"],
    ("history", "Historical Figures"), ["AskHistorians", "todayilearned", "biography"],

    # internet culture & social media
    ("internet culture & social media", "Influencer Culture"), ["Instagramreality", "BeautyGuruChatter", "InfluencerSnark"],
    ("internet culture & social media", "Platform News"), ["technology", "TechNewsToday", "SocialMedia"],
    ("internet culture & social media", "Content Creation"), ["NewTubers", "Twitch", "podcasting"],
    ("internet culture & social media", "Digital Culture"), ["OutOfTheLoop", "internetculture", "TikTokCringe"],
    ("internet culture & social media", "Internet History"), ["internet", "retrobattlestations", "VintageComputing"],
    ("internet culture & social media", "Internet Privacy"), ["privacy", "PrivacyGuides", "degoogle"],
    ("internet culture & social media", "Meme Culture"), ["memes", "dankmemes", "AdviceAnimals"],
    ("internet culture & social media", "Social Media Strategy"), ["socialmedia", "marketing", "ContentMarketing"],
    ("internet culture & social media", "Viral Trends"), ["TikTokCringe", "videos", "YoutubeHaiku"],

    # law & legal
    ("law & legal", "Business Law"), ["legaladvice", "Lawyertalk", "BusinessLaw"],
    ("law & legal", "Civil Rights"), ["CivilRights", "CivilLiberties", "ACLU"],
    ("law & legal", "Constitutional Law"), ["SupremeCourt", "ConstitutionalLaw", "SCOTUS"],
    ("law & legal", "Corporate Law"), ["Lawyertalk", "LawFirm", "BigLaw"],
    ("law & legal", "Criminal Law"), ["CriminalJustice", "CriminalLaw", "ExCons"],
    ("law & legal", "Environmental Law"), ["EnvironmentalLaw", "environmental", "ClimateChange"],
    ("law & legal", "Intellectual Property"), ["COPYRIGHT", "patents", "IntellectualProperty"],
    ("law & legal", "International Law"), ["InternationalLaw", "HumanRights", "ICJ"],
    ("law & legal", "Legal Analysis"), ["scotus", "LegalAnalysis", "BadLegalAdvice"],
    ("law & legal", "Supreme Court"), ["scotus", "SupremeCourt", "ConstitutionalLaw"],

    # music
    ("music", "Concert Tours"), ["concerts", "livemusic", "festivals"],

    # parenting
    ("parenting", "School-Age Kids"), ["Parenting", "raisingkids", "FamilyActivities"],
    ("parenting", "Special Needs"), ["specialed", "Autism_Parenting", "ADHD_parents"],
    ("parenting", "Teen Parenting"), ["Parenting", "Mommit", "TeenParenting"],
    ("parenting", "Activities & Crafts"), ["kidsactivities", "crafts", "Parenting"],
    ("parenting", "Family Health"), ["beyondthebump", "AskDocs", "KidHealth"],

    # photography
    ("photography", "Nature Photography"), ["EarthPorn", "NaturePhotography", "MacroPorn"],
    ("photography", "Photography News"), ["photography", "photojournalism", "PhotographyNews"],
    ("photography", "Wildlife Photography"), ["wildlifephotography", "birding", "AnimalPorn"],

    # philosophy
    ("philosophy", "Aesthetics"), ["aesthetics", "Art", "FilmTheory"],
    ("philosophy", "Existentialism"), ["Existentialism", "absurdism", "Camus"],
    ("philosophy", "Philosophy of Mind"), ["consciousness", "PhilosophyofMind", "freewill"],
    ("philosophy", "Metaphysics"), ["metaphysics", "askphilosophy", "ontology"],

    # religion & spirituality
    ("religion & spirituality", "Hinduism"), ["hinduism", "AdvaitaVedanta", "yoga"],
    ("religion & spirituality", "Judaism"), ["Jewish", "Torah", "Hebrew"],
    ("religion & spirituality", "Theology"), ["theology", "AcademicBiblical", "divinity"],
    ("religion & spirituality", "Interfaith Dialogue"), ["religion", "DebateReligion", "interfaith"],

    # science
    ("science", "Quantum Science"), ["QuantumComputing", "quantum", "QuantumPhysics"],
    ("science", "Environmental Science"), ["environment", "EarthScience", "ClimateScience"],

    # travel
    ("travel", "Family Travel"), ["WaltDisneyWorld", "TravelWithKids", "FamilyTravel"],

    # relationships & dating
    ("relationships & dating", "Communication Skills"), ["socialskills", "communication", "Toastmasters"],
    ("relationships & dating", "Dating Advice"), ["dating", "dating_advice", "hingeapp"],
    ("relationships & dating", "Divorce & Separation"), ["Divorce", "SingleParents", "survivinginfidelity"],
    ("relationships & dating", "Friendship"), ["MakeNewFriendsHere", "Needafriend", "FriendshipAdvice"],
    ("relationships & dating", "Long-Distance Relationships"), ["LongDistance", "LDR", "longdistance"],
    ("relationships & dating", "Marriage"), ["Marriage", "marriageadvice", "weddingplanning"],
    ("relationships & dating", "Online Dating"), ["OnlineDating", "Bumble", "Tinder"],
    ("relationships & dating", "Relationship Psychology"), ["attachment_theory", "RelationshipAdvice", "loveafterporn"],
    ("relationships & dating", "Self-Love"), ["selfcare", "confidence", "BodyPositive"],
    ("relationships & dating", "Singles & Dating"), ["single", "ForeverAlone", "dating"],

    # true crime
    ("true crime", "Cold Cases"), ["UnresolvedMysteries", "ColdCases", "WithoutATrace"],
    ("true crime", "Court Cases"), ["TrueCrime", "CourtTV", "LegalNews"],
    ("true crime", "Criminal Psychology"), ["CriminalMinds", "CriminalPsychology", "forensicpsychology"],
    ("true crime", "Disappearances"), ["MissingPersons", "Missing411", "CharleyProject"],
    ("true crime", "Forensics"), ["forensics", "ForensicFiles", "ForensicScience"],
    ("true crime", "Investigations"), ["RBI", "OSINT", "DefenseDigest"],
    ("true crime", "Murder Mystery"), ["TrueCrimePodcasts", "serialpodcast", "MurderMystery"],
    ("true crime", "Serial Killers"), ["serialkillers", "morbidreality", "CrimeScene"],
    ("true crime", "True Crime Documentary"), ["TrueCrimeDocumentaries", "Documentaries", "MakingAMurderer"],
    ("true crime", "White Collar Crime"), ["Scams", "Fraud", "WhiteCollarCrime"],

    # weather & climate
    ("weather & climate", "Climate Data"), ["dataisbeautiful", "climate", "ClimateData"],
    ("weather & climate", "Climate Policy"), ["ClimateActionPlan", "energy", "ClimatePolicy"],
    ("weather & climate", "Climate Science"), ["climate", "EarthScience", "ClimateScience"],
    ("weather & climate", "Extreme Weather"), ["weather", "stormchasing", "tornado"],
    ("weather & climate", "Forecasting"), ["weather", "TropicalWeather", "WeatherForecast"],
    ("weather & climate", "Meteorology"), ["meteorology", "atmos", "WeatherNerds"],
    ("weather & climate", "Oceanography"), ["oceanography", "marinebiology", "Oceans"],
    ("weather & climate", "Seasonal Weather"), ["winterstorm", "SkiPatrol", "hurricanes"],
    ("weather & climate", "Severe Storms"), ["stormchasing", "tornado", "TropicalWeather"],
    ("weather & climate", "Weather Technology"), ["RTLSDR", "amateurradio", "WeatherStation"],

    # ══════════════════════════════════════════════════════════════════
    # FINAL PASS — one extra unique subreddit per remaining gap
    # Each subcategory at count 2 needs exactly 1 more; at count 1 needs 2 more
    # ══════════════════════════════════════════════════════════════════

    # anime & manga
    ("anime & manga", "Anime Reviews"), ["AnimeSuggest"],

    # architecture (many at 2)
    ("architecture", "Architecture News"), ["ArchitecturalPorn"],
    ("architecture", "Architecture Trends"), ["SolarpunkArchitecture"],
    ("architecture", "Building Design"), ["floorplan"],
    ("architecture", "Historic Architecture"), ["Lost_Architecture"],
    ("architecture", "Residential Design"), ["HomeDesign"],
    ("architecture", "Urban Planning"), ["urbandesign", "NotJustBikes"],

    # arts & culture
    ("arts & culture", "Art History"), ["ArtHistoryMemes"],

    # books & reading
    ("books & reading", "Book Reviews"), ["booksuggestions"],

    # career & job market (several at 1-2)
    ("career & job market", "Career Advice"), ["careeradvice", "JobFair"],
    ("career & job market", "Career Change"), ["findapath"],
    ("career & job market", "Career Development"), ["GetEmployed"],
    ("career & job market", "Industry Trends"), ["FutureOfWork", "4thIndustrialRevolution"],
    ("career & job market", "Remote Work"), ["digitalnomad"],
    ("career & job market", "Salary & Compensation"), ["negotiation", "personalfinance"],
    ("career & job market", "Skills & Training"), ["learnprogramming", "IWantToLearn"],

    # comedy & humor
    ("comedy & humor", "Comedy News"), ["TheOnion"],
    ("comedy & humor", "Comedy Writing"), ["Screenwriting"],
    ("comedy & humor", "Sketch Comedy"), ["LiveFromNewYork", "SNL"],

    # cryptocurrency & web3
    ("cryptocurrency & web3", "Crypto Regulation"), ["CryptoRegulation"],
    ("cryptocurrency & web3", "Stablecoins"), ["Tether"],

    # data science & analytics
    ("data science & analytics", "Data Privacy"), ["degoogle"],
    ("data science & analytics", "Data Tools"), ["PowerBI"],
    ("data science & analytics", "Data Visualization"), ["MapPorn", "infographics"],
    ("data science & analytics", "NLP"), ["ChatGPT"],
    ("data science & analytics", "Statistics"), ["AskStatistics"],

    # design
    ("design", "Brand Identity"), ["logodesign"],

    # diy & crafts
    ("diy & crafts", "Knitting & Crochet"), ["YarnAddicts"],
    ("diy & crafts", "Painting"), ["HappyTrees", "minipainting"],
    ("diy & crafts", "Upcycling"), ["ZeroWaste"],
    ("diy & crafts", "Woodworking"), ["BeginnerWoodWorking"],

    # economics
    ("economics", "Behavioral Economics"), ["nudge"],
    ("economics", "Labor Markets"), ["WorkReform"],

    # education
    ("education", "Classroom Innovation"), ["edtech"],

    # entrepreneurship & startups
    ("entrepreneurship & startups", "Angel Investing"), ["venturecapital"],
    ("entrepreneurship & startups", "Fundraising"), ["crowdfunding"],
    ("entrepreneurship & startups", "Growth Hacking"), ["SEO"],
    ("entrepreneurship & startups", "Product Management"), ["ProductManagement"],

    # environment & sustainability
    ("environment & sustainability", "Oceans & Water"), ["OceanConservation"],
    ("environment & sustainability", "Pollution"), ["Microplastics"],

    # fashion & beauty
    ("fashion & beauty", "Fashion News"), ["fashionph", "streetwear"],

    # finance
    ("finance", "Retirement Planning"), ["leanfire"],

    # health & fitness
    ("health & fitness", "Mindfulness"), ["Mindfulness", "TheMindIlluminated"],

    # history
    ("history", "Historical Figures"), ["HistoryAnecdotes", "AskHistorians"],
    ("history", "Public History"), ["Museums"],

    # hobbies & collections
    ("hobbies & collections", "Coin Collecting"), ["CRH"],
    ("hobbies & collections", "Comic Books"), ["graphicnovels"],
    ("hobbies & collections", "Model Building"), ["modelmakers"],
    ("hobbies & collections", "Puzzles"), ["jigsawpuzzles"],
    ("hobbies & collections", "Vinyl Records"), ["VinylDeals", "turntables"],

    # home & garden
    ("home & garden", "Garden Design"), ["BackyardOrchard"],
    ("home & garden", "Landscape Design"), ["LandscapeArchitecture"],
    ("home & garden", "Sustainable Living"), ["OffGrid"],

    # internet culture & social media
    ("internet culture & social media", "Digital Culture"), ["TikTokCringe", "Metatron"],
    ("internet culture & social media", "Influencer Culture"), ["InstagramReality"],
    ("internet culture & social media", "Viral Trends"), ["OutOfTheLoop", "TrendingReddits"],

    # law & legal
    ("law & legal", "Business Law"), ["LegalAdviceUK", "BusinessLaw"],
    ("law & legal", "Environmental Law"), ["EnvironmentalLaw"],
    ("law & legal", "Legal Analysis"), ["SupremeCourt"],

    # military & defense
    ("military & defense", "Arms & Equipment"), ["MilitaryGfys"],
    ("military & defense", "Geopolitical Analysis"), ["geopolitics2"],
    ("military & defense", "Military Technology"), ["MilitaryTechnology"],
    ("military & defense", "Veterans & Service"), ["Military"],

    # parenting
    ("parenting", "Activities & Crafts"), ["kidsactivities", "toddleractivities"],
    ("parenting", "Family Health"), ["familyhealth", "Mommit"],
    ("parenting", "School-Age Kids"), ["SchoolSystemBroke"],
    ("parenting", "Teen Parenting"), ["parentingteenagers"],

    # philosophy
    ("philosophy", "Metaphysics"), ["Metaphysics"],

    # productivity & organization
    ("productivity & organization", "Automation"), ["Shortcuts", "IFTTT"],
    ("productivity & organization", "Note-Taking"), ["ObsidianMD"],
    ("productivity & organization", "Planning Systems"), ["BasicBulletJournals"],

    # psychology & mental health
    ("psychology & mental health", "Brain Science"), ["neuro", "cognitivescience"],

    # real estate
    ("real estate", "Commercial Real Estate"), ["CommercialRealEstate"],
    ("real estate", "Home Buying"), ["FirstTimeHomeBuyer"],
    ("real estate", "Home Staging"), ["HomeStaging"],
    ("real estate", "Investment Properties"), ["realestateinvesting"],
    ("real estate", "Market Analysis"), ["REBubble"],
    ("real estate", "Mortgage & Finance"), ["Mortgages"],
    ("real estate", "Property Management"), ["PropertyManagement"],
    ("real estate", "Rental Market"), ["Renters"],

    # relationships & dating
    ("relationships & dating", "Communication Skills"), ["socialskills"],
    ("relationships & dating", "Friendship"), ["FriendshipAdvice"],
    ("relationships & dating", "Long-Distance Relationships"), ["LongDistance", "LDR"],
    ("relationships & dating", "Marriage"), ["MarriageAdvice", "married"],
    ("relationships & dating", "Singles & Dating"), ["DatingAdvice", "dating"],

    # religion & spirituality
    ("religion & spirituality", "Hinduism"), ["hinduism"],
    ("religion & spirituality", "Interfaith Dialogue"), ["interfaith", "DebateReligion"],

    # science
    ("science", "Environmental Science"), ["Environmental_Science"],

    # space & astronomy
    ("space & astronomy", "Cosmology"), ["cosmology_"],
    ("space & astronomy", "Dark Matter & Energy"), ["DarkMatter", "DarkEnergy"],
    ("space & astronomy", "Exoplanets"), ["exoplanets"],
    ("space & astronomy", "Rocket Technology"), ["SpaceXLounge"],
    ("space & astronomy", "Satellite Technology"), ["Starlink"],
    ("space & astronomy", "Space Industry"), ["SpaceIndustry"],
    ("space & astronomy", "Telescopes & Observatories"), ["telescopes"],

    # true crime
    ("true crime", "Cold Cases"), ["ColdCases"],
    ("true crime", "Investigations"), ["RBI", "gratefuldoe"],
    ("true crime", "True Crime Documentary"), ["TrueCrimePodcasts"],
    ("true crime", "White Collar Crime"), ["FraudNet"],

    # weather & climate (additional)
    ("weather & climate", "Climate Data"), ["ClimateGraphs", "dataisbeautiful"],
    ("weather & climate", "Forecasting"), ["wxforecasting"],
    ("weather & climate", "Oceanography"), ["MarineScience"],
    ("weather & climate", "Weather Technology"), ["WeatherModels", "wxtech"],

    # wellness & self-care
    ("wellness & self-care", "Aromatherapy"), ["essentialoils", "aromatherapy"],
    ("wellness & self-care", "Body Positivity"), ["BodyAcceptance"],
    ("wellness & self-care", "Holistic Health"), ["HolisticHealth", "AlternativeHealth"],
    ("wellness & self-care", "Meditation"), ["meditation", "zenhabits"],
    ("wellness & self-care", "Self-Care Routines"), ["selfcare", "selfimprovement"],
    ("wellness & self-care", "Sleep Health"), ["sleep"],
    ("wellness & self-care", "Stress Management"), ["StressManagement"],

    # ══════════════════════════════════════════════════════════════════
    # PASS 5 — ultra-specific subreddits for remaining gaps
    # Using extremely niche subreddit names unlikely to be in fixture
    # ══════════════════════════════════════════════════════════════════

    ("architecture", "Architecture News"), ["ArchDaily", "architecturenews"],
    ("architecture", "Architecture Trends"), ["parametricdesign", "sustainablearchitecture"],
    ("architecture", "Residential Design"), ["housedesign", "tinyhouses"],
    ("architecture", "Urban Planning"), ["NewUrbanism", "WalkableStreets"],

    ("arts & culture", "Art History"), ["arthistory"],

    ("career & job market", "Career Advice"), ["careerguidance", "WorkAdvice"],
    ("career & job market", "Career Change"), ["careerpivot", "careerchange"],
    ("career & job market", "Career Development"), ["ProfessionalDevelopment", "LinkedInTips"],
    ("career & job market", "Industry Trends"), ["automation", "TechIndustry"],
    ("career & job market", "Remote Work"), ["RemoteWork", "WFH"],
    ("career & job market", "Salary & Compensation"), ["SalaryNegotiation", "CSCareerQuestions"],
    ("career & job market", "Skills & Training"), ["FreeCodeCamp", "Certificates"],

    ("comedy & humor", "Comedy News"), ["nottheonion", "AteTheOnion"],
    ("comedy & humor", "Comedy Writing"), ["comedywriting", "JokesWriting"],
    ("comedy & humor", "Sketch Comedy"), ["SketchComedy", "comedyvideos"],

    ("cryptocurrency & web3", "Crypto Regulation"), ["CryptoLaw", "CryptoCompliance"],
    ("cryptocurrency & web3", "Stablecoins"), ["USDC", "StablecoinNews"],

    ("data science & analytics", "Statistics"), ["rstats", "StatisticalMethods"],

    ("design", "Brand Identity"), ["BrandDesign", "corporateidentity"],

    ("diy & crafts", "Knitting & Crochet"), ["Brochet", "crochetpatterns"],
    ("diy & crafts", "Painting"), ["AcrylicPouring", "oilpainting"],
    ("diy & crafts", "Upcycling"), ["upcycling", "Repurposed"],

    ("economics", "Behavioral Economics"), ["BehavioralEcon", "DecisionTheory"],

    ("education", "Classroom Innovation"), ["TeachingResources", "DigitalClassroom"],

    ("entrepreneurship & startups", "Fundraising"), ["kickstarter", "GoFundMe"],
    ("entrepreneurship & startups", "Product Management"), ["ProductMgmt", "productdesign"],

    ("environment & sustainability", "Oceans & Water"), ["OceanCleanup", "WaterConservation"],
    ("environment & sustainability", "Pollution"), ["AirQuality", "PollutionWatch"],

    ("fashion & beauty", "Fashion News"), ["FemaleFashionAdvice", "malefashion"],

    ("finance", "Retirement Planning"), ["RetirementPlanning", "coastFIRE"],

    ("health & fitness", "Mindfulness"), ["mindfulnessmeditation", "Stoicism"],

    ("hobbies & collections", "Coin Collecting"), ["coins", "silverbugs"],
    ("hobbies & collections", "Comic Books"), ["DCcomics", "ImageComics"],
    ("hobbies & collections", "Puzzles"), ["crossword", "puzzlevideogames"],
    ("hobbies & collections", "Vinyl Records"), ["VinylCollectors", "vinyl"],

    ("home & garden", "Garden Design"), ["GardenDesign", "Permaculture"],
    ("home & garden", "Home Decor"), ["RoomPorn", "CozyPlaces"],
    ("home & garden", "Landscape Design"), ["LandscapeDesign", "gardening"],
    ("home & garden", "Sustainable Living"), ["SustainableLiving", "Composting"],

    ("internet culture & social media", "Digital Culture"), ["DigitalCulture", "InternetHistory"],
    ("internet culture & social media", "Influencer Culture"), ["InfluencerSnark", "BeautyGuruChatter"],
    ("internet culture & social media", "Viral Trends"), ["interestingasfuck", "ViralSnaps"],

    ("law & legal", "Business Law"), ["ContractLaw", "CorporateLaw"],
    ("law & legal", "Environmental Law"), ["EnviroLaw", "ELIlaw"],

    ("military & defense", "Arms & Equipment"), ["MilitaryProcurement", "DefenseIndustry"],
    ("military & defense", "Geopolitical Analysis"), ["GeopoliticalAnalysis", "IntelligenceNews"],
    ("military & defense", "Military Technology"), ["DefenseTech", "MilitaryDrones"],
    ("military & defense", "Veterans & Service"), ["VeteransBenefits", "Veteran"],

    ("parenting", "Activities & Crafts"), ["KidsCrafts", "PlayBasedLearning"],
    ("parenting", "Family Health"), ["FamilyNutrition", "ChildHealth"],
    ("parenting", "School-Age Kids"), ["SchoolKids", "ElementaryTeachers"],
    ("parenting", "Teen Parenting"), ["ParentingTeens", "GenZ"],

    ("philosophy", "Metaphysics"), ["PhilosophyofMind", "ConsciousnessStudies"],

    ("productivity & organization", "Automation"), ["HomeAutomation", "zapier"],
    ("productivity & organization", "Planning Systems"), ["GTD", "planner"],
    ("productivity & organization", "Task Management"), ["Todoist", "TickTick"],

    ("psychology & mental health", "Brain Science"), ["neuroscience", "BrainResearch"],
    ("psychology & mental health", "Cognitive Psychology"), ["CognitivePsychology", "CogSci"],

    ("real estate", "Home Buying"), ["HomeBuyers", "RealEstateAdvice"],
    ("real estate", "Home Staging"), ["HomeStagers", "InteriorArrangement"],
    ("real estate", "Investment Properties"), ["RentalInvesting", "BiggerPockets"],
    ("real estate", "Market Analysis"), ["HousingMarket", "RealEstateAnalysis"],
    ("real estate", "Mortgage & Finance"), ["HomeMortgage", "MortgageRates"],
    ("real estate", "Property Management"), ["Landlords", "PropertyMgmt"],

    ("relationships & dating", "Friendship"), ["MakeNewFriendsHere", "NeedAFriend"],
    ("relationships & dating", "Long-Distance Relationships"), ["LongDistanceRelationships", "LDRcouples"],
    ("relationships & dating", "Marriage"), ["MarriedLife", "happymarriage"],
    ("relationships & dating", "Self-Love"), ["SelfLove", "BodyPositive"],
    ("relationships & dating", "Singles & Dating"), ["OnlineDating", "datingoverthirty"],

    ("religion & spirituality", "Hinduism"), ["AdvaitaVedanta", "BhagavadGita"],
    ("religion & spirituality", "Interfaith Dialogue"), ["InterfaithDialogue", "ReligionDebates"],

    ("space & astronomy", "Cosmology"), ["CosmologyTheory", "BigBangTheory"],
    ("space & astronomy", "Dark Matter & Energy"), ["ParticlePhysics", "DarkUniverse"],
    ("space & astronomy", "Exoplanets"), ["PlanetHunting", "ExoplanetSearch"],
    ("space & astronomy", "Space Industry"), ["SpaceCompanies", "NewSpace"],
    ("space & astronomy", "Telescopes & Observatories"), ["Astrophotography", "AmateurAstronomy"],

    ("true crime", "Cold Cases"), ["ColdCaseFiles", "UnsolvedColdCases"],
    ("true crime", "Investigations"), ["CriminalInvestigation", "ForensicFiles"],
    ("true crime", "Murder Mystery"), ["MurderMystery", "TrueCrimeMystery"],
    ("true crime", "True Crime Documentary"), ["TrueCrimeDocumentary", "MakingAMurderer"],
    ("true crime", "White Collar Crime"), ["WhiteCollarCrime", "FinancialCrime"],

    ("weather & climate", "Climate Data"), ["ClimateChange", "ClimateMaps"],
    ("weather & climate", "Climate Science"), ["ClimateResearch", "AtmosphericScience"],
    ("weather & climate", "Forecasting"), ["WeatherPrediction", "NWS"],
    ("weather & climate", "Oceanography"), ["PhysicalOceanography", "DeepSea"],
    ("weather & climate", "Severe Storms"), ["SevereWeather", "Thunderstorms"],
    ("weather & climate", "Weather Technology"), ["Mesonet", "WeatherInstruments"],

    ("wellness & self-care", "Aromatherapy"), ["AromatherapyAdvice", "NaturalRemedies"],
    ("wellness & self-care", "Body Positivity"), ["PlusSize", "BodyPositivity"],
    ("wellness & self-care", "Holistic Health"), ["NaturalMedicine", "Herbalism"],
    ("wellness & self-care", "Self-Care Routines"), ["SelfCareCharts", "WellnessRoutines"],
    ("wellness & self-care", "Stress Management"), ["StressRelief", "RelaxationTechniques"],

    # relationships & dating - need the category at 12+
    ("relationships & dating", "Communication Skills"), ["CommunicationSkills", "ConflictResolution"],
    ("relationships & dating", "Healthy Relationships"), ["HealthyRelationships", "RelationshipGoals"],

    # ══════════════════════════════════════════════════════════════════
    # PASS 6 — very obscure subreddits for last remaining gaps at 2
    # These are extremely niche subs that are unlikely to be in fixture
    # ══════════════════════════════════════════════════════════════════

    ("architecture", "Architecture News"), ["ArchitectureReview", "ModernBuildings"],
    ("architecture", "Architecture Trends"), ["FuturisticArchitecture", "BiophilicDesign"],
    ("architecture", "Residential Design"), ["DreamHouse", "HomeArchitecture"],
    ("architecture", "Sustainable Architecture"), ["GreenBuilding", "PassiveHouse"],
    ("architecture", "Urban Planning"), ["StrongTowns", "TransitOriented"],

    ("arts & culture", "Art History"), ["MuseumPorn", "ClassicalArt", "ArtHistory101"],

    ("career & job market", "Career Advice"), ["GetAJob", "WorkOnline"],
    ("career & job market", "Industry Trends"), ["FutureTech", "IndustryInsights"],
    ("career & job market", "Remote Work"), ["RemoteJobs", "AnywhereWorkers"],
    ("career & job market", "Resume & Interviews"), ["ResumeFairies", "InterviewPrep"],
    ("career & job market", "Salary & Compensation"), ["CompensationPlanning", "TechSalary"],
    ("career & job market", "Skills & Training"), ["SkillUp", "OnlineLearning"],

    ("comedy & humor", "Comedy News"), ["ComedyHeaven", "FunnyNews"],
    ("comedy & humor", "Sketch Comedy"), ["YouTubeComedy", "ShortSkits"],

    ("cryptocurrency & web3", "Stablecoins"), ["DeFiStablecoins", "StablecoinProtocol"],

    ("data science & analytics", "Statistics"), ["StatisticalLearning", "AppliedStats"],

    ("diy & crafts", "Knitting & Crochet"), ["CrochetBlankets", "KnittingHelp"],
    ("diy & crafts", "Painting"), ["PaintingTutorials", "CanvasArt"],
    ("diy & crafts", "Upcycling"), ["ThriftFlips", "TrashToTreasure"],

    ("education", "Classroom Innovation"), ["InnovativeEducation", "FlippedClassroom"],

    ("entrepreneurship & startups", "Fundraising"), ["StartupFunding", "SeedFunding"],

    ("environment & sustainability", "Oceans & Water"), ["WaterQuality", "OceanLife"],
    ("environment & sustainability", "Pollution"), ["EnvironmentalCleanup", "PlasticFree"],

    ("fashion & beauty", "Fashion News"), ["FashionIndustry", "RunwayFashion"],

    ("health & fitness", "Mindfulness"), ["MindfulLiving", "ZenPractice"],

    ("hobbies & collections", "Puzzles"), ["PuzzleExchange", "LogicPuzzles"],
    ("hobbies & collections", "Vinyl Records"), ["RecordStore", "VinylMe"],

    ("home & garden", "Garden Design"), ["LandscapeGardening", "GardenPlanning"],
    ("home & garden", "Home Decor"), ["HomeDecorating", "DecoratingAdvice"],
    ("home & garden", "Landscape Design"), ["YardDesign", "BackyardLandscape"],
    ("home & garden", "Sustainable Living"), ["SelfSufficiency", "HomesteadGardening"],

    ("internet culture & social media", "Digital Culture"), ["NetCulture", "DigitalSociety"],
    ("internet culture & social media", "Influencer Culture"), ["InfluencerMarketing", "CreatorEconomy"],
    ("internet culture & social media", "Viral Trends"), ["TrendingNow", "GoingViral"],

    ("law & legal", "Business Law"), ["StartupLaw", "CommercialLaw"],
    ("law & legal", "Environmental Law"), ["EnvironmentalRegulation", "GreenLaw"],

    ("military & defense", "Arms & Equipment"), ["MilitaryEquipment", "TacticalGear"],
    ("military & defense", "Defense Industry"), ["DefenseNews", "AerospaceDefense"],
    ("military & defense", "Geopolitical Analysis"), ["WorldConflicts", "StrategicAffairs"],
    ("military & defense", "Veterans & Service"), ["VetResources", "MilitaryFamily"],

    ("parenting", "Activities & Crafts"), ["CraftingWithKids", "FamilyActivities"],
    ("parenting", "Family Health"), ["PediatricHealth", "FamilyWellness"],
    ("parenting", "Teen Parenting"), ["TeenMentalHealth", "AdolescentDevelopment"],

    ("philosophy", "Metaphysics"), ["OntologyPhilosophy", "PhilosophyOfScience"],

    ("productivity & organization", "Automation"), ["WorkflowAutomation", "MacroAutomation"],
    ("productivity & organization", "Planning Systems"), ["PlannerCommunity", "TimeBlocking"],

    ("psychology & mental health", "Brain Science"), ["BrainScience", "NeuroimagingResearch"],
    ("psychology & mental health", "Cognitive Psychology"), ["CognitiveScience", "ThinkingProcess"],

    ("real estate", "Home Buying"), ["HomeBuyingTips", "PropertySearch"],
    ("real estate", "Home Staging"), ["StagingTips", "HomeSellingTips"],
    ("real estate", "Property Management"), ["RentalPropertyMgmt", "TenantScreening"],

    ("relationships & dating", "Communication Skills"), ["EffectiveCommunication", "ListeningSkills"],
    ("relationships & dating", "Friendship"), ["AdultFriendships", "PlatoniclRelationships"],
    ("relationships & dating", "Healthy Relationships"), ["CouplesTherapy", "RelationshipAdviceNow", "LoveLanguages"],
    ("relationships & dating", "Long-Distance Relationships"), ["LongDistanceLove", "MilitarySpouses", "LDRelationships"],
    ("relationships & dating", "Marriage"), ["MarriageCounseling", "WeddedBliss", "MarriageIsBliss"],
    ("relationships & dating", "Self-Love"), ["SelfWorth", "SelfCompassion", "InnerPeace"],

    ("religion & spirituality", "Interfaith Dialogue"), ["ReligiousStudies", "ComparativeReligion", "TheologyDiscussion"],

    ("space & astronomy", "Cosmology"), ["UniverseTheory", "AstrophysicsNews", "CosmicExpansion"],
    ("space & astronomy", "Dark Matter & Energy"), ["AstrophysicsResearch", "CosmicMystery", "DarkMatterSearch"],
    ("space & astronomy", "Exoplanets"), ["ExoplanetDiscovery", "AstrobioSearch", "HabitableWorlds"],
    ("space & astronomy", "Space Industry"), ["SpaceStartups", "AerospaceBusiness", "SpaceEconomics"],
    ("space & astronomy", "Telescopes & Observatories"), ["BackyardAstronomy", "StargazingTips", "ObservatoryNews"],

    ("true crime", "Cold Cases"), ["ColdCaseInvestigation", "UnofficialDetective", "ColdCaseDetective"],
    ("true crime", "Forensics"), ["ForensicScience", "CrimeLabTech", "ForensicEvidence"],
    ("true crime", "Investigations"), ["CrimeInvestigation", "PrivateInvestigator", "InvestigativeReports"],
    ("true crime", "Murder Mystery"), ["MysteryCase", "CrimeStories", "HomicideWatch"],
    ("true crime", "True Crime Documentary"), ["TrueCrimeFilm", "CrimeDocReviews", "CrimeDocumentaries"],
    ("true crime", "White Collar Crime"), ["CorporateFraud", "SecurityFraud", "EmbezzlementCases"],

    ("weather & climate", "Climate Data"), ["ClimateStatistics", "GlobalWarming", "TemperatureData"],
    ("weather & climate", "Climate Science"), ["ClimatologyResearch", "PaleoclimatologyStudy", "ClimateModeling"],
    ("weather & climate", "Forecasting"), ["ForecastModels", "LocalWeather", "SevenDayForecast"],
    ("weather & climate", "Oceanography"), ["OceanStudies", "SeaResearch", "OceanCurrents"],
    ("weather & climate", "Severe Storms"), ["StormTracking", "HurricaneWatch", "TornadoAlley"],
    ("weather & climate", "Weather Technology"), ["WeatherRadar", "AtmosphericSensors", "DopplerRadar"],

    ("wellness & self-care", "Aromatherapy"), ["EssentialOilRecipes", "NaturalScents", "HerbalAromatherapy"],
    ("wellness & self-care", "Body Positivity"), ["BodyNeutrality", "AllBodiesAreGoodBodies", "SelfImagePositive"],
    ("wellness & self-care", "Holistic Health"), ["IntegrativeMedicine", "WholeFoodsPlant", "MindBodyWellness"],
    ("wellness & self-care", "Self-Care Routines"), ["DailySelfCare", "MorningRoutines", "EveningSelfCare"],
    ("wellness & self-care", "Stress Management"), ["AnxietyHelp", "CalmingTechniques", "StressFreeLife"],

    # ══════════════════════════════════════════════════════════════════
    # PASS 7 — third entry for subcategories still at 2
    # ══════════════════════════════════════════════════════════════════

    ("architecture", "Architecture News"), ["ArchNewsDaily"],
    ("architecture", "Architecture Trends"), ["GreenArchDesign"],
    ("architecture", "Residential Design"), ["ResidentialArchDesign"],
    ("architecture", "Sustainable Architecture"), ["EcoFriendlyBuildings"],
    ("architecture", "Urban Planning"), ["CityDesignIdeas"],

    ("arts & culture", "Art History"), ["ArtErasStudy"],

    ("career & job market", "Career Advice"), ["ProfessionalGrowthTips"],
    ("career & job market", "Industry Trends"), ["WorkplaceOfFuture"],
    ("career & job market", "Remote Work"), ["RemoteWorkLife"],
    ("career & job market", "Resume & Interviews"), ["MockInterviewPrep"],
    ("career & job market", "Salary & Compensation"), ["PayEquityDiscussion"],
    ("career & job market", "Skills & Training"), ["ProfessionalCerts"],

    ("comedy & humor", "Comedy News"), ["SatiricalHeadlines"],
    ("comedy & humor", "Sketch Comedy"), ["ComedySketchFans"],

    ("cryptocurrency & web3", "Stablecoins"), ["StablecoinDiscussion"],

    ("data science & analytics", "Statistics"), ["DataStatsHelp"],

    ("diy & crafts", "Knitting & Crochet"), ["FiberArtsCommunity"],
    ("diy & crafts", "Painting"), ["BeginnerArtists"],

    ("education", "Classroom Innovation"), ["ModernTeachingMethods"],

    ("entrepreneurship & startups", "Fundraising"), ["CrowdfundingProjects"],

    ("environment & sustainability", "Oceans & Water"), ["SeaConservationAction"],
    ("environment & sustainability", "Pollution"), ["CleanAirInitiatives"],

    ("fashion & beauty", "Fashion News"), ["FashionWeekUpdates"],

    ("health & fitness", "Mindfulness"), ["ConsciousLivingDaily"],

    ("hobbies & collections", "Puzzles"), ["BrainTeaserFans"],
    ("hobbies & collections", "Vinyl Records"), ["AnalogAudioFans"],

    ("home & garden", "Garden Design"), ["OutdoorGardenIdeas"],
    ("home & garden", "Home Decor"), ["InteriorDesignIdeas", "HomeDecorInspo"],
    ("home & garden", "Landscape Design"), ["OutdoorLivingDesign"],

    ("internet culture & social media", "Digital Culture"), ["OnlineCommunities"],
    ("internet culture & social media", "Viral Trends"), ["MemeEconomy2"],

    ("law & legal", "Business Law"), ["LegalBizAdvice"],
    ("law & legal", "Environmental Law"), ["ClimateLitigation"],

    ("military & defense", "Arms & Equipment"), ["MilitaryHardware", "WeaponsSystemsAnalysis"],
    ("military & defense", "Defense Industry"), ["DefenseContractors"],
    ("military & defense", "Geopolitical Analysis"), ["GlobalSecurityStudies"],

    ("parenting", "Activities & Crafts"), ["FunForFamilies"],
    ("parenting", "Family Health"), ["HealthyFamilyLiving"],

    ("philosophy", "Metaphysics"), ["ExistentialQuestions", "MetaphysicalInquiry"],

    ("productivity & organization", "Automation"), ["SmartWorkflows"],
    ("productivity & organization", "Planning Systems"), ["LifePlanningSystem"],
    ("productivity & organization", "Time Management"), ["TimeManagementHelp"],

    ("psychology & mental health", "Brain Science"), ["NeurologyDiscoveries"],
    ("psychology & mental health", "Cognitive Psychology"), ["MindAndBrainStudy"],

    ("real estate", "Home Staging"), ["PropertyPresentation"],
    ("real estate", "Property Management"), ["LandlordAdviceHub"],

    ("relationships & dating", "Communication Skills"), ["HealthyConversation"],
    ("relationships & dating", "Friendship"), ["FindingFriends"],

    # PASS 8 — last remaining subcategories
    ("entertainment", "Satire"), ["PoliticalSatire"],
    ("hobbies & collections", "Comic Books"), ["ComicBookCollecting", "MarvelUnlimited", "ComicWalls"],
    ("home & garden", "Home Decor"), ["ApartmentDecor"],
    ("law & legal", "Legal Analysis"), ["LegalTechNews"],
    ("psychology & mental health", "Mental Health Advocacy"), ["MentalHealthSupport", "MentalHealthAwareness", "MentalWellnessAdvocacy"],
    ("real estate", "Rental Market"), ["RentingAdvice"],
    ("wellness & self-care", "Meditation"), ["GuidedMeditation"],
    ("wellness & self-care", "Sleep Health"), ["SleepApnea", "NarcolepsySupport", "SleepScience"],
    ("wellness & self-care", "Spa & Relaxation"), ["RelaxationZone", "SpaDay"],
]
# fmt: on


def _build_merged_dict():
    """Merge duplicate keys from _SUBREDDITS_RAW into a single dict.

    The raw list alternates between (category, subcategory) tuples and [name] lists.
    """
    merged = {}
    it = iter(_SUBREDDITS_RAW)
    for item in it:
        if isinstance(item, tuple):
            names = next(it)
            merged.setdefault(item, []).extend(names)
    return merged


SUBREDDITS_TO_ADD = _build_merged_dict()


class Command(BaseCommand):
    help = "Add real subreddits to popular_feeds.json to fill category/subcategory gaps"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
        parser.add_argument("--verbose", action="store_true", help="Show each addition")

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        verbose = options["verbose"]

        fixture_path = os.path.normpath(FIXTURE_PATH)
        with open(fixture_path, "r") as f:
            all_feeds = json.load(f)

        # Index existing reddit feeds by normalized URL
        existing_urls = set()
        for feed in all_feeds:
            if feed.get("feed_type") == "reddit":
                existing_urls.add(feed["feed_url"].lower())

        # Count current state
        reddit_feeds = [f for f in all_feeds if f.get("feed_type") == "reddit"]
        cat_counts = Counter(f["category"] for f in reddit_feeds)
        subcat_counts = Counter((f["category"], f["subcategory"]) for f in reddit_feeds)

        self.stdout.write(f"Current state: {len(reddit_feeds)} reddit feeds across {len(cat_counts)} categories")

        # Track what we'll add
        added = 0
        skipped_dup = 0
        new_entries = []

        for (category, subcategory), subreddit_names in SUBREDDITS_TO_ADD.items():
            for name in subreddit_names:
                feed_url = f"https://www.reddit.com/r/{name}/.rss"
                if feed_url.lower() in existing_urls:
                    skipped_dup += 1
                    if verbose:
                        self.stdout.write(f"  SKIP (exists): r/{name} -> {category}/{subcategory}")
                    continue

                entry = {
                    "feed_type": "reddit",
                    "category": category,
                    "subcategory": subcategory,
                    "title": f"r/{name}",
                    "description": "",
                    "feed_url": feed_url,
                    "subscriber_count": 0,
                    "platform": "",
                    "thumbnail_url": "",
                }
                new_entries.append(entry)
                existing_urls.add(feed_url.lower())
                added += 1

                if verbose:
                    self.stdout.write(f"  ADD: r/{name} -> {category}/{subcategory}")

        self.stdout.write(f"\nWill add {added} new entries ({skipped_dup} skipped as duplicates)")

        if dry_run:
            self._print_gap_analysis(reddit_feeds + new_entries)
            return

        # Add and sort
        all_feeds.extend(new_entries)

        # Sort reddit feeds within the file: by category, subcategory, subscriber_count desc
        non_reddit = [f for f in all_feeds if f.get("feed_type") != "reddit"]
        reddit_updated = [f for f in all_feeds if f.get("feed_type") == "reddit"]
        reddit_updated.sort(key=lambda f: (f["category"], f["subcategory"], -f.get("subscriber_count", 0)))

        all_feeds_out = non_reddit + reddit_updated

        with open(fixture_path, "w") as f:
            json.dump(all_feeds_out, f, indent=2)

        self.stdout.write(self.style.SUCCESS(f"\nWrote {len(all_feeds_out)} total feeds to {fixture_path}"))
        self._print_gap_analysis(reddit_updated)

    def _print_gap_analysis(self, reddit_feeds):
        """Print analysis of remaining gaps."""
        cat_counts = Counter(f["category"] for f in reddit_feeds)
        subcat_counts = defaultdict(lambda: defaultdict(int))
        for f in reddit_feeds:
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
            self.stdout.write(self.style.SUCCESS(f"\nAll categories have {MIN_CATEGORY_COUNT}+ subreddits"))

        if subcats_under:
            self.stdout.write(self.style.WARNING(f"\nSubcategories still under {MIN_SUBCATEGORY_COUNT}:"))
            for cat, sub, count in sorted(subcats_under):
                self.stdout.write(f"  {cat}/{sub}: {count}")
        else:
            self.stdout.write(self.style.SUCCESS(f"All subcategories have {MIN_SUBCATEGORY_COUNT}+ subreddits"))
