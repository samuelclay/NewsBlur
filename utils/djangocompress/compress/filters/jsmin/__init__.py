from compress.filters.jsmin.jsmin import jsmin
from compress.filter_base import FilterBase

class JSMinFilter(FilterBase):
    def filter_js(self, js):
        return jsmin(js)