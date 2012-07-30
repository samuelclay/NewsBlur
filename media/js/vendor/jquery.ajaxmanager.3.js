/**!
 * project-site: http://plugins.jquery.com/project/AjaxManager
 * repository: http://github.com/aFarkas/Ajaxmanager
 * @author Alexander Farkas
 * @version 3.12
 * Copyright 2010, Alexander Farkas
 * Dual licensed under the MIT or GPL Version 2 licenses.
 */

(function($){
	"use strict";
	var managed = {},
		cache   = {}
	;
	$.manageAjax = (function(){
		function create(name, opts){
			managed[name] = new $.manageAjax._manager(name, opts);
			return managed[name];
		}
		
		function destroy(name){
			if(managed[name]){
				managed[name].clear(true);
				delete managed[name];
			}
		}

		
		var publicFns = {
			create: create,
			destroy: destroy
		};
		
		return publicFns;
	})();
	
	$.manageAjax._manager = function(name, opts){
		this.requests = {};
		this.inProgress = 0;
		this.name = name;
		this.qName = name;
		
		this.opts = $.extend({}, $.manageAjax.defaults, opts);
		if(opts && opts.queue && opts.queue !== true && typeof opts.queue === 'string' && opts.queue !== 'clear'){
			this.qName = opts.queue;
		}
	};
	
	$.manageAjax._manager.prototype = {
		add: function(url, o){
			if(typeof url == 'object'){
				o = url;
			} else if(typeof url == 'string'){
				o = $.extend(o || {}, {url: url});
			}
			o = $.extend({}, this.opts, o);
			
			var origCom		= o.complete || $.noop,
				origSuc		= o.success || $.noop,
				beforeSend	= o.beforeSend || $.noop,
				origError 	= o.error || $.noop,
				strData 	= (typeof o.data == 'string') ? o.data : $.param(o.data || {}),
				xhrID 		= o.type + o.url + strData,
				that 		= this,
				ajaxFn 		= this._createAjax(xhrID, o, origSuc, origCom)
			;
			if(o.preventDoubleRequests && o.queueDuplicateRequests){
				if(o.preventDoubleRequests){
					o.queueDuplicateRequests = false;
				}
				setTimeout(function(){
					throw("preventDoubleRequests and queueDuplicateRequests can't be both true");
				}, 0);
			}
			if(this.requests[xhrID] && o.preventDoubleRequests){
				return;
			}
			ajaxFn.xhrID = xhrID;
			o.xhrID = xhrID;
			
			o.beforeSend = function(xhr, opts){
				var ret = beforeSend.call(this, xhr, opts);
				if(ret === false){
					that._removeXHR(xhrID);
				}
				xhr = null;
				return ret;
			};
			o.complete = function(xhr, status){
				that._complete.call(that, this, origCom, xhr, status, xhrID, o);
				xhr = null;
			};
			
			o.success = function(data, status, xhr){
				that._success.call(that, this, origSuc, data, status, xhr, o);
				xhr = null;
			};
						
			//always add some error callback
			o.error =  function(ahr, status, errorStr){
				var httpStatus 	= '',
					content 	= ''
				;
				if(status !== 'timeout' && ahr){
					httpStatus = ahr.status;
					content = ahr.responseXML || ahr.responseText;
				}
				if(origError) {
					origError.call(this, ahr, status, errorStr, o);
				} else {
					setTimeout(function(){
						throw status + '| status: ' + httpStatus + ' | URL: ' + o.url + ' | data: '+ strData + ' | thrown: '+ errorStr + ' | response: '+ content;
					}, 0);
				}
				ahr = null;
			};
			
			if(o.queue === 'clear'){
				$(document).clearQueue(this.qName);
			}
			
			if(o.queue || (o.queueDuplicateRequests && this.requests[xhrID])){
				$.queue(document, this.qName, ajaxFn);
				if(this.inProgress < o.maxRequests && (!this.requests[xhrID] || !o.queueDuplicateRequests)){
					$.dequeue(document, this.qName);
				}
				return xhrID;
			}
			return ajaxFn();
		},
		_createAjax: function(id, o, origSuc, origCom){
			var that = this;
			return function(){
				if(o.beforeCreate.call(o.context || that, id, o) === false){return;}
				that.inProgress++;
				if(that.inProgress === 1){
					$.event.trigger(that.name +'AjaxStart');
				}
				if(o.cacheResponse && cache[id]){
					if(!cache[id].cacheTTL || cache[id].cacheTTL < 0 || ((new Date().getTime() - cache[id].timestamp) < cache[id].cacheTTL)){
                        that.requests[id] = {};
                        setTimeout(function(){
							that._success.call(that, o.context || o, origSuc, cache[id]._successData, 'success', cache[id], o);
                        	that._complete.call(that, o.context || o, origCom, cache[id], 'success', id, o);
                        }, 0);
                    } else {
						 delete cache[id];
					}
				} 
				if(!o.cacheResponse || !cache[id]) {
					if (o.async) {
						that.requests[id] = $.ajax(o);
					} else {
						$.ajax(o);
					}
				}
				return id;
			};
		},
		_removeXHR: function(xhrID){
			if(this.opts.queue || this.opts.queueDuplicateRequests){
				$.dequeue(document, this.qName);
			}
			this.inProgress--;
			this.requests[xhrID] = null;
			delete this.requests[xhrID];
		},
		clearCache: function () {
            cache = {};
        },
		_isAbort: function(xhr, status, o){
			if(!o.abortIsNoSuccess || (!xhr && !status)){
				return false;
			}
			var ret = !!(  ( !xhr || xhr.readyState === 0 || this.lastAbort === o.xhrID ) );
			xhr = null;
			return ret;
		},
		_complete: function(context, origFn, xhr, status, xhrID, o){
			if(this._isAbort(xhr, status, o)){
				status = 'abort';
				o.abort.call(context, xhr, status, o);
			}
			origFn.call(context, xhr, status, o);
			
			$.event.trigger(this.name +'AjaxComplete', [xhr, status, o]);
			
			if(o.domCompleteTrigger){
				$(o.domCompleteTrigger)
					.trigger(this.name +'DOMComplete', [xhr, status, o])
					.trigger('DOMComplete', [xhr, status, o])
				;
			}
			
			this._removeXHR(xhrID);
			if(!this.inProgress){
				$.event.trigger(this.name +'AjaxStop');
			}
			xhr = null;
		},
		_success: function(context, origFn, data, status, xhr, o){
			var that = this;
			if(this._isAbort(xhr, status, o)){
				xhr = null;
				return;
			}
			if(o.abortOld){
				$.each(this.requests, function(name){
					if(name === o.xhrID){
						return false;
					}
					that.abort(name);
				});
			}
			if(o.cacheResponse && !cache[o.xhrID]){
				if(!xhr){
					xhr = {};
				}
				cache[o.xhrID] = {
					status: xhr.status,
					statusText: xhr.statusText,
					responseText: xhr.responseText,
					responseXML: xhr.responseXML,
					_successData: data,
					cacheTTL: o.cacheTTL, 
					timestamp: new Date().getTime()
				};
				if('getAllResponseHeaders' in xhr){
					var responseHeaders = xhr.getAllResponseHeaders();
					var parsedHeaders;
					var parseHeaders = function(){
						if(parsedHeaders){return;}
						parsedHeaders = {};
						$.each(responseHeaders.split("\n"), function(i, headerLine){
							var delimiter = headerLine.indexOf(":");
		                    parsedHeaders[headerLine.substr(0, delimiter)] = headerLine.substr(delimiter + 2);
						});
					};
					$.extend(cache[o.xhrID], {
						getAllResponseHeaders: function() {return responseHeaders;},
						getResponseHeader: function(name) {
							parseHeaders();
							return (name in parsedHeaders) ? parsedHeaders[name] : null;
						}
					});
				}
			}
			origFn.call(context, data, status, xhr, o);
			$.event.trigger(this.name +'AjaxSuccess', [xhr, o, data]);
			if(o.domSuccessTrigger){
				$(o.domSuccessTrigger)
					.trigger(this.name +'DOMSuccess', [data, o])
					.trigger('DOMSuccess', [data, o])
				;
			}
			xhr = null;
		},
		getData: function(id){
			if( id ){
				var ret = this.requests[id];
				if(!ret && this.opts.queue) {
					ret = $.grep($(document).queue(this.qName), function(fn, i){
						return (fn.xhrID === id);
					})[0];
				}
				return ret;
			}
			return {
				requests: this.requests,
				queue: (this.opts.queue) ? $(document).queue(this.qName) : [],
				inProgress: this.inProgress
			};
		},
		abort: function(id){
			var xhr;
			if(id){
				xhr = this.getData(id);
				
				if(xhr && xhr.abort){
					this.lastAbort = id;
					xhr.abort();
					this.lastAbort = false;
				} else {
					$(document).queue(
						this.qName, $.grep($(document).queue(this.qName), function(fn, i){
							return (fn !== xhr);
						})
					);
				}
				xhr = null;
				return;
			}
			
			var that 	= this,
				ids 	= []
			;
			$.each(this.requests, function(id){
				ids.push(id);
			});
			$.each(ids, function(i, id){
				that.abort(id);
			});
		},
		clear: function(shouldAbort){
			$(document).clearQueue(this.qName); 
			if(shouldAbort){
				this.abort();
			}
		}
	};
	$.manageAjax._manager.prototype.getXHR = $.manageAjax._manager.prototype.getData;
	$.manageAjax.defaults = {
		beforeCreate: $.noop,
		abort: $.noop,
		abortIsNoSuccess: true,
		maxRequests: 1,
		cacheResponse: false,
		async: true,
		domCompleteTrigger: false,
		domSuccessTrigger: false,
		preventDoubleRequests: true,
		queueDuplicateRequests: false,
		cacheTTL: -1,
		queue: false // true, false, clear
	};
	
	$.each($.manageAjax._manager.prototype, function(n, fn){
		if(n.indexOf('_') === 0 || !$.isFunction(fn)){return;}
		$.manageAjax[n] =  function(name, o){
			if(!managed[name]){
				if(n === 'add'){
					$.manageAjax.create(name, o);
				} else {
					return;
				}
			}
			var args = Array.prototype.slice.call(arguments, 1);
			managed[name][n].apply(managed[name], args);
		};
	});
	
})(jQuery);