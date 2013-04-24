
$.fn.extend({

    // Align an element relative to a target element's coordinates. Forces the
    // element to be absolutely positioned. Element must be visible.
    // Position string format is: "top -right".
    // You can pass an optional offset object with top and left offsets specified.
    align : function(target, pos, offset) {
        var el = this;
        pos = pos || '';
        offset = offset || {};
        var scrollTop = document.documentElement.scrollTop || document.body.scrollTop || 0;
        var scrollLeft = document.documentElement.scrollLeft || document.body.scrollLeft || 0;
        var clientWidth = document.documentElement.clientWidth;
        var clientHeight = document.documentElement.clientHeight;

        if (target == window) {
            var b = {
                left    : scrollLeft,
                top     : scrollTop,
                width   : $(window).width(),
                height  : $(window).height()
            };
        } else {
            target = $(target);
            var targOff = target.offset();
            var b = {
                left    : targOff.left,
                top     : targOff.top,
                width   : target.innerWidth(),
                height  : target.innerHeight()
            };
        }

        var elb = {
            width : el.innerWidth(),
            height : el.innerHeight()
        };

        var left, top;

        if (pos.indexOf('-left') >= 0) {
            left = b.left;
        } else if (pos.indexOf('left') >= 0) {
            left = b.left - elb.width;
        } else if (pos.indexOf('-right') >= 0) {
            left = b.left + b.width - elb.width;
        } else if (pos.indexOf('right') >= 0) {
            left = b.left + b.width;
        } else { // Centered.
            left = b.left + (b.width - elb.width) / 2;
        }

        if (pos.indexOf('-top') >= 0) {
            top = b.top;
        } else if (pos.indexOf('top') >= 0) {
            top = b.top - elb.height;
        } else if (pos.indexOf('-bottom') >= 0) {
            top = b.top + b.height - elb.height;
        } else if (pos.indexOf('bottom') >= 0) {
            top = b.top + b.height;
        } else { // Centered.
            top = b.top + (b.height - elb.height) / 2;
        }

        var constrain = (pos.indexOf('no-constraint') >= 0) ? false : true;

        left += offset.left || 0;
        top += offset.top || 0;

        if (constrain) {
            left = Math.max(scrollLeft, Math.min(left, scrollLeft + clientWidth - elb.width));
            top = Math.max(scrollTop, Math.min(top, scrollTop + clientHeight - elb.height));
        }

        // var offParent;
        // if (offParent = el.offsetParent()) {
        //   left -= offParent.offset().left;
        //   top -= offParent.offset().top;
        // }

        $(el).css({position : 'absolute', left : left + 'px', top : top + 'px'});
        return el;
    }

});
