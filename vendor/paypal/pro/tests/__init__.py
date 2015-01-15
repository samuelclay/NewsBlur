import django

if django.VERSION < (1, 6):
    # Old style test discovery
    from .test_pro import *
