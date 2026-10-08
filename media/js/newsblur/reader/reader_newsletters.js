NEWSBLUR.ReaderNewsletters = function (options) {
    var defaults = {
        'width': 800
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderNewsletters.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderNewsletters.prototype.constructor = NEWSBLUR.ReaderNewsletters;

_.extend(NEWSBLUR.ReaderNewsletters.prototype, {

    runner: function () {
        this.make_modal();
        this.open_modal(_.bind(function () {
            $('.NB-newsletters-email').click();
        }, this));

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },

    make_modal: function () {
        var self = this;
        var email = NEWSBLUR.Globals.username + "-" + NEWSBLUR.Globals.secret_token + "@newsletters.newsblur.com";

        this.$modal = $.make('div', { className: 'NB-modal-newsletters NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                gettext('Email Newsletters'),
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),

            $.make('fieldset', [
                $.make('legend', gettext('Forwarding email address'))
            ]),
            $.make('div', { className: 'NB-newsletters-group' }, [
                $.make('input', { type: 'text', value: email, className: 'NB-newsletters-email' })
            ]),

            $.make('fieldset', [
                $.make('legend', gettext('Setup instructions'))
            ]),
            $.make('div', { className: 'NB-newsletters-group' }, [
                $.make('p', gettext('To read your email newsletters in NewsBlur, forward your newsletters to your custom email address shown above.')),
                $.make('p', [
                    gettext('In Gmail, go to '),
                    $.make('b', gettext('Settings &gt; Forwarding')),
                    gettext(' and click on '),
                    $.make('b', gettext('Add a forwarding address')),
                    '. Add your custom NewsBlur email address.'
                ]),
                $.make('p', gettext('Gmail will walk you through confirming the email address. You\'ll want to come back to NewsBlur and look for the confirmation email under the "Newsletters" folder.')),
                $.make('p', gettext('Next, create a filter with all of your newsletters so that they forward to the custom address on NewsBlur.')),
                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/newsletters_gmail.png", className: 'NB-newsletters-gmail' })
            ])
        ]);
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-newsletters-email' }, function ($t, $p) {
            e.preventDefault();
            $t.select();
        });
    }

});
