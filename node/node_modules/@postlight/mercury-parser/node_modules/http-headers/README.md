# http-headers

[![Build status](https://travis-ci.org/watson/http-headers.svg?branch=master)](https://travis-ci.org/watson/http-headers)
[![js-standard-style](https://img.shields.io/badge/code%20style-standard-brightgreen.svg?style=flat)](https://github.com/feross/standard)

Parse the start-line and headers from an HTTP request or reponse.

Converts:

```http
HTTP/1.1 200 OK
Date: Tue, 10 Jun 2014 07:19:27 GMT
Connection: keep-alive
Transfer-Encoding: chunked

Hello World
```

To this:

```js
{
  version: { major: 1, minor: 1 },
  statusCode: 200,
  statusMessage: 'OK',
  headers: {
    date: 'Tue, 10 Jun 2014 07:19:27 GMT',
    connection: 'keep-alive',
    'transfer-encoding': 'chunked'
  }
}
```

**Features:**

- Auto-detects and ignores body if present
- Fully [RFC 2068](http://www.rfc-base.org/txt/rfc-2068.txt) compliant
  (please [open an issue](https://github.com/watson/http-headers/issues)
  if you find a discrepancy)
- Support multi-line headers (lines will be joined with a space)
- Support repeating headers

## Installation

```
npm install http-headers --save
```

## Usage

```js
var net = require('net')
var httpHeaders = require('http-headers')

// create TCP server
net.createServer(function (c) {
  var buffers = []
  c.on('data', buffers.push.bind(buffers))
  c.on('end', function () {
    var data = Buffer.concat(buffers)

    // parse incoming data as an HTTP request and extra HTTP headers
    console.log(httpHeaders(data))
  })
}).listen(8080)
```

### `http.ServerReponse` support

If given an instance of `http.ServerResponse`, the reponse headers is
automatically extracted, parsed and returned:

```js
var http = require('http')
var httpHeaders = require('http-headers')

http.createServer(function (req, res) {
  res.end('Hello World')
  console.log(httpHeaders(res))
}).listen(8080)
```

#### Why?

If you've ever needed to log or in another way access the headers sent
to the client on a `http.ServerResponse` in Node.js, you know it's not
as easy as with the `http.IncomingMessage` headers (which you just
access via `request.headers['content-type']`).

Response headers are not directly available on the `response` object.
Instead all headers are preprocessed as a string on the private
`response._header` property and needs to be processed in order to be
available as an object.

This module makes the task super simple.

## API

The http-headers module exposes a single parser function:

```js
httpHeaders(data[, onlyHeaders])
```

Arguments:

- `data` - A string, buffer or instance of `http.ServerReponse`
- `onlyHeaders` - An optional boolean. If `true`, only the headers
  object will be returned. Defaults to `false`

### Request example

If given a request as input:

```http
GET /foo HTTP/1.1
Date: Tue, 10 Jun 2014 07:19:27 GMT
Connection: keep-alive
Transfer-Encoding: chunked

Hello World
```

Returns:

```js
{
  method: 'GET',
  url: '/foo',
  version: { major: 1, minor: 1 },
  headers: {
    date: 'Tue, 10 Jun 2014 07:19:27 GMT',
    connection: 'keep-alive',
    'transfer-encoding': 'chunked'
  }
}
```

### Response example

If given a request as input:

```http
HTTP/1.1 200 OK
Date: Tue, 10 Jun 2014 07:19:27 GMT
Connection: keep-alive
Transfer-Encoding: chunked

Hello World
```

Returns:

```js
{
  version: { major: 1, minor: 1 },
  statusCode: 200,
  statusMessage: 'OK',
  headers: {
    date: 'Tue, 10 Jun 2014 07:19:27 GMT',
    connection: 'keep-alive',
    'transfer-encoding': 'chunked'
  }
}
```

### `onlyHeaders` example

If the optional second argument is set to `true`, only headers are
returned no matter the type of input:

```js
{
  date: 'Tue, 10 Jun 2014 07:19:27 GMT',
  connection: 'keep-alive',
  'transfer-encoding': 'chunked'
}
```

### No Start-Line

If the `data` given does not contain an HTTP Start-Line, only the
headers are returned, even if the `onlyHeaders` argument is `false`:

```http
Date: Tue, 10 Jun 2014 07:19:27 GMT
Connection: keep-alive
Transfer-Encoding: chunked

Hello World
```

Returns:

```js
{
  date: 'Tue, 10 Jun 2014 07:19:27 GMT',
  connection: 'keep-alive',
  'transfer-encoding': 'chunked'
}
```

## License

MIT
