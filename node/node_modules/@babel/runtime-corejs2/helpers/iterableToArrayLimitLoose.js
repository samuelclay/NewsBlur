var _getIterator = require("../core-js/get-iterator");

function _iterableToArrayLimitLoose(arr, i) {
  var _arr = [];

  for (var _iterator = _getIterator(arr), _step; !(_step = _iterator.next()).done;) {
    _arr.push(_step.value);

    if (i && _arr.length === i) break;
  }

  return _arr;
}

module.exports = _iterableToArrayLimitLoose;