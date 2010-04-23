/**
 * 
 * Find more about the scrolling function at
 * http://cubiq.org/scrolling-div-for-mobile-webkit-turns-3/16
 *
 * Copyright (c) 2009 Matteo Spinelli, http://cubiq.org/
 * Released under MIT license
 * http://cubiq.org/dropbox/mit-license.txt
 * 
 * Version 3.0beta4 - Last updated: 2010.04.02
 * 
 */

function iScroll (el, options) {
	this.element = typeof el == 'object' ? el : document.getElementById(el);
	this.wrapper = this.element.parentNode;

	this.wrapper.style.overflow = 'hidden';
	this.wrapper.style.position = 'relative';
	this.element.style.webkitTransitionProperty = '-webkit-transform';
	this.element.style.webkitTransitionTimingFunction = 'cubic-bezier(0,0,0.25,1)';
	this.element.style.webkitTransitionDuration = '0';
	this.element.style.webkitTransform = 'translate3d(0,0,0)';

	// Get options
	this.options = {
		bounce: true,
		hScrollBar: true,
		vScrollBar: true
	};
	
	if (typeof options == 'object') {
		for (var i in options) {
			this.options[i] = options[i];
		}
	}

	this.refresh();
	
	this.element.addEventListener('touchstart', this, false);
	this.element.addEventListener('touchmove', this, false);
	this.element.addEventListener('touchend', this, false);
	window.addEventListener('orientationchange', this, false);
}

iScroll.prototype = {
	_x: 0,
	_y: 0,

	handleEvent: function (e) {
		switch (e.type) {
			case 'touchstart': this.onTouchStart(e); break;
			case 'touchmove': this.onTouchMove(e); break;
			case 'touchend': this.onTouchEnd(e); break;
			case 'webkitTransitionEnd': this.onTransitionEnd(e); break;
			case 'orientationchange': this.refresh(); this.scrollTo(0,0,'0'); break;
		}
	},

	refresh: function () {
		this.element.style.webkitTransitionDuration = '0';
		this.scrollWidth = this.wrapper.clientWidth;
		this.scrollHeight = this.wrapper.clientHeight;
		this.maxScrollX = this.scrollWidth - this.element.offsetWidth;
		this.maxScrollY = this.scrollHeight - this.element.offsetHeight;
		this.scrollX = this.element.offsetWidth > this.scrollWidth ? true : false;
		this.scrollY = this.element.offsetHeight > this.scrollHeight ? true : false;

		// Update horizontal scrollbar
		if (this.options.hScrollBar && this.scrollX) {
			this.scrollBarX = new scrollbar('horizontal', this.wrapper);			
			this.scrollBarX.init(this.scrollWidth, this.element.offsetWidth);
		} else if (this.scrollBarX) {
			this.scrollBarX = this.scrollBarX.remove();
		}

		// Update vertical scrollbar
		if (this.options.vScrollBar && this.scrollY) {
			this.scrollBarY = new scrollbar('vertical', this.wrapper);			
			this.scrollBarY.init(this.scrollHeight, this.element.offsetHeight);
		} else if (this.scrollBarY) {
			this.scrollBarY = this.scrollBarY.remove();
		}
	},

	get x() {
		return this._x;
	},

	get y() {
		return this._y;
	},

	setPosition: function (x, y) { 
		this._x = x !== null ? x : this._x;
		this._y = y !== null ? y : this._y;

		this.element.style.webkitTransform = 'translate3d(' + this._x + 'px,' + this._y + 'px,0)';

		// Move the scrollbars
		if (this.scrollBarX) {
			this.scrollBarX.setPosition(this.scrollBarX.maxScroll / this.maxScrollX * this._x);
		}
		if (this.scrollBarY) {
			this.scrollBarY.setPosition(this.scrollBarY.maxScroll / this.maxScrollY * this._y);
		}
	},
		
	onTouchStart: function(e) {
	    if (e.targetTouches.length != 1) {
	        return false;
        }

		e.preventDefault();
		e.stopPropagation();
		
		this.element.style.webkitTransitionDuration = '0';
		
		if (this.scrollBarX) {
			this.scrollBarX.bar.style.webkitTransitionDuration = '0, 250ms';
		}
		if (this.scrollBarY) {
			this.scrollBarY.bar.style.webkitTransitionDuration = '0, 250ms';
		}

		// Check if elem is really where it should be
		var theTransform = new WebKitCSSMatrix(window.getComputedStyle(this.element).webkitTransform);
		if (theTransform.m41 != this.x || theTransform.m42 != this.y) {
			this.setPosition(theTransform.m41, theTransform.m42);
		}

		this.touchStartX = e.touches[0].pageX;
		this.scrollStartX = this.x;

		this.touchStartY = e.touches[0].pageY;
		this.scrollStartY = this.y;			

		this.scrollStartTime = e.timeStamp;
		this.moved = false;
	},
	
	onTouchMove: function(e) {
		if (e.targetTouches.length != 1) {
			return false;
		}

		var leftDelta = this.scrollX === true ? e.touches[0].pageX - this.touchStartX : 0;
		var topDelta = this.scrollY === true ? e.touches[0].pageY - this.touchStartY : 0;

		if (this.x > 0 || this.x < this.maxScrollX) { 
			leftDelta = Math.round(leftDelta / 4);		// Slow down if outside of the boundaries
		}

		if (this.y > 0 || this.y < this.maxScrollY) { 
			topDelta = Math.round(topDelta / 4);		// Slow down if outside of the boundaries
		}

		if (this.scrollBarX && !this.scrollBarX.visible) {
			this.scrollBarX.show();
		}
		if (this.scrollBarY && !this.scrollBarY.visible) {
			this.scrollBarY.show();
		}

		this.setPosition(this.x + leftDelta, this.y + topDelta);

		this.touchStartX = e.touches[0].pageX;
		this.touchStartY = e.touches[0].pageY;
		this.moved = true;

		// Prevent slingshot effect
		if( e.timeStamp-this.scrollStartTime > 250 ) {
			this.scrollStartX = this.x;
			this.scrollStartY = this.y;
			this.scrollStartTime = e.timeStamp;
		}
	},
	
	onTouchEnd: function(e) {
		if (e.targetTouches.length > 0) {
			return false;
		}

		if (!this.moved) {
			var theEvent = document.createEvent('MouseEvents');
			theEvent.initMouseEvent("click", true, true, document.defaultView, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, null);
			e.changedTouches[0].target.dispatchEvent(theEvent);		
			return false;
		}
		
		var time = e.timeStamp - this.scrollStartTime;

		var momentumX = this.scrollX === true
			? this.momentum(this.x - this.scrollStartX,
							time,
							-this.x + 50,
							this.x + this.element.offsetWidth - this.scrollWidth + 50)
			: { dist: 0, time: 0 };

		var momentumY = this.scrollY === true
			? this.momentum(this.y - this.scrollStartY,
							time,
							 -this.y + /*this.scrollHeight/3*/ 50,
							this.y + this.element.offsetHeight - this.scrollHeight + /*this.scrollHeight/3*/ 50)
			: { dist: 0, time: 0 };

		if (!momentumX.dist && !momentumY.dist) {
			this.onTransitionEnd();	// I know, I know... This is lame
			return false;
		}

		var newDuration = Math.max(momentumX.time, momentumY.time);
		var newPositionX = this.x + momentumX.dist;
		var newPositionY = this.y + momentumY.dist;

		this.element.addEventListener('webkitTransitionEnd', this);

		this.scrollTo(newPositionX, newPositionY, newDuration + 'ms');

		// Move the scrollbars
		if (this.scrollBarX) {
			this.scrollBarX.scrollTo(this.scrollBarX.maxScroll / this.maxScrollX * newPositionX, newDuration + 'ms');	
		}		
		if (this.scrollBarY) {
			this.scrollBarY.scrollTo(this.scrollBarY.maxScroll / this.maxScrollY * newPositionY, newDuration + 'ms');
		}
	},
	
	onTransitionEnd: function () {
		this.element.removeEventListener('webkitTransitionEnd', this);
		this.resetPosition();

		// Hide the scrollbars
		if (this.scrollBarX) {
			this.scrollBarX.hide();
		}
		if (this.scrollBarY) {
			this.scrollBarY.hide();
		}
	},

	resetPosition: function () {
		var resetX = resetY = null;
		if (this.x > 0 || this.x < this.maxScrollX) {
			resetX = this.x >= 0 ? 0 : this.maxScrollX;
		}

		if (this.y > 0 || this.y < this.maxScrollY) {
			resetY = this.y >= 0 ? 0 : this.maxScrollY;
		}

		if (resetX !== null || resetY !== null) {
			this.scrollTo(resetX, resetY, '500ms');

			if (this.scrollBarX) {
				this.scrollBarX.scrollTo(this.scrollBarX.maxScroll / this.maxScrollX * (resetX || this.x), '500ms');
			}			
			if (this.scrollBarY) {
				this.scrollBarY.scrollTo(this.scrollBarY.maxScroll / this.maxScrollY * (resetY || this.y), '500ms');
			}
		}
	},

	scrollTo: function (destX, destY, runtime) {
		this.element.style.webkitTransitionDuration = runtime || '400ms';
		this.setPosition(destX, destY);
	},

	momentum: function (dist, time, maxDist1, maxDist2) {
		friction = 0.1;
		deceleration = 1.5;

		var speed = Math.abs(dist) / time * 1000;
		var newDist = speed * speed / (20 * friction) / 1000;

		// Proportinally reduce speed if we are outside of the boundaries 
		if (dist > 0 && maxDist1 !== undefined && newDist > maxDist1) {
			speed = speed * maxDist1 / newDist;
			newDist = maxDist1;
		}
		if (dist < 0 && maxDist2 !== undefined && newDist > maxDist2) {
			speed = speed * maxDist2 / newDist;
			newDist = maxDist2;
		}
		
		newDist = newDist * (dist < 0 ? -1 : 1);
		
		var newTime = -speed / -deceleration;
		if (newTime < 1) {	// We can't go back in time
			newTime = 1;
		}

		return { dist: Math.round(newDist), time: Math.round(newTime) };
	}
};

var scrollbar = function (dir, wrapper) {
	this.dir = dir;
	this.bar = document.createElement('div');
	this.bar.className = 'scrollbar ' + dir;
	this.bar.style.webkitTransitionTimingFunction = 'cubic-bezier(0,0,0.25,1)';
	this.bar.style.webkitTransform = 'translate3d(0,0,0)';
	this.bar.style.webkitTransitionProperty = '-webkit-transform,opacity';
	this.bar.style.webkitTransitionDuration = '0,250ms';
	this.bar.style.pointerEvents = 'none';
	this.bar.style.opacity = '0';

	wrapper.appendChild(this.bar);
}

scrollbar.prototype = {
	size: 0,
	maxSize: 0,
	maxScroll: 0,
	visible: false,
	
	init: function (scroll, size) {
		var offset = this.dir == 'horizontal' ? this.bar.offsetWidth - this.bar.clientWidth : this.bar.offsetHeight - this.bar.clientHeight;
		this.maxSize = scroll - 8;		// 8 = distance from top + distance from bottom
		this.size = Math.round(this.maxSize * this.maxSize / size) + offset;
		this.maxScroll = this.maxSize - this.size;
		this.bar.style[this.dir == 'horizontal' ? 'width' : 'height'] = (this.size - offset) + 'px';
	},
	
	setPosition: function (pos) {
		if (pos < 0) {
			pos = 0;
		} else if (pos > this.maxScroll) {
			pos = this.maxScroll;
		}

		pos = this.dir == 'horizontal' ? 'translate3d(' + Math.round(pos) + 'px,0,0)' : 'translate3d(0,' + Math.round(pos) + 'px,0)';
		this.bar.style.webkitTransform = pos;
	},
	
	scrollTo: function (pos, runtime) {
		this.bar.style.webkitTransitionDuration = (runtime || '400ms') + ',250ms';
		this.setPosition(pos);
	},
	
	show: function () {
		this.visible = true;
		this.bar.style.opacity = '1';
	},

	hide: function () {
		this.visible = false;
		this.bar.style.opacity = '0';
	},
	
	remove: function () {
		this.bar.parentNode.removeChild(this.bar);
		return null;
	}
};