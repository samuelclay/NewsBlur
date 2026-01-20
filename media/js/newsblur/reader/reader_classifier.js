NEWSBLUR.ReaderClassifierTrainer = function (options) {
    var defaults = {
        'width': 720,
        'training': true,
        modal_container_class: "NB-full-container NB-classifier-container"
    };

    this.flags = {
        'publisher': true,
        'story': false,
        'modal_loading': false,
        'modal_loaded': false
    };
    this.cache = {};
    this.trainer_iterator = -1;
    this.feed_id = null;
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner_trainer();
};

NEWSBLUR.ReaderClassifierFeed = function (feed_id, options) {
    var defaults = {
        'width': 720,
        'training': false,
        'feed_loaded': true,
        modal_container_class: "NB-full-container NB-classifier-container"
    };

    this.flags = {
        'publisher': true,
        'story': false,
        'modal_loading': false,
        'modal_loaded': false
    };
    this.cache = {};
    this.feed_id = feed_id;
    this.trainer_iterator = -1;
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner_feed();
};


NEWSBLUR.ReaderClassifierStory = function (story_id, feed_id, options) {
    var defaults = {
        'width': 720,
        'feed_loaded': true,
        modal_container_class: "NB-full-container NB-classifier-container"
    };

    this.flags = {
        'publisher': false,
        'story': true,
        'modal_loading': false,
        'modal_loaded': false
    };
    this.cache = {};
    this.story_id = story_id;
    this.feed_id = feed_id;
    this.original_feed_id = feed_id;
    // if (options.social_feed_id) this.feed_id = options.social_feed_id;
    this.trainer_iterator = -1;
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner_story();
};

var classifier_prototype = {

    runner_trainer: function (reload) {
        if (!reload) {
            this.user_classifiers = {};
        }

        this.make_trainer_intro();
        this.get_feeds_trainer();
        this.handle_cancel();
        this.open_modal();

        this.model.preference('has_trained_intelligence', true);
        NEWSBLUR.reader.check_hide_getting_started();

        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));
    },

    runner_feed: function () {
        this.options.social_feed = _.string.include(this.feed_id, 'social:');

        if (!this.model.classifiers[this.feed_id]) {
            this.model.classifiers[this.feed_id] = _.extend({}, this.model.defaults['classifiers']);
        }

        if (this.options.feed_loaded) {
            this.user_classifiers = this.model.classifiers[this.feed_id];
        } else {
            this.user_classifiers = {};
        }
        this.find_story_and_feed();
        this.make_modal_feed();
        this.make_modal_title();
        this.handle_cancel();
        this.open_modal(_.bind(function () {
            this.fit_classifiers();
        }, this));
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));

        if (!this.options.feed_loaded) {
            _.defer(_.bind(function () {
                this.load_single_feed_trainer();
            }, this));
        }
    },

    runner_story: function () {
        this.options.social_feed = _.string.include(this.feed_id, 'social:');

        if (!this.model.classifiers[this.feed_id]) {
            this.model.classifiers[this.feed_id] = _.extend({}, this.model.defaults['classifiers']);
        }

        if (this.options.feed_loaded) {
            this.user_classifiers = this.model.classifiers[this.feed_id];
        } else {
            this.user_classifiers = {};
        }

        this.find_story_and_feed();
        this.make_modal_story();
        this.handle_text_highlight();
        this.handle_regex_input();
        this.make_modal_title();
        this.handle_cancel();
        this.open_modal(_.bind(function () {
            this.fit_classifiers();
            // Initialize Tipsy tooltips for help icons (now that modal is in DOM)
            this.$modal.find('.NB-classifier-help-icon').tipsy({
                gravity: 's',
                fade: true,
                delayIn: 50,
                opacity: 1
            });
        }, this));
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));

        if (!this.options.feed_loaded) {
            _.defer(_.bind(function () {
                this.load_single_feed_trainer();
            }, this));
        }
    },

    load_previous_feed_in_trainer: function () {
        var trainer_data_length = this.trainer_data.length;
        this.trainer_iterator = this.trainer_iterator - 1;
        var trainer_data = this.trainer_data[this.trainer_iterator];
        // NEWSBLUR.log(['load_previous_feed_in_trainer', this.trainer_iterator, trainer_data]);
        if (!trainer_data || this.trainer_iterator < 0) {
            this.make_trainer_intro();
            this.reload_modal();
        } else {
            this.feed_id = trainer_data['feed_id'];
            this.load_feed(trainer_data);
        }
    },

    load_next_feed_in_trainer: function () {
        var trainer_data_length = this.trainer_data.length;
        this.trainer_iterator += 1;
        var trainer_data = this.trainer_data[this.trainer_iterator];
        // NEWSBLUR.log(['load_next_feed_in_trainer', this.trainer_iterator, trainer_data]);
        if (!trainer_data || this.trainer_iterator >= trainer_data_length) {
            this.make_trainer_outro();
            this.reload_modal();
            this.load_feeds_trainer(null, this.trainer_data);
        } else {
            this.feed_id = trainer_data['feed_id'];
            if (this.model.get_feed(this.feed_id)) {
                this.load_feed(trainer_data);
            } else {
                this.load_next_feed_in_trainer();
            }
        }
    },

    load_feed: function (trainer_data) {
        this.feed_id = trainer_data['feed_id'] || trainer_data['id'];
        this.feed = this.model.get_feed(this.feed_id);
        this.feed_tags = trainer_data['feed_tags'];
        this.feed_authors = trainer_data['feed_authors'];
        this.user_classifiers = trainer_data['classifiers'];
        this.feed_publishers = new Backbone.Collection(trainer_data['popular_publishers']);
        this.feed.set('num_subscribers', trainer_data['num_subscribers'], { silent: true });
        this.options.feed_loaded = true;

        if (!this.model.classifiers[this.feed_id]) {
            this.model.classifiers[this.feed_id] = _.extend({}, this.model.defaults['classifiers']);
        }

        if (this.feed_id in this.cache) {
            this.$modal = this.cache[this.feed_id];
        } else {
            if (this.flags['story']) {
                this.make_modal_story();
                this.handle_text_highlight();
            } else if (this.flags['publisher']) {
                this.make_modal_feed();
                this.make_modal_trainer_count();
            }
            this.make_modal_title();
        }

        this.reload_modal();
    },

    reload_modal: function (callback) {
        this.flags.modal_loading = setInterval(_.bind(function () {
            if (this.flags.modal_loaded) {
                clearInterval(this.flags.modal_loading);
                $('.NB-modal').empty().append(this.$modal.children());
                this.$modal = $('.NB-modal'); // This is bonkers. I shouldn't have to reattach like this
                $(window).trigger('resize.simplemodal');
                this.handle_cancel();
                this.$modal.parent().scrollTop(0);
                callback && callback();
                this.fit_classifiers();
            }
        }, this), 125);
    },

    fit_classifiers: function () {
        var $form = $("form", this.$modal);
        if (!$form.length) return;
        var form_height = $form.innerHeight();
        var form_outerheight = $form.outerHeight(true);
        var offset_top = $form.position().top;
        var offset_bottom = $(".NB-modal-submit-bottom", this.$modal).outerHeight(true);
        var container_height = $(".simplemodal-container").height();
        var new_form_height;
        var i = 0;
        while (form_outerheight + offset_top + offset_bottom > container_height) {
            // console.log(["fit_classifiers", form_outerheight, offset_top, offset_bottom, container_height]);
            i++;
            $form.height(form_height - 1);
            new_form_height = $form.innerHeight();
            form_outerheight = $form.outerHeight(true);
            if (new_form_height == form_height || i > 500) break;
            form_height = Math.min(new_form_height, form_height - 1);
        }
    },

    get_feeds_trainer: function () {
        this.model.get_feeds_trainer(null, $.rescope(this.load_feeds_trainer, this));
    },

    load_feeds_trainer: function (e, data) {
        var $begin = $('.NB-modal-submit-begin', this.$modal);

        this.trainer_data = data;

        if (!data || !data.length) {
            this.make_trainer_outro();
            this.reload_modal();
        } else {
            $begin.text('Begin Training')
                .addClass('NB-modal-submit-green')
                .removeClass('NB-modal-submit-grey')
                .removeClass('NB-disabled');
        }
    },

    retrain_all_sites: function () {
        $('.NB-modal-submit-reset', this.$modal).text('Rewinding...').attr('disabled', true).addClass('NB-disabled');

        this.model.retrain_all_sites(_.bind(function (data) {
            this.load_feeds_trainer(null, data);
            this.load_next_feed_in_trainer();
        }, this));
    },

    find_story_and_feed: function () {
        if (this.story_id) {
            this.story = this.model.get_story(this.story_id);
        }

        this.feed = this.model.get_feed(this.feed_id);

        if (this.options.feed_loaded && this.feed) {
            this.feed_tags = this.model.get_feed_tags();
            this.feed_authors = this.model.get_feed_authors();
            var $feed_icon = $.favicon_el(this.feed, {
                image_class: 'NB-modal-feed-image feed_favicon',
                emoji_class: 'NB-modal-feed-image NB-feed-emoji',
                colored_class: 'NB-modal-feed-image NB-feed-icon-colored'
            });
            if ($feed_icon) {
                var $existing_icon = $('.NB-modal-subtitle .NB-modal-feed-image, .NB-modal-subtitle .NB-feed-emoji, .NB-modal-subtitle .NB-feed-icon-colored', this.$modal).first();
                if ($existing_icon.length) {
                    $existing_icon.replaceWith($feed_icon);
                } else {
                    $('.NB-modal-subtitle', this.$modal).prepend($feed_icon);
                }
            }
            $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed.get('feed_title'));
            $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).html(Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true));
        }
    },

    load_single_feed_trainer: function () {
        var self = this;
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');

        var get_trainer_fn = this.model.get_feeds_trainer;
        if (this.options.social_feed) {
            get_trainer_fn = this.model.get_social_trainer;
        }
        get_trainer_fn.call(this.model, this.feed_id, function (data) {
            self.trainer_data = data;
            if (data && data.length) {
                // Should only be one feed
                self.load_feed(data[0]);
            }
        });
    },

    make_trainer_intro: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal NB-modal-trainer' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Intelligence Trainer',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('h3', { className: 'NB-modal-subtitle' }, 'Here\'s what to do:'),
            $.make('ol', { className: 'NB-trainer-points NB-classifiers' }, [
                $.make('li', [
                    $.make('div', { className: 'NB-classifier-example' }),
                    $.make('b', 'You will see a bunch of tags and authors.'),
                    ' Sites will be ordered by popularity. Click on what you like and don\'t like.'
                ]),
                $.make('li', [
                    $.make('b', 'The intelligence slider filters stories.'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-focus.svg' }),
                    ' are stories you like',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-unread.svg' }),
                    ' are stories you have not yet rated',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-hidden.svg' }),
                    ' are stories you don\'t like'
                ]),
                $.make('li', [
                    // $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_menu.png', style: 'float: right', width: 176, height: 118 }),
                    $.make('b', 'Stop any time you like.'),
                    ' You can easily train individual stories as you read.'
                ])
            ]),
            (!NEWSBLUR.Globals.is_authenticated && $.make('div', { className: 'NB-trainer-not-authenticated' }, 'Please create an account and add sites you read. Then you can train them.')),
            $.make('div', { className: 'NB-modal-submit-bottom' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    (!NEWSBLUR.Globals.is_authenticated && $.make('div', { className: 'NB-modal-submit-grey NB-modal-submit-button' }, 'Close')),
                    (NEWSBLUR.Globals.is_authenticated && $.make('div', { className: 'NB-modal-submit-begin NB-modal-submit-button NB-modal-submit-grey NB-disabled' }, 'Loading Training...'))
                ])
            ])
        ]);

    },

    make_trainer_outro: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal NB-modal-trainer' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Congratulations! You\'re done.'),
            $.make('h3', { className: 'NB-modal-subtitle' }, 'Here\'s what happens next:'),
            $.make('ol', { className: 'NB-trainer-points' }, [
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_classifier_tag.png', style: 'float: right', width: 135 }),
                    $.make('b', 'You can change your opinions.'),
                    ' You can click the ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/thumbs-up.svg', style: 'vertical-align: middle;padding: 0 8px 0 2px', width: 14, height: 20 }),
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/thumbs-down.svg', style: 'vertical-align: top; padding: 0', width: 14, height: 20 }),
                    ' buttons next to stories as you read them.'
                ]),
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/intelligence_slider_positive.png', style: 'float: right', width: 114, height: 29 }),
                    $.make('b', 'As a reminder, use the intelligence slider to select a filter:'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-hidden.svg' }),
                    ' are stories you don\'t like',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-unread.svg' }),
                    ' are stories you have not yet rated',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/indicator-focus.svg' }),
                    ' are stories you like'

                ]),
                $.make('li', [
                    $.make('b', 'You can also filter out stories you don\'t want to read.'),
                    ' As great as finding good stuff is, you can just as easily ignore the stories you do not like.'
                ])
            ]),
            $.make('div', { className: 'NB-modal-submit-bottom' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-reset' }, $.entity('&laquo;') + ' Retrain all sites'),
                    $.make('div', { className: 'NB-modal-submit-end NB-modal-submit-button' }, 'Close Training and Start Reading')
                ])
            ])
        ]);

    },

    make_modal_feed: function () {
        var self = this;
        var feed = this.feed;

        // NEWSBLUR.log(['Make feed', feed, this.feed_authors, this.feed_tags, this.options['feed_loaded']]);

        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal ' + (this.options['training'] && 'NB-modal-trainer') }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, ''),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                (this.options['training'] && $.make('div', { className: 'NB-classifier-trainer-counts' })),
                $.favicon_el(this.feed, {
                    image_class: 'NB-modal-feed-image feed_favicon',
                    emoji_class: 'NB-modal-feed-image NB-feed-emoji',
                    colored_class: 'NB-modal-feed-image NB-feed-icon-colored'
                }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title')),
                    $.make('span', { className: 'NB-modal-feed-subscribers' }, Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true))
                ])
            ]),
            (this.options['feed_loaded'] &&
                $.make('form', { method: 'post', className: 'NB-publisher' }, [
                    ((!_.isEmpty(this.user_classifiers.titles) || !_.isEmpty(this.user_classifiers.title_regex)) && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Title Phrases'),
                        $.make('div', { className: 'NB-classifier-titles NB-fieldset-fields NB-classifiers' },
                            this.make_user_titles().concat(this.make_user_title_regex())
                        )
                    ])),
                    ((!_.isEmpty(this.user_classifiers.texts) || !_.isEmpty(this.user_classifiers.text_regex) || !_.isEmpty(this.user_classifiers.regex)) && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Text Phrases'),
                        $.make('div', { className: 'NB-classifier-texts NB-fieldset-fields NB-classifiers' },
                            this.make_user_texts().concat(this.make_user_text_regex())
                        )
                    ])),
                    (this.feed_authors.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Authors'),
                        $.make('div', { className: 'NB-classifier-authors NB-fieldset-fields NB-classifiers' },
                            this.make_authors(this.feed_authors).concat(this.make_user_authors())
                        )
                    ])),
                    (this.feed_tags.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Categories &amp; Tags'),
                        $.make('div', { className: 'NB-classifier-tags NB-fieldset-fields NB-classifiers' },
                            this.make_tags(this.feed_tags).concat(this.make_user_tags())
                        )
                    ])),
                    (this.feed_publishers && this.feed_publishers.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-publishers' }, [
                        $.make('h5', 'Sharing Stories From These Sites'),
                        $.make('div', { className: 'NB-classifier-publishers NB-fieldset-fields NB-classifiers' },
                            this.make_publishers(this.feed_publishers)
                        )
                    ])),
                    $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Everything by This Publisher'),
                        $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                            this.make_publisher(feed)
                        )
                    ])
                ])
            ),
            (!this.options['feed_loaded'] &&
                $.make('form', { method: 'post', className: 'NB-publisher' })),
            (this.options['training'] && $.make('div', { className: 'NB-modal-submit-bottom' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-back' }, $.entity('&laquo;') + ' Back'),
                    $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-next NB-modal-submit-save' }, 'Save & Next ' + $.entity('&raquo;')),
                    $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-grey' }, 'Close')
                ])
            ])),
            (!this.options['training'] && $.make('div', { className: 'NB-modal-submit-bottom' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('div', { className: 'NB-modal-submit-save NB-modal-submit-button NB-modal-submit-green NB-disabled' }, 'Check what you like above...')
                ])
            ]))
        ]);
    },

    make_modal_story: function () {
        var self = this;
        var story = this.story;
        var feed = this.feed;

        // NEWSBLUR.log(['Make Story', story, feed]);

        // HTML entities decoding.
        var story_title = _.string.trim($('<div/>').html(story.get('story_title')).text());
        var selected_text = this.options.selected_text || '';

        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal' }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                (this.options['training'] && $.make('div', { className: 'NB-classifier-trainer-counts' })),
                $.favicon_el(this.feed, {
                    image_class: 'NB-modal-feed-image feed_favicon',
                    emoji_class: 'NB-modal-feed-image NB-feed-emoji',
                    colored_class: 'NB-modal-feed-image NB-feed-icon-colored'
                }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title')),
                    $.make('span', { className: 'NB-modal-feed-subscribers' }, Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true))
                ])
            ]),
            (this.options['feed_loaded'] &&
                $.make('form', { method: 'post' }, [
                    // Section 1: Story Text
                    this.make_story_text_section(selected_text, story),
                    // Section 2: Story Title
                    this.make_story_title_section(story_title, story),
                    // Section 3: URL
                    this.make_story_url_section(story),
                    // Section 4: Combined Authors (story author + feed authors)
                    this.make_combined_authors_section(story),
                    // Section 5: Combined Tags (story tags + feed tags)
                    this.make_combined_tags_section(story),
                    // Section 6: Publisher
                    this.make_combined_publisher_section(feed)
                ])
            ),
            (!this.options['feed_loaded'] &&
                $.make('form', { method: 'post', className: 'NB-publisher' })),
            $.make('div', { className: 'NB-modal-submit-bottom' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('div', { className: 'NB-modal-submit-save NB-modal-submit-button NB-modal-submit-green NB-disabled' }, 'Check what you like above...')
                ])
            ])
        ]);
    },

    make_story_text_section: function (selected_text, story) {
        var self = this;
        var story_content = story.get('story_content') || '';

        return $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifier-content-section NB-classifier-text-section', 'data-section': 'text' }, [
            $.make('h5', 'Story Text'),
            $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                $.make('div', { className: 'NB-classifier-input-row' }, [
                    $.make('span', { className: 'NB-classifier-help-icon', title: 'Enter a phrase or regex pattern. You can also highlight text in the story and click Train to populate this field.' }, 'ⓘ'),
                    $.make('input', { type: 'text', value: selected_text || '', className: 'NB-classifier-text-input', placeholder: 'Enter text to match...' }),
                    $.make('div', { className: 'NB-classifier-match-type-control' }, [
                        $.make('span', { className: 'NB-match-type-option NB-match-type-exact NB-active', 'data-type': 'exact' }, 'Exact phrase'),
                        $.make('span', { className: 'NB-match-type-option NB-match-type-regex', 'data-type': 'regex' }, [
                            'Regex',
                            $.make('span', { className: 'NB-regex-info-icon' }, 'ⓘ')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-classifier-validation-inline NB-classifier-text-validation' }),
                this.make_regex_popover(),
                $.make('div', { className: 'NB-classifier-content-classifiers' }, [
                    this.make_classifier('<span class="NB-classifier-text-placeholder">Enter text above</span>', '', 'text'),
                    $.make('span', this.make_user_texts(story_content)),
                    $.make('span', this.make_user_text_regex())
                ]),
                (!NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_pro && $.make('div', { className: 'NB-classifier-text-premium-notice' }, [
                    $.make('div', { className: 'NB-classifier-text-premium-notice-text' }, [
                        'Text classifiers will be saved but not applied.',
                        $.make('br'),
                        'Upgrade to ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Archive or Premium Pro'),
                        ' to use text classifiers.'
                    ])
                ]))
            ])
        ]);
    },

    make_story_title_section: function (story_title, story) {
        var self = this;
        return $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifier-content-section NB-classifier-title-section', 'data-section': 'title' }, [
            $.make('h5', 'Story Title'),
            $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                $.make('div', { className: 'NB-classifier-input-row' }, [
                    $.make('span', { className: 'NB-classifier-help-icon', title: 'Highlight phrases in the title to train on specific words' }, 'ⓘ'),
                    $.make('input', { type: 'text', value: story_title || '', className: 'NB-classifier-title-input' }),
                    $.make('div', { className: 'NB-classifier-match-type-control' }, [
                        $.make('span', { className: 'NB-match-type-option NB-match-type-exact NB-active', 'data-type': 'exact' }, 'Exact phrase'),
                        $.make('span', { className: 'NB-match-type-option NB-match-type-regex', 'data-type': 'regex' }, [
                            'Regex',
                            $.make('span', { className: 'NB-regex-info-icon' }, 'ⓘ')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-classifier-validation-inline NB-classifier-title-validation' }),
                this.make_regex_popover(),
                $.make('div', { className: 'NB-classifier-content-classifiers' }, [
                    this.make_classifier('<span class="NB-classifier-title-placeholder">Select title phrase</span>', '', 'title'),
                    $.make('span', this.make_user_titles(story_title)),
                    $.make('span', this.make_user_title_regex())
                ])
            ])
        ]);
    },

    make_story_url_section: function (story) {
        var self = this;
        // Strip protocol from URL for display, keep domain + path
        var story_url = (story.get('story_permalink') || '').replace(/^https?:\/\//, '');

        // Only show URL section for Premium+ users
        if (!NEWSBLUR.Globals.is_premium) {
            return '';
        }

        return $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifier-content-section NB-classifier-url-section', 'data-section': 'url' }, [
            $.make('h5', 'URL'),
            $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                $.make('div', { className: 'NB-classifier-input-row' }, [
                    $.make('span', { className: 'NB-classifier-help-icon', title: 'Highlight portions of the URL to train on specific patterns' }, 'ⓘ'),
                    $.make('input', { type: 'text', value: story_url || '', className: 'NB-classifier-url-input', placeholder: 'Enter URL pattern to match...' }),
                    $.make('div', { className: 'NB-classifier-match-type-control' }, [
                        $.make('span', { className: 'NB-match-type-option NB-match-type-exact NB-active', 'data-type': 'exact' }, 'Exact phrase'),
                        $.make('span', { className: 'NB-match-type-option NB-match-type-regex', 'data-type': 'regex' }, [
                            'Regex',
                            $.make('span', { className: 'NB-regex-info-icon' }, 'ⓘ')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-classifier-validation-inline NB-classifier-url-validation' }),
                this.make_regex_popover(),
                $.make('div', { className: 'NB-classifier-content-classifiers' }, [
                    this.make_classifier('<span class="NB-classifier-url-placeholder">Select URL portion above</span>', '', 'url'),
                    $.make('span', this.make_user_urls()),
                    $.make('span', this.make_user_url_regex())
                ]),
                (!NEWSBLUR.Globals.is_pro && $.make('div', { className: 'NB-classifier-url-pro-notice NB-classifier-pro-notice' }, [
                    $.make('div', { className: 'NB-classifier-pro-notice-text' }, [
                        'URL regex filters will be saved but not applied.',
                        $.make('br'),
                        'Upgrade to ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Pro'),
                        ' to use regex filters.'
                    ])
                ]))
            ])
        ]);
    },

    make_regex_popover: function () {
        return $.make('div', { className: 'NB-classifier-regex-popover' }, [
            $.make('div', { className: 'NB-classifier-regex-popover-content' }, [
                $.make('div', { className: 'NB-classifier-regex-popover-columns' }, [
                    $.make('div', { className: 'NB-classifier-regex-popover-column' }, [
                        $.make('div', { className: 'NB-regex-tip-category' }, 'Word Matching'),
                        $.make('ul', { className: 'NB-classifier-regex-popover-list' }, [
                            $.make('li', [$.make('code', '\\bcat\\b'), ' — Whole word "cat" only']),
                            $.make('li', [$.make('code', '\\bthe cat\\b'), ' — Exact phrase "the cat"']),
                            $.make('li', [$.make('code', 'cat|dog|bird'), ' — Any of these words']),
                            $.make('li', [$.make('code', '\\b(new|latest) release\\b'), ' — "new release" or "latest release"']),
                            $.make('li', [$.make('code', 'colou?r'), ' — "color" or "colour" (optional letter)'])
                        ]),
                        $.make('div', { className: 'NB-regex-tip-category' }, 'Position & Greedy'),
                        $.make('ul', { className: 'NB-classifier-regex-popover-list' }, [
                            $.make('li', [$.make('code', '^Breaking'), ' — Starts with "Breaking"']),
                            $.make('li', [$.make('code', 'update$'), ' — Ends with "update"']),
                            $.make('li', [$.make('code', '^\\[Video\\]'), ' — Starts with "[Video]"']),
                            $.make('li', [$.make('code', 'breaking.*news'), ' — "breaking" then anything then "news"']),
                            $.make('li', [$.make('code', '".*?"'), ' — Non-greedy: each quoted phrase'])
                        ])
                    ]),
                    $.make('div', { className: 'NB-classifier-regex-popover-column' }, [
                        $.make('div', { className: 'NB-regex-tip-category' }, 'Numbers & Symbols'),
                        $.make('ul', { className: 'NB-classifier-regex-popover-list' }, [
                            $.make('li', [$.make('code', 'v\\d+'), ' — "v" followed by numbers (v1, v2, v10)']),
                            $.make('li', [$.make('code', '\\$\\d+'), ' — Dollar amounts ($5, $100)']),
                            $.make('li', [$.make('code', '#\\w+'), ' — Hashtags (#news, #tech)']),
                            $.make('li', [$.make('code', '@\\w+'), ' — Mentions (@user, @company)']),
                            $.make('li', [$.make('code', '^\\d+\\.'), ' — Starts with number and period'])
                        ]),
                        $.make('div', { className: 'NB-regex-tip-category' }, 'Exclusions & Advanced'),
                        $.make('ul', { className: 'NB-classifier-regex-popover-list' }, [
                            $.make('li', [$.make('code', '^(?!.*sponsor)'), ' — NOT containing "sponsor"']),
                            $.make('li', [$.make('code', '^(?!.*\\bad\\b)'), ' — NOT containing word "ad"']),
                            $.make('li', [$.make('code', '\\d{4}'), ' — Exactly 4 digits (years)']),
                            $.make('li', [$.make('code', '.{50,}'), ' — At least 50 characters']),
                            $.make('li', [$.make('code', '[A-Z]{2,}'), ' — Two or more capital letters'])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-classifier-regex-popover-note' }, 'All patterns are case-insensitive by default. Use \\b for word boundaries to avoid partial matches.')
            ])
        ]);
    },

    make_combined_authors_section: function (story) {
        var story_author = story.story_authors();
        var feed_authors = this.feed_authors || [];

        // Filter out story author from feed authors to avoid duplication
        var other_authors = feed_authors.filter(function (author_obj) {
            var author = typeof author_obj === 'string' ? author_obj : author_obj[0];
            return author !== story_author;
        });

        // Build combined authors list
        var has_story_author = story_author && story_author.length > 0;
        var has_other_authors = other_authors.length > 0;

        if (!has_story_author && !has_other_authors) {
            return '';  // No authors to show
        }

        var $story_authors = has_story_author ?
            $.make('div', { className: 'NB-classifier-this-story' }, this.make_authors([story_author])) : '';
        var $feed_authors = has_other_authors ?
            $.make('div', { className: 'NB-classifier-feed-items' }, this.make_authors(other_authors)) : '';

        return $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
            $.make('h5', 'Authors'),
            $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                $story_authors,
                $feed_authors
            ])
        ]);
    },

    make_combined_tags_section: function (story) {
        var story_tags = story.get('story_tags') || [];
        var feed_tags = this.feed_tags || [];

        // Get story tag names for comparison
        var story_tag_names = story_tags.map(function (tag) {
            return typeof tag === 'string' ? tag.toLowerCase() : tag[0].toLowerCase();
        });

        // Filter out story tags from feed tags to avoid duplication
        var other_tags = feed_tags.filter(function (tag_obj) {
            var tag = typeof tag_obj === 'string' ? tag_obj : tag_obj[0];
            return !_.contains(story_tag_names, tag.toLowerCase());
        });

        // Build combined tags list
        var has_story_tags = story_tags.length > 0;
        var has_other_tags = other_tags.length > 0;

        if (!has_story_tags && !has_other_tags) {
            return '';  // No tags to show
        }

        var $story_tags = has_story_tags ?
            $.make('div', { className: 'NB-classifier-this-story' }, this.make_tags(story_tags)) : '';
        var $feed_tags = has_other_tags ?
            $.make('div', { className: 'NB-classifier-feed-items' }, this.make_tags(other_tags)) : '';

        return $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
            $.make('h5', 'Categories &amp; Tags'),
            $.make('div', { className: 'NB-classifier-tags NB-fieldset-fields NB-classifiers' }, [
                $story_tags,
                $feed_tags
            ])
        ]);
    },

    make_combined_publisher_section: function (feed) {
        var has_other_publishers = this.feed_publishers && this.feed_publishers.length > 0;

        var $other_publishers = has_other_publishers ?
            $.make('div', { className: 'NB-classifier-feed-items' }, this.make_publishers(this.feed_publishers)) : '';

        return $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
            $.make('h5', 'Publisher'),
            $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                this.make_publisher(feed),
                $other_publishers
            ])
        ]);
    },

    make_modal_title: function () {
        var $modal_title = $('.NB-modal-title', this.$modal);

        var $title = $.make('div', [
            'What do you ',
            $.make('b', { className: 'NB-classifier-title-like' }, 'like'),
            ' and ',
            $.make('b', { className: 'NB-classifier-title-dislike' }, 'dislike'),
            ' about this ',
            (this.flags['publisher'] && 'site'),
            (this.flags['story'] && 'story'),
            '?'
        ]);

        $modal_title.html($title);
    },

    make_modal_trainer_count: function () {
        var $count = $('.NB-classifier-trainer-counts', this.$modal);
        var count = this.trainer_iterator + 1;
        var total = this.trainer_data.length;
        $count.html(count + '/' + total);
    },

    make_user_titles: function (existing_title) {
        var $titles = [];
        var titles = _.keys(this.user_classifiers.titles);

        _.each(titles, _.bind(function (title) {
            // Check if title text is in the story title
            if (!existing_title || existing_title.toLowerCase().indexOf(title.toLowerCase()) != -1) {
                var $title = this.make_classifier(title, title, 'title');
                $titles.push($title);
            }
        }, this));

        return $titles;
    },

    make_user_texts: function (story_content) {
        var $texts = [];
        var texts = _.keys(this.user_classifiers.texts || {});

        _.each(texts, _.bind(function (text) {
            // Check if text is in the story content (show all if no story_content provided)
            if (!story_content || story_content.toLowerCase().indexOf(text.toLowerCase()) != -1) {
                var $text = this.make_classifier(text, text, 'text');
                $texts.push($text);
            }
        }, this));

        return $texts;
    },

    make_user_title_regex: function () {
        var $regexes = [];
        var regex_classifiers = this.user_classifiers.title_regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            var $regex = this.make_classifier(pattern, pattern, 'title', null, null, true);
            $regexes.push($regex);
        }, this));

        return $regexes;
    },

    make_user_text_regex: function () {
        var $regexes = [];
        // Support both new 'text_regex' and legacy 'regex' storage
        var regex_classifiers = this.user_classifiers.text_regex || this.user_classifiers.regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            var $regex = this.make_classifier(pattern, pattern, 'text', null, null, true);
            $regexes.push($regex);
        }, this));

        return $regexes;
    },

    make_user_urls: function () {
        var $urls = [];
        var url_classifiers = this.user_classifiers.urls || {};

        _.each(_.keys(url_classifiers), _.bind(function (pattern) {
            var $url = this.make_classifier(pattern, pattern, 'url');
            $urls.push($url);
        }, this));

        return $urls;
    },

    make_user_url_regex: function () {
        var $regexes = [];
        var regex_classifiers = this.user_classifiers.url_regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            var $regex = this.make_classifier(pattern, pattern, 'url', null, null, true);
            $regexes.push($regex);
        }, this));

        return $regexes;
    },

    make_authors: function (authors) {
        var $authors = [];

        for (var a in authors) {
            var author_obj = authors[a];
            if (typeof author_obj == 'string') {
                var author = author_obj;
                var author_count;
            } else {
                var author = author_obj[0];
                var author_count = author_obj[1];
            }

            if (!author) continue;

            var $author = this.make_classifier(author, author, 'author', author_count);
            $authors.push($author);
        }
        return $authors;
    },

    make_user_authors: function () {
        var $authors = [];
        var user_authors = _.keys(this.user_classifiers.authors);
        var feed_authors = _.map(this.feed_authors, function (author) { return author[0]; });
        var authors = _.reduce(user_authors, function (memo, author, i) {
            if (!_.contains(feed_authors, author)) return memo.concat(author);
            return memo;
        }, []);

        return this.make_authors(authors);
    },

    make_tags: function (tags) {
        var $tags = [];

        for (var t in tags) {
            var tag_obj = tags[t];
            if (typeof tag_obj == 'string') {
                var tag = tag_obj;
                var tag_count;
            } else {
                var tag = tag_obj[0];
                var tag_count = tag_obj[1];
            }

            if (!tag) continue;

            var $tag = this.make_classifier(tag, tag, 'tag', tag_count);
            $tags.push($tag);
        }

        return $tags;
    },

    make_user_tags: function () {
        var $tags = [];
        var user_tags = _.keys(this.user_classifiers.tags);
        var feed_tags = _.map(this.feed_tags, function (tag) { return tag[0]; });
        var tags = _.reduce(user_tags, function (memo, tag, i) {
            if (!_.contains(feed_tags, tag)) return memo.concat(tag);
            return memo;
        }, []);

        return this.make_tags(tags);
    },

    make_publishers: function (publishers) {
        var $publishers = publishers.map(_.bind(function (publisher) {
            return this.make_publisher(publisher);
        }, this));

        return $publishers;
    },

    make_publisher: function (publisher) {
        var $publisher = this.make_classifier(_.string.truncate(publisher.get('feed_title'), 50),
            publisher.id, 'feed', publisher.get('story_count'), publisher);
        return $publisher;
    },

    make_classifier: function (classifier_title, classifier_value, classifier_type, classifier_count, classifier, is_regex) {
        var score = 0;
        // is_regex can be passed explicitly, or detected from classifier_type === 'regex'
        if (is_regex === undefined) {
            is_regex = classifier_type === 'regex';
        }
        // Storage key: regex classifiers use type + '_regex', others use type + 's'
        var storage_key = is_regex ? classifier_type + '_regex' : classifier_type + 's';
        // Input name: regex classifiers save as 'like_title_regex' or 'like_text_regex'
        var input_type = is_regex ? classifier_type + '_regex' : classifier_type;

        // NEWSBLUR.log(['classifiers', this.user_classifiers, classifier_value, this.user_classifiers[classifier_type+'s']]);
        if (this.user_classifiers[storage_key] &&
            classifier_value in this.user_classifiers[storage_key]) {
            score = this.user_classifiers[storage_key][classifier_value];
        }

        // Label shows the display type (Text, Title, etc.) not "Regex"
        var classifier_type_title = Inflector.capitalize(classifier_type == 'feed' ? 'site' : classifier_type);

        var css_class = 'NB-classifier NB-classifier-' + classifier_type;
        if (is_regex) {
            css_class += ' NB-classifier-regex';
        }

        var $classifier = $.make('span', { className: 'NB-classifier-container' }, [
            $.make('span', { className: css_class }, [
                $.make('input', {
                    type: 'checkbox',
                    className: 'NB-classifier-input-like',
                    name: 'like_' + input_type,
                    value: classifier_value
                }),
                $.make('input', {
                    type: 'checkbox',
                    className: 'NB-classifier-input-dislike',
                    name: 'dislike_' + input_type,
                    value: classifier_value
                }),
                $.make('div', { className: 'NB-classifier-icon-like' }),
                $.make('div', { className: 'NB-classifier-icon-dislike' }, [
                    $.make('div', { className: 'NB-classifier-icon-dislike-inner' })
                ]),
                $.make('label', [
                    (classifier_type == 'feed' && $.favicon_el(classifier)),
                    $.make('b', classifier_type_title + ': '),
                    (is_regex && $.make('span', { className: 'NB-classifier-regex-badge' }, 'REGEX')),
                    $.make('span', classifier_title)
                ])
            ]),
            (classifier_count && $.make('span', { className: 'NB-classifier-count' }, [
                '&times;&nbsp;',
                classifier_count
            ]))
        ]);

        if (score > 0) {
            $('.NB-classifier', $classifier).addClass('NB-classifier-like');
            $('.NB-classifier-input-like', $classifier).prop('checked', true);
        } else if (score < 0) {
            $('.NB-classifier', $classifier).addClass('NB-classifier-dislike');
            $('.NB-classifier-input-dislike', $classifier).prop('checked', true);
        }

        $('.NB-classifier', $classifier).bind('mouseenter', function (e) {
            $(e.currentTarget).addClass('NB-classifier-hover-like');
        }).bind('mouseleave', function (e) {
            $(e.currentTarget).removeClass('NB-classifier-hover-like');
        });

        $('.NB-classifier-icon-dislike', $classifier).bind('mouseenter', function (e) {
            $('.NB-classifier', $classifier).addClass('NB-classifier-hover-dislike');
        }).bind('mouseleave', function (e) {
            $('.NB-classifier', $classifier).removeClass('NB-classifier-hover-dislike');
        });

        return $classifier;
    },

    change_classifier: function ($classifier, classifier_opinion) {
        var $like = $('.NB-classifier-input-like', $classifier);
        var $dislike = $('.NB-classifier-input-dislike', $classifier);

        var $save = $('.NB-modal-submit-save', this.$modal);
        var $close = $('.NB-modal-submit-grey', this.$modal);
        var $back = $('.NB-modal-submit-back', this.$modal);

        if (classifier_opinion == 'like') {
            if ($classifier.is('.NB-classifier-like')) {
                $classifier.removeClass('NB-classifier-like');
                $dislike.prop('checked', false);
                $like.prop('checked', false);
            } else {
                $classifier.removeClass('NB-classifier-dislike');
                $classifier.addClass('NB-classifier-like');
                $dislike.prop('checked', false);
                $like.prop('checked', true);
            }
        } else if (classifier_opinion == 'dislike') {
            if ($classifier.is('.NB-classifier-dislike')) {
                $classifier.removeClass('NB-classifier-dislike');
                $like.prop('checked', false);
                $dislike.prop('checked', false);
            } else {
                $classifier.removeClass('NB-classifier-like');
                $classifier.addClass('NB-classifier-dislike');
                $like.prop('checked', false);
                $dislike.prop('checked', true);
            }
        }

        if (this.options['training']) {
            $close.text('Save & Close');
        } else {
            $save.removeClass("NB-disabled").text('Save Training');
        }
        // NEWSBLUR.log(['change_classifier', classifier_opinion, $classifier, $like.is(':checked'), $dislike.is(':checked')]);
    },

    end: function () {
        this.model.preference('has_trained_intelligence', true);
        NEWSBLUR.reader.check_hide_getting_started();
        $.modal.close();
    },

    // ==========
    // = Events =
    // ==========

    handle_text_highlight: function () {
        var self = this;

        // Handle story text input - auto-update classifier as user types
        var $text_section = $('.NB-classifier-text-section', this.$modal);
        var $text_input = $('.NB-classifier-text-input', this.$modal);
        var $text_placeholder = $('.NB-classifier-text-placeholder', this.$modal);
        var $text_classifier = $text_placeholder.parents('.NB-classifier').eq(0);
        var $text_checkboxes = $('.NB-classifier-input-like, .NB-classifier-input-dislike', $text_classifier);
        var $text_validation = $('.NB-classifier-text-validation', this.$modal);

        var update_text_classifier = function () {
            var text = $.trim($text_input.val());
            var is_regex_mode = $text_section.hasClass('NB-classifier-section-regex-active');
            $text_validation.empty();

            if (text.length) {
                $text_placeholder.text(text);
                $text_placeholder.css('font-style', 'normal');
                $text_checkboxes.val(text);
                // Auto thumbs-up if not already rated
                if (!$text_classifier.is('.NB-classifier-like,.NB-classifier-dislike')) {
                    self.change_classifier($text_classifier, 'like');
                }

                // Validate based on mode
                if (self.story) {
                    var story_content = $('<div>').html(self.story.get('story_content') || '').text();
                    var is_full_match = self.check_full_content_match(text, story_content, is_regex_mode);

                    if (is_regex_mode) {
                        // Regex validation
                        var validation_result = self.validate_regex(text);
                        if (validation_result.valid) {
                            $text_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-valid' }, '✓ Valid'));
                            if (validation_result.regex.test(story_content)) {
                                $text_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-match' }, '✓ Matches story'));
                            } else {
                                $text_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-no-match' }, 'No match in story'));
                            }
                        } else {
                            $text_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-error' }, validation_result.error));
                        }
                    } else {
                        // Exact phrase validation
                        if (story_content.toLowerCase().indexOf(text.toLowerCase()) !== -1) {
                            $text_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-match' }, '✓ Found in story'));
                        } else {
                            $text_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-no-match' }, 'Not found in story'));
                        }
                    }

                    // Warn if matching entire content
                    if (is_full_match) {
                        $text_validation.append($.make('div', { className: 'NB-regex-full-match-warning' }, [
                            $.make('span', { className: 'NB-regex-warning-icon' }, '⚠'),
                            $.make('span', { className: 'NB-regex-warning-text' }, 'This matches the entire story text and will only match this exact story. Consider using a shorter phrase or pattern.')
                        ]));
                    }
                }
            } else {
                $text_placeholder.text('Enter text above');
                $text_placeholder.css('font-style', 'italic');
            }
        };

        $text_input.on('input keyup', update_text_classifier);

        // If pre-populated (from selected text), trigger update immediately
        if ($text_input.val()) {
            update_text_classifier();
        }

        // Store update function for mode switching
        this.update_text_classifier = update_text_classifier;

        // Handle story title input
        var $title_section = $('.NB-classifier-title-section', this.$modal);
        var $title_input = $('.NB-classifier-title-input', this.$modal);
        var $title_placeholder = $('.NB-classifier-title-placeholder', this.$modal);
        var $title_classifier = $title_placeholder.parents('.NB-classifier').eq(0);
        var $title_checkboxes = $('.NB-classifier-input-like, .NB-classifier-input-dislike', $title_classifier);
        var $title_validation = $('.NB-classifier-title-validation', this.$modal);

        var last_title_selection = '';
        var update_title = function (e) {
            var text = $.trim($title_input.getSelection().text);
            var is_regex_mode = $title_section.hasClass('NB-classifier-section-regex-active');

            // Only update when selection has actually changed (not on every mousemove/hover)
            // For regex mode, also trigger on input events
            if (is_regex_mode) {
                text = $.trim($title_input.val());
                // Clear the selection tracking for regex mode
                last_title_selection = '';
            }

            if (text.length && (is_regex_mode || (text != last_title_selection && $title_placeholder.text() != text))) {
                if (!is_regex_mode) {
                    last_title_selection = text;
                }
                $title_placeholder.text(text);
                $title_placeholder.css('font-style', 'normal');
                $title_checkboxes.val(text);
                if (!$title_classifier.is('.NB-classifier-like,.NB-classifier-dislike')) {
                    self.change_classifier($title_classifier, 'like');
                }

                // Validate based on mode
                $title_validation.empty();
                var story_title = self.story ? self.story.get('story_title') || '' : '';
                var is_full_match = self.check_full_content_match(text, story_title, is_regex_mode);

                if (is_regex_mode) {
                    // Regex validation
                    var validation_result = self.validate_regex(text);
                    if (validation_result.valid) {
                        $title_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-valid' }, '✓ Valid'));
                        if (validation_result.regex.test(story_title)) {
                            $title_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-match' }, '✓ Matches title'));
                        } else {
                            $title_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-no-match' }, 'No match in title'));
                        }
                    } else {
                        $title_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-error' }, validation_result.error));
                    }
                } else {
                    // Exact phrase - only show badge when NOT found (since selected text is usually found)
                    if (story_title.toLowerCase().indexOf(text.toLowerCase()) === -1) {
                        $title_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-no-match' }, 'Not found in title'));
                    }
                }

                // Warn if matching entire title
                if (is_full_match) {
                    $title_validation.append($.make('div', { className: 'NB-regex-full-match-warning' }, [
                        $.make('span', { className: 'NB-regex-warning-icon' }, '⚠'),
                        $.make('span', { className: 'NB-regex-warning-text' }, 'This matches the entire title and will only match this exact story. Select a portion of the title instead.')
                    ]));
                }
            }
        };

        $title_input
            .on('select keyup mouseup input', update_title);
        $title_checkboxes.val($title_input.val());

        // Store update function for mode switching
        this.update_title_classifier = update_title;

        // Clicking the placeholder does nothing - user must select text first
        $title_placeholder.parents('.NB-classifier').bind('click', function (e) {
            // Prevent default classifier toggle behavior if placeholder text is showing
            if ($title_placeholder.text() === 'Select title phrase') {
                e.preventDefault();
                return false;
            }
        });

        // Handle URL input (for Premium+ users only)
        var $url_section = $('.NB-classifier-url-section', this.$modal);
        if ($url_section.length) {
            var $url_input = $('.NB-classifier-url-input', this.$modal);
            var $url_placeholder = $('.NB-classifier-url-placeholder', this.$modal);
            var $url_classifier = $url_placeholder.parents('.NB-classifier').eq(0);
            var $url_checkboxes = $('.NB-classifier-input-like, .NB-classifier-input-dislike', $url_classifier);
            var $url_validation = $('.NB-classifier-url-validation', this.$modal);

            var last_url_selection = '';
            var update_url = function (e) {
                var is_regex_mode = $url_section.hasClass('NB-classifier-section-regex-active');
                var text;

                if (is_regex_mode) {
                    // In regex mode, get text from input value (user can type or select)
                    text = $.trim($url_input.val());
                    // Clear selection tracking for regex mode
                    last_url_selection = '';
                } else {
                    // In exact mode, get text from selection
                    text = $.trim($url_input.getSelection().text);
                }

                // Only update when selection has actually changed (for exact mode) or on input event (for regex mode)
                if (text.length && (is_regex_mode || (text != last_url_selection && $url_placeholder.text() != text))) {
                    if (!is_regex_mode) {
                        last_url_selection = text;
                    }
                    $url_placeholder.text(text);
                    $url_placeholder.css('font-style', 'normal');
                    $url_checkboxes.val(text);
                    if (!$url_classifier.is('.NB-classifier-like,.NB-classifier-dislike')) {
                        self.change_classifier($url_classifier, 'like');
                    }

                    // Validate based on mode
                    $url_validation.empty();
                    var story_url = self.story ? (self.story.get('story_permalink') || '') : '';
                    var is_full_match = self.check_full_content_match(text, story_url, is_regex_mode);

                    if (is_regex_mode) {
                        // Regex validation
                        var validation_result = self.validate_regex(text);
                        if (validation_result.valid) {
                            $url_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-valid' }, '✓ Valid'));
                            if (validation_result.regex.test(story_url)) {
                                $url_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-match' }, '✓ Matches URL'));
                            } else {
                                $url_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-no-match' }, 'No match in URL'));
                            }
                        } else {
                            $url_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-error' }, validation_result.error));
                        }
                    } else {
                        // Exact phrase validation - substring check
                        if (story_url.toLowerCase().indexOf(text.toLowerCase()) >= 0) {
                            $url_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-match' }, '✓ Found in URL'));
                        } else {
                            $url_validation.append($.make('span', { className: 'NB-regex-badge NB-regex-badge-no-match' }, 'Not found in URL'));
                        }
                    }

                    // Show warning if matching the entire URL
                    if (is_full_match) {
                        $url_validation.append($.make('div', { className: 'NB-regex-full-match-warning' }, [
                            $.make('span', { className: 'NB-regex-warning-icon' }, '⚠'),
                            $.make('span', { className: 'NB-regex-warning-text' }, 'This matches the entire URL and will only match this exact story. Select a portion of the URL instead.')
                        ]));
                    }
                }
            };

            $url_input.on('select keyup mouseup input', update_url);

            // Don't initialize checkbox value - user must select a portion
            // $url_checkboxes.val($url_input.val());

            // Store update function for mode switching
            this.update_url_classifier = update_url;

            // Clicking the placeholder does nothing - user must select URL text first
            $url_placeholder.parents('.NB-classifier').bind('click', function (e) {
                if ($url_placeholder.text() === 'Select URL portion above') {
                    e.preventDefault();
                    return false;
                }
            });
        }
    },

    // ================================
    // = Segmented Control & Regex   =
    // ================================

    handle_match_type_control: function () {
        var self = this;
        var $modal = this.$modal;

        // Handle segmented control clicks
        $modal.on('click', '.NB-match-type-option', function (e) {
            var $option = $(this);
            var $section = $option.closest('.NB-classifier-content-section');
            var section_type = $section.data('section');  // 'text' or 'title'
            var match_type = $option.data('type');
            // Only target the placeholder classifier, not existing user classifiers
            var $placeholder = $section.find('.NB-classifier-' + section_type + '-placeholder');
            var $classifier = $placeholder.closest('.NB-classifier');
            var $label = $classifier.find('label');
            var $input = $section.find('.NB-classifier-' + section_type + '-input');

            // Update active state
            $section.find('.NB-match-type-option').removeClass('NB-active');
            $option.addClass('NB-active');

            // Toggle section class for showing/hiding inputs (CSS controls visibility)
            if (match_type === 'regex') {
                $section.addClass('NB-classifier-section-regex-active');
                $section.find('.NB-classifier-pro-notice').addClass('NB-visible');

                // Update input styling for regex mode
                $input.addClass('NB-classifier-input-regex-mode');
                if (section_type === 'text') {
                    $input.attr('placeholder', 'e.g., \\bcat\\b or dog|bird');
                } else if (section_type === 'title') {
                    $input.attr('placeholder', 'e.g., \\bbreaking\\b or urgent|alert');
                } else if (section_type === 'url') {
                    $input.attr('placeholder', 'e.g., /news/\\d+ or /category/');
                }

                // Change classifier to regex type for saving
                $classifier.addClass('NB-classifier-regex');
                var $like = $classifier.find('.NB-classifier-input-like');
                var $dislike = $classifier.find('.NB-classifier-input-dislike');
                $like.attr('name', 'like_' + section_type + '_regex');
                $dislike.attr('name', 'dislike_' + section_type + '_regex');

                // Add small "REGEX" badge after the label text (keep "Text:" or "Title:")
                var $existing_badge = $label.find('.NB-classifier-regex-badge');
                if (!$existing_badge.length) {
                    $label.find('b').after($.make('span', { className: 'NB-classifier-regex-badge' }, 'REGEX'));
                }
            } else {
                $section.removeClass('NB-classifier-section-regex-active');
                $section.find('.NB-classifier-regex-popover').removeClass('NB-visible');
                $section.find('.NB-classifier-pro-notice').removeClass('NB-visible');

                // Update input styling for exact mode
                $input.removeClass('NB-classifier-input-regex-mode');
                if (section_type === 'text') {
                    $input.attr('placeholder', 'Enter text to match...');
                } else if (section_type === 'url') {
                    $input.attr('placeholder', 'Enter URL pattern to match...');
                } else {
                    $input.attr('placeholder', '');
                }

                // Change classifier back to original type
                $classifier.removeClass('NB-classifier-regex');
                var $like = $classifier.find('.NB-classifier-input-like');
                var $dislike = $classifier.find('.NB-classifier-input-dislike');
                $like.attr('name', 'like_' + section_type);
                $dislike.attr('name', 'dislike_' + section_type);

                // Remove regex badge
                $label.find('.NB-classifier-regex-badge').remove();
            }

            // Re-trigger validation with new mode
            if (section_type === 'text' && self.update_text_classifier) {
                self.update_text_classifier();
            } else if (section_type === 'title' && self.update_title_classifier) {
                self.update_title_classifier();
            } else if (section_type === 'url' && self.update_url_classifier) {
                self.update_url_classifier();
            }
        });
    },

    handle_regex_input: function () {
        var self = this;
        var $modal = this.$modal;

        // Handle match type segmented control
        this.handle_match_type_control();

        // Handle regex info icon hover - show popover on mouseenter, hide on mouseleave
        // Use portal approach: move popover to body for proper overflow
        $modal.on('mouseenter', '.NB-regex-info-icon', function (e) {
            var $icon = $(this);
            var $section = $icon.closest('.NB-classifier-content-section');

            // Get popover - either from stored reference or find in section
            var $popover = $icon.data('popover') || $section.find('.NB-classifier-regex-popover');

            if (!$popover || !$popover.length) return;

            // Close any other open popovers
            $('.NB-classifier-regex-popover.NB-visible').removeClass('NB-visible');

            // Get icon position for popover placement
            var iconRect = $icon[0].getBoundingClientRect();

            // Move popover to body and position it
            $popover.appendTo('body');
            $popover.css({
                position: 'fixed',
                top: iconRect.bottom + 8,
                right: window.innerWidth - iconRect.right,
                left: 'auto',
                bottom: 'auto'
            });

            // Show this popover
            $popover.addClass('NB-visible');

            // Store reference for subsequent hovers
            $icon.data('popover', $popover);
            $icon.data('section', $section);
        });

        // Hide popover when mouse leaves both icon and popover
        $modal.on('mouseleave', '.NB-regex-info-icon', function (e) {
            var $icon = $(this);
            var $popover = $icon.data('popover');

            if (!$popover) return;

            // Small delay to allow mouse to move to popover
            setTimeout(function () {
                if ($popover && !$popover.is(':hover') && !$icon.is(':hover')) {
                    $popover.removeClass('NB-visible');
                }
            }, 100);
        });

        $(document).on('mouseleave', '.NB-classifier-regex-popover', function (e) {
            var $popover = $(this);

            // Small delay to check if mouse moved back to icon
            setTimeout(function () {
                if ($popover && !$popover.is(':hover')) {
                    $popover.removeClass('NB-visible');
                }
            }, 100);
        });
    },

    validate_regex: function (pattern) {
        if (!pattern || pattern.trim() === '') {
            return { valid: false, error: 'Enter a pattern' };
        }

        try {
            // Default case-insensitive
            var regex = new RegExp(pattern, 'i');
            return { valid: true, regex: regex };
        } catch (e) {
            return { valid: false, error: 'Invalid regex: ' + e.message };
        }
    },

    check_full_content_match: function (pattern, content, is_regex_mode) {
        if (!pattern || !content) return false;

        var pattern_lower = pattern.toLowerCase().trim();
        var content_lower = content.toLowerCase().trim();

        // For exact phrase mode: check if pattern equals the entire content
        if (!is_regex_mode) {
            return pattern_lower === content_lower;
        }

        // For regex mode: check if the regex matches the entire content
        // by testing if the match is essentially the full content
        try {
            var regex = new RegExp(pattern, 'i');
            var match = content.match(regex);
            if (match && match[0]) {
                // If match is 90%+ of content length, consider it a full match
                return match[0].length >= content.length * 0.9;
            }
        } catch (e) {
            return false;
        }
        return false;
    },

    get_regex_matches: function (regex, content) {
        var matches = [];
        // Strip HTML for preview
        var text_content = $('<div>').html(content).text();
        var global_regex = new RegExp(regex.source, 'gi');
        var match;

        while ((match = global_regex.exec(text_content)) !== null) {
            matches.push({
                text: match[0],
                index: match.index,
                length: match[0].length
            });
            if (matches.length >= 10) break;  // Limit to 10 matches
        }
        return matches;
    },

    render_regex_preview: function ($preview, content, matches, label) {
        if (!matches.length) {
            $preview.html('<span class="NB-preview-label">' + label + ':</span> <span class="NB-no-matches">No matches</span>');
            return;
        }

        // Strip HTML and limit to first 300 chars for content, full for title
        var max_chars = label === 'Title' ? 200 : 300;
        var text_content = $('<div>').html(content).text().substring(0, max_chars);
        var highlighted = '<span class="NB-preview-label">' + label + ':</span> ';
        var last_index = 0;

        _.each(matches, function (match) {
            if (match.index < max_chars) {
                highlighted += _.escape(text_content.substring(last_index, match.index));
                highlighted += '<mark class="NB-regex-match">' + _.escape(match.text) + '</mark>';
                last_index = match.index + match.length;
            }
        });
        highlighted += _.escape(text_content.substring(last_index));

        $preview.html(highlighted + (content.length > max_chars ? '...' : ''));
    },

    handle_cancel: function () {
        var $cancel = $('.NB-modal-cancel', this.$modal);

        $cancel.click(function (e) {
            e.preventDefault();
            $.modal.close();
        });
    },

    handle_clicks: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-classifier-premium-link' }, function ($t, $p) {
            e.preventDefault();
            self.close(function () {
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
        });

        if (this.options['training']) {
            $.targetIs(e, { tagSelector: '.NB-modal-submit-begin' }, function ($t, $p) {
                e.preventDefault();
                self.load_next_feed_in_trainer();
            });
            $.targetIs(e, { tagSelector: '.NB-modal-submit-save.NB-modal-submit-next' }, function ($t, $p) {
                e.preventDefault();
                self.save(true);
                self.load_next_feed_in_trainer();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-back' }, function ($t, $p) {
                e.preventDefault();
                self.load_previous_feed_in_trainer();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-reset' }, function ($t, $p) {
                e.preventDefault();
                self.retrain_all_sites();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-grey' }, function ($t, $p) {
                e.preventDefault();
                self.save();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-end' }, function ($t, $p) {
                e.preventDefault();
                NEWSBLUR.reader.force_feed_refresh();
                self.end();
                // NEWSBLUR.reader.open_feed(self.feed_id, true);
                // TODO: Update counts in active feed.
            });
        } else {
            $.targetIs(e, { tagSelector: '.NB-modal-submit-save:not(.NB-modal-submit-next)' }, function ($t, $p) {
                e.preventDefault();
                self.save();
                return false;
            });
        }

        var stop = false;
        $.targetIs(e, { tagSelector: '.NB-classifier-icon-dislike' }, function ($t, $p) {
            e.preventDefault();
            stop = true;
            var $classifier = $t.closest('.NB-classifier');
            var value = $('.NB-classifier-input-like', $classifier).val();
            if (value) {
                self.change_classifier($classifier, 'dislike');
            }
        });
        if (stop) return;
        $.targetIs(e, { tagSelector: '.NB-classifier' }, function ($t, $p) {
            e.preventDefault();
            var value = $('.NB-classifier-input-like', $t).val();
            if (value) {
                self.change_classifier($t, 'like');
            }
        });
    },

    serialize_classifier: function () {
        var data = {};
        $('.NB-classifier', this.$modal).each(function () {
            var value = $('.NB-classifier-input-like', this).val();
            if ($('.NB-classifier-input-like, .NB-classifier-input-dislike', this).is(':checked')) {
                var name = $('input:checked', this).attr('name');
                if (!data[name]) data[name] = [];
                data[name].push(value);
            } else {
                var name = 'remove_' + $('.NB-classifier-input-like', this).attr('name');
                if (!data[name]) data[name] = [];
                data[name].push(value);
            }
        });

        data['feed_id'] = this.feed_id;
        if (this.story_id) {
            data['story_id'] = this.story_id;
        }
        return data;
    },

    save: function (keep_modal_open) {
        var self = this;
        var $save = $('.NB-modal-submit-save', this.$modal);
        var data = this.serialize_classifier();
        var feed_id = this.feed_id;
        if (this.options.social_feed && this.story_id) {
            feed_id = this.original_feed_id;
        }

        if (this.options['training']) {
            this.cache[this.feed_id] = this.$modal.clone();
        }
        $save.text('Saving...');
        $save.addClass('NB-disabled');

        this.update_opinions();
        NEWSBLUR.assets.recalculate_story_scores(feed_id);
        NEWSBLUR.assets.stories.trigger('render:intelligence');
        this.model.save_classifier(data, function () {
            if (!keep_modal_open) {
                NEWSBLUR.reader.feed_unread_count(feed_id);
                $.modal.close();
            }
        });
    },

    update_opinions: function () {
        var self = this;
        var feed_id = this.feed_id;

        $('input[type=checkbox]', this.$modal).each(function () {
            var $this = $(this);
            var name = $this.attr('name').replace(/^(dis)?like_/, '');
            var score = /^dislike/.test($this.attr('name')) ? -1 : 1;
            var value = $this.val();
            var checked = $this.prop('checked');

            if (checked) {
                if (name == 'tag') {
                    self.model.classifiers[feed_id].tags[value] = score;
                } else if (name == 'title') {
                    self.model.classifiers[feed_id].titles[value] = score;
                } else if (name == 'title_regex') {
                    if (!self.model.classifiers[feed_id].title_regex) {
                        self.model.classifiers[feed_id].title_regex = {};
                    }
                    self.model.classifiers[feed_id].title_regex[value] = score;
                } else if (name == 'text') {
                    if (!self.model.classifiers[feed_id].texts) {
                        self.model.classifiers[feed_id].texts = {};
                    }
                    self.model.classifiers[feed_id].texts[value] = score;
                } else if (name == 'text_regex') {
                    if (!self.model.classifiers[feed_id].text_regex) {
                        self.model.classifiers[feed_id].text_regex = {};
                    }
                    self.model.classifiers[feed_id].text_regex[value] = score;
                } else if (name == 'url') {
                    if (!self.model.classifiers[feed_id].urls) {
                        self.model.classifiers[feed_id].urls = {};
                    }
                    self.model.classifiers[feed_id].urls[value] = score;
                } else if (name == 'url_regex') {
                    if (!self.model.classifiers[feed_id].url_regex) {
                        self.model.classifiers[feed_id].url_regex = {};
                    }
                    self.model.classifiers[feed_id].url_regex[value] = score;
                } else if (name == 'author') {
                    self.model.classifiers[feed_id].authors[value] = score;
                } else if (name == 'feed') {
                    self.model.classifiers[feed_id].feeds[feed_id] = score;
                }
            } else {
                if (name == 'tag' && self.model.classifiers[feed_id].tags[value] == score) {
                    delete self.model.classifiers[feed_id].tags[value];
                } else if (name == 'title' && self.model.classifiers[feed_id].titles[value] == score) {
                    delete self.model.classifiers[feed_id].titles[value];
                } else if (name == 'title_regex' && self.model.classifiers[feed_id].title_regex && self.model.classifiers[feed_id].title_regex[value] == score) {
                    delete self.model.classifiers[feed_id].title_regex[value];
                } else if (name == 'text' && self.model.classifiers[feed_id].texts && self.model.classifiers[feed_id].texts[value] == score) {
                    delete self.model.classifiers[feed_id].texts[value];
                } else if (name == 'text_regex' && self.model.classifiers[feed_id].text_regex && self.model.classifiers[feed_id].text_regex[value] == score) {
                    delete self.model.classifiers[feed_id].text_regex[value];
                } else if (name == 'url' && self.model.classifiers[feed_id].urls && self.model.classifiers[feed_id].urls[value] == score) {
                    delete self.model.classifiers[feed_id].urls[value];
                } else if (name == 'url_regex' && self.model.classifiers[feed_id].url_regex && self.model.classifiers[feed_id].url_regex[value] == score) {
                    delete self.model.classifiers[feed_id].url_regex[value];
                } else if (name == 'author' && self.model.classifiers[feed_id].authors[value] == score) {
                    delete self.model.classifiers[feed_id].authors[value];
                } else if (name == 'feed' && self.model.classifiers[feed_id].feeds[feed_id] == score) {
                    delete self.model.classifiers[feed_id].feeds[feed_id];
                }
            }
        });
    }

};

NEWSBLUR.ReaderClassifierStory.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderClassifierStory.prototype.constructor = NEWSBLUR.ReaderClassifierStory;
_.extend(NEWSBLUR.ReaderClassifierStory.prototype, classifier_prototype);

NEWSBLUR.ReaderClassifierFeed.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderClassifierFeed.prototype.constructor = NEWSBLUR.ReaderClassifierFeed;
_.extend(NEWSBLUR.ReaderClassifierFeed.prototype, classifier_prototype);

NEWSBLUR.ReaderClassifierTrainer.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderClassifierTrainer.prototype.constructor = NEWSBLUR.ReaderClassifierTrainer;
_.extend(NEWSBLUR.ReaderClassifierTrainer.prototype, classifier_prototype);
