// StoryDetailObjCViewController.m must receive readiness even if optional media or touch setup fails.
function notifyStoryDOMReady() {
    if (!window.sampleText) {
        notifyLoaded();
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', notifyStoryDOMReady, { once: true });
} else {
    setTimeout(notifyStoryDOMReady, 0);
}

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

// StoryImageViewerController.swift converts document coordinates through the native scroll offset.
var newsblur_image_sequence = 0;
function newsblurImageRect(token, load_id) {
    var load = document.querySelector('meta[name="newsblur-story-load"]');
    if (!load || load.content !== load_id) return null;
    var image = document.querySelector('img[data-newsblur-image-token="' + token + '"]');
    if (!image) return null;
    var rect = image.getBoundingClientRect();
    return {x: rect.left + window.scrollX, y: rect.top + window.scrollY, width: rect.width, height: rect.height,
            viewportWidth: window.innerWidth};
}

function newsblurIsStoryImage(image) {
    return image && image.tagName === 'IMG' && image.closest('.NB-story') &&
        image.complete && image.naturalWidth > 1 && image.naturalHeight > 1;
}

function newsblurOpenImage(image, accessibility_activation, show_actions) {
    var bridge = window.webkit && window.webkit.messageHandlers.newsblurStoryImage;
    var load = document.querySelector('meta[name="newsblur-story-load"]');
    if (!bridge || !load || !newsblurIsStoryImage(image)) return false;
    var token = image.getAttribute('data-newsblur-image-token');
    if (!token) {
        token = String(++newsblur_image_sequence);
        image.setAttribute('data-newsblur-image-token', token);
    }
    var link = image.closest('a[href]');
    bridge.postMessage({loadID: load.content, token: token,
        accessibilityActivation: accessibility_activation === true,
        showActions: show_actions === true,
        src: image.currentSrc || image.src,
        originalURL: image.getAttribute('data-newsblur-original-src') || image.currentSrc || image.src,
        link: link ? link.href : '', title: image.alt || image.title || 'Story image',
        hoverText: image.title || '',
        naturalWidth: image.naturalWidth, naturalHeight: image.naturalHeight,
        rect: newsblurImageRect(token, load.content)});
    return true;
}

function newsblurOpenImageAt(x, y, offset_x, offset_y, view_width, show_actions) {
    var scale = window.innerWidth / view_width;
    return newsblurOpenImage(document.elementFromPoint(
        (x + offset_x) * scale - window.scrollX,
        (y + offset_y) * scale - window.scrollY), false, show_actions);
}

document.addEventListener('click', function(event) {
    if (newsblurIsStoryImage(event.target)) {
        event.preventDefault();
        event.stopImmediatePropagation();
        // StoryDetailObjCViewController.m owns pointer taps after scroll and double-tap recognition.
        if (event.detail === 0) newsblurOpenImage(event.target, true);
    }
}, true);

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

// storyDetailView.js: the Listen button holds Listen itself and, while another story plays, the + for Up Next.
$('.NB-listen-button').live('click', function (e) {
    var link = $(e.target).closest('a');
    if (!link.length) link = $('a', this).first();
    window.location = link.attr('href');
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
    var width = img.naturalWidth || $(img).width();
    var height = img.naturalHeight || $(img).height();
//    console.log("img load", img.src, width, height, img.naturalWidth, img.naturalHeight);
    if ($img.prop('tagName') == 'VIDEO') {
        $img.attr('class', 'NB-large-image');
    } else if (($img.attr('src') || '').indexOf('feedburner') != - 1) {
        $img.attr('class', 'NB-feedburner');
    } else if (width >= 300 && height >= 50) {
        $img.attr('class', 'NB-large-image');
        if ($img.parent().attr('href')) {
            $img.parent().addClass('NB-contains-image')
        }
    } else if (width >= 300 && height > 30) {
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
    var load = document.querySelector('meta[name="newsblur-story-load"]');
    if (load && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.newsblurStoryReady) {
        window.webkit.messageHandlers.newsblurStoryReady.postMessage(load.getAttribute("content"));
    }
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

        // Strip any score icons left over from a previous run. Mark.js's unmark() only
        // unwraps the <mark> element — icons that were inserted inside it become
        // orphaned siblings in the text flow, and the next mark() would append a
        // fresh icon on top of them, stacking multiple thumbs for the same match.
        if (container.querySelectorAll) {
            var staleIcons = container.querySelectorAll('.NB-score-icon, .NB-score-icon-double');
            for (var i = 0; i < staleIcons.length; i++) {
                var icon = staleIcons[i];
                if (icon && icon.parentNode) {
                    icon.parentNode.removeChild(icon);
                }
            }
        }

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

// storyDetailView.js follow-along for Listen (Classes/Listen/ListenStoryBridge.swift). Blocks are found the way
// apps/listen/text.py finds paragraphs, and each server paragraph is matched to the next block that starts with
// the same 40 characters.
var NEWSBLUR_LISTEN_BLOCKS = {p: 1, h1: 1, h2: 1, h3: 1, h4: 1, h5: 1, h6: 1, li: 1, blockquote: 1, dd: 1, dt: 1};
var NEWSBLUR_LISTEN_CONTAINERS = {div: 1, section: 1, article: 1, main: 1, header: 1, ul: 1, ol: 1, dl: 1,
    center: 1, details: 1, summary: 1};
var NEWSBLUR_LISTEN_SKIP = {script: 1, style: 1, noscript: 1, svg: 1, canvas: 1, iframe: 1, pre: 1, table: 1,
    figure: 1, figcaption: 1, audio: 1, video: 1, object: 1, embed: 1, form: 1, button: 1, nav: 1, aside: 1,
    footer: 1, img: 1, picture: 1, select: 1, textarea: 1};
var NEWSBLUR_LISTEN_BLOCK_SELECTOR = 'p,h1,h2,h3,h4,h5,h6,li,blockquote,dd,dt,div,section,article,main,header,ul,ol,dl,center,details,summary';
var newsblur_listen = {elements: {}, last_user_scroll: 0, mini_player: false};
var NEWSBLUR_LISTEN_NOT_PROSE = /caption|credit|gallery/i;
var NEWSBLUR_LISTEN_MAX_CAPTION_CHARACTERS = 1000;

// Mirrors apps/listen/text.py _is_skipped: skip tags, aria-hidden decoration, and short elements whose class or
// id marks them as image captions, credits or galleries (a long one is an article wrapper, which is read).
function newsblurListenIsSkipped(element) {
    var tag = element.tagName.toLowerCase();
    if (NEWSBLUR_LISTEN_SKIP[tag] || element.getAttribute('aria-hidden') === 'true') return true;
    var marker = (element.getAttribute('class') || '') + ' ' + (element.getAttribute('id') || '');
    if (!NEWSBLUR_LISTEN_NOT_PROSE.test(marker)) return false;
    return (element.textContent || '').length < NEWSBLUR_LISTEN_MAX_CAPTION_CHARACTERS;
}

// A tap isn't scrolling; only drags and wheel scrolls hold off the follow-along scroll.
['touchmove', 'wheel'].forEach(function (type) {
    window.addEventListener(type, function () {
        newsblur_listen.last_user_scroll = Date.now();
    }, {passive: true});
});

function newsblurListenNormalize(text) {
    return (text || '').replace(/\s+/g, ' ').trim();
}

function newsblurListenKey(text) {
    return newsblurListenNormalize(text).substring(0, 40).toLowerCase();
}

function newsblurListenText(node) {
    if (node.nodeType === 3) return node.nodeValue;
    if (node.nodeType !== 1) return '';
    if (node.tagName.toLowerCase() === 'br') return ' ';
    if (newsblurListenIsSkipped(node)) return '';
    var pieces = [];
    for (var child = node.firstChild; child; child = child.nextSibling) {
        pieces.push(newsblurListenText(child));
    }
    return pieces.join('');
}

function newsblurListenIsContainer(element) {
    var tag = element.tagName.toLowerCase();
    return NEWSBLUR_LISTEN_BLOCKS[tag] || NEWSBLUR_LISTEN_CONTAINERS[tag] ||
        !!element.querySelector(NEWSBLUR_LISTEN_BLOCK_SELECTOR);
}

function newsblurListenCollect(container, blocks) {
    var run = [];
    var flush = function () {
        var text = newsblurListenNormalize(run.map(newsblurListenText).join(''));
        if (text && /\p{L}/u.test(text)) {
            var element;
            var elements = run.filter(function (node) { return node.nodeType === 1; });
            // A skipped block, like a captioned figure, keeps its place: the span covers the first stretch of
            // text beside it rather than wrapping the block.
            var chunks = [[]];
            run.forEach(function (node) {
                if (node.nodeType === 1 && newsblurListenIsSkipped(node) &&
                    window.getComputedStyle(node).display.indexOf('inline') !== 0) {
                    chunks.push([]);
                } else {
                    chunks[chunks.length - 1].push(node);
                }
            });
            var wrapped = chunks.filter(function (chunk) {
                return newsblurListenNormalize(chunk.map(newsblurListenText).join(''));
            })[0];
            if (!wrapped) {
                run = [];
                return;
            }
            if (wrapped.length === 1 && wrapped[0].nodeType === 1 && elements.length === 1) {
                element = wrapped[0];
            } else {
                // Loose text beside blocks gets its own span so just that run highlights.
                element = document.createElement('span');
                element.className = 'NB-listen-run';
                container.insertBefore(element, wrapped[0]);
                wrapped.forEach(function (node) { element.appendChild(node); });
            }
            blocks.push({element: element, text: text});
        }
        run = [];
    };
    Array.prototype.slice.call(container.childNodes).forEach(function (child) {
        if (child.nodeType === 3) {
            run.push(child);
            return;
        }
        if (child.nodeType !== 1) return;
        var tag = child.tagName.toLowerCase();
        if (tag === 'br' || newsblurListenIsSkipped(child)) {
            run.push(child);
        } else if (NEWSBLUR_LISTEN_BLOCKS[tag] && !child.querySelector(NEWSBLUR_LISTEN_BLOCK_SELECTOR)) {
            flush();
            blocks.push({element: child, text: newsblurListenNormalize(newsblurListenText(child))});
        } else if (newsblurListenIsContainer(child)) {
            flush();
            newsblurListenCollect(child, blocks);
        } else {
            run.push(child);
        }
    });
    flush();
}

function newsblurListenElement(index) {
    var element = newsblur_listen.elements[index];
    if (element === 'title') return document.querySelector('#NB-header-container .NB-story-title');
    return element && element.isConnected ? element : null;
}

function newsblurListenClearHighlight() {
    var highlighted = document.querySelectorAll('.NB-listen-highlight');
    for (var i = 0; i < highlighted.length; i++) {
        highlighted[i].classList.remove('NB-listen-highlight');
    }
}

function newsblurListenClear() {
    newsblurListenClearHighlight();
    var mapped = document.querySelectorAll('[data-nb-listen-index]');
    for (var i = 0; i < mapped.length; i++) {
        mapped[i].removeAttribute('data-nb-listen-index');
    }
    newsblur_listen.elements = {};
    document.body.classList.remove('NB-listen-active');
    return true;
}

function newsblurListenPrepare(paragraphs) {
    newsblurListenClear();
    var story = document.getElementById('NB-story');
    if (!story) return 0;
    var blocks = [];
    newsblurListenCollect(story, blocks);
    var cursor = 0;
    var matched = 0;
    paragraphs.forEach(function (paragraph) {
        if (paragraph.kind === 'title') {
            newsblur_listen.elements[paragraph.index] = 'title';
            matched += 1;
            return;
        }
        var key = newsblurListenKey(paragraph.text);
        if (!key) return;
        for (var i = cursor; i < blocks.length; i++) {
            if (newsblurListenKey(blocks[i].text) === key) {
                newsblur_listen.elements[paragraph.index] = blocks[i].element;
                blocks[i].element.setAttribute('data-nb-listen-index', paragraph.index);
                cursor = i + 1;
                matched += 1;
                return;
            }
        }
    });
    document.body.classList.add('NB-listen-active');
    return matched;
}

function newsblurListenScrollTo(element) {
    var rect = element.getBoundingClientRect();
    var view = window.innerHeight;
    var top_margin = 90;
    var bottom_margin = newsblur_listen.mini_player ? 170 : 110;
    if (rect.top >= top_margin && rect.bottom <= view - bottom_margin) return;
    // A tall paragraph that has already started on screen stays where it is.
    if (rect.top >= top_margin && rect.top < view - bottom_margin && rect.height > view - top_margin - bottom_margin) return;
    window.scrollTo({top: Math.max(0, window.scrollY + rect.top - view * 0.25), behavior: 'smooth'});
}

function newsblurListenHighlight(indices, scroll) {
    newsblurListenClearHighlight();
    var first = null;
    indices.forEach(function (index) {
        var element = newsblurListenElement(index);
        if (!element) return;
        element.classList.add('NB-listen-highlight');
        if (!first) first = element;
    });
    // Leave the page alone while the reader is scrolling it themselves.
    if (scroll && first && Date.now() - newsblur_listen.last_user_scroll > 2500) {
        newsblurListenScrollTo(first);
    }
    return !!first;
}

function newsblurListenIndexAt(x, y, offset_x, offset_y, view_width) {
    var scale = window.innerWidth / view_width;
    var element = document.elementFromPoint((x + offset_x) * scale - window.scrollX,
                                            (y + offset_y) * scale - window.scrollY);
    if (!element || element.closest('a[href], img, video, iframe, .NB-sideoptions, .NB-button')) return -1;
    var block = element.closest('[data-nb-listen-index]');
    if (block) return parseInt(block.getAttribute('data-nb-listen-index'), 10);
    if (newsblur_listen.elements[0] === 'title' && element.closest('#NB-header-container .NB-story-title')) return 0;
    return -1;
}

function newsblurListenSetMiniPlayer(shown) {
    newsblur_listen.mini_player = !!shown;
    document.body.classList.toggle('NB-listen-mini-player', !!shown);
    return true;
}

// storyDetailView.js: a narrow Listen button drops its "30s preview" pill before its label gets cut off. It
// measures rather than using a width breakpoint because the label and pill change length with the language.
function newsblurListenFitPill() {
    var buttons = document.querySelectorAll('.NB-listen-has-pill');
    for (var i = 0; i < buttons.length; i++) {
        var button = buttons[i];
        button.classList.remove('NB-listen-pill-hidden');
        var label = button.querySelector('.NB-sideoption-text');
        if (label && label.scrollWidth > label.clientWidth + 1) {
            button.classList.add('NB-listen-pill-hidden');
        }
    }
}

// StoryDetailObjCViewController.m refreshSideOptions replaces the buttons' HTML, so the new Listen button is
// watched again whenever the container's children change.
function newsblurListenWatchPill() {
    var container = document.getElementById('NB-sideoptions-container');
    if (!container || typeof ResizeObserver !== 'function') return;
    var resize_observer = new ResizeObserver(newsblurListenFitPill);
    var observe_buttons = function () {
        resize_observer.disconnect();
        var buttons = container.querySelectorAll('.NB-listen-has-pill');
        for (var i = 0; i < buttons.length; i++) {
            resize_observer.observe(buttons[i]);
        }
    };
    new MutationObserver(observe_buttons).observe(container, { childList: true, subtree: true });
    observe_buttons();
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', newsblurListenWatchPill);
} else {
    newsblurListenWatchPill();
}

loadImages();
fitVideos();

Zepto(function($) {
      attachFastClick();
});
