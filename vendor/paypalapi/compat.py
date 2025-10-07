# -*- coding: utf-8 -*-

"""
pythoncompat, from python-requests.

Copyright (c) 2012 Kenneth Reitz.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
"""


import sys

# -------
# Pythons
# -------

# Syntax sugar.
_ver = sys.version_info


#: Python 3.x?
is_py3 = _ver[0] == 3

#: Python 3.0.x
is_py30 = is_py3 and _ver[1] == 0

#: Python 3.1.x
is_py31 = is_py3 and _ver[1] == 1

#: Python 3.2.x
is_py32 = is_py3 and _ver[1] == 2

#: Python 3.3.x
is_py33 = is_py3 and _ver[1] == 3

#: Python 3.4.x
is_py34 = is_py3 and _ver[1] == 4


# ---------
# Platforms
# ---------


# Syntax sugar.
_ver = sys.version.lower()

is_pypy = "pypy" in _ver
is_jython = "jython" in _ver
is_ironpython = "iron" in _ver

# Assume CPython, if nothing else.
is_cpython = not any((is_pypy, is_jython, is_ironpython))

# Windows-based system.
is_windows = "win32" in str(sys.platform).lower()

# Standard Linux 2+ system.
is_linux = "linux" in str(sys.platform).lower()
is_osx = "darwin" in str(sys.platform).lower()
is_hpux = "hpux" in str(sys.platform).lower()  # Complete guess.
is_solaris = "solar==" in str(sys.platform).lower()  # Complete guess.


# ---------
# Specifics
# ---------


# noinspection PyUnresolvedReferences,PyCompatibility
from http import cookiejar as cookielib

# noinspection PyUnresolvedReferences,PyCompatibility
from http.cookies import Morsel

# noinspection PyUnresolvedReferences,PyCompatibility
from io import StringIO

# noinspection PyUnresolvedReferences,PyCompatibility
from urllib.parse import (
    quote,
    unquote,
    urlencode,
    urljoin,
    urlparse,
    urlsplit,
    urlunparse,
)

# noinspection PyUnresolvedReferences,PyCompatibility
from urllib.request import parse_http_list
