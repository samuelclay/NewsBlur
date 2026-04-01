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

$('.NB-read-button a').live('click', function () {
    var offset = $(this).offset();
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

$('.NB-share-share-button').live('click', function () {
    var offset = $('a', this).offset();
    var url = $('a', this).attr('href') + "/" + offset.left + "/" + (offset.top - window.pageYOffset) + "/" + offset.width + "/" + offset.height;
    window.location = url;
    return false;
});

$('.NB-ask-ai-button').live('click', function () {
    var offset = $('a', this).offset();
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

function scoreIconHtml(score) {
    var thumbsUp = "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB3aWR0aD0iMTUwcHgiIGhlaWdodD0iMTUwcHgiIHZpZXdCb3g9IjAgMCAxNTAgMTUwIiB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgogICAgPHRpdGxlPnRodW1icy11cDwvdGl0bGU+CiAgICA8ZyBpZD0idGh1bWJzLXVwIiBzdHJva2U9Im5vbmUiIHN0cm9rZS13aWR0aD0iMSIgZmlsbD0ibm9uZSIgZmlsbC1ydWxlPSJldmVub2RkIj4KICAgICAgICA8ZyBpZD0ibm91bi10aHVtYnMtdXAtMjAwMzU5Mi05NTk3OEUiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDkuNzgyNiwgMTguNDc4MykiIGZpbGw9IiNGRkMwMjEiPgogICAgICAgICAgICA8cGF0aCBkPSJNNDguMDg0NjQ3OCw0MC40NjU3MDMzIEw0OC4wODQ2NDc4LDEwNy42Nzg5NTkgQzUyLjMwNzMwOTEsMTEwLjY1NjE5NiA1NS4wNDMwOTk1LDExMy4wNDM0NzggNjEuMTA5OTk0MSwxMTMuMDQzNDc4IEwxMTAuODI2NDI2LDExMy4wNDM0NzggQzEyMC43MDMzNzMsMTEzLjA0MzQ3OCAxMjcuMzU1Nzk0LDEwNS41NTM3OTkgMTI0Ljc2NDIxLDk3Ljg3MDcwNzQgQzEyOS42MzI2NDcsOTMuMDM3NDExNSAxMzAuODYwMzU5LDg3LjQxMDUwMzcgMTI3Ljg3ODEzNSw4MS42MDgxMTExIEMxMzIuMzgxMTYxLDc1LjUzOTc5NzYgMTMyLjk5Mjg5Nyw2OS4wMzcxNDM3IDEyOC4xMTYwMzIsNjIuOTY4OTE4NSBDMTM1LjQxNDMzNyw1MS43MzI0MTMgMTI4Ljc0NDc1NSwzOC43MjMzOTU4IDExMi41MDQ1MzksMzguNzIzMzk1OCBMOTIuNjQ0MDY3MiwzOC43MjMzOTU4IEM5Mi42NjUzMDc3LDMwLjc5MjEzNDUgOTIuMTQ3MDMzMywxNy44MzQ3ODI1IDg4Ljc3Mzk4MywxMC41MjA0MTE4IEM4MS44NzQ5MTA1LC00LjQ0MTI4MjcyIDYwLjI3NzQzNTUsLTIuNjc0OTUzMTYgNjAuOTUyNzkxNiwxMC45NTUwOTY3IEM2MC4zMzY4MDM4LDIxLjY4NzMxNTEgNTcuMTkzMjAwNiwzMi4zNDc5OTcxIDQ4LjA4NDY0NzgsNDAuNDY1MTY0NiBNMCwzOC45NzgyNjgzIEwwLDExMy4wNDMxMTYgTDQwLjE3NDQ0NDIsMTEzLjA0MzExNiBMNDAuMTc0NDQ0MiwzOC45NzgyNjgzIEwwLDM4Ljk3ODI2ODMgWiIgaWQ9IlNoYXBlIj48L3BhdGg+CiAgICAgICAgPC9nPgogICAgPC9nPgo8L3N2Zz4=";
    var thumbsDown = "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB3aWR0aD0iMTUwcHgiIGhlaWdodD0iMTUwcHgiIHZpZXdCb3g9IjAgMCAxNTAgMTUwIiB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgogICAgPHRpdGxlPnRodW1icy1kb3duPC90aXRsZT4KICAgIDxnIGlkPSJ0aHVtYnMtZG93biIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjEiIGZpbGw9Im5vbmUiIGZpbGwtcnVsZT0iZXZlbm9kZCI+CiAgICAgICAgPGcgaWQ9Im5vdW4tdGh1bWJzLXVwLTIwMDM1OTItOTU5NzhFIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSg3NS41NDM1LCA3NSkgcm90YXRlKC0xODApIHRyYW5zbGF0ZSgtNzUuNTQzNSwgLTc1KXRyYW5zbGF0ZSg5Ljc4MjYsIDE4LjQ3ODMpIiBmaWxsPSIjRkZDMDIxIj4KICAgICAgICAgICAgPHBhdGggZD0iTTQ4LjA4NDY0NzgsNDAuNDY1NzAzMyBMNDguMDg0NjQ3OCwxMDcuNjc4OTU5IEM1Mi4zMDczMDkxLDExMC42NTYxOTYgNTUuMDQzMDk5NSwxMTMuMDQzNDc4IDYxLjEwOTk5NDEsMTEzLjA0MzQ3OCBMMTEwLjgyNjQyNiwxMTMuMDQzNDc4IEMxMjAuNzAzMzczLDExMy4wNDM0NzggMTI3LjM1NTc5NCwxMDUuNTUzNzk5IDEyNC43NjQyMSw5Ny44NzA3MDc0IEMxMjkuNjMyNjQ3LDkzLjAzNzQxMTUgMTMwLjg2MDM1OSw4Ny40MTA1MDM3IDEyNy44NzgxMzUsODEuNjA4MTExMSBDMTMyLjM4MTE2MSw3NS41Mzk3OTc2IDEzMi45OTI4OTcsNjkuMDM3MTQzNyAxMjguMTE2MDMyLDYyLjk2ODkxODUgQzEzNS40MTQzMzcsNTEuNzMyNDEzIDEyOC43NDQ3NTUsMzguNzIzMzk1OCAxMTIuNTA0NTM5LDM4LjcyMzM5NTggTDkyLjY0NDA2NzIsMzguNzIzMzk1OCBDOTIuNjY1MzA3NywzMC43OTIxMzQ1IDkyLjE0NzAzMzMsMTcuODM0NzgyNSA4OC43NzM5ODMsMTAuNTIwNDExOCBDODEuODc0OTEwNSwtNC40NDEyODI3MiA2MC4yNzc0MzU1LC0yLjY3NDk1MzE2IDYwLjk1Mjc5MTYsMTAuOTU1MDk2NyBDNjAuMzM2ODAzOCwyMS42ODczMTUxIDU3LjE5MzIwMDYsMzIuMzQ3OTk3MSA0OC4wODQ2NDc4LDQwLjQ2NTE2NDYgTS0yLjkzMzE1OTUzZS0xNCwzOC45NzgyNjgzIEwtMi45MzMxNTk1M2UtMTQsMTEzLjA0MzExNiBMNDAuMTc0NDQ0MiwxMTMuMDQzMTE2IEw0MC4xNzQ0NDQyLDM4Ljk3ODI2ODMgTC0yLjkzMzE1OTUzZS0xNCwzOC45NzgyNjgzIFoiIGlkPSJTaGFwZSI+PC9wYXRoPgogICAgICAgIDwvZz4KICAgIDwvZz4KPC9zdmc+";
    if (score >= 1) {
        return '<img src="' + thumbsUp + '" class="NB-score-icon NB-score-icon-like" />';
    } else if (score <= -2) {
        return '<span class="NB-score-icon-double"><img src="' + thumbsDown + '" class="NB-score-icon NB-score-icon-super-dislike NB-score-icon-super-dislike-back" /><img src="' + thumbsDown + '" class="NB-score-icon NB-score-icon-super-dislike" /></span>';
    } else if (score <= -1) {
        return '<img src="' + thumbsDown + '" class="NB-score-icon NB-score-icon-dislike" />';
    }
    return '';
}

function applyClassifierHighlights(classifiers) {
    try {
        if (!classifiers) return;
        if (typeof Mark === 'undefined') return;
        var container = document.getElementById('NB-story');
        if (!container) return;

        var instance = new Mark(container);
        instance.unmark({
            done: function () {
                var texts = classifiers.texts || {};
                var textRegex = classifiers.text_regex || {};

                Object.keys(texts).forEach(function (classifierText) {
                    var score = texts[classifierText];
                    var className = score > 0 ? "NB-classifier-highlight-positive" : (score <= -2 ? "NB-classifier-highlight-super-negative" : "NB-classifier-highlight-negative");
                    var iconHtml = scoreIconHtml(score);
                    instance.mark(classifierText, {
                        className: className,
                        separateWordSearch: false,
                        acrossElements: true,
                        caseSensitive: false,
                        each: function (element) {
                            if (iconHtml) {
                                element.insertAdjacentHTML('beforeend', iconHtml);
                            }
                        }
                    });
                });

                Object.keys(textRegex).forEach(function (pattern) {
                    try {
                        var score = textRegex[pattern];
                        var className = score > 0 ? "NB-classifier-highlight-positive" : (score <= -2 ? "NB-classifier-highlight-super-negative" : "NB-classifier-highlight-negative");
                        var iconHtml = scoreIconHtml(score);
                        var regex = new RegExp(pattern, 'gi');
                        instance.markRegExp(regex, {
                            className: className,
                            acrossElements: true,
                            each: function (element) {
                                if (iconHtml) {
                                    element.insertAdjacentHTML('beforeend', iconHtml);
                                }
                            }
                        });
                    } catch (e) {
                        // Invalid regex pattern, skip
                    }
                });
            }
        });
    } catch (e) {
        // ignore highlight errors
    }
}

loadImages();
fitVideos();

Zepto(function($) {
      attachFastClick();
      if (!window.sampleText) {
        notifyLoaded();
      }
});
