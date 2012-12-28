var Trainer = function() {
    this.highlightTitle();
}

Trainer.prototype = {
    
    highlightTitle: function() {
        var $title = $(".NB-title").get(0);

    }
    
};


Zepto(function($) {
      new Trainer();
      attachFastClick({
          skipEvent: true
      });
});
