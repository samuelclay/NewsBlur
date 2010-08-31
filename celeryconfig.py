BROKER_HOST = "db01.newsblur.com"
BROKER_PORT = 5672
BROKER_USER = "newsblur"
BROKER_PASSWORD = "newsblur"
BROKER_VHOST = "newsblurvhost"

CELERY_RESULT_BACKEND = "amqp"

CELERY_IMPORTS = ("apps.rss_feeds.tasks", )