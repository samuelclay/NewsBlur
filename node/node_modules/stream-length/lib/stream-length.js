var Promise, createRetrieverPromise, fs, nodeifyWrapper, retrieveBuffer, retrieveCombinedStream, retrieveCoreHttpStream, retrieveFilesystemStream, retrieveRequestHttpStream;

Promise = require("bluebird");

fs = Promise.promisifyAll(require("fs"));

nodeifyWrapper = function(callback, func) {
  return func().nodeify(callback);
};

createRetrieverPromise = function(stream, retriever) {
  return new Promise(function(resolve, reject) {
    return retriever(stream, function(result) {
      if (result != null) {
        if (result instanceof Error) {
          return reject(result);
        } else {
          return resolve(result);
        }
      } else {
        return reject(new Error("Could not find a length using this lengthRetriever."));
      }
    });
  });
};

retrieveBuffer = function(stream, callback) {
  if (stream instanceof Buffer) {
    return callback(stream.length);
  } else {
    return callback(null);
  }
};

retrieveFilesystemStream = function(stream, callback) {
  var _ref;
  if (stream.hasOwnProperty("fd")) {
    if (stream.end !== void 0 && stream.end !== Infinity && stream.start !== void 0) {
      return callback(stream.end + 1 - ((_ref = stream.start) != null ? _ref : 0));
    } else {
      return Promise["try"](function() {
        return fs.statAsync(stream.path);
      }).then(function(stat) {
        var _ref1;
        return callback(stat.size - ((_ref1 = stream.start) != null ? _ref1 : 0));
      })["catch"](function(err) {
        return callback(err);
      });
    }
  } else {
    return callback(null);
  }
};

retrieveCoreHttpStream = function(stream, callback) {
  if (stream.hasOwnProperty("httpVersion") && (stream.headers["content-length"] != null)) {
    return callback(parseInt(stream.headers["content-length"]));
  } else {
    return callback(null);
  }
};

retrieveRequestHttpStream = function(stream, callback) {
  if (stream.hasOwnProperty("httpModule")) {
    return stream.on("response", function(response) {
      if (response.headers["content-length"] != null) {
        return callback(parseInt(response.headers["content-length"]));
      } else {
        return callback(null);
      }
    });
  } else {
    return callback(null);
  }
};

retrieveCombinedStream = function(stream, callback) {
  if (stream.getCombinedStreamLength != null) {
    return stream.getCombinedStreamLength().then(function(length) {
      return callback(length);
    })["catch"](function(err) {
      return callback(err);
    });
  } else {
    return callback(null);
  }
};

module.exports = function(stream, options, callback) {
  if (options == null) {
    options = {};
  }
  return nodeifyWrapper(callback, function() {
    var retriever, retrieverPromises, _i, _j, _len, _len1, _ref, _ref1;
    retrieverPromises = [];
    if (options.lengthRetrievers != null) {
      _ref = options.lengthRetrievers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        retriever = _ref[_i];
        retrieverPromises.push(createRetrieverPromise(stream, retriever));
      }
    }
    _ref1 = [retrieveBuffer, retrieveFilesystemStream, retrieveCoreHttpStream, retrieveRequestHttpStream, retrieveCombinedStream];
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      retriever = _ref1[_j];
      retrieverPromises.push(createRetrieverPromise(stream, retriever));
    }
    return Promise.any(retrieverPromises);
  });
};
