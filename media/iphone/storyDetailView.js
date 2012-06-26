Zepto(function($) {
    $('img').each(function() {
        setImage(this);
    });

    $('img').bind('load', function() {
        setImage(this);
    });
    
    function setImage(img) {
      var $img = $(img);
      if ($img.parent().attr('href')) {

        $img.parent().addClass('NB-contains-image')
      }
      var width = $(img).width();
      if ($(img).attr('src').indexOf('feedburner') != -1) {
          $(img).addClass('NB-feedburner');
      } else if (width > 300) {
          $(img).addClass('NB-large-image');
          $(img).removeClass('NB-small-image');
      } else if (width > 10) {
          $(img).addClass('NB-small-image');
          $(img).removeClass('NB-large-image');
      } else {
          $(img).addClass('NB-tracker');
      }
    }
    
})

window.onload = load;

function load() {  
  //document.getElementsByClassName('NB-share-button')[0].addEventListener("mousedown", touchStart, false);
  document.getElementsByClassName('NB-share-button')[0].addEventListener("touchstart", touchStart, false);
  //document.getElementsByClassName('NB-share-button')[0].addEventListener("mouseup", touchEnd, false);
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
