NEWSBLUR.ReaderAddFeed = function(feed_id, score, options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner();
};

NEWSBLUR.ReaderAddFeed.prototype = {
    
    runner: function() {
        this.make_modal();
        this.handle_cancel();
        this.open_modal();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$add = $.make('div', { className: 'NB-add NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Add feeds and folders'),
            $.make('form', { method: 'post', enctype: 'multipart/form-data', className: 'NB-add-form' }, [
                $.make('div', { className: 'NB-fieldset' }, [
                    $.make('h5', [
                        $.make('div', { className: 'NB-add-folders' }, this.make_folders()),
                        'Add a new feed'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', [
                            $.make('label', { 'for': 'NB-add-url' }, 'RSS or URL: '),
                            $.make('input', { type: 'text', id: 'NB-add-url', className: 'NB-add-url', name: 'url' }),
                            $.make('input', { type: 'submit', value: 'Add it' })
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset' }, [
                    $.make('h5', [
                        $.make('div', { className: 'NB-add-folders' }, this.make_folders()),
                        'Add a new folder'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', [
                            $.make('label', { 'for': 'NB-add-folder' }, [
                                $.make('div', { className: 'NB-folder-icon' })
                            ]),
                            $.make('input', { type: 'text', id: 'NB-add-folder', className: 'NB-add-folder', name: 'url' }),
                            $.make('input', { type: 'submit', value: 'Add folder' })
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset' }, [
                    $.make('h5', 'Upload OPML (from Google Reader)'),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('input', { type: 'file', name: 'file', id: 'opml_file_input' }),
                        $.make('input', { type: 'submit', className: 'NB-add-opml-button', value: 'Upload OPML File' }).click(function(e) {
                            e.preventDefault();
                            self.handle_opml_upload();
                            return false;
                        })
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset' }, [
                    $.make('h5', [
                        'Import from Google Reader'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', { className: 'NB-disabled' }, 'Google Reader integration coming in the next few months.')
                    ])
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save();
                return false;
            })
        ]);
    
    },
    
    make_folders: function() {
        var folders = this.model.get_folders();
        var $options = $.make('select');
        
        var $option = $.make('option', { value: '' }, "Top Level");
        $options.append($option);

        $options = this.make_folder_options($options, folders, '-');
        
        return $options;
    },

    make_folder_options: function($options, items, depth) {
        for (var i in items) {
            var item = items[i];
            if (typeof item == "object") {
                for (var o in item) {
                    var folder = item[o];
                    var $option = $.make('option', { value: o }, depth + ' ' + o);
                    $options.append($option);
                    $options = this.make_folder_options($options, folder, depth+'-');
                }
            }
        }
    
        return $options;
    },

    open_modal: function() {
        var self = this;

        var $holder = $.make('div', { className: 'NB-modal-holder' }).append(this.$add).appendTo('body').css({'visibility': 'hidden', 'display': 'block', 'width': 600});
        var height = $('.NB-add', $holder).outerHeight(true);
        $holder.css({'visibility': 'visible', 'display': 'none'});
        
        this.$add.modal({
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
                // $('.NB-classifier-tag', self.$add).corner('4px');
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
        var $cancel = $('.NB-modal-cancel', this.$add);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
    
    serialize_classifier: function() {
        var data = $('.NB-add form input').serialize();
        
        return data;
    },
    
    save: function() {
        var $save = $('.NB-modal input[type=submit]');
        var story_id = this.story_id;
        var data = this.serialize_classifier();
        
        $save.text('Saving...').addClass('NB-disabled').attr('disabled', true);
        this.model.save_classifier_publisher(data, function() {
            $.modal.close();
        });
    },
    
    // ========
    // = OPML =
    // ========
        
    handle_opml_upload: function() {
        var self = this;
        
        // NEWSBLUR.log(['Uploading']);
        $.ajaxFileUpload({
			url: '/opml/opml_upload', 
			secureuri: false,
			fileElementId: 'opml_file_input',
			dataType: 'json',
			success: function (data, status)
			{
				if (typeof data.code != 'undefined') {
					if (data.code <= 0) {
                        // NEWSBLUR.log(['Success - Error', data.code]);
					} else {
                        // NEWSBLUR.log(['Success', data]);
						NEWSBLUR.reader.load_feeds();
						$.modal.close();
					}
				}
			},
			error: function (data, status, e)
			{
				NEWSBLUR.log(['Error', data, status, e]);
			}
		});
		
		return false;
    },
    
    handle_opml_form: function() {
        var self = this;
        var $form = $('form.opml_import_form');
        
        // NEWSBLUR.log(['OPML Form:', $form]);
        
        var callback = function(e) {
            // NEWSBLUR.log(['OPML Callback', e]);
        };
        
        $form.submit(function() {
            
            self.model.process_opml_import($form.serialize(), callback);
            return false;
        });
    }
    
};