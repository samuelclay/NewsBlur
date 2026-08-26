NEWSBLUR.ReaderSendEmail = function (story, options) {
    var defaults = {};

    _.bindAll(this, 'close', 'save_callback', 'error');

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.story = story;
    this.feed_id = this.story.get('story_feed_id');
    this.feed = this.model.get_feed(this.feed_id);

    this.runner();
};

NEWSBLUR.ReaderSendEmail.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderSendEmail.prototype, {

    runner: function () {
        _.bindAll(this, 'save', 'update_send_button');
        this.options.onOpen = _.bind(function () {
            $('input[name=to]', this.$modal).focus();
        }, this);
        this.make_modal();
        this.open_modal();
        this.existing_emails = $.evalJSON($.cookie('NB:email:addresses')) || [];
        this.autocomplete_emails();
        this.update_send_button();

        if (!NEWSBLUR.Globals.is_authenticated) {
            this.save_callback({ 'code': -1, 'message': 'You must be logged in to send a story over email.' });
        }

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        $('input, textarea', this.$modal).bind('keydown', 'ctrl+return', this.save);
        $('input, textarea', this.$modal).bind('keydown', 'meta+return', this.save);
        $('input[name=to]', this.$modal).bind('input keyup change', this.update_send_button);
    },

    make_modal: function () {
        var self = this;
        var is_mac = /Mac|iPhone|iPad/.test(navigator.platform);

        this.$modal = $.make('div', { className: 'NB-modal-email NB-modal' }, [
            $.make('span', { className: 'NB-modal-loading NB-spinner' }),
            $.make('div', { className: 'NB-modal-error' }),
            $.make('h2', { className: 'NB-modal-title' }, 'Send Story by Email'),
            $.make('div', { className: 'NB-modal-email-story' }, [
                (this.feed && $.make('div', { className: 'NB-modal-email-feed' }, [
                    $.favicon_el(this.feed, {
                        image_class: 'NB-modal-feed-image feed_favicon',
                        emoji_class: 'NB-modal-feed-image NB-feed-emoji',
                        colored_class: 'NB-modal-feed-image NB-feed-icon-colored'
                    }),
                    $.make('div', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title'))
                ])),
                $.make('div', { className: 'NB-modal-email-story-title' }, this.story.story_title),
                $.make('a', {
                    className: 'NB-modal-email-story-permalink',
                    href: this.story.story_permalink,
                    target: '_blank',
                    rel: 'noopener noreferrer',
                    title: this.story.story_permalink
                }, this.story.story_permalink)
            ]),
            $.make('div', { className: 'NB-modal-email-field NB-modal-email-to-container' }, [
                $.make('label', { 'for': 'NB-send-email-to' }, [
                    'To',
                    $.make('span', { className: 'NB-modal-email-label-hint' }, 'separate multiple addresses with commas')
                ]),
                $.make('input', {
                    className: 'NB-input NB-modal-to', name: 'to', id: 'NB-send-email-to',
                    placeholder: 'recipient@example.com',
                    value: ($.cookie('NB:email:to') || "")
                })
            ]),
            $.make('div', { className: 'NB-modal-email-field NB-modal-email-comments-container' }, [
                $.make('label', { 'for': 'NB-send-email-comments' }, [
                    'Comment',
                    $.make('span', { className: 'NB-modal-email-label-hint' }, 'optional, appears above the story')
                ]),
                $.make('textarea', {
                    className: 'NB-modal-email-comments', id: 'NB-send-email-comments',
                    placeholder: 'Add a note to send along with the story…'
                })
            ]),
            $.make('div', { className: 'NB-modal-email-from-container' }, [
                $.make('div', { className: 'NB-modal-email-field' }, [
                    $.make('label', { 'for': 'NB-send-email-from-name' }, 'Your name'),
                    $.make('input', { className: 'NB-input NB-modal-email-from', name: 'from_name', id: 'NB-send-email-from-name', value: this.model.preference('full_name') || NEWSBLUR.Globals.username || '' })
                ]),
                $.make('div', { className: 'NB-modal-email-field' }, [
                    $.make('label', { 'for': 'NB-send-email-from-email' }, 'Your email'),
                    $.make('input', { className: 'NB-input NB-modal-email-from', name: 'from_email', id: 'NB-send-email-from-email', value: NEWSBLUR.Globals.email || this.model.preference('email') || '' })
                ])
            ]),
            $.make('div', { className: 'NB-modal-email-cc-wrapper' }, [
                $.make('label', { className: 'NB-modal-email-cc-label', 'for': 'NB-send-email-cc' }, [
                    $.make('input', { className: 'NB-modal-email-cc', name: 'email_cc', id: 'NB-send-email-cc', type: "checkbox", checked: this.model.preference('email_cc') }),
                    "Send me a copy of this email"
                ])
            ]),
            $.make('form', { className: 'NB-recommend-form' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', className: 'NB-modal-submit-button NB-modal-submit-green', value: 'Send this story' }),
                    $.make('span', { className: 'NB-modal-email-shortcut-hint' }, (is_mac ? '⌘↩' : 'Ctrl+↩') + ' to send'),
                    $.make('a', { href: '#', className: 'NB-modal-emailclient' }, 'Open in email client')
                ]),
                $.make('div', { className: 'NB-error' })
            ])
        ]);
    },

    update_send_button: function () {
        var to = $('input[name=to]', this.$modal).val() || '';
        var has_recipient = /\S+@\S+\.\S+/.test(to);
        $('input[type=submit]', this.$modal).toggleClass('NB-disabled', !has_recipient);
    },

    save: function (e) {
        var from_name = $('input[name=from_name]', this.$modal).val();
        var from_email = $('input[name=from_email]', this.$modal).val();
        var to = $('input[name=to]', this.$modal).val();
        var email_cc = $('input[name=email_cc]', this.$modal).is(":checked");
        var comments = $('textarea', this.$modal).val();
        var $save = $('input[type=submit]', this.$modal);
        var $error = $('.NB-modal-error', this.$modal);

        // Blocked while the recipient field is empty/invalid or a send is already in flight.
        if ($save.hasClass('NB-disabled')) {
            $('input[name=to]', this.$modal).focus();
            return;
        }

        $error.hide();
        $save.addClass('NB-disabled').val('Sending…');
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        this.model.preference('full_name', from_name);
        this.model.preference('email', from_email);
        this.model.preference('email_cc', email_cc);
        $('.NB-error', this.$modal).hide();

        this.model.send_story_email({
            story_id: this.story.id,
            feed_id: this.feed_id,
            from_name: from_name,
            from_email: from_email,
            email_cc: email_cc,
            to: to,
            comments: comments
        }, this.save_callback, this.error);
    },

    save_callback: function (data) {
        var $save = $('input[type=submit]', this.$modal);
        if (!data || data.code < 0) {
            $('.NB-error', this.$modal).html(data.message).fadeIn(500);
            $('.NB-modal-loading', this.$modal).removeClass('NB-active');
            $save.removeClass('NB-disabled').val('Send this story');
            this.update_send_button();
        } else {
            $('.NB-modal-loading', this.$modal).removeClass('NB-active');
            $save.val('✓ Sent').addClass('NB-modal-email-sent');
            $.cookie('NB:email:to', $('input[name=to]', this.$modal).val());
            var emails = $('input[name=to]', this.$modal).val();
            emails = emails.replace(/[, ]+/g, ' ').split(' ');
            emails = _.uniq(this.existing_emails.concat(emails));
            emails = _.map(emails, function (e) { return _.string.trim(e); });
            emails = _.compact(emails);
            $.cookie('NB:email:addresses', $.toJSON(emails), { expires: 365 * 10 });
            // Let the sent state land for a beat before dismissing the modal.
            _.delay(this.close, 750);
        }
    },

    error: function (data) {
        var $error = $('.NB-error', this.$modal);
        var $save = $('input[type=submit]', this.$modal);
        $error.show();
        console.log(['Error sending email', data]);
        if (!data || !data.message) {
            $error.text("There was a issue on the backend with sending your email. Sorry about this! It has been noted and will be fixed soon. You should probably send this manually now.");
        } else {
            $error.html(data.message).fadeIn(500);
        }
        $save.removeClass('NB-disabled').val('Send this story');
        this.update_send_button();
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');

        this.resize();
    },

    open_email_client: function () {
        var from_name = $('input[name=from_name]', this.$modal).val();
        var from_email = $('input[name=from_email]', this.$modal).val();
        var to = $('input[name=to]', this.$modal).val();
        var comments = $('textarea', this.$modal).val();

        var url = [
            'mailto:',
            to,
            '?subject=',
            from_name,
            ' is sharing a story: ',
            this.story.story_title,
            '&body=',
            comments,
            '%0D%0A%0D%0A--%0D%0A%0D%0A',
            this.story.story_permalink,
            '%0D%0A%0D%0A',
            encodeURIComponent($(this.story.story_content()).text()),
            '%0D%0A%0D%0A',
            '--',
            '%0D%0A%0D%0A',
            'Shared with NewsBlur.com'
        ].join('');
        window.open(url);
    },

    autocomplete_emails: function () {
        var self = this;
        var $to = $('input[name=to]', this.$modal);
        var existing_emails = this.existing_emails;

        var split = function (val) {
            return val.split(/,\s*/);
        };
        var extractLast = function (term) {
            return split(term).pop();
        };

        $to
            // don't navigate away from the field on tab when selecting an item
            .bind("keydown", function (event) {
                if (event.keyCode === $.ui.keyCode.TAB &&
                    $(this).data("ui-autocomplete").menu.active) {
                    event.preventDefault();
                }
            })
            .autocomplete({
                delay: 0,
                minLength: 0,
                appendTo: '.NB-modal-email',
                source: function (request, response) {
                    // delegate back to autocomplete, but extract the last term
                    console.log(["autocomplete", request, request.term, existing_emails]);
                    response($.ui.autocomplete.filter(
                        existing_emails, extractLast(request.term)));
                },
                focus: function () {
                    // prevent value inserted on focus
                    return false;
                },
                select: function (event, ui) {
                    var terms = split(this.value);
                    // remove the current input
                    terms.pop();
                    // add the selected item
                    terms.push(ui.item.value);
                    // add placeholder to get the comma-and-space at the end
                    terms.push("");
                    this.value = terms.join(", ");
                    self.update_send_button();
                    return false;
                }
            });
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-submit-button' }, function ($t, $p) {
            e.preventDefault();

            self.save();
            return false;
        });
        $.targetIs(e, { tagSelector: '.NB-modal-emailclient' }, function ($t, $p) {
            e.preventDefault();

            self.open_email_client();
            return false;
        });
    }

});
