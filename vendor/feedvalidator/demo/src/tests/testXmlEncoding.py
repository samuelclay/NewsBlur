#!/usr/bin/python
"""$Id: testXmlEncoding.py 710 2006-10-13 00:57:33Z josephw $
Test XML character decoding against a range of encodings, valid and not."""

__author__ = "Joseph Walton <http://www.kafsemo.org/>"
__version__ = "$Revision: 710 $"
__date__ = "$Date: 2006-10-13 00:57:33 +0000 (Fri, 13 Oct 2006) $"
__copyright__ = "Copyright (c) 2004, 2006 Joseph Walton"

import os, sys

import codecs
import re

curdir = os.path.abspath(os.path.dirname(__file__))
srcdir = os.path.split(curdir)[0]
if srcdir not in sys.path:
  sys.path.insert(0, srcdir)
basedir = os.path.split(srcdir)[0]
skippedNames = []

import unittest, new, glob, re
from feedvalidator import xmlEncoding

class EncodingTestCase(unittest.TestCase):
  def testEncodingMatches(self):
    try:
      enc = xmlEncoding.detect(self.bytes)
    except UnicodeError,u:
      self.fail("'" + self.filename + "' should not cause an exception (" + str(u) + ")")

    self.assert_(enc, 'An encoding must be returned for all valid files ('
        + self.filename + ')')
    self.assertEqual(enc, self.expectedEncoding, 'Encoding for '
        + self.filename + ' should be ' + self.expectedEncoding + ', but was ' + enc)

  def testEncodingFails(self):
    eventLog = []

    try:
      encoding = xmlEncoding.detect(self.bytes, eventLog)
    except UnicodeError,u:
      self.fail("'" + self.filename + "' should not cause an exception (" + str(u) + ")")

    if encoding:
      self.fail("'" + self.filename + "' should not parse successfully (as " + encoding + ")")

    if not(eventLog):
      self.fail("'" + self.filename + "' should give a reason for parse failure")



bom8='\xEF\xBB\xBF'
bom16BE='\xFE\xFF'
bom16LE='\xFF\xFE'
bom32BE='\x00\x00\xFE\xFF'
bom32LE='\xFF\xFE\x00\x00'

# Some fairly typical Unicode text. It should survive XML roundtripping.
docText=u'<x>\u201c"This\uFEFF" is\na\r\u00A3t\u20Acst\u201D</x>'

validDecl = re.compile('[A-Za-z][-A-Za-z0-9._]*')

def makeDecl(enc=None):
  if enc:
    assert validDecl.match(enc), "'" + enc + "' is not a valid encoding name"
    return "<?xml version='1.0' encoding='" + enc + "'?>"
  else:
    return "<?xml version='1.0'?>"

def encoded(enc, txt=docText):
  return codecs.getencoder(enc)(txt, 'xmlcharrefreplace')[0]

def genValidXmlTestCases():
  someFailed = False

  # Required

  yield('UTF-8', ['BOM', 'declaration'],
    bom8 + makeDecl('UTF-8') + encoded('UTF-8'))

  yield('UTF-8', [],
    encoded('UTF-8'))

  yield('UTF-8', ['noenc'],
    makeDecl() + encoded('UTF-8'))

  yield('UTF-8', ['declaration'],
    makeDecl('UTF-8') + encoded('UTF-8'))

  yield('UTF-8', ['BOM'],
    bom8 + encoded('UTF-8'))

  yield('UTF-8', ['BOM', 'noenc'],
    bom8 + makeDecl('UTF-8') + encoded('UTF-8'))

  yield('UTF-16', ['BOM', 'declaration', 'BE'],
    bom16BE + encoded('UTF-16BE', makeDecl('UTF-16') + docText))

  yield('UTF-16', ['BOM', 'declaration', 'LE'],
    bom16LE + encoded('UTF-16LE', makeDecl('UTF-16') + docText))

  yield('UTF-16', ['BOM', 'BE'],
    bom16BE + encoded('UTF-16BE'))

  yield('UTF-16', ['BOM', 'BE', 'noenc'],
    bom16BE + encoded('UTF-16BE', makeDecl() + docText))

  yield('UTF-16', ['BOM', 'LE'],
    bom16LE + encoded('UTF-16LE'))

  yield('UTF-16', ['BOM', 'LE', 'noenc'],
    bom16LE + encoded('UTF-16LE', makeDecl() + docText))

  yield('UTF-16', ['declaration', 'BE'],
    encoded('UTF-16BE', makeDecl('UTF-16') + docText))

  yield('UTF-16', ['declaration', 'LE'],
    encoded('UTF-16LE', makeDecl('UTF-16') + docText))


  # Standard wide encodings

  try:
    yield('ISO-10646-UCS-2', ['BOM', 'declaration', 'BE'],
      bom16BE + encoded('UCS-2BE', makeDecl('ISO-10646-UCS-2') + docText))

    yield('ISO-10646-UCS-2', ['BOM', 'declaration', 'LE'],
      bom16LE + encoded('UCS-2LE', makeDecl('ISO-10646-UCS-2') + docText))

    yield('UTF-32', ['BOM', 'declaration', 'BE'],
      bom32BE + encoded('UTF-32BE', makeDecl('UTF-32') + docText))

    yield('UTF-32', ['BOM', 'declaration', 'LE'],
      bom32LE + encoded('UTF-32LE', makeDecl('UTF-32') + docText))

    yield('UTF-32', ['declaration', 'BE'],
      encoded('UTF-32BE', makeDecl('UTF-32') + docText))

    yield('UTF-32', ['declaration', 'LE'],
      encoded('UTF-32LE', makeDecl('UTF-32') + docText))

    yield('ISO-10646-UCS-4', ['BOM', 'declaration', 'BE'],
      bom32BE + encoded('UCS-4BE', makeDecl('ISO-10646-UCS-4') + docText))

    yield('ISO-10646-UCS-4', ['BOM', 'declaration', 'LE'],
      bom32LE + encoded('UCS-4LE', makeDecl('ISO-10646-UCS-4') + docText))
  except LookupError, e:
    print e
    someFailed = True


  # Encodings that don't have BOMs, and require declarations
  withDeclarations = [
    # Common ASCII-compatible encodings
    'US-ASCII', 'ISO-8859-1', 'ISO-8859-15', 'WINDOWS-1252',

    # EBCDIC
    'IBM037', 'IBM038',

    # Encodings with explicit endianness
    'UTF-16BE', 'UTF-16LE',
    'UTF-32BE', 'UTF-32LE',
    # (UCS doesn't seem to define endian'd encodings)
  ]

  for enc in withDeclarations:
    try:
      yield(enc, ['declaration'], encoded(enc, makeDecl(enc) + docText))
    except LookupError, e:
      print e
      someFailed = True


  # 10646-UCS encodings, with no BOM but with a declaration

  try:
    yield('ISO-10646-UCS-2', ['declaration', 'BE'],
      encoded('UCS-2BE', makeDecl('ISO-10646-UCS-2') + docText))

    yield('ISO-10646-UCS-2', ['declaration', 'LE'],
      encoded('UCS-2LE', makeDecl('ISO-10646-UCS-2') + docText))

    yield('ISO-10646-UCS-4', ['declaration', 'BE'],
      encoded('UCS-4BE', makeDecl('ISO-10646-UCS-4') + docText))

    yield('ISO-10646-UCS-4', ['declaration', 'LE'],
      bom32LE + encoded('UCS-4LE', makeDecl('ISO-10646-UCS-4') + docText))
  except LookupError, e:
    print e
    someFailed = True


  # Files with aliases for declarations. The declared alias should be
  #  reported back, rather than the canonical form.

  try:
    yield('csUnicode', ['alias', 'BOM', 'BE'],
      bom16BE + encoded('UCS-2BE', makeDecl('csUnicode') + docText))

    yield('csUnicode', ['alias', 'LE'],
      encoded('UCS-2LE', makeDecl('csUnicode') + docText))

    yield('csucs4', ['alias', 'BE'],
      encoded('csucs4', makeDecl('csucs4') + docText))
  except LookupError, e:
    print e
    someFailed = True

  if someFailed:
    print "Unable to generate some tests; see README for details"

def genInvalidXmlTestCases():
  # Invalid files

  someFailed = False
  # UTF-32 with a non-four-byte declaration
  try:
    yield('UTF-32', ['BOM', 'BE', 'declaration'],
      encoded('UTF-32', makeDecl('US-ASCII') + docText))
  except LookupError, e:
    print e
    someFailed = True

  # UTF-16 with a non-two-byte declaration
  yield('UTF-16', ['BOM', 'BE', 'declaration'],
    encoded('UTF-16', makeDecl('UTF-8') + docText))

  # UTF-16BE, with a BOM
  yield('UTF-16BE', ['BOM', 'declaration'],
    bom16BE + encoded('UTF-16BE', makeDecl('UTF-16BE') + docText))

  # UTF-8, with a BOM, declaring US-ASCII
  yield('UTF-8', ['BOM', 'declaration'],
    bom8 + encoded('UTF-8', makeDecl('US-ASCII') + docText))

  try:
    # UTF-32, with a BOM, beginning without a declaration
    yield('UTF-32', ['BOM', 'BE'],
      bom32BE + encoded('UTF-32BE'))

    # UTF-32, with a BOM, and a declaration with no encoding
    yield('UTF-32', ['BOM', 'BE', 'noenc'],
      bom32BE + encoded('UTF-32BE', makeDecl() + docText))
  except LookupError, e:
    print e
    someFailed = True

  # UTF-16, no BOM, no declaration
  # yield('UTF-16', ['BE'], encoded('UTF-16BE'))
  # This case falls through, and is identified as UTF-8; leave it out
  #  until we're doing decoding as well as detection.

  if someFailed:
    print "Unable to generate some tests; see README for details"

def genXmlTestCases():
  for (enc, t, x) in genValidXmlTestCases():
    yield (enc, t, x, True)
  for (enc, t, x) in genInvalidXmlTestCases():
    yield (enc, t, x, False)

def buildTestSuite():
  import codecs
  suite = unittest.TestSuite()
  for (enc, t, x, valid) in genXmlTestCases():
    t.sort()
    if valid: pfx = 'valid_'
    else: pfx  = 'invalid_'
    name = pfx + '_'.join([enc] + t) + '.xml'

# name, x is content
    try:
      alias = enc
      if enc.startswith('ISO-10646-'):
        alias = enc[10:]
      c = codecs.lookup(alias)
      if valid:
        t = EncodingTestCase('testEncodingMatches')
        t.expectedEncoding = enc
      else:
        t = EncodingTestCase('testEncodingFails')
      t.filename = name
      t.bytes = x
      suite.addTest(t)
    except LookupError,e:
      print "Skipping " + name + ": " + str(e)
      skippedNames.append(name)
  return suite

if __name__ == "__main__":
  s = buildTestSuite()
  unittest.TextTestRunner().run(s)
  if skippedNames:
    print "Tests skipped:",len(skippedNames)
    print "Please see README for details"
