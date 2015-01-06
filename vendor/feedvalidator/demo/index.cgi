#!/usr/bin/env python
from config import *

import cgi, cgitb, sys
cgitb.enable()

import codecs
ENCODING='UTF-8'
sys.stdout = codecs.getwriter(ENCODING)(sys.stdout)

if SRCDIR not in sys.path:
    sys.path.insert(0, SRCDIR)

class request:
  content_type = "text/html"

from index import index

fs = cgi.FieldStorage()
req = request()
url =  fs.getvalue('url') or ''
out =  fs.getvalue('out') or 'xml'

result=index(req,url,out)

print "Content-type: %s\r\n\r\n%s" % (req.content_type, result)
