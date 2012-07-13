/* encoding: utf-8

  ****  linkify plugin for jQuery - automatically finds and changes URLs in text content into proper hyperlinks  ****

  Version: 1.0

  Copyright (c) 2009
    Már Örlygsson  (http://mar.anomy.net/)  &
    Hugsmiðjan ehf. (http://www.hugsmidjan.is)

  Dual licensed under a MIT licence (http://en.wikipedia.org/wiki/MIT_License)
  and GPL 2.0 or above (http://www.gnu.org/licenses/old-licenses/gpl-2.0.html).

-----------------------------------------------------------------------------

  Demo and Qunit-tests:
    * <./jquery.linkify-1.0-demo.html>
    * <./jquery.linkify-1.0-test.html>

  Documentation:
    * ...

  Get updates from:
    * <http://github.com/maranomynet/linkify/>
    * <git://github.com/maranomynet/linkify.git>

-----------------------------------------------------------------------------

  Requires:
    * jQuery (1.2.6 or later)

  Usage:

      jQuery('.articlebody').linkify();

      // adding plugins:
      jQuery.extend( jQuery.fn.linkify.plugins, {
          name1: {
              re:   RegExp
              tmpl: String/Function
            },
          name2: function(html){ return html; }
        });

      // Uses all plugins by default:
      jQuery('.articlebody').linkify();

      // Use only certain plugins:
      jQuery('.articlebody').linkify( 'name1,name2' );
      jQuery('.articlebody').linkify({  use: 'name1,name2'  });
      jQuery('.articlebody').linkify({  use: ['name1','name2']  });

      // Explicitly use all plugins:
      jQuery('.articlebody').linkify('*');
      jQuery('.articlebody').linkify({  use: '*'  });
      jQuery('.articlebody').linkify({  use: ['*']  });

      // Use no plugins:
      jQuery('.articlebody').linkify('');
      jQuery('.articlebody').linkify({  use: ''  });
      jQuery('.articlebody').linkify({  use: []  });
      jQuery('.articlebody').linkify({  use: ['']  });

      // Perfmorm actions on all newly created links:
      jQuery('.articlebody').linkify( function (links){ links.addClass('linkified'); } );
      jQuery('.articlebody').linkify({  handleLinks: function (links){ links.addClass('linkified'); }  });

*/

(function($){

  var noProtocolUrl = /(^|["'(\s]|&lt;)(www\..+?\..+?)((?:[:?]|\.+)?(?:\s|$)|&gt;|[)"',])/g,
      httpOrMailtoUrl = /(^|["'(\s]|&lt;)((?:(?:https?|ftp):\/\/|mailto:).+?)((?:[:?]|\.+)?(?:\s|$)|&gt;|[)"',])/g,
      linkifier = function ( html ) {
          return html
                      .replace( noProtocolUrl, '$1<a href="<``>://$2">$2</a>$3' )  // NOTE: we escape `"http` as `"<``>` to make sure `httpOrMailtoUrl` below doesn't find it as a false-positive
                      .replace( httpOrMailtoUrl, '$1<a href="$2">$2</a>$3' )
                      .replace( /"<``>/g, '"http' );  // reinsert `"http`
        },


      linkify = $.fn.linkify = function ( cfg ) {
          if ( !$.isPlainObject( cfg ) )
          {
            cfg = {
                use:         (typeof cfg == 'string') ? cfg : undefined,
                handleLinks: $.isFunction(cfg) ? cfg : arguments[1]
              };
          }
          var use = cfg.use,
              allPlugins = linkify.plugins || {},
              plugins = [linkifier],
              tmpCont,
              newLinks = [],
              callback = cfg.handleLinks;
          if ( use == undefined ||  use == '*' ) // use === undefined  ||  use === null
          {
            for ( var name in allPlugins )
            {
              plugins.push( allPlugins[name] );
            }
          }
          else
          {
            use = $.isArray( use ) ? use : $.trim(use).split( / *, */ );
            var plugin,
                name;
            for ( var i=0, l=use.length;  i<l;  i++ )
            {
              name = use[i];
              plugin = allPlugins[name];
              if ( plugin )
              {
                plugins.push( plugin );
              }
            }
          }

          this.each(function () {
              var childNodes = this.childNodes,
                  i = childNodes.length;
              while ( i-- )
              {
                var n = childNodes[i];
                if ( n.nodeType == 3 )
                {
                  var html = n.nodeValue;
                  if ( html.length>1  &&  /\S/.test(html) )
                  {
                    var htmlChanged,
                        preHtml;
                    tmpCont = tmpCont || $('<div/>')[0];
                    tmpCont.innerHTML = '';
                    tmpCont.appendChild( n.cloneNode(false) );
                    var tmpContNodes = tmpCont.childNodes;

                    for (var j=0, plugin; (plugin = plugins[j]); j++)
                    {
                      var k = tmpContNodes.length,
                          tmpNode;
                      while ( k-- )
                      {
                        tmpNode = tmpContNodes[k];
                        if ( tmpNode.nodeType == 3 )
                        {
                          html = tmpNode.nodeValue;
                          if ( html.length>1  &&  /\S/.test(html) )
                          {
                            preHtml = html;
                            html = html
                                      .replace( /&/g, '&amp;' )
                                      .replace( /</g, '&lt;' )
                                      .replace( />/g, '&gt;' );
                            html = $.isFunction( plugin ) ? 
                                        plugin( html ):
                                        html.replace( plugin.re, plugin.tmpl );
                            htmlChanged = htmlChanged || preHtml!=html;
                            preHtml!=html  &&  $(tmpNode).after(html).remove();
                          }
                        }
                      }
                    }
                    html = tmpCont.innerHTML;
                    if ( callback )
                    {
                      html = $('<div/>').html(html);
                      //newLinks.push.apply( newLinks,  html.find('a').toArray() );
                      newLinks = newLinks.concat( html.find('a').toArray().reverse() );
                      html = html.contents();
                    }
                    htmlChanged  &&  $(n).after(html).remove();
                  }
                }
                else if ( n.nodeType == 1  &&  !/^(a|button|textarea|code|pre)$/i.test(n.tagName) )
                {
                  arguments.callee.call( n );
                }
              };
          });
          callback  &&  callback( $(newLinks.reverse()) );
          return this;
        };

  linkify.plugins = {
      // default mailto: plugin
      mailto: {
          re: /(^|["'(\s]|&lt;)([^"'(\s&]+?@.+\.[a-z]{2,7})(([:?]|\.+)?(\s|$)|&gt;|[)"',])/gi,
          tmpl: '$1<a href="mailto:$2">$2</a>$3'
        }
    };

})(jQuery);