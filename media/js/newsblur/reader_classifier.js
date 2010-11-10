NEWSBLUR.ReaderClassifierTrainer = function(options) {
    var defaults = {
        'score': 1,
        'training': true
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
    this.score = this.options['score'];
    this.model = NEWSBLUR.AssetModel.reader();
    this.runner_trainer();
};

NEWSBLUR.ReaderClassifierFeed = function(feed_id, options) {
    var defaults = {
        'score': 1,
        'training': false,
        'feed_loaded': true
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
    this.score = this.options['score'];
    this.model = NEWSBLUR.AssetModel.reader();
    this.runner_feed();
};


NEWSBLUR.ReaderClassifierStory = function(story_id, feed_id, options) {
    var defaults = {
        'score': 1
    };
    
    this.flags = {
        'publisher': false,
        'story': true,
        'modal_loading': false,
        'modal_loaded': false
    };
    this.story_id = story_id;
    this.feed_id = feed_id;
    this.options = $.extend({}, defaults, options);
    this.score = this.options['score'];
    this.model = NEWSBLUR.AssetModel.reader();
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
            
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));
    },
    
    runner_feed: function() {
        
        if (this.options.feed_loaded) {
            this.user_classifiers = this.model.classifiers;
        } else {
            this.user_classifiers = {};
        }
        this.find_story_and_feed();
        this.make_modal_feed();
        this.make_modal_title();
        this.handle_cancel();
        this.open_modal();
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));

        if (!this.options.feed_loaded) {
            _.defer(_.bind(function() {
                this.load_single_feed_trainer();
            }, this));
        }
    },
    
    runner_story: function() {
        this.user_classifiers = this.model.classifiers;
        
        this.find_story_and_feed();
        this.make_modal_story();
        this.handle_text_highlight();
        this.make_modal_title();
        this.handle_cancel();
        this.open_modal();
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));
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
        this.trainer_iterator = this.trainer_iterator + 1;
        var trainer_data = this.trainer_data[this.trainer_iterator];
        // NEWSBLUR.log(['load_next_feed_in_trainer', this.trainer_iterator, trainer_data]);
        if (!trainer_data || this.trainer_iterator >= trainer_data_length) {
            this.make_trainer_outro();
            this.reload_modal();
            this.load_feeds_trainer(null, this.trainer_data);
        } else {
            this.feed_id = trainer_data['feed_id'];
            this.load_feed(trainer_data);
        }
    },
    
    load_feed: function(trainer_data) {
        this.feed_id = trainer_data['feed_id'];
        this.feed = this.model.get_feed(this.feed_id);
        this.feed_tags = trainer_data['feed_tags'];
        this.feed_authors = trainer_data['feed_authors'];
        this.user_classifiers = trainer_data['classifiers'];
        this.options.feed_loaded = true;
        if (this.feed_id in this.cache) {
            this.$modal = this.cache[this.feed_id];
        } else {
            this.make_modal_feed();
            this.make_modal_title();
            this.make_modal_trainer_count();
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
            }
        }, this), 125);
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
                .removeClass('NB-modal-submit-close')
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
        
        if (this.options.feed_loaded) {
          this.feed_tags = this.model.get_feed_tags();
          this.feed_authors = this.model.get_feed_authors();
          $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', NEWSBLUR.Globals.google_favicon_url + this.feed['feed_link']);
          $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed['feed_title']);
        }
    },
    
    load_single_feed_trainer: function() {
        var self = this;
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
    
        this.model.get_feeds_trainer(this.feed_id, function(data) {
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
            $.make('h2', { className: 'NB-modal-title' }, 'Intelligence Trainer'),
            $.make('h3', { className: 'NB-modal-subtitle' }, 'Here\'s what to do:'),
            $.make('ol', { className: 'NB-trainer-points' }, [
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_classifier_tag.png', style: 'float: right', width: 135, height: 20 }),
                    $.make('b', 'You will see a bunch of tags and authors.'),
                    ' Check the features you want to see in stories. If you check too many options, you won\'t find the good among the neutral.'
                ]),
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/intelligence_slider_positive.png', style: 'float: right', width: 114, height: 29 }),
                    $.make('b', 'What you select now will show when you use the intelligence slider.'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_red.png'}),
                    ' are stories you don\'t like',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_yellow.png'}),
                    ' are stories you have not yet rated',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_green.png'}),
                    ' are stories you like'
                ]),
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_menu.png', style: 'float: right', width: 176, height: 118 }),
                    $.make('b', 'Stop at any time you like.'),
                    ' You can always come back to this.'
                ]),
                $.make('li', [
                    $.make('b', 'Don\'t worry if you don\'t know what you like right now.'),
                    ' Just skip the site. You can click the ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs_up.png', style: 'vertical-align: middle;padding: 0 8px 0 2px', width: 14, height: 20 }),
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs_down.png', style: 'vertical-align: top; padding: 0', width: 14, height: 20 }),
                    ' buttons as you read stories.'
                ])
            ]),
            (!NEWSBLUR.Globals.is_authenticated && $.make('div', { className: 'NB-trainer-not-authenticated' }, 'Please create an account and add sites you read. Then you can train them.')),
            $.make('div', { className: 'NB-modal-submit' }, [
                (!NEWSBLUR.Globals.is_authenticated && $.make('a', { href: '#', className: 'NB-modal-submit-close NB-modal-submit-button' }, 'Close')),
                (NEWSBLUR.Globals.is_authenticated && $.make('a', { href: '#', className: 'NB-modal-submit-begin NB-modal-submit-button NB-modal-submit-close NB-disabled' }, 'Loading Training...'))
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
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_classifier_tag.png', style: 'float: right', width: 135, height: 20 }),
                    $.make('b', 'You can change your opinions.'),
                    ' You can click the ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs_up.png', style: 'vertical-align: middle;padding: 0 8px 0 2px', width: 14, height: 20 }),
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs_down.png', style: 'vertical-align: top; padding: 0', width: 14, height: 20 }),
                    ' buttons next to stories as you read them.'
                ]),
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/intelligence_slider_positive.png', style: 'float: right', width: 114, height: 29 }),
                    $.make('b', 'As a reminder, use the intelligence slider to select a filter:'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_red.png'}),
                    ' are stories you don\'t like',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_yellow.png'}),
                    ' are stories you have not yet rated',
                    $.make('br'),
                    $.make('img', { className: 'NB-trainer-bullet', src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/bullet_green.png'}),
                    ' are stories you like'

                ]),
                $.make('li', [
                    $.make('b', 'You can also filter out stories you don\'t want to read.'),
                    ' As great as finding good stuff is, you can just as easily ignore the stories you do not like.'
                ])
            ]),
            $.make('div', { className: 'NB-modal-submit' }, [
                $.make('a', { href: '#', className: 'NB-modal-submit-button NB-modal-submit-reset' }, $.entity('&laquo;') + ' Retrain all sites'),
                $.make('a', { href: '#', className: 'NB-modal-submit-end NB-modal-submit-button' }, 'Close Training and Start Reading')
            ])
        ]);
        
    },
    
    make_modal_feed: function() {
        var self = this;
        var feed = this.feed;

        // NEWSBLUR.log(['Make feed', feed, this.feed_authors, this.feed_tags]);
        
        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal ' + (this.options['training'] && 'NB-modal-trainer') }, [
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, ''),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                (this.options['training'] && $.make('div', { className: 'NB-classifier-trainer-counts' })),
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: NEWSBLUR.Globals.google_favicon_url + this.feed.feed_link }),
                $.make('span', { className: 'NB-modal-feed-title' }, this.feed.feed_title)
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
                  $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                      $.make('h5', 'Everything by This Publisher'),
                      $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                          this.make_publisher(feed)
                      )
                  ]),
                  (this.options['training'] && $.make('div', { className: 'NB-modal-submit' }, [
                      $.make('input', { name: 'score', value: this.score, type: 'hidden' }),
                      $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                      $.make('a', { href: '#', className: 'NB-modal-submit-button NB-modal-submit-back' }, $.entity('&laquo;') + ' Back'),
                      $.make('a', { href: '#', className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-next NB-modal-submit-save' }, 'Save & Next '+$.entity('&raquo;')),
                      $.make('a', { href: '#', className: 'NB-modal-submit-button NB-modal-submit-close' }, 'Close')
                  ])),
                  (!this.options['training'] && $.make('div', { className: 'NB-modal-submit' }, [
                      $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                      $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                      $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-save NB-modal-submit-green NB-disabled', value: 'Check what you like above...' }),
                      ' or ',
                      $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                  ]))
              ])
            )
        ]);
    },
        
    make_modal_story: function() {
        var self = this;
        var story = this.story;
        var feed = this.feed;
        var opinion = (this.score == 1 ? 'like_' : 'dislike_');
        
        // NEWSBLUR.log(['Make Story', story, feed]);
        
        // HTML entities decoding.
        story.story_title = $('<div/>').html(story.story_title).text();
        
        this.$modal = $.make('div', { className: 'NB-modal-classifiers NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('form', { method: 'post' }, [
                (story.story_title && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                    $.make('h5', 'Story Title'),
                    $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                        $.make('input', { type: 'text', value: story.story_title, className: 'NB-classifier-title-highlight' }),
                        this.make_classifier('<span class="NB-classifier-title-placeholder">Highlight phrases to look for in future stories</span>', '', 'title'),
                        $.make('span',
                            this.make_user_titles(story.story_title)
                        )
                    ])
                ])),
                (story.story_authors && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                    $.make('h5', 'Story Author'),
                    $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                        this.make_authors([story.story_authors], opinion)
                    )
                ])),
                (story.story_tags.length && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                    $.make('h5', 'Story Categories &amp; Tags'),
                    $.make('div', { className: 'NB-classifier-tags NB-fieldset-fields NB-classifiers' },
                        this.make_tags(story.story_tags, opinion)
                    )
                ])),
                $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                    $.make('h5', 'Everything by This Publisher'),
                    $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                        this.make_publisher(feed, opinion)
                    )
                ]),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-save NB-modal-submit-green NB-disabled', value: 'Check what you like above...' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save_story();
                return false;
            })
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
            if (!existing_title || existing_title.indexOf(title) != -1) {
                var $title = this.make_classifier(title, title, 'title');
                $titles.push($title);
            }
        }, this));
        
        return $titles;
    },
    
    make_authors: function(authors, opinion) {
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
    
    make_publisher: function(publisher, opinion) {
        var $publisher = this.make_classifier(publisher.feed_title, this.feed_id, 'feed');
        return $publisher;
    },
    
    make_classifier: function(classifier_title, classifier_value, classifier_type, classifier_count) {
        var score = 0;
        // NEWSBLUR.log(['classifiers', this.user_classifiers, classifier_value, this.user_classifiers[classifier_type+'s']]);
        if (classifier_value in this.user_classifiers[classifier_type+'s']) {
            score = this.user_classifiers[classifier_type+'s'][classifier_value];
        }
        
        var classifier_type_title = Inflector.capitalize(classifier_type=='feed' ?
                                    'publisher' :
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
                            src: NEWSBLUR.Globals.google_favicon_url + this.feed.feed_link 
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
            $('.NB-classifier-input-like', $classifier).attr('checked', true);
        } else if (score < 0) {
            $('.NB-classifier', $classifier).addClass('NB-classifier-dislike');
            $('.NB-classifier-input-dislike', $classifier).attr('checked', true);
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
        var $close = $('.NB-modal-submit-close', this.$modal);
        var $back = $('.NB-modal-submit-back', this.$modal);
        
        if (classifier_opinion == 'like') {
            if ($classifier.is('.NB-classifier-like')) {
                $classifier.removeClass('NB-classifier-like');
                $dislike.attr('checked', false);
                $like.attr('checked', false);
            } else {
                $classifier.removeClass('NB-classifier-dislike');
                $classifier.addClass('NB-classifier-like');
                $dislike.attr('checked', false);
                $like.attr('checked', true);
            }
        } else if (classifier_opinion == 'dislike') {
            if ($classifier.is('.NB-classifier-dislike')) {
                $classifier.removeClass('NB-classifier-dislike');
                $like.attr('checked', false);
                $dislike.attr('checked', false);
            } else {
                $classifier.removeClass('NB-classifier-like');
                $classifier.addClass('NB-classifier-dislike');
                $like.attr('checked', false);
                $dislike.attr('checked', true);
            }
        }
        
        if (this.options['training']) {
            $close.val('Save & Close');
        } else {
            $save.removeClass("NB-disabled").removeAttr('disabled').attr('value', 'Save');
        }
        // NEWSBLUR.log(['change_classifier', classifier_opinion, $classifier, $like.is(':checked'), $dislike.is(':checked')]);
    },
    
    open_modal: function() {
        var self = this;
        
        this.$modal.modal({
            'minWidth': 600,
            'maxWidth': 600,
            'overlayClose': true,
            'autoResize': true,
            'position': [this.options['training'] ? 40 : 0, 0],
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                    setTimeout(function() {
                        self.flags.modal_loaded = true;
                        $(window).resize();
                    });
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
                $('.NB-classifier', self.$modal).corner('14px');
            },
            'onClose': function(dialog) {
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(200, function() {
                    dialog.overlay.empty().remove();
                    $.modal.close();
                });
                $('.NB-modal-holder').empty().remove();
            }
        });
    },
    
    update_homepage_counts: function() {
      var $count = $('.NB-module-account-trainer-count');
      
      $count.text(_.size(this.model.get_feeds()) - (this.trainer_data.length - this.trainer_iterator) - 1);
    },
    
    end: function() {
      _.defer(function() {
        $('.NB-module-account-trainer').animate({
          'opacity': 0
        }, {
          'duration': 1000,
          'complete': function() {
            $('.NB-module-account-trainer').slideUp(350);
          }
        });
      }, 1000);
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
            $title_placeholder.text($title_highlight.val());
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
                self.save_publisher(true);
                self.load_next_feed_in_trainer();
                self.update_homepage_counts();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-back' }, function($t, $p){
                e.preventDefault();
                self.load_previous_feed_in_trainer();
            });
            
            $.targetIs(e, { tagSelector: '.NB-modal-submit-reset' }, function($t, $p){
                e.preventDefault();
                self.retrain_all_sites();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-close' }, function($t, $p){
                e.preventDefault();
                self.save_publisher();
            });

            $.targetIs(e, { tagSelector: '.NB-modal-submit-end' }, function($t, $p){
                e.preventDefault();
                NEWSBLUR.reader.force_feeds_refresh();
                self.end();
                // NEWSBLUR.reader.open_feed(self.feed_id, true);
                // TODO: Update counts in active feed.
            });
        } else {
            $.targetIs(e, { tagSelector: '.NB-modal-submit-save:not(.NB-modal-submit-next)' }, function($t, $p){
                e.preventDefault();
                self.save_publisher();
                return false;
            });
        }
        
        var stop = false;
        $.targetIs(e, { tagSelector: '.NB-classifier-icon-dislike' }, function($t, $p){
            e.preventDefault();
            stop = true;
            self.change_classifier($t.parents('.NB-classifier').eq(0), 'dislike');
        });
        if (stop) return;
        $.targetIs(e, { tagSelector: '.NB-classifier' }, function($t, $p){
            e.preventDefault();
            self.change_classifier($t, 'like');
        });
    },
    
    serialize_classifier: function() {
        var data = [];
        $('.NB-classifier', this.$modal).each(function() {
            if ($('.NB-classifier-input-like, .NB-classifier-input-dislike', this).is(':checked')) {
                data.push([$('input:checked', this).attr('name'), $('.NB-classifier-input-like', this).val()]);
            } else {
                data.push(['remove_'+$('.NB-classifier-input-like', this).attr('name'), $('.NB-classifier-input-like', this).val()]);
            }
        });
        data.push(['feed_id', this.feed_id]);
        if (this.story_id) {
            data.push(['story_id', this.story_id]);
        }
        data = _.map(data, function(c) { 
            return [c[0], '=', c[1]].join(''); 
        }).join('&');
        return data;
    },
        
    save_publisher: function(keep_modal_open) {
        var self = this;
        var $save = $('.NB-modal-submit-save', this.$modal);
        var data = this.serialize_classifier();
        
        NEWSBLUR.reader.update_opinions(this.$modal, this.feed_id);
        
        if (this.options['training']) {
            this.cache[this.feed_id] = this.$modal.clone();
            $save.text('Saving...');
        } else {
            $save.val('Saving...');
        }
        $save.addClass('NB-disabled').attr('disabled', true);
        
        this.model.save_classifier_publisher(data, function() {
            if (!keep_modal_open) {
                NEWSBLUR.reader.force_feeds_refresh();
                // NEWSBLUR.reader.open_feed(self.feed_id, true);
                // TODO: Update counts in active feed.
                $.modal.close();
            }
        });
    },
    
    save_story: function() {
        var self = this;
        var $save = $('.NB-modal-submit-save', this.$modal);
        var story_id = this.story_id;
        var data = this.serialize_classifier();
        
        NEWSBLUR.reader.update_opinions(this.$modal, this.feed_id);
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_story(story_id, data, function() {
            NEWSBLUR.reader.force_feeds_refresh();
            NEWSBLUR.reader.open_feed(self.feed_id, true);
            $.modal.close();
        });
    }
    
};

NEWSBLUR.ReaderClassifierStory.prototype = classifier_prototype;
NEWSBLUR.ReaderClassifierFeed.prototype = classifier_prototype;
NEWSBLUR.ReaderClassifierTrainer.prototype = classifier_prototype;
