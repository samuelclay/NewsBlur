import django

if django.VERSION < (1, 6):
    # Old style test discovery
    from .test_ipn import *
    from .test_forms import *
