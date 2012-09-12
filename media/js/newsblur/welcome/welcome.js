NEWSBLUR.Welcome = Backbone.View.extend({
    
    el: 'body',
    
    rotation: 0,
    
    initialize: function() {
        this.start_rotation();
    },
    
    start_rotation: function() {
        this.$('.NB-welcome-header-image img').eq(0).load(_.bind(function() {
            _.delay(_.bind(this.rotate_screenshots, this), 2000);
        }, this));
    },
    
    rotate_screenshots: function() {
        var r = this.rotation;
        var $images = $('.NB-welcome-header-image img');
        var $captions = $('.NB-welcome-header-caption');
        var $in_img = $images.eq((r+1) % $images.length);
        var $out_img = $images.eq(r % $images.length);
        var $in_caption = $captions.eq((r+1) % $images.length);
        var $out_caption = $captions.eq(r % $images.length);
        
        $out_img.css({zIndex: 0}).animate({
            bottom: -300,
            opacity: 0
        }, {easing: 'easeInOutQuart', queue: false, duration: 1400});
        $in_img.css({zIndex: 1, bottom: -300}).animate({
            bottom: 0,
            opacity: 1
        }, {easing: 'easeInOutQuart', queue: false, duration: 1400});
        $out_caption.removeClass('NB-active');
        $in_caption.addClass('NB-active');

        this.rotation += 1;

        _.delay(_.bind(this.rotate_screenshots, this), 3000);
    }
    
});