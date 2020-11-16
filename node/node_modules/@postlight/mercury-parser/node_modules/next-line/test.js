'use strict'

var test = require('tape')
var nextLine = require('./')

var strings = [
  'a\nb\nc\nd\n\ne',
  'a\rb\rc\rd\r\re',
  'a\r\nb\r\nc\r\nd\r\n\r\ne',
  'a\r\nb\nc\rd\r\n\ne',
  'a\r\nb\rc\nd\r\n\re'
]

strings.forEach(function (str, index) {
  test('string ' + index, function (t) {
    var next = nextLine(str)
    t.equal(next(), 'a')
    t.equal(next(), 'b')
    t.equal(next(), 'c')
    t.equal(next(), 'd')
    t.equal(next(), '')
    t.equal(next(), 'e')
    t.equal(next(), null)
    t.end()
  })
})

strings.forEach(function (str, index) {
  test('buffer ' + index, function (t) {
    var next = nextLine(new Buffer(str))
    t.equal(next(), 'a')
    t.equal(next(), 'b')
    t.equal(next(), 'c')
    t.equal(next(), 'd')
    t.equal(next(), '')
    t.equal(next(), 'e')
    t.equal(next(), null)
    t.end()
  })
})
