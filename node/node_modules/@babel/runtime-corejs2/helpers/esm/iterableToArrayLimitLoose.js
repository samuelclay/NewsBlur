import _getIterator from "../../core-js/get-iterator";
export default function _iterableToArrayLimitLoose(arr, i) {
  var _arr = [];

  for (var _iterator = _getIterator(arr), _step; !(_step = _iterator.next()).done;) {
    _arr.push(_step.value);

    if (i && _arr.length === i) break;
  }

  return _arr;
}