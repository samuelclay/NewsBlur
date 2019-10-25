'use strict'

var test = require('tape')
var http = require('http')
var Buffer = require('safe-buffer').Buffer
var httpHeaders = require('./')

var requestLine = 'GET /foo HTTP/1.1\r\n'
var statusLine = 'HTTP/1.1 200 OK\r\n'
var msgHeaders = 'Date: Tue, 10 Jun 2014 07:29:20 GMT\r\n' +
  'Connection: keep-alive\r\n' +
  'Transfer-Encoding: chunked\r\n' +
  'Age: foo\r\n' +
  'Age: bar\r\n' +
  'Set-Cookie: cookie\r\n' +
  'X-List: A\r\n' +
  'X-Multi-Line-Header: Foo\r\n' +
  ' Bar\r\n' +
  'X-List: B\r\n' +
  '\r\n'
var requestMsg = requestLine + msgHeaders + 'Hello: World'
var responseMsg = statusLine + msgHeaders + 'Hello: World'

var headerResult = {
  date: 'Tue, 10 Jun 2014 07:29:20 GMT',
  connection: 'keep-alive',
  'transfer-encoding': 'chunked',
  age: 'foo',
  'set-cookie': ['cookie'],
  'x-list': 'A, B',
  'x-multi-line-header': 'Foo Bar'
}
var responseResult = {
  version: { major: 1, minor: 1 },
  statusCode: 200,
  statusMessage: 'OK',
  headers: headerResult
}
var requestResult = {
  method: 'GET',
  url: '/foo',
  version: { major: 1, minor: 1 },
  headers: headerResult
}

test('no argument', function (t) {
  t.deepEqual(httpHeaders(), {})
  t.deepEqual(httpHeaders(undefined, true), {})
  t.end()
})

test('empty string', function (t) {
  t.deepEqual(httpHeaders(''), {})
  t.deepEqual(httpHeaders('', true), {})
  t.end()
})

test('empty object', function (t) {
  t.deepEqual(httpHeaders({}), {})
  t.deepEqual(httpHeaders({}, true), {})
  t.end()
})

test('empty buffer', function (t) {
  t.deepEqual(httpHeaders(new Buffer('')), {})
  t.deepEqual(httpHeaders(new Buffer(''), true), {})
  t.end()
})

test('start-line + header', function (t) {
  t.deepEqual(httpHeaders(requestLine + msgHeaders), requestResult)
  t.deepEqual(httpHeaders(statusLine + msgHeaders), responseResult)
  t.deepEqual(httpHeaders(new Buffer(requestLine + msgHeaders)), requestResult)
  t.deepEqual(httpHeaders(new Buffer(statusLine + msgHeaders)), responseResult)
  t.deepEqual(httpHeaders(requestLine + msgHeaders, true), headerResult)
  t.deepEqual(httpHeaders(statusLine + msgHeaders, true), headerResult)
  t.deepEqual(httpHeaders(new Buffer(requestLine + msgHeaders), true), headerResult)
  t.deepEqual(httpHeaders(new Buffer(statusLine + msgHeaders), true), headerResult)
  t.end()
})

test('request-line only', function (t) {
  var requestResult = {
    method: 'GET',
    url: '/foo',
    version: { major: 1, minor: 1 },
    headers: {}
  }

  t.deepEqual(httpHeaders(requestLine + '\r\n'), requestResult)
  t.deepEqual(httpHeaders(new Buffer(requestLine + '\r\n')), requestResult)
  t.deepEqual(httpHeaders(requestLine + '\r\n', true), {})
  t.deepEqual(httpHeaders(new Buffer(requestLine + '\r\n'), true), {})
  t.end()
})

test('status-line only', function (t) {
  var responseResult = {
    version: { major: 1, minor: 1 },
    statusCode: 200,
    statusMessage: 'OK',
    headers: {}
  }

  t.deepEqual(httpHeaders(statusLine + '\r\n'), responseResult)
  t.deepEqual(httpHeaders(new Buffer(statusLine + '\r\n')), responseResult)
  t.deepEqual(httpHeaders(statusLine + '\r\n', true), {})
  t.deepEqual(httpHeaders(new Buffer(statusLine + '\r\n'), true), {})
  t.end()
})

test('headers only', function (t) {
  t.deepEqual(httpHeaders(msgHeaders), headerResult)
  t.deepEqual(httpHeaders(new Buffer(msgHeaders)), headerResult)
  t.deepEqual(httpHeaders(msgHeaders, true), headerResult)
  t.deepEqual(httpHeaders(new Buffer(msgHeaders), true), headerResult)
  t.end()
})

test('full http response', function (t) {
  t.deepEqual(httpHeaders(requestMsg), requestResult)
  t.deepEqual(httpHeaders(responseMsg), responseResult)
  t.deepEqual(httpHeaders(new Buffer(requestMsg)), requestResult)
  t.deepEqual(httpHeaders(new Buffer(responseMsg)), responseResult)
  t.deepEqual(httpHeaders(requestMsg, true), headerResult)
  t.deepEqual(httpHeaders(responseMsg, true), headerResult)
  t.deepEqual(httpHeaders(new Buffer(requestMsg), true), headerResult)
  t.deepEqual(httpHeaders(new Buffer(responseMsg), true), headerResult)
  t.end()
})

test('http.ServerResponse', function (t) {
  t.test('real http.ServerResponse object', function (t) {
    var res = new http.ServerResponse({})
    t.deepEqual(httpHeaders(res), {})
    t.deepEqual(httpHeaders(res, true), {})
    t.end()
  })

  t.test('no _header property', function (t) {
    t.deepEqual(httpHeaders({ _header: undefined }), {})
    t.deepEqual(httpHeaders({ _header: undefined }, true), {})
    t.end()
  })

  t.test('empty string as _header', function (t) {
    t.deepEqual(httpHeaders({ _header: '' }), {})
    t.deepEqual(httpHeaders({ _header: '' }, true), {})
    t.end()
  })

  t.test('normal _header property', function (t) {
    t.deepEqual(httpHeaders({ _header: statusLine + msgHeaders }), responseResult)
    t.deepEqual(httpHeaders({ _header: statusLine + msgHeaders }, true), headerResult)
    t.end()
  })
})

test('set-cookie', function (t) {
  t.deepEqual(httpHeaders('Set-Cookie: foo'), { 'set-cookie': ['foo'] })
  t.deepEqual(httpHeaders('Set-Cookie: foo\r\nSet-Cookie: bar'), { 'set-cookie': ['foo', 'bar'] })
  t.end()
})
