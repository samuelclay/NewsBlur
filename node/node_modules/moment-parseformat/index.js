var parseFormat = require('./lib/parseformat')
module.exports = parseFormat

/* istanbul ignore next */
if (typeof window !== 'undefined' && window.moment) {
  window.moment.parseFormat = parseFormat
}
