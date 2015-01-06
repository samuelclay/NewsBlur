#!/usr/bin/python

# This is a simple demo of validation through the web service.


WS_HOST = 'www.feedvalidator.org'
WS_URI = '/check.cgi'

import urllib, httplib
from xml.dom import minidom
from sys import exit

# Fetch the feed to validate
rawData = open('../testcases/rss/may/image_height_recommended.xml').read()

# Specify the content type, including the charset if known
hdrs = {'Content-Type': 'application/xml'}

# Simply POST the feed contents to the validator URL
connection=httplib.HTTPConnection(WS_HOST, 80)
connection.request('POST', WS_URI, rawData, hdrs)
response=connection.getresponse()

# The response is a SOAP message, as XML (otherwise there's a problem
#  with the validator)
try:
  document=minidom.parseString(response.read())
except:
  print "Server error, unable to validate:",response.status,response.reason
  print "(Unable to parse response as XML.)"
  exit(20)

# If the status is OK, validation took place.
if response.status == 200:
  errors = document.getElementsByTagName("text")
  if not errors:
    print "The feed is valid!"
    exit(0)
  else:
    # Errors were found
    for node in errors:
      print "".join([child.data for child in node.childNodes])
    exit(5)
 

# If there was a problem on the server, show details
elif response.status >= 500:
  errors = document.getElementsByTagName("faultstring")
  for node in errors:
    print "".join([child.data for child in node.childNodes])
  traceback = document.getElementsByTagNameNS("http://www.python.org/doc/current/lib/module-traceback.html", "traceback")
  if traceback:
    print "".join([child.data for child in traceback[0].childNodes])
  exit(10)
 
# The unexpected happened...
else:
  print "Unexpected server response:",response.status,response.reason
  exit(20)
