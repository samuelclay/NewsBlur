NEWSBLUR.ReaderClassifierTrainer = function (options) {
    var defaults = {
        'width': 760,
        'height': 600,
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
    this.current_tab = 'sitebyside';
    this.all_classifiers_data = null;
    this.manage_dirty_feeds = {};
    this.runner_trainer();
};

NEWSBLUR.ReaderClassifierFeed = function (feed_id, options) {
    var defaults = {
        'width': 620,
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
        'width': 620,
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

                // For tabbed trainer, update just the Site by Site tab content
                if (this.options['training'] && this.$tab_content) {
                    var $existing_modal = $('.NB-modal');
                    var $existing_tab = $existing_modal.find('.NB-tab-sitebyside');
                    if ($existing_tab.length) {
                        // Update Site by Site tab by replacing it atomically to avoid flash
                        var $new_tab = $.make('div', { className: 'NB-tab NB-tab-sitebyside NB-active' }, [this.$tab_content]);
                        $existing_tab.replaceWith($new_tab);
                        this.$modal = $existing_modal;
                    } else {
                        // First load - use full modal with tabs
                        $('.NB-modal').empty().append(this.$modal.children());
                        this.$modal = $('.NB-modal');
                    }
                    this.$tab_content = null;
                } else {
                    // Original behavior for non-trainer modals
                    $('.NB-modal').empty().append(this.$modal.children());
                    this.$modal = $('.NB-modal');
                }

                $(window).trigger('resize.simplemodal');
                this.handle_cancel();
                this.$modal.parent().scrollTop(0);
                callback && callback();
                this.fit_classifiers();
            }
        }, this), 125);
    },

    fit_classifiers: function () {
        // CSS flexbox now handles the layout - this function is kept for compatibility
        // but doesn't need to manually calculate heights anymore
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

        var $intro_content = $.make('div', { className: 'NB-trainer-intro-content' }, [
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

        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal NB-modal-trainer' }, [
            $.make('div', { className: 'NB-trainer-header' }, [
                $.make('h2', { className: 'NB-modal-title' }, [
                    $.make('div', { className: 'NB-icon' }),
                    'Intelligence Trainer',
                    $.make('div', { className: 'NB-icon-dropdown' })
                ]),
                $.make('div', { className: 'NB-modal-tabs' }, [
                    $.make('div', { className: 'NB-modal-loading' }),
                    $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-sitebyside' }, 'Site by Site'),
                    $.make('div', { className: 'NB-modal-tab NB-modal-tab-manage' }, 'Manage Training')
                ])
            ]),
            $.make('div', { className: 'NB-tab NB-tab-sitebyside NB-active' }, [
                $intro_content
            ]),
            $.make('div', { className: 'NB-tab NB-tab-manage' }, [
                $.make('div', { className: 'NB-manage-loading' }, [
                    $.make('div', { className: 'NB-modal-loading NB-active' }),
                    $.make('div', { className: 'NB-manage-loading-text' }, 'Loading classifiers...')
                ])
            ])
        ]);

    },

    make_trainer_outro: function () {
        var self = this;

        var $outro_content = $.make('div', { className: 'NB-trainer-outro-content' }, [
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

        // Store content for Site by Site tab
        this.$tab_content = $outro_content;
    },

    make_modal_feed: function () {
        var self = this;
        var feed = this.feed;

        // NEWSBLUR.log(['Make feed', feed, this.feed_authors, this.feed_tags, this.options['feed_loaded']]);

        var $feed_content = $.make('div', { className: 'NB-trainer-feed-content' }, [
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
                    (!_.isEmpty(this.user_classifiers.titles) && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Titles and Phrases'),
                        $.make('div', { className: 'NB-classifier-titles NB-fieldset-fields NB-classifiers' },
                            this.make_user_titles()
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

        if (this.options['training']) {
            // For trainer, store content for Site by Site tab
            this.$tab_content = $feed_content;
        } else {
            // For standalone feed classifier, use the full modal
            this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal' }, [
                $feed_content
            ]);
        }
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
                    $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                        $.make('h5', 'Story Text'),
                        $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                            $.make('div', { className: 'NB-classifier-help-text' }, 'Highlight text in the field below to train on specific phrases'),
                            $.make('input', { type: 'text', value: selected_text, className: 'NB-classifier-text-highlight' }),
                            this.make_classifier('<span class="NB-classifier-text-placeholder">Select text above</span>', '', 'text'),
                            $.make('span',
                                this.make_user_texts(story.get('story_content'))
                            ),
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
                    ]),
                    (story_title && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                        $.make('h5', 'Story Title'),
                        $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                            $.make('div', { className: 'NB-classifier-help-text' }, 'Highlight phrases in the title below to train on specific words'),
                            $.make('input', { type: 'text', value: story_title, className: 'NB-classifier-title-highlight' }),
                            this.make_classifier('<span class="NB-classifier-title-placeholder">Select phrase above</span>', '', 'title'),
                            $.make('span',
                                this.make_user_titles(story_title)
                            )
                        ])
                    ])),
                    (story.story_authors() && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                        $.make('h5', 'Story Author'),
                        $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                            this.make_authors([story.story_authors()])
                        )
                    ])),
                    (story.get('story_tags').length && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                        $.make('h5', 'Story Categories &amp; Tags'),
                        $.make('div', { className: 'NB-classifier-tags NB-fieldset-fields NB-classifiers' },
                            this.make_tags(story.get('story_tags'))
                        )
                    ])),

                    (this.feed_authors && this.feed_authors.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Feed Authors'),
                        $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                            this.make_authors(this.feed_authors)
                        )
                    ])),

                    (this.feed_tags && this.feed_tags.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                        $.make('h5', 'Feed Categories &amp; Tags'),
                        $.make('div', { className: 'NB-classifier-tags NB-fieldset-fields NB-classifiers' },
                            this.make_tags(this.feed_tags)
                        )
                    ])),

                    (this.feed_publishers && this.feed_publishers.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-publishers' }, [
                        $.make('h5', 'Sharing Stories From These Sites'),
                        $.make('div', { className: 'NB-classifier-publishers NB-fieldset-fields NB-classifiers' },
                            this.make_publishers(this.feed_publishers)
                        )
                    ])),
                    $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                        $.make('h5', 'Everything by This Publisher'),
                        $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                            this.make_publisher(feed)
                        )
                    ])
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

    make_modal_title: function () {
        // For training mode, update the new tab content, not the live modal
        var $container = (this.options['training'] && this.$tab_content) ? this.$tab_content : this.$modal;
        var $modal_title = $('.NB-modal-title', $container);

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
        // For training mode, update the new tab content, not the live modal
        var $container = (this.options['training'] && this.$tab_content) ? this.$tab_content : this.$modal;
        var $count = $('.NB-classifier-trainer-counts', $container);
        var count = this.trainer_iterator + 1;
        var total = this.trainer_data.length;
        $count.html(count + '/' + total);
    },

    make_user_titles: function (existing_title) {
        var $titles = [];
        var titles = _.keys(this.user_classifiers.titles);

        _.each(titles, _.bind(function (title) {
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
            if (!story_content || story_content.toLowerCase().indexOf(text.toLowerCase()) != -1) {
                var $text = this.make_classifier(text, text, 'text');
                $texts.push($text);
            }
        }, this));

        return $texts;
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

    make_classifier: function (classifier_title, classifier_value, classifier_type, classifier_count, classifier) {
        var score = 0;
        // NEWSBLUR.log(['classifiers', this.user_classifiers, classifier_value, this.user_classifiers[classifier_type+'s']]);
        if (this.user_classifiers[classifier_type + 's'] &&
            classifier_value in this.user_classifiers[classifier_type + 's']) {
            score = this.user_classifiers[classifier_type + 's'][classifier_value];
        }

        var classifier_type_title = Inflector.capitalize(classifier_type == 'feed' ?
            'site' :
            classifier_type);

        var $classifier = $.make('span', { className: 'NB-classifier-container' }, [
            $.make('span', { className: 'NB-classifier NB-classifier-' + classifier_type }, [
                $.make('input', {
                    type: 'checkbox',
                    className: 'NB-classifier-input-like',
                    name: 'like_' + classifier_type,
                    value: classifier_value
                }),
                $.make('input', {
                    type: 'checkbox',
                    className: 'NB-classifier-input-dislike',
                    name: 'dislike_' + classifier_type,
                    value: classifier_value
                }),
                $.make('div', { className: 'NB-classifier-icon-like' }),
                $.make('div', { className: 'NB-classifier-icon-dislike' }, [
                    $.make('div', { className: 'NB-classifier-icon-dislike-inner' })
                ]),
                $.make('label', [
                    (classifier_type == 'feed' && $.favicon_el(classifier)),
                    $.make('b', classifier_type_title + ': '),
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

        // Handle story text highlighting
        var $text_highlight = $('.NB-classifier-text-highlight', this.$modal);
        var $text_placeholder = $('.NB-classifier-text-placeholder', this.$modal);
        var $text_classifier = $text_placeholder.parents('.NB-classifier').eq(0);
        var $text_checkboxs = $('.NB-classifier-input-like, .NB-classifier-input-dislike', $text_classifier);

        var last_text_selection = '';
        var update_text = function (e) {
            var text = $.trim($(this).getSelection().text);

            // Only update when selection has actually changed (not on every mousemove/hover)
            if (text.length && text != last_text_selection && $text_placeholder.text() != text) {
                last_text_selection = text;
                $text_placeholder.text(text);
                $text_placeholder.css('font-style', 'normal');
                $text_checkboxs.val(text);
                if (!$text_classifier.is('.NB-classifier-like,.NB-classifier-dislike')) {
                    self.change_classifier($text_classifier, 'like');
                }
            }
        };

        $text_highlight
            .on('select keyup mouseup', update_text);
        $text_checkboxs.val($text_highlight.val());

        // Auto-select text classifier as positive when selected_text is provided
        var selected_text = this.options.selected_text || '';
        if (selected_text && selected_text.length) {
            // Only auto-select if this text is not already in the user's classifiers
            var text_already_exists = this.user_classifiers.texts && (selected_text in this.user_classifiers.texts);
            if (!text_already_exists) {
                $text_placeholder.text(selected_text);
                $text_checkboxs.val(selected_text);
                self.change_classifier($text_classifier, 'like');
            }
        }

        // Clicking the placeholder does nothing - user must select text first
        $text_placeholder.parents('.NB-classifier').bind('click', function (e) {
            // Prevent default classifier toggle behavior if placeholder text is showing
            if ($text_placeholder.text() === 'Select text above') {
                e.preventDefault();
                return false;
            }
        });

        // Handle story title highlighting
        var $title_highlight = $('.NB-classifier-title-highlight', this.$modal);
        var $title_placeholder = $('.NB-classifier-title-placeholder', this.$modal);
        var $title_classifier = $title_placeholder.parents('.NB-classifier').eq(0);
        var $title_checkboxs = $('.NB-classifier-input-like, .NB-classifier-input-dislike', $title_classifier);

        var last_title_selection = '';
        var update_title = function (e) {
            var text = $.trim($(this).getSelection().text);

            // Only update when selection has actually changed (not on every mousemove/hover)
            if (text.length && text != last_title_selection && $title_placeholder.text() != text) {
                last_title_selection = text;
                $title_placeholder.text(text);
                $title_placeholder.css('font-style', 'normal');
                $title_checkboxs.val(text);
                if (!$title_classifier.is('.NB-classifier-like,.NB-classifier-dislike')) {
                    self.change_classifier($title_classifier, 'like');
                }
            }
        };

        $title_highlight
            .on('select keyup mouseup', update_title);
        $title_checkboxs.val($title_highlight.val());

        // Clicking the placeholder does nothing - user must select text first
        $title_placeholder.parents('.NB-classifier').bind('click', function (e) {
            // Prevent default classifier toggle behavior if placeholder text is showing
            if ($title_placeholder.text() === 'Select phrase above') {
                e.preventDefault();
                return false;
            }
        });
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

        // Tab switching
        $.targetIs(e, { tagSelector: '.NB-modal-tab-sitebyside' }, function ($t, $p) {
            e.preventDefault();
            self.switch_trainer_tab('sitebyside');
        });

        $.targetIs(e, { tagSelector: '.NB-modal-tab-manage' }, function ($t, $p) {
            e.preventDefault();
            self.switch_trainer_tab('manage');
        });

        // Manage tab - switch to site by site from empty state
        $.targetIs(e, { tagSelector: '.NB-manage-switch-to-sitebyside' }, function ($t, $p) {
            e.preventDefault();
            self.switch_trainer_tab('sitebyside');
        });

        // Manage tab - retry after error
        $.targetIs(e, { tagSelector: '.NB-manage-retry' }, function ($t, $p) {
            e.preventDefault();
            // Reset data so it will reload
            self.all_classifiers_data = null;
            // Show loading state again
            $('.NB-tab-manage', self.$modal).html([
                $.make('div', { className: 'NB-manage-loading' }, [
                    $.make('div', { className: 'NB-modal-loading NB-active' }),
                    $.make('div', { className: 'NB-manage-loading-text' }, 'Loading classifiers...')
                ])
            ]);
            self.switch_trainer_tab('manage');
        });

        // Manage tab - save button
        $.targetIs(e, { tagSelector: '.NB-manage-save:not(.NB-disabled)' }, function () {
            e.preventDefault();
            self.save_manage_classifiers();
        });

        // Manage tab classifier clicks (handle before regular classifiers)
        var manage_stop = false;
        $.targetIs(e, { tagSelector: '.NB-manage-classifier-item .NB-classifier-icon-dislike' }, function ($t, $p) {
            e.preventDefault();
            manage_stop = true;
            var $item = $t.closest('.NB-manage-classifier-item');
            self.change_manage_classifier($item, 'dislike');
        });
        if (manage_stop) return;
        $.targetIs(e, { tagSelector: '.NB-manage-classifier-item .NB-classifier' }, function ($t, $p) {
            e.preventDefault();
            manage_stop = true;
            var $item = $t.closest('.NB-manage-classifier-item');
            self.change_manage_classifier($item, 'like');
        });
        if (manage_stop) return;

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
            self.change_classifier($t.closest('.NB-classifier'), 'dislike');
        });
        if (stop) return;
        $.targetIs(e, { tagSelector: '.NB-classifier' }, function ($t, $p) {
            e.preventDefault();
            self.change_classifier($t, 'like');
        });
    },

    serialize_classifier: function () {
        var data = {};
        // Only serialize classifiers from the site-by-side tab, not the manage tab
        $('.NB-tab-sitebyside .NB-classifier', this.$modal).each(function () {
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

        // Only update opinions from the site-by-side tab, not the manage tab
        $('.NB-tab-sitebyside input[type=checkbox]', this.$modal).each(function () {
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
                } else if (name == 'text') {
                    if (!self.model.classifiers[feed_id].texts) {
                        self.model.classifiers[feed_id].texts = {};
                    }
                    self.model.classifiers[feed_id].texts[value] = score;
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
                } else if (name == 'text' && self.model.classifiers[feed_id].texts && self.model.classifiers[feed_id].texts[value] == score) {
                    delete self.model.classifiers[feed_id].texts[value];
                } else if (name == 'author' && self.model.classifiers[feed_id].authors[value] == score) {
                    delete self.model.classifiers[feed_id].authors[value];
                } else if (name == 'feed' && self.model.classifiers[feed_id].feeds[feed_id] == score) {
                    delete self.model.classifiers[feed_id].feeds[feed_id];
                }
            }
        });
    },

    // =====================
    // = Manage Training Tab =
    // =====================

    switch_trainer_tab: function (tab) {
        var self = this;
        this.current_tab = tab;

        // Use base modal's switch_tab method
        this.switch_tab(tab);

        if (tab === 'manage') {
            // Always refresh data when switching to manage tab
            this.all_classifiers_data = null;
            this.manage_dirty_feeds = {};

            // Show loading state
            $('.NB-tab-manage', this.$modal).html([
                $.make('div', { className: 'NB-manage-loading' }, [
                    $.make('div', { className: 'NB-modal-loading NB-active' }),
                    $.make('div', { className: 'NB-manage-loading-text' }, 'Loading classifiers...')
                ])
            ]);

            this.model.get_all_classifiers(function (data) {
                self.all_classifiers_data = data;
                self.render_manage_tab_content();
            }, function (error) {
                self.render_manage_tab_error(error);
            });
        }
    },

    render_manage_tab_error: function (error) {
        var self = this;
        var $error = $.make('div', { className: 'NB-manage-training-error' }, [
            $.make('div', { className: 'NB-manage-training-error-icon' }),
            $.make('div', { className: 'NB-manage-training-error-message' }, [
                $.make('h3', 'Error Loading Classifiers'),
                $.make('p', 'There was a problem loading your training data. Please try again.'),
                $.make('div', {
                    className: 'NB-modal-submit-button NB-modal-submit-green NB-manage-retry'
                }, 'Try Again')
            ])
        ]);
        $('.NB-tab-manage', this.$modal).empty().append($error);
    },

    render_manage_tab_content: function () {
        var $content = this.make_manage_tab_content();
        $('.NB-tab-manage', this.$modal).empty().append($content);
    },

    make_manage_tab_content: function () {
        var self = this;
        var $content;

        if (!this.all_classifiers_data || this.all_classifiers_data.total_classifiers === 0) {
            // Empty state
            $content = $.make('div', { className: 'NB-manage-training-empty' }, [
                $.make('div', { className: 'NB-manage-training-empty-icon' }),
                $.make('div', { className: 'NB-manage-training-empty-message' }, [
                    $.make('h3', 'No Trained Classifiers Yet'),
                    $.make('p', 'Train your feeds to filter stories you like and dislike.'),
                    $.make('div', {
                        className: 'NB-modal-submit-button NB-modal-submit-green NB-manage-switch-to-sitebyside'
                    }, 'Start Training Site by Site')
                ])
            ]);
        } else {
            // Build classifier list by folder
            var $folders = [];

            _.each(this.all_classifiers_data.folders, function (folder) {
                var $folder_feeds = [];

                _.each(folder.feeds, function (feed) {
                    var $feed_classifiers = self.make_feed_classifiers_for_manage(feed);
                    if ($feed_classifiers) {
                        $folder_feeds.push($feed_classifiers);
                    }
                });

                if ($folder_feeds.length) {
                    var folder_name = folder.folder_name === ' ' ? 'Top Level' : folder.folder_name;
                    $folders.push($.make('div', { className: 'NB-manage-folder' }, [
                        $.make('div', { className: 'NB-manage-folder-title' }, folder_name),
                        $.make('div', { className: 'NB-manage-folder-feeds' }, $folder_feeds)
                    ]));
                }
            });

            $content = $.make('div', { className: 'NB-manage-training-content' }, [
                $.make('div', { className: 'NB-manage-training-folders' }, $folders),
                $.make('div', { className: 'NB-modal-submit-bottom' }, [
                    $.make('div', { className: 'NB-modal-submit NB-manage-submit-area' }, [
                        $.make('span', { className: 'NB-manage-saved-message' }, 'Saved'),
                        $.make('div', {
                            className: 'NB-modal-submit-save NB-modal-submit-button NB-modal-submit-green NB-disabled NB-manage-prompt'
                        }, 'Check what you like above...'),
                        $.make('div', {
                            className: 'NB-modal-submit-save NB-modal-submit-button NB-modal-submit-green NB-manage-save'
                        }, 'Save')
                    ])
                ])
            ]);
        }

        return $content;
    },

    make_feed_classifiers_for_manage: function (feed) {
        var self = this;
        var classifiers = feed.classifiers;
        var $classifiers_list = [];

        // Titles
        _.each(classifiers.titles, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'title', c.title, c.score));
        });

        // Authors
        _.each(classifiers.authors, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'author', c.author, c.score));
        });

        // Tags
        _.each(classifiers.tags, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'tag', c.tag, c.score));
        });

        // Texts
        _.each(classifiers.texts, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'text', c.text, c.score));
        });

        // Feed-level classifier (publisher) - use feed_id as value but display feed_title
        _.each(classifiers.feeds, function (c) {
            var $item = self.make_manage_classifier_item(feed.feed_id, 'feed', feed.feed_id, c.score);
            // Update the label to show feed title instead of feed_id
            $item.find('.NB-classifier label span').text(feed.feed_title);
            $classifiers_list.push($item);
        });

        if (!$classifiers_list.length) return null;

        return $.make('div', { className: 'NB-manage-feed', 'data-feed-id': feed.feed_id }, [
            $.make('div', { className: 'NB-manage-feed-header' }, [
                $.favicon_el(feed.feed_id, {
                    image_class: 'NB-manage-feed-favicon feed_favicon'
                }),
                $.make('span', { className: 'NB-manage-feed-title' }, feed.feed_title)
            ]),
            $.make('div', { className: 'NB-manage-feed-classifiers NB-classifiers' }, $classifiers_list)
        ]);
    },

    make_manage_classifier_item: function (feed_id, type, value, score) {
        var type_label = type.charAt(0).toUpperCase() + type.slice(1);
        if (type === 'feed') type_label = 'Site';

        var $item = $.make('div', {
            className: 'NB-manage-classifier-item',
            'data-feed-id': feed_id,
            'data-type': type,
            'data-value': value,
            'data-score': score
        }, [
            $.make('div', { className: 'NB-classifier NB-classifier-' + type + (score > 0 ? ' NB-classifier-like' : ' NB-classifier-dislike') }, [
                $.make('input', { type: 'checkbox', className: 'NB-classifier-input-like', name: 'like_' + type, value: value }),
                $.make('input', { type: 'checkbox', className: 'NB-classifier-input-dislike', name: 'dislike_' + type, value: value }),
                $.make('div', { className: 'NB-classifier-icon-like' }),
                $.make('div', { className: 'NB-classifier-icon-dislike' }, [
                    $.make('div', { className: 'NB-classifier-icon-dislike-inner' })
                ]),
                $.make('label', [
                    $.make('b', type_label + ': '),
                    $.make('span', value)
                ])
            ])
        ]);

        // Set initial checkbox state
        if (score > 0) {
            $('.NB-classifier-input-like', $item).prop('checked', true);
        } else if (score < 0) {
            $('.NB-classifier-input-dislike', $item).prop('checked', true);
        }

        return $item;
    },

    change_manage_classifier: function ($item, opinion) {
        var $classifier = $('.NB-classifier', $item);
        var feed_id = $item.data('feed-id');
        var type = $item.data('type');
        var value = $item.data('value');
        var orig_score = $item.data('score');
        var key = feed_id + ':' + type + ':' + value;

        this.change_classifier($classifier, opinion);

        // Determine current score based on checkbox state
        var current_score = 0;
        if ($('.NB-classifier-input-like', $item).is(':checked')) {
            current_score = 1;
        } else if ($('.NB-classifier-input-dislike', $item).is(':checked')) {
            current_score = -1;
        }

        // Track dirty state - only if different from original
        if (!this.manage_dirty_feeds[feed_id]) {
            this.manage_dirty_feeds[feed_id] = {};
        }

        if (current_score !== orig_score) {
            // Changed from original - add to dirty
            this.manage_dirty_feeds[feed_id][key] = {
                type: type,
                value: value,
                orig_score: orig_score,
                current_score: current_score
            };
        } else {
            // Reverted to original - remove from dirty
            delete this.manage_dirty_feeds[feed_id][key];
            // Clean up empty feed entries
            if (Object.keys(this.manage_dirty_feeds[feed_id]).length === 0) {
                delete this.manage_dirty_feeds[feed_id];
            }
        }

        this.update_manage_save_button();
    },

    update_manage_save_button: function () {
        var $save = $('.NB-manage-save', this.$modal);
        var $prompt = $('.NB-manage-prompt', this.$modal);
        var $saved = $('.NB-manage-saved-message', this.$modal);

        // Count total changes
        var total_changes = 0;
        _.each(this.manage_dirty_feeds, function (changes) {
            total_changes += Object.keys(changes).length;
        });

        if (total_changes > 0) {
            var label = total_changes === 1 ? 'Save 1 change' : 'Save ' + total_changes + ' changes';
            $save.text(label).show();
            $prompt.hide();
            $saved.hide();
        } else {
            $save.hide();
            $prompt.show();
        }
    },

    save_manage_classifiers: function () {
        var self = this;
        var $save = $('.NB-manage-save', this.$modal);
        var $prompt = $('.NB-manage-prompt', this.$modal);
        var $saved_message = $('.NB-manage-saved-message', this.$modal);

        // Collect all changes by feed_id
        var feeds_to_save = Object.keys(this.manage_dirty_feeds);

        if (feeds_to_save.length === 0) {
            return;
        }

        $save.addClass('NB-disabled').text('Saving...');

        // Build classifiers object for all dirty feeds
        var classifiers_by_feed = {};
        _.each(feeds_to_save, function (feed_id) {
            classifiers_by_feed[feed_id] = self.serialize_manage_classifiers_for_feed(feed_id);
        });

        // Single bulk request
        this.model.save_all_classifiers(classifiers_by_feed, function () {
            // Update original scores to current scores for saved items
            _.each(self.manage_dirty_feeds, function (changes, feed_id) {
                _.each(changes, function (change) {
                    var $item = $('.NB-manage-classifier-item[data-feed-id="' + feed_id + '"][data-type="' + change.type + '"][data-value="' + change.value + '"]', self.$modal);
                    $item.data('score', change.current_score);
                });
            });

            self.manage_dirty_feeds = {};

            // Hide save button, show both "Saved" message and prompt immediately
            $save.removeClass('NB-disabled').hide();
            $prompt.show();
            $saved_message.stop(true).css('opacity', 1).show();

            // After delay, just fade out "Saved" - prompt stays visible
            setTimeout(function () {
                $saved_message.fadeOut(500);
            }, 1500);

            // Refresh feeds without re-opening any specific feed
            NEWSBLUR.reader.force_feeds_refresh();
        }, function () {
            $save.removeClass('NB-disabled');
            self.update_manage_save_button();
        });
    },

    serialize_manage_classifiers_for_feed: function (feed_id) {
        var data = {};
        var changed_items = this.manage_dirty_feeds[feed_id] || {};

        // Serialize each changed item
        _.each(changed_items, function (change) {
            var value = change.value;
            var type = change.type;
            var name;

            // For feed-level classifiers, use feed_id as the value
            if (type === 'feed') {
                value = feed_id;
            }

            if (change.current_score === 1) {
                name = 'like_' + type;
            } else if (change.current_score === -1) {
                name = 'dislike_' + type;
            } else {
                // Removed - neutral
                if (change.orig_score > 0) {
                    name = 'remove_like_' + type;
                } else {
                    name = 'remove_dislike_' + type;
                }
            }

            if (!data[name]) data[name] = [];
            if (data[name].indexOf(value) === -1) data[name].push(value);
        });

        return data;
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
