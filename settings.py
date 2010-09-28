import sys
import logging
import os
from mongoengine import connect

# ===========================
# = Directory Declaractions =
# ===========================

CURRENT_DIR = os.path.dirname(__file__)
NEWSBLUR_DIR = CURRENT_DIR
TEMPLATE_DIRS = (''.join([CURRENT_DIR, '/templates']),)
MEDIA_ROOT = ''.join([CURRENT_DIR, '/media'])
UTILS_ROOT = ''.join([CURRENT_DIR, '/utils'])
LOG_FILE = ''.join([CURRENT_DIR, '/logs/newsblur.log'])

# ==============
# = PYTHONPATH =
# ==============

UTILS_DIR = ''.join([CURRENT_DIR, '/utils'])
if '/utils' not in ' '.join(sys.path):
    sys.path.append(UTILS_DIR)

# ===================
# = Global Settings =
# ===================

ADMINS = (
    ('Samuel Clay', 'samuel@ofbrooklyn.com'),
)
MANAGERS = ADMINS

TIME_ZONE = 'GMT'
LANGUAGE_CODE = 'en-us'
SITE_ID = 1
USE_I18N = False
LOGIN_REDIRECT_URL = '/'
LOGIN_URL = '/reader/login'
# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
ADMIN_MEDIA_PREFIX = '/media/admin/'
SECRET_KEY = '6yx-@2u@v$)-=fqm&tc8lhk3$6d68+c7gd%p$q2@o7b4o8-*fz'

# ===============
# = Enviornment =
# ===============

PRODUCTION = __file__.find('/home/conesus/newsblur') == 0
DEV_SERVER1 = __file__.find('/Users/conesus/Projects/newsblur') == 0
DEV_SERVER2 = __file__.find('/Users/conesus/newsblur') == 0
DEVELOPMENT = DEV_SERVER1 or DEV_SERVER2
                
# ===========================
# = Django-specific Modules =
# ===========================

TEMPLATE_LOADERS = (
    'django.template.loaders.filesystem.load_template_source',
    'django.template.loaders.app_directories.load_template_source',
    'django.template.loaders.eggs.load_template_source',
)
TEMPLATE_CONTEXT_PROCESSORS = (
    "django.core.context_processors.auth",
    "django.core.context_processors.debug",
    "django.core.context_processors.media",
    'django.core.context_processors.request',
)

MIDDLEWARE_CLASSES = (
    'django.middleware.gzip.GZipMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.cache.CacheMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'apps.profile.middleware.LastSeenMiddleware',
    # 'debug_toolbar.middleware.DebugToolbarMiddleware',
)

# =====================
# = Media Compression =
# =====================

COMPRESS_JS = {
    'all': {
        'source_filenames': (
            'js/jquery-1.4.2.js',
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
            'js/jquery.ui.progressbar.js',
            'js/jquery.layout.js',
            'js/jquery.tinysort.js',
            'js/jquery.fieldselection.js',
            'js/jquery.flot.js',
            'js/underscore.js',
            'js/newsblur/assetmodel.js',
            'js/newsblur/reader.js',
            'js/newsblur/reader_classifier.js',
            'js/newsblur/reader_add_feed.js',
            'js/newsblur/reader_manage_feed.js',
            'js/newsblur/reader_mark_read.js',
            'js/newsblur/reader_preferences.js',
            'js/newsblur/reader_statistics.js',
            'js/newsblur/reader_feed_exception.js',
            'js/newsblur/about.js',
            'js/newsblur/faq.js',
        ),
        'output_filename': 'js/all-compressed-?.js'
    }
}

COMPRESS_CSS = {
    'all': {
        'source_filenames': (
            'css/reader.css',
            'css/jquery-ui/jquery.theme.css',
        ),
        'output_filename': 'css/all-compressed-?.css'
    }
}

COMPRESS_VERSION = True
COMPRESS_JS_FILTERS = ['compress.filters.jsmin.JSMinFilter']
COMPRESS_CSS_FILTERS = []

# YUI_DIR = ''.join([UTILS_ROOT, '/yuicompressor-2.4.2/build/yuicompressor-2.4.2.jar'])
# COMPRESS_YUI_BINARY = 'java -jar ' + YUI_DIR
# COMPRESS_YUI_JS_ARGUMENTS = '--preserve-semi --nomunge --disable-optimizations'

# ========================
# = Django Debug Toolbar =
# ========================

DEBUG_TOOLBAR_PANELS = (
    'debug_toolbar.panels.version.VersionDebugPanel',
    'debug_toolbar.panels.timer.TimerDebugPanel',
    'debug_toolbar.panels.settings_vars.SettingsVarsDebugPanel',
    'debug_toolbar.panels.headers.HeaderDebugPanel',
    'debug_toolbar.panels.request_vars.RequestVarsDebugPanel',
    'debug_toolbar.panels.template.TemplateDebugPanel',
    'debug_toolbar.panels.sql.SQLDebugPanel',
    'debug_toolbar.panels.cache.CacheDebugPanel',
    'debug_toolbar.panels.signals.SignalDebugPanel',
    'debug_toolbar.panels.logger.LoggingPanel',
)

# ==========================
# = Miscellaneous Settings =
# ==========================

AUTH_PROFILE_MODULE = 'newsblur.UserProfile'
TEST_DATABASE_COLLATION = 'utf8_general_ci'
TEST_DATABASE_NAME = 'newsblur_test'
ROOT_URLCONF = 'urls'
INTERNAL_IPS = ('127.0.0.1',)
LOGGING_LOG_SQL = True
APPEND_SLASH = True
SOUTH_TESTS_MIGRATE = False 
SESSION_ENGINE = "django.contrib.sessions.backends.cached_db"
TEST_RUNNER = "utils.testrunner.TestRunner"
DAYS_OF_UNREAD = 14

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
    'compress',
    'apps.rss_feeds',
    'apps.reader',
    'apps.analyzer',
    'apps.feed_import',
    'apps.profile',
    'devserver',
    'south',
    # 'test_utils',
    'utils',
    'utils.typogrify',
    # 'debug_toolbar'
)

DEVSERVER_MODULES = (
   'devserver.modules.sql.SQLRealTimeModule',
    'devserver.modules.sql.SQLSummaryModule',
    'devserver.modules.profile.ProfileSummaryModule',

    # Modules not enabled by default
    'devserver.modules.profile.MemoryUseModule',
    'devserver.modules.cache.CacheSummaryModule',
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
BROKER_HOST = "db01.newsblur.com"
BROKER_PORT = 5672
BROKER_USER = "newsblur"
BROKER_PASSWORD = "newsblur"
BROKER_VHOST = "newsblurvhost"

CELERY_RESULT_BACKEND = "amqp"

CELERY_IMPORTS = ("apps.rss_feeds.tasks", )
CELERYD_CONCURRENCY = 4
CELERY_IGNORE_RESULT = True
CELERYD_MAX_TASKS_PER_CHILD = 100
CELERY_DISABLE_RATE_LIMITS = True

# ==================
# = Configurations =
# ==================

from local_settings import *

COMPRESS = not DEBUG
TEMPLATE_DEBUG = DEBUG
ACCOUNT_ACTIVATION_DAYS = 30

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

MONGODB = connect(MONGO_DB['NAME'], host=MONGO_DB['HOST'], port=MONGO_DB['PORT'])
