import django

if django.VERSION < (1, 6):
    # Old style test discovery
    from .test_ipn import *  # noqa
    from .test_forms import *  # noqa
