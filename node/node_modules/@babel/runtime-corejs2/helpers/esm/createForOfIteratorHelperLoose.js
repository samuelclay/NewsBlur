import _getIterator from "../../core-js/get-iterator";
import _Array$isArray from "../../core-js/array/is-array";
import _Symbol$iterator from "../../core-js/symbol/iterator";
import _Symbol from "../../core-js/symbol";
import unsupportedIterableToArray from "./unsupportedIterableToArray";
export default function _createForOfIteratorHelperLoose(o, allowArrayLike) {
  var it;

  if (typeof _Symbol === "undefined" || o[_Symbol$iterator] == null) {
    if (_Array$isArray(o) || (it = unsupportedIterableToArray(o)) || allowArrayLike && o && typeof o.length === "number") {
      if (it) o = it;
      var i = 0;
      return function () {
        if (i >= o.length) return {
          done: true
        };
        return {
          done: false,
          value: o[i++]
        };
      };
    }

    throw new TypeError("Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.");
  }

  it = _getIterator(o);
  return it.next.bind(it);
}