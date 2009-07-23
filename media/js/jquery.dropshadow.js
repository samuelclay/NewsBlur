/*
	VERSION: Drop Shadow jQuery Plugin 1.6  12-13-2007

	REQUIRES: jquery.js (1.2.6 or later)

	SYNTAX: $(selector).dropShadow(options);  // Creates new drop shadows
					$(selector).redrawShadow();       // Redraws shadows on elements
					$(selector).removeShadow();       // Removes shadows from elements
					$(selector).shadowId();           // Returns an existing shadow's ID

	OPTIONS:

		left    : integer (default = 4)
		top     : integer (default = 4)
		blur    : integer (default = 2)
		opacity : decimal (default = 0.5)
		color   : string (default = "black")
		swap    : boolean (default = false)

	The left and top parameters specify the distance and direction, in	pixels, to
	offset the shadow. Zero values position the shadow directly behind the element.
	Positive values shift the shadow to the right and down, while negative values 
	shift the shadow to the left and up.
	
	The blur parameter specifies the spread, or dispersion, of the shadow. Zero 
	produces a sharp shadow, one or two produces a normal shadow, and	three or four
	produces a softer shadow. Higher values increase the processing load.
	
	The opacity parameter	should be a decimal value, usually less than one. You can
	use a value	higher than one in special situations, e.g. with extreme blurring. 
	
	Color is specified in the usual manner, with a color name or hex value. The
	color parameter	does not apply with transparent images.
	
	The swap parameter reverses the stacking order of the original and the shadow.
	This can be used for special effects, like an embossed or engraved look.

	EXPLANATION:
	
	This jQuery plug-in adds soft drop shadows behind page elements. It is only
	intended for adding a few drop shadows to mostly stationary objects, like a
	page heading, a photo, or content containers.

	The shadows it creates are not bound to the original elements, so they won't
	move or change size automatically if the original elements change. A window
	resize event listener is assigned, which should re-align the shadows in many
	cases, but if the elements otherwise move or resize you will have to handle
	those events manually. Shadows can be redrawn with the redrawShadow() method
	or removed with the removeShadow() method. The redrawShadow() method uses the
	same options used to create the original shadow. If you want to change the
	options, you should remove the shadow first and then create a new shadow.
	
	The dropShadow method returns a jQuery collection of the new shadow(s). If
	further manipulation is required, you can store it in a variable like this:

		var myShadow = $("#myElement").dropShadow();

	You can also read the ID of the shadow from the original element at a later
	time. To get a shadow's ID, either read the shadowId attribute of the
	original element or call the shadowId() method. For example:

		var myShadowId = $("#myElement").attr("shadowId");  or
		var myShadowId = $("#myElement").shadowId();

	If the original element does not already have an ID assigned, a random ID will
	be generated for the shadow. However, if the original does have an ID, the 
	shadow's ID will be the original ID and "_dropShadow". For example, if the
	element's ID is "myElement", the shadow's ID would be "myElement_dropShadow".

	If you have a long piece of text and the user resizes the	window so that the
	text wraps or unwraps, the shape of the text changes and the words are no
	longer in the same positions. In that case, you can either preset the height
	and width, so that it becomes a fixed box, or you can shadow each word
	separately, like this:

		<h1><span>Your</span> <span>Page</span> <span>Title</span></h1>

		$("h1 span").dropShadow();

	The dropShadow method attempts to determine whether the selected elements have
	transparent backgrounds. If you want to shadow the content inside an element,
	like text or a transparent image, it must not have a background-color or
	background-image style. If the element has a solid background it will create a
	rectangular	shadow around the outside box.

	The shadow elements are positioned absolutely one layer below the original 
	element, which is positioned relatively (unless it's already absolute).

	*** All shadows have the "dropShadow" class, for selecting with CSS or jQuery.

	ISSUES:
	
		1)	Limited styling of shadowed elements by ID. Because IDs must be unique,
				and the shadows have their own ID, styles applied by ID won't transfer
				to the shadows. Instead, style elements by class or use inline styles.
		2)	Sometimes shadows don't align properly. Elements may need to be wrapped
				in container elements, margins or floats changed, etc. or you may just 
				have to tweak the left and top offsets to get them to align. For example,
				with draggable objects, you have to wrap them inside two divs. Make the 
				outer div draggable and set the inner div's position to relative. Then 
				you can create a shadow on the element inside the inner div.
		3)	If the user changes font sizes it will throw the shadows off. Browsers 
				do not expose an event for font size changes. The only known way to 
				detect a user font size change is to embed an invisible text element and
				then continuously poll for changes in size.
		4)	Safari support is shaky, and may require even more tweaks/wrappers, etc.
		
		The bottom line is that this is a gimick effect, not PFM, and if you push it
		too hard or expect it to work in every possible situation on every browser,
		you will be disappointed. Use it sparingly, and don't use it for anything 
		critical. Otherwise, have fun with it!
				
	AUTHOR: Larry Stevens (McLars@eyebulb.com) This work is in the public domain,
					and it is not supported in any way. Use it at your own risk.
*/


(function($){

	var dropShadowZindex = 1;  //z-index counter

	$.fn.dropShadow = function(options)
	{
		// Default options
		var opt = $.extend({
			left: 4,
			top: 4,
			blur: 2,
			opacity: .5,
			color: "black",
			swap: false
			}, options);
		var jShadows = $([]);  //empty jQuery collection
		
		// Loop through original elements
		this.not(".dropShadow").each(function()
		{
			var jthis = $(this);
			var shadows = [];
			var blur = (opt.blur <= 0) ? 0 : opt.blur;
			var opacity = (blur == 0) ? opt.opacity : opt.opacity / (blur * 8);
			var zOriginal = (opt.swap) ? dropShadowZindex : dropShadowZindex + 1;
			var zShadow = (opt.swap) ? dropShadowZindex + 1 : dropShadowZindex;
			
			// Create ID for shadow
			var shadowId;
			if (this.id) {
				shadowId = this.id + "_dropShadow";
			}
			else {
				shadowId = "ds" + (1 + Math.floor(9999 * Math.random()));
			}

			// Modify original element
			$.data(this, "shadowId", shadowId); //store id in expando
			$.data(this, "shadowOptions", options); //store options in expando
			jthis
				.attr("shadowId", shadowId)
				.css("zIndex", zOriginal);
			if (jthis.css("position") != "absolute") {
				jthis.css({
					position: "relative",
					zoom: 1 //for IE layout
				});
			}

			// Create first shadow layer
			bgColor = jthis.css("backgroundColor");
			if (bgColor == "rgba(0, 0, 0, 0)") bgColor = "transparent";  //Safari
			if (bgColor != "transparent" || jthis.css("backgroundImage") != "none" 
					|| this.nodeName == "SELECT" 
					|| this.nodeName == "INPUT"
					|| this.nodeName == "TEXTAREA") {		
				shadows[0] = $("<div></div>")
					.css("background", opt.color);								
			}
			else {
				shadows[0] = jthis
					.clone()
					.removeAttr("id")
					.removeAttr("name")
					.removeAttr("shadowId")
					.css("color", opt.color);
			}
			shadows[0]
				.addClass("dropShadow")
				.css({
					height: jthis.outerHeight(),
					left: blur,
					opacity: opacity,
					position: "absolute",
					top: blur,
					width: jthis.outerWidth(),
					zIndex: zShadow
				});
				
			// Create other shadow layers
			var layers = (8 * blur) + 1;
			for (i = 1; i < layers; i++) {
				shadows[i] = shadows[0].clone();
			}

			// Position layers
			var i = 1;			
			var j = blur;
			while (j > 0) {
				shadows[i].css({left: j * 2, top: 0});           //top
				shadows[i + 1].css({left: j * 4, top: j * 2});   //right
				shadows[i + 2].css({left: j * 2, top: j * 4});   //bottom
				shadows[i + 3].css({left: 0, top: j * 2});       //left
				shadows[i + 4].css({left: j * 3, top: j});       //top-right
				shadows[i + 5].css({left: j * 3, top: j * 3});   //bottom-right
				shadows[i + 6].css({left: j, top: j * 3});       //bottom-left
				shadows[i + 7].css({left: j, top: j});           //top-left
				i += 8;
				j--;
			}

			// Create container
			var divShadow = $("<div></div>")
				.attr("id", shadowId) 
				.addClass("dropShadow")
				.css({
					left: jthis.position().left + opt.left - blur,
					marginTop: jthis.css("marginTop"),
					marginRight: jthis.css("marginRight"),
					marginBottom: jthis.css("marginBottom"),
					marginLeft: jthis.css("marginLeft"),
					position: "absolute",
					top: jthis.position().top + opt.top - blur,
					zIndex: zShadow
				});

			// Add layers to container	
			for (i = 0; i < layers; i++) {
				divShadow.append(shadows[i]);
			}
			
			// Add container to DOM
			jthis.after(divShadow);

			// Add shadow to return set
			jShadows = jShadows.add(divShadow);

			// Re-align shadow on window resize
			$(window).resize(function()
			{
				try {
					divShadow.css({
						left: jthis.position().left + opt.left - blur,
						top: jthis.position().top + opt.top - blur
					});
				}
				catch(e){}
			});
			
			// Increment z-index counter
			dropShadowZindex += 2;

		});  //end each
		
		return this.pushStack(jShadows);
	};


	$.fn.redrawShadow = function()
	{
		// Remove existing shadows
		this.removeShadow();
		
		// Draw new shadows
		return this.each(function()
		{
			var shadowOptions = $.data(this, "shadowOptions");
			$(this).dropShadow(shadowOptions);
		});
	};


	$.fn.removeShadow = function()
	{
		return this.each(function()
		{
			var shadowId = $(this).shadowId();
			$("div#" + shadowId).remove();
		});
	};


	$.fn.shadowId = function()
	{
		return $.data(this[0], "shadowId");
	};


	$(function()  
	{
		// Suppress printing of shadows
		var noPrint = "<style type='text/css' media='print'>";
		noPrint += ".dropShadow{visibility:hidden;}</style>";
		$("head").append(noPrint);
	});

})(jQuery);