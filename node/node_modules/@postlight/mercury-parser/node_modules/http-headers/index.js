'use strict'

var nextLine = require('next-line')

// RFC-2068 Start-Line definitions:
//   Request-Line: Method SP Request-URI SP HTTP-Version CRLF
//   Status-Line:  HTTP-Version SP Status-Code SP Reason-Phrase CRLF
var startLine = /^[A-Z_]+(\/\d\.\d)? /
var requestLine = /^([A-Z_]+) (.+) [A-Z]+\/(\d)\.(\d)$/
var statusLine = /^[A-Z]+\/(\d)\.(\d) (\d{3}) (.*)$/

module.exports = function (data, onlyHeaders) {
  return parse(normalize(data), onlyHeaders)
}

function parse (str, onlyHeaders) {
  var line = firstLine(str)
  var match

  if (onlyHeaders && startLine.test(line)) {
    return parseHeaders(str)
  } else if ((match = line.match(requestLine)) !== null) {
    return {
      method: match[1],
      url: match[2],
      version: { major: parseInt(match[3], 10), minor: parseInt(match[4], 10) },
      headers: parseHeaders(str)
    }
  } else if ((match = line.match(statusLine)) !== null) {
    return {
      version: { major: parseInt(match[1], 10), minor: parseInt(match[2], 10) },
      statusCode: parseInt(match[3], 10),
      statusMessage: match[4],
      headers: parseHeaders(str)
    }
  } else {
    return parseHeaders(str)
  }
}

function parseHeaders (str) {
  var headers = {}
  var next = nextLine(str)
  var line = next()
  var index, name, value

  if (startLine.test(line)) line = next()

  while (line) {
    // subsequent lines in multi-line headers start with whitespace
    if (line[0] === ' ' || line[0] === '\t') {
      value += ' ' + line.trim()
      line = next()
      continue
    }

    if (name) addHeaderLine(name, value, headers)

    index = line.indexOf(':')
    name = line.substr(0, index)
    value = line.substr(index + 1).trim()

    line = next()
  }

  if (name) addHeaderLine(name, value, headers)

  return headers
}

function normalize (str) {
  if (str && str._header) str = str._header // extra headers from http.ServerResponse object
  if (!str || typeof str.toString !== 'function') return ''
  return str.toString().trim()
}

function firstLine (str) {
  var nl = str.indexOf('\r\n')
  if (nl === -1) return str
  else return str.slice(0, nl)
}

// The following function is lifted from:
// https://github.com/nodejs/node/blob/f1294f5bfd7f02bce8029818be9c92de59749137/lib/_http_incoming.js#L116-L170
//
// Add the given (field, value) pair to the message
//
// Per RFC2616, section 4.2 it is acceptable to join multiple instances of the
// same header with a ', ' if the header in question supports specification of
// multiple values this way. If not, we declare the first instance the winner
// and drop the second. Extended header fields (those beginning with 'x-') are
// always joined.
function addHeaderLine (field, value, dest) {
  field = field.toLowerCase()
  switch (field) {
    // Array headers:
    case 'set-cookie':
      if (dest[field] !== undefined) {
        dest[field].push(value)
      } else {
        dest[field] = [value]
      }
      break

    // list is taken from:
    // https://mxr.mozilla.org/mozilla/source/netwerk/protocol/http/src/nsHttpHeaderArray.cpp
    case 'content-type':
    case 'content-length':
    case 'user-agent':
    case 'referer':
    case 'host':
    case 'authorization':
    case 'proxy-authorization':
    case 'if-modified-since':
    case 'if-unmodified-since':
    case 'from':
    case 'location':
    case 'max-forwards':
    case 'retry-after':
    case 'etag':
    case 'last-modified':
    case 'server':
    case 'age':
    case 'expires':
      // drop duplicates
      if (dest[field] === undefined) dest[field] = value
      break

    default:
      // make comma-separated list
      if (typeof dest[field] === 'string') {
        dest[field] += ', ' + value
      } else {
        dest[field] = value
      }
  }
}
