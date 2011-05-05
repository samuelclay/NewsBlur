if (typeof NEWSBLUR == 'undefined') NEWSBLUR = {};
if (typeof NEWSBLUR.Globals == 'undefined') NEWSBLUR.Globals = {};

/* ============================= */
/* = Core NewsBlur Javascript = */
/* ============================= */

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
        
        isScrollVisible: function($elem) {
            var docViewTop = 0; // $(this).scrollTop();
            var docViewBottom = docViewTop + $(this).height();
            var docOffset = $(this).offset().top;

            var elemTop = $elem.offset().top - docOffset;
            var elemBottom = elemTop + $elem.outerHeight();

            // NEWSBLUR.log(['isScrollVisible', docViewTop, docViewBottom, docOffset, elemTop, elemBottom]);
            
            return ((elemTop >= docViewTop) && (elemBottom <= docViewBottom));
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
              width   : $(window).width(),
              height  : $(window).height()
            };
          } else {
            target = $(target);
            var targOff = target.offset();
            var b = {
              left    : targOff.left,
              top     : targOff.top,
              width   : target.innerWidth(),
              height  : target.innerHeight()
            };
          }

          var elb = {
            width : el.innerWidth(),
            height : el.innerHeight()
          };

          var left, top;

          if (pos.indexOf('-left') >= 0) {
            left = b.left;
          } else if (pos.indexOf('left') >= 0) {
            left = b.left - elb.width;
          } else if (pos.indexOf('-right') >= 0) {
            left = b.left + b.width - elb.width;
          } else if (pos.indexOf('right') >= 0) {
            left = b.left + b.width;
          } else { // Centered.
            left = b.left + (b.width - elb.width) / 2;
          }

          if (pos.indexOf('-top') >= 0) {
            top = b.top;
          } else if (pos.indexOf('top') >= 0) {
            top = b.top - elb.height;
          } else if (pos.indexOf('-bottom') >= 0) {
            top = b.top + b.height - elb.height;
          } else if (pos.indexOf('bottom') >= 0) {
            top = b.top + b.height;
          } else { // Centered.
            top = b.top + (b.height - elb.height) / 2;
          }

          var constrain = (pos.indexOf('no-constraint') >= 0) ? false : true;

          left += offset.left || 0;
          top += offset.top || 0;

          if (constrain) {
            left = Math.max(scrollLeft, Math.min(left, scrollLeft + clientWidth - elb.width));
            top = Math.max(scrollTop, Math.min(top, scrollTop + clientHeight - elb.height));
          }

          // var offParent;
          // if (offParent = el.offsetParent()) {
          //   left -= offParent.offset().left;
          //   top -= offParent.offset().top;
          // }

          $(el).css({position : 'absolute', left : left + 'px', top : top + 'px'});
          return el;
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
        
        favicon: function(feed_favicon, empty_on_missing) {
          
            if (feed_favicon && feed_favicon.indexOf('data:image/png;base64,') != -1) return feed_favicon;
            else if (feed_favicon) return 'data:image/png;base64,' + feed_favicon;
            else if (empty_on_missing) return 'data:image/png;base64,R0lGODlhAQABAIAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==';
            return NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/world.png';
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
                }
            }
            
            // Third argument can be TextNode or an array of additional $.make
            if (args[2]) {
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
            if (text) {
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
            function parseParams() {
                var params = {},
                    e,
                    a = /\+/g,  // Regex for replacing addition symbol with a space
                    r = /([^&=]+)=?([^&]*)/g,
                    d = function (s) { return decodeURIComponent(s.replace(a, " ")); },
                    q = window.location.search.substring(1);

                while (e = r.exec(q))
                    params[d(e[1])] = d(e[2]);

                return params;
            }

            if (!this.queryStringParams)
                this.queryStringParams = parseParams(); 

            return this.queryStringParams[name];
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