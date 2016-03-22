NEWSBLUR.ReaderClassifierTrainer = function(options) {
    var defaults = {
        'width': 620,
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

NEWSBLUR.ReaderClassifierFeed = function(feed_id, options) {
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


NEWSBLUR.ReaderClassifierStory = function(story_id, feed_id, options) {
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
    
    runner_trainer: function(reload) {
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
    
    runner_feed: function() {
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
        this.open_modal(_.bind(function() {
            this.fit_classifiers();
        }, this));
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));

        if (!this.options.feed_loaded) {
            _.defer(_.bind(function() {
                this.load_single_feed_trainer();
            }, this));
        }
    },
    
    runner_story: function() {
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
        this.open_modal(_.bind(function() {
            this.fit_classifiers();
        }, this));
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));

        if (!this.options.feed_loaded) {
            _.defer(_.bind(function() {
                this.load_single_feed_trainer();
            }, this));
        }
    },
    
    load_previous_feed_in_trainer: function() {
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
    
    load_next_feed_in_trainer: function() {
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
    
    load_feed: function(trainer_data) {
        this.feed_id = trainer_data['feed_id'] || trainer_data['id'];
        this.feed = this.model.get_feed(this.feed_id);
        this.feed_tags = trainer_data['feed_tags'];
        this.feed_authors = trainer_data['feed_authors'];
        this.user_classifiers = trainer_data['classifiers'];
        this.feed_publishers = new Backbone.Collection(trainer_data['popular_publishers']);
        this.feed.set('num_subscribers', trainer_data['num_subscribers'], {silent: true});
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
    
    reload_modal: function(callback) {
        this.flags.modal_loading = setInterval(_.bind(function() {
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
    
    fit_classifiers: function() {
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
            form_height = Math.min(new_form_height, form_height-1);
        }
    },
    
    get_feeds_trainer: function() {
        this.model.get_feeds_trainer(null, $.rescope(this.load_feeds_trainer, this));
    },
    
    load_feeds_trainer: function(e, data) {
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
    
    retrain_all_sites: function() {
        $('.NB-modal-submit-reset', this.$modal).text('Rewinding...').attr('disabled', true).addClass('NB-disabled');
        
        this.model.retrain_all_sites(_.bind(function(data) {
            this.load_feeds_trainer(null, data);
            this.load_next_feed_in_trainer();
        }, this));
    },
    
    find_story_and_feed: function() {
        if (this.story_id) {
            this.story = this.model.get_story(this.story_id);
        }
        
        this.feed = this.model.get_feed(this.feed_id);
        
        if (this.options.feed_loaded && this.feed) {
          this.feed_tags = this.model.get_feed_tags();
          this.feed_authors = this.model.get_feed_authors();
          $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', $.favicon(this.feed));
          $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed.get('feed_title'));
          $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).html(Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true));
        }
    },
    
    load_single_feed_trainer: function() {
        var self = this;
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        var get_trainer_fn = this.model.get_feeds_trainer;
        if (this.options.social_feed) {
            get_trainer_fn = this.model.get_social_trainer;
        }
        get_trainer_fn.call(this.model, this.feed_id, function(data) {
            self.trainer_data = data;
            if (data && data.length) {
              // Should only be one feed
              self.load_feed(data[0]);
            }
        });
    },
    
    make_trainer_intro: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal NB-modal-trainer'}, [
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
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_focus.png'}),
                    ' are stories you like',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_unread.png'}),
                    ' are stories you have not yet rated',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_hidden.png'}),
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
    
    make_trainer_outro: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal NB-modal-trainer'}, [
            $.make('h2', { className: 'NB-modal-title' }, 'Congratulations! You\'re done.'),
            $.make('h3', { className: 'NB-modal-subtitle' }, 'Here\'s what happens next:'),
            $.make('ol', { className: 'NB-trainer-points' }, [
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_classifier_tag.png', style: 'float: right', width: 135 }),
                    $.make('b', 'You can change your opinions.'),
                    ' You can click the ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs_up.png', style: 'vertical-align: middle;padding: 0 8px 0 2px', width: 14, height: 20 }),
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs_down.png', style: 'vertical-align: top; padding: 0', width: 14, height: 20 }),
                    ' buttons next to stories as you read them.'
                ]),
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/intelligence_slider_positive.png', style: 'float: right', width: 114, height: 29 }),
                    $.make('b', 'As a reminder, use the intelligence slider to select a filter:'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_hidden.png'}),
                    ' are stories you don\'t like',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_unread.png'}),
                    ' are stories you have not yet rated',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_focus.png'}),
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
    
    make_modal_feed: function() {
        var self = this;
        var feed = this.feed;

        // NEWSBLUR.log(['Make feed', feed, this.feed_authors, this.feed_tags, this.options['feed_loaded']]);
        
        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal ' + (this.options['training'] && 'NB-modal-trainer') }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, ''),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                (this.options['training'] && $.make('div', { className: 'NB-classifier-trainer-counts' })),
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed) }),
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
                  $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-next NB-modal-submit-save' }, 'Save & Next '+$.entity('&raquo;')),
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
        
    make_modal_story: function() {
        var self = this;
        var story = this.story;
        var feed = this.feed;
        
        // NEWSBLUR.log(['Make Story', story, feed]);
        
        // HTML entities decoding.
        story_title = _.string.trim($('<div/>').html(story.get('story_title')).text());
        
        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal' }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                (this.options['training'] && $.make('div', { className: 'NB-classifier-trainer-counts' })),
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed) }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title')),
                    $.make('span', { className: 'NB-modal-feed-subscribers' }, Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true))
                ])
            ]),
            (this.options['feed_loaded'] &&
                $.make('form', { method: 'post' }, [
                    (story_title && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                        $.make('h5', 'Story Title'),
                        $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                            $.make('input', { type: 'text', value: story_title, className: 'NB-classifier-title-highlight' }),
                            this.make_classifier('<span class="NB-classifier-title-placeholder">Highlight phrases to look for in future stories</span>', '', 'title'),
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
    
    make_modal_title: function() {
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
    
    make_modal_trainer_count: function() {
        var $count = $('.NB-classifier-trainer-counts', this.$modal);
        var count = this.trainer_iterator + 1;
        var total = this.trainer_data.length;
        $count.html(count + '/' + total);
    },
    
    make_user_titles: function(existing_title) {
        var $titles = [];
        var titles = _.keys(this.user_classifiers.titles);
        
        _.each(titles, _.bind(function(title) {
            if (!existing_title || existing_title.toLowerCase().indexOf(title.toLowerCase()) != -1) {
                var $title = this.make_classifier(title, title, 'title');
                $titles.push($title);
            }
        }, this));
        
        return $titles;
    },
    
    make_authors: function(authors) {
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
    
    make_user_authors: function() {
        var $authors = [];
        var user_authors = _.keys(this.user_classifiers.authors);
        var feed_authors = _.map(this.feed_authors, function(author) { return author[0]; });
        var authors = _.reduce(user_authors, function(memo, author, i) {
            if (!_.contains(feed_authors, author)) return memo.concat(author);
            return memo;
        }, []);
        
        return this.make_authors(authors);
    },
    
    make_tags: function(tags) {
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
    
    make_user_tags: function() {
        var $tags = [];
        var user_tags = _.keys(this.user_classifiers.tags);
        var feed_tags = _.map(this.feed_tags, function(tag) { return tag[0]; });
        var tags = _.reduce(user_tags, function(memo, tag, i) {
            if (!_.contains(feed_tags, tag)) return memo.concat(tag);
            return memo;
        }, []);
        
        return this.make_tags(tags);
    },
    
    make_publishers: function(publishers) {
        var $publishers = publishers.map(_.bind(function(publisher) {
            return this.make_publisher(publisher);
        }, this));
        
        return $publishers;
    },
        
    make_publisher: function(publisher) {
        var $publisher = this.make_classifier(_.string.truncate(publisher.get('feed_title'), 50), 
                                              publisher.id, 'feed', publisher.get('story_count'), publisher);
        return $publisher;
    },
    
    make_classifier: function(classifier_title, classifier_value, classifier_type, classifier_count, classifier) {
        var score = 0;
        // NEWSBLUR.log(['classifiers', this.user_classifiers, classifier_value, this.user_classifiers[classifier_type+'s']]);
        if (this.user_classifiers[classifier_type+'s'] && 
            classifier_value in this.user_classifiers[classifier_type+'s']) {
            score = this.user_classifiers[classifier_type+'s'][classifier_value];
        }
        
        var classifier_type_title = Inflector.capitalize(classifier_type=='feed' ?
                                    'site' :
                                    classifier_type);
                                    
        var $classifier = $.make('span', { className: 'NB-classifier-container' }, [
            $.make('span', { className: 'NB-classifier NB-classifier-'+classifier_type }, [
                $.make('input', { 
                    type: 'checkbox', 
                    className: 'NB-classifier-input-like', 
                    name: 'like_'+classifier_type, 
                    value: classifier_value
                }),
                $.make('input', { 
                    type: 'checkbox', 
                    className: 'NB-classifier-input-dislike', 
                    name: 'dislike_'+classifier_type, 
                    value: classifier_value
                }),
                $.make('div', { className: 'NB-classifier-icon-like' }),
                $.make('div', { className: 'NB-classifier-icon-dislike' }, [
                    $.make('div', { className: 'NB-classifier-icon-dislike-inner' })
                ]),
                $.make('label', [
                    (classifier_type == 'feed' && 
                        $.make('img', { 
                            className: 'feed_favicon', 
                            src: $.favicon(classifier)
                        })),
                    $.make('b', classifier_type_title+': '),
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
        
        $('.NB-classifier', $classifier).bind('mouseenter', function(e) {
            $(e.currentTarget).addClass('NB-classifier-hover-like');
        }).bind('mouseleave', function(e) {
            $(e.currentTarget).removeClass('NB-classifier-hover-like');
        });
        
        $('.NB-classifier-icon-dislike', $classifier).bind('mouseenter', function(e) {
            $('.NB-classifier', $classifier).addClass('NB-classifier-hover-dislike');
        }).bind('mouseleave', function(e) {
            $('.NB-classifier', $classifier).removeClass('NB-classifier-hover-dislike');
        });
        
        return $classifier;
    },
        
    change_classifier: function($classifier, classifier_opinion) {
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
    
    end: function() {
        this.model.preference('has_trained_intelligence', true);
        NEWSBLUR.reader.check_hide_getting_started();
        $.modal.close();
    },
    
    // ==========
    // = Events =
    // ==========
    
    handle_text_highlight: function() {
        var self = this;
        var $title_highlight = $('.NB-classifier-title-highlight', this.$modal);
        var $title_placeholder = $('.NB-classifier-title-placeholder', this.$modal);
        var $title_classifier = $title_placeholder.parents('.NB-classifier').eq(0);
        var $title_checkboxs = $('.NB-classifier-input-like, .NB-classifier-input-dislike', $title_classifier);

        var update = function() {
            var text = $.trim($(this).getSelection().text);
            
            if (text.length && $title_placeholder.text() != text) {
                $title_placeholder.text(text);
                $title_checkboxs.val(text);
                if (!$title_classifier.is('.NB-classifier-like,.NB-classifier-dislike')) {
                    self.change_classifier($title_classifier, 'like');
                }
            }
        };
        
        $title_highlight
            .keydown(update).keyup(update)
            .mousedown(update).mouseup(update).mousemove(update);
        $title_checkboxs.val($title_highlight.val());

        $title_placeholder.parents('.NB-classifier').bind('click', function() {
            if ($title_highlight.val() == $title_checkboxs.val()) {
                $title_placeholder.text($title_highlight.val());
            }
        });
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
    
    handle_clicks: function(elem, e) {
        var self = this;
                
        if (this.options['training']) {
            $.targetIs(e, { tagSelector: '.NB-modal-submit-begin' }, function($t, $p){
                e.preventDefault();
                self.load_next_feed_in_trainer();
            });
            $.targetIs(e, { tagSelector: '.NB-modal-submit-save.NB-modal-submit-next' }, function($t, $p){
                e.preventDefault();
                self.save(true);
                self.load_next_feed_in_trainer();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-back' }, function($t, $p){
                e.preventDefault();
                self.load_previous_feed_in_trainer();
            });
            
            $.targetIs(e, { tagSelector: '.NB-modal-submit-reset' }, function($t, $p){
                e.preventDefault();
                self.retrain_all_sites();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-grey' }, function($t, $p){
                e.preventDefault();
                self.save();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-end' }, function($t, $p){
                e.preventDefault();
                NEWSBLUR.reader.force_feed_refresh();
                self.end();
                // NEWSBLUR.reader.open_feed(self.feed_id, true);
                // TODO: Update counts in active feed.
            });
        } else {
            $.targetIs(e, { tagSelector: '.NB-modal-submit-save:not(.NB-modal-submit-next)' }, function($t, $p){
                e.preventDefault();
                self.save();
                return false;
            });
        }
        
        var stop = false;
        $.targetIs(e, { tagSelector: '.NB-classifier-icon-dislike' }, function($t, $p){
            e.preventDefault();
            stop = true;
            self.change_classifier($t.closest('.NB-classifier'), 'dislike');
        });
        if (stop) return;
        $.targetIs(e, { tagSelector: '.NB-classifier' }, function($t, $p){
            e.preventDefault();
            self.change_classifier($t, 'like');
        });
    },
    
    serialize_classifier: function() {
        var data = {};
        $('.NB-classifier', this.$modal).each(function() {
            var value = $('.NB-classifier-input-like', this).val();
            if ($('.NB-classifier-input-like, .NB-classifier-input-dislike', this).is(':checked')) {
                var name = $('input:checked', this).attr('name');
                if (!data[name]) data[name] = [];
                data[name].push(value);
            } else {
                var name = 'remove_'+$('.NB-classifier-input-like', this).attr('name');
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
        
    save: function(keep_modal_open) {
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
        this.model.save_classifier(data, function() {
            if (!keep_modal_open) {
                NEWSBLUR.reader.feed_unread_count(feed_id);
                $.modal.close();
            }
        });
    },
    
    update_opinions: function() {
        var self = this;
        var feed_id = this.feed_id;
        
        $('input[type=checkbox]', this.$modal).each(function() {
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
