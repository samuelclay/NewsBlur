#!/usr/bin/python
"""
$Id: missingWebPages.py 75 2004-03-28 07:48:21Z josephw $
Show any logging events without explanatory web pages
"""


from sys import path, argv, exit
from os.path import isfile

import inspect
import os.path

curdir = os.path.abspath(os.path.dirname(argv[0]))
BASE = os.path.split(curdir)[0]

path.insert(0, os.path.join(BASE, 'src'))
import feedvalidator.logging

# Logic from text_html.py
def getRootClass(aClass):
  bl = aClass.__bases__
  if not(bl):
    return None

  aClass = bl[0]
  bl = bl[0].__bases__

  while bl:
    base = bl[0]
    if base == feedvalidator.logging.LoggedEvent:
      return aClass
    aClass = base
    bl = aClass.__bases__
  return None

show = argv[1:] or ['warning', 'error']

areMissing=False

for n, o in inspect.getmembers(feedvalidator.logging, inspect.isclass):
  rc = getRootClass(o)
  if not(rc):
    continue

  rcname = rc.__name__.split('.')[-1].lower()
  if rcname in show:
    fn = os.path.join('docs', rcname, n + '.html')
    if not(isfile(os.path.join(BASE, fn))):
      print fn
      areMissing=True

if areMissing:
  exit(5)
