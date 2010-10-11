NEWSBLUR.ReaderManageFeed = function(feed_id, options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.feed_id = feed_id;
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.counters = {
        'classifier': 0
    };
    this.runner();
};

NEWSBLUR.ReaderManageFeed.prototype = {
    
    runner: function() {
        this.feeds = this.model.get_feeds();
        
        if (!this.feed_id) {
            // No feed selected, so just choose a random feed.
            var feeds_list = [];
            for (var f in this.feeds) {
                feeds_list.push(f);
            }
            this.feed_id = feeds_list[Math.round(Math.random() * 1000 % (feeds_list.length-1))];
            if (!this.feed_id) this.feed_id = f;
        }
        this.feed = this.model.get_feed(this.feed_id);
        
        if (this.feed_id) {
            this.make_modal();
            this.initialize_feed();
            this.handle_cancel();
            this.open_modal();
            this.load_feed_classifier();
        
            this.$manage.bind('click', $.rescope(this.handle_click, this));
            this.$manage.bind('change', $.rescope(this.handle_change, this));
            this.$manage.bind('keyup', $.rescope(this.handle_keyup, this));
        }
    },
    
    initialize_feed: function(feed_id) {
        if (feed_id) this.feed_id = feed_id;
        this.feed = this.model.get_feed(this.feed_id);
        $('.NB-modal-title', this.$manage).html(this.feed['feed_title']);
        $('input[name=feed_id]', this.$manage).val(this.feed_id);
        $('input[name=rename_title]', this.$manage).val(this.feed['feed_title']);
    },
    
    make_modal: function() {
        var self = this;
        
        this.$manage = $.make('div', { className: 'NB-manage NB-modal' }, [
            $.make('form', { method: 'post', className: 'NB-manage-form' }, [
                $.make('div', { className: 'NB-manage-container'}, [
                    $.make('div', { className: 'NB-modal-loading' }),
                    $.make('h2', { className: 'NB-modal-title' }),
                    $.make('div', { className: 'NB-manage-field' }, [
                        $.make('div', { className: 'NB-fieldset' }, [
                            $.make('h5', [
                                'What you ',
                                $.make('span', { className: 'NB-classifier-like' }, 'like')
                            ]),
                            $.make('div', { className: 'NB-manage-classifier NB-manage-classifier-likes NB-fieldset-fields' })
                        ]),
                        $.make('div', { className: 'NB-fieldset' }, [
                            $.make('h5', [
                                'What you ',
                                $.make('span', { className: 'NB-classifier-dislike' }, 'dislike')
                            ]),
                            $.make('div', { className: 'NB-manage-classifier NB-manage-classifier-dislikes NB-fieldset-fields' })
                        ]),
                        $.make('div', { className: 'NB-fieldset' }, [
                            $.make('h5', 'Management'),
                            $.make('div', { className: 'NB-manage-management NB-fieldset-fields NB-modal-submit' }, [
                                $.make('div', { className: 'NB-manage-rename' }, [
                                    $.make('label', { className: 'NB-manage-rename-label', 'for': 'id_rename' }, "Feed Title: "),
                                    $.make('input', { name: 'rename_title', id: 'id_rename' })
                                ]),
                                $.make('input', { type: 'submit', value: 'Fetch and refresh this site', className: 'NB-modal-submit-green NB-modal-submit-retry' }),
                                $.make('div', { className: 'NB-manage-delete' }, [
                                    $.make('input', { type: 'submit', value: 'Delete this site', className: 'NB-modal-submit-green NB-modal-submit-delete' }),
                                    $.make('a', { className: 'NB-delete-confirm', href: '#' }, "Yes, delete this feed!"),
                                    $.make('a', { className: 'NB-delete-cancel', href: '#' }, "cancel")
                                ])
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-modal-feed-chooser-container'}, [
                    this.make_feed_chooser()
                ]),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { name: 'feed_id', type: 'hidden' }),
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-save NB-modal-submit-green NB-disabled', value: 'Check what you like above...' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save();
                return false;
            })
        ]);
    
    },
    
    make_feed_chooser: function() {
        var $chooser = $.make('select', { name: 'feed', className: 'NB-modal-feed-chooser' });
        
        for (var f in this.feeds) {
            var feed = this.feeds[f];
            var $option = $.make('option', { value: feed.id }, feed.feed_title);
            $option.appendTo($chooser);
            
            if (feed.id == this.feed_id) {
                $option.attr('selected', true);
            }
        }
        
        $('option', $chooser).tsort();
        return $chooser;
    },
    
    make_classifiers: function(classifiers, score) {
        var $classifiers = $.make('div');
        var i = this.counters['classifier'];
        var opinion = (score == 1 ? 'like_' : 'dislike_');
        
        // Tags
        var $tags = $.make('div', { className: 'NB-classifiers NB-classifier-tags'});
        for (var t in classifiers.tags) {
            if (classifiers.tags[t] == score) {
                var $tag = this.make_tag(t, i++, opinion);
                $tags.append($tag);
            }
        }
        
        // Authors
        var $authors = $.make('div', { className: 'NB-classifiers NB-classifier-authors'});
        for (var fa in classifiers.authors) {
            if (classifiers.authors[fa] == score) {
                var $author = this.make_author(fa, i++, opinion);
                $authors.append($author);
            }
        }
        
        // Titles
        var $titles = $.make('div', { className: 'NB-classifiers NB-classifier-titles'});
        for (var t in classifiers.titles) {
            if (classifiers.titles[t] == score) {
                var $title = this.make_title(t, i++, opinion);
                $titles.append($title);
            }
        }
        
        // Publisher
        var $publishers = $.make('div', { className: 'NB-classifiers NB-classifier-publishers'});
        for (var feed_id in classifiers.feeds) {
            if (classifiers.feeds[feed_id] == score) {
                var $publisher = this.make_publisher(feed_id, i++, opinion);
                $publishers.append($publisher);
            }
        }
        
        $classifiers.append($tags);
        $classifiers.append($authors);
        $classifiers.append($titles);
        $classifiers.append($publishers);
        
        if (!$('.NB-classifier', $classifiers).length) {
            var $empty_classifier = $.make('div', { className: 'NB-classifier-empty' }, [
                'No opinions yet. Use the ',
                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/thumbs-down.png', className: 'NB-dislike' }),
                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/reader/thumbs-up.png', className: 'NB-like' }),
                ' buttons next to stories.'
            ]);
            $classifiers.append($empty_classifier);
        }
        
        this.counters['classifier'] = i;
        return $classifiers;
    },
    
    make_author: function(feed_author, i, opinion) {
        var $author = $.make('span', { className: 'NB-classifier NB-classifier-author' }, [
            $.make('input', { type: 'checkbox', name: opinion+'author', value: feed_author, id: 'classifier_author_'+i, checked: 'checked' }),
            $.make('label', { 'for': 'classifier_author_'+i }, [
                $.make('b', 'Author: '),
                $.make('span', feed_author)
            ])
        ]);
        return $author;
    },
    
    make_tag: function(tag, t, opinion) {
        var $tag = $.make('span', { className: 'NB-classifier-tag-container' }, [
            $.make('span', { className: 'NB-classifier NB-classifier-tag' }, [
                $.make('input', { type: 'checkbox', name: opinion+'tag', value: tag, id: 'classifier_tag_'+t, checked: 'checked' }),
                $.make('label', { 'for': 'classifier_tag_'+t }, [
                    $.make('b', 'Tag: '),
                    $.make('span', tag)
                ])
            ])
        ]);
        return $tag;
    },
    
    make_publisher: function(feed_id, i, opinion) {
        var publisher = this.model.get_feed(feed_id);
        var $publisher = $.make('div', { className: 'NB-classifier NB-classifier-publisher' }, [
            $.make('input', { type: 'checkbox', name: opinion+'publisher', value: this.feed_id, id: 'classifier_publisher', checked: 'checked' }),
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
    
    load_feed_classifier: function() {
        var $loading = $('.NB-modal-loading', this.$manage);
        $loading.addClass('NB-active');
        
        this.model.get_feed_classifier(this.feed_id, $.rescope(this.post_load_feed_classifier, this));
    },
    
    post_load_feed_classifier: function(e, classifiers) {
        var $loading = $('.NB-modal-loading', this.$manage);
        $loading.removeClass('NB-active');
        
        var $likes = $('.NB-manage-classifier-likes');
        var $classifiers_likes = this.make_classifiers(classifiers.payload, 1);
        $likes.empty().append($classifiers_likes);
        
        var $dislikes = $('.NB-manage-classifier-dislikes');
        var $classifiers_dislikes = this.make_classifiers(classifiers.payload, -1);
        $dislikes.empty().append($classifiers_dislikes);
        
        $('.NB-classifier', this.$manage).corner('14px');
    },
    
    open_modal: function() {
        var self = this;
        
        this.$manage.modal({
            'minWidth': 600,
            'maxWidth': 600,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
                // $('.NB-classifier-tag', self.$manage).corner('4px');
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
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$manage);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
    
    serialize_classifier: function() {
        var checked_data = $('input', this.$manage).serialize();
        var $unchecked = $('input[type=checkbox]:not(:checked)', this.$manage);
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
    
    save: function() {
        var self = this;
        var $save = $('.NB-modal-submit-save', this.$manage);
        var data = this.serialize_classifier();
        
        NEWSBLUR.reader.update_opinions(this.$manage, this.feed_id);
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_publisher(data, function() {
            NEWSBLUR.reader.force_feed_refresh(self.feed_id);
            $.modal.close();
        });
    },
    
    save_retry_feed: function() {
        var self = this;
        var $loading = $('.NB-modal-loading', this.$manage);
        $loading.addClass('NB-active');
        
        $('.NB-modal-submit-retry', this.$manage).addClass('NB-disabled').attr('value', 'Fetching...');
        this.model.save_exception_retry(this.feed_id, function() {
            NEWSBLUR.reader.force_feed_refresh(self.feed_id, function() {
              if (NEWSBLUR.reader.active_feed == self.feed_id) {
                NEWSBLUR.reader.open_feed(self.feed_id, true);
              }
              $.modal.close();
            }, true);
        });
    },
    
    delete_feed: function() {
        var $loading = $('.NB-modal-loading', this.$manage);
        $loading.addClass('NB-active');
        var feed_id = this.feed_id;
        
        this.model.delete_publisher(feed_id, function() {
            NEWSBLUR.reader.delete_feed(feed_id);
            $.modal.close();
        });
    },

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-delete' }, function($t, $p){
            e.preventDefault();
            
            var $confirm = $('.NB-delete-confirm', self.$manage);
            var $cancel = $('.NB-delete-cancel', self.$manage);
            var $delete = $('.NB-modal-submit-delete', self.$manage);
            
            $delete.animate({'opacity': 0}, {'duration': 500});
            $confirm.fadeIn(500);
            $cancel.fadeIn(500);
        });
        
        $.targetIs(e, { tagSelector: '.NB-delete-cancel' }, function($t, $p){
            e.preventDefault();
            
            var $confirm = $('.NB-delete-confirm', self.$manage);
            var $cancel = $('.NB-delete-cancel', self.$manage);
            var $delete = $('.NB-modal-submit-delete', self.$manage);
            
            $delete.css({'opacity': 1});
            $confirm.css({'display': 'none'});
            $cancel.css({'display': 'none'});
        });
        
        $.targetIs(e, { tagSelector: '.NB-delete-confirm' }, function($t, $p){
            e.preventDefault();
            
            self.delete_feed();
        });
        
        $.targetIs(e, { tagSelector: 'input', childOf: '.NB-classifier' }, function($t, $p) {
            var $submit = $('.NB-modal-submit-save', self.$manage);
            $submit.removeClass("NB-disabled").removeAttr('disabled').attr('value', 'Save');
        });
    
        $.targetIs(e, { tagSelector: '.NB-modal-submit-retry' }, function($t, $p) {
            e.preventDefault();
            
            self.save_retry_feed();
        });
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function($t, $p){
            var feed_id = $t.val();
            self.initialize_feed(feed_id);
            self.load_feed_classifier();
        });
        
        $.targetIs(e, { tagSelector: 'input[type=checkbox]', childOf: '.NB-classifier' }, function($t, $p) {
            var $submit = $('.NB-modal-submit-save', self.$manage);
            $submit.removeClass("NB-disabled").removeAttr('disabled').attr('value', 'Save');
        });
    },
    
    handle_keyup: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: 'input', childOf: '.NB-manage-rename' }, function($t, $p) {
            if ($t.val() != self.feed.feed_title) {
                var $submit = $('.NB-modal-submit-save', self.$manage);
                $submit.removeClass("NB-disabled").removeAttr('disabled').attr('value', 'Save');
            }
        });
    }
};