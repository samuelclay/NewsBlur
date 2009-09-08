from django.conf import settings

from compress.filter_base import FilterBase
from compress.filters.csstidy_python.csstidy import CSSTidy

COMPRESS_CSSTIDY_SETTINGS = getattr(settings, 'COMPRESS_CSSTIDY_SETTINGS', {})

class CSSTidyFilter(FilterBase):
    def filter_css(self, css):
        tidy = CSSTidy()
        
        for k, v in COMPRESS_CSSTIDY_SETTINGS.items():
            tidy.setSetting(k, v)

        tidy.parse(css)

        r = tidy.Output('string')
        
        return r
