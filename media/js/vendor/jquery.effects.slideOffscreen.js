/**
 *	UI Layout Plugin: Slide-Offscreen Animation
 *
 *	Prevent panes from being 'hidden' so that an iframes/objects 
 *	does not reload/refresh when pane 'opens' again.
 *	This plug-in adds a new animation called "slideOffscreen".
 *	It is identical to the normal "slide" effect, but avoids hiding the element
 *
 *	Requires Layout 1.3.0.RC30.1 or later for Close offscreen
 *	Requires Layout 1.3.0.RC30.5 or later for Hide, initClosed & initHidden offscreen
 *
 *	Version:	1.0 - 2012-04-07
 *	Author:		Kevin Dalman (kevin.dalman@gmail.com)
 *	@preserve	jquery.layout.slideOffscreen-1.0.js
 */
;(function ($) {
var _ = $.layout;

// Add a new "slideOffscreen" effect
if ($.effects) {

	// add an option so initClosed and initHidden will work
	_.defaults.panes.useOffscreenClose = false; // user must enable when needed
	/* set the new animation as the default for all panes
	_.defaults.panes.fxName = "slideOffscreen";
	*/

	if (_.plugins)
		_.plugins.effects.slideOffscreen = true;

	// dupe 'slide' effect defaults as new effect defaults
	_.effects.slideOffscreen = $.extend(true, {}, _.effects.slide);

	// add new effect to jQuery UI
	$.effects.slideOffscreen = function(o) {
		return this.queue(function(){

			var fx		= $.effects
			,	opt		= o.options
			,	$el		= $(this)
			,	pane	= $el.data('layoutEdge')
			,	state	= $el.data('parentLayout').state
			,	dist	= state[pane].size
			,	s		= this.style
			,	props	= ['top','bottom','left','right']
				// Set options
			,	mode	= fx.setMode($el, opt.mode || 'show') // Set Mode
			,	show	= (mode == 'show')
			,	dir		= opt.direction || 'left' // Default Direction
			,	ref	 	= (dir == 'up' || dir == 'down') ? 'top' : 'left'
			,	pos		= (dir == 'up' || dir == 'left')
			,	offscrn	= _.config.offscreenCSS || {}
			,	keyLR	= _.config.offscreenReset
			,	keyTB	= 'offscreenResetTop' // only used internally
			,	animation = {}
			;
			// Animation settings
			animation[ref]	= (show ? (pos ? '+=' : '-=') : (pos ? '-=' : '+=')) + dist;

			if (show) { // show() animation, so save top/bottom but retain left/right set when 'hidden'
				$el.data(keyTB, { top: s.top, bottom: s.bottom });

				// set the top or left offset in preparation for animation
				// Note: ALL animations work by shifting the top or left edges
				if (pos) { // top (north) or left (west)
					$el.css(ref, isNaN(dist) ? "-" + dist : -dist); // Shift outside the left/top edge
				}
				else { // bottom (south) or right (east) - shift all the way across container
					if (dir === 'right')
						$el.css({ left: state.container.offsetWidth, right: 'auto' });
					else // dir === bottom
						$el.css({ top: state.container.offsetHeight, bottom: 'auto' });
				}
				// restore the left/right setting if is a top/bottom animation
				if (ref === 'top')
					$el.css( $el.data( keyLR ) || {} );
			}
			else { // hide() animation, so save ALL CSS
				$el.data(keyTB, { top: s.top, bottom: s.bottom });
				$el.data(keyLR, { left: s.left, right: s.right });
			}

			// Animate
			$el.show().animate(animation, { queue: false, duration: o.duration, easing: opt.easing, complete: function(){
				// Restore top/bottom
				if ($el.data( keyTB ))
					$el.css($el.data( keyTB )).removeData( keyTB );
				if (show) // Restore left/right too
					$el.css($el.data( keyLR ) || {}).removeData( keyLR );
				else // Move the pane off-screen (left: -99999, right: 'auto')
					$el.css( offscrn );

				if (o.callback) o.callback.apply(this, arguments); // Callback
				$el.dequeue();
			}});
	
		});
	};

}

})( jQuery );