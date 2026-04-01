# Adapted from djpubsubhubbub. See License: http://git.participatoryculture.org/djpubsubhubbub/tree/LICENSE

from django.dispatch import Signal

# Note: providing_args was removed in Django 4.0
pre_subscribe = Signal()
verified = Signal()
updated = Signal()
