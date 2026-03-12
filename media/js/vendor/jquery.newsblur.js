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
              // console.log(['autohide', $(e.target), $(e.target).closest(me[0]), $(e.target).parents(), me[0], _.include($(e.target).parents(), me[0])]);
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
        
        favicon: function (feed, empty_on_missing) {
            var empty_icon = NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/world.svg';
            if (!feed) return empty_icon;
            // console.log(['Favicon', feed]);

            // Feed is a string
            if (_.isNumber(feed)) {
                return NEWSBLUR.URLs.favicon.replace('{id}', feed);
            } else if (_.isString(feed)) {
                var feed_id = feed;
                if (_.string.startsWith(feed_id, 'search:')) {
                    feed_id = feed_id.substring('search:'.length);
                }

                if (feed_id == 'river:')
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/all-stories.svg';
                if (feed_id == 'river:infrequent')
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/noun_turtle.png';
                if (feed_id == 'river:blurblogs')
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/all-shares.svg';
                if (feed_id == 'river:global')
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/global-shares.svg';
                if (feed_id == 'river:trending')
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/discover.svg';
                if (_.string.startsWith(feed_id, 'river:')) {
                    var folder_title = feed_id.substring('river:'.length);
                    var folder_icon = NEWSBLUR.assets && NEWSBLUR.assets.get_folder_icon(folder_title);
                    if (folder_icon && folder_icon.icon_type && folder_icon.icon_type !== 'none') {
                        return $.make_folder_icon(folder_icon);
                    }
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/folder-open.svg';
                }
                if (feed_id == "read")
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/indicator-unread.svg';
                if (feed_id == "starred")
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/saved-stories.svg';
                if (feed_id == "searches")
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/search.svg';
                if (feed_id == "archive")
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/archive.svg';
                if (_.string.startsWith(feed_id, 'briefing:')) {
                    var BRIEFING_SECTION_ICONS = {
                        'trending_unread': 'indicator-unread-gray.svg',
                        'long_read': 'scroll.svg',
                        'classifier_match': 'train.svg',
                        'follow_up': 'boomerang.svg',
                        'trending_global': 'discover.svg',
                        'duplicates': 'venn.svg',
                        'quick_catchup': 'pulse.svg',
                        'emerging_topics': 'growth-rocket-gray.svg',
                        'contrarian_views': 'stack.svg',
                        'custom_1': 'prompt.svg',
                        'custom_2': 'prompt.svg',
                        'custom_3': 'prompt.svg',
                        'custom_4': 'prompt.svg',
                        'custom_5': 'prompt.svg'
                    };
                    var section_key = feed_id.replace('briefing:', '');
                    var icon = BRIEFING_SECTION_ICONS[section_key] || 'briefing.svg';
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/' + icon;
                }
                if (_.string.startsWith(feed_id, 'starred:'))
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/tag.svg';
                if (_.string.startsWith(feed_id, 'feed:'))
                    return $.favicon(parseInt(feed_id.replace('feed:', ''), 10));
                if (_.string.startsWith(feed_id, 'social:'))
                    return $.favicon(NEWSBLUR.assets.get_feed(feed_id));
            }
            
            // Feed is a model - check for briefing section or custom feed icon first
            var feed_id = feed.id;
            if (_.isString(feed_id) && _.string.startsWith(feed_id, 'briefing:')) {
                return $.favicon(feed_id);
            }
            if (_.isNumber(feed_id)) {
                var custom_feed_icon = NEWSBLUR.assets && NEWSBLUR.assets.get_feed_icon(feed_id);
                if (custom_feed_icon && custom_feed_icon.icon_type && custom_feed_icon.icon_type !== 'none') {
                    return $.make_feed_icon(custom_feed_icon);
                }
            }

            if (feed.get('favicon') && feed.get('favicon').length && feed.get('favicon').indexOf('data:image/png;base64,') != -1)
                return feed.get('favicon');
            if (feed.get('favicon') && feed.get('favicon').length)
                return 'data:image/png;base64,' + feed.get('favicon');
            if (feed.get('favicon_url') && !empty_on_missing)
                return feed.get('favicon_url');
            if (feed.get('photo_url'))
                return feed.get('photo_url');
            if (_.string.include(feed.id, 'social:'))
                return NEWSBLUR.Globals.MEDIA_URL + 'img/reader/default_profile_photo.png';
            if (empty_on_missing)
                return 'data:image/png;base64,R0lGODlhAQABAIAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==';
            if (_.isNumber(feed.id))
                return NEWSBLUR.URLs.favicon.replace('{id}', feed.id);
            if (feed.get('favicon_url'))
                return feed.get('favicon_url');
            if (feed.is_starred())
                return NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/tag.svg';
            if (feed.get('is_newsletter'))
                return NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/email.svg';

            return empty_icon;
        },

        make_folder_icon: function (folder_icon) {
            if (folder_icon.icon_type === 'upload') {
                return 'data:image/png;base64,' + folder_icon.icon_data;
            } else if (folder_icon.icon_type === 'preset') {
                var icon_set = folder_icon.icon_set || 'lucide';
                return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/' + icon_set + '/' + folder_icon.icon_data + '.svg';
            } else if (folder_icon.icon_type === 'emoji') {
                // Return a special marker that folder_view.js will handle
                return 'emoji:' + folder_icon.icon_data;
            }
            return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/folder-open.svg';
        },

        make_feed_icon: function (feed_icon) {
            if (feed_icon.icon_type === 'upload') {
                return 'data:image/png;base64,' + feed_icon.icon_data;
            } else if (feed_icon.icon_type === 'preset') {
                var icon_set = feed_icon.icon_set || 'lucide';
                return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/' + icon_set + '/' + feed_icon.icon_data + '.svg';
            } else if (feed_icon.icon_type === 'emoji') {
                // Return a special marker that feed_title_view.js will handle
                return 'emoji:' + feed_icon.icon_data;
            }
            if (feed_icon.feed_id) {
                return NEWSBLUR.URLs.favicon.replace('{id}', feed_icon.feed_id);
            }
            return null;
        },

        icon_url_is_preset: function (icon_url) {
            return _.isString(icon_url) && (
                icon_url.indexOf('/lucide/') !== -1 ||
                icon_url.indexOf('/heroicons-solid/') !== -1
            );
        },

        icon_url_is_custom: function (icon_url) {
            return _.isString(icon_url) && (
                _.string.startsWith(icon_url, 'emoji:') ||
                _.string.startsWith(icon_url, 'data:') ||
                $.icon_url_is_preset(icon_url)
            );
        },

        is_hex_color: function (color) {
            return _.isString(color) && !!color.match(/^#[0-9a-fA-F]{6}$/);
        },

        make_icon_element: function (options) {
            options = options || {};
            var icon_url = options.icon_url;
            if (!icon_url) return null;

            var icon_color = $.is_hex_color(options.icon_color) ? options.icon_color : null;
            var is_preset = _.isBoolean(options.is_preset) ? options.is_preset : $.icon_url_is_preset(icon_url);
            var role = options.role;

            if (_.string.startsWith(icon_url, 'emoji:')) {
                var emoji_class = options.emoji_class || '';
                var emoji_attrs = { className: emoji_class };
                if (role) emoji_attrs.role = role;
                return $.make('span', emoji_attrs, icon_url.substring(6));
            }

            if (is_preset && icon_color && icon_color !== '#000000') {
                var colored_class = options.colored_class || '';
                var $colored = $.make('span', { className: colored_class });
                if (role) $colored.attr('role', role);
                $colored.css({
                    'background-color': icon_color,
                    '-webkit-mask-image': 'url(' + icon_url + ')',
                    'mask-image': 'url(' + icon_url + ')'
                });
                return $colored;
            }

            var image_class = options.image_class || '';
            var image_attrs = { src: icon_url };
            if (image_class) image_attrs.className = image_class;
            if (role) image_attrs.role = role;
            return $.make('img', image_attrs);
        },

        favicon_el: function (feed, options) {
            options = options || {};
            var icon_url = $.favicon(feed);
            if (!icon_url) return null;

            var is_folder = _.isString(feed) && _.string.startsWith(feed, 'river:');
            var icon_color = null;
            var feed_id = null;
            var feed_key = null;

            if (is_folder) {
                var folder_title = feed.substring('river:'.length);
                var folder_icon = NEWSBLUR.assets && NEWSBLUR.assets.get_folder_icon(folder_title);
                icon_color = folder_icon && folder_icon.icon_color;
            } else if (_.isNumber(feed)) {
                feed_id = feed;
            } else if (_.isString(feed) && _.string.startsWith(feed, 'feed:')) {
                feed_id = parseInt(feed.replace('feed:', ''), 10);
            } else if (feed && _.isNumber(feed.id)) {
                feed_id = feed.id;
            } else if (feed && feed.get) {
                feed_key = feed.get('feed_id');
                if (_.isNumber(feed_key)) {
                    feed_id = feed_key;
                } else if (_.isString(feed_key) && _.string.startsWith(feed_key, 'feed:')) {
                    var parsed_feed_id = parseInt(feed_key.replace('feed:', ''), 10);
                    if (!isNaN(parsed_feed_id)) {
                        feed_id = parsed_feed_id;
                    }
                }
            }

            if (_.isNumber(feed_id)) {
                var feed_icon = NEWSBLUR.assets && NEWSBLUR.assets.get_feed_icon(feed_id);
                icon_color = feed_icon && feed_icon.icon_color;
            }
            if (!icon_color && _.isString(feed_key) && _.string.startsWith(feed_key, 'river:')) {
                var feed_folder_title = feed_key.substring('river:'.length);
                var feed_folder_icon = NEWSBLUR.assets && NEWSBLUR.assets.get_folder_icon(feed_folder_title);
                icon_color = feed_folder_icon && feed_folder_icon.icon_color;
            }

            var image_class = options.image_class || 'feed_favicon';
            var emoji_class = options.emoji_class || (is_folder ? 'NB-folder-emoji' : 'feed_favicon NB-feed-emoji');
            var colored_class = options.colored_class || (is_folder ? 'NB-folder-icon-colored' : 'feed_favicon NB-feed-icon-colored');

            return $.make_icon_element({
                icon_url: icon_url,
                icon_color: icon_color,
                image_class: image_class,
                emoji_class: emoji_class,
                colored_class: colored_class,
                role: options.role
            });
        },

        favicon_html: function (feed, options) {
            var $icon = $.favicon_el(feed, options);
            return $icon && $icon.length ? $icon.prop('outerHTML') : '';
        },

        favicon_is_custom: function (feed) {
            return $.icon_url_is_custom($.favicon(feed));
        },

        favicon_image_url: function (feed, empty_on_missing) {
            var icon_url = $.favicon(feed, empty_on_missing);
            if (!_.isString(icon_url) || !_.string.startsWith(icon_url, 'emoji:')) {
                return icon_url;
            }

            if (_.isNumber(feed)) {
                return NEWSBLUR.URLs.favicon.replace('{id}', feed);
            } else if (_.isString(feed)) {
                if (_.string.startsWith(feed, 'feed:')) {
                    return NEWSBLUR.URLs.favicon.replace('{id}', parseInt(feed.replace('feed:', ''), 10));
                } else if (_.string.startsWith(feed, 'river:')) {
                    return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/folder-open.svg';
                }
            } else if (feed && _.isNumber(feed.id)) {
                return NEWSBLUR.URLs.favicon.replace('{id}', feed.id);
            } else if (feed && feed.get && feed.get('favicon_url')) {
                return feed.get('favicon_url');
            }

            return NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/world.svg';
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
                        var $tp = $t.closest(ts);
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

        redirectPost: function(location, args) {
            var form = '';
            $.each( args, function( key, value ) {
                value = value.split('"').join('\"')
                form += '<input type="hidden" name="'+key+'" value="'+value+'">';
            });
            $('<form action="' + location + '" method="POST">' + form + '</form>').appendTo($(document.body)).submit();
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
