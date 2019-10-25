window.fbAsyncInit = function() {
    FB.init({
      appId            : NEWSBLUR.Globals.debug ? '111137799005981' : '230426707030569',
      autoLogAppEvents : true,
      xfbml            : true,
      version          : 'v3.2'
    });
  };
   
NEWSBLUR.ReaderFacebook = function(url, comments, options) {
    var defaults = {
        'width': 800
    };
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.url = url;
    this.comments = comments;
    this.runner();
};

NEWSBLUR.ReaderFacebook.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderFacebook.prototype.constructor = NEWSBLUR.ReaderFacebook;

_.extend(NEWSBLUR.ReaderFacebook.prototype, {
    
    runner: function() {
      $.getScript("https://connect.facebook.net/en_US/sdk.js").done(_.bind(function() {
        _.delay(_.bind(function() {
          console.log(['Opening facebook dialog', this.url, this.comments]);
           FB.ui({
             method: 'share',
             quote: this.comments,
             href: this.url
           }, function(response){});        
         }, this), 100);
       }, this));
    }
    
 
});