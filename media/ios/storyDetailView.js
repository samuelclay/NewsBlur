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

})

$('.NB-button').live('touchstart', function () {
    $(this).addClass('hover');
});

$('.NB-button').live('touchend', function (e) {
    $(this).removeClass('hover');
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
    var commentString = 'NB-user-comment-' + commentId;

    //Get comment
    var $comment = $('#' + commentString);
    if ($comment.length) {
        $.scroll($comment.offset().top - 32, 1000);
    } else {
        var shareButton = document.getElementById("NB-share-button-id");
        $.scroll($('#NB-share-button-id').offset().top - 32, 1000);
    }

    if (highlight) {
        setTimeout(function(){
            $('#' + commentString).addClass('NB-highlighted');
            setTimeout(function(){
                $('#' + commentString).removeClass('NB-highlighted');
            }, 2000);
        }, 1000);
    }
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