/*
* jQuery TinySort - A plugin to sort child nodes by (sub) contents or attributes.
*
* Version: 1.0.4
*
* Copyright (c) 2008 Ron Valstar
*
* Dual licensed under the MIT and GPL licenses:
*   http://www.opensource.org/licenses/mit-license.php
*   http://www.gnu.org/licenses/gpl.html
*
* description
*   - A plugin to sort child nodes by (sub) contents or attributes.
*
* Usage:
*   $("ul#people>li").tsort();
*   $("ul#people>li").tsort("span.surname");
*   $("ul#people>li").tsort("span.surname",{order:"desc"});
*   $("ul#people>li").tsort({place:"end"});
*
* Change default like so:
*   $.tinysort.defaults.order = "desc";
*
* in this update:
*	- changed setArray to pushStack
*
* in last update:
*	- tested with jQuery 1.4.1
*	- correct isNum return
*
* Todos
*   - fix mixed literal/numeral values
*   - determine if I have to use pushStack or pushStack
*
*/
;(function($) {
	// default settings
	$.tinysort = {
		 id: "TinySort"
		,version: "1.0.4"
		,defaults: {
			 order: "asc"	// order: asc, desc or rand
			,attr: ""		// order by attribute value
			,place: "start"	// place ordered elements at position: start, end, org (original position), first
			,returns: false	// return all elements or only the sorted ones (true/false)
		}
	};
	$.fn.extend({
		tinysort: function(_find,_settings) {
			if (_find&&typeof(_find)!="string") {
				_settings = _find;
				_find = null;
			}

			var oSettings = $.extend({}, $.tinysort.defaults, _settings);

			var oElements = {}; // contains sortable- and non-sortable list per parent
			this.each(function(i) {
				// element or sub selection
				var mElm = (!_find||_find=="")?$(this):$(this).find(_find);
				// text or attribute value
				var sSort = oSettings.order=="rand"?""+Math.random():(oSettings.attr==""?mElm.text():mElm.attr(oSettings.attr));
				// to sort or not to sort
				var mParent = $(this).parent();
				if (!oElements[mParent]) oElements[mParent] = {s:[],n:[]};	// s: sort, n: not sort
				if (mElm.length>0)	oElements[mParent].s.push({s:sSort,e:$(this),n:i}); // s:string, e:element, n:number
				else				oElements[mParent].n.push({e:$(this),n:i});
			});
			//
			// sort
			for (var sParent in oElements) {
				var oParent = oElements[sParent];
				oParent.s.sort(
					function zeSort(a,b) {
						var x = a.s.toLowerCase?a.s.toLowerCase():a.s;
						var y = b.s.toLowerCase?b.s.toLowerCase():b.s;
						if (isNum(a.s)&&isNum(b.s)) {
							x = parseFloat(a.s);
							y = parseFloat(b.s);
						}
						return (oSettings.order=="asc"?1:-1)*(x<y?-1:(x>y?1:0));
					}
				);
			}
			//
			// order elements and fill new order
			var aNewOrder = [];
			for (var sParent in oElements) {
				var oParent = oElements[sParent];
				var aOrg = []; // list for original position
				var iLow = $(this).length;
				switch (oSettings.place) {
					case "first": $.each(oParent.s,function(i,obj) { iLow = Math.min(iLow,obj.n) }); break;
					case "org": $.each(oParent.s,function(i,obj) { aOrg.push(obj.n) }); break;
					case "end": iLow = oParent.n.length; break;
					default: iLow = 0;
				}
				var aCnt = [0,0]; // count how much we've sorted for retreival from either the sort list or the non-sort list (oParent.s/oParent.n)
				for (var i=0;i<$(this).length;i++) {
					var bSList = i>=iLow&&i<iLow+oParent.s.length;
					if (contains(aOrg,i)) bSList = true;
					var mEl = (bSList?oParent.s:oParent.n)[aCnt[bSList?0:1]].e;
					mEl.parent().append(mEl);
					if (bSList||!oSettings.returns) aNewOrder.push(mEl.get(0));
					aCnt[bSList?0:1]++;
				}
			}
			//
			return this.pushStack(aNewOrder); // pushStack or pushStack?
		}
	});
	// is numeric
	function isNum(n) {
		var x = /^\s*?[\+-]?(\d*\.?\d*?)\s*?$/.exec(n);
		return x&&x.length>0?x[1]:false;
	};
	// array contains
	function contains(a,n) {
		var bInside = false;
		$.each(a,function(i,m) {
			if (!bInside) bInside = m==n;
		});
		return bInside;
	};
	// set functions
	$.fn.TinySort = $.fn.Tinysort = $.fn.tsort = $.fn.tinysort;
})(jQuery);