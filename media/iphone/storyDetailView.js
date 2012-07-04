$('.NB-story img').each(function() {
    setImage(this);
});

$('.NB-story img').bind('load', function() {
    setImage(this);
});

$('a.NB-show-profile').click(function(){
  var offset = $(this).offset();
  console.log(offset);
  var url = $(this).attr('href') + "/" + offset.left + "/" + (offset.top - window.pageYOffset) + "/" + offset.width + "/" + offset.height;
  window.location = url;
  return false;
  
})

function setImage(img) {
    var $img = $(img);
    var width = $(img).width();
    var height = $(img).height();
    
    if ($img.attr('src').indexOf('feedburner') != -1) {
        $img.attr('class', 'NB-feedburner');
    } else if (width > 300 && height > 50) {
        $img.attr('class', 'NB-large-image');
        if ($img.parent().attr('href')) {
            $img.parent().addClass('NB-contains-image')
        }
    } else if (width > 30  && height > 30) {
        $img.attr('class', 'NB-medium-image');
        if ($img.parent().attr('href')) {
            $img.parent().addClass('NB-contains-image')
        }
    } else {
        $img.attr('class', 'NB-small-image');
    }
}

window.onload = load;

function load() {  
    document.getElementsByClassName('NB-share-button')[0].addEventListener("touchstart", touchStart, false);
    document.getElementsByClassName('NB-share-button')[0].addEventListener("touchend", touchEnd, false);
} 

function touchStart(e) {
    var original_class = e.target.getAttribute("class");
    e.target.setAttribute("class", original_class + " active");
    return false;
}

function touchEnd(e) {
    var original_class = e.target.getAttribute("class");
    e.target.setAttribute("class", original_class.replace('active', ''));
    window.location = "http://ios.newsblur.com/share";  
    return false;
}

