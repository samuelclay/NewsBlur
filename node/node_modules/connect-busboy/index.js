var Busboy = require('busboy');

var RE_MIME = /^(?:multipart\/.+)|(?:application\/x-www-form-urlencoded)$/i;

module.exports = function(options) {
  options = options || {};

  return function(req, res, next) {
    if (req.busboy
        || req.method === 'GET'
        || req.method === 'HEAD'
        || !hasBody(req)
        || !RE_MIME.test(mime(req)))
      return next();

    var cfg = {};
    for (var prop in options)
      cfg[prop] = options[prop];
    cfg.headers = req.headers;

    req.busboy = new Busboy(cfg);

    if (options.immediate) {
      process.nextTick(function() {
        req.pipe(req.busboy);
      });
    }

    next();
  };
};

// utility functions copied from Connect

function hasBody(req) {
  var encoding = 'transfer-encoding' in req.headers,
      length = 'content-length' in req.headers
               && req.headers['content-length'] !== '0';
  return encoding || length;
};

function mime(req) {
  var str = req.headers['content-type'] || '';
  return str.split(';')[0];
};