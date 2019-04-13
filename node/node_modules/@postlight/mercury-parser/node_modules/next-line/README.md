# next-line

Iterator over lines in a string:

- Support different newline types: CRLF, LF, CR
- Support mixed newline formats in the same string

[![Build status](https://travis-ci.org/watson/next-line.svg?branch=master)](https://travis-ci.org/watson/next-line)
[![js-standard-style](https://img.shields.io/badge/code%20style-standard-brightgreen.svg?style=flat)](https://github.com/feross/standard)

## Installation

```
npm install next-line
```

## Usage

```js
var next = require('next-line')('foo\r\nbar\nbaz')

console.log(next()) // => foo
console.log(next()) // => bar
console.log(next()) // => baz
console.log(next()) // => null
```

## License

MIT
