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
        var opinion = (this.score == 1 ? 'like_' : 'dislike_');
                
        NEWSBLUR.log(['Make feed', feed, this.feed_authors, this.feed_tags]);
        
        this.$classifier = $.make('div', { className: 'NB-classifier NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }),
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
        var opinion = (this.score == 1 ? 'like_' : 'dislike_');
        
        NEWSBLUR.log(['Make Story', story, feed]);
        
        // HTML entities decoding.
        story.story_title = $('<div/>').html(story.story_title).text();
        
        this.$classifier = $.make('div', { className: 'NB-classifier NB-modal' }, [
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
        
            if (author in this.model.classifiers.authors 
                && this.model.classifiers.authors[author] == this.score) {
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
            
            if (tag in this.model.classifiers.tags && this.model.classifiers.tags[tag] == this.score) {
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
        if (this.feed.feed_link in this.model.classifiers.feeds 
            && this.model.classifiers.feeds[this.feed.feed_link].score == this.score) {
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
            .append(this.$classifier)
            .appendTo('body')
            .css({'visibility': 'hidden', 'display': 'block', 'width': 600});
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
        var $title = $('.NB-classifier-title-text', this.$classifier);
        var $title_checkbox = $('#classifier_title', this.$classifier);
        
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
        var $title_checkbox = $('#classifier_title', this.$classifier);
        var $title = $('.NB-classifier-title-text', this.$classifier);
        var $title_highlight = $('.NB-classifier-title-highlight', this.$classifier);
        
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
        var checked_data = $('input', this.$classifier).serialize();
        
        var $unchecked = $('input[type=checkbox]:not(:checked)', this.$classifier);
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
        
    save_publisher: function() {
        var $save = $('.NB-classifier input[type=submit]');
        var story_id = this.story_id;
        var data = this.serialize_classifier();
        
        NEWSBLUR.reader.update_opinions(this.$classifier, this.feed_id);
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_publisher(data, function() {
            $.modal.close();
        });
    },
    
    save_story: function() {
        var $save = $('.NB-classifier input[type=submit]');
        var story_id = this.story_id;
        var data = this.serialize_classifier();
        
        NEWSBLUR.reader.update_opinions(this.$classifier, this.feed_id);
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_story(story_id, data, function() {
            $.modal.close();
        });
    }
    
};

NEWSBLUR.ReaderClassifierStory.prototype = classifier;
NEWSBLUR.ReaderClassifierFeed.prototype = classifier;
