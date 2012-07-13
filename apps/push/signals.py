# Adapted from djpubsubhubbub. See License: http://git.participatoryculture.org/djpubsubhubbub/tree/LICENSE

from django.dispatch import Signal

pre_subscribe = Signal(providing_args=['created'])
verified = Signal()
updated = Signal(providing_args=['update'])
