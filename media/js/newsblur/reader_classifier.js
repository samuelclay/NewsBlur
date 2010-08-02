NEWSBLUR.ReaderClassifierTrainer = function(options) {
    var defaults = {
        'score': 1,
        'training': true
    };
    
    this.flags = {
        'publisher': true,
        'story': false
    };
    this.cache = {};
    this.trainer_iterator = 0;
    this.feed_id = null;
    this.options = $.extend({}, defaults, options);
    this.score = this.options['score'];
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner_trainer();
};

NEWSBLUR.ReaderClassifierFeed = function(feed_id, options) {
    var defaults = {
        'score': 1,
        'training': false
    };
    
    this.flags = {
        'publisher': true,
        'story': false
    };
    this.feed_id = feed_id;
    this.options = $.extend({}, defaults, options);
    this.score = this.options['score'];
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner_feed();
};


NEWSBLUR.ReaderClassifierStory = function(story_id, feed_id, options) {
    var defaults = {
        'score': 1
    };
    
    this.flags = {
        'publisher': false,
        'story': true
    };
    this.story_id = story_id;
    this.feed_id = feed_id;
    this.options = $.extend({}, defaults, options);
    this.score = this.options['score'];
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner_story();
};

var classifier = {
    
    runner_trainer: function() {
        this.user_classifiers = {};

        this.make_trainer_intro();
        this.get_feeds_trainer();
        this.handle_select_checkboxes();
        this.handle_cancel();
        this.handle_select_title();
        this.open_modal();
            
        this.$modal.parent().bind('click.reader_classifer', $.rescope(this.handle_clicks, this));
    },
    
    runner_feed: function() {
        this.user_classifiers = this.model.classifiers;
        
        this.find_story_and_feed();
        this.make_modal_feed();
        this.make_modal_title();
        this.make_modal_intelligence_slider();
        this.handle_select_checkboxes();
        this.handle_cancel();
        this.handle_select_title();
        this.open_modal();
    },
    
    runner_story: function() {
        this.user_classifiers = this.model.classifiers;
        
        this.find_story_and_feed();
        this.make_modal_story();
        this.make_modal_title();
        this.handle_text_highlight();
        this.handle_select_checkboxes();
        this.handle_cancel();
        this.handle_select_title();
        this.open_modal();
    },
    
    load_next_feed_in_trainer: function(backwards) {
        var trainer_data_length = this.trainer_data.length;
        if (backwards) {
            this.trainer_iterator = this.trainer_iterator - 1;
            if (this.trainer_iterator < 1) {
                this.make_trainer_intro();
                this.load_feeds_trainer(null, this.trainer_data);
            }
        } else {
            this.trainer_iterator = this.trainer_iterator + 1;
            if (this.trainer_iterator > trainer_data_length) {
                this.make_trainer_outro();
                this.load_feeds_trainer(null, this.trainer_data);
            }
        }

        // Show only feeds, not the trainer intro if going backwards.
        if (this.trainer_iterator > 0 && this.trainer_iterator <= trainer_data_length) {
            var trainer_data = this.trainer_data[this.trainer_iterator-1];
            this.feed_id = trainer_data['feed_id'];
            this.feed = this.model.get_feed(this.feed_id);
            this.feed_tags = trainer_data['feed_tags'];
            this.feed_authors = trainer_data['feed_authors'];
            this.user_classifiers = trainer_data['classifiers'];
        
            this.make_modal_feed();
            this.make_modal_title();
            this.make_modal_trainer_count();
        
            if (backwards || this.feed_id in this.cache) {
                this.$modal = this.cache[this.feed_id];
            }
        }
        
        $('.NB-modal').replaceWith(this.$modal);
        $.modal.impl.resize(this.$modal);
    },
    
    get_feeds_trainer: function() {
        this.model.get_feeds_trainer($.rescope(this.load_feeds_trainer, this));
    },
    
    load_feeds_trainer: function(e, data) {
        var $begin = $('.NB-modal-submit-begin', this.$modal);
        
        NEWSBLUR.log(['data', data]);
        this.trainer_data = data;
        
        $begin.text('Begin Training')
              .addClass('NB-modal-submit-save')
              .removeClass('NB-disabled');
    },
    
    find_story_and_feed: function() {
        if (this.story_id) {
            this.story = this.model.get_story(this.story_id);
        }
        this.feed = this.model.get_feed(this.feed_id);
        this.feed_tags = this.model.get_feed_tags();
        this.feed_authors = this.model.get_feed_authors();
        
        $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', this.google_favicon_url + this.feed['feed_link']);
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed['feed_title']);
    },
    
    make_trainer_intro: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-classifier NB-modal NB-modal-trainer'}, [
            $.make('h2', { className: 'NB-modal-title' }, 'Intelligence Trainer'),
            $.make('h3', { className: 'NB-modal-subtitle' }, 'Here\'s what to do:'),
            $.make('ol', { className: 'NB-trainer-points' }, [
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_classifier_tag.png', style: 'float: right', width: 135, height: 20 }),
                    $.make('b', 'You will see a bunch of tags and authors.'),
                    ' Check the features you want to see in stories. If you check too many options, you won\'t filter the good stories from the neutral stories.'
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
                    ' You can always come back to this trainer.'
                ]),
                $.make('li', [
                    $.make('b', 'Don\'t worry if you don\'t know what you like right now.'),
                    ' Just skip the site. You can click the ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs-up.png', style: 'vertical-align: middle;padding: 0 8px 0 2px', width: 14, height: 20 }),
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs-down.png', style: 'vertical-align: top; padding: 0', width: 14, height: 20 }),
                    ' buttons next to stories as you read them.'
                ])
            ]),
            (!NEWSBLUR.Globals.is_authenticated && $.make('div', { className: 'NB-trainer-not-authenticated' }, 'Please create an account and add sites you read. Then you can train them.')),
            $.make('div', { className: 'NB-modal-submit' }, [
                (!NEWSBLUR.Globals.is_authenticated && $.make('a', { href: '#', className: 'NB-modal-submit-close NB-modal-submit-button' }, 'Close')),
                (NEWSBLUR.Globals.is_authenticated && $.make('a', { href: '#', className: 'NB-modal-submit-save NB-modal-submit-begin NB-modal-submit-button NB-disabled' }, 'Loading Training...'))
            ])
        ]);
        
    },
    
    make_trainer_outro: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-classifier NB-modal NB-modal-trainer'}, [
            $.make('h2', { className: 'NB-modal-title' }, 'Congratulations! You\'re done.'),
            $.make('h3', { className: 'NB-modal-subtitle' }, 'Here\'s what happens next:'),
            $.make('ol', { className: 'NB-trainer-points' }, [
                $.make('li', [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/sample_classifier_tag.png', style: 'float: right', width: 135, height: 20 }),
                    $.make('b', 'You can change your opinions.'),
                    ' You can click the ',
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs-up.png', style: 'vertical-align: middle;padding: 0 8px 0 2px', width: 14, height: 20 }),
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/thumbs-down.png', style: 'vertical-align: top; padding: 0', width: 14, height: 20 }),
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
                $.make('a', { href: '#', className: 'NB-modal-submit-end NB-modal-submit-button' }, 'Close Training and Start Reading')
            ])
        ]);
        
    },
    
    make_modal_feed: function() {
        var self = this;
        var feed = this.feed;
        var opinion = (this.score == 1 ? 'like_' : 'dislike_');
                
        // NEWSBLUR.log(['Make feed', feed, this.feed_authors, this.feed_tags]);
        
        this.$modal = $.make('div', { className: 'NB-classifier NB-modal ' + (this.options['training'] && 'NB-modal-trainer') }, [
            $.make('div', { className: 'NB-modal-loading' }),
            (!this.options['training'] && this.make_modal_intelligence_slider()),
            (this.options['training'] && $.make('div', { className: 'NB-classifier-trainer-counts' })),
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: this.google_favicon_url + this.feed.feed_link }),
                $.make('span', { className: 'NB-modal-feed-title' }, this.feed.feed_title)
            ]),
            $.make('form', { method: 'post', className: 'NB-publisher' }, [
                (this.feed_authors.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                    $.make('h5', 'Authors'),
                    $.make('div', { className: 'NB-classifier-authors NB-fieldset-fields NB-classifiers' },
                        this.make_authors(this.feed_authors, opinion)
                    )
                ])),
                (this.feed_tags.length && $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                    $.make('h5', 'Categories &amp; Tags'),
                    $.make('div', { className: 'NB-classifier-tags NB-fieldset-fields NB-classifiers' },
                        this.make_tags(this.feed_tags, opinion)
                    )
                ])),
                $.make('div', { className: 'NB-modal-field NB-fieldset NB-classifiers' }, [
                    $.make('h5', 'Everything by This Publisher'),
                    $.make('div', { className: 'NB-fieldset-fields NB-classifiers' },
                        this.make_publisher(feed, opinion)
                    )
                ]),
                (this.options['training'] && $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'score', value: this.score, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('a', { href: '#', className: 'NB-modal-submit-button NB-modal-submit-back' }, $.entity('&laquo;') + ' Back'),
                    $.make('a', { href: '#', className: 'NB-modal-submit-button NB-modal-submit-save' }, 'Save & Next '+$.entity('&raquo;')),
                    $.make('a', { href: '#', className: 'NB-modal-submit-button NB-modal-submit-close' }, 'Close')
                ])),
                (!this.options['training'] && $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'score', value: this.score, type: 'hidden' }),
                    $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-save NB-disabled', value: 'Check what you like above...' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ]))
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save_publisher();
                return false;
            })
        ]);
    },
        
    make_modal_story: function() {
        var self = this;
        var story = this.story;
        var feed = this.feed;
        var opinion = (this.score == 1 ? 'like_' : 'dislike_');
        
        NEWSBLUR.log(['Make Story', story, feed]);
        
        // HTML entities decoding.
        story.story_title = $('<div/>').html(story.story_title).text();
        
        this.$modal = $.make('div', { className: 'NB-classifier NB-modal' }, [
            this.make_modal_intelligence_slider(),
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('form', { method: 'post' }, [
                (story.story_title && $.make('div', { className: 'NB-modal-field NB-fieldset' }, [
                    $.make('h5', 'Story Title'),
                    $.make('div', { className: 'NB-fieldset-fields NB-classifiers' }, [
                        $.make('input', { type: 'text', value: story.story_title, className: 'NB-classifier-title-highlight' }),
                        $.make('div', { className: 'NB-classifier NB-classifier-title NB-classifier-facet-disabled' }, [
                            $.make('input', { type: 'checkbox', name: opinion+'title', value: '', id: 'classifier_title' }),
                            $.make('label', { 'for': 'classifier_title' }, [
                                $.make('b', 'Look for: '),
                                $.make('span', { className: 'NB-classifier-title-text' }, 'Highlight phrases to look for in future stories')
                            ])
                        ])
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
                    $.make('input', { name: 'score', value: this.score, type: 'hidden' }),
                    $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-save NB-disabled', value: 'Check what you like above...' }),
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
        
        if (this.flags['publisher']) {
            if (this.score == 1) {
                $modal_title.html('What do you <b class="NB-classifier-like">like</b> about this site?');
            } else if (this.score == -1) {
                $modal_title.html('What do you <b class="NB-classifier-dislike">dislike</b> about this site?');
            }
        } else if (this.flags['story']) {
            if (this.score == 1) {
                $modal_title.html('What do you <b class="NB-classifier-like">like</b> about this story?');
            } else if (this.score == -1) {
                $modal_title.html('What do you <b class="NB-classifier-dislike">dislike</b> about this story?');
            }
        }
    },
    
    make_modal_trainer_count: function() {
        var $count = $('.NB-classifier-trainer-counts', this.$modal);
        var count = this.trainer_iterator;
        var total = this.trainer_data.length;
        $count.html(count + '/' + total);
    },
    
    make_modal_intelligence_slider: function() {
        var self = this;
        var $slider = $.make('div', { className: 'NB-taskbar-intelligence NB-modal-slider' }, [
            $.make('div', { className: 'NB-taskbar-intelligence-indicator NB-taskbar-intelligence-negative' }),
            $.make('div', { className: 'NB-taskbar-intelligence-indicator NB-taskbar-intelligence-neutral' }),
            $.make('div', { className: 'NB-taskbar-intelligence-indicator NB-taskbar-intelligence-positive' }),
            $.make('div', { className: 'NB-intelligence-slider' })
        ]);
        
        $('.NB-intelligence-slider', $slider).slider({
            range: 'max',
            min: 0,
            max: 2,
            step: 2,
            value: this.score + 1,
            slide: function(e, ui) {
                // self.switch_feed_view_unread_view(ui.value);
                self.score = ui.value - 1;
                self.make_modal_title();
                $('input[name^=like],input[name^=dislike]', self.$modal).attr('name', function(i, current_name) {
                    if (self.score == -1) {
                        return 'dis' + current_name.substr(current_name.indexOf('like_'));
                    } else if (self.score == 1) {
                        return current_name.substr(current_name.indexOf('like_'));
                    }
                });
                var $submit = $('input[type=submit]', self.$modal);
                $submit.removeClass("NB-disabled").removeAttr('disabled').attr('value', 'Save');
            }
        });
        
        return $slider;
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
            
            var input_attrs = { 
                type: 'checkbox', 
                name: opinion+'author', 
                value: author, 
                id: 'classifier_author_'+a
            };
        
            if (author in this.user_classifiers.authors 
                && this.user_classifiers.authors[author] == this.score) {
                input_attrs['checked'] = 'checked';
            }
        
            var $author = $.make('span', { className: 'NB-classifier-container NB-classifier-author-container' }, [
                $.make('span', { className: 'NB-classifier NB-classifier-author' }, [
                    $.make('input', input_attrs),
                    $.make('label', { 'for': 'classifier_author_'+a }, [
                        $.make('b', 'Author: '),
                        $.make('span', author)
                    ])
                ]),
                (author_count && $.make('span', { className: 'NB-classifier-tag-count' }, [
                    '&times;&nbsp;',
                    author_count
                ]))
            ]);
            $authors.push($author);
        }
        return $authors;
    },
    
    make_tags: function(tags, opinion) {
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
            
            var input_attrs = { 
                type: 'checkbox', 
                name: opinion+'tag', 
                value: tag, 
                id: 'classifier_tag_'+t 
            };
            
            if (tag in this.user_classifiers.tags && this.user_classifiers.tags[tag] == this.score) {
                input_attrs['checked'] = 'checked';
            }
            
            var $tag = $.make('span', { className: 'NB-classifier-container NB-classifier-tag-container' }, [
                $.make('span', { className: 'NB-classifier NB-classifier-tag' }, [
                    $.make('input', input_attrs),
                    $.make('label', { 'for': 'classifier_tag_'+t }, [
                        $.make('b', 'Tag: '),
                        $.make('span', tag)
                    ])
                ]),
                (tag_count && $.make('span', { className: 'NB-classifier-tag-count' }, [
                    '&times;&nbsp;',
                    tag_count
                ]))
            ]);
            $tags.push($tag);
        }
        
        return $tags;
    },
        
    make_publisher: function(publisher, opinion) {
        var input_attrs = { 
            type: 'checkbox', 
            name: opinion+'publisher', 
            value: this.feed_id,
            id: 'classifier_publisher',
            checked: false
        };
        if (this.feed.feed_link in this.user_classifiers.feeds 
            && this.user_classifiers.feeds[this.feed.feed_link].score == this.score) {
            input_attrs['checked'] = true;
        }
        
        var $publisher = $.make('div', { className: 'NB-classifier NB-classifier-publisher' }, [
            $.make('input', input_attrs),
            $.make('label', { 'for': 'classifier_publisher' }, [
                $.make('img', { className: 'feed_favicon', src: this.google_favicon_url + publisher.feed_link }),
                $.make('span', { className: 'feed_title' }, [
                    $.make('b', 'Publisher: '),
                    $.make('span', publisher.feed_title)
                ])
            ])
        ]);
        return $publisher;
    },
    
    make_title: function(title, t, opinion) {
        var $title = $.make('div', { className: 'NB-classifier NB-classifier-title' }, [
            $.make('input', { type: 'checkbox', name: opinion+'title', value: title, id: 'classifier_title_'+t, checked: 'checked' }),
            $.make('label', { 'for': 'classifier_title_'+t }, [
                $.make('b', 'Title: '),
                $.make('span', title)
            ])
        ]);
        return $title;
    },
    
    open_modal: function() {
        var self = this;

        var $holder = $.make('div', { className: 'NB-modal-holder' })
            .append(this.$modal)
            .appendTo('body')
            .css({'visibility': 'hidden', 'display': 'block', 'width': 600});
        var height = $('.NB-classifier', $holder).outerHeight(true);
        $holder.css({'visibility': 'visible', 'display': 'none'});
        var w = $.modal.impl.getDimensions();
        if (height > w[0] - 70) {
            height = w[0] - 70;
        }
        
        this.$modal.modal({
            'minWidth': 600,
            'overlayClose': true,
            'autoResize': true,
            'position': [this.options['training'] ? 40 : 0, 0],
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px').css({'width': 600, 'height': height});
                $('.NB-classifier', self.$modal).corner('14px');
                $.modal.impl.setPosition();
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
    
    handle_text_highlight: function() {
        var $title_highlight = $('.NB-classifier-title-highlight', this.$modal);
        var $title = $('.NB-classifier-title-text', this.$modal);
        var $title_checkbox = $('#classifier_title', this.$modal);
        
        var update = function() {
            var text = $.trim($(this).getSelection().text);
            
            if ($title.text() != text && text.length) {
                $title_checkbox.attr('checked', 'checked').change();
                $title.text(text);
                $title_checkbox.parents('.NB-classifier-facet-disabled')
                    .removeClass('NB-classifier-facet-disabled');
                $title_checkbox.val(text);
            }
        };
        
        $title_highlight
            .keydown(update).keyup(update)
            .mousedown(update).mouseup(update).mousemove(update);
    },
    
    handle_select_title: function() {
        var $title_checkbox = $('#classifier_title', this.$modal);
        var $title = $('.NB-classifier-title-text', this.$modal);
        var $title_highlight = $('.NB-classifier-title-highlight', this.$modal);
        
        $title_checkbox.change(function() {;
            if ($title.parents('.NB-classifier-facet-disabled').length) {
                var text = $title_highlight.val();
                $title.text(text);
                $title_checkbox.parents('.NB-classifier-facet-disabled')
                    .removeClass('NB-classifier-facet-disabled');
                $title_checkbox.val(text);
            }
        });
    },
    
    handle_select_checkboxes: function() {
        var self = this;
        var $save = $('.NB-modal-submit-save', this.$modal);
        var $close = $('.NB-modal-submit-close', this.$modal);
        var $back = $('.NB-modal-submit-back', this.$modal);
        
        $('input', this.$modal).change(function() {
            // var count = $('input:checked', self.$modal).length;
            if (self.options['training']) {
                $close.val('Save & Close');
            } else {
                $save.removeClass("NB-disabled").removeAttr('disabled').attr('value', 'Save');
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
                
        $.targetIs(e, { tagSelector: '.NB-modal-submit-begin' }, function($t, $p){
            e.preventDefault();
            self.load_next_feed_in_trainer();
        });

        $.targetIs(e, { tagSelector: '.NB-modal-submit-save:not(.NB-modal-submit-begin)' }, function($t, $p){
            e.preventDefault();
            self.save_publisher(true);
            self.load_next_feed_in_trainer();
        });

        $.targetIs(e, { tagSelector: '.NB-modal-submit-back' }, function($t, $p){
            e.preventDefault();
            self.load_next_feed_in_trainer(true);
        });

        $.targetIs(e, { tagSelector: '.NB-modal-submit-close' }, function($t, $p){
            e.preventDefault();
            self.save_publisher();
        });

        $.targetIs(e, { tagSelector: '.NB-modal-submit-end' }, function($t, $p){
            e.preventDefault();
            self.save_publisher();
        });
    },
    
    serialize_classifier: function() {
        var checked_data = $('input', this.$modal).serialize();
        
        var $unchecked = $('input[type=checkbox]:not(:checked)', this.$modal);
        $unchecked.attr('checked', true);
        $unchecked.each(function() {
           $(this).attr('name', 'remove_' + $(this).attr('name'));
        });
        
        var unchecked_data = $unchecked.serialize();
        $unchecked.each(function() {
           $(this).attr('name', $(this).attr('name').replace(/^remove_/, ''));
        });
        $unchecked.attr('checked', false);
        
        var data = [checked_data, unchecked_data].join('&');
        return data;
    },
        
    save_publisher: function(keep_modal_open) {
        var $save = $('.NB-modal-submit-save', this.$modal);
        var story_id = this.story_id;
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
                NEWSBLUR.reader.force_feed_refresh();
                $.modal.close();
            }
        });
    },
    
    save_story: function() {
        var $save = $('.NB-modal-submit-save', this.$modal);
        var story_id = this.story_id;
        var data = this.serialize_classifier();
        
        NEWSBLUR.reader.update_opinions(this.$modal, this.feed_id);
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_story(story_id, data, function() {
            NEWSBLUR.reader.force_feed_refresh();
            $.modal.close();
        });
    }
    
};

NEWSBLUR.ReaderClassifierStory.prototype = classifier;
NEWSBLUR.ReaderClassifierFeed.prototype = classifier;
NEWSBLUR.ReaderClassifierTrainer.prototype = classifier;
