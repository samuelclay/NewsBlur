import logging
import os

# ===================
# = Server Settings =
# ===================

ADMINS = (("Samuel Clay", "samuel@newsblur.com"),)

SERVER_EMAIL = "server@newsblur.com"
HELLO_EMAIL = "hello@newsblur.com"
NEWSBLUR_URL = "https://localhost"
PUSH_DOMAIN = "localhost"
SESSION_COOKIE_DOMAIN = "localhost"

# ===================
# = Global Settings =
# ===================

DOCKERBUILD = True
DEBUG = False
# DEBUG = True

# DEBUG_ASSETS controls JS/CSS asset packaging. Turning this off requires you to run
# `./manage.py collectstatic` first. Turn this on for development so you can see
# changes in your JS/CSS.
DEBUG_ASSETS = False  # Make sure to run `./manage.py collectstatic` first
DEBUG_ASSETS = True

# DEBUG_QUERIES controls the output of the database query logs. Can be rather verbose
# but is useful to catch slow running queries. A summary is also useful in cutting
# down verbosity.
DEBUG_QUERIES = DEBUG
DEBUG_QUERIES_SUMMARY_ONLY = True
# DEBUG_QUERIES_SUMMARY_ONLY = False

MEDIA_URL = "/media/"
IMAGES_URL = "/imageproxy"
# Uncomment below to debug iOS/Android widget
# IMAGES_URL = 'https://haproxy/imageproxy'
SECRET_KEY = "YOUR SECRET KEY"
AUTO_PREMIUM_NEW_USERS = True
AUTO_PREMIUM_ARCHIVE_NEW_USERS = True
AUTO_PREMIUM_PRO_NEW_USERS = True
AUTO_PREMIUM = True
# AUTO_PREMIUM = False
if not AUTO_PREMIUM:
    AUTO_PREMIUM_NEW_USERS = False
    AUTO_PREMIUM_ARCHIVE_NEW_USERS = False
    AUTO_PREMIUM_PRO_NEW_USERS = False
AUTO_ENABLE_NEW_USERS = True
ENFORCE_SIGNUP_CAPTCHA = False
ENABLE_PUSH = False

PRO_MINUTES_BETWEEN_FETCHES = 15

CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://db_redis:6579/6",
    },
}

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Set this to the username that is shown on the homepage to unauthenticated users.
HOMEPAGE_USERNAME = "popular"

# Google Reader OAuth API Keys
OAUTH_KEY = "www.example.com"
OAUTH_SECRET = "SECRET_KEY_FROM_GOOGLE"

S3_ACCESS_KEY = "XXX"
S3_SECRET = "SECRET"
S3_BACKUP_BUCKET = "newsblur-backups"
S3_PAGES_BUCKET_NAME = "pages-XXX.newsblur.com"
S3_ICONS_BUCKET_NAME = "icons-XXX.newsblur.com"
S3_AVATARS_BUCKET_NAME = "avatars-XXX.newsblur.com"

STRIPE_SECRET = "YOUR-SECRET-API-KEY"
STRIPE_PUBLISHABLE = "YOUR-PUBLISHABLE-API-KEY"

# ===============
# = Social APIs =
# ===============

FACEBOOK_APP_ID = "111111111111111"
FACEBOOK_SECRET = "99999999999999999999999999999999"
TWITTER_CONSUMER_KEY = "ooooooooooooooooooooo"
TWITTER_CONSUMER_SECRET = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
YOUTUBE_API_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# =============
# = Databases =
# =============

DATABASES = {
    "default": {
        "NAME": "newsblur",
        "ENGINE": "django_prometheus.db.backends.postgresql",
        #'ENGINE': 'django.db.backends.mysql',
        "USER": "newsblur",
        "PASSWORD": "newsblur",
        "HOST": "db_postgres",
        "PORT": 5432,
    },
}

MONGO_DB = {"name": "newsblur", "host": "db_mongo:29019"}
MONGO_ANALYTICS_DB = {
    "name": "nbanalytics",
    "host": "db_mongo:29019",
}

MONGODB_SLAVE = {"host": "db_mongo"}

# Celery RabbitMQ/Redis Broker
BROKER_URL = "redis://db_redis:6579/0"
CELERY_RESULT_BACKEND = BROKER_URL
CELERY_WORKER_CONCURRENCY = 1

REDIS_USER = {"host": "db_redis", "port": 6579}
REDIS_PUBSUB = {"host": "db_redis", "port": 6579}
REDIS_STORY = {"host": "db_redis", "port": 6579}
REDIS_SESSIONS = {"host": "db_redis", "port": 6579}

CELERY_REDIS_DB_NUM = 4
SESSION_REDIS_DB = 5

ELASTICSEARCH_FEED_HOSTS = ["db_elasticsearch:9200"]
ELASTICSEARCH_STORY_HOSTS = ["db_elasticsearch:9200"]
ELASTICSEARCH_DISCOVER_HOSTS = ["db_elasticsearch:9200"]

ELASTICSEARCH_FEED_HOST = "http://db_elasticsearch:9200"
ELASTICSEARCH_STORY_HOST = "http://db_elasticsearch:9200"
ELASTICSEARCH_DISCOVER_HOST = "http://db_elasticsearch:9200"
BACKED_BY_AWS = {
    "pages_on_node": False,
    "pages_on_s3": False,
    "icons_on_s3": False,
}

OPENAI_API_KEY = "sk-svcacct-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# ===========
# = Logging =
# ===========

# Logging (setup for development)
LOG_TO_STREAM = True

if len(logging._handlerList) < 1:
    LOG_FILE = "~/newsblur/logs/development.log"
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)-12s: %(message)s",
        datefmt="%b %d %H:%M:%S",
        handler=logging.StreamHandler,
    )

MAILGUN_ACCESS_KEY = "key-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
MAILGUN_SERVER_NAME = "newsblur.com"

DO_TOKEN_LOG = "0000000000000000000000000000000000000000000000000000000000000000"
DO_TOKEN_FABRIC = "0000000000000000000000000000000000000000000000000000000000000000"

SERVER_NAME = "nblocalhost"
NEWSBLUR_URL = os.getenv("NEWSBLUR_URL", "https://localhost")

if NEWSBLUR_URL == "https://localhost":
    SESSION_COOKIE_DOMAIN = "localhost"

SESSION_ENGINE = "redis_sessions.session"

# CORS_ORIGIN_REGEX_WHITELIST = ('^(https?://)?(\w+\.)?nb.local\.com$', )

RECAPTCHA_SECRET_KEY = "0000000000000000000000000000000000000000"
IMAGES_SECRET_KEY = "0000000000000000000000000000000"

# APNS settings for token-based authentication
APNS_TEAM_ID = "XXXXXXXXXX"  # Apple Developer Team ID (10 characters)
APNS_KEY_ID = "XXXXXXXXXX"  # APNS Key ID (10 characters)
