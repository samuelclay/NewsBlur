/*!***************************************************
* mark.js v9.0.0
* https://markjs.io/
* Copyright (c) 2014–2018, Julian Kühnel
* Released under the MIT license https://git.io/vwTVl
*****************************************************/

(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory(require('jquery')) :
  typeof define === 'function' && define.amd ? define(['jquery'], factory) :
  (global.Mark = factory(global.jQuery));
}(this, (function ($) { 'use strict';

  $ = $ && $.hasOwnProperty('default') ? $['default'] : $;

  function _typeof(obj) {
    if (typeof Symbol === "function" && typeof Symbol.iterator === "symbol") {
      _typeof = function (obj) {
        return typeof obj;
      };
    } else {
      _typeof = function (obj) {
        return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj;
      };
    }

    return _typeof(obj);
  }

  function _classCallCheck(instance, Constructor) {
    if (!(instance instanceof Constructor)) {
      throw new TypeError("Cannot call a class as a function");
    }
  }

  function _defineProperties(target, props) {
    for (var i = 0; i < props.length; i++) {
      var descriptor = props[i];
      descriptor.enumerable = descriptor.enumerable || false;
      descriptor.configurable = true;
      if ("value" in descriptor) descriptor.writable = true;
      Object.defineProperty(target, descriptor.key, descriptor);
    }
  }

  function _createClass(Constructor, protoProps, staticProps) {
    if (protoProps) _defineProperties(Constructor.prototype, protoProps);
    if (staticProps) _defineProperties(Constructor, staticProps);
    return Constructor;
  }

  function _extends() {
    _extends = Object.assign || function (target) {
      for (var i = 1; i < arguments.length; i++) {
        var source = arguments[i];

        for (var key in source) {
          if (Object.prototype.hasOwnProperty.call(source, key)) {
            target[key] = source[key];
          }
        }
      }

      return target;
    };

    return _extends.apply(this, arguments);
  }

  var DOMIterator =
  /*#__PURE__*/
  function () {
    function DOMIterator(ctx) {
      var iframes = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : true;
      var exclude = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : [];
      var iframesTimeout = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : 5000;

      _classCallCheck(this, DOMIterator);

      this.ctx = ctx;
      this.iframes = iframes;
      this.exclude = exclude;
      this.iframesTimeout = iframesTimeout;
    }

    _createClass(DOMIterator, [{
      key: "getContexts",
      value: function getContexts() {
        var ctx,
            filteredCtx = [];

        if (typeof this.ctx === 'undefined' || !this.ctx) {
          ctx = [];
        } else if (NodeList.prototype.isPrototypeOf(this.ctx)) {
          ctx = Array.prototype.slice.call(this.ctx);
        } else if (Array.isArray(this.ctx)) {
          ctx = this.ctx;
        } else if (typeof this.ctx === 'string') {
          ctx = Array.prototype.slice.call(document.querySelectorAll(this.ctx));
        } else {
          ctx = [this.ctx];
        }

        ctx.forEach(function (ctx) {
          var isDescendant = filteredCtx.filter(function (contexts) {
            return contexts.contains(ctx);
          }).length > 0;

          if (filteredCtx.indexOf(ctx) === -1 && !isDescendant) {
            filteredCtx.push(ctx);
          }
        });
        return filteredCtx;
      }
    }, {
      key: "getIframeContents",
      value: function getIframeContents(ifr, successFn) {
        var errorFn = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : function () {};
        var doc;

        try {
          var ifrWin = ifr.contentWindow;
          doc = ifrWin.document;

          if (!ifrWin || !doc) {
            throw new Error('iframe inaccessible');
          }
        } catch (e) {
          errorFn();
        }

        if (doc) {
          successFn(doc);
        }
      }
    }, {
      key: "isIframeBlank",
      value: function isIframeBlank(ifr) {
        var bl = 'about:blank',
            src = ifr.getAttribute('src').trim(),
            href = ifr.contentWindow.location.href;
        return href === bl && src !== bl && src;
      }
    }, {
      key: "observeIframeLoad",
      value: function observeIframeLoad(ifr, successFn, errorFn) {
        var _this = this;

        var called = false,
            tout = null;

        var listener = function listener() {
          if (called) {
            return;
          }

          called = true;
          clearTimeout(tout);

          try {
            if (!_this.isIframeBlank(ifr)) {
              ifr.removeEventListener('load', listener);

              _this.getIframeContents(ifr, successFn, errorFn);
            }
          } catch (e) {
            errorFn();
          }
        };

        ifr.addEventListener('load', listener);
        tout = setTimeout(listener, this.iframesTimeout);
      }
    }, {
      key: "onIframeReady",
      value: function onIframeReady(ifr, successFn, errorFn) {
        try {
          if (ifr.contentWindow.document.readyState === 'complete') {
            if (this.isIframeBlank(ifr)) {
              this.observeIframeLoad(ifr, successFn, errorFn);
            } else {
              this.getIframeContents(ifr, successFn, errorFn);
            }
          } else {
            this.observeIframeLoad(ifr, successFn, errorFn);
          }
        } catch (e) {
          errorFn();
        }
      }
    }, {
      key: "waitForIframes",
      value: function waitForIframes(ctx, done) {
        var _this2 = this;

        var eachCalled = 0;
        this.forEachIframe(ctx, function () {
          return true;
        }, function (ifr) {
          eachCalled++;

          _this2.waitForIframes(ifr.querySelector('html'), function () {
            if (! --eachCalled) {
              done();
            }
          });
        }, function (handled) {
          if (!handled) {
            done();
          }
        });
      }
    }, {
      key: "forEachIframe",
      value: function forEachIframe(ctx, filter, each) {
        var _this3 = this;

        var end = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : function () {};
        var ifr = ctx.querySelectorAll('iframe'),
            open = ifr.length,
            handled = 0;
        ifr = Array.prototype.slice.call(ifr);

        var checkEnd = function checkEnd() {
          if (--open <= 0) {
            end(handled);
          }
        };

        if (!open) {
          checkEnd();
        }

        ifr.forEach(function (ifr) {
          if (DOMIterator.matches(ifr, _this3.exclude)) {
            checkEnd();
          } else {
            _this3.onIframeReady(ifr, function (con) {
              if (filter(ifr)) {
                handled++;
                each(con);
              }

              checkEnd();
            }, checkEnd);
          }
        });
      }
    }, {
      key: "createIterator",
      value: function createIterator(ctx, whatToShow, filter) {
        return document.createNodeIterator(ctx, whatToShow, filter, false);
      }
    }, {
      key: "createInstanceOnIframe",
      value: function createInstanceOnIframe(contents) {
        return new DOMIterator(contents.querySelector('html'), this.iframes);
      }
    }, {
      key: "compareNodeIframe",
      value: function compareNodeIframe(node, prevNode, ifr) {
        var compCurr = node.compareDocumentPosition(ifr),
            prev = Node.DOCUMENT_POSITION_PRECEDING;

        if (compCurr & prev) {
          if (prevNode !== null) {
            var compPrev = prevNode.compareDocumentPosition(ifr),
                after = Node.DOCUMENT_POSITION_FOLLOWING;

            if (compPrev & after) {
              return true;
            }
          } else {
            return true;
          }
        }

        return false;
      }
    }, {
      key: "getIteratorNode",
      value: function getIteratorNode(itr) {
        var prevNode = itr.previousNode();
        var node;

        if (prevNode === null) {
          node = itr.nextNode();
        } else {
          node = itr.nextNode() && itr.nextNode();
        }

        return {
          prevNode: prevNode,
          node: node
        };
      }
    }, {
      key: "checkIframeFilter",
      value: function checkIframeFilter(node, prevNode, currIfr, ifr) {
        var key = false,
            handled = false;
        ifr.forEach(function (ifrDict, i) {
          if (ifrDict.val === currIfr) {
            key = i;
            handled = ifrDict.handled;
          }
        });

        if (this.compareNodeIframe(node, prevNode, currIfr)) {
          if (key === false && !handled) {
            ifr.push({
              val: currIfr,
              handled: true
            });
          } else if (key !== false && !handled) {
            ifr[key].handled = true;
          }

          return true;
        }

        if (key === false) {
          ifr.push({
            val: currIfr,
            handled: false
          });
        }

        return false;
      }
    }, {
      key: "handleOpenIframes",
      value: function handleOpenIframes(ifr, whatToShow, eCb, fCb) {
        var _this4 = this;

        ifr.forEach(function (ifrDict) {
          if (!ifrDict.handled) {
            _this4.getIframeContents(ifrDict.val, function (con) {
              _this4.createInstanceOnIframe(con).forEachNode(whatToShow, eCb, fCb);
            });
          }
        });
      }
    }, {
      key: "iterateThroughNodes",
      value: function iterateThroughNodes(whatToShow, ctx, eachCb, filterCb, doneCb) {
        var _this5 = this;

        var itr = this.createIterator(ctx, whatToShow, filterCb);

        var ifr = [],
            elements = [],
            node,
            prevNode,
            retrieveNodes = function retrieveNodes() {
          var _this5$getIteratorNod = _this5.getIteratorNode(itr);

          prevNode = _this5$getIteratorNod.prevNode;
          node = _this5$getIteratorNod.node;
          return node;
        };

        while (retrieveNodes()) {
          if (this.iframes) {
            this.forEachIframe(ctx, function (currIfr) {
              return _this5.checkIframeFilter(node, prevNode, currIfr, ifr);
            }, function (con) {
              _this5.createInstanceOnIframe(con).forEachNode(whatToShow, function (ifrNode) {
                return elements.push(ifrNode);
              }, filterCb);
            });
          }

          elements.push(node);
        }

        elements.forEach(function (node) {
          eachCb(node);
        });

        if (this.iframes) {
          this.handleOpenIframes(ifr, whatToShow, eachCb, filterCb);
        }

        doneCb();
      }
    }, {
      key: "forEachNode",
      value: function forEachNode(whatToShow, each, filter) {
        var _this6 = this;

        var done = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : function () {};
        var contexts = this.getContexts();
        var open = contexts.length;

        if (!open) {
          done();
        }

        contexts.forEach(function (ctx) {
          var ready = function ready() {
            _this6.iterateThroughNodes(whatToShow, ctx, each, filter, function () {
              if (--open <= 0) {
                done();
              }
            });
          };

          if (_this6.iframes) {
            _this6.waitForIframes(ctx, ready);
          } else {
            ready();
          }
        });
      }
    }], [{
      key: "matches",
      value: function matches(element, selector) {
        var selectors = typeof selector === 'string' ? [selector] : selector,
            fn = element.matches || element.matchesSelector || element.msMatchesSelector || element.mozMatchesSelector || element.oMatchesSelector || element.webkitMatchesSelector;

        if (fn) {
          var match = false;
          selectors.every(function (sel) {
            if (fn.call(element, sel)) {
              match = true;
              return false;
            }

            return true;
          });
          return match;
        } else {
          return false;
        }
      }
    }]);

    return DOMIterator;
  }();

  var RegExpCreator =
  /*#__PURE__*/
  function () {
    function RegExpCreator(options) {
      _classCallCheck(this, RegExpCreator);

      this.opt = _extends({}, {
        'diacritics': true,
        'synonyms': {},
        'accuracy': 'partially',
        'caseSensitive': false,
        'ignoreJoiners': false,
        'ignorePunctuation': [],
        'wildcards': 'disabled'
      }, options);
    }

    _createClass(RegExpCreator, [{
      key: "create",
      value: function create(str) {
        if (this.opt.wildcards !== 'disabled') {
          str = this.setupWildcardsRegExp(str);
        }

        str = this.escapeStr(str);

        if (Object.keys(this.opt.synonyms).length) {
          str = this.createSynonymsRegExp(str);
        }

        if (this.opt.ignoreJoiners || this.opt.ignorePunctuation.length) {
          str = this.setupIgnoreJoinersRegExp(str);
        }

        if (this.opt.diacritics) {
          str = this.createDiacriticsRegExp(str);
        }

        str = this.createMergedBlanksRegExp(str);

        if (this.opt.ignoreJoiners || this.opt.ignorePunctuation.length) {
          str = this.createJoinersRegExp(str);
        }

        if (this.opt.wildcards !== 'disabled') {
          str = this.createWildcardsRegExp(str);
        }

        str = this.createAccuracyRegExp(str);
        return new RegExp(str, "gm".concat(this.opt.caseSensitive ? '' : 'i'));
      }
    }, {
      key: "sortByLength",
      value: function sortByLength(arry) {
        return arry.sort(function (a, b) {
          return a.length === b.length ? a > b ? 1 : -1 : b.length - a.length;
        });
      }
    }, {
      key: "escapeStr",
      value: function escapeStr(str) {
        return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, '\\$&');
      }
    }, {
      key: "createSynonymsRegExp",
      value: function createSynonymsRegExp(str) {
        var _this = this;

        var syn = this.opt.synonyms,
            sens = this.opt.caseSensitive ? '' : 'i',
            joinerPlaceholder = this.opt.ignoreJoiners || this.opt.ignorePunctuation.length ? "\0" : '';

        for (var index in syn) {
          if (syn.hasOwnProperty(index)) {
            var keys = Array.isArray(syn[index]) ? syn[index] : [syn[index]];
            keys.unshift(index);
            keys = this.sortByLength(keys).map(function (key) {
              if (_this.opt.wildcards !== 'disabled') {
                key = _this.setupWildcardsRegExp(key);
              }

              key = _this.escapeStr(key);
              return key;
            }).filter(function (k) {
              return k !== '';
            });

            if (keys.length > 1) {
              str = str.replace(new RegExp("(".concat(keys.map(function (k) {
                return _this.escapeStr(k);
              }).join('|'), ")"), "gm".concat(sens)), joinerPlaceholder + "(".concat(keys.map(function (k) {
                return _this.processSynonyms(k);
              }).join('|'), ")") + joinerPlaceholder);
            }
          }
        }

        return str;
      }
    }, {
      key: "processSynonyms",
      value: function processSynonyms(str) {
        if (this.opt.ignoreJoiners || this.opt.ignorePunctuation.length) {
          str = this.setupIgnoreJoinersRegExp(str);
        }

        return str;
      }
    }, {
      key: "setupWildcardsRegExp",
      value: function setupWildcardsRegExp(str) {
        str = str.replace(/(?:\\)*\?/g, function (val) {
          return val.charAt(0) === '\\' ? '?' : "\x01";
        });
        return str.replace(/(?:\\)*\*/g, function (val) {
          return val.charAt(0) === '\\' ? '*' : "\x02";
        });
      }
    }, {
      key: "createWildcardsRegExp",
      value: function createWildcardsRegExp(str) {
        var spaces = this.opt.wildcards === 'withSpaces';
        return str.replace(/\u0001/g, spaces ? '[\\S\\s]?' : '\\S?').replace(/\u0002/g, spaces ? '[\\S\\s]*?' : '\\S*');
      }
    }, {
      key: "setupIgnoreJoinersRegExp",
      value: function setupIgnoreJoinersRegExp(str) {
        return str.replace(/[^(|)\\]/g, function (val, indx, original) {
          var nextChar = original.charAt(indx + 1);

          if (/[(|)\\]/.test(nextChar) || nextChar === '') {
            return val;
          } else {
            return val + "\0";
          }
        });
      }
    }, {
      key: "createJoinersRegExp",
      value: function createJoinersRegExp(str) {
        var joiner = [];
        var ignorePunctuation = this.opt.ignorePunctuation;

        if (Array.isArray(ignorePunctuation) && ignorePunctuation.length) {
          joiner.push(this.escapeStr(ignorePunctuation.join('')));
        }

        if (this.opt.ignoreJoiners) {
          joiner.push("\\u00ad\\u200b\\u200c\\u200d");
        }

        return joiner.length ? str.split(/\u0000+/).join("[".concat(joiner.join(''), "]*")) : str;
      }
    }, {
      key: "createDiacriticsRegExp",
      value: function createDiacriticsRegExp(str) {
        var sens = this.opt.caseSensitive ? '' : 'i',
            dct = this.opt.caseSensitive ? ['aàáảãạăằắẳẵặâầấẩẫậäåāą', 'AÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÄÅĀĄ', 'cçćč', 'CÇĆČ', 'dđď', 'DĐĎ', 'eèéẻẽẹêềếểễệëěēę', 'EÈÉẺẼẸÊỀẾỂỄỆËĚĒĘ', 'iìíỉĩịîïī', 'IÌÍỈĨỊÎÏĪ', 'lł', 'LŁ', 'nñňń', 'NÑŇŃ', 'oòóỏõọôồốổỗộơởỡớờợöøō', 'OÒÓỎÕỌÔỒỐỔỖỘƠỞỠỚỜỢÖØŌ', 'rř', 'RŘ', 'sšśșş', 'SŠŚȘŞ', 'tťțţ', 'TŤȚŢ', 'uùúủũụưừứửữựûüůū', 'UÙÚỦŨỤƯỪỨỬỮỰÛÜŮŪ', 'yýỳỷỹỵÿ', 'YÝỲỶỸỴŸ', 'zžżź', 'ZŽŻŹ'] : ['aàáảãạăằắẳẵặâầấẩẫậäåāąAÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÄÅĀĄ', 'cçćčCÇĆČ', 'dđďDĐĎ', 'eèéẻẽẹêềếểễệëěēęEÈÉẺẼẸÊỀẾỂỄỆËĚĒĘ', 'iìíỉĩịîïīIÌÍỈĨỊÎÏĪ', 'lłLŁ', 'nñňńNÑŇŃ', 'oòóỏõọôồốổỗộơởỡớờợöøōOÒÓỎÕỌÔỒỐỔỖỘƠỞỠỚỜỢÖØŌ', 'rřRŘ', 'sšśșşSŠŚȘŞ', 'tťțţTŤȚŢ', 'uùúủũụưừứửữựûüůūUÙÚỦŨỤƯỪỨỬỮỰÛÜŮŪ', 'yýỳỷỹỵÿYÝỲỶỸỴŸ', 'zžżźZŽŻŹ'];
        var handled = [];
        str.split('').forEach(function (ch) {
          dct.every(function (dct) {
            if (dct.indexOf(ch) !== -1) {
              if (handled.indexOf(dct) > -1) {
                return false;
              }

              str = str.replace(new RegExp("[".concat(dct, "]"), "gm".concat(sens)), "[".concat(dct, "]"));
              handled.push(dct);
            }

            return true;
          });
        });
        return str;
      }
    }, {
      key: "createMergedBlanksRegExp",
      value: function createMergedBlanksRegExp(str) {
        return str.replace(/[\s]+/gmi, '[\\s]+');
      }
    }, {
      key: "createAccuracyRegExp",
      value: function createAccuracyRegExp(str) {
        var _this2 = this;

        var chars = '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~¡¿';
        var acc = this.opt.accuracy,
            val = typeof acc === 'string' ? acc : acc.value,
            ls = typeof acc === 'string' ? [] : acc.limiters,
            lsJoin = '';
        ls.forEach(function (limiter) {
          lsJoin += "|".concat(_this2.escapeStr(limiter));
        });

        switch (val) {
          case 'partially':
          default:
            return "()(".concat(str, ")");

          case 'complementary':
            lsJoin = '\\s' + (lsJoin ? lsJoin : this.escapeStr(chars));
            return "()([^".concat(lsJoin, "]*").concat(str, "[^").concat(lsJoin, "]*)");

          case 'exactly':
            return "(^|\\s".concat(lsJoin, ")(").concat(str, ")(?=$|\\s").concat(lsJoin, ")");
        }
      }
    }]);

    return RegExpCreator;
  }();

  var Mark =
  /*#__PURE__*/
  function () {
    function Mark(ctx) {
      _classCallCheck(this, Mark);

      this.ctx = ctx;
      this.ie = false;
      var ua = window.navigator.userAgent;

      if (ua.indexOf('MSIE') > -1 || ua.indexOf('Trident') > -1) {
        this.ie = true;
      }
    }

    _createClass(Mark, [{
      key: "log",
      value: function log(msg) {
        var level = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : 'debug';
        var log = this.opt.log;

        if (!this.opt.debug) {
          return;
        }

        if (_typeof(log) === 'object' && typeof log[level] === 'function') {
          log[level]("mark.js: ".concat(msg));
        }
      }
    }, {
      key: "getSeparatedKeywords",
      value: function getSeparatedKeywords(sv) {
        var _this = this;

        var stack = [];
        sv.forEach(function (kw) {
          if (!_this.opt.separateWordSearch) {
            if (kw.trim() && stack.indexOf(kw) === -1) {
              stack.push(kw);
            }
          } else {
            kw.split(' ').forEach(function (kwSplitted) {
              if (kwSplitted.trim() && stack.indexOf(kwSplitted) === -1) {
                stack.push(kwSplitted);
              }
            });
          }
        });
        return {
          'keywords': stack.sort(function (a, b) {
            return b.length - a.length;
          }),
          'length': stack.length
        };
      }
    }, {
      key: "isNumeric",
      value: function isNumeric(value) {
        return Number(parseFloat(value)) == value;
      }
    }, {
      key: "checkRanges",
      value: function checkRanges(array) {
        var _this2 = this;

        if (!Array.isArray(array) || Object.prototype.toString.call(array[0]) !== '[object Object]') {
          this.log('markRanges() will only accept an array of objects');
          this.opt.noMatch(array);
          return [];
        }

        var stack = [];
        var last = 0;
        array.sort(function (a, b) {
          return a.start - b.start;
        }).forEach(function (item) {
          var _this2$callNoMatchOnI = _this2.callNoMatchOnInvalidRanges(item, last),
              start = _this2$callNoMatchOnI.start,
              end = _this2$callNoMatchOnI.end,
              valid = _this2$callNoMatchOnI.valid;

          if (valid) {
            item.start = start;
            item.length = end - start;
            stack.push(item);
            last = end;
          }
        });
        return stack;
      }
    }, {
      key: "callNoMatchOnInvalidRanges",
      value: function callNoMatchOnInvalidRanges(range, last) {
        var start,
            end,
            valid = false;

        if (range && typeof range.start !== 'undefined') {
          start = parseInt(range.start, 10);
          end = start + parseInt(range.length, 10);

          if (this.isNumeric(range.start) && this.isNumeric(range.length) && end - last > 0 && end - start > 0) {
            valid = true;
          } else {
            this.log('Ignoring invalid or overlapping range: ' + "".concat(JSON.stringify(range)));
            this.opt.noMatch(range);
          }
        } else {
          this.log("Ignoring invalid range: ".concat(JSON.stringify(range)));
          this.opt.noMatch(range);
        }

        return {
          start: start,
          end: end,
          valid: valid
        };
      }
    }, {
      key: "checkWhitespaceRanges",
      value: function checkWhitespaceRanges(range, originalLength, string) {
        var end,
            valid = true,
            max = string.length,
            offset = originalLength - max,
            start = parseInt(range.start, 10) - offset;
        start = start > max ? max : start;
        end = start + parseInt(range.length, 10);

        if (end > max) {
          end = max;
          this.log("End range automatically set to the max value of ".concat(max));
        }

        if (start < 0 || end - start < 0 || start > max || end > max) {
          valid = false;
          this.log("Invalid range: ".concat(JSON.stringify(range)));
          this.opt.noMatch(range);
        } else if (string.substring(start, end).replace(/\s+/g, '') === '') {
          valid = false;
          this.log('Skipping whitespace only range: ' + JSON.stringify(range));
          this.opt.noMatch(range);
        }

        return {
          start: start,
          end: end,
          valid: valid
        };
      }
    }, {
      key: "getTextNodes",
      value: function getTextNodes(cb) {
        var _this3 = this;

        var val = '',
            nodes = [];
        this.iterator.forEachNode(NodeFilter.SHOW_TEXT, function (node) {
          nodes.push({
            start: val.length,
            end: (val += node.textContent).length,
            node: node
          });
        }, function (node) {
          if (_this3.matchesExclude(node.parentNode)) {
            return NodeFilter.FILTER_REJECT;
          } else {
            return NodeFilter.FILTER_ACCEPT;
          }
        }, function () {
          cb({
            value: val,
            nodes: nodes
          });
        });
      }
    }, {
      key: "matchesExclude",
      value: function matchesExclude(el) {
        return DOMIterator.matches(el, this.opt.exclude.concat(['script', 'style', 'title', 'head', 'html']));
      }
    }, {
      key: "wrapRangeInTextNode",
      value: function wrapRangeInTextNode(node, start, end) {
        var hEl = !this.opt.element ? 'mark' : this.opt.element,
            startNode = node.splitText(start),
            ret = startNode.splitText(end - start);
        var repl = document.createElement(hEl);
        repl.setAttribute('data-markjs', 'true');

        if (this.opt.className) {
          repl.setAttribute('class', this.opt.className);
        }

        repl.textContent = startNode.textContent;
        startNode.parentNode.replaceChild(repl, startNode);
        return ret;
      }
    }, {
      key: "wrapRangeInMappedTextNode",
      value: function wrapRangeInMappedTextNode(dict, start, end, filterCb, eachCb) {
        var _this4 = this;

        dict.nodes.every(function (n, i) {
          var sibl = dict.nodes[i + 1];

          if (typeof sibl === 'undefined' || sibl.start > start) {
            if (!filterCb(n.node)) {
              return false;
            }

            var s = start - n.start,
                e = (end > n.end ? n.end : end) - n.start,
                startStr = dict.value.substr(0, n.start),
                endStr = dict.value.substr(e + n.start);
            n.node = _this4.wrapRangeInTextNode(n.node, s, e);
            dict.value = startStr + endStr;
            dict.nodes.forEach(function (k, j) {
              if (j >= i) {
                if (dict.nodes[j].start > 0 && j !== i) {
                  dict.nodes[j].start -= e;
                }

                dict.nodes[j].end -= e;
              }
            });
            end -= e;
            eachCb(n.node.previousSibling, n.start);

            if (end > n.end) {
              start = n.end;
            } else {
              return false;
            }
          }

          return true;
        });
      }
    }, {
      key: "wrapGroups",
      value: function wrapGroups(node, pos, len, eachCb) {
        node = this.wrapRangeInTextNode(node, pos, pos + len);
        eachCb(node.previousSibling);
        return node;
      }
    }, {
      key: "separateGroups",
      value: function separateGroups(node, match, matchIdx, filterCb, eachCb) {
        var matchLen = match.length;

        for (var i = 1; i < matchLen; i++) {
          var pos = node.textContent.indexOf(match[i]);

          if (match[i] && pos > -1 && filterCb(match[i], node)) {
            node = this.wrapGroups(node, pos, match[i].length, eachCb);
          }
        }

        return node;
      }
    }, {
      key: "wrapMatches",
      value: function wrapMatches(regex, ignoreGroups, filterCb, eachCb, endCb) {
        var _this5 = this;

        var matchIdx = ignoreGroups === 0 ? 0 : ignoreGroups + 1;
        this.getTextNodes(function (dict) {
          dict.nodes.forEach(function (node) {
            node = node.node;
            var match;

            while ((match = regex.exec(node.textContent)) !== null && match[matchIdx] !== '') {
              if (_this5.opt.separateGroups) {
                node = _this5.separateGroups(node, match, matchIdx, filterCb, eachCb);
              } else {
                if (!filterCb(match[matchIdx], node)) {
                  continue;
                }

                var pos = match.index;

                if (matchIdx !== 0) {
                  for (var i = 1; i < matchIdx; i++) {
                    pos += match[i].length;
                  }
                }

                node = _this5.wrapGroups(node, pos, match[matchIdx].length, eachCb);
              }

              regex.lastIndex = 0;
            }
          });
          endCb();
        });
      }
    }, {
      key: "wrapMatchesAcrossElements",
      value: function wrapMatchesAcrossElements(regex, ignoreGroups, filterCb, eachCb, endCb) {
        var _this6 = this;

        var matchIdx = ignoreGroups === 0 ? 0 : ignoreGroups + 1;
        this.getTextNodes(function (dict) {
          var match;

          while ((match = regex.exec(dict.value)) !== null && match[matchIdx] !== '') {
            var start = match.index;

            if (matchIdx !== 0) {
              for (var i = 1; i < matchIdx; i++) {
                start += match[i].length;
              }
            }

            var end = start + match[matchIdx].length;

            _this6.wrapRangeInMappedTextNode(dict, start, end, function (node) {
              return filterCb(match[matchIdx], node);
            }, function (node, lastIndex) {
              regex.lastIndex = lastIndex;
              eachCb(node);
            });
          }

          endCb();
        });
      }
    }, {
      key: "wrapRangeFromIndex",
      value: function wrapRangeFromIndex(ranges, filterCb, eachCb, endCb) {
        var _this7 = this;

        this.getTextNodes(function (dict) {
          var originalLength = dict.value.length;
          ranges.forEach(function (range, counter) {
            var _this7$checkWhitespac = _this7.checkWhitespaceRanges(range, originalLength, dict.value),
                start = _this7$checkWhitespac.start,
                end = _this7$checkWhitespac.end,
                valid = _this7$checkWhitespac.valid;

            if (valid) {
              _this7.wrapRangeInMappedTextNode(dict, start, end, function (node) {
                return filterCb(node, range, dict.value.substring(start, end), counter);
              }, function (node) {
                eachCb(node, range);
              });
            }
          });
          endCb();
        });
      }
    }, {
      key: "unwrapMatches",
      value: function unwrapMatches(node) {
        var parent = node.parentNode;
        var docFrag = document.createDocumentFragment();

        while (node.firstChild) {
          docFrag.appendChild(node.removeChild(node.firstChild));
        }

        parent.replaceChild(docFrag, node);

        if (!this.ie) {
          parent.normalize();
        } else {
          this.normalizeTextNode(parent);
        }
      }
    }, {
      key: "normalizeTextNode",
      value: function normalizeTextNode(node) {
        if (!node) {
          return;
        }

        if (node.nodeType === 3) {
          while (node.nextSibling && node.nextSibling.nodeType === 3) {
            node.nodeValue += node.nextSibling.nodeValue;
            node.parentNode.removeChild(node.nextSibling);
          }
        } else {
          this.normalizeTextNode(node.firstChild);
        }

        this.normalizeTextNode(node.nextSibling);
      }
    }, {
      key: "markRegExp",
      value: function markRegExp(regexp, opt) {
        var _this8 = this;

        this.opt = opt;
        this.log("Searching with expression \"".concat(regexp, "\""));
        var totalMatches = 0,
            fn = 'wrapMatches';

        var eachCb = function eachCb(element) {
          totalMatches++;

          _this8.opt.each(element);
        };

        if (this.opt.acrossElements) {
          fn = 'wrapMatchesAcrossElements';
        }

        this[fn](regexp, this.opt.ignoreGroups, function (match, node) {
          return _this8.opt.filter(node, match, totalMatches);
        }, eachCb, function () {
          if (totalMatches === 0) {
            _this8.opt.noMatch(regexp);
          }

          _this8.opt.done(totalMatches);
        });
      }
    }, {
      key: "mark",
      value: function mark(sv, opt) {
        var _this9 = this;

        this.opt = opt;
        var totalMatches = 0,
            fn = 'wrapMatches';

        var _this$getSeparatedKey = this.getSeparatedKeywords(typeof sv === 'string' ? [sv] : sv),
            kwArr = _this$getSeparatedKey.keywords,
            kwArrLen = _this$getSeparatedKey.length,
            handler = function handler(kw) {
          var regex = new RegExpCreator(_this9.opt).create(kw);
          var matches = 0;

          _this9.log("Searching with expression \"".concat(regex, "\""));

          _this9[fn](regex, 1, function (term, node) {
            return _this9.opt.filter(node, kw, totalMatches, matches);
          }, function (element) {
            matches++;
            totalMatches++;

            _this9.opt.each(element);
          }, function () {
            if (matches === 0) {
              _this9.opt.noMatch(kw);
            }

            if (kwArr[kwArrLen - 1] === kw) {
              _this9.opt.done(totalMatches);
            } else {
              handler(kwArr[kwArr.indexOf(kw) + 1]);
            }
          });
        };

        if (this.opt.acrossElements) {
          fn = 'wrapMatchesAcrossElements';
        }

        if (kwArrLen === 0) {
          this.opt.done(totalMatches);
        } else {
          handler(kwArr[0]);
        }
      }
    }, {
      key: "markRanges",
      value: function markRanges(rawRanges, opt) {
        var _this10 = this;

        this.opt = opt;
        var totalMatches = 0,
            ranges = this.checkRanges(rawRanges);

        if (ranges && ranges.length) {
          this.log('Starting to mark with the following ranges: ' + JSON.stringify(ranges));
          this.wrapRangeFromIndex(ranges, function (node, range, match, counter) {
            return _this10.opt.filter(node, range, match, counter);
          }, function (element, range) {
            totalMatches++;

            _this10.opt.each(element, range);
          }, function () {
            _this10.opt.done(totalMatches);
          });
        } else {
          this.opt.done(totalMatches);
        }
      }
    }, {
      key: "unmark",
      value: function unmark(opt) {
        var _this11 = this;

        this.opt = opt;
        var sel = this.opt.element ? this.opt.element : '*';
        sel += '[data-markjs]';

        if (this.opt.className) {
          sel += ".".concat(this.opt.className);
        }

        this.log("Removal selector \"".concat(sel, "\""));
        this.iterator.forEachNode(NodeFilter.SHOW_ELEMENT, function (node) {
          _this11.unwrapMatches(node);
        }, function (node) {
          var matchesSel = DOMIterator.matches(node, sel),
              matchesExclude = _this11.matchesExclude(node);

          if (!matchesSel || matchesExclude) {
            return NodeFilter.FILTER_REJECT;
          } else {
            return NodeFilter.FILTER_ACCEPT;
          }
        }, this.opt.done);
      }
    }, {
      key: "opt",
      set: function set(val) {
        this._opt = _extends({}, {
          'element': '',
          'className': '',
          'exclude': [],
          'iframes': false,
          'iframesTimeout': 5000,
          'separateWordSearch': true,
          'acrossElements': false,
          'ignoreGroups': 0,
          'each': function each() {},
          'noMatch': function noMatch() {},
          'filter': function filter() {
            return true;
          },
          'done': function done() {},
          'debug': false,
          'log': window.console
        }, val);
      },
      get: function get() {
        return this._opt;
      }
    }, {
      key: "iterator",
      get: function get() {
        return new DOMIterator(this.ctx, this.opt.iframes, this.opt.exclude, this.opt.iframesTimeout);
      }
    }]);

    return Mark;
  }();

  $.fn.mark = function (sv, opt) {
    new Mark(this.get()).mark(sv, opt);
    return this;
  };

  $.fn.markRegExp = function (regexp, opt) {
    new Mark(this.get()).markRegExp(regexp, opt);
    return this;
  };

  $.fn.markRanges = function (ranges, opt) {
    new Mark(this.get()).markRanges(ranges, opt);
    return this;
  };

  $.fn.unmark = function (opt) {
    new Mark(this.get()).unmark(opt);
    return this;
  };

  return $;

})));