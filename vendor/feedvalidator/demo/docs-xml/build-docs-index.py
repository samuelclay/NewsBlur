#!/usr/bin/python

# Put a header and a footer on a list of all documented diagnostics,
#  linking to their pages.

# Note that this script has lots of hardcoded paths, needs to be run
#  from the docs-xml directory, and modifies the index.html in docs.

from os import listdir
from os import path
import re

from sys import stderr

basedir = '.'

messageRe = re.compile("<div id='message'>\n<p>(.*)</p>\n</div>")

def getMessage(fn):
  f = open(fn)
  txt = f.read()
  f.close()

  m = messageRe.search(txt)
  return m.group(1)

of = open('../docs/index.html', 'w')

def printLine(hr, msg):
  of.write('<li><a href="%s">%s</a></li>' % (hr, msg))
  of.write("\n")


f = open('docs-index-header.html')
of.write(f.read())
f.close()

of.write("<h2>Validator messages</h2>\n")

for (type, title) in [('error', 'Errors'), ('warning', 'Warnings'), ('info', 'Information')]:
  p = path.join(basedir, type)

  allMsgs = []

  for f in listdir(p):
    (name,ext) = path.splitext(f)
    if ext != '.xml':
      continue
    msg = getMessage(path.join(p, f))

    allMsgs.append([name, msg])

  allMsgs.sort()

  of.write("\n<h3>%s</h3>\n" % title)
  of.write("<ul>\n")

  for (f, msg) in allMsgs:
    printLine(type + '/' + f + '.html', msg)
  of.write("</ul>\n")
  
f = open('docs-index-footer.html')
of.write(f.read())
f.close()
