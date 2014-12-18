#!/usr/bin/python

# Given a template (with a specific format), a target document root and a set of formatted XML
#  documents, generate HTML documentation for public web access.

# Extracts information from XML using regular expression and proper parsing


from sys import argv, stderr, exit

if len(argv) < 3:
  print >>stderr,"Usage:",argv[0]," <template.html> <target-doc-directory> [source XML document ... ]"
  exit(5)

template = argv[1]
targetDir = argv[2]

f = open(template)
bp = f.read()
f.close()

doc = bp

import libxml2
import os.path

libxml2.substituteEntitiesDefault(True)

def asText(x):
  d = libxml2.parseDoc(x)
  return d.xpathCastNodeToString()

import re

wsRE = re.compile('\s+')

def trimWS(s):
  s = wsRE.sub(' ', s)
  if s and s[0] == ' ':
    s = s[1:]
  if s and s[-1] == ' ':
    s = s[:-1]

  return s

secRe = re.compile("<div id='(\w+)'>\n(.*?\n)</div>\n", re.DOTALL)

import codecs

def writeDoc(x, h):
  f = open(x)
  t = f.read()
  f.close()

  doc = bp

  # Get the title
  xd = libxml2.parseFile(x)
  ctxt = xd.xpathNewContext()
  ctxt.xpathRegisterNs('html', 'http://www.w3.org/1999/xhtml')

  title = ctxt.xpathEvalExpression('string(/fvdoc//html:div[@id="message"])')

  title = trimWS(title)
  doc = doc.replace('<title></title>', '<title>' + title + '</title>')

  
  for (sec, txt) in secRe.findall(t):
    r = re.compile('<h2>' + sec + '</h2>\s*<div class="docbody">\s*()</div>', re.IGNORECASE)
    idx = r.search(doc).start(1)
    doc = doc[:idx] + txt + doc[idx:]

  c = codecs.getdecoder('utf-8')

  doc = c(doc)[0]

  c = codecs.getencoder('iso-8859-1')

  f = open(h, 'w')
  f.write(c(doc, 'xmlcharrefreplace')[0])
  f.close()

for f in argv[3:]:
  sp = os.path.abspath(f)

  if not(os.path.isfile(sp)):
    continue

  category = os.path.split(os.path.dirname(sp))[1]
  filename = os.path.basename(sp)

  if not(category):
    continue

  (name, ext) = os.path.splitext(filename)

  if ext == '.xml':
    writeDoc(sp, os.path.join(targetDir, category, name + '.html'))
  else:
    print >>stderr,"Ignoring",f
