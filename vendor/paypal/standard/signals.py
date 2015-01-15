from django.dispatch import Signal

import warnings


class DeprecatedSignal(Signal):

    def __init__(self, deprecation_message, *args, **kwargs):
        self.deprecation_message = deprecation_message
        super(DeprecatedSignal, self).__init__(*args, **kwargs)

    def connect(self, *args, **kwargs):
        warnings.warn(
            self.deprecation_message, DeprecationWarning, stacklevel=2)
        return super(DeprecatedSignal, self).connect(*args, **kwargs)

