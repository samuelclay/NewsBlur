/*!
 * jQuery WakeUp plugin
 * 
 * A JQuery plugin that will help detecting waking up from sleep and/or 
 * hibernation and executing assigned functions.
 * 
 * Based on code provided by Andrew Mu:
 * http://stackoverflow.com/questions/4079115
 * 
 * Copyright (c) 2013, Paul Okopny <paul.okopny@gmail.com>
 * 
 * Permission to use, copy, modify, and/or distribute this software for any 
 * purpose with or without fee is hereby granted, provided that the above 
 * copyright notice and this permission notice appear in all copies.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES 
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF 
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR 
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES 
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN 
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF 
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 * 
 */
(function ($, document, undefined) {
	var default_wakeup_interval = 1000;
	var wake_up_ids = new Array();
	// returns intervalId, which can be used to cancel future waking
	$.wakeUp = function (on_wakeup, params, interval) {
		
		if ((!interval) || typeof(interval) !== 'number' ){
			interval = default_wakeup_interval;
		};
		// on_wakeup should be a function
		if (typeof(on_wakeup) !== "function") {
			return null;
		}
		var lastTime = (new Date()).getTime();
		var intervalId = setInterval(function() {
		  var currentTime = (new Date()).getTime();
		  if (currentTime > (lastTime + interval + 1000)) {  //
			  var sleepTime = currentTime - lastTime;
			  lastTime = currentTime;
			  if (params) {
				  on_wakeup(sleepTime, params);} else {on_wakeup(sleepTime); }
		  } else {lastTime = currentTime;}
		}, interval);
		//add interval id to wake_up_ids array
		wake_up_ids.push(intervalId);
		return intervalId;
	};
	
	$.ignoreBell = function(interval_id) {
		if (interval_id) {
			// delete only one wakeUp call
			wake_up_ids.splice($.inArray(interval_id, wake_up_ids),1);
			clearInterval(interval_id);
		};
	};
	
	$.dreamOn = function() {
		// delete all current wake Up calls
		$.each(wake_up_ids, function(index_of, interval_id) {
				clearInterval(interval_id)
			});
		wake_up_ids = new Array();
	};
	
})(jQuery, document);