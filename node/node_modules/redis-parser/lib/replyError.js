'use strict'

var util = require('util')

function ReplyError (message, newLimit) {
  var limit = Error.stackTraceLimit
  Error.stackTraceLimit = newLimit || 2
  Error.call(this, message)
  Error.captureStackTrace(this, this.constructor)
  Error.stackTraceLimit = limit
  Object.defineProperty(this, 'message', {
    value: message || '',
    writable: true
  })
}

util.inherits(ReplyError, Error)

Object.defineProperty(ReplyError.prototype, 'name', {
  value: 'ReplyError',
  writable: true
})

module.exports = ReplyError
