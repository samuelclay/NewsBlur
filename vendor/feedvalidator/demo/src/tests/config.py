from os import environ

# This is a test config, used by the runtests script, to ensure check.cgi
#  runs without requiring a web server.

HOMEURL = 'http://localhost/check'

PYDIR  = '/usr/lib/python/'
WEBDIR = environ['FEEDVALIDATOR_HOME']
SRCDIR = WEBDIR + '/src'

DOCSURL = 'docs'
CSSURL = 'css'
