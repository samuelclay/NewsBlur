var loadImages = function() {
    
    $('.NB-story img, .NB-story video').each(function () {
        if ($(this).closest('.NB-twitter-rss-author,.NB-twitter-rss-retweet').length) return;
        setImage(this);
    });

    $('.NB-story img, .NB-story video').bind('load', function () {
        if ($(this).closest('.NB-twitter-rss-author,.NB-twitter-rss-retweet').length) return;
        setImage(this);
    });

};

var fitVideos = function() {
       $(".NB-story").fitVids({
            customSelector: "iframe[src*='youtu.be'],iframe[src*='flickr.com'],iframe[src*='vimeo.com']"
       });
};

var linkAt = function(x, y, attribute) {
    var el = document.elementFromPoint(x, y);
    return el && el[attribute];
};

$('a.NB-show-profile').live('click', function () {
    var offset = $('img', this).offset();
    console.log(offset);
    var url = $(this).attr('href') + "/" + offset.left + "/" + (offset.top - window.pageYOffset) + "/" + offset.width + "/" + offset.height;
    window.location = url;
    return false;
});

$('.NB-train-button a').live('click', function () {
    var offset = $(this).offset();
    console.log(offset);
    var url = $(this).attr('href') + "/" + offset.left + "/" + (offset.top - window.pageYOffset) + "/" + offset.width + "/" + offset.height;
    window.location = url;
    return false;
});

$('.NB-user-tag').live('click', function () {
    var offset = $(this).offset();
    console.log(['Offset', offset]);
    var url = $(this).attr('href') + "/" + offset.left + "/" + (offset.top - window.pageYOffset) + "/" + offset.width + "/" + offset.height;
    window.location = url;
    return false;
});

$('.NB-save-button').live('click', function () {
    var offset = $('a', this).offset();
    console.log(['Offset', offset]);
    var url = $('a', this).attr('href') + "/" + offset.left + "/" + (offset.top - window.pageYOffset) + "/" + offset.width + "/" + offset.height;
    window.location = url;
    return false;
});

$('.NB-button').live('touchstart', function () {
    $(this).addClass('active');
});

$('.NB-button').live('touchend', function (e) {
    $(this).removeClass('active');
});

function setImage(img) {
    var $img = $(img);
    var width = $(img).width();
    var height = $(img).height();
//    console.log("img load", img.src, width, height);
    if ($img.prop('tagName') == 'VIDEO') {
        $img.attr('class', 'NB-large-image');
    } else if ($img.attr('src').indexOf('feedburner') != - 1) {
        $img.attr('class', 'NB-feedburner');
    } else if (width >= (320-24) && height >= 50) {
        $img.attr('class', 'NB-large-image');
        if ($img.parent().attr('href')) {
            $img.parent().addClass('NB-contains-image')
        }
    } else if (width > 30 && height > 30) {
        $img.attr('class', 'NB-medium-image');
        if ($img.parent().attr('href')) {
            $img.parent().addClass('NB-contains-image')
        }
    } else {
        $img.attr('class', 'NB-small-image');
    }
}

function slideToComment(commentId, highlight) {
    setTimeout(function(){
        var commentString = 'NB-user-comment-' + commentId;
        var shareString = 'NB-user-share-bar-' + commentId;
        //Get comment
        var $comment = $('#' + commentString);
        if ($comment.length) {
            $.scroll($comment.offset().top - 32, 1000, 'ease-in-out');
        } else {
            var $shareBar = $('#' + shareString);
            if ($shareBar.length) {
                $.scroll($shareBar.offset().top - 32, 1000, 'ease-in-out');
            } else {
                var $shareButton =$("#NB-share-button-id");
                $.scroll($shareButton.offset().top - 32, 1000, 'ease-in-out');
            }
        }

        if (highlight) {
            if ($comment.length) {
                setTimeout(function(){
                           $comment.addClass('NB-highlighted');
                           setTimeout(function(){
                                      $comment.removeClass('NB-highlighted');
                                      }, 2000);
                           }, 1000);
            } else if ($shareBar.length) {

                setTimeout(function(){
                    $(".NB-story-comments-shares-teaser").addClass('NB-highlighted');
                    setTimeout(function(){
                        $(".NB-story-comments-shares-teaser").removeClass('NB-highlighted');
                    }, 2000);
                }, 1000);
            }
        }
    }, 500);
    
}
          
function findPos(obj) {
    var curtop = 0; 
    if (obj.offsetParent) {
        do {
            curtop += obj.offsetTop;
        } while (obj = obj.offsetParent);
        return [curtop];
    }
}

function NoClickDelay(el) {
    this.element = typeof el == 'object' ? el : document.getElementById(el);
    if( window.Touch ) {
        this.element.removeEventListener('touchstart', this.element.notouch, false);
        this.element.notouch = this;
        this.element.addEventListener('touchstart', this.element.notouch, false);
    }
}
NoClickDelay.prototype = {
handleEvent: function(e) {
    switch(e.type) {
        case 'touchstart': this.onTouchStart(e); break;
        case 'touchmove': this.onTouchMove(e); break;
        case 'touchend': this.onTouchEnd(e); break;
    }
},
onTouchStart: function(e) {
    e.preventDefault();
    this.moved = false;
    this.x = e.targetTouches[0].clientX;
    this.y = e.targetTouches[0].clientY;
    this.theTarget = document.elementFromPoint(e.targetTouches[0].clientX, e.targetTouches[0].clientY);
    this.theTarget = $(this.theTarget).closest('a').get(0);
//    if(this.theTarget.nodeType == 3) this.theTarget = theTarget.parentNode;
    this.theTarget.className+= ' pressed';
    this.element.addEventListener('touchmove', this, false);
    this.element.addEventListener('touchend', this, false);
},
onTouchMove: function(e) {
    var x = e.targetTouches[0].clientX;
    var y = e.targetTouches[0].clientY;
    if( Math.sqrt(Math.pow(x-this.x,2)+Math.pow(y-this.y,2))>50){
        this.moved = true;
        this.theTarget.className = this.theTarget.className.replace(/ ?pressed/gi, '');
        this.theTarget.className = this.theTarget.className.replace(/ ?active/gi, '');
    } else {
        if(this.moved==true){
            this.moved=false;
            this.theTarget.className+= ' pressed';
        }
    }
},
onTouchEnd: function(e) {
    this.element.removeEventListener('touchmove', this, false);
    this.element.removeEventListener('touchend', this, false);
    if( !this.moved && this.theTarget ) {
        this.theTarget.className = this.theTarget.className.replace(/ ?pressed/gi, '');
        this.theTarget.className+= ' active';
        var theEvent = document.createEvent('MouseEvents');
        theEvent.initEvent('click', true, true);
        this.theTarget.dispatchEvent(theEvent);
    }
    this.theTarget = undefined;
}
};

function attachFastClick() {
    var avatars = document.getElementsByClassName("NB-show-profile");
    Array.prototype.slice.call(avatars, 0).forEach(function(avatar) {
                                                   new NoClickDelay(avatar);
                                                   });
    var tags = document.getElementsByClassName("NB-story-tag");
    Array.prototype.slice.call(tags, 0).forEach(function(tag) {
                                                new NoClickDelay(tag);
                                                });
    var userTags = document.getElementsByClassName("NB-user-tag");
    Array.prototype.slice.call(userTags, 0).forEach(function(tag) {
                                                new NoClickDelay(tag);
                                                });
    
    var author = document.getElementById("NB-story-author");
    if (author) {
        new NoClickDelay(author);
    }
}

function notifyLoaded() {
    var url = "http://ios.newsblur.com/notify-loaded";
    window.location = url;
}

loadImages();
fitVideos();

Zepto(function($) {
      attachFastClick();
      if (!window.sampleText) {
        notifyLoaded();
      }
});
