'use strict'

module.exports = function (str) {
  var offset = 0
  str = str.toString()

  return iterator

  function iterator () {
    var i1 = str.indexOf('\r\n', offset)
    var i2 = str.indexOf('\n', offset)
    var i3 = str.indexOf('\r', offset)

    var indexes = [i1, i2, i3]
    var index = indexes
      .sort(function (a, b) {
        if (a > b) return 1
        if (a < b) return -1
        return 0
      })
      .filter(function (index) {
        return index !== -1
      })[0]

    if (index !== undefined) return extract(index, index === i1 ? 2 : 1)

    var length = str.length
    if (length === offset) return null

    return extract(length, 0)
  }

  function extract (index, skip) {
    var line = str.substr(offset, index - offset)
    offset = index + skip
    return line
  }
}
