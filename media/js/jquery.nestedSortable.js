$.fn.nestedSortable = function(options) {
 
  var settings = $.extend({
    nestable: 'li',
    container: 'ul',
    indent: 30,
    handle: null,
    opacity: 1,
    placeholderClass: 'placeholder',
    appendTo: 'parent',
    start: function() {},
    stop: function() {},
    drag: function() {}
  }, options);
  settings.snapTolerance = settings.indent * 0.4;
 
  this.each(function() {
 
    // The top level nestable list container
    var root = $(this);
 
    // Placed to preview the location of the dragged element
    var placeholder = $('<div class="' + settings.placeholderClass + '"></div>');
 
    // Use the onmouse over live event in order to bind to nestables as they are created
    root.find(settings.nestable).live("mouseover", function() {
      if (!$(this).data("nestable")) {
       
        $(this).draggable({
         
          opacity: settings.opacity,
          handle: settings.handle,
          appendTo: settings.appendTo,
 
          helper: function() {
            // Create a helper that is a clone of the original (with a few little tweaks)
            return $(this).clone().width($(this).width()).addClass("helper");
          },
 
          start: function() {
            // Hide the original and initialize the placeholder ontop of the starting position
            $(this).hide().after(placeholder);
            // Run a custom start function specitifed in the settings
            settings.start.apply(this);
          },
 
          stop: function(event, ui) {
            // Replace the placeholder with the original
            placeholder.after($(this).show()).remove();
            // Run a custom stop function specitifed in the settings
            settings.stop.apply(this);
          },
 
          drag: function (event, ui) {
            // Find the nestable item underneath the helper being dragged
            var largestY = 0;
            var underItems = $.grep(root.find(settings.nestable), function(item) {
              // Is the item being checked underneath the one being dragged?
              if(!(($(item).offset().top < ui.position.top) && ($(item).offset().top > largestY))) {
                return false;
              }
              // Is the item being checked on the same nesting level as the dragged item?
              if ($(item).offset().left - settings.snapTolerance >= ui.position.left) {
                return false;
              }
              // Make sure the itme being checked is not part of the helper
              if (ui.helper.find($(item)).length) {
                return false;
              }
              // If we've got this far, its a match
              largestY = $(item).offset().top;
              return true;
            });
            var underItem = underItems.length ? $(underItems.pop()) : null;
 
            // Position the placeholder if appropriate
            if (underItem !== null) {
              // Should the dragged item be nested
              if (underItem.offset().left + settings.indent – settings.snapTolerance < ui.position.left) {
                underItem.children(settings.container).prepend(placeholder);
              } else  {
                underItem.after(placeholder);
              }
            // If there is no item underneath, it still might be over the very first list item
            } else {
              var firstItem = root.find(settings.nestable + ":first");
              if ((firstItem.offset().top < ui.position.top + $(this).height()) && (firstItem.offset().top > ui.position.top)) {
                firstItem.closest(settings.container).prepend(placeholder);
              }
            }
            // Run a custom drag function specitifed in the settings
            settings.drag.apply(this);
          }
        }).data("nestable", true);
      }
    });
  });
  return this;
};