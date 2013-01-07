$('.NB-story img').each(function () {
    setImage(this);
});

$('.NB-story img').bind('load', function () {
    setImage(this);
});

$('a.NB-show-profile').live('click', function () {
    var offset = $('img', this).offset();
    console.log(offset);
    var url = $(this).attr('href') + "/" + offset.left + "/" + (offset.top - window.pageYOffset) + "/" + offset.width + "/" + offset.height;
    window.location = url;
    return false;
});

$('.NB-button').live('touchstart', function () {
    $(this).addClass('selected');
});

$('.NB-button').live('touchend', function (e) {
    $(this).removeClass('selected');
});

function setImage(img) {
    var $img = $(img);
    var width = $(img).width();
    var height = $(img).height();

    if ($img.attr('src').indexOf('feedburner') != - 1) {
        $img.attr('class', 'NB-feedburner');
    } else if (width > 300 && height > 50) {
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
