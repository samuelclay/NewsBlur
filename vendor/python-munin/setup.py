#!/usr/bin/env python

from distutils.core import setup

from vendor.munin import __version__ as version

setup(
    name = 'munin',
    version = version,
    description = 'Framework for building Munin plugins',
    author = 'Samuel Stauffer',
    author_email = 'samuel@descolada.com',
    url = 'http://github.com/samuel/python-munin/tree/master',
    packages = ['munin'],
    classifiers = [
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python',
        'Topic :: Software Development :: Libraries :: Python Modules',
    ],
)
