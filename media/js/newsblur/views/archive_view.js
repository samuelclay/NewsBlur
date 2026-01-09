NEWSBLUR.Views.ArchiveView = Backbone.View.extend({

    className: "NB-archive-view",

    events: {
        "click .NB-archive-tab": "switch_tab",
        "click .NB-archive-category-filter": "toggle_category_filter",
        "click .NB-archive-domain-filter": "toggle_domain_filter",
        "click .NB-archive-load-more": "load_more_archives",
        "click .NB-archive-item": "open_archive_item",
        "click .NB-archive-item-newsblur-link": "open_story_in_newsblur",
        "keypress .NB-archive-assistant-input": "handle_assistant_keypress",
        "click .NB-archive-assistant-send": "submit_assistant_query",
        "click .NB-archive-suggestion": "use_suggestion"
    },

    initialize: function (options) {
        this.options = options || {};
        this.model = NEWSBLUR.assets;
        this.active_tab = 'assistant';  // 'assistant' or 'browser'
        this.archives = [];
        this.categories = [];
        this.domains = [];
        this.page = 1;
        this.has_more = true;
        this.is_loading = false;
        this.active_category = null;
        this.active_domain = null;
        this.suggestions = [];
        this.conversations = [];
        this.active_conversation = null;
        this.conversation_history = [];
        this.is_streaming = false;
        this.response_text = '';
        this.usage = null;
        this.active_query_id = null;
        this.tool_status = null;
        this.websocket_timeout = null;
        this.response_completed = false;

        this.fetch_initial_data();
    },

    fetch_initial_data: function () {
        var self = this;

        // Fetch suggestions, usage, and recent archives in parallel
        this.show_loading();

        var fetch_count = 3;
        var completed = 0;

        var check_complete = function () {
            completed++;
            if (completed >= fetch_count) {
                self.hide_loading();
                self.render();
            }
        };

        // Fetch suggestions
        this.model.make_request('/archive-assistant/suggestions', {}, function (data) {
            if (data.code === 0) {
                self.suggestions = data.suggestions || [];
            }
            check_complete();
        }, check_complete, { request_type: 'GET' });

        // Fetch usage
        this.model.make_request('/archive-assistant/usage', {}, function (data) {
            if (data.code === 0) {
                self.usage = data.usage;
            }
            check_complete();
        }, check_complete, { request_type: 'GET' });

        // Fetch categories and domains
        this.fetch_filters(check_complete);
    },

    fetch_filters: function (callback) {
        var self = this;

        this.model.make_request('/api/archive/categories', {}, function (data) {
            if (data.code === 0) {
                self.categories = data.categories || [];
                self.domains = data.domains || [];
            }
            if (callback) callback();
        }, callback, { request_type: 'GET' });
    },

    fetch_archives: function (reset) {
        var self = this;

        if (this.is_loading) return;

        if (reset) {
            this.page = 1;
            this.has_more = true;
            this.archives = [];
        }

        this.is_loading = true;
        this.show_archive_loading();

        var params = {
            page: this.page,
            limit: 20
        };

        if (this.active_category) {
            params.category = this.active_category;
        }
        if (this.active_domain) {
            params.domain = this.active_domain;
        }

        this.model.make_request('/api/archive/list', params, function (data) {
            self.is_loading = false;
            self.hide_archive_loading();

            if (data.code === 0) {
                self.archives = self.archives.concat(data.archives || []);
                self.has_more = data.has_more || false;
                self.page++;
                self.render_archives();
            }
        }, function () {
            self.is_loading = false;
            self.hide_archive_loading();
            self.show_archive_error('Failed to load archives');
        }, { request_type: 'GET' });
    },

    show_loading: function () {
        this.$el.html($.make('div', { className: 'NB-archive-container' }, [
            $.make('div', { className: 'NB-archive-loading' }, [
                $.make('div', { className: 'NB-loading NB-active' })
            ])
        ]));
    },

    hide_loading: function () {
        this.$el.find('.NB-loading').removeClass('NB-active').html('');
    },

    show_archive_loading: function () {
        var $loading = this.$('.NB-archive-load-more');
        if ($loading.length) {
            $loading.addClass('NB-loading').text('Loading...');
        }
    },

    hide_archive_loading: function () {
        var $loading = this.$('.NB-archive-load-more');
        if ($loading.length) {
            $loading.removeClass('NB-loading').text('Load More');
        }
    },

    show_archive_error: function (message) {
        this.$('.NB-archive-browser-content').html(
            $.make('div', { className: 'NB-archive-error' }, message)
        );
    },

    render: function () {
        var self = this;

        this.$el.html($.make('div', { className: 'NB-archive-container' }, [
            // Header with tabs
            $.make('div', { className: 'NB-archive-header' }, [
                $.make('div', { className: 'NB-archive-tabs' }, [
                    $.make('div', {
                        className: 'NB-archive-tab' + (this.active_tab === 'assistant' ? ' NB-active' : ''),
                        'data-tab': 'assistant'
                    }, [
                        $.make('img', { src: '/media/img/icons/nouns/ai-brain.svg', className: 'NB-archive-tab-icon' }),
                        'Archive Assistant'
                    ]),
                    $.make('div', {
                        className: 'NB-archive-tab' + (this.active_tab === 'browser' ? ' NB-active' : ''),
                        'data-tab': 'browser'
                    }, [
                        $.make('img', { src: '/media/img/icons/nouns/archive.svg', className: 'NB-archive-tab-icon' }),
                        'Browse Archives'
                    ])
                ]),
                this.usage ? $.make('div', { className: 'NB-archive-usage' }, [
                    $.make('span', { className: 'NB-archive-usage-count' }, this.usage.queries_today + '/' + this.usage.queries_limit),
                    ' queries today'
                ]) : ''
            ]),

            // Tab content
            $.make('div', { className: 'NB-archive-tab-content' }, [
                // Assistant tab
                $.make('div', {
                    className: 'NB-archive-assistant-tab' + (this.active_tab === 'assistant' ? ' NB-active' : '')
                }, this.render_assistant_tab()),

                // Browser tab
                $.make('div', {
                    className: 'NB-archive-browser-tab' + (this.active_tab === 'browser' ? ' NB-active' : '')
                }, this.render_browser_tab())
            ])
        ]));

        // Set up scroll handler for infinite scroll in browser tab
        this.throttled_check_scroll = _.throttle(_.bind(this.check_scroll, this), 100);
        this.$el.on('scroll', this.throttled_check_scroll);

        // Store view reference for WebSocket event lookup
        this.$el.data('view', this);

        return this;
    },

    render_assistant_tab: function () {
        var elements = [];

        // Chat history
        elements.push($.make('div', { className: 'NB-archive-assistant-chat' }, [
            $.make('div', { className: 'NB-archive-assistant-messages' },
                this.render_conversation_messages()
            )
        ]));

        // Suggestions (only show if no conversation yet)
        if (this.conversation_history.length === 0 && this.suggestions.length > 0) {
            var suggestion_elements = _.map(this.suggestions.slice(0, 4), function (suggestion) {
                return $.make('div', { className: 'NB-archive-suggestion' }, suggestion);
            });

            elements.push($.make('div', { className: 'NB-archive-suggestions' }, [
                $.make('div', { className: 'NB-archive-suggestions-title' }, 'Suggested questions'),
                $.make('div', { className: 'NB-archive-suggestions-list' }, suggestion_elements)
            ]));
        }

        // Input area
        elements.push($.make('div', { className: 'NB-archive-assistant-input-wrapper' }, [
            $.make('input', {
                type: 'text',
                className: 'NB-archive-assistant-input',
                placeholder: 'Ask about your browsing history...'
            }),
            $.make('div', { className: 'NB-archive-assistant-send' })
        ]));

        return elements;
    },

    render_conversation_messages: function () {
        var self = this;
        var elements = [];

        if (this.conversation_history.length === 0) {
            elements.push($.make('div', { className: 'NB-archive-assistant-welcome' }, [
                $.make('img', { src: '/media/img/icons/nouns/ai-brain.svg', className: 'NB-archive-welcome-icon' }),
                $.make('div', { className: 'NB-archive-welcome-title' }, 'Archive Assistant'),
                $.make('div', { className: 'NB-archive-welcome-subtitle' },
                    'Ask questions about everything you\'ve read. I can search your browsing history and find relevant information.')
            ]));
        } else {
            _.each(this.conversation_history, function (message, index) {
                var is_user = message.role === 'user';
                var $message = $.make('div', {
                    className: 'NB-archive-assistant-message' + (is_user ? ' NB-user' : ' NB-assistant')
                }, [
                    $.make('div', { className: 'NB-archive-message-content' },
                        is_user ? message.content : self.markdown_to_html(message.content))
                ]);
                elements.push($message);
            });
        }

        // Show streaming response or tool status
        if (this.is_streaming) {
            if (this.tool_status) {
                // Show tool call status (e.g., "Searching your archive...")
                elements.push($.make('div', { className: 'NB-archive-assistant-message NB-assistant NB-tool-status' }, [
                    $.make('div', { className: 'NB-archive-message-tool' }, [
                        $.make('span', { className: 'NB-tool-icon' }),
                        this.tool_status
                    ])
                ]));
            } else if (this.response_text) {
                // Show streaming text
                elements.push($.make('div', { className: 'NB-archive-assistant-message NB-assistant NB-streaming' }, [
                    $.make('div', { className: 'NB-archive-message-content' }, this.markdown_to_html(this.response_text))
                ]));
            } else {
                // Show thinking animation
                elements.push($.make('div', { className: 'NB-archive-assistant-message NB-assistant NB-thinking' }, [
                    $.make('div', { className: 'NB-archive-message-thinking' }, [
                        $.make('span', { className: 'NB-thinking-dot' }),
                        $.make('span', { className: 'NB-thinking-dot' }),
                        $.make('span', { className: 'NB-thinking-dot' })
                    ])
                ]));
            }
        }

        return elements;
    },

    render_browser_tab: function () {
        var elements = [];

        // Filters sidebar
        elements.push($.make('div', { className: 'NB-archive-filters' }, [
            // Categories
            $.make('div', { className: 'NB-archive-filter-section' }, [
                $.make('div', { className: 'NB-archive-filter-title' }, 'Categories'),
                $.make('div', { className: 'NB-archive-filter-list NB-archive-categories' },
                    this.render_category_filters()
                )
            ]),
            // Domains
            $.make('div', { className: 'NB-archive-filter-section' }, [
                $.make('div', { className: 'NB-archive-filter-title' }, 'Top Domains'),
                $.make('div', { className: 'NB-archive-filter-list NB-archive-domains' },
                    this.render_domain_filters()
                )
            ])
        ]));

        // Archive list
        elements.push($.make('div', { className: 'NB-archive-browser-content' }, [
            $.make('div', { className: 'NB-archive-list' }),
            $.make('div', { className: 'NB-archive-load-more NB-button' }, 'Load Archives')
        ]));

        return elements;
    },

    render_category_filters: function () {
        return this.render_filters(this.categories, 'category', this.active_category);
    },

    render_domain_filters: function () {
        return this.render_filters(this.domains, 'domain', this.active_domain);
    },

    render_filters: function (items, filter_type, active_value) {
        return _.map(items.slice(0, 10), function (item) {
            var is_active = active_value === item._id;
            var attrs = {
                className: 'NB-archive-' + filter_type + '-filter' + (is_active ? ' NB-active' : '')
            };
            attrs['data-' + filter_type] = item._id;

            return $.make('div', attrs, [
                $.make('span', { className: 'NB-archive-filter-name' }, item._id),
                $.make('span', { className: 'NB-archive-filter-count' }, item.count)
            ]);
        });
    },

    render_archives: function () {
        var self = this;
        var $list = this.$('.NB-archive-list');
        var $load_more = this.$('.NB-archive-load-more');

        if (this.archives.length === 0) {
            $list.html($.make('div', { className: 'NB-archive-empty' }, [
                $.make('img', { src: '/media/img/icons/nouns/archive.svg', className: 'NB-archive-empty-icon' }),
                $.make('div', { className: 'NB-archive-empty-title' }, 'No archived pages yet'),
                $.make('div', { className: 'NB-archive-empty-subtitle' },
                    'Install the NewsBlur Archive browser extension to start building your browsing history.')
            ]));
            $load_more.hide();
            return;
        }

        var items = _.map(this.archives, function (archive) {
            return self.render_archive_item(archive);
        });

        $list.html(items);
        $load_more.toggle(this.has_more);
    },

    render_archive_item: function (archive) {
        var date = archive.archived_date ? new Date(archive.archived_date) : null;
        var date_str = date ? this.format_relative_date(date) : '';

        var categories = archive.ai_categories || [];
        var categories_html = _.map(categories.slice(0, 2), function (cat) {
            return $.make('span', { className: 'NB-archive-item-category' }, cat);
        });

        // Build stats display (word count, file size)
        var stats_items = [];
        if (archive.word_count_display) {
            stats_items.push($.make('span', { className: 'NB-archive-item-stat' }, [
                $.make('span', { className: 'NB-archive-stat-value' }, archive.word_count_display),
                ' words'
            ]));
        }
        if (archive.file_size_display) {
            stats_items.push($.make('span', { className: 'NB-archive-item-stat' }, [
                $.make('span', { className: 'NB-archive-stat-value' }, archive.file_size_display)
            ]));
        }
        if (archive.has_content === false) {
            stats_items.push($.make('span', { className: 'NB-archive-item-stat NB-no-content' }, 'No content'));
        }

        // Create NewsBlur link if matched to a feed
        var newsblur_link = '';
        if (archive.matched_feed_id) {
            var link_attrs = {
                className: 'NB-archive-item-newsblur-link',
                'data-feed-id': archive.matched_feed_id,
                title: 'Open in NewsBlur'
            };
            if (archive.matched_story_hash) {
                link_attrs['data-story-hash'] = archive.matched_story_hash;
            }
            newsblur_link = $.make('div', link_attrs, [
                $.make('img', { src: '/media/img/favicon_32.png', className: 'NB-archive-item-newsblur-icon' })
            ]);
        }

        return $.make('div', { className: 'NB-archive-item', 'data-id': archive.id }, [
            $.make('div', { className: 'NB-archive-item-favicon' }, [
                archive.favicon_url ?
                    $.make('img', { src: archive.favicon_url, className: 'NB-archive-item-favicon-img' }) :
                    $.make('div', { className: 'NB-archive-item-favicon-placeholder' })
            ]),
            $.make('div', { className: 'NB-archive-item-content' }, [
                $.make('div', { className: 'NB-archive-item-title' }, archive.title || 'Untitled'),
                $.make('div', { className: 'NB-archive-item-meta' }, [
                    $.make('span', { className: 'NB-archive-item-domain' }, archive.domain || ''),
                    $.make('span', { className: 'NB-archive-item-date' }, date_str)
                ]),
                stats_items.length > 0 ? $.make('div', { className: 'NB-archive-item-stats' }, stats_items) : '',
                $.make('div', { className: 'NB-archive-item-categories' }, categories_html)
            ]),
            newsblur_link
        ]);
    },

    format_relative_date: function (date) {
        var now = new Date();
        var diff = now - date;
        var minutes = Math.floor(diff / 60000);
        var hours = Math.floor(diff / 3600000);
        var days = Math.floor(diff / 86400000);

        if (minutes < 1) return 'Just now';
        if (minutes < 60) return minutes + 'm ago';
        if (hours < 24) return hours + 'h ago';
        if (days < 7) return days + 'd ago';
        if (days < 30) return Math.floor(days / 7) + 'w ago';
        return date.toLocaleDateString();
    },

    switch_tab: function (e) {
        var $tab = $(e.currentTarget);
        var tab = $tab.data('tab');

        if (tab === this.active_tab) return;

        this.active_tab = tab;

        // Update tab buttons
        this.$('.NB-archive-tab').removeClass('NB-active');
        $tab.addClass('NB-active');

        // Update tab content
        this.$('.NB-archive-assistant-tab, .NB-archive-browser-tab').removeClass('NB-active');
        this.$('.NB-archive-' + tab + '-tab').addClass('NB-active');

        // Load archives when switching to browser tab
        if (tab === 'browser' && this.archives.length === 0) {
            this.fetch_archives(true);
        }
    },

    toggle_category_filter: function (e) {
        this.toggle_filter(e, 'category');
    },

    toggle_domain_filter: function (e) {
        this.toggle_filter(e, 'domain');
    },

    toggle_filter: function (e, filter_type) {
        var $filter = $(e.currentTarget);
        var value = $filter.data(filter_type);
        var active_property = 'active_' + filter_type;
        var filter_class = '.NB-archive-' + filter_type + '-filter';

        if (this[active_property] === value) {
            this[active_property] = null;
            $filter.removeClass('NB-active');
        } else {
            this.$(filter_class).removeClass('NB-active');
            this[active_property] = value;
            $filter.addClass('NB-active');
        }

        this.fetch_archives(true);
    },

    load_more_archives: function () {
        if (this.archives.length === 0) {
            this.fetch_archives(true);
        } else if (this.has_more) {
            this.fetch_archives(false);
        }
    },

    check_scroll: function () {
        if (this.active_tab !== 'browser') return;
        if (this.is_loading || !this.has_more) return;

        var container_height = this.$el.height();
        var scroll_top = this.$el.scrollTop();
        var scroll_height = this.$el[0].scrollHeight;

        if (scroll_height - (scroll_top + container_height) < 200) {
            this.fetch_archives(false);
        }
    },

    open_archive_item: function (e) {
        var $item = $(e.currentTarget);
        var id = $item.data('id');
        var archive = _.find(this.archives, function (a) { return a.id === id; });

        if (archive && archive.url) {
            window.open(archive.url, '_blank');
        }
    },

    open_story_in_newsblur: function (e) {
        e.stopPropagation();  // Prevent opening the archive URL

        var $link = $(e.currentTarget);
        var feed_id = $link.data('feed-id');
        var story_hash = $link.data('story-hash');

        if (feed_id && NEWSBLUR.reader) {
            var options = {
                router: true
            };
            if (story_hash) {
                options.story_id = story_hash;
            }
            NEWSBLUR.reader.open_feed(feed_id, options);
        }
    },

    use_suggestion: function (e) {
        var $suggestion = $(e.currentTarget);
        var query = $suggestion.text();

        this.$('.NB-archive-assistant-input').val(query);
        this.submit_assistant_query();
    },

    handle_assistant_keypress: function (e) {
        if (e.which === 13) {  // Enter key
            e.preventDefault();
            this.submit_assistant_query();
        }
    },

    submit_assistant_query: function () {
        var $input = this.$('.NB-archive-assistant-input');
        var query = $input.val().trim();

        if (!query) return;

        // Add user message to history
        this.conversation_history.push({
            role: 'user',
            content: query
        });

        // Clear input and start streaming
        $input.val('');
        this.is_streaming = true;
        this.response_text = '';

        // Re-render messages
        this.render_assistant_messages();

        // Scroll to bottom
        this.scroll_to_bottom();

        // Send request
        this.send_assistant_query(query);
    },

    send_assistant_query: function (query) {
        var self = this;

        var params = {
            query: query
        };

        if (this.active_conversation) {
            params.conversation_id = this.active_conversation;
        }

        this.model.make_request('/archive-assistant/query', params, function (data) {
            if (data.code === 0) {
                self.active_conversation = data.conversation_id;
                self.active_query_id = data.query_id;
                self.response_completed = false;

                // Response will come via WebSocket
                // Set a timeout fallback in case WebSocket fails
                self.websocket_timeout = setTimeout(function () {
                    if (self.is_streaming && self.active_query_id === data.query_id) {
                        // Fallback to polling if no WebSocket response after 5 seconds
                        NEWSBLUR.log(['Archive Assistant: WebSocket timeout, falling back to polling']);
                        self.poll_for_response(data.query_id);
                    }
                }, 5000);
            } else {
                self.handle_assistant_error(data.message || 'Failed to submit query');
            }
        }, function () {
            self.handle_assistant_error('Failed to connect to server');
        }, { method: 'POST' });
    },

    poll_for_response: function (query_id) {
        var self = this;
        var poll_count = 0;
        var max_polls = 60;  // 30 seconds max

        var poll = function () {
            // Stop polling if response was already completed via WebSocket
            if (self.response_completed) {
                NEWSBLUR.log(['Archive Assistant: Polling stopped - response already completed via WebSocket']);
                return;
            }

            if (poll_count >= max_polls) {
                self.handle_assistant_error('Request timed out');
                return;
            }

            poll_count++;

            self.model.make_request('/archive-assistant/conversation/' + self.active_conversation, {}, function (data) {
                // Check again in case WebSocket completed while request was in flight
                if (self.response_completed) {
                    NEWSBLUR.log(['Archive Assistant: Polling stopped - response completed during request']);
                    return;
                }

                if (data.code === 0 && data.queries && data.queries.length > 0) {
                    var query = _.find(data.queries, function (q) { return q.id === query_id; });

                    if (query && query.response) {
                        // Mark as completed to prevent WebSocket from duplicating
                        self.response_completed = true;
                        self.is_streaming = false;
                        self.response_text = '';

                        // Add assistant response to history
                        self.conversation_history.push({
                            role: 'assistant',
                            content: query.response
                        });

                        self.render_assistant_messages();
                        self.scroll_to_bottom();
                    } else if (query && query.error) {
                        self.handle_assistant_error(query.error);
                    } else {
                        // Still processing, poll again
                        setTimeout(poll, 500);
                    }
                } else {
                    setTimeout(poll, 500);
                }
            }, function () {
                setTimeout(poll, 500);
            }, { request_type: 'GET' });
        };

        poll();
    },

    handle_assistant_error: function (message) {
        this.is_streaming = false;
        this.response_text = '';
        this.tool_status = null;
        this.active_query_id = null;
        this.clear_websocket_timeout();

        this.conversation_history.push({
            role: 'assistant',
            content: '**Error:** ' + message
        });

        this.render_assistant_messages();
        this.scroll_to_bottom();
    },

    clear_websocket_timeout: function () {
        if (this.websocket_timeout) {
            clearTimeout(this.websocket_timeout);
            this.websocket_timeout = null;
        }
    },

    // ===================
    // = WebSocket Handlers =
    // ===================

    handle_stream_start: function (data) {
        this.clear_websocket_timeout();
        NEWSBLUR.log(['Archive Assistant: WebSocket stream started', data.query_id]);
    },

    append_chunk: function (content) {
        this.response_text += content;
        this.tool_status = null;  // Clear tool status when content arrives
        this.render_assistant_messages();
        this.scroll_to_bottom();
    },

    show_tool_call: function (tool_name, tool_input) {
        // Map tool names to user-friendly status messages
        var status_messages = {
            'search_archives': 'Searching your archive...',
            'search_by_date': 'Searching by date...',
            'get_page_content': 'Retrieving page content...',
            'search_by_domain': 'Searching domain...',
            'list_categories': 'Loading categories...'
        };

        this.tool_status = status_messages[tool_name] || 'Processing...';
        NEWSBLUR.log(['Archive Assistant: Tool call', tool_name, tool_input]);
        this.render_assistant_messages();
        this.scroll_to_bottom();
    },

    complete_response: function (data) {
        NEWSBLUR.log(['Archive Assistant: Response complete', data]);

        // Prevent duplicate responses from WebSocket and polling
        if (this.response_completed) {
            NEWSBLUR.log(['Archive Assistant: Response already completed, skipping']);
            return;
        }
        this.response_completed = true;

        this.is_streaming = false;
        this.tool_status = null;
        this.active_query_id = null;
        this.clear_websocket_timeout();

        if (this.response_text) {
            this.conversation_history.push({
                role: 'assistant',
                content: this.response_text
            });
        }

        this.response_text = '';
        this.render_assistant_messages();
        this.scroll_to_bottom();
    },

    show_error: function (error_message) {
        NEWSBLUR.log(['Archive Assistant: Error', error_message]);
        this.handle_assistant_error(error_message);
    },

    render_assistant_messages: function () {
        var $messages = this.$('.NB-archive-assistant-messages');
        $messages.html(this.render_conversation_messages());

        // Hide suggestions after first message
        if (this.conversation_history.length > 0) {
            this.$('.NB-archive-suggestions').hide();
        }
    },

    scroll_to_bottom: function () {
        var $chat = this.$('.NB-archive-assistant-chat');
        if ($chat.length) {
            $chat.scrollTop($chat[0].scrollHeight);
        }
    },

    markdown_to_html: function (text) {
        // Markdown to HTML converter
        var self = this;
        var lines = text.split('\n');
        var html_lines = [];
        var list_type = null;  // 'ul' or 'ol'

        var close_list = function () {
            if (list_type) {
                html_lines.push('</' + list_type + '>');
                list_type = null;
            }
        };

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];

            // Escape HTML
            line = line.replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');

            // Headings (## and ###)
            if (line.match(/^### (.+)$/)) {
                close_list();
                line = '<h4>' + self.apply_inline_formatting(line.replace(/^### (.+)$/, '$1')) + '</h4>';
                html_lines.push(line);
                continue;
            }
            if (line.match(/^## (.+)$/)) {
                close_list();
                line = '<h3>' + self.apply_inline_formatting(line.replace(/^## (.+)$/, '$1')) + '</h3>';
                html_lines.push(line);
                continue;
            }

            // Ordered list items (1. 2. 3.)
            if (line.match(/^\d+\. (.+)$/)) {
                if (list_type !== 'ol') {
                    close_list();
                    html_lines.push('<ol class="NB-markdown-list">');
                    list_type = 'ol';
                }
                var content = line.replace(/^\d+\. (.+)$/, '$1');
                content = self.apply_inline_formatting(content);
                html_lines.push('<li>' + content + '</li>');
                continue;
            }

            // Unordered list items (- item)
            if (line.match(/^- (.+)$/)) {
                if (list_type !== 'ul') {
                    close_list();
                    html_lines.push('<ul class="NB-markdown-list">');
                    list_type = 'ul';
                }
                var content = line.replace(/^- (.+)$/, '$1');
                content = self.apply_inline_formatting(content);
                html_lines.push('<li>' + content + '</li>');
                continue;
            }

            // Close list if we hit non-list content
            if (list_type && line.trim() !== '') {
                close_list();
            }

            // Empty lines
            if (line.trim() === '') {
                close_list();
                continue;
            }

            // Regular paragraph text
            line = self.apply_inline_formatting(line);
            html_lines.push('<p>' + line + '</p>');
        }

        close_list();
        return html_lines.join('');
    },

    apply_inline_formatting: function (text) {
        // Bold
        text = text.replace(/\*\*([^\n]+?)\*\*/g, '<strong>$1</strong>');
        text = text.replace(/__([^\n]+?)__/g, '<strong>$1</strong>');

        // Italic
        text = text.replace(/\*([^\n*]+?)\*/g, '<em>$1</em>');
        text = text.replace(/_([^\n_]+?)_/g, '<em>$1</em>');

        // Links - convert [text](url) to clickable links
        text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');

        return text;
    },

    // ==========================
    // = Real-time WebSocket Updates =
    // ==========================

    handle_archive_new: function (data) {
        var self = this;
        var new_archives = data.archives || [];

        if (new_archives.length === 0) return;

        NEWSBLUR.log(['Archive View: Received', new_archives.length, 'new archives via WebSocket']);

        // Prepend new archives to the list (check for duplicates by archive_id)
        new_archives.forEach(function (archive) {
            // Normalize the ID field (backend sends archive_id, frontend expects id)
            if (archive.archive_id && !archive.id) {
                archive.id = archive.archive_id;
            }

            var exists = _.find(self.archives, function (a) {
                return a.id === archive.id || a.id === archive.archive_id;
            });

            if (!exists) {
                self.archives.unshift(archive);
                self.update_sidebar_for_archive(archive);
            }
        });

        // Re-render if on browser tab
        if (this.active_tab === 'browser') {
            this.render_archives();
        }

        // Show notification
        this.show_archive_notification(new_archives.length);
    },

    update_sidebar_for_archive: function (archive) {
        // Update domain count
        var domain = archive.domain;
        if (domain) {
            var existing_domain = _.find(this.domains, function (d) { return d._id === domain; });
            if (existing_domain) {
                existing_domain.count++;
            } else {
                this.domains.unshift({ _id: domain, count: 1 });
            }
            // Re-sort domains by count
            this.domains = _.sortBy(this.domains, function (d) { return -d.count; });
            this.$('.NB-archive-domains').html(this.render_domain_filters());
        }

        // Update categories (if present in the archive data)
        var categories = archive.ai_categories || [];
        if (categories.length > 0) {
            categories.forEach(function (cat) {
                var existing_cat = _.find(this.categories, function (c) { return c._id === cat; });
                if (existing_cat) {
                    existing_cat.count++;
                } else {
                    this.categories.push({ _id: cat, count: 1 });
                }
            }, this);
            // Re-sort categories by count
            this.categories = _.sortBy(this.categories, function (c) { return -c.count; });
            this.$('.NB-archive-categories').html(this.render_category_filters());
        }
    },

    handle_archive_deleted: function (data) {
        var ids = data.archive_ids || [];

        if (ids.length === 0) return;

        NEWSBLUR.log(['Archive View: Received delete for', ids.length, 'archives via WebSocket']);

        // Remove deleted archives from the list
        this.archives = _.reject(this.archives, function (a) {
            return _.contains(ids, a.id) || _.contains(ids, a.archive_id);
        });

        // Re-render if on browser tab
        if (this.active_tab === 'browser') {
            this.render_archives();
        }
    },

    show_archive_notification: function (count) {
        // Log notification (could be enhanced to show a toast)
        NEWSBLUR.log(['Archive: ' + count + ' new page(s) archived in real-time']);
    },

    close: function () {
        this.clear_websocket_timeout();
        this.$el.off('scroll');
        this.remove();
    }

});
