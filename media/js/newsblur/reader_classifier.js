NEWSBLUR.ReaderClassifierFeed = function(feed_id, score, options) {
    var defaults = {};
    
    this.feed_id = feed_id;
    this.score = score;
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner_feed();
};


NEWSBLUR.ReaderClassifierStory = function(story_id, feed_id, score, options) {
    var defaults = {};
    
    this.story_id = story_id;
    this.feed_id = feed_id;
    this.score = score;
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner_story();
};

var classifier = {
    
    runner_feed: function() {
        this.find_story_and_feed();
        this.make_modal_feed();
        this.handle_text_highlight();
        this.handle_select_checkboxes();
        this.handle_cancel();
        this.handle_select_title();
        this.open_modal();
    },
    
    runner_story: function() {
        this.find_story_and_feed();
        this.make_modal_story();
        this.handle_text_highlight();
        this.handle_select_checkboxes();
        this.handle_cancel();
        this.handle_select_title();
        this.open_modal();
    },
    
    find_story_and_feed: function() {
        if (this.story_id) {
            this.story = this.model.get_story(this.story_id);
        }
        this.feed = this.model.get_feed(this.feed_id);
        this.feed_tags = this.model.get_feed_tags();
        this.feed_authors = this.model.get_feed_authors();
    },
    
    make_modal_feed: function() {
        var self = this;
        var feed = this.feed;
        var $feed_authors = [];
        var $feed_tags = [];

        if (this.feed_authors) {
            for (var fa in this.feed_authors) {
                var feed_author = this.feed_authors[fa];
                if (feed_author[0]) {
                    var $author = $.make('span', { className: 'NB-classifier-author NB-classifier' }, [
                        $.make('input', { type: 'checkbox', name: 'author', value: feed_author[0], id: 'classifier_author_'+fa }),
                        $.make('label', { 'for': 'classifier_author_'+fa }, feed_author[0])
                    ]);
                    $feed_authors.push($author);
                }
            }
        }
        
        if (this.feed_tags) {
            for (var t in this.feed_tags) {
                var tag = this.feed_tags[t];
                var checked = (tag[0] in this.model.classifiers.tags) ? 'checked' : 'false';
                var $tag = $.make('span', { className: 'NB-classifier-tag-container' }, [
                    $.make('span', { className: 'NB-classifier-tag NB-classifier' }, [
                        $.make('input', { type: 'checkbox', name: 'tag', value: tag[0], id: 'classifier_tag_'+t, checked: checked }),
                        $.make('label', { 'for': 'classifier_tag_'+t }, [
                            $.make('b', tag[0])
                        ])
                    ]),
                    $.make('span', { className: 'NB-classifier-tag-count' }, [
                        '&times;&nbsp;',
                        tag[1]
                    ])
                ]);
                $feed_tags.push($tag);
            }
        }
        
        this.$classifier = $.make('div', { className: 'NB-classifier NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('form', { method: 'post', className: 'NB-publisher' }, [
                ($feed_authors.length && $.make('div', { className: 'NB-modal-field NB-classifiers' }, [
                    $.make('h5', 'Authors'),
                    $.make('div', { className: 'NB-classifier-authors NB-classifiers' }, $feed_authors)
                ])),
                ($feed_tags.length && $.make('div', { className: 'NB-modal-field' }, [
                    $.make('h5', 'Categories &amp; Tags'),
                    $.make('div', { className: 'NB-classifier-tags NB-classifiers' }, $feed_tags)
                ])),
                $.make('div', { className: 'NB-modal-field NB-classifiers' }, [
                    $.make('h5', 'Everything by This Publisher'),
                    $.make('div', { className: 'NB-classifiers' }, [
                        $.make('div', { className: 'NB-classifier NB-classifier-publisher' }, [
                            $.make('input', { type: 'checkbox', name: 'facet', value: 'publisher', id: 'classifier_publisher' }),
                            $.make('label', { 'for': 'classifier_publisher' }, [
                                $.make('img', { className: 'feed_favicon', src: this.google_favicon_url + feed.feed_link }),
                                $.make('span', { className: 'feed_title' }, feed.feed_title)
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'score', value: this.score, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-disabled', value: 'Check what you like above...' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save_publisher();
                return false;
            })
        ]);
        
        var $modal_title = $('.NB-modal-title', this.$classifier);
        if (this.score == 1) {
            $modal_title.html('What do you <b class="NB-classifier-like">like</b> about this publisher?');
        } else if (this.score == -1) {
            $modal_title.html('What do you <b class="NB-classifier-dislike">dislike</b> about this publisher?');
        }
    },
        
    make_modal_story: function() {
        var self = this;
        var story = this.story;
        var feed = this.feed;
        var $story_tags = [];
        var $story_author;
        
        // HTML entities decoding.
        story.story_title = $('<div/>').html(story.story_title).text();

        for (var t in story.story_tags) {
            var tag = story.story_tags[t];
            var input_attrs = { type: 'checkbox', name: 'tag', value: tag, id: 'classifier_tag_'+t };
            NEWSBLUR.log(['input_attrs', input_attrs, tag, this.model.classifiers.tags]);
            if (tag in this.model.classifiers.tags && this.model.classifiers.tags[tag] == this.score) {
                input_attrs['checked'] = 'checked';
            }
            var $tag = $.make('span', { className: 'NB-classifier-tag-container NB-classifier NB-classifier-tag' }, [
                $.make('input', input_attrs),
                $.make('label', { 'for': 'classifier_tag_'+t }, [
                    $.make('b', tag)
                ])
            ]);
            $story_tags.push($tag);
        }
        
        if (story.story_authors) {
            var input_attrs = { type: 'checkbox', name: 'author', value: story.story_authors, id: 'classifier_author' };
            if (story.story_authors in this.model.classifiers.authors && this.model.classifiers.authors[story.story_authors] == this.score) {
                input_attrs['checked'] = 'checked';
            }
            $story_author = $.make('input', input_attrs);
        }
        
        this.$classifier = $.make('div', { className: 'NB-classifier NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }),
            $.make('form', { method: 'post' }, [
                (story.story_title && $.make('div', { className: 'NB-modal-field' }, [
                    $.make('h5', 'Story Title'),
                    $.make('div', { className: 'NB-classifiers' }, [
                        $.make('input', { type: 'checkbox', name: 'facet', value: 'title', id: 'classifier_title' }),
                        $.make('input', { type: 'text', value: story.story_title, className: 'NB-classifier-title-highlight' }),
                        $.make('label', { 'for': 'classifier_title' }, [
                            $.make('div', { className: 'NB-classifier-title-display' }, [
                                'Look for: ',
                                $.make('span', { className: 'NB-classifier-title NB-classifier-facet-disabled' }, 'Highlight phrases to look for in future stories'),
                                $.make('input', { name: 'title', value: '', type: 'hidden', className: 'NB-classifier-title-hidden' })
                            ])
                        ])
                    ])
                ])),
                (story.story_authors && $.make('div', { className: 'NB-modal-field' }, [
                    $.make('h5', 'Story Author'),
                    $.make('div', { className: 'NB-classifiers' }, [
                        $.make('div', { className: 'NB-classifier NB-classifier-author' }, [
                            $story_author,
                            $.make('label', { 'for': 'classifier_author' }, [
                                $.make('b', story.story_authors)
                            ])
                        ])
                    ])
                ])),
                ($story_tags.length && $.make('div', { className: 'NB-modal-field' }, [
                    $.make('h5', 'Story Categories &amp; Tags'),
                    $.make('div', { className: 'NB-classifier-tags NB-classifiers' }, $story_tags)
                ])),
                $.make('div', { className: 'NB-modal-field' }, [
                    $.make('h5', 'Everything by This Publisher'),
                    $.make('div', { className: 'NB-classifiers' }, [
                        $.make('div', { className: 'NB-classifier NB-classifier-publisher' }, [
                            $.make('input', { type: 'checkbox', name: 'facet', value: 'publisher', id: 'classifier_publisher' }),
                            $.make('label', { 'for': 'classifier_publisher' }, [
                                $.make('img', { className: 'feed_favicon', src: this.google_favicon_url + feed.feed_link }),
                                $.make('span', { className: 'feed_title' }, feed.feed_title)
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'score', value: this.score, type: 'hidden' }),
                    $.make('input', { name: 'feed_id', value: this.feed_id, type: 'hidden' }),
                    $.make('input', { name: 'story_id', value: this.story_id, type: 'hidden' }),
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-disabled', value: 'Check what you like above...' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save_story();
                return false;
            })
        ]);
        
        var $modal_title = $('.NB-modal-title', this.$classifier);
        if (this.score == 1) {
            $modal_title.html('What do you <b class="NB-classifier-like">like</b> about this story?');
        } else if (this.score == -1) {
            $modal_title.html('What do you <b class="NB-classifier-dislike">dislike</b> about this story?');
        }
    },
    
    open_modal: function() {
        var self = this;

        var $holder = $.make('div', { className: 'NB-modal-holder' }).append(this.$classifier).appendTo('body').css({'visibility': 'hidden', 'display': 'block', 'width': 600});
        var height = $('.NB-classifier', $holder).outerHeight(true);
        $holder.css({'visibility': 'visible', 'display': 'none'});
        
        this.$classifier.modal({
            'minWidth': 600,
            'minHeight': height,
            'overlayClose': true,
            'onOpen': function (dialog) {
	            dialog.overlay.fadeIn(200, function () {
		            dialog.container.fadeIn(200);
		            dialog.data.fadeIn(200);
	            });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px').css({'width': 600, 'height': height});
                $('.NB-classifier', self.$classifier).corner('14px');
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
        var $title_highlight = $('.NB-classifier-title-highlight', this.$classifier);
        var $title = $('.NB-classifier-title', this.$classifier);
        var $title_hidden = $('.NB-classifier-title-hidden', this.$classifier);
        var $title_checkbox = $('#classifier_title', this.$classifier);
        
        var update = function() {
            var text = $.trim($(this).getSelection().text);
            
            if ($title.text() != text && text.length) {
                $title_checkbox.attr('checked', 'checked').change();
                $title.text(text).removeClass('NB-classifier-facet-disabled');
                $title_hidden.val(text);
            }
        };
        
        $title_highlight.keydown(update).keyup(update).mousedown(update).mouseup(update).mousemove(update);
    },
    
    handle_select_title: function() {
        var $title_checkbox = $('#classifier_title', this.$classifier);
        var $title = $('.NB-classifier-title', this.$classifier);
        var $title_hidden = $('.NB-classifier-title-hidden', this.$classifier);
        var $title_highlight = $('.NB-classifier-title-highlight', this.$classifier);
        
        $title_checkbox.change(function() {;
            if ($title.hasClass('NB-classifier-facet-disabled')) {
                var text = $title_highlight.val();
                $title.text(text).removeClass('NB-classifier-facet-disabled');
                $title_hidden.val(text);
            }
        });
    },
    
    handle_select_checkboxes: function() {
        var self = this;
        var $submit = $('input[type=submit]', this.$classifier);
        
        $('input', this.$classifier).change(function() {
            var count = $('input:checked', self.$classifier).length;
            
            if (count) {
                $submit.removeClass("NB-disabled").removeAttr('disabled').attr('value', 'Save');
            } else {
                $submit.addClass("NB-disabled").attr('disabled', 'true').attr('value', 'Check what you like above...');
            }
        });
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$classifier);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
    
    serialize_classifier: function() {
        var data = $('.NB-classifier form input').serialize();
        
        return data;
    },
    
    serialize_classifier_array: function() {
        var data = $('.NB-classifier form input').serializeArray();
        
        return data;
    },
    
    save_publisher: function() {
        var $save = $('.NB-classifier input[type=submit]');
        var story_id = this.story_id;
        var data = this.serialize_classifier();
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_publisher(data, function() {
            $.modal.close();
        });
    },
    
    save_story: function() {
        var $save = $('.NB-classifier input[type=submit]');
        var story_id = this.story_id;
        var data = this.serialize_classifier();
        var classifiers = this.serialize_classifier_array();
        
        for (var c in classifiers) {
            var classifier = classifiers[c];
            if (!classifier) continue;
            if (classifier['name'] == 'tag') {
                this.model.classifiers.tags[classifier['value']] = this.score;
            } else if (classifier['name'] == 'title') {
                this.model.classifiers.titles[classifier['value']] = this.score;
            } else if (classifier['name'] == 'author') {
                this.model.classifiers.authors[classifier['value']] = this.score;
            } else if (classifier['name'] == 'facet' && classifier['value'] == 'publisher') {
                this.model.classifiers.feeds[this.feed_id] = this.score;
            }
        }
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_story(story_id, data, function() {
            $.modal.close();
        });
    }
    
};

NEWSBLUR.ReaderClassifierStory.prototype = classifier;
NEWSBLUR.ReaderClassifierFeed.prototype = classifier;
