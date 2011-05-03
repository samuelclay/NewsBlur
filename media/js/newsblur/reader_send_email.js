NEWSBLUR.ReaderSendEmail = function(options) {
    var defaults = {};

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.story_id = options.story_id;
    this.story = this.model.get_story(story_id);

    this.runner();
};

NEWSBLUR.ReaderSendEmail.prototype = _.extend(NEWSBLUR.Modal.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-goodies NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Goodies &amp; Extras'),
            $.make('div', { className: 'NB-goodies-group' }, [
              NEWSBLUR.generate_bookmarklet(),
              $.make('div', { className: 'NB-goodies-title' }, 'Add Site Bookmarklet')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-firefox-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add to Firefox'),
              $.make('div', { className: 'NB-goodies-firefox' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Firefox: Register Newsblur as an RSS reader')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-chrome-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add to Chrome'),
              $.make('div', { className: 'NB-goodies-chrome' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Google Chome: NewsBlur Chrome Web App')
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('a', {
                  className: 'NB-goodies-safari-link NB-modal-submit-button NB-modal-submit-green',
                  href: '#'
              }, 'Add to Safari'),
              $.make('div', { className: 'NB-goodies-safari' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Safari: Register Newsblur as an RSS reader'),
              $.make('div', { className: 'NB-goodies-subtitle' }, [
                'To use this extension, extract and move the NewsBlur Safari Helper.app ',
                'to your Applications folder. Then in ',
                $.make('b', 'Safari > Settings > RSS'),
                ' choose the new NewsBlur Safari Helper.app. Then clicking on the RSS button in ',
                'Safari will open the feed in NewsBlur. Simple!'
              ])
            ]),
            $.make('div', { className: 'NB-goodies-group NB-modal-submit' }, [
              $.make('input', {
                  className: 'NB-goodies-custom-input',
                  value: 'http://www.newsblur.com/?url=BLOG_URL_GOES_HERE'
              }),
              $.make('div', { className: 'NB-goodies-custom' }),
              $.make('div', { className: 'NB-goodies-title' }, 'Custom Add Site URL')
            ])
        ]);
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-goodies-bookmarklet-button' }, function($t, $p) {
            e.preventDefault();
            
            alert('Drag this button to your bookmark toolbar.');
        });
    }
    
});