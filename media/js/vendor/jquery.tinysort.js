/*
* jQuery TinySort 1.1.1
* A plugin to sort child nodes by (sub) contents or attributes.
*
* Copyright (c) 2008-2011 Ron Valstar http://www.sjeiti.com/
*
* Dual licensed under the MIT and GPL licenses:
*   http://www.opensource.org/licenses/mit-license.php
*   http://www.gnu.org/licenses/gpl.html
*
* contributors:
*	brian.gibson@gmail.com
*	michael.thornberry@gmail.com
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
*	- better isNum
*
* in last update:
* 	- reduced minified filesize with 14% by doing
*     - bit of code cleaning
* 	  - removed redundant var declarations
* 	  - predeclaring reoccuring variables
* 	  - removed the comment for the minified version
*	- added better documentation for custom sort function
*	- tested with jQuery 1.6.4
*
* Todos
*   - fix mixed literal/numeral values
*
*/
;(function($) {
	// default settings
	var f = false, n = null;
	$.tinysort = {
		 id: 'TinySort'
		,version: '1.1.2'
		,copyright: 'Copyright (c) 2008-2011 Ron Valstar'
		,uri: 'http://tinysort.sjeiti.com/'
		,licenced: {
			MIT: 'http://www.opensource.org/licenses/mit-license.php'
			,GPL: 'http://www.gnu.org/licenses/gpl.html'
		}
		,defaults: {
			 order: 'asc'		// order: asc, desc or rand

			,attr: n			// order by attribute value
			,data: n			// use the data attribute for sorting
			,useVal: f			// use element value instead of text

			,place: 'start'		// place ordered elements at position: start, end, org (original position), first
			,returns: f			// return all elements or only the sorted ones (true/false)

			,cases: f			// a case sensitive sort orders [aB,aa,ab,bb]
			,forceStrings:f		// if false the string '2' will sort with the value 2, not the string '2'

			,sortFunction: n	// override the default sort function
		}
//		,expose: function(){return {toLowerCase:toLowerCase,isNum:isNum,contains:contains};}
	};
	$.fn.extend({
		tinysort: function(_find,_settings) {
			if (_find&&typeof(_find)!='string') {
				_settings = _find;
				_find = n;
			}

			var oSettings = $.extend({}, $.tinysort.defaults, _settings)
				,p = parseFloat
				,sParent
				,oElements = {} // contains sortable- and non-sortable list per parent
				,bFind = !(!_find||_find=='')
				,bAttr = !(oSettings.attr===n||oSettings.attr=="")
				,bData = oSettings.data!==n
				// since jQuery's filter within each works on array index and not actual index we have to create the filter in advance
				,bFilter = bFind&&_find[0]==':'
				,$Filter = bFilter?this.filter(_find):this
				,fn = oSettings.sortFunction;

			if (!fn) fn = oSettings.order=='rand'?function() {
				return Math.random()<.5?1:-1;
			}:function(a,b) {
				var x = !oSettings.cases?toLowerCase(a.s):a.s
					,y = !oSettings.cases?toLowerCase(b.s):b.s;
				if (!oSettings.forceStrings&&isNum(a.s)&&isNum(b.s)) {
					x = p(a.s);
					y = p(b.s);
				}
				return (oSettings.order=='asc'?1:-1)*(x<y?-1:(x>y?1:0));
			};

			this.each(function(i,el) {
				var $This = $(el)
					// element or sub selection
					,mElm = bFind?(bFilter?$Filter.filter(this):$This.find(_find)):$This
					// text or attribute value
					,sSort = bData?mElm.data(oSettings.data):(bAttr?mElm.attr(oSettings.attr):(oSettings.useVal?mElm.val():mElm.text()))
 					// to sort or not to sort
					,mParent = $This.parent();

				if (!oElements[mParent])	oElements[mParent] = {s:[],n:[]};	// s: sort, n: not sort
				if (mElm.length>0)			oElements[mParent].s.push({s:sSort,e:$This,n:i}); // s:string, e:element, n:number
				else						oElements[mParent].n.push({e:$This,n:i});
			});
			//
			// sort
			for (sParent in oElements) oElements[sParent].s.sort(fn);
			//
			// order elements and fill new order
			var aNewOrder = [];
			for (sParent in oElements) {
				var oParent = oElements[sParent]
					,aOrg = [] // list for original position
					,iLow = $(this).length;
				switch (oSettings.place) {
					case 'first':	$.each(oParent.s,function(i,obj) { iLow = Math.min(iLow,obj.n) }); break;
					case 'org':		$.each(oParent.s,function(i,obj) { aOrg.push(obj.n) }); break;
					case 'end':		iLow = oParent.n.length; break;
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
			return this.pushStack(aNewOrder);
		}
	});
	// toLowerCase
	function toLowerCase(s) {
		return s&&s.toLowerCase?s.toLowerCase():s;
	}
	// is numeric
	function isNum(n) {
		return !isNaN(parseFloat(n)) && isFinite(n);
	}
	// array contains
	function contains(a,n) {
		var bInside = f;
		$.each(a,function(i,m) {
			if (!bInside) bInside = m==n;
		});
		return bInside;
	}
	// set functions
	$.fn.TinySort = $.fn.Tinysort = $.fn.tsort = $.fn.tinysort;
})(jQuery);