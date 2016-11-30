try {
  exports.BSONPure = require('./bson');
  exports.BSONNative = require('./bson');
} catch(err) {
}

[ 'binary'
  , 'code'
  , 'map'
  , 'db_ref'
  , 'double'
  , 'int_32'
  , 'max_key'
  , 'min_key'
  , 'objectid'
  , 'regexp'
  , 'symbol'
  , 'decimal128'
  , 'timestamp'
  , 'long'
  , 'bson'].forEach(function (path) {
  	var module = require('./' + path);
  	for (var i in module) {
  		exports[i] = module[i];
    }
});

// Exports all the classes for the PURE JS BSON Parser
exports.pure = function() {
  var classes = {};
  // Map all the classes
  [ 'binary'
    , 'code'
    , 'map'
    , 'db_ref'
    , 'double'
    , 'int_32'
    , 'max_key'
    , 'min_key'
    , 'objectid'
    , 'regexp'
    , 'symbol'
    , 'decimal128'
    , 'timestamp'
    , 'long'
    , 'bson'].forEach(function (path) {
    	var module = require('./' + path);
    	for (var i in module) {
    		classes[i] = module[i];
      }
  });
  // Return classes list
  return classes;
}

// Exports all the classes for the NATIVE JS BSON Parser
exports.native = function() {
  var classes = {};
  // Map all the classes
  [ 'binary'
    , 'code'
    , 'map'
    , 'db_ref'
    , 'double'
    , 'int_32'
    , 'max_key'
    , 'min_key'
    , 'objectid'
    , 'regexp'
    , 'symbol'
    , 'decimal128'
    , 'timestamp'
    , 'long'
    , 'bson'].forEach(function (path) {
      var module = require('./' + path);
      for (var i in module) {
        classes[i] = module[i];
      }
  });

  // Catch error and return no classes found
  try {
    classes['BSON'] = require('./bson');
  } catch(err) {
    return exports.pure();
  }

  // Return classes list
  return classes;
}
