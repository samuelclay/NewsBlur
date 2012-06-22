Zepto(function($) {
    $('img').each(function() {
        setImage(this);
    });

    $('img').bind('load', function() {
        setImage(this);
    });
    
    function setImage(img) {
      var $img = $(img);
              console.log($img.parent().attr('href'));
      if ($img.parent().attr('href')) {

        $img.parent().addClass('NB-contains-image')
      }
      var width = $(img).width();
      console.log('width is' + width);
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

