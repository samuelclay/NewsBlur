import sys
import logging
import os
from mongoengine import connect
import redis

# ===========================
# = Directory Declaractions =
# ===========================

CURRENT_DIR   = os.path.dirname(__file__)
NEWSBLUR_DIR  = CURRENT_DIR
TEMPLATE_DIRS = (os.path.join(CURRENT_DIR, 'templates'),)
MEDIA_ROOT    = os.path.join(CURRENT_DIR, 'media')
UTILS_ROOT    = os.path.join(CURRENT_DIR, 'utils')
VENDOR_ROOT   = os.path.join(CURRENT_DIR, 'vendor')
LOG_FILE      = os.path.join(CURRENT_DIR, 'logs/newsblur.log')
IMAGE_MASK    = os.path.join(CURRENT_DIR, 'media/img/mask.png')

# ==============
# = PYTHONPATH =
# ==============

if '/utils' not in ' '.join(sys.path):
    sys.path.append(UTILS_ROOT)
if '/vendor' not in ' '.join(sys.path):
    sys.path.append(VENDOR_ROOT)

# ===================
# = Global Settings =
# ===================

ADMINS                = (
    ('Samuel Clay', 'samuel@ofbrooklyn.com'),
)
TEST_DEBUG            = False
SEND_BROKEN_LINK_EMAILS = False
MANAGERS              = ADMINS
PAYPAL_RECEIVER_EMAIL = 'samuel@ofbrooklyn.com'
TIME_ZONE             = 'GMT'
LANGUAGE_CODE         = 'en-us'
SITE_ID               = 1
USE_I18N              = False
LOGIN_REDIRECT_URL    = '/'
LOGIN_URL             = '/reader/login'
# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
ADMIN_MEDIA_PREFIX    = '/media/admin/'
SECRET_KEY            = 'YOUR_SECRET_KEY'
EMAIL_BACKEND         = 'django_ses.SESBackend'


# ===============
# = Enviornment =
# ===============

PRODUCTION  = NEWSBLUR_DIR.find('/home/conesus/newsblur') == 0
STAGING     = NEWSBLUR_DIR.find('/home/conesus/staging') == 0
DEVELOPMENT = NEWSBLUR_DIR.find('/Users/') == 0

# ===========================
# = Django-specific Modules =
# ===========================

TEMPLATE_LOADERS = (
    'django.template.loaders.filesystem.Loader',
    'django.template.loaders.app_directories.Loader',
    'django.template.loaders.eggs.load_template_source',

)
TEMPLATE_CONTEXT_PROCESSORS = (
    "django.contrib.auth.context_processors.auth",
    "django.core.context_processors.debug",
    "django.core.context_processors.media",
    'django.core.context_processors.request',
)

MIDDLEWARE_CLASSES = (
    'django.middleware.gzip.GZipMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'apps.profile.middleware.LastSeenMiddleware',
    'apps.profile.middleware.SQLLogToConsoleMiddleware',
    # 'debug_toolbar.middleware.DebugToolbarMiddleware',
)

# ===========
# = Logging =
# ===========

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[%(asctime)-12s] %(message)s', 
            'datefmt': '%b %d %H:%M:%S'
        },
        'simple': {
            'format': '%(message)s'
        },
    },
    'handlers': {
        'null': {
            'level':'DEBUG',
            'class':'django.utils.log.NullHandler',
        },
        'console':{
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose'
        },
        'log_file':{
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': LOG_FILE,
            'maxBytes': '16777216', # 16megabytes
            'formatter': 'verbose'
        },
        'mail_admins': {
            'level': 'ERROR',
            'class': 'django.utils.log.AdminEmailHandler',
            'include_html': True,
        }
    },
    'loggers': {
        'django.request': {
            'handlers': ['mail_admins'],
            'level': 'ERROR',
            'propagate': True,
        },
        'django.db.backends': {
            'handlers': ['null'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'newsblur': {
            'handlers': ['console', 'log_file'],
            'level': 'DEBUG',
            'propagate': False,
        },
    'apps': {
            'handlers': ['log_file'],
            'level': 'INFO',
            'propagate': True,
        },
    }
}

# =====================
# = Media Compression =
# =====================

COMPRESS_JS = {
    'all': {
        'source_filenames': (
            'js/jquery-1.6.1.js',
            'js/inflector.js',
            'js/jquery.json.js',
            'js/jquery.easing.js',
            'js/jquery.newsblur.js',
            'js/jquery.scrollTo.js',
            'js/jquery.corners.js',
            'js/jquery.hotkeys.js',
            'js/jquery.ajaxupload.js',
            'js/jquery.ajaxmanager.3.js',
            'js/jquery.simplemodal-1.3.js',
            'js/jquery.color.js',
            'js/jquery.rightclick.js',
            'js/jquery.ui.core.js',
            'js/jquery.ui.widget.js',
            'js/jquery.ui.mouse.js',
            'js/jquery.ui.position.js',
            'js/jquery.ui.draggable.js',
            'js/jquery.ui.sortable.js',
            'js/jquery.ui.slider.js',
            'js/jquery.ui.autocomplete.js',
            'js/jquery.ui.progressbar.js',
            'js/jquery.layout.js',
            'js/jquery.tinysort.js',
            'js/jquery.fieldselection.js',
            'js/jquery.flot.js',
            'js/jquery.tipsy.js',
            'js/socket.io-client.0.8.7.js',
            'js/underscore.js',
            'js/underscore.string.js',
            'js/newsblur/reader_utils.js',
            'js/newsblur/assetmodel.js',
            'js/newsblur/reader.js',
            'js/newsblur/generate_bookmarklet.js',
            'js/newsblur/modal.js',
            'js/newsblur/reader_classifier.js',
            'js/newsblur/reader_add_feed.js',
            'js/newsblur/reader_mark_read.js',
            'js/newsblur/reader_goodies.js',
            'js/newsblur/reader_preferences.js',
            'js/newsblur/reader_account.js',
            'js/newsblur/reader_feedchooser.js',
            'js/newsblur/reader_statistics.js',
            'js/newsblur/reader_feed_exception.js',
            'js/newsblur/reader_keyboard.js',
            'js/newsblur/reader_recommend_feed.js',
            'js/newsblur/reader_send_email.js',
            'js/newsblur/reader_tutorial.js',
            'js/newsblur/about.js',
            'js/newsblur/faq.js',
        ),
        'output_filename': 'js/all-compressed-?.js'
    },
    'mobile': {
        'source_filenames': (
            'js/jquery-1.6.1.js',
            'js/mobile/jquery.mobile-1.0b1.js',
            'js/jquery.ajaxmanager.3.js',
            'js/underscore.js',
            'js/underscore.string.js',
            'js/inflector.js',
            'js/jquery.json.js',
            'js/jquery.easing.js',
            'js/jquery.newsblur.js',
            'js/newsblur/reader_utils.js',
            'js/newsblur/assetmodel.js',
            'js/mobile/newsblur/mobile_workspace.js',
        ),
        'output_filename': 'js/mobile-compressed-?.js',
    },
    'paypal': {
        'source_filenames': (
            'js/newsblur/paypal_return.js',
        ),
        'output_filename': 'js/paypal-compressed-?.js',
    },
    'bookmarklet': {
        'source_filenames': (
            'js/jquery-1.5.1.min.js',
            'js/jquery.noConflict.js',
            'js/jquery.newsblur.js',
            'js/jquery.tinysort.js',
            'js/jquery.simplemodal-1.3.js',
            'js/jquery.corners.js',
        ),
        'output_filename': 'js/bookmarklet-compressed-?.js',
    },
}

COMPRESS_CSS = {
    'all': {
        'source_filenames': (
            'css/reader.css',
            'css/modals.css',
            'css/status.css',
            'css/jquery-ui/jquery.theme.css',
            'css/jquery.tipsy.css',
        ),
        'output_filename': 'css/all-compressed-?.css'
    },
    'mobile': {
        'source_filenames': (
            'css/mobile/jquery.mobile-1.0b1.css',
            'css/mobile/mobile.css',
        ),
        'output_filename': 'css/mobile/mobile-compressed-?.css',
    },
    'paypal': {
        'source_filenames': (
            'css/paypal_return.css',
        ),
        'output_filename': 'css/paypal-compressed-?.css',
    },
    'bookmarklet': {
        'source_filenames': (
            'css/reset.css',
            'css/modals.css',
        ),
        'output_filename': 'css/paypal-compressed-?.css',
    },
}

COMPRESS_VERSION = True
COMPRESS_JS_FILTERS = ['compress.filters.jsmin.JSMinFilter']
COMPRESS_CSS_FILTERS = []

# YUI_DIR = ''.join([UTILS_ROOT, '/yuicompressor-2.4.2/build/yuicompressor-2.4.2.jar'])
# COMPRESS_YUI_BINARY = 'java -jar ' + YUI_DIR
# COMPRESS_YUI_JS_ARGUMENTS = '--preserve-semi --nomunge --disable-optimizations'

# ==========================
# = Miscellaneous Settings =
# ==========================

DAYS_OF_UNREAD          = 14
SUBSCRIBER_EXPIRE       = 1

AUTH_PROFILE_MODULE     = 'newsblur.UserProfile'
TEST_DATABASE_COLLATION = 'utf8_general_ci'
TEST_DATABASE_NAME      = 'newsblur_test'
ROOT_URLCONF            = 'urls'
INTERNAL_IPS            = ('127.0.0.1',)
LOGGING_LOG_SQL         = True
APPEND_SLASH            = True
SOUTH_TESTS_MIGRATE     = False 
SESSION_ENGINE          = "django.contrib.sessions.backends.db"
TEST_RUNNER             = "utils.testrunner.TestRunner"
SESSION_COOKIE_NAME     = 'newsblur_sessionid'
SESSION_COOKIE_AGE      = 60*60*24*365*2 # 2 years
SERVER_EMAIL            = 'server@newsblur.com'
HELLO_EMAIL             = 'hello@newsblur.com'

# ===========
# = Logging =
# ===========

LOG_LEVEL = logging.DEBUG
LOG_TO_STREAM = False

# ===============
# = Django Apps =
# ===============

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.admin',
    'django_extensions',
    'djcelery',
    # 'seacucumber',
    'django_ses',
    'compress',
    'apps.rss_feeds',
    'apps.reader',
    'apps.analyzer',
    'apps.feed_import',
    'apps.profile',
    'apps.recommendations',
    'apps.statistics',
    'apps.static',
    'apps.mobile',
    'south',
    'utils',
    'vendor',
    'vendor.typogrify',
    'vendor.paypal.standard.ipn',
)

if not DEVELOPMENT:
    INSTALLED_APPS += (
        'gunicorn',
    )

# ==========
# = Celery =
# ==========

import djcelery
djcelery.setup_loader()
CELERY_ROUTES = {
    "new-feeds": {
        "queue": "new_feeds",
        "binding_key": "new_feeds"
    },
    "update-feeds": {
        "queue": "update_feeds",
        "binding_key": "update_feeds"
    },
}
CELERY_QUEUES = {
    "new_feeds": {
        "exchange": "new_feeds",
        "exchange_type": "direct",
        "binding_key": "new_feeds"
    },
    "update_feeds": {
        "exchange": "update_feeds",
        "exchange_type": "direct",
        "binding_key": "update_feeds"
    },
}
CELERY_DEFAULT_QUEUE = "update_feeds"
BROKER_BACKEND       = "amqplib"
BROKER_HOST          = "db02.newsblur.com"
BROKER_PORT          = 5672
BROKER_USER          = "newsblur"
BROKER_PASSWORD      = "newsblur"
BROKER_VHOST         = "newsblurvhost"

CELERY_RESULT_BACKEND       = "amqp"
CELERYD_LOG_LEVEL           = 'ERROR'
CELERY_IMPORTS              = ("apps.rss_feeds.tasks", )
CELERYD_CONCURRENCY         = 4
CELERY_IGNORE_RESULT        = True
CELERY_ACKS_LATE            = True # Retry if task fails
CELERYD_MAX_TASKS_PER_CHILD = 10
# CELERYD_TASK_TIME_LIMIT   = 12 * 30
CELERY_DISABLE_RATE_LIMITS  = True

# ====================
# = Database Routers =
# ====================

class MasterSlaveRouter(object):
    """A router that sets up a simple master/slave configuration"""

    def db_for_read(self, model, **hints):
        "Point all read operations to a random slave"
        return 'slave'

    def db_for_write(self, model, **hints):
        "Point all write operations to the master"
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        "Allow any relation between two objects in the db pool"
        db_list = ('slave','default')
        if obj1._state.db in db_list and obj2._state.db in db_list:
            return True
        return None

    def allow_syncdb(self, db, model):
        "Explicitly put all models on all databases."
        return True

# =========
# = Redis =
# =========

REDIS = {
    'host': 'db02',
}

# ===========
# = MongoDB =
# ===========

MONGODB_SLAVE = {
    'host': 'db01'
}

# ==================
# = Configurations =
# ==================
try:
    from gunicorn_conf import *
except ImportError, e:
    pass
from local_settings import *

COMPRESS = not DEBUG
TEMPLATE_DEBUG = DEBUG
ACCOUNT_ACTIVATION_DAYS = 30
AWS_ACCESS_KEY_ID = S3_ACCESS_KEY
AWS_SECRET_ACCESS_KEY = S3_SECRET

def custom_show_toolbar(request):
    return DEBUG

DEBUG_TOOLBAR_CONFIG = {
    'INTERCEPT_REDIRECTS': True,
    'SHOW_TOOLBAR_CALLBACK': custom_show_toolbar,
    'HIDE_DJANGO_SQL': False,
}

# =========
# = Mongo =
# =========

MONGO_DB_DEFAULTS = {
    'name': 'newsblur',
    'host': 'mongodb://db01,db03/?slaveOk=true',
}
MONGO_DB = dict(MONGO_DB_DEFAULTS, **MONGO_DB)
MONGODB = connect(MONGO_DB.pop('name'), **MONGO_DB)

# =========
# = Redis =
# =========

REDIS_POOL = redis.ConnectionPool(host=REDIS['host'], port=6379, db=0)
