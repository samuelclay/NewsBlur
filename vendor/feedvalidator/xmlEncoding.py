#!/usr/bin/python

"""
$Id: xmlEncoding.py 699 2006-09-25 02:01:18Z rubys $
This module deals with detecting XML encodings, using both BOMs and
explicit declarations.
"""

__author__ = "Joseph Walton <http://www.kafsemo.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2004 Joseph Walton"

import codecs
import re
from logging import ObscureEncoding, NonstdEncoding
import logging

class FailingCodec:
  def __init__(self, name):
    self.name = name
  def fail(self, txt, errors='strict'):
    raise UnicodeError('No codec available for ' + self.name + ' in this installation of FeedValidator')

# Don't die if the codec can't be found, but return
#  a decoder that will fail on use
def getdecoder(codec):
  try:
    return codecs.getdecoder(codec)
  except:
    return FailingCodec(codec).fail

# These are generic decoders that are only used
#  to decode the XML declaration, from which we can read
#  the real encoding
_decUTF32BE = getdecoder('UTF-32BE')
_decUTF32LE = getdecoder('UTF-32LE')
_decUTF16BE = getdecoder('UTF-16BE')
_decUTF16LE = getdecoder('UTF-16LE')
_decEBCDIC = getdecoder('IBM037') # EBCDIC
_decACE = getdecoder('ISO-8859-1') # An ASCII-compatible encoding

# Given a character index into a string, calculate its 1-based row and column
def _position(txt, idx):
  row = txt.count('\n', 0, idx) + 1
  ln = txt.rfind('\n', 0, idx) + 1
  column = 0
  for c in txt[ln:idx]:
    if c == '\t':
      column = (column // 8 + 1) * 8
    else:
      column += 1
  column += 1
  return (row, column)

def _normaliseNewlines(txt):
  return txt.replace('\r\n', '\n').replace('\r', '\n')

def _logEvent(loggedEvents, e, pos=None):
  if pos:
    e.params['line'], e.params['column'] = pos
  loggedEvents.append(e)

# Return the encoding from the declaration, or 'None'
# Return None if the 'permitted' list is passed in and the encoding
#  isn't found in it. This is so that, e.g., a 4-byte-character XML file
#  that claims to be US-ASCII will fail now.
def _decodeDeclaration(sig, dec, permitted, loggedEvents):
  sig = _normaliseNewlines(dec(sig)[0])
  eo = _encodingFromDecl(sig)
  if not(eo):
    _logEvent(loggedEvents,
      logging.UnicodeError({'exception': 'This XML file (apparently ' + permitted[0] + ') requires an encoding declaration'}), (1, 1))
  elif permitted and not(eo[0].upper() in permitted):
    if _hasCodec(eo[0]):
      # see if the codec is an alias of one of the permitted encodings
      codec=codecs.lookup(eo[0])
      for encoding in permitted:
        if _hasCodec(encoding) and codecs.lookup(encoding)[-1]==codec[-1]: break
      else:
        _logEvent(loggedEvents,
          logging.UnicodeError({'exception': 'This XML file claims an encoding of ' + eo[0] + ', but looks more like ' + permitted[0]}), eo[1])
  return eo

# Return the encoding from the declaration, or 'fallback' if none is
#  present. Return None if the 'permitted' list is passed in and
#  the encoding isn't found in it
def _decodePostBOMDeclaration(sig, dec, permitted, loggedEvents, fallback=None):
  sig = _normaliseNewlines(dec(sig)[0])
  eo = _encodingFromDecl(sig)
  if eo and not(eo[0].upper() in permitted):
    _logEvent(loggedEvents,
      logging.UnicodeError({'exception': 'Document starts with ' + permitted[0] + ' BOM marker but has incompatible declaration of ' + eo[0]}), eo[1])
    return None
  else:
    return eo or (fallback, None)

def isStandard(x):
  """ Is this encoding required by the XML 1.0 Specification, 4.3.3? """
  return x.upper() in ['UTF-8', 'UTF-16']

def isCommon(x):
  """Is this encoding commonly used, according to
  <http://www.syndic8.com/stats.php?Section=feeds#XMLEncodings>
  (as of 2004-03-27)?"""

  return isStandard(x) or x.upper() in ['US-ASCII', 'ISO-8859-1',
    'EUC-JP', 'ISO-8859-2', 'ISO-8859-15', 'ISO-8859-7',
    'KOI8-R', 'SHIFT_JIS', 'WINDOWS-1250', 'WINDOWS-1251',
    'WINDOWS-1252', 'WINDOWS-1254', 'WINDOWS-1255', 'WINDOWS-1256',

    # This doesn't seem to be popular, but is the Chinese
    #  government's mandatory standard
    'GB18030'
    ]

# Inspired by xmlproc's autodetect_encoding, but rewritten
def _detect(doc_start, loggedEvents=[], fallback='UTF-8'):
  """This is the logic from appendix F.1 of the XML 1.0 specification.
  Pass in the start of a document (>= 256 octets), and receive the encoding to
  use, or None if there is a problem with the document."""
  sig = doc_start[:4]

  # With a BOM. We also check for a declaration, and make sure
  #  it doesn't contradict (for 4-byte encodings, it's required)
  if sig == '\x00\x00\xFE\xFF':  # UTF-32 BE
    eo = _decodeDeclaration(doc_start[4:], _decUTF32BE, ['UTF-32', 'ISO-10646-UCS-4', 'CSUCS4', 'UCS-4'], loggedEvents)
  elif sig == '\xFF\xFE\x00\x00':  # UTF-32 LE
    eo = _decodeDeclaration(doc_start[4:], _decUTF32LE, ['UTF-32', 'ISO-10646-UCS-4', 'CSUCS4', 'UCS-4'], loggedEvents)
  elif sig == '\x00\x00\xFF\xFE'  or sig == '\xFE\xFF\x00\x00':
    raise UnicodeError('Unable to process UCS-4 with unusual octet ordering')
  elif sig[:2] == '\xFE\xFF':  # UTF-16 BE
    eo = _decodePostBOMDeclaration(doc_start[2:], _decUTF16BE, ['UTF-16', 'ISO-10646-UCS-2', 'CSUNICODE', 'UCS-2'], loggedEvents, fallback='UTF-16')
  elif sig[:2] == '\xFF\xFE':  # UTF-16 LE
    eo = _decodePostBOMDeclaration(doc_start[2:], _decUTF16LE, ['UTF-16', 'ISO-10646-UCS-2', 'CSUNICODE', 'UCS-2'], loggedEvents, fallback='UTF-16')
  elif sig[:3] == '\xEF\xBB\xBF':
    eo = _decodePostBOMDeclaration(doc_start[3:], _decACE, ['UTF-8'], loggedEvents, fallback='UTF-8')
  
  # Without a BOM; we must read the declaration
  elif sig == '\x00\x00\x00\x3C':
    eo = _decodeDeclaration(doc_start, _decUTF32BE, ['UTF-32BE', 'UTF-32', 'ISO-10646-UCS-4', 'CSUCS4', 'UCS-4'], loggedEvents)
  elif sig == '\x3C\x00\x00\x00':
    eo = _decodeDeclaration(doc_start, _decUTF32LE, ['UTF-32LE', 'UTF-32', 'ISO-10646-UCS-4', 'CSUCS4', 'UCS-4'], loggedEvents)
  elif sig == '\x00\x3C\x00\x3F':
    eo = _decodeDeclaration(doc_start, _decUTF16BE, ['UTF-16BE', 'UTF-16', 'ISO-10646-UCS-2', 'CSUNICODE', 'UCS-2'], loggedEvents)
  elif sig == '\x3C\x00\x3F\x00':
    eo = _decodeDeclaration(doc_start, _decUTF16LE, ['UTF-16LE', 'UTF-16', 'ISO-10646-UCS-2', 'CSUNICODE', 'UCS-2'], loggedEvents)
  elif sig == '\x3C\x3F\x78\x6D':
    eo = _encodingFromDecl(_normaliseNewlines(_decACE(doc_start)[0])) or ('UTF-8', None)
  elif sig == '\x4C\x6F\xA7\x94':
    eo = _decodeDeclaration(doc_start, _decEBCDIC, ['IBM037', 'CP037', 'IBM038', 'EBCDIC-INT'], loggedEvents)

  # There's no BOM, and no declaration. It's UTF-8, or mislabelled.
  else:
    eo = (fallback, None)

  return eo

def detect(doc_start, loggedEvents=[], fallback='UTF-8'):
  eo = _detect(doc_start, loggedEvents, fallback)

  if eo:
    return eo[0]
  else:
    return None

_encRe = re.compile(r'<\?xml\s+version\s*=\s*(?:"[-a-zA-Z0-9_.:]+"|\'[-a-zA-Z0-9_.:]+\')\s+(encoding\s*=\s*(?:"([-A-Za-z0-9._]+)"|\'([-A-Za-z0-9._]+)\'))')

def _encodingFromDecl(x):
  m = _encRe.match(x)
  if m:
    if m.group(2):
      return m.group(2), _position(x, m.start(2))
    else:
      return m.group(3), _position(x, m.start(3))
  else:
    return None

def removeDeclaration(x):
  """Replace an XML document string's encoding declaration with the
  same number of spaces. Some XML parsers don't allow the
  encoding to be overridden, and this is a workaround."""
  m = _encRe.match(x)
  if m:
    s = m.start(1)
    e = m.end(1)
    res = x[:s] + ' ' * (e - s) + x[e:]
  else:
    res = x
  return res

def _hasCodec(enc):
  try:
    return codecs.lookup(enc) is not None
  except:
    return False

def decode(mediaType, charset, bs, loggedEvents, fallback=None):
  eo = _detect(bs, loggedEvents, fallback=None)

  # Check declared encodings
  if eo and eo[1] and _hasCodec(eo[0]):
    if not(isCommon(eo[0])):
      _logEvent(loggedEvents, ObscureEncoding({"encoding": eo[0]}), eo[1])
    elif not(isStandard(eo[0])):
      _logEvent(loggedEvents, NonstdEncoding({"encoding": eo[0]}), eo[1])

  if eo:
    encoding = eo[0]
  else:
    encoding = None

  if charset and encoding and charset.lower() != encoding.lower():
    # RFC 3023 requires us to use 'charset', but a number of aggregators
    # ignore this recommendation, so we should warn.
    loggedEvents.append(logging.EncodingMismatch({"charset": charset, "encoding": encoding}))

  if mediaType and mediaType.startswith("text/") and charset is None:
    loggedEvents.append(logging.TextXml({}))

    # RFC 3023 requires text/* to default to US-ASCII.  Issue a warning
    # if this occurs, but continue validation using the detected encoding
    try:
      bs.decode("US-ASCII")
    except:
      if not encoding:
        try:
          bs.decode(fallback)
          encoding=fallback
        except:
          pass
      if encoding and encoding.lower() != 'us-ascii':
        loggedEvents.append(logging.EncodingMismatch({"charset": "US-ASCII", "encoding": encoding}))

  enc = charset or encoding

  if enc is None:
    loggedEvents.append(logging.MissingEncoding({}))
    enc = fallback
  elif not(_hasCodec(enc)):
    if eo:
      _logEvent(loggedEvents, logging.UnknownEncoding({'encoding': enc}), eo[1])
    else:
      _logEvent(loggedEvents, logging.UnknownEncoding({'encoding': enc}))
    enc = fallback

  if enc is None:
    return enc, None

  dec = getdecoder(enc)
  try:
    return enc, dec(bs)[0]
  except UnicodeError, ue:
    salvage = dec(bs, 'replace')[0]
    if 'start' in ue.__dict__:
      # XXX 'start' is in bytes, not characters. This is wrong for multibyte
      #  encodings
      pos = _position(salvage, ue.start)
    else:
      pos = None

    _logEvent(loggedEvents, logging.UnicodeError({"exception":ue}), pos)

    return enc, salvage


_encUTF8 = codecs.getencoder('UTF-8')

def asUTF8(x):
  """Accept a Unicode string and return a UTF-8 encoded string, with
  its encoding declaration removed, suitable for parsing."""
  x = removeDeclaration(unicode(x))
  return _encUTF8(x)[0]


if __name__ == '__main__':
  from sys import argv
  from os.path import isfile

  for x in argv[1:]:
    if isfile(x):
      f = open(x, 'r')
      l = f.read(1024)
      log = []
      eo = detect(l, log)
      if eo:
        print x,eo
      else:
        print repr(log)
