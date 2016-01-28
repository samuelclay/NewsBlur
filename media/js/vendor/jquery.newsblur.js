if (typeof NEWSBLUR.Globals == 'undefined') NEWSBLUR.Globals = {};

/* ============================= */
/* = Core NewsBlur Javascript = */
/* ============================= */

var URL_REGEX = /((https?\:\/\/)|(www\.))(\S+)(\w{2,4})(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/gi;

if (!window.console || !window.console.log) {
    window.console = {};
    window.console.log = function() {};
}

NEWSBLUR.log = function(msg) {
    try {
        if (typeof o == "object")
        {
            var new_m = [];
            for (var i=0; i < msg.length; i++) {
                if (i!=0) new_m.push(msg[i]);
            }
            console.debug(msg[0], new_m);
        }
        else
        {
            console.log(msg);  
        }      
    } catch(e) {
        console = 
        { 
            log: function() {} 
        };
    }
};

(function($) {

    $.fn.extend({
        
        textNodes: function() {
            var ret = [];

            (function(el){
                if (!el) return;
                if ((el.nodeType == 3)) {
                    ret.push(el);
                } else {
                    for (var i=0; i < el.childNodes.length; ++i) {
                        arguments.callee(el.childNodes[i]);
                    }
                }
            })(this[0]);
            return $(ret);
        },
    
        isScrollVisible: function($elem, partial) {
            var docViewTop = 0; // $(this).scrollTop();
            var docViewBottom = docViewTop + $(this).height();
            var docOffset = $(this).offset().top;

            var elemTop = $elem.offset().top - docOffset;
            var elemBottom = elemTop + $elem.outerHeight();

            // NEWSBLUR.log(['isScrollVisible', docViewTop, docViewBottom, elemTop, elemBottom]);
            
            if (partial) {
                var topVisible = ((elemTop >= docViewTop) && (elemTop <= docViewBottom));
                var bottomVisible = ((elemBottom <= docViewBottom) && (elemBottom >= docViewTop));
                var centerVisible = (elemTop <= docViewTop) && (elemBottom >= docViewBottom);
                return topVisible || bottomVisible || centerVisible;
            } else {
                return ((elemTop >= docViewTop) && (elemBottom <= docViewBottom));
            }
        },
        
        // Align an element relative to a target element's coordinates. Forces the
        // element to be absolutely positioned. Element must be visible.
        // Position string format is: "top -right".
        // You can pass an optional offset object with top and left offsets specified.
        align : function(target, pos, offset) {
          var el = this;
          pos = pos || '';
          offset = offset || {};
          var scrollTop = document.documentElement.scrollTop || document.body.scrollTop || 0;
          var scrollLeft = document.documentElement.scrollLeft || document.body.scrollLeft || 0;
          var clientWidth = document.documentElement.clientWidth;
          var clientHeight = document.documentElement.clientHeight;

          if (target == window) {
            var b = {
              left    : scrollLeft,
              top     : scrollTop,
              right   : $(window).width() - scrollLeft,
              bottom  : $(window).height() - scrollTop,
              width   : $(window).width(),
              height  : $(window).height()
            };
          } else {
            target = $(target);
            var targOff = target.offset();
            var b = {
              left    : targOff.left,
              top     : targOff.top,
              right   : clientWidth - targOff.left,
              bottom  : clientHeight - targOff.top,
              width   : target.innerWidth(),
              height  : target.innerHeight()
            };
          }

          var elb = {
            width : el.innerWidth(),
            height : el.innerHeight()
          };

          var left, top, bottom, right;

          if (pos.indexOf('-left') >= 0) {
            left = b.left;
          } else if (pos.indexOf('left') >= 0) {
            left = b.left - elb.width;
          } else if (pos.indexOf('-right') >= 0) {
            right = b.right - elb.width;
          } else if (pos.indexOf('right') >= 0) {
            right = b.right;
          } else { // Centered.
            left = b.left + (b.width - elb.width) / 2;
          }

          if (pos.indexOf('-top') >= 0) {
            bottom = b.bottom - elb.height;
          } else if (pos.indexOf('top') >= 0) {
            bottom = b.bottom;
          } else if (pos.indexOf('-bottom') >= 0) {
            top = b.top;
          } else if (pos.indexOf('bottom') >= 0) {
            top = b.top + elb.height;
          } else { // Centered.
            top = b.top + (b.height - elb.height) / 2;
          }

          var constrain = (pos.indexOf('no-constraint') >= 0) ? false : true;

          left += offset.left || 0;
          top += offset.top || 0;
          bottom += offset.top || 0;
          right += offset.left || 0;

          if (constrain) {
            left = Math.max(scrollLeft, Math.min(left, scrollLeft + clientWidth - elb.width));
            top = Math.max(scrollTop, Math.min(top, scrollTop + clientHeight - elb.height));
            bottom = Math.max(scrollTop, Math.min(bottom, scrollTop + clientHeight - elb.height));
            right = Math.max(scrollTop, Math.min(right, scrollLeft + clientWidth - elb.height));
          }

          // var offParent;
          // if (offParent = el.offsetParent()) {
          //   left -= offParent.offset().left;
          //   top -= offParent.offset().top;
          // }
          $(el).css({position : 'absolute'});
          if (pos.indexOf('bottom') >= 0) {
              $(el).css({top : top + 'px', bottom: 'auto'});
          } else {
              $(el).css({bottom : bottom + 'px', top: 'auto'});
          }
          if (pos.indexOf('right') >= 0) {
              $(el).css({right : right + 'px', left: 'auto'});
          } else {
              $(el).css({left : left + 'px', right: 'auto'});
          }
          return el;
        },
        
        // When the next click or keypress happens, anywhere on the screen, hide the
        // element. 'clickable' makes the element and its contents clickable without
        // hiding. The 'onHide' callback runs when the hide fires, and has a chance
        // to cancel it.
        autohide : function(options) {
          var me = this;
          options = _.extend({clickable : null, onHide : null}, options || {});
          me._autoignore = true;
          setTimeout(function(){ delete me._autoignore; }, 0);

          if (!me._autohider) {
            me.forceHide = function(e) {
              if (!e && options.onHide) options.onHide();
              me.hide();
              me.removeHide();
            };
            me.removeHide = function() {
              $(document).unbind('click.autohide', me._autohider);
              $(document).unbind('keypress.autohide', me._autohider);
              $(document).unbind('keyup.autohide', me._checkesc);
              me._autohider = null;
              me._checkesc = null;
              me.forceHide = null;
            };
            me._autohider = function(e) {
              if (me._autoignore) return;
              if (options.clickable && (me[0] == e.target || _.include($(e.target).parents(), me[0]))) return;
              if (options.onHide && !options.onHide(e, _.bind(me.forceHide, me))) return;
              me.forceHide(e);
            };
            me._checkesc = function(e) {
                if (e.keyCode == 27) {
                    options.clickable = false;
                    me._autohider(e);
                }
            };
            $(document).bind('click.autohide', this._autohider);
            $(document).bind('keypress.autohide', this._autohider);
            $(document).bind('keyup.autohide', this._checkesc);
          }
          
          return this;
        }
        
    });
    
    $.extend({
      
        // Color format: {r: 1, g: .5, b: 0}
        textColor: function(background_color) {
            var contrast = function (color1, color2) {
                var lum1 = luminosity(color1);
                var lum2 = luminosity(color2);
                if(lum1 > lum2)
                return (lum1 + 0.05) / (lum2 + 0.05);
                return (lum2 + 0.05) / (lum1 + 0.05);
            };
            
            var luminosity = function (color) {
                var r = color.r, g = color.g, b = color.b;
                var red = (r <= 0.03928) ? r/12.92 : Math.pow(((r + 0.055)/1.055), 2.4);
                var green = (g <= 0.03928) ? g/12.92 : Math.pow(((g + 0.055)/1.055), 2.4);
                var blue = (b <= 0.03928) ? b/12.92 : Math.pow(((b + 0.055)/1.055), 2.4);
                
                return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
            };
            
            if (contrast(background_color, {r: 1, g: 1, b: 1}) > 
                contrast(background_color, {r: .5, g: .5, b: .5})) {
                return 'white';
            } else {
                return 'black';
            }
        },
        
        favicon: function(feed, empty_on_missing) {
            if (_.isNumber(feed)) return NEWSBLUR.URLs.favicon.replace('{id}', feed);
            else if (feed.get('favicon') && feed.get('favicon').length && feed.get('favicon').indexOf('data:image/png;base64,') != -1) return feed.get('favicon');
            else if (feed.get('favicon') && feed.get('favicon').length) return 'data:image/png;base64,' + feed.get('favicon');
            else if (feed.get('favicon_url') && !empty_on_missing) return feed.get('favicon_url');
            else if (feed.get('photo_url')) return feed.get('photo_url');
            else if (_.string.include(feed.id, 'social:')) return NEWSBLUR.Globals.MEDIA_URL + 'img/reader/default_profile_photo.png';
            else if (empty_on_missing) return 'data:image/png;base64,R0lGODlhAQABAIAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==';
            else if (_.isNumber(feed.id)) return NEWSBLUR.URLs.favicon.replace('{id}', feed.id);
            else if (feed.get('favicon_url')) return feed.get('favicon_url');
            else if (feed.is_starred()) return NEWSBLUR.Globals.MEDIA_URL + '/img/reader/tag.png';
            return NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/world.png';
        },
        
        deepCopy: function(obj) {
            var type = $.typeOf(obj);
            switch (type) {
                case 'object':
                    var o = {};
                    for (key in obj) {
                        o[key] = $.deepCopy(obj[key]);
                    };
                    return o;
                case 'array':
                    var a = [];
                    for (var i = 0; i < obj.length; i++) {
                        a.push($.deepCopy(obj[i]));
                    }
                    return a;
                default:
                    return obj;
            };
        },

        typeOf: function(value) {
            var s = typeof value;
            if (s == 'object') {
                if (value) {
                    if (typeof value.length == 'number' &&
                        !(value.propertyIsEnumerable('length')) &&
                        typeof value.splice == 'function') {
                            s = 'array';
                    }
                } else {
                    s = 'null';
                }
            }
            return s;
        },

        targetIs: function(e, opts, callback){
            if(!e || !opts){ return false; }
            // defaults
            // (want to make this explicit, since it's a little weird)
            opts = {
                childOf: opts.childOf || null,
                tagSelector: opts.tagSelector || null,
                cancelBubbling: opts.cancelBubbling || false
            };
            var target = e.target;
            var $t = $(target);
            var $p = null;
            var fails = false;
            if(opts.childOf){
                $p = $t.closest(opts.childOf);
                if(!$p.length){
                    fails = true;
                }
            }
            if(opts.tagSelector){
                var ts = opts.tagSelector;
                if(!$t.is(ts)){
                    if(opts.cancelBubbling){
                        fails = true;
                    }else{
                        $tp = $t.closest(ts);
                        if(!$tp.length){
                            fails = true;
                        }else{
                            // we are going to assume dev
                            // wants the $elem we bubbled to
                            $t = $tp;
                        }
                    }
                };
            }
            if(fails){
                return false;
            }else{
                if(callback && typeof callback == 'function'){
                    // NEWSBLUR.log(['Target', e, opts.tagSelector, opts]);
                    callback($t, $p);
                }
                return true;
            }
        },
        
        entity: function(str) {
            var e = document.createElement('div');
            
            e.innerHTML = String(str);
            
            return e.innerHTML;
        },

        make: function(){
            var $elem, text, children, type, name, props;
            var args = arguments;
            var tagname = args[0];
            
            // Second argument can be TextNode or Attributes
            // $.make('div', 'inner text') || $.make('div', { className: 'etc' })
            if (args[1]) {
                if (typeof args[1] == 'string' || typeof args[1] == 'number') {
                    text = args[1];
                } else if (typeof args[1] == 'object' && args[1].push) {
                    children = args[1];
                } else {
                    props = args[1];
                    if (props.className) {
                      props['class'] = props.className;
                      delete props.className;
                    }
                }
            }
            
            // Third argument can be TextNode or an array of additional $.make
            if (args[2] != null) {
                if (typeof args[2] == 'string' || typeof args[2] == 'number') {
                    text = args[2];
                } else if (typeof args[1] == 'object' && args[2].push) {
                    children = args[2];
                }
            }
            
            $elem = $(document.createElement(tagname));
            if (props) {
                for (var propname in props) {
                    if (props.hasOwnProperty(propname)) {
                        if ($elem.is(':input') && propname == 'value') {
                            $elem.val(props[propname]);
                        } else {
                            $elem.attr(propname, props[propname]);
                        }
                    }
                }
            }
            if (children) {
                for (var i = 0; i < children.length; i++) {
                    if (children[i]) {
                        $elem.append(children[i]);
                    }
                }
            }
            if (text != null) {
                $elem.html(text);
            }
            return $elem;
        },
        
        rescope: function(func, thisArg){
            return function(a, b, c, d, e, f){
                func.call(thisArg, this, a, b, c, d, e, f);
            };
        },
                
        closest: function(value, array) {
            var offset = 0;
            var index = 0;
            var closest = Math.abs(array[index] - value);
            for (var i in array) {
                var next_value = array[i] - value;
                if (next_value <= offset && Math.abs(next_value) < closest) {
                    index = parseInt(i, 10);
                    closest = Math.abs(array[index] - value);
                } else if (next_value > offset) {
                    // NEWSBLUR.log(['Not Closest', index, next_value, value, closest]);
                    return index;
                }
            }
            return index;
        },
        
        getQueryString: function (name) {           
            var params = {},
                e,
                a = /\+/g,  // Regex for replacing addition symbol with a space
                r = /([^&=]+)=?([^&]*)/g,
                d = function (s) { return decodeURIComponent(s.replace(a, " ")); },
                q = window.location.search.substring(1);

            while (e = r.exec(q))
                params[d(e[1])] = d(e[2]);
            console.log(['get query string', name, params, params[name]]);
            return params[name];
        },
        
        updateQueryString: function(key, value, url) {
            if (!url) url = window.location.href;
            var re = new RegExp("([?&])" + key + "=.*?(&|#|$)(.*)", "gi"),
                hash;

            if (re.test(url)) {
                if (typeof value !== 'undefined' && value !== null)
                    return url.replace(re, '$1' + key + "=" + value + '$2$3');
                else {
                    hash = url.split('#');
                    url = hash[0].replace(re, '$1$3').replace(/(&|\?)$/, '');
                    if (typeof hash[1] !== 'undefined' && hash[1] !== null) 
                        url += '#' + hash[1];
                    return url;
                }
            }
            else {
                if (typeof value !== 'undefined' && value !== null) {
                    var separator = url.indexOf('?') !== -1 ? '&' : '?';
                    hash = url.split('#');
                    url = hash[0] + separator + key + '=' + value;
                    if (typeof hash[1] !== 'undefined' && hash[1] !== null) 
                        url += '#' + hash[1];
                    return url;
                }
                else
                    return url;
            }
        }

    });
})(jQuery);

// ------- IE Debug -------- //

(function($) {
    var _$ied;
    $.extend({
        iedebug: function(msg){
            if(!_$ied){
                _$ied = $.make('div', [
                    $.make('ol')
                ]).css({
                    'position': 'absolute',
                    'top': 10,
                    'left': 10,
                    'zIndex': 20000,
                    'border': '1px solid #000',
                    'padding': '10px',
                    'backgroundColor': '#fff',
                    'fontFamily': 'arial,helvetica,sans-serif',
                    'fontSize': '11px'
                });
                $('body').append(_$ied);
                _$ied.draggable();
            }
            _$ied.find('ol').append($.make('li', msg).css({
                'borderBottom': '1px solid #999999'
            }));
        }
    });
})(jQuery);