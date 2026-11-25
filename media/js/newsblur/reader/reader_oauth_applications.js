NEWSBLUR.AccountOAuthApplications = function (account) {
    var self = this;
    this.account = account;
    var can_register = NEWSBLUR.Globals.can_register_oauth_app;
    this.$form = $.make('form', { className: 'NB-oauth-form' }, [
        this.field(gettext('Application name'), {
            type: 'text', name: 'name', maxlength: 255, placeholder: gettext('Your app name'), required: true
        }),
        this.field(gettext('Application website'), {
            type: 'url', name: 'website', maxlength: 2048, placeholder: 'https://example.com', required: true
        }),
        this.field(gettext('Redirect URL'), {
            type: 'url', name: 'redirect_uri', maxlength: 2048, placeholder: 'https://example.com/oauth/callback',
            required: true, 'aria-describedby': 'NB-oauth-redirect-help'
        }),
        $.make('p', { className: 'NB-oauth-help', id: 'NB-oauth-redirect-help' },
            gettext('After a reader authorizes your app, NewsBlur sends them to this URL with an authorization code.')),
        $.make('p', { className: 'NB-oauth-error', role: 'alert' }),
        can_register && $.make('button', {
            type: 'submit', className: 'NB-modal-submit-button NB-modal-submit-green'
        }, gettext('Create application'))
    ]);

    this.$consent_link = $.make('a', {
        target: '_blank', rel: 'noopener noreferrer'
    }, gettext('Consent screen preview'));
    this.$link = $.make('code', { className: 'NB-oauth-url', dir: 'ltr' });
    var $preview = $.make('section', { className: 'NB-oauth-preview' }, [
        $.make('p', { className: 'NB-oauth-preview-link' }, [this.$consent_link]),
        $.make('h4', gettext('Authorization link')),
        this.$link,
        $.make('p', { className: 'NB-oauth-help' }, gettext('This example requests read access. Generate a fresh state value for each sign-in and verify it when the reader returns.'))
    ]);

    var $upgrade = $.make('button', {
        type: 'button', className: 'NB-modal-submit-button NB-modal-submit-green'
    }, gettext('Upgrade to Premium Pro')).on('click', function () {
        account.close_and_load_premium({ highlight_feature: 'oauth' });
    });
    this.$upgrade_text = $.make('strong', gettext('Creating OAuth applications requires NewsBlur Premium Pro.'));
    this.$heading = $.make('summary', gettext('Create a new OAuth application'));
    this.$refresh = $.make('button', { type: 'button', className: 'NB-oauth-refresh' }, gettext('Refresh')).on('click', function () {
        self.load_applications();
    });
    this.$list = $.make('div', { className: 'NB-oauth-app-list' });
    this.$status = $.make('p', { className: 'NB-oauth-help', role: 'status' });
    this.$intro = $.make('p', { className: 'NB-oauth-intro' },
        gettext('Connect your app to NewsBlur so readers can grant access to their stories and feeds. Readers on any plan can connect.'));
    this.intro_text = this.$intro.text();
    this.$registration = $.make('details', { className: 'NB-oauth-registration' }, [
        this.$heading, this.$intro, $.make('div', { className: 'NB-oauth-columns' }, [this.$form, $preview])
    ]).prop('open', !!account.options.create_oauth);
    this.$tab = $.make('div', { className: 'NB-tab NB-tab-oauth NB-oauth-application' }, [
        $.make('div', { className: 'NB-oauth-list-heading' }, [
            $.make('h3', gettext('Your OAuth applications')), this.$refresh
        ]),
        !can_register && $.make('div', { className: 'NB-oauth-upgrade NB-ai-filter-upgrade-banner-inner' }, [
            this.$upgrade_text, $upgrade
        ]),
        this.$registration, this.$status, this.$list
    ]);
    this.$form.on('input', _.bind(this.update_preview, this));
    this.$form.on('submit', _.bind(this.submit, this));
    this.update_preview();
};

NEWSBLUR.AccountOAuthApplications.prototype = {
    field: function (label, attributes) {
        return $.make('label', {}, [label, $.make('input', attributes)]);
    },

    load_applications: function () {
        var self = this;
        if (this.request) this.request.abort();
        this.$refresh.prop('disabled', true);
        this.$status.text(gettext('Loading applications…'));
        this.request = $.getJSON('/account/applications/usage/').done(function (data) {
            self.$list.empty();
            data.applications.forEach(function (app) { self.$list.append(self.application_row(app)); });
            if (data.applications.length) {
                if (!NEWSBLUR.Globals.can_register_oauth_app) {
                    self.$upgrade_text.text(gettext('Your applications are paused until your account has active Premium Pro.'));
                }
                self.$status.text(gettext('Connected accounts have an unexpired access token. Active readers are estimated over seven UTC days. API requests and last activity are measured from the start of tracking.'));
            } else {
                self.$status.text(gettext('You haven’t registered any OAuth applications yet.'));
                self.$registration.prop('open', true);
            }
            self.account.resize();
        }).fail(function (xhr, status) {
            if (status !== 'abort') self.$status.text(gettext('Could not load your applications. Try refreshing.'));
        }).always(function () {
            self.request = null;
            self.$refresh.prop('disabled', false);
        });
    },

    application_row: function (app) {
        var usage = app.usage;
        var lang = document.documentElement.lang || undefined;
        var last_used = usage && usage.last_used
            ? new Date(usage.last_used * 1000).toLocaleString(lang, {dateStyle: 'medium', timeStyle: 'short'})
            : gettext('No recorded activity');
        var $metrics = $.make('dl', { className: 'NB-oauth-metrics' });
        function metric(label, value) {
            $metrics.append($.make('div', {}, [$.make('dt', label), $.make('dd').text(value)]));
        }
        var unavailable = gettext('Unavailable');
        metric(gettext('Connected accounts'), app.connected.toLocaleString(lang));
        metric(gettext('Active readers · 7 days'), usage ? usage.readers.toLocaleString(lang) : unavailable);
        metric(gettext('API requests'), usage ? usage.requests.toLocaleString(lang) : unavailable);
        metric(gettext('Last activity'), usage ? last_used : unavailable);
        var $details = $.make('details', { className: 'NB-oauth-app-details' }, [
            $.make('summary').text(app.name || app.client_id),
            this.field(gettext('Client ID'), { type: 'text', readonly: true, value: app.client_id }),
            app.website && this.field(gettext('Application website'), { type: 'url', readonly: true, value: app.website }),
            $.make('div', {}, [
                $.make('strong', gettext('Redirect URL')),
                $.make('code', { className: 'NB-oauth-redirects', dir: 'ltr' }).text(app.redirect_uris.split(/\s+/).join('\n'))
            ])
        ]);
        return $.make('section', { className: 'NB-oauth-app-row' }, [$details, $metrics]);
    },

    update_preview: function () {
        var fields = this.$form[0].elements;
        var preview = new URL('/account/applications/preview/', window.location.origin);
        preview.searchParams.set('name', fields.name.value.trim() || fields.name.placeholder);
        preview.searchParams.set('website', fields.website.value.trim() || fields.website.placeholder);
        this.$consent_link.attr('href', preview.href);
        var url = new URL('/oauth/authorize/', window.location.origin);
        url.search = new URLSearchParams({
            client_id: this.client_id || 'YOUR_CLIENT_ID',
            redirect_uri: fields.redirect_uri.value.trim() || fields.redirect_uri.placeholder,
            response_type: 'code', scope: 'read', state: 'STATE'
        }).toString();
        this.$link.text(url.href);
    },

    submit: function (event) {
        event.preventDefault();
        var self = this;
        var $button = this.$form.find('button[type=submit]');
        if (!NEWSBLUR.Globals.can_register_oauth_app || $button.prop('disabled')) return;
        $button.prop('disabled', true);
        this.$form.find('[role=alert]').empty();
        $.ajax({
            url: '/account/applications/register/', type: 'POST', dataType: 'json',
            headers: { 'X-CSRFToken': $.cookie('csrftoken') },
            data: this.$form.serialize()
        }).done(function (data) {
            self.client_id = data.client_id;
            self.update_preview();
            self.$heading.text(gettext('OAuth application created')).focus();
            self.$intro.text(gettext('Copy your client secret now. You will only see it once.'));
            self.$form.detach();
            self.$registration.find('.NB-oauth-columns').prepend($.make('div', { className: 'NB-oauth-credentials' }, [
                self.field(gettext('Client ID'), { type: 'text', readonly: true, value: data.client_id }),
                self.field(gettext('Client secret'), { type: 'text', readonly: true, value: data.client_secret }),
                $.make('button', { type: 'button', className: 'NB-oauth-refresh' }, gettext('Create another application')).on('click', function () {
                    self.client_id = null;
                    self.$form[0].reset();
                    self.$form.find('button[type=submit]').prop('disabled', false);
                    self.$registration.find('.NB-oauth-credentials').replaceWith(self.$form);
                    self.$heading.text(gettext('Create a new OAuth application'));
                    self.$intro.text(self.intro_text);
                    self.update_preview();
                    self.$form.find('[name=name]').focus();
                })
            ]));
            self.load_applications();
        }).fail(function (xhr) {
            var error = xhr.responseJSON && xhr.responseJSON.error;
            self.$form.find('[role=alert]').text(error || gettext('Could not create the application. Please try again.'));
            $button.prop('disabled', false);
        });
    }
};
