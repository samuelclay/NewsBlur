
# https://192.168.1.10/Info.live.htm

import os
import re
import urllib.request
from vendor.munin import MuninPlugin

class DDWrtPlugin(MuninPlugin):
    category = "Wireless"

    def __init__(self):
        super(DDWrtPlugin, self).__init__()
        self.root_url = os.environ.get('DDWRT_URL') or "http://192.168.1.1"
        self.url = self.root_url + "/Info.live.htm"

    def get_info(self):
        res = urllib.request.urlopen(self.url)
        text = res.read()
        return dict(
            x[1:-1].split('::')
            for x in text.split('\n')
        )
