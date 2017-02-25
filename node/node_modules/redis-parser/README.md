[![Build Status](https://travis-ci.org/NodeRedis/node-redis-parser.png?branch=master)](https://travis-ci.org/NodeRedis/node-redis-parser)
[![Code Climate](https://codeclimate.com/github/NodeRedis/node-redis-parser/badges/gpa.svg)](https://codeclimate.com/github/NodeRedis/node-redis-parser)
[![Test Coverage](https://codeclimate.com/github/NodeRedis/node-redis-parser/badges/coverage.svg)](https://codeclimate.com/github/NodeRedis/node-redis-parser/coverage)
[![js-standard-style](https://img.shields.io/badge/code%20style-standard-brightgreen.svg)](http://standardjs.com/)

# redis-parser

A high performance javascript redis parser built for [node_redis](https://github.com/NodeRedis/node_redis) and [ioredis](https://github.com/luin/ioredis). Parses all [RESP](http://redis.io/topics/protocol) data.

## Install

Install with [NPM](https://npmjs.org/):

    npm install redis-parser

## Usage

```js
var Parser = require('redis-parser');

var myParser = new Parser(options);
```

### Possible options

* `returnReply`: *function*; mandatory
* `returnError`: *function*; mandatory
* `returnFatalError`: *function*; optional, defaults to the returnError function
* `returnBuffers`: *boolean*; optional, defaults to false
* `stringNumbers`: *boolean*; optional, defaults to false

### Example

```js
var Parser = require("redis-parser");

function Library () {}

Library.prototype.returnReply = function (reply) { ... }
Library.prototype.returnError = function (err) { ... }
Library.prototype.returnFatalError = function (err) { ... }

var lib = new Library();

var parser = new Parser({
    returnReply: function(reply) {
        lib.returnReply(reply);
    },
    returnError: function(err) {
        lib.returnError(err);
    },
    returnFatalError: function (err) {
        lib.returnFatalError(err);
    }
});

Library.prototype.streamHandler = function () {
    this.stream.on('data', function (buffer) {
        // Here the data (e.g. `new Buffer('$5\r\nHello\r\n'`)) is passed to the parser and the result is passed to either function depending on the provided data.
        parser.execute(buffer);
    });
};
```
You do not have to use the returnFatalError function. Fatal errors will be returned in the normal error function in that case.

And if you want to return buffers instead of strings, you can do this by adding the `returnBuffers` option.

If you handle with big numbers that are to large for JS (Number.MAX_SAFE_INTEGER === 2^53 - 16) please use the `stringNumbers` option. That way all numbers are going to be returned as String and you can handle them safely.

```js
// Same functions as in the first example

var parser = new Parser({
    returnReply: function(reply) {
        lib.returnReply(reply);
    },
    returnError: function(err) {
        lib.returnError(err);
    },
    returnBuffers: true, // All strings are returned as Buffer e.g. <Buffer 48 65 6c 6c 6f>
    stringNumbers: true // All numbers are returned as String
});

// The streamHandler as above
```

## Protocol errors

To handle protocol errors (this is very unlikely to happen) gracefully you should add the returnFatalError option, reject any still running command (they might have been processed properly but the reply is just wrong), destroy the socket and reconnect. Note that while doing this no new command may be added, so all new commands have to be buffered in the meantime, otherwise a chunk might still contain partial data of a following command that was already processed properly but answered in the same chunk as the command that resulted in the protocol error.

## Contribute

The parser is highly optimized but there may still be further optimizations possible.

    npm install
    npm test
    npm run benchmark

Currently the benchmark compares the performance against the hiredis parser:

    HIREDIS: $ multiple chunks in a bulk string x 867,643 ops/sec ±1.39% (82 runs sampled)
    HIREDIS BUF: $ multiple chunks in a bulk string x 591,398 ops/sec ±1.48% (83 runs sampled)
    JS PARSER: $ multiple chunks in a bulk string x 942,834 ops/sec ±0.87% (90 runs sampled)
    JS PARSER BUF: $ multiple chunks in a bulk string x 1,081,096 ops/sec ±1.81% (85 runs sampled)

    HIREDIS: + multiple chunks in a string x 1,785,222 ops/sec ±0.59% (92 runs sampled)
    HIREDIS BUF: + multiple chunks in a string x 902,391 ops/sec ±1.62% (88 runs sampled)
    JS PARSER: + multiple chunks in a string x 1,936,709 ops/sec ±1.07% (90 runs sampled)
    JS PARSER BUF: + multiple chunks in a string x 1,954,798 ops/sec ±0.84% (91 runs sampled)

    HIREDIS: $ 4mb bulk string x 344 ops/sec ±1.40% (85 runs sampled)
    HIREDIS BUF: $ 4mb bulk string x 555 ops/sec ±1.85% (80 runs sampled)
    JS PARSER: $ 4mb bulk string x 834 ops/sec ±1.23% (81 runs sampled)
    JS PARSER BUF: $ 4mb bulk string x 620 ops/sec ±2.40% (59 runs sampled)

    HIREDIS: + simple string x 2,344,042 ops/sec ±1.45% (91 runs sampled)
    HIREDIS BUF: + simple string x 993,081 ops/sec ±1.87% (83 runs sampled)
    JS PARSER: + simple string x 4,431,517 ops/sec ±1.86% (88 runs sampled)
    JS PARSER BUF: + simple string x 5,259,552 ops/sec ±0.61% (96 runs sampled)

    HIREDIS: : integer x 2,376,642 ops/sec ±0.30% (92 runs sampled)
    JS PARSER: : integer x 17,765,077 ops/sec ±0.53% (93 runs sampled)
    JS PARSER STR: : integer x 13,110,365 ops/sec ±0.67% (91 runs sampled)

    HIREDIS: : big integer x 2,010,124 ops/sec ±0.87% (86 runs sampled)
    JS PARSER: : big integer x 10,277,063 ops/sec ±0.69% (91 runs sampled)
    JS PARSER STR: : big integer x 4,492,626 ops/sec ±0.67% (94 runs sampled)

    HIREDIS: * array x 43,763 ops/sec ±0.84% (94 runs sampled)
    HIREDIS BUF: * array x 13,893 ops/sec ±1.05% (85 runs sampled)
    JS PARSER: * array x 50,825 ops/sec ±1.92% (80 runs sampled)
    JS PARSER BUF: * array x 72,546 ops/sec ±0.80% (94 runs sampled)

    HIREDIS: * big array x 265 ops/sec ±1.46% (86 runs sampled)
    HIREDIS BUF: * big array x 226 ops/sec ±3.21% (75 runs sampled)
    JS PARSER: * big array x 201 ops/sec ±0.95% (83 runs sampled)
    JS PARSER BUF: * big array x 244 ops/sec ±2.65% (81 runs sampled)

    HIREDIS: - error x 81,563 ops/sec ±0.51% (93 runs sampled)
    JS PARSER: - error x 155,225 ops/sec ±0.57% (95 runs sampled)

    Platform info:
    Ubuntu 16.10
    Node.js 7.1.0
    Intel(R) Core(TM) i7-5600U CPU

## License

[MIT](./LICENSE)
