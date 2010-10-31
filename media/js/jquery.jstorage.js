/**
 * ----------------------------- JSTORAGE -------------------------------------
 * Simple local storage wrapper to save data on the browser side, supporting
 * all major browsers - IE6+, Firefox2+, Safari4+, Chrome4+ and Opera 10.5+
 *
 * Copyright (c) 2010 Andris Reinman, andris.reinman@gmail.com
 * Project homepage: www.jstorage.info
 *
 * Licensed under MIT-style license:
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * USAGE:
 *
 * jStorage requires Prototype, MooTools or jQuery! If jQuery is used, then
 * jQuery-JSON (http://code.google.com/p/jquery-json/) is also needed.
 * (jQuery-JSON needs to be loaded BEFORE jStorage!)
 *
 * Methods:
 *
 * -set(key, value)
 * $.jStorage.set(key, value) -> saves a value
 *
 * -get(key[, default])
 * value = $.jStorage.get(key [, default]) ->
 *    retrieves value if key exists, or default if it doesn't
 *
 * -deleteKey(key)
 * $.jStorage.deleteKey(key) -> removes a key from the storage
 *
 * -flush()
 * $.jStorage.flush() -> clears the cache
 *
 * <value> can be any JSON-able value, including objects and arrays.
 *
 */

(function($){
	if(!$ || !($.toJSON || Object.toJSON || window.JSON)){
		throw new Error("jQuery, MooTools or Prototype needs to be loaded before jStorage!");
	}
	
	var
		/* This is the object, that holds the cached values */ 
		_storage = {},

		/* Actual browser storage (localStorage or globalStorage['domain']) */
		_storage_service = {jStorage:"{}"},

		/* DOM element for older IE versions, holds userData behavior */
		_storage_elm = null,

		/* function to encode objects to JSON strings */
		json_encode = $.toJSON || Object.toJSON || (window.JSON && (JSON.encode || JSON.stringify)),

		/* function to decode objects from JSON strings */
		json_decode = $.evalJSON || (window.JSON && (JSON.decode || JSON.parse)) || function(str){
			return String(str).evalJSON();
		};

	////////////////////////// PRIVATE METHODS ////////////////////////

	/**
	 * Initialization function. Detects if the browser supports DOM Storage
	 * or userData behavior and behaves accordingly.
	 * @returns undefined
	 */
	function _init(){
		/* Check if browser supports localStorage */
		if(window.localStorage){
			try {
				_storage_service = window.localStorage;
			} catch(E0) {/* Firefox fails when touching localStorage and cookies are disabled */}
		}
		/* Check if browser supports globalStorage */
		else if(window.globalStorage){
			try {
				_storage_service = window.globalStorage[window.location.hostname];
			} catch(E1) {/* Firefox fails when touching localStorage and cookies are disabled */}
		}
		/* Check if browser supports userData behavior */
		else {
			_storage_elm = document.createElement('link');
			if(_storage_elm.addBehavior){

				/* Use a DOM element to act as userData storage */
				_storage_elm.style.behavior = 'url(#default#userData)';

				/* userData element needs to be inserted into the DOM! */
				document.getElementsByTagName('head')[0].appendChild(_storage_elm);

				_storage_elm.load("jStorage");
				var data = "{}";
				try{
					data = _storage_elm.getAttribute("jStorage");
				}catch(E2){}
				_storage_service.jStorage = data;
			}else{
				_storage_elm = null;
				return;
			}
		}

		/* if jStorage string is retrieved, then decode it */
		if(_storage_service.jStorage){
			try{
				_storage = json_decode(_storage_service.jStorage);
			}catch(E3){_storage_service.jStorage = "{}";}
		}else{
			_storage_service.jStorage = "{}";
		}
	}

	/**
	 * This functions provides the "save" mechanism to store the jStorage object
	 * @returns undefined
	 */
	function _save(){
		try{
			_storage_service.jStorage = json_encode(_storage);
			// If userData is used as the storage engine, additional
			if(_storage_elm) {
				_storage_elm.setAttribute("jStorage",_storage_service.jStorage);
				_storage_elm.save("jStorage");
			}
		}catch(E4){/* probably cache is full, nothing is saved this way*/}
	}

	/**
	 * Function checks if a key is set and is string or numberic
	 */
	function _checkKey(key){
		if(!key || (typeof key != "string" && typeof key != "number")){
			throw new TypeError('Key name must be string or numeric');
		}
		return true;
	}

	////////////////////////// PUBLIC INTERFACE /////////////////////////

	$.storage = {
		/* Version number */
		version: "0.1.3",

		/**
		 * Sets a key's value.
		 * 
		 * @param {String} key - Key to set. If this value is not set or not
		 *				a string an exception is raised.
		 * @param value - Value to set. This can be any value that is JSON
		 *				compatible (Numbers, Strings, Objects etc.).
		 * @returns the used value
		 */
		set: function(key, value){
			_checkKey(key);
			_storage[key] = value;
			_save();
			return value;
		},
		
		/**
		 * Looks up a key in cache
		 * 
		 * @param {String} key - Key to look up.
		 * @param {mixed} def - Default value to return, if key didn't exist.
		 * @returns the key value, default value or <null>
		 */
		get: function(key, def){
			_checkKey(key);
			if(key in _storage){
				return _storage[key];
			}
			return typeof(def) == 'undefined' ? null : def;
		},
		
		/**
		 * Deletes a key from cache.
		 * 
		 * @param {String} key - Key to delete.
		 * @returns true if key existed or false if it didn't
		 */
		deleteKey: function(key){
			_checkKey(key);
			if(key in _storage){
				delete _storage[key];
				_save();
				return true;
			}
			return false;
		},

		/**
		 * Deletes everything in cache.
		 * 
		 * @returns true
		 */
		flush: function(){
			_storage = {};
			_save();
			/*
			 * Just to be sure - andris9/jStorage#3
			 */
			if (window.localStorage){
				try{
					localStorage.clear();
				}catch(E5){}
			}
			return true;
		},
		
		/**
		 * Returns a read-only copy of _storage
		 * 
		 * @returns Object
		*/
		storageObj: function(){
			function F() {}
			F.prototype = _storage;
			return new F();
		}
	};

	// Initialize jStorage
	_init();

})(window.jQuery || window.$);