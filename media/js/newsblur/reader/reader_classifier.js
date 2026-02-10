NEWSBLUR.ReaderClassifierTrainer = function (options) {
    var defaults = {
        'width': 820,
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
    // Manage tab filter state
    this.manage_filter_sentiment = 'all'; // 'all', 'like', 'dislike'
    this.manage_filter_types = 'all'; // 'all' or specific type: 'title', 'text', 'tag', 'author', 'feed', 'url'
    this.manage_filter_scope = 'all'; // 'all', 'feed', 'folder', 'global'
    this.manage_filter_feed = null; // null = all feeds/folders, or specific feed_id/folder path
    this.manage_filter_search = ''; // search query for filtering
    this.runner_trainer();
};

NEWSBLUR.ReaderClassifierFeed = function (feed_id, options) {
    var defaults = {
        'width': 820,
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
    this.current_tab = 'feed';
    this.all_classifiers_data = null;
    this.manage_dirty_feeds = {};
    this.manage_filter_sentiment = 'all';
    this.manage_filter_types = 'all';
    this.manage_filter_scope = 'all';
    this.manage_filter_feed = null;
    this.manage_filter_search = '';
    this.runner_feed();
};


NEWSBLUR.ReaderClassifierStory = function (story_id, feed_id, options) {
    var defaults = {
        'width': 820,
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
    this.current_tab = 'story';
    this.all_classifiers_data = null;
    this.manage_dirty_feeds = {};
    this.manage_filter_sentiment = 'all';
    this.manage_filter_types = 'all';
    this.manage_filter_scope = 'all';
    this.manage_filter_feed = null;
    this.manage_filter_search = '';
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

        if (this.options['training']) {
            // For trainer, store content for Site by Site tab
            this.$tab_content = $feed_content;
        } else {
            // For standalone feed classifier, add tabs for Train this site / Manage Training
            // Move subtitle from $feed_content to header, remove empty title and loading
            var $subtitle = $feed_content.find('.NB-modal-subtitle').detach();
            $feed_content.find('.NB-modal-title').remove();
            $feed_content.find('.NB-modal-loading').remove();

            this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal' }, [
                $.make('h2', { className: 'NB-modal-title' }, [
                    'What do you ',
                    $.make('span', { className: 'NB-classifier-like NB-like' }, 'like'),
                    ' and ',
                    $.make('span', { className: 'NB-classifier-dislike NB-dislike' }, 'dislike'),
                    ' about this site?'
                ]),
                $.make('div', { className: 'NB-modal-header' }, [
                    $subtitle,
                    $.make('div', { className: 'NB-modal-tabs' }, [
                        $.make('div', { className: 'NB-modal-loading' }),
                        $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-feed' }, 'Train this site'),
                        $.make('div', { className: 'NB-modal-tab NB-modal-tab-manage' }, 'Manage Training')
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-feed NB-active' }, [
                    $feed_content
                ]),
                $.make('div', { className: 'NB-tab NB-tab-manage' }, [
                    $.make('div', { className: 'NB-manage-loading' }, [
                        $.make('div', { className: 'NB-modal-loading NB-active' }),
                        $.make('div', { className: 'NB-manage-loading-text' }, 'Loading classifiers...')
                    ])
                ])
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
            $.make('h2', { className: 'NB-modal-title' }, [
                'What do you ',
                $.make('span', { className: 'NB-classifier-like NB-like' }, 'like'),
                ' and ',
                $.make('span', { className: 'NB-classifier-dislike NB-dislike' }, 'dislike'),
                ' about this story?'
            ]),
            $.make('div', { className: 'NB-modal-header' }, [
                $.make('h2', { className: 'NB-modal-subtitle' }, [
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
                $.make('div', { className: 'NB-modal-tabs' }, [
                    $.make('div', { className: 'NB-modal-loading' }),
                    $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-story' }, 'Train this story'),
                    $.make('div', { className: 'NB-modal-tab NB-modal-tab-manage' }, 'Manage Training')
                ])
            ]),
            $.make('div', { className: 'NB-tab NB-tab-story NB-active' }, [
                (this.options['feed_loaded'] &&
                    $.make('form', { method: 'post' }, [
                        // Section 1: Story Text
                        this.make_story_text_section(selected_text, story),
                        // Section 2: Story Title
                        this.make_story_title_section(story_title),
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
            ]),
            $.make('div', { className: 'NB-tab NB-tab-manage' }, [
                $.make('div', { className: 'NB-manage-loading' }, [
                    $.make('div', { className: 'NB-modal-loading NB-active' }),
                    $.make('div', { className: 'NB-manage-loading-text' }, 'Loading classifiers...')
                ])
            ])
        ]);
    },

    make_story_text_section: function (selected_text, story) {
        var story_content = story.get('story_content') || '';

        // Separate text classifiers into matching and non-matching
        var matching_texts = this.make_user_texts(story_content);
        var matching_text_regex = this.make_user_text_regex(story_content);
        var non_matching_texts = this.make_user_texts_non_matching(story_content);
        var non_matching_text_regex = this.make_user_text_regex_non_matching(story_content);
        var $scoped_groups = this.make_scoped_groups(non_matching_texts.concat(non_matching_text_regex));

        var $this_story = $.make('div', { className: 'NB-classifier-this-story' }, [
            this.make_classifier('<span class="NB-classifier-text-placeholder">Enter text above</span>', '', 'text'),
            $.make('span', matching_texts),
            $.make('span', matching_text_regex)
        ]);

        return $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifier-content-section NB-classifier-text-section', 'data-section': 'text' }, [
            $.make('h5', { className: 'NB-classifier-section-header' }, [
                $.make('span', 'Story Text'),
                $.make('span', { className: 'NB-classifier-header-notices' }, [
                    (!NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_pro && $.make('span', { className: 'NB-classifier-archive-notice' }, [
                        'Requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Archive')
                    ])),
                    (!NEWSBLUR.Globals.is_pro && $.make('span', { className: 'NB-classifier-pro-notice' }, [
                        'Regex requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Pro')
                    ])),
                    (!NEWSBLUR.Globals.is_archive && $.make('span', { className: 'NB-classifier-scope-notice' }, [
                        'Classifier scope requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Archive')
                    ]))
                ])
            ]),
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
                $.make('div', { className: 'NB-classifier-content-classifiers' },
                    [$this_story].concat($scoped_groups)
                )
            ])
        ]);
    },

    make_story_title_section: function (story_title) {
        // Separate title classifiers into matching and non-matching
        var matching_titles = this.make_user_titles(story_title);
        var matching_title_regex = this.make_user_title_regex_matching(story_title);
        var non_matching_titles = this.make_user_titles_non_matching(story_title);
        var non_matching_title_regex = this.make_user_title_regex_non_matching(story_title);
        var $scoped_groups = this.make_scoped_groups(non_matching_titles.concat(non_matching_title_regex));

        var $this_story = $.make('div', { className: 'NB-classifier-this-story' }, [
            this.make_classifier('<span class="NB-classifier-title-placeholder">Select title phrase</span>', '', 'title'),
            $.make('span', matching_titles),
            $.make('span', matching_title_regex)
        ]);

        return $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifier-content-section NB-classifier-title-section', 'data-section': 'title' }, [
            $.make('h5', { className: 'NB-classifier-section-header' }, [
                $.make('span', 'Story Title'),
                $.make('span', { className: 'NB-classifier-header-notices' }, [
                    (!NEWSBLUR.Globals.is_pro && $.make('span', { className: 'NB-classifier-pro-notice' }, [
                        'Regex requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Pro')
                    ])),
                    (!NEWSBLUR.Globals.is_archive && $.make('span', { className: 'NB-classifier-scope-notice' }, [
                        'Classifier scope requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Archive')
                    ]))
                ])
            ]),
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
                $.make('div', { className: 'NB-classifier-content-classifiers' },
                    [$this_story].concat($scoped_groups)
                )
            ])
        ]);
    },

    make_story_url_section: function (story) {
        // Strip protocol from URL for display, keep domain + path
        var story_url = (story.get('story_permalink') || '').replace(/^https?:\/\//, '');

        // Only show URL section for Premium+ users
        if (!NEWSBLUR.Globals.is_premium) {
            return '';
        }

        // Separate URL classifiers into matching (found in this story's URL) and non-matching
        var matching_urls = this.make_user_urls(story_url);
        var matching_url_regex = this.make_user_url_regex_matching(story_url);
        var non_matching_urls = this.make_user_urls_non_matching(story_url);
        var non_matching_url_regex = this.make_user_url_regex_non_matching(story_url);
        var $scoped_groups = this.make_scoped_groups(non_matching_urls.concat(non_matching_url_regex));

        // Always create the "this story" div with the placeholder, plus any matching URLs
        var $this_story = $.make('div', { className: 'NB-classifier-this-story' }, [
            this.make_classifier('<span class="NB-classifier-url-placeholder">Select URL portion above</span>', '', 'url'),
            $.make('span', matching_urls),
            $.make('span', matching_url_regex)
        ]);

        return $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifier-content-section NB-classifier-url-section', 'data-section': 'url' }, [
            $.make('h5', { className: 'NB-classifier-section-header' }, [
                $.make('span', 'Story URL'),
                $.make('span', { className: 'NB-classifier-header-notices' }, [
                    (!NEWSBLUR.Globals.is_pro && $.make('span', { className: 'NB-classifier-pro-notice' }, [
                        'Regex requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Pro')
                    ])),
                    (!NEWSBLUR.Globals.is_archive && $.make('span', { className: 'NB-classifier-scope-notice' }, [
                        'Classifier scope requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Archive')
                    ]))
                ])
            ]),
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
                $.make('div', { className: 'NB-classifier-content-classifiers' },
                    [$this_story].concat($scoped_groups)
                )
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
        var $scoped_groups = has_other_authors ?
            this.make_scoped_groups(this.make_authors(other_authors)) : [];

        return $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
            $.make('h5', { className: 'NB-classifier-section-header' }, [
                $.make('span', 'Story Authors'),
                $.make('span', { className: 'NB-classifier-header-notices' }, [
                    (!NEWSBLUR.Globals.is_archive && $.make('span', { className: 'NB-classifier-scope-notice' }, [
                        'Classifier scope requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Archive')
                    ]))
                ])
            ]),
            $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                [$story_authors].concat($scoped_groups)
            )
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
        var $scoped_groups = has_other_tags ?
            this.make_scoped_groups(this.make_tags(other_tags)) : [];

        return $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
            $.make('h5', { className: 'NB-classifier-section-header' }, [
                $.make('span', 'Story Categories &amp; Tags'),
                $.make('span', { className: 'NB-classifier-header-notices' }, [
                    (!NEWSBLUR.Globals.is_archive && $.make('span', { className: 'NB-classifier-scope-notice' }, [
                        'Classifier scope requires ',
                        $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, 'Premium Archive')
                    ]))
                ])
            ]),
            $.make('div', { className: 'NB-classifier-tags NB-fieldset-fields NB-classifiers' },
                [$story_tags].concat($scoped_groups)
            )
        ]);
    },

    make_combined_publisher_section: function (feed) {
        var has_other_publishers = this.feed_publishers && this.feed_publishers.length > 0;
        var $scoped_groups = has_other_publishers ?
            this.make_scoped_groups(this.make_publishers(this.feed_publishers)) : [];

        return $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
            $.make('h5', 'Publisher'),
            $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                [this.make_publisher(feed)].concat($scoped_groups)
            )
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

    make_user_text_regex: function (story_content) {
        var $regexes = [];
        // Support both new 'text_regex' and legacy 'regex' storage
        var regex_classifiers = this.user_classifiers.text_regex || this.user_classifiers.regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            // Check if regex matches the story content
            try {
                var regex = new RegExp(pattern, 'i');
                if (!story_content || regex.test(story_content)) {
                    var $regex = this.make_classifier(pattern, pattern, 'text', null, null, true);
                    $regexes.push($regex);
                }
            } catch (e) {
                // Invalid regex, include it anyway so user can see/edit it
                var $regex = this.make_classifier(pattern, pattern, 'text', null, null, true);
                $regexes.push($regex);
            }
        }, this));

        return $regexes;
    },

    make_user_texts_non_matching: function (story_content) {
        var $texts = [];
        var texts = _.keys(this.user_classifiers.texts || {});

        _.each(texts, _.bind(function (text) {
            // Only include texts that DON'T match the story content
            if (story_content && story_content.toLowerCase().indexOf(text.toLowerCase()) === -1) {
                var $text = this.make_classifier(text, text, 'text');
                $texts.push($text);
            }
        }, this));

        return $texts;
    },

    make_user_text_regex_non_matching: function (story_content) {
        var $regexes = [];
        var regex_classifiers = this.user_classifiers.text_regex || this.user_classifiers.regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            // Check if regex does NOT match the story content
            try {
                var regex = new RegExp(pattern, 'i');
                if (story_content && !regex.test(story_content)) {
                    var $regex = this.make_classifier(pattern, pattern, 'text', null, null, true);
                    $regexes.push($regex);
                }
            } catch (e) {
                // Invalid regex - don't include in non-matching (already shown in matching)
            }
        }, this));

        return $regexes;
    },

    make_user_titles_non_matching: function (story_title) {
        var $titles = [];
        var titles = _.keys(this.user_classifiers.titles);

        _.each(titles, _.bind(function (title) {
            // Only include titles that DON'T match the story title
            if (story_title && story_title.toLowerCase().indexOf(title.toLowerCase()) === -1) {
                var $title = this.make_classifier(title, title, 'title');
                $titles.push($title);
            }
        }, this));

        return $titles;
    },

    make_user_title_regex_matching: function (story_title) {
        var $regexes = [];
        var regex_classifiers = this.user_classifiers.title_regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            // Check if regex matches the story title
            try {
                var regex = new RegExp(pattern, 'i');
                if (!story_title || regex.test(story_title)) {
                    var $regex = this.make_classifier(pattern, pattern, 'title', null, null, true);
                    $regexes.push($regex);
                }
            } catch (e) {
                // Invalid regex, include it anyway so user can see/edit it
                var $regex = this.make_classifier(pattern, pattern, 'title', null, null, true);
                $regexes.push($regex);
            }
        }, this));

        return $regexes;
    },

    make_user_title_regex_non_matching: function (story_title) {
        var $regexes = [];
        var regex_classifiers = this.user_classifiers.title_regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            // Check if regex does NOT match the story title
            try {
                var regex = new RegExp(pattern, 'i');
                if (story_title && !regex.test(story_title)) {
                    var $regex = this.make_classifier(pattern, pattern, 'title', null, null, true);
                    $regexes.push($regex);
                }
            } catch (e) {
                // Invalid regex - don't include in non-matching (already shown in matching)
            }
        }, this));

        return $regexes;
    },

    make_user_urls: function (story_url) {
        var $urls = [];
        var url_classifiers = this.user_classifiers.urls || {};
        var story_url_lower = story_url ? story_url.toLowerCase() : '';

        _.each(_.keys(url_classifiers), _.bind(function (pattern) {
            // If story_url provided, only include patterns that match the story URL
            if (!story_url || story_url_lower.indexOf(pattern.toLowerCase()) !== -1) {
                var $url = this.make_classifier(pattern, pattern, 'url');
                $urls.push($url);
            }
        }, this));

        return $urls;
    },

    make_user_urls_non_matching: function (story_url) {
        var $urls = [];
        var url_classifiers = this.user_classifiers.urls || {};
        var story_url_lower = story_url ? story_url.toLowerCase() : '';

        _.each(_.keys(url_classifiers), _.bind(function (pattern) {
            // Only include patterns that DON'T match the story URL
            if (story_url && story_url_lower.indexOf(pattern.toLowerCase()) === -1) {
                var $url = this.make_classifier(pattern, pattern, 'url');
                $urls.push($url);
            }
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

    make_user_url_regex_matching: function (story_url) {
        var $regexes = [];
        var regex_classifiers = this.user_classifiers.url_regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            // Check if regex matches the story URL
            try {
                var regex = new RegExp(pattern, 'i');
                if (!story_url || regex.test(story_url)) {
                    var $regex = this.make_classifier(pattern, pattern, 'url', null, null, true);
                    $regexes.push($regex);
                }
            } catch (e) {
                // Invalid regex, include it anyway so user can see/edit it
                var $regex = this.make_classifier(pattern, pattern, 'url', null, null, true);
                $regexes.push($regex);
            }
        }, this));

        return $regexes;
    },

    make_user_url_regex_non_matching: function (story_url) {
        var $regexes = [];
        var regex_classifiers = this.user_classifiers.url_regex || {};

        _.each(_.keys(regex_classifiers), _.bind(function (pattern) {
            // Check if regex does NOT match the story URL
            try {
                var regex = new RegExp(pattern, 'i');
                if (story_url && !regex.test(story_url)) {
                    var $regex = this.make_classifier(pattern, pattern, 'url', null, null, true);
                    $regexes.push($regex);
                }
            } catch (e) {
                // Invalid regex - don't include in non-matching (already shown in matching)
            }
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

    group_classifiers_by_scope: function (classifiers) {
        var groups = { feed: [], folder: [], global: [] };
        _.each(classifiers, function ($el) {
            var scope = $('.NB-classifier', $el).data('scope') || 'feed';
            if (groups[scope]) {
                groups[scope].push($el);
            } else {
                groups.feed.push($el);
            }
        });
        return groups;
    },

    make_scoped_groups: function (classifiers) {
        var groups = this.group_classifiers_by_scope(classifiers);
        var $sections = [];

        if (groups.feed.length > 0) {
            $sections.push($.make('div', { className: 'NB-classifier-feed-items' }, groups.feed));
        }
        if (groups.folder.length > 0) {
            $sections.push($.make('div', { className: 'NB-classifier-folder-items' }, groups.folder));
        }
        if (groups.global.length > 0) {
            $sections.push($.make('div', { className: 'NB-classifier-global-items' }, groups.global));
        }

        return $sections;
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

        // Check scope metadata for this classifier
        var scope_key = classifier_type + 's_scope';
        var scope_info = null;
        if (this.user_classifiers[scope_key] && classifier_value in this.user_classifiers[scope_key]) {
            scope_info = this.user_classifiers[scope_key][classifier_value];
        }
        var scope = scope_info ? scope_info.scope : 'feed';
        var scope_folder_name = scope_info ? scope_info.folder_name : '';

        // Label shows the display type (Text, Title, etc.) not "Regex"
        var display_type = classifier_type == 'feed' ? 'site' : (classifier_type == 'url' ? 'URL' : classifier_type);
        var classifier_type_title = classifier_type == 'url' ? 'URL' : Inflector.capitalize(display_type);

        var css_class = 'NB-classifier NB-classifier-' + classifier_type;
        if (is_regex) {
            css_class += ' NB-classifier-regex';
        }

        // Build the type badge with all three scope icons as a toggle group
        // For feed-type classifiers, just show the favicon + "Site:" (no scope controls)
        var $type_badge;
        if (classifier_type === 'feed') {
            $type_badge = $.make('span', { className: 'NB-classifier-type-badge NB-classifier-type-feed' }, [
                $.favicon_el(classifier),
                $.make('span', { className: 'NB-classifier-type-label' }, 'Site')
            ]);
        } else {
            // Three scope icons shown simultaneously — active one highlighted
            var scope_icon_data = [
                { key: 'feed', title: 'This site only', svg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 11a9 9 0 0 1 9 9"/><path d="M4 4a16 16 0 0 1 16 16"/><circle cx="5" cy="19" r="1"/></svg>' },
                { key: 'folder', title: 'All sites in folder', svg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/></svg>' },
                { key: 'global', title: 'All sites', svg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>' }
            ];
            var $scope_toggles = $.make('span', { className: 'NB-classifier-scope-toggles' });
            _.each(scope_icon_data, function (icon) {
                var $toggle = $.make('span', {
                    className: 'NB-scope-toggle NB-scope-toggle-' + icon.key + (icon.key === scope ? ' NB-active' : ''),
                    'data-tooltip': icon.title
                });
                $toggle.html(icon.svg);
                $toggle.data('scope', icon.key);
                $scope_toggles.append($toggle);
            });

            $type_badge = $.make('span', { className: 'NB-classifier-type-badge' }, [
                $scope_toggles,
                $.make('span', { className: 'NB-classifier-type-label' }, classifier_type_title)
            ]);
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
                    $type_badge,
                    (is_regex && $.make('span', { className: 'NB-classifier-regex-badge' }, 'REGEX')),
                    $.make('span', classifier_title)
                ])
            ]),
            (classifier_count && $.make('span', { className: 'NB-classifier-count' }, [
                '&times;&nbsp;',
                classifier_count
            ]))
        ]);

        // Store scope data on the classifier element
        $('.NB-classifier', $classifier).data('scope', scope);
        $('.NB-classifier', $classifier).data('folder-name', scope_folder_name);

        // Store original state for change tracking (like, dislike, or neutral)
        var original_state = score > 0 ? 'like' : (score < 0 ? 'dislike' : 'neutral');
        $('.NB-classifier', $classifier).data('original-state', original_state);
        $('.NB-classifier', $classifier).data('original-scope', scope || 'feed');
        $('.NB-classifier', $classifier).data('original-folder-name', scope_folder_name || '');

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

        // Click individual scope toggle icons to switch scope
        if (classifier_type !== 'feed') {
            var self = this;
            $('.NB-scope-toggle', $classifier).on('click', function (e) {
                e.stopPropagation();
                e.preventDefault();
                self.select_scope($(this), $classifier);
            });

            // Instant tooltip on hover (appended to body to avoid overflow clipping)
            $('.NB-scope-toggle', $classifier).on('mouseenter', function () {
                var $this = $(this);
                var text = $this.attr('data-tooltip');
                if (!text) return;
                var $tip = $('<div class="NB-scope-tooltip">' + text + '</div>');
                $('body').append($tip);
                var rect = this.getBoundingClientRect();
                $tip.css({
                    top: rect.top - $tip.outerHeight() - 6,
                    left: rect.left + rect.width / 2 - $tip.outerWidth() / 2
                });
                $this.data('$tooltip', $tip);
            }).on('mouseleave', function () {
                var $tip = $(this).data('$tooltip');
                if ($tip) { $tip.remove(); $(this).removeData('$tooltip'); }
            });
        }

        return $classifier;
    },

    select_scope: function ($toggle, $classifier_container) {
        var $cl = $('.NB-classifier', $classifier_container);
        var new_scope = $toggle.data('scope');
        var current_scope = $cl.data('scope') || 'feed';
        var is_archive = NEWSBLUR.Globals.is_archive;

        // Already active — do nothing
        if (new_scope === current_scope) return;

        // Archive gating: non-Archive users can't use folder/global
        if (!is_archive && new_scope !== 'feed') {
            // 1. Shake the type badge to signal "denied"
            var $badge = $toggle.closest('.NB-classifier-type-badge');
            $badge.removeClass('NB-shake');
            $badge[0].offsetWidth; // force reflow
            $badge.addClass('NB-shake');
            setTimeout(function () { $badge.removeClass('NB-shake'); }, 500);

            // 2. Flash the clicked toggle amber to connect it to the notice
            $toggle.addClass('NB-scope-toggle-denied');
            setTimeout(function () { $toggle.removeClass('NB-scope-toggle-denied'); }, 800);

            // 3. Show a brief "Requires Pro" tooltip on the blocked toggle
            $('.NB-scope-tooltip').remove();
            var $tip = $('<div class="NB-scope-tooltip NB-scope-tooltip-denied">Requires Premium Archive</div>');
            $('body').append($tip);
            var rect = $toggle[0].getBoundingClientRect();
            $tip.css({
                top: rect.top - $tip.outerHeight() - 6,
                left: rect.left + rect.width / 2 - $tip.outerWidth() / 2
            });
            setTimeout(function () { $tip.fadeOut(300, function () { $tip.remove(); }); }, 1500);

            // 4. Animate in the header notice and keep it visible
            var $section = $classifier_container.closest('.NB-fieldset');
            var $notice = $section.find('.NB-classifier-scope-notice');
            if ($notice.length && !$notice.hasClass('NB-visible')) {
                $notice.removeClass('NB-fading');
                $notice[0].offsetWidth;
                $notice.addClass('NB-visible');
            }
            return;
        }

        // For folder scope, find the folder this feed belongs to
        var folder_name = '';
        if (new_scope === 'folder') {
            if (this.feed_id && NEWSBLUR.assets.folders) {
                var feed_id = parseInt(this.feed_id, 10);
                var find_in_collection = function (collection) {
                    collection.each(function (item) {
                        if (folder_name) return;
                        if (item.is_folder()) {
                            var feed_ids = item.feed_ids_in_folder();
                            if (_.contains(feed_ids, feed_id)) {
                                folder_name = item.get('folder_title') || '';
                            }
                        }
                    });
                };
                find_in_collection(NEWSBLUR.assets.folders);
            }
        }

        // Update data
        $cl.data('scope', new_scope);
        $cl.data('folder-name', folder_name);

        // Update toggle active states
        $toggle.closest('.NB-classifier-scope-toggles').find('.NB-scope-toggle').removeClass('NB-active');
        $toggle.addClass('NB-active');

        // Brief scale animation on the clicked toggle
        $toggle.css('transform', 'scale(1.3)');
        setTimeout(function () {
            $toggle.css('transform', '');
        }, 150);

        // Compare scope + like/dislike to original state to determine if changed
        var original_scope = $cl.data('original-scope') || 'feed';
        var current_state = $cl.hasClass('NB-classifier-like') ? 'like' :
            ($cl.hasClass('NB-classifier-dislike') ? 'dislike' : 'neutral');
        var original_state = $cl.data('original-state') || 'neutral';

        if (new_scope !== original_scope || current_state !== original_state) {
            $cl.addClass('NB-classifier-changed');
        } else {
            $cl.removeClass('NB-classifier-changed');
        }
        this.update_save_button();
    },

    save_scope_change: function ($classifier) {
        var value = $classifier.find('.NB-classifier-input-like').val();
        var is_like = $classifier.hasClass('NB-classifier-like');
        var is_dislike = $classifier.hasClass('NB-classifier-dislike');
        var scope = $classifier.data('scope') || 'feed';
        var folder_name = $classifier.data('folder-name') || '';
        var input_name = $classifier.find('.NB-classifier-input-like').attr('name');

        if (!is_like && !is_dislike) return;

        var data = {
            'feed_id': this.feed_id,
            'scope': scope,
            'folder_name': folder_name
        };

        if (is_like) {
            data[input_name] = value;
        } else {
            data[input_name.replace('like_', 'dislike_')] = value;
        }

        NEWSBLUR.assets.save_classifier(data, function () {
            NEWSBLUR.reader.force_feeds_refresh();
        });
    },

    change_classifier: function ($classifier, classifier_opinion) {
        var $like = $('.NB-classifier-input-like', $classifier);
        var $dislike = $('.NB-classifier-input-dislike', $classifier);

        var $close = $('.NB-modal-submit-grey', this.$modal);

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

        // Determine current state after toggle
        var current_state = 'neutral';
        if ($classifier.is('.NB-classifier-like')) {
            current_state = 'like';
        } else if ($classifier.is('.NB-classifier-dislike')) {
            current_state = 'dislike';
        }

        // Compare to original state (sentiment + scope) - only mark as changed if different
        var original_state = $classifier.data('original-state') || 'neutral';
        var current_scope = $classifier.data('scope') || 'feed';
        var original_scope = $classifier.data('original-scope') || 'feed';
        if (current_state === original_state && current_scope === original_scope) {
            $classifier.removeClass('NB-classifier-changed');
        } else {
            $classifier.addClass('NB-classifier-changed');
        }

        if (this.options['training']) {
            $close.text('Save & Close');
        } else {
            this.update_save_button();
        }
    },

    count_selected_classifiers: function () {
        // Only count classifiers that have been CHANGED during this session
        // For training modal: count all like/dislike classifiers (original behavior)
        if (this.options['training']) {
            return this.$modal.find('.NB-classifier.NB-classifier-like, .NB-classifier.NB-classifier-dislike').length;
        }
        // For story/feed modals: count changed classifiers only in the ACTIVE tab
        var $active_tab = this.$modal.find('.NB-tab.NB-active');
        return $active_tab.find('.NB-classifier.NB-classifier-changed').length;
    },

    get_save_button_text: function (count) {
        if (count === 0) {
            return 'Check what you like above...';
        } else if (count === 1) {
            return 'Save 1 classifier';
        } else {
            return 'Save ' + count + ' classifiers';
        }
    },

    update_save_button: function () {
        var $save = $('.NB-modal-submit-save', this.$modal);
        var count = this.count_selected_classifiers();

        if (count === 0) {
            $save.addClass('NB-disabled').text(this.get_save_button_text(0));
        } else {
            $save.removeClass('NB-disabled').text(this.get_save_button_text(count));
        }
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
                // Check if this text already exists as a classifier
                var existing_texts = self.user_classifiers.texts || {};
                var text_lower = text.toLowerCase();
                var text_already_exists = _.any(_.keys(existing_texts), function (k) {
                    return k.toLowerCase() === text_lower;
                });

                if (text_already_exists) {
                    // Hide the placeholder classifier — the existing one is already shown
                    $text_classifier.hide();
                } else {
                    $text_classifier.show();
                    $text_placeholder.text(text);
                    $text_placeholder.css('font-style', 'normal');
                    $text_checkboxes.val(text);
                    // Auto thumbs-up if not already rated
                    if (!$text_classifier.is('.NB-classifier-like,.NB-classifier-dislike')) {
                        self.change_classifier($text_classifier, 'like');
                    }
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
                $text_classifier.show();
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
                        // Exact phrase - only show badge when NOT found (since selected text is usually found)
                        if (story_url.toLowerCase().indexOf(text.toLowerCase()) === -1) {
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

        // Tab switching
        $.targetIs(e, { tagSelector: '.NB-modal-tab-sitebyside' }, function ($t, $p) {
            e.preventDefault();
            self.switch_trainer_tab('sitebyside');
        });

        $.targetIs(e, { tagSelector: '.NB-modal-tab-manage' }, function ($t, $p) {
            e.preventDefault();
            self.switch_trainer_tab('manage');
        });

        // Feed/Story trainer tabs
        $.targetIs(e, { tagSelector: '.NB-modal-tab-feed' }, function ($t, $p) {
            e.preventDefault();
            self.switch_trainer_tab('feed');
        });

        $.targetIs(e, { tagSelector: '.NB-modal-tab-story' }, function ($t, $p) {
            e.preventDefault();
            self.switch_trainer_tab('story');
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

        // Manage tab - sentiment filter (single select, toggle back to all)
        $.targetIs(e, { tagSelector: '.NB-manage-sentiment-control li' }, function ($t) {
            e.preventDefault();
            var sentiment = $t.data('sentiment');
            // Toggle back to 'all' if clicking already-selected item (except 'all' itself)
            if (sentiment !== 'all' && self.manage_filter_sentiment === sentiment) {
                sentiment = 'all';
            }
            self.manage_filter_sentiment = sentiment;
            $('.NB-manage-sentiment-control li', self.$modal).removeClass('NB-active');
            $('.NB-manage-sentiment-control li[data-sentiment="' + sentiment + '"]', self.$modal).addClass('NB-active');
            self.apply_manage_filters();
        });

        // Manage tab - type filter (single select, toggle back to all)
        $.targetIs(e, { tagSelector: '.NB-manage-types-control li' }, function ($t) {
            e.preventDefault();
            var type = $t.data('type');
            // Toggle back to 'all' if clicking already-selected item (except 'all' itself)
            if (type !== 'all' && self.manage_filter_types === type) {
                type = 'all';
            }
            self.manage_filter_types = type;
            $('.NB-manage-types-control li', self.$modal).removeClass('NB-active');
            $('.NB-manage-types-control li[data-type="' + type + '"]', self.$modal).addClass('NB-active');
            self.apply_manage_filters();
        });

        // Manage tab - scope filter (single select, toggle back to all)
        $.targetIs(e, { tagSelector: '.NB-manage-scope-control li' }, function ($t) {
            e.preventDefault();
            var scope = $t.data('scope');
            // Archive gating: non-Archive users cannot filter by folder/global
            if (scope !== 'all' && scope !== 'feed' && !NEWSBLUR.Globals.is_archive) {
                // Show the archive banner
                var $banner = $('.NB-manage-scope-pro-banner', self.$modal);
                $banner.addClass('NB-visible');
                return;
            }
            // Toggle back to 'all' if clicking already-selected item (except 'all' itself)
            if (scope !== 'all' && self.manage_filter_scope === scope) {
                scope = 'all';
            }
            self.manage_filter_scope = scope;
            $('.NB-manage-scope-control li', self.$modal).removeClass('NB-active');
            $('.NB-manage-scope-control li[data-scope="' + scope + '"]', self.$modal).addClass('NB-active');
            // Hide pro banner if visible
            $('.NB-manage-scope-pro-banner', self.$modal).removeClass('NB-visible');
            self.apply_manage_filters();
        });

        // Manage tab - scope pro banner upgrade link
        $.targetIs(e, { tagSelector: '.NB-manage-scope-pro-banner a' }, function ($t) {
            e.preventDefault();
            $.modal.close(function () {
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
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
        var $active_tab = this.$modal.find('.NB-tab.NB-active');

        // Only serialize classifiers from the currently active tab
        // For main tabs (sitebyside/story/feed): serialize all classifiers
        // For manage tab: serialize only changed classifiers
        var is_manage_tab = $active_tab.hasClass('NB-tab-manage');
        var selector = is_manage_tab ? '.NB-classifier.NB-classifier-changed' : '.NB-classifier';

        $active_tab.find(selector).each(function () {
            // Skip non-feed-scope classifiers — they are saved immediately
            // by save_scope_change() and should not be included in the
            // batch save, which would incorrectly re-save them as feed-level.
            var el_scope = $(this).data('scope');
            if (el_scope && el_scope !== 'feed') {
                return;
            }

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
        var $active_tab = this.$modal.find('.NB-tab.NB-active');
        var data = this.serialize_classifier();
        var feed_id = this.feed_id;
        if (this.options.social_feed && this.story_id) {
            feed_id = this.original_feed_id;
        }

        if (this.options['training']) {
            // Invalidate the DOM cache so the modal is rebuilt fresh next time.
            // jQuery .clone() doesn't copy .data() attributes (scope, original-scope),
            // so cached modals would show stale scope state.
            delete this.cache[this.feed_id];
        }
        $save.text('Saving...');
        $save.addClass('NB-disabled');

        this.update_opinions();
        NEWSBLUR.assets.recalculate_story_scores(feed_id);
        NEWSBLUR.assets.stories.trigger('render:intelligence');

        // Collect changed non-feed-scope classifiers to save separately.
        // Also handle scope changes: if a classifier moved from one scope to
        // another (e.g. global→folder), we must remove the old-scope classifier
        // before creating the new-scope one.
        var scoped_saves = [];
        $active_tab.find('.NB-classifier.NB-classifier-changed').each(function () {
            var $cl = $(this);
            var el_scope = $cl.data('scope') || 'feed';
            var original_scope = $cl.data('original-scope') || 'feed';
            var value = $cl.find('.NB-classifier-input-like').val();
            var input_name = $cl.find('.NB-classifier-input-like').attr('name');
            var is_like = $cl.hasClass('NB-classifier-like');
            var is_dislike = $cl.hasClass('NB-classifier-dislike');

            // If scope changed, remove the old classifier at its previous scope
            if (original_scope !== el_scope) {
                var remove_data = {
                    'feed_id': self.feed_id,
                    'scope': original_scope,
                    'folder_name': $cl.data('original-folder-name') || ''
                };
                remove_data['remove_' + input_name] = value;
                scoped_saves.push(remove_data);
            }

            // If the new scope is non-feed, save the classifier at the new scope
            if (el_scope !== 'feed') {
                var scoped_data = {
                    'feed_id': self.feed_id,
                    'scope': el_scope,
                    'folder_name': $cl.data('folder-name') || ''
                };

                if (is_like) {
                    scoped_data[input_name] = value;
                } else if (is_dislike) {
                    scoped_data[input_name.replace('like_', 'dislike_')] = value;
                } else {
                    scoped_data['remove_' + input_name] = value;
                }
                scoped_saves.push(scoped_data);
            }
        });

        this.model.save_classifier(data, function () {
            // Save non-feed-scope classifiers with their individual scope
            _.each(scoped_saves, function (scoped_data) {
                self.model.save_classifier(scoped_data);
            });

            // Clear changed markers only for the tab that was saved
            $active_tab.find('.NB-classifier-changed').removeClass('NB-classifier-changed');
            self.update_save_button();

            if (!keep_modal_open) {
                if (scoped_saves.length) {
                    NEWSBLUR.reader.force_feeds_refresh();
                } else {
                    NEWSBLUR.reader.feed_unread_count(feed_id);
                }
                $.modal.close();
            }
        });
    },

    update_opinions: function () {
        var self = this;
        var feed_id = this.feed_id;
        var $active_tab = this.$modal.find('.NB-tab.NB-active');

        // Only update opinions from the currently active tab
        // For main tabs: all checkboxes; for manage tab: only changed classifiers
        var is_manage_tab = $active_tab.hasClass('NB-tab-manage');
        var selector = is_manage_tab ? '.NB-classifier-changed input[type=checkbox]' : 'input[type=checkbox]';

        $active_tab.find(selector).each(function () {
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

        // Sync scope metadata for classifiers whose scope changed.
        // The *_scope keys in model.classifiers are read by make_classifier()
        // to determine scope icons when reopening the modal.
        $active_tab.find('.NB-classifier').each(function () {
            var $cl = $(this);
            var current_scope = $cl.data('scope') || 'feed';
            var original_scope = $cl.data('original-scope') || 'feed';
            if (current_scope === original_scope) return;

            var value = $cl.find('.NB-classifier-input-like').val();
            var input_name = $cl.find('.NB-classifier-input-like').attr('name') || '';
            var type_name = input_name.replace(/^(dis)?like_/, '').replace(/_regex$/, '');

            // Map input type to scope key (e.g. 'text' → 'texts_scope', 'author' → 'authors_scope')
            var scope_key_map = {
                'tag': 'tags_scope', 'title': 'titles_scope', 'text': 'texts_scope',
                'url': 'urls_scope', 'author': 'authors_scope',
                'title_regex': 'title_regex_scope', 'text_regex': 'text_regex_scope',
                'url_regex': 'url_regex_scope'
            };
            var scope_key = scope_key_map[type_name];
            if (!scope_key) return;

            if (current_scope === 'feed') {
                // Moved back to feed scope — remove scope metadata entry
                if (self.model.classifiers[feed_id][scope_key]) {
                    delete self.model.classifiers[feed_id][scope_key][value];
                }
            } else {
                // Moved to folder/global scope — update scope metadata
                if (!self.model.classifiers[feed_id][scope_key]) {
                    self.model.classifiers[feed_id][scope_key] = {};
                }
                self.model.classifiers[feed_id][scope_key][value] = {
                    scope: current_scope,
                    folder_name: $cl.data('folder-name') || ''
                };
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

        // Update save button to show count for the active tab
        this.update_save_button();

        if (tab === 'manage') {
            // Reset filter state to defaults when switching to manage tab
            this.manage_filter_sentiment = 'all';
            this.manage_filter_types = 'all';
            this.manage_filter_scope = 'all';
            this.manage_filter_feed = null;
            this.manage_filter_search = '';

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
        var self = this;
        var $content = this.make_manage_tab_content();
        $('.NB-tab-manage', this.$modal).empty().append($content);

        // Bind event handlers for feed chooser and search input
        $('.NB-manage-feed-chooser', this.$modal).on('change', function () {
            var feed_id = $(this).val();
            self.manage_filter_feed = feed_id || null;
            self.apply_manage_filters();
        });

        $('.NB-manage-search-input', this.$modal).on('input', function () {
            self.manage_filter_search = $(this).val().toLowerCase();
            self.apply_manage_filters();
        });
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
            // Split scoped classifiers into global (top section) and folder (under their folders)
            var $scoped_section = [];
            var folder_scoped_map = {}; // folder_name -> [$items]
            if (this.all_classifiers_data.scoped_classifiers) {
                var scoped = this.all_classifiers_data.scoped_classifiers;
                var $global_items = [];

                var route_scoped_item = function (item, type, value_key) {
                    var $el = self.make_manage_classifier_item(0, type, item[value_key], item.score, item.scope, item.folder_name);
                    if (item.scope === 'global') {
                        $global_items.push($el);
                    } else if (item.scope === 'folder') {
                        var fn = item.folder_name || ' ';
                        if (!folder_scoped_map[fn]) folder_scoped_map[fn] = [];
                        folder_scoped_map[fn].push($el);
                    }
                };

                _.each(scoped.titles || [], function (item) { route_scoped_item(item, 'title', 'title'); });
                _.each(scoped.authors || [], function (item) { route_scoped_item(item, 'author', 'author'); });
                _.each(scoped.tags || [], function (item) { route_scoped_item(item, 'tag', 'tag'); });
                _.each(scoped.texts || [], function (item) { route_scoped_item(item, 'text', 'text'); });
                _.each(scoped.urls || [], function (item) { route_scoped_item(item, 'url', 'url'); });

                if ($global_items.length) {
                    $scoped_section.push($.make('div', { className: 'NB-manage-folder NB-manage-scoped-section', 'data-feed-id': 0 }, [
                        $.make('div', { className: 'NB-manage-folder-title NB-manage-scoped-title' }, [
                            $.make('span', 'Global Classifiers'),
                            $.make('span', { className: 'NB-manage-scoped-count' }, String($global_items.length))
                        ]),
                        $.make('div', { className: 'NB-manage-folder-feeds NB-classifiers' }, $global_items)
                    ]));
                }
            }

            // Build classifier list by folder, injecting folder-scoped classifiers
            var $folders = [];

            _.each(this.all_classifiers_data.folders, function (folder) {
                var $folder_feeds = [];
                var raw_folder_name = folder.folder_name;

                // Prepend folder-scoped classifiers for this folder
                var $folder_classifiers = folder_scoped_map[raw_folder_name] || [];
                if ($folder_classifiers.length) {
                    $folder_feeds.push($.make('div', {
                        className: 'NB-manage-folder-classifiers NB-classifiers',
                        'data-folder-name': raw_folder_name
                    }, $folder_classifiers));
                }
                delete folder_scoped_map[raw_folder_name];

                _.each(folder.feeds, function (feed) {
                    var $feed_classifiers = self.make_feed_classifiers_for_manage(feed);
                    if ($feed_classifiers) {
                        $folder_feeds.push($feed_classifiers);
                    }
                });

                if ($folder_feeds.length) {
                    var folder_name = raw_folder_name === ' ' ? 'Top Level' : raw_folder_name;
                    $folders.push($.make('div', { className: 'NB-manage-folder', 'data-folder-name': raw_folder_name }, [
                        $.make('div', { className: 'NB-manage-folder-title' }, folder_name),
                        $.make('div', { className: 'NB-manage-folder-feeds' }, $folder_feeds)
                    ]));
                }
            });

            // Handle orphan folders (folder-scoped classifiers for folders not in the feed list)
            _.each(folder_scoped_map, function ($items, raw_folder_name) {
                if ($items.length) {
                    var folder_name = raw_folder_name === ' ' ? 'Top Level' : raw_folder_name;
                    $folders.push($.make('div', { className: 'NB-manage-folder', 'data-folder-name': raw_folder_name }, [
                        $.make('div', { className: 'NB-manage-folder-title' }, folder_name),
                        $.make('div', { className: 'NB-manage-folder-feeds' }, [
                            $.make('div', {
                                className: 'NB-manage-folder-classifiers NB-classifiers',
                                'data-folder-name': raw_folder_name
                            }, $items)
                        ])
                    ]));
                }
            });

            $content = $.make('div', { className: 'NB-manage-training-content' }, [
                this.make_manage_filter_bar(),
                $.make('div', { className: 'NB-manage-training-folders' }, $scoped_section.concat($folders)),
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

    count_classifiers: function (sentiment_filter, type_filter, scope_filter, allowed_feed_ids, search_filter, feeds_matching_search, filter_feed) {
        // Count classifiers, optionally filtered by sentiment, type, scope, feed, and search
        var counts = {
            all: 0,
            likes: 0,
            dislikes: 0,
            title: 0,
            author: 0,
            tag: 0,
            text: 0,
            feed: 0,
            url: 0,
            scope_all: 0,
            scope_feed: 0,
            scope_folder: 0,
            scope_global: 0
        };

        if (!this.all_classifiers_data || !this.all_classifiers_data.folders) {
            return counts;
        }

        var countItems = function (items, type, feed_id) {
            _.each(items || [], function (item) {
                var is_like = item.score > 0;
                var is_dislike = item.score < 0;
                var sentiment = is_like ? 'like' : (is_dislike ? 'dislike' : 'neutral');
                var item_scope = item.scope || 'feed';

                var sentiment_match = !sentiment_filter || sentiment_filter === 'all' || sentiment_filter === sentiment;
                var type_match = !type_filter || type_filter === 'all' || type_filter === type;
                var scope_match = !scope_filter || scope_filter === 'all' || scope_filter === item_scope;
                // Feed/folder filter: global bypasses, folder matches by folder name, feed matches by feed_id
                var feed_match;
                if (item_scope === 'global') {
                    feed_match = true;
                } else if (item_scope === 'folder') {
                    if (!filter_feed) {
                        feed_match = true;
                    } else if (_.string.startsWith(filter_feed, 'river:')) {
                        var cf = filter_feed.replace('river:', '');
                        feed_match = cf === '' || cf === (item.folder_name || '');
                    } else {
                        feed_match = false;
                    }
                } else {
                    feed_match = !allowed_feed_ids || allowed_feed_ids[feed_id];
                }
                var search_match = !search_filter;
                if (!search_match) {
                    var value = '';
                    if (type === 'title') value = item.title || '';
                    else if (type === 'author') value = item.author || '';
                    else if (type === 'tag') value = item.tag || '';
                    else if (type === 'text') value = item.text || '';
                    else if (type === 'feed') value = item.feed_title || '';
                    else if (type === 'url') value = item.url || '';
                    value = value.toLowerCase();
                    search_match = value.indexOf(search_filter) !== -1 ||
                                   (feeds_matching_search && feeds_matching_search[feed_id]);
                }

                if (sentiment_match && type_match && scope_match && feed_match && search_match) {
                    counts.all++;
                    counts[type]++;
                    if (is_like) counts.likes++;
                    if (is_dislike) counts.dislikes++;
                }
                // Scope counts: filtered by sentiment, type, feed, search (but NOT scope)
                if (sentiment_match && type_match && feed_match && search_match) {
                    counts.scope_all++;
                    counts['scope_' + item_scope]++;
                }
            });
        };

        // Count scoped classifiers (global/folder)
        if (this.all_classifiers_data.scoped_classifiers) {
            var scoped = this.all_classifiers_data.scoped_classifiers;
            countItems(scoped.titles, 'title', 0);
            countItems(scoped.authors, 'author', 0);
            countItems(scoped.tags, 'tag', 0);
            countItems(scoped.texts, 'text', 0);
            countItems(scoped.urls, 'url', 0);
        }

        // Count per-feed classifiers
        _.each(this.all_classifiers_data.folders, function (folder) {
            _.each(folder.feeds, function (feed) {
                var classifiers = feed.classifiers;
                if (classifiers) {
                    countItems(classifiers.titles, 'title', feed.feed_id);
                    countItems(classifiers.authors, 'author', feed.feed_id);
                    countItems(classifiers.tags, 'tag', feed.feed_id);
                    countItems(classifiers.texts, 'text', feed.feed_id);
                    countItems(classifiers.feeds, 'feed', feed.feed_id);
                    countItems(classifiers.urls, 'url', feed.feed_id);
                }
            });
        });

        return counts;
    },

    get_filtered_counts: function () {
        // Get counts for display, respecting current filters
        var sentiment = this.manage_filter_sentiment;
        var type = this.manage_filter_types;
        var scope = this.manage_filter_scope;

        // Get allowed feed IDs from folder/site filter
        var allowed_feed_ids = null;
        if (this.manage_filter_feed) {
            allowed_feed_ids = this.get_feeds_in_filter(this.manage_filter_feed);
        }

        // Build feeds matching search (by title or address)
        var search_filter = this.manage_filter_search;
        var feeds_matching_search = {};
        if (search_filter && this.all_classifiers_data && this.all_classifiers_data.folders) {
            _.each(this.all_classifiers_data.folders, function (folder) {
                _.each(folder.feeds, function (feed) {
                    var feed_model = NEWSBLUR.assets.get_feed(feed.feed_id);
                    var feed_title = (feed.feed_title || '').toLowerCase();
                    var feed_address = feed_model ? (feed_model.get('feed_address') || '').toLowerCase() : '';
                    if (feed_title.indexOf(search_filter) !== -1 ||
                        feed_address.indexOf(search_filter) !== -1) {
                        feeds_matching_search[feed.feed_id] = true;
                    }
                });
            });
        }

        // For type buttons: filter by current sentiment, scope, feed, and search
        var type_counts = this.count_classifiers(sentiment, null, scope, allowed_feed_ids, search_filter, feeds_matching_search, this.manage_filter_feed);
        // For sentiment buttons: filter by current type, scope, feed, and search
        var sentiment_counts = this.count_classifiers(null, type, scope, allowed_feed_ids, search_filter, feeds_matching_search, this.manage_filter_feed);
        // For scope buttons: filter by current sentiment, type, feed, and search (NOT scope)
        var scope_counts = this.count_classifiers(sentiment, type, null, allowed_feed_ids, search_filter, feeds_matching_search, this.manage_filter_feed);

        return {
            // Sentiment control counts (filtered by type + scope)
            sentiment_all: sentiment_counts.all,
            sentiment_likes: sentiment_counts.likes,
            sentiment_dislikes: sentiment_counts.dislikes,
            // Type control counts (filtered by sentiment + scope)
            type_all: type_counts.all,
            type_title: type_counts.title,
            type_author: type_counts.author,
            type_tag: type_counts.tag,
            type_text: type_counts.text,
            type_feed: type_counts.feed,
            type_url: type_counts.url,
            // Scope control counts (filtered by sentiment + type)
            scope_all: scope_counts.scope_all,
            scope_feed: scope_counts.scope_feed,
            scope_folder: scope_counts.scope_folder,
            scope_global: scope_counts.scope_global
        };
    },

    update_filter_counts: function () {
        var counts = this.get_filtered_counts();
        var $modal = this.$modal;

        // Helper to update count and toggle zero-count class
        var updateCount = function (selector, count) {
            var $el = $(selector, $modal);
            $el.find('.NB-type-count').text(count);
            $el.toggleClass('NB-zero-count', count === 0);
        };

        // Update sentiment control counts
        updateCount('.NB-manage-filter-sentiment-all', counts.sentiment_all);
        updateCount('.NB-manage-filter-sentiment-like', counts.sentiment_likes);
        updateCount('.NB-manage-filter-sentiment-dislike', counts.sentiment_dislikes);

        // Update type control counts
        updateCount('.NB-manage-filter-type-all', counts.type_all);
        updateCount('.NB-manage-filter-type-title', counts.type_title);
        updateCount('.NB-manage-filter-type-author', counts.type_author);
        updateCount('.NB-manage-filter-type-tag', counts.type_tag);
        updateCount('.NB-manage-filter-type-text', counts.type_text);
        updateCount('.NB-manage-filter-type-feed', counts.type_feed);
        updateCount('.NB-manage-filter-type-url', counts.type_url);

        // Update scope control counts
        updateCount('.NB-manage-filter-scope-all', counts.scope_all);
        updateCount('.NB-manage-filter-scope-feed', counts.scope_feed);
        updateCount('.NB-manage-filter-scope-folder', counts.scope_folder);
        updateCount('.NB-manage-filter-scope-global', counts.scope_global);
    },

    make_manage_filter_bar: function () {
        // Count classifiers by type for displaying in the filter bar
        var counts = this.get_filtered_counts();

        // Build set of feed IDs that have classifiers from the loaded data
        var classifier_feed_ids = {};
        if (this.all_classifiers_data && this.all_classifiers_data.folders) {
            _.each(this.all_classifiers_data.folders, function (folder) {
                _.each(folder.feeds, function (feed) {
                    if (feed.feed_id) {
                        classifier_feed_ids[feed.feed_id] = true;
                    }
                });
            });
        }

        // Also include feeds from folders that have folder-scoped classifiers
        if (this.all_classifiers_data && this.all_classifiers_data.scoped_classifiers) {
            var scoped = this.all_classifiers_data.scoped_classifiers;
            var folder_names = {};
            var collect_folder_names = function (items) {
                _.each(items, function (item) {
                    if (item.scope === 'folder' && item.folder_name) {
                        folder_names[item.folder_name] = true;
                    }
                });
            };
            collect_folder_names(scoped.titles || []);
            collect_folder_names(scoped.authors || []);
            collect_folder_names(scoped.tags || []);
            collect_folder_names(scoped.texts || []);
            collect_folder_names(scoped.urls || []);

            _.each(folder_names, function (val, folder_name) {
                var folder = NEWSBLUR.assets.get_folder(folder_name);
                if (folder) {
                    _.each(folder.feed_ids_in_folder(), function (feed_id) {
                        classifier_feed_ids[feed_id] = true;
                    });
                }
            });
        }

        // Create the feed chooser dropdown, filtered to only feeds with classifiers
        var $feed_chooser = NEWSBLUR.utils.make_feed_chooser({
            include_folders: true,
            feed_id: this.manage_filter_feed,
            filter_feed_ids: classifier_feed_ids,
            skip_social: true,
            skip_searches: true,
            skip_starred: true
        });
        $feed_chooser.addClass('NB-manage-feed-chooser');

        // Remove the "All Folders & Sites" / Top Level from inside the Folders optgroup
        // (it gets added by make_folders but we want it only at the root level)
        $feed_chooser.find('optgroup[label="Folders"] option[value="river:"]').remove();

        // Add "All Folders & Sites" as first option at the root level
        if (!$feed_chooser.find('> option[value=""]').length) {
            $feed_chooser.prepend($.make('option', { value: '' }, 'All Folders & Sites'));
        }
        if (!this.manage_filter_feed) {
            $feed_chooser.val('');
        }

        // Scope filter SVG icons (matching the scope toggle icons from classifier pills)
        var scope_svg_feed = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 11a9 9 0 0 1 9 9"/><path d="M4 4a16 16 0 0 1 16 16"/><circle cx="5" cy="19" r="1"/></svg>';
        var scope_svg_folder = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/></svg>';
        var scope_svg_global = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>';

        var $scope_feed_icon = $.make('span', { className: 'NB-manage-scope-icon NB-manage-scope-icon-feed' });
        $scope_feed_icon.html(scope_svg_feed);
        var $scope_folder_icon = $.make('span', { className: 'NB-manage-scope-icon NB-manage-scope-icon-folder' });
        $scope_folder_icon.html(scope_svg_folder);
        var $scope_global_icon = $.make('span', { className: 'NB-manage-scope-icon NB-manage-scope-icon-global' });
        $scope_global_icon.html(scope_svg_global);

        return $.make('div', { className: 'NB-manage-filter-bar' }, [
            // Row 1: Feed/folder dropdown + search (full width)
            $.make('div', { className: 'NB-manage-filter-row NB-manage-filter-row-1' }, [
                $.make('div', { className: 'NB-manage-filter-group NB-manage-filter-feed' }, [
                    $feed_chooser
                ]),
                $.make('div', { className: 'NB-manage-filter-group NB-manage-filter-search' }, [
                    $.make('input', {
                        type: 'text',
                        className: 'NB-manage-search-input',
                        placeholder: 'Filter by site or classifier...',
                        value: this.manage_filter_search
                    })
                ])
            ]),
            // Row 2: Sentiment (left) + Scope (right)
            $.make('div', { className: 'NB-manage-filter-row NB-manage-filter-row-2' }, [
                $.make('div', { className: 'NB-manage-filter-group NB-manage-filter-sentiment' }, [
                    $.make('ul', { className: 'segmented-control NB-manage-sentiment-control' }, [
                        $.make('li', {
                            className: 'NB-manage-filter-sentiment-all' + (this.manage_filter_sentiment === 'all' ? ' NB-active' : '') + (counts.sentiment_all === 0 ? ' NB-zero-count' : ''),
                            'data-sentiment': 'all'
                        }, [
                            $.make('span', { className: 'NB-type-label' }, 'All'),
                            $.make('span', { className: 'NB-type-count' }, counts.sentiment_all)
                        ]),
                        $.make('li', {
                            className: 'NB-manage-filter-sentiment-like' + (this.manage_filter_sentiment === 'like' ? ' NB-active' : '') + (counts.sentiment_likes === 0 ? ' NB-zero-count' : ''),
                            'data-sentiment': 'like'
                        }, [
                            $.make('span', { className: 'NB-manage-filter-icon NB-icon-like' }),
                            $.make('span', { className: 'NB-type-label' }, 'Likes'),
                            $.make('span', { className: 'NB-type-count' }, counts.sentiment_likes)
                        ]),
                        $.make('li', {
                            className: 'NB-manage-filter-sentiment-dislike' + (this.manage_filter_sentiment === 'dislike' ? ' NB-active' : '') + (counts.sentiment_dislikes === 0 ? ' NB-zero-count' : ''),
                            'data-sentiment': 'dislike'
                        }, [
                            $.make('span', { className: 'NB-manage-filter-icon NB-icon-dislike' }),
                            $.make('span', { className: 'NB-type-label' }, 'Dislikes'),
                            $.make('span', { className: 'NB-type-count' }, counts.sentiment_dislikes)
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-manage-filter-group NB-manage-filter-scope' }, [
                    $.make('ul', { className: 'segmented-control NB-manage-scope-control' }, [
                        $.make('li', {
                            className: 'NB-manage-filter-scope-all' + (this.manage_filter_scope === 'all' ? ' NB-active' : '') + (counts.scope_all === 0 ? ' NB-zero-count' : ''),
                            'data-scope': 'all'
                        }, [
                            $.make('span', { className: 'NB-type-label' }, 'All'),
                            $.make('span', { className: 'NB-type-count' }, counts.scope_all)
                        ]),
                        $.make('li', {
                            className: 'NB-manage-filter-scope-feed' + (this.manage_filter_scope === 'feed' ? ' NB-active' : '') + (counts.scope_feed === 0 ? ' NB-zero-count' : ''),
                            'data-scope': 'feed'
                        }, [
                            $scope_feed_icon,
                            $.make('span', { className: 'NB-type-label' }, 'Per Site'),
                            $.make('span', { className: 'NB-type-count' }, counts.scope_feed)
                        ]),
                        $.make('li', {
                            className: 'NB-manage-filter-scope-folder' + (this.manage_filter_scope === 'folder' ? ' NB-active' : '') + (counts.scope_folder === 0 ? ' NB-zero-count' : ''),
                            'data-scope': 'folder'
                        }, [
                            $scope_folder_icon,
                            $.make('span', { className: 'NB-type-label' }, 'Per Folder'),
                            $.make('span', { className: 'NB-type-count' }, counts.scope_folder)
                        ]),
                        $.make('li', {
                            className: 'NB-manage-filter-scope-global' + (this.manage_filter_scope === 'global' ? ' NB-active' : '') + (counts.scope_global === 0 ? ' NB-zero-count' : ''),
                            'data-scope': 'global'
                        }, [
                            $scope_global_icon,
                            $.make('span', { className: 'NB-type-label' }, 'Global'),
                            $.make('span', { className: 'NB-type-count' }, counts.scope_global)
                        ])
                    ])
                ])
            ]),
            // Archive banner for scope filter (hidden by default)
            $.make('div', { className: 'NB-manage-scope-pro-banner' }, [
                $.make('span', 'Scoped classifiers are only available to '),
                $.make('a', { href: '#', className: 'NB-manage-scope-pro-link' }, 'Premium Archive'),
                $.make('span', ' subscribers.')
            ]),
            // Row 3: Type control (full width)
            $.make('div', { className: 'NB-manage-filter-row NB-manage-filter-row-3' }, [
                $.make('ul', { className: 'segmented-control NB-manage-types-control' }, [
                    $.make('li', {
                        className: 'NB-manage-filter-type-all' + (this.manage_filter_types === 'all' ? ' NB-active' : '') + (counts.type_all === 0 ? ' NB-zero-count' : ''),
                        'data-type': 'all'
                    }, [
                        $.make('span', { className: 'NB-type-label' }, 'All'),
                        $.make('span', { className: 'NB-type-count' }, counts.type_all)
                    ]),
                    $.make('li', {
                        className: 'NB-manage-filter-type-title' + (this.manage_filter_types === 'title' ? ' NB-active' : '') + (counts.type_title === 0 ? ' NB-zero-count' : ''),
                        'data-type': 'title'
                    }, [
                        $.make('span', { className: 'NB-type-label' }, 'Title'),
                        $.make('span', { className: 'NB-type-count' }, counts.type_title)
                    ]),
                    $.make('li', {
                        className: 'NB-manage-filter-type-author' + (this.manage_filter_types === 'author' ? ' NB-active' : '') + (counts.type_author === 0 ? ' NB-zero-count' : ''),
                        'data-type': 'author'
                    }, [
                        $.make('span', { className: 'NB-type-label' }, 'Author'),
                        $.make('span', { className: 'NB-type-count' }, counts.type_author)
                    ]),
                    $.make('li', {
                        className: 'NB-manage-filter-type-tag' + (this.manage_filter_types === 'tag' ? ' NB-active' : '') + (counts.type_tag === 0 ? ' NB-zero-count' : ''),
                        'data-type': 'tag'
                    }, [
                        $.make('span', { className: 'NB-type-label' }, 'Tag'),
                        $.make('span', { className: 'NB-type-count' }, counts.type_tag)
                    ]),
                    $.make('li', {
                        className: 'NB-manage-filter-type-text' + (this.manage_filter_types === 'text' ? ' NB-active' : '') + (counts.type_text === 0 ? ' NB-zero-count' : ''),
                        'data-type': 'text'
                    }, [
                        $.make('span', { className: 'NB-type-label' }, 'Text'),
                        $.make('span', { className: 'NB-type-count' }, counts.type_text)
                    ]),
                    $.make('li', {
                        className: 'NB-manage-filter-type-feed' + (this.manage_filter_types === 'feed' ? ' NB-active' : '') + (counts.type_feed === 0 ? ' NB-zero-count' : ''),
                        'data-type': 'feed'
                    }, [
                        $.make('span', { className: 'NB-type-label' }, 'Site'),
                        $.make('span', { className: 'NB-type-count' }, counts.type_feed)
                    ]),
                    $.make('li', {
                        className: 'NB-manage-filter-type-url' + (this.manage_filter_types === 'url' ? ' NB-active' : '') + (counts.type_url === 0 ? ' NB-zero-count' : ''),
                        'data-type': 'url'
                    }, [
                        $.make('span', { className: 'NB-type-label' }, 'URL'),
                        $.make('span', { className: 'NB-type-count' }, counts.type_url)
                    ])
                ])
            ])
        ]);
    },

    apply_manage_filters: function () {
        var self = this;
        // Always query the DOM for the current modal to avoid stale references
        var $modal = $('.NB-modal-classifiers');
        var $items = $('.NB-manage-classifier-item', $modal);
        var visible_feeds = {};

        // Build a set of feed IDs that match the feed/folder filter
        var allowed_feed_ids = null;
        if (this.manage_filter_feed) {
            allowed_feed_ids = this.get_feeds_in_filter(this.manage_filter_feed);
        }

        // Build a set of feed IDs whose titles or addresses match the search
        // When a feed title/address matches, we show ALL classifiers under that feed
        var feeds_matching_search = {};
        if (this.manage_filter_search) {
            $('.NB-manage-feed', $modal).each(function () {
                var $feed = $(this);
                var feed_id = $feed.data('feed-id');
                var feed_title = $feed.find('.NB-manage-feed-title').text().toLowerCase();
                var feed = NEWSBLUR.assets.get_feed(feed_id);
                var feed_address = feed ? (feed.get('feed_address') || '').toLowerCase() : '';
                if (feed_title.indexOf(self.manage_filter_search) !== -1 ||
                    feed_address.indexOf(self.manage_filter_search) !== -1) {
                    feeds_matching_search[feed_id] = true;
                }
            });
        }

        $items.each(function () {
            var $item = $(this);
            var type = $item.data('type');
            var score = $item.data('score');
            var feed_id = $item.data('feed-id');
            var item_scope = $item.data('scope') || 'feed';
            var value = String($item.data('value') || '').toLowerCase();
            var sentiment = score > 0 ? 'like' : 'dislike';

            var type_match = self.manage_filter_types === 'all' || self.manage_filter_types === type;
            var sentiment_match = self.manage_filter_sentiment === 'all' || self.manage_filter_sentiment === sentiment;
            var scope_match = self.manage_filter_scope === 'all' || self.manage_filter_scope === item_scope;
            // Feed/folder filter: global bypasses, folder matches by folder name, feed matches by feed_id
            var feed_match;
            if (item_scope === 'global') {
                feed_match = true;
            } else if (item_scope === 'folder') {
                if (!self.manage_filter_feed) {
                    feed_match = true;
                } else if (_.string.startsWith(self.manage_filter_feed, 'river:')) {
                    var filter_folder = self.manage_filter_feed.replace('river:', '');
                    var item_folder = $item.data('folder-name') || '';
                    feed_match = filter_folder === '' || filter_folder === item_folder;
                } else {
                    feed_match = false;
                }
            } else {
                feed_match = !allowed_feed_ids || allowed_feed_ids[feed_id];
            }
            // Search matches if: no search, OR classifier value matches, OR parent feed title matches
            var search_match = !self.manage_filter_search ||
                               value.indexOf(self.manage_filter_search) !== -1 ||
                               feeds_matching_search[feed_id];

            if (type_match && sentiment_match && scope_match && feed_match && search_match) {
                $item.show();
                visible_feeds[feed_id] = true;
            } else {
                $item.hide();
            }
        });

        // Hide/show feeds based on whether they have visible items
        $('.NB-manage-feed', $modal).each(function () {
            var $feed = $(this);
            var feed_id = $feed.data('feed-id');

            if (visible_feeds[feed_id]) {
                $feed.show();
            } else {
                $feed.hide();
            }
        });

        // Hide/show folder-scoped classifier containers
        $('.NB-manage-folder-classifiers', $modal).each(function () {
            var $container = $(this);
            var has_visible = $container.find('.NB-manage-classifier-item').filter(function () {
                return $(this).css('display') !== 'none';
            }).length > 0;
            if (has_visible) {
                $container.show();
            } else {
                $container.hide();
            }
        });

        // Hide/show folders based on whether they have visible feeds or items
        $('.NB-manage-folder', $modal).each(function () {
            var $folder = $(this);

            // For the global scoped section, check visible classifier items directly
            if ($folder.hasClass('NB-manage-scoped-section')) {
                var has_visible_items = $folder.find('.NB-manage-classifier-item').filter(function () {
                    return $(this).css('display') !== 'none';
                }).length > 0;
                if (has_visible_items) {
                    $folder.show();
                } else {
                    $folder.hide();
                }
                return;
            }

            // Check for visible feeds OR visible folder-scoped classifiers
            var has_visible_feed = $folder.find('.NB-manage-feed').filter(function () {
                return $(this).css('display') !== 'none';
            }).length > 0;

            var has_visible_folder_classifier = $folder.find('.NB-manage-folder-classifiers .NB-manage-classifier-item').filter(function () {
                return $(this).css('display') !== 'none';
            }).length > 0;

            if (has_visible_feed || has_visible_folder_classifier) {
                $folder.show();
            } else {
                $folder.hide();
            }
        });

        // Update the filter badge counts dynamically
        this.update_filter_counts();
    },

    get_feeds_in_filter: function (filter_value) {
        var feed_ids = {};

        if (!filter_value) {
            return null; // No filter, allow all
        }

        // Check if it's a river (folder) or a specific feed
        if (_.string.startsWith(filter_value, 'river:')) {
            // It's a folder - get all feeds in this folder
            var folder_name = filter_value.replace('river:', '');
            if (folder_name === '') {
                return null; // Root folder = all feeds
            }
            var folder = NEWSBLUR.assets.get_folder(folder_name);
            if (folder) {
                var folder_feeds = folder.feed_ids_in_folder();
                _.each(folder_feeds, function (id) {
                    feed_ids[id] = true;
                });
            }
        } else if (_.string.startsWith(filter_value, 'feed:')) {
            // It's a specific feed
            var feed_id = filter_value.replace('feed:', '');
            feed_ids[feed_id] = true;
        } else {
            // Try as a direct feed ID
            feed_ids[filter_value] = true;
        }

        return feed_ids;
    },

    make_feed_classifiers_for_manage: function (feed) {
        var self = this;
        var classifiers = feed.classifiers;
        var $classifiers_list = [];

        // Titles
        _.each(classifiers.titles, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'title', c.title, c.score, c.scope, c.folder_name));
        });

        // Authors
        _.each(classifiers.authors, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'author', c.author, c.score, c.scope, c.folder_name));
        });

        // Tags
        _.each(classifiers.tags, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'tag', c.tag, c.score, c.scope, c.folder_name));
        });

        // Texts
        _.each(classifiers.texts, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'text', c.text, c.score, c.scope, c.folder_name));
        });

        // URLs (includes both regular URLs and URL regex, distinguished by is_regex flag)
        _.each(classifiers.urls, function (c) {
            $classifiers_list.push(self.make_manage_classifier_item(feed.feed_id, 'url', c.url, c.score, c.scope, c.folder_name));
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

    make_manage_classifier_item: function (feed_id, type, value, score, scope, folder_name) {
        var type_label = type.charAt(0).toUpperCase() + type.slice(1);
        if (type === 'feed') type_label = 'Site';
        if (type === 'url') type_label = 'URL';

        var effective_scope = scope || 'feed';
        var scope_svgs = {
            'feed': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 11a9 9 0 0 1 9 9"/><path d="M4 4a16 16 0 0 1 16 16"/><circle cx="5" cy="19" r="1"/></svg>',
            'folder': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/></svg>',
            'global': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>'
        };

        // Build type badge with scope icon
        var $type_badge;
        if (type === 'feed') {
            $type_badge = $.make('span', { className: 'NB-classifier-type-badge NB-classifier-type-feed' }, [
                $.make('span', { className: 'NB-classifier-type-label' }, type_label)
            ]);
        } else {
            var $scope_icon = $.make('span', { className: 'NB-classifier-scope-icon NB-scope-' + effective_scope });
            $scope_icon.html(scope_svgs[effective_scope]);
            $type_badge = $.make('span', { className: 'NB-classifier-type-badge NB-scope-' + effective_scope }, [
                $scope_icon,
                $.make('span', { className: 'NB-classifier-type-label' }, type_label)
            ]);
        }

        var $item = $.make('div', {
            className: 'NB-manage-classifier-item',
            'data-feed-id': feed_id,
            'data-type': type,
            'data-value': value,
            'data-score': score,
            'data-scope': effective_scope,
            'data-folder-name': folder_name || ''
        }, [
            $.make('div', { className: 'NB-classifier NB-classifier-' + type + (score > 0 ? ' NB-classifier-like' : ' NB-classifier-dislike') }, [
                $.make('input', { type: 'checkbox', className: 'NB-classifier-input-like', name: 'like_' + type, value: value }),
                $.make('input', { type: 'checkbox', className: 'NB-classifier-input-dislike', name: 'dislike_' + type, value: value }),
                $.make('div', { className: 'NB-classifier-icon-like' }),
                $.make('div', { className: 'NB-classifier-icon-dislike' }, [
                    $.make('div', { className: 'NB-classifier-icon-dislike-inner' })
                ]),
                $.make('label', [
                    $type_badge,
                    $.make('span', value)
                ])
            ])
        ]);

        // Set initial checkbox state and store original state for change tracking
        var original_state = 'neutral';
        if (score > 0) {
            $('.NB-classifier-input-like', $item).prop('checked', true);
            original_state = 'like';
        } else if (score < 0) {
            $('.NB-classifier-input-dislike', $item).prop('checked', true);
            original_state = 'dislike';
        }
        $('.NB-classifier', $item).data('original-state', original_state);

        return $item;
    },

    change_manage_classifier: function ($item, opinion) {
        var $classifier = $('.NB-classifier', $item);
        var feed_id = $item.data('feed-id');
        var type = $item.data('type');
        var value = $item.data('value');
        var orig_score = $item.data('score');
        var scope = $item.data('scope') || 'feed';
        var folder_name = $item.data('folder-name') || '';
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
                current_score: current_score,
                scope: scope,
                folder_name: folder_name
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
            var label = total_changes === 1 ? 'Save 1 classifier' : 'Save ' + total_changes + ' classifiers';
            $save.text(label).removeClass('NB-disabled').show();
            $prompt.hide();
            $saved.hide();
        } else {
            $save.addClass('NB-disabled').hide();
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

        // Separate scoped classifiers (feed_id=0, non-feed scope) from feed-level ones
        var classifiers_by_feed = {};
        var scoped_saves = [];

        _.each(feeds_to_save, function (feed_id) {
            var changes = self.manage_dirty_feeds[feed_id] || {};
            var feed_changes = {};
            _.each(changes, function (change, key) {
                if (change.scope && change.scope !== 'feed') {
                    // Scoped classifier — build individual save data
                    var name;
                    if (change.current_score === 1) {
                        name = 'like_' + change.type;
                    } else if (change.current_score === -1) {
                        name = 'dislike_' + change.type;
                    } else if (change.orig_score > 0) {
                        name = 'remove_like_' + change.type;
                    } else {
                        name = 'remove_dislike_' + change.type;
                    }
                    var save_data = {
                        'feed_id': 0,
                        'scope': change.scope,
                        'folder_name': change.folder_name || ''
                    };
                    save_data[name] = change.value;
                    scoped_saves.push(save_data);
                } else {
                    feed_changes[key] = change;
                }
            });

            if (Object.keys(feed_changes).length > 0) {
                // Temporarily replace with only feed-level changes for serialization
                self.manage_dirty_feeds[feed_id] = feed_changes;
                classifiers_by_feed[feed_id] = self.serialize_manage_classifiers_for_feed(feed_id);
            }
        });

        var pending = (Object.keys(classifiers_by_feed).length > 0 ? 1 : 0) + scoped_saves.length;
        var on_complete = function () {
            pending--;
            if (pending > 0) return;

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
        };

        var on_error = function () {
            $save.removeClass('NB-disabled');
            self.update_manage_save_button();
        };

        // Save feed-level classifiers via bulk endpoint
        if (Object.keys(classifiers_by_feed).length > 0) {
            this.model.save_all_classifiers(classifiers_by_feed, on_complete, on_error);
        }

        // Save scoped classifiers individually with scope metadata
        _.each(scoped_saves, function (save_data) {
            self.model.save_classifier(save_data, on_complete);
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
