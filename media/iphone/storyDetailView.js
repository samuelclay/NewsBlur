Zepto(function($){
      
      $('img').each(function() {
                    var width = $(this).width();
                    console.log('width is' + width);
                    if ($(this).attr('src').indexOf('feedburner') != -1) {
                    $(this).addClass('NB-feedburner');
                    } else if (width > 300) {
                    $(this).addClass('NB-large-image');
                    } else if (width > 10 ) {
                    $(this).addClass('NB-small-image');
                    } else {
                    $(this).addClass('NB-tracker');
                    }
                    
    });
      
      $('img').bind('load', function() {
            var width = $(this).width();
            console.log('width is' + width);
            if ($(this).attr('src').indexOf('feedburner') != -1) {
            $(this).addClass('NB-feedburner');
            } else if (width > 300) {
            $(this).addClass('NB-large-image');
            } else if (width > 10 ) {
            $(this).addClass('NB-small-image');
            } else {
            $(this).addClass('NB-tracker');
            }
    
    });
})