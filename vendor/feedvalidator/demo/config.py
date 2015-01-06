# Default URL of the validator itself... feel free to beautify as you like
import os
HOMEURL = os.environ['HTTP_HOST'] + os.environ['SCRIPT_NAME']
if not HOMEURL.startswith('http://'): HOMEURL = 'http://' + HOMEURL

# This is where the CGI itself is... other supporting scripts (like
# feedfinder) may be placed here.
WEBDIR = '/'.join(os.environ['SCRIPT_FILENAME'].split('/')[0:-1])

# This following value is primarily used for setting up the other values...
HOMEDIR = WEBDIR

# This is where local python libraries are installed.  This may be useful
# for locating a locally installed libxml2 library, for example...
PYDIR  = HOMEDIR + r'/lib/python/'

# This is where the feedvalidator code lives...
SRCDIR = WEBDIR + r'/src'

# The web location prefix of the docs and CSS, relative to check.cgi
DOCSURL='docs'
CSSURL='css'
