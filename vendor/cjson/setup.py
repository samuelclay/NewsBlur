#!/usr/bin/python
# -*- coding: ascii -*-

from distutils.core import setup, Extension

__version__ = "1.0.3x6"

setup(
    name         = "python-cjson",
    version      = __version__,
    author       = "Dan Pascu",
    author_email = "dan@ag-projects.com",
    url          = "http://ag-projects.com/",
    download_url = "http://cheeseshop.python.org/pypi/python-cjson/%s" % __version__,
    description  = "Fast JSON encoder/decoder for Python",
    long_description = open('README', 'r').read(),
    license      = "LGPL",
    platforms    = ["Platform Independent"],
    classifiers  = [
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: GNU Library or Lesser General Public License (LGPL)",
        "Operating System :: OS Independent",
        "Programming Language :: Python",
        "Topic :: Software Development :: Libraries :: Python Modules"
    ],
    ext_modules  = [Extension(name='cjson', sources=['cjson.c'])],
)
