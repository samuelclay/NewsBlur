NEWSBLUR.Views.ArchiveView = Backbone.View.extend({

    className: "NB-archive-view",

    events: {
        "click .NB-archive-tab": "switch_tab",
        "click .NB-archive-category-filter": "toggle_category_filter",
        "click .NB-archive-domain-filter": "toggle_domain_filter",
        "click .NB-archive-item": "open_archive_item",
        "click .NB-archive-item-newsblur-link": "open_story_in_newsblur",
        "keypress .NB-archive-assistant-input": "handle_assistant_keypress",
        "click .NB-archive-assistant-send": "submit_assistant_query",
        "click .NB-archive-suggestion": "use_suggestion",
        "click .NB-archive-assistant-voice-button": "start_voice_recording",
        "click .NB-archive-assistant-premium-only .NB-premium-link": "open_premium_modal",
        // Category management events
        "click .NB-archive-manage-categories": "open_category_manager",
        "click .NB-category-manager-close": "close_category_manager",
        "click .NB-category-manager-overlay": "close_category_manager",
        "change .NB-category-checkbox": "handle_category_selection",
        "click .NB-category-merge-btn": "merge_selected_categories",
        "click .NB-category-rename-btn": "show_rename_dialog",
        "click .NB-category-split-btn": "show_split_dialog",
        "click .NB-category-bulk-btn": "bulk_categorize",
        "click .NB-merge-suggestion-apply": "apply_merge_suggestion",
        "click .NB-inline-action-confirm": "confirm_inline_action",
        "click .NB-inline-action-cancel": "cancel_inline_action",
        "keypress .NB-inline-action-input": "handle_inline_action_keypress",
        // Conversation history sidebar events
        "click .NB-archive-conversation-item": "handle_conversation_click",
        "click .NB-archive-new-conversation": "start_new_conversation",
        "click .NB-archive-sidebar-toggle": "toggle_sidebar",
        // Search events
        "input .NB-archive-search-input": "handle_search_input",
        "click .NB-archive-search-clear": "clear_search",
        "keydown .NB-archive-search-input": "handle_search_keydown",
        // Re-categorize event
        "click .NB-archive-item-recategorize": "recategorize_item"
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
        this.active_conversation = null;
        this.conversation_history = [];
        this.is_streaming = false;
        this.response_text = '';
        this.usage = null;
        this.active_query_id = null;
        this.tool_status = null;
        this.websocket_timeout = null;
        this.response_completed = false;
        // Category management state
        this.selected_categories = [];
        this.category_manager_open = false;
        this.merge_suggestions = [];
        this.uncategorized_count = 0;
        this.inline_action = null;  // Tracks current inline action: 'merge', 'rename', 'split'
        this.inline_action_data = null;  // Data for current inline action
        // Conversation history sidebar state
        this.past_conversations = [];
        this.conversations_loaded = false;
        this.conversations_loading = false;
        this.sidebar_collapsed = false;
        // Search state
        this.search_query = '';
        this.search_debounced = _.debounce(_.bind(this.perform_search, this), 300);

        this.fetch_initial_data();
    },

    fetch_initial_data: function () {
        var self = this;

        // Fetch suggestions, usage, conversations, and filters in parallel
        this.show_loading();

        var fetch_count = 4;
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

        // Fetch past conversations
        this.fetch_conversations(check_complete);
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

    fetch_conversations: function (callback) {
        var self = this;
        this.conversations_loading = true;

        this.model.make_request('/archive-assistant/conversations', {
            limit: 50,
            active_only: true
        }, function (data) {
            self.conversations_loading = false;
            self.conversations_loaded = true;
            if (data.code === 0) {
                self.past_conversations = data.conversations || [];
            }
            if (callback) callback();
        }, function () {
            self.conversations_loading = false;
            if (callback) callback();
        }, { request_type: 'GET' });
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
        if (this.search_query) {
            params.search = this.search_query;
        }

        this.model.make_request('/api/archive/list', params, function (data) {
            self.is_loading = false;
            self.hide_archive_loading();

            if (data.code === 0) {
                self.archives = self.archives.concat(data.archives || []);
                self.has_more = data.has_more || false;
                self.page++;
                self.render_archives();

                // Update sidebar filters when searching
                if (self.search_query && reset) {
                    self.update_sidebar_for_search_results();
                } else if (!self.search_query && reset) {
                    // Restore full sidebar when clearing search
                    self.restore_full_sidebar();
                }
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
        var $content = this.$('.NB-archive-browser-content');
        // Remove any existing end line
        $content.find('.NB-end-line').remove();
        // Add pulsing loading bar
        var $endline = $.make('div', { className: 'NB-end-line NB-load-line NB-short' });
        $content.append($endline);
    },

    hide_archive_loading: function () {
        var $content = this.$('.NB-archive-browser-content');
        $content.find('.NB-end-line.NB-load-line').remove();
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
                ])
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
        this.$('.NB-archive-browser-content').on('scroll', this.throttled_check_scroll);

        // Store view reference for WebSocket event lookup
        this.$el.data('view', this);

        return this;
    },

    render_assistant_tab: function () {
        var self = this;

        // Check localStorage for sidebar state
        try {
            this.sidebar_collapsed = localStorage.getItem('NB:archive_sidebar_collapsed') === 'true';
        } catch (e) {}

        // Build main chat area elements
        var main_elements = [];

        // Chat history
        main_elements.push($.make('div', { className: 'NB-archive-assistant-chat' }, [
            $.make('div', { className: 'NB-archive-assistant-messages' },
                this.render_conversation_messages()
            )
        ]));

        // Suggestions (only show if no conversation yet)
        if (this.conversation_history.length === 0 && this.suggestions.length > 0) {
            var suggestion_elements = _.map(this.suggestions.slice(0, 4), function (suggestion) {
                return $.make('div', { className: 'NB-archive-suggestion' }, suggestion);
            });

            main_elements.push($.make('div', { className: 'NB-archive-suggestions' }, [
                $.make('div', { className: 'NB-archive-suggestions-title' }, 'Suggested questions'),
                $.make('div', { className: 'NB-archive-suggestions-list' }, suggestion_elements)
            ]));
        }

        // Input area
        main_elements.push($.make('div', { className: 'NB-archive-assistant-input-wrapper' }, [
            $.make('div', { className: 'NB-archive-assistant-voice-button', title: 'Record voice question' }, [
                $.make('img', { src: '/media/img/icons/nouns/microphone.svg', className: 'NB-archive-assistant-voice-icon' })
            ]),
            $.make('input', {
                type: 'text',
                className: 'NB-archive-assistant-input',
                placeholder: 'Ask about your browsing history...'
            }),
            $.make('div', { className: 'NB-archive-assistant-send' })
        ]));

        // Return main area + sidebar (sidebar on right)
        var sidebar_elements = [];

        if (!this.sidebar_collapsed) {
            // Sidebar header with new conversation button and toggle
            sidebar_elements.push($.make('div', { className: 'NB-archive-sidebar-header' }, [
                $.make('div', { className: 'NB-archive-new-conversation' }, [
                    $.make('img', { src: '/media/img/icons/nouns/add.svg', className: 'NB-new-chat-icon' }),
                    'New Chat'
                ]),
                $.make('div', {
                    className: 'NB-archive-sidebar-toggle',
                    title: 'Hide history'
                })
            ]));
            // Conversation list
            sidebar_elements.push($.make('div', { className: 'NB-archive-conversation-list' },
                this.render_conversation_list_items()
            ));
        }

        return [
            // Main chat area (with floating toggle when collapsed)
            $.make('div', { className: 'NB-archive-assistant-main' }, [
                this.sidebar_collapsed ? $.make('div', {
                    className: 'NB-archive-sidebar-toggle NB-collapsed',
                    title: 'Show history'
                }) : '',
                main_elements
            ].flat().filter(Boolean)),

            // Conversation Sidebar (on right)
            $.make('div', {
                className: 'NB-archive-conversation-sidebar' + (this.sidebar_collapsed ? ' NB-collapsed' : '')
            }, sidebar_elements)
        ];
    },

    render_conversation_list_items: function () {
        var self = this;

        if (this.conversations_loading) {
            return $.make('div', { className: 'NB-archive-conversations-loading' }, [
                $.make('div', { className: 'NB-loading NB-active' })
            ]);
        }

        if (this.past_conversations.length === 0) {
            return $.make('div', { className: 'NB-archive-conversations-empty' },
                'No past conversations');
        }

        return _.map(this.past_conversations, function (conv) {
            var is_active = self.active_conversation === conv.id;
            var date_str = self.format_relative_date(new Date(conv.last_activity));

            return $.make('div', {
                className: 'NB-archive-conversation-item' + (is_active ? ' NB-active' : ''),
                'data-conversation-id': conv.id
            }, [
                $.make('div', { className: 'NB-archive-conversation-title' },
                    conv.title || 'New Conversation'),
                $.make('div', { className: 'NB-archive-conversation-date' }, date_str)
            ]);
        });
    },

    format_relative_date: function (date) {
        if (!date || isNaN(date.getTime())) return '';

        var now = new Date();
        var diff = now - date;
        var seconds = Math.floor(diff / 1000);
        var minutes = Math.floor(seconds / 60);
        var hours = Math.floor(minutes / 60);
        var days = Math.floor(hours / 24);

        if (days > 7) {
            return date.toLocaleDateString();
        } else if (days > 0) {
            return days === 1 ? 'Yesterday' : days + ' days ago';
        } else if (hours > 0) {
            return hours === 1 ? '1 hour ago' : hours + ' hours ago';
        } else if (minutes > 0) {
            return minutes === 1 ? '1 minute ago' : minutes + ' minutes ago';
        } else {
            return 'Just now';
        }
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
                var message_class = 'NB-archive-assistant-message' + (is_user ? ' NB-user' : ' NB-assistant');
                if (!is_user && message.truncated) {
                    message_class += ' NB-archive-assistant-premium-only';
                }
                var $message = $.make('div', {
                    className: message_class
                }, [
                    $.make('div', { className: 'NB-archive-message-content' },
                        is_user ? message.content : self.markdown_to_html(message.content))
                ]);

                // Add fade and upgrade notice for truncated messages
                if (!is_user && message.truncated) {
                    $message.append($.make('div', { className: 'NB-archive-assistant-premium-fade' }));
                    $message.append($.make('div', { className: 'NB-archive-assistant-premium-notice' }, [
                        'Full Archive Assistant responses are a ',
                        $.make('a', { href: '#', className: 'NB-splash-link NB-premium-link' }, 'premium archive feature'),
                        '.'
                    ]));
                }

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

        // Search bar wrapper for inside filters
        var search_wrapper_class = 'NB-archive-search-wrapper';
        if (this.search_query) {
            search_wrapper_class += ' NB-has-query';
        }
        var search_element = $.make('div', { className: 'NB-archive-search-container' }, [
            $.make('div', { className: search_wrapper_class }, [
                $.make('div', { className: 'NB-archive-search-icon' }),
                $.make('input', {
                    type: 'text',
                    className: 'NB-archive-search-input',
                    placeholder: 'Search archives...',
                    value: this.search_query || ''
                }),
                $.make('div', {
                    className: 'NB-archive-search-clear',
                    title: 'Clear search'
                })
            ])
        ]);

        // Filters sidebar with search at top
        elements.push($.make('div', { className: 'NB-archive-filters' }, [
            // Search bar at top of filters
            search_element,
            // Categories with manage button
            $.make('div', { className: 'NB-archive-filter-section' }, [
                $.make('div', { className: 'NB-archive-filter-header' }, [
                    $.make('div', { className: 'NB-archive-filter-title' }, 'Categories'),
                    $.make('div', { className: 'NB-archive-manage-categories', title: 'Manage Categories' }, [
                        $.make('img', { src: '/media/img/icons/nouns/settings.svg', className: 'NB-manage-icon' })
                    ])
                ]),
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
            $.make('div', { className: 'NB-archive-list' })
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
        var $content = this.$('.NB-archive-browser-content');

        // Remove any existing end line
        $content.find('.NB-end-line').remove();

        if (this.archives.length === 0 && !this.is_loading) {
            $list.html($.make('div', { className: 'NB-archive-empty' }, [
                $.make('img', { src: '/media/img/icons/nouns/archive.svg', className: 'NB-archive-empty-icon' }),
                $.make('div', { className: 'NB-archive-empty-title' }, 'No archived pages yet'),
                $.make('div', { className: 'NB-archive-empty-subtitle' },
                    'Install the NewsBlur Archive browser extension to start building your browsing history.')
            ]));
            return;
        }

        var items = _.map(this.archives, function (archive) {
            return self.render_archive_item(archive);
        });

        $list.html(items);

        // Add end line with fleuron if no more archives, otherwise nothing (loading bar added separately)
        if (!this.has_more && this.archives.length > 0) {
            var $end_line = $.make('div', { className: 'NB-end-line' }, [
                $.make('div', { className: 'NB-fleuron' })
            ]);
            $content.append($end_line);
        }
    },

    get_favicon_url: function (archive) {
        // Fallback chain: favicon_url -> NewsBlur feed icon -> Google Favicon API
        if (archive.favicon_url) return archive.favicon_url;
        if (archive.matched_feed_id) return '/rss_feeds/icon/' + archive.matched_feed_id;
        if (archive.domain) return 'https://www.google.com/s2/favicons?domain=' + archive.domain + '&sz=32';
        return null;
    },

    render_archive_item: function (archive) {
        var date = archive.archived_date ? new Date(archive.archived_date) : null;
        var date_str = date ? this.format_relative_date(date) : '';

        var categories = archive.ai_categories || [];
        var categories_html = _.map(categories.slice(0, 2), function (cat) {
            return $.make('span', { className: 'NB-archive-item-category' }, cat);
        });
        // Re-categorize button (shown on hover, next to categories)
        categories_html.push($.make('div', {
            className: 'NB-archive-item-recategorize',
            title: 'Re-categorize this article'
        }, '↻'));

        // Build stats display (word count only)
        var stats_items = [];
        if (archive.word_count_display) {
            stats_items.push($.make('span', { className: 'NB-archive-item-stat' }, [
                $.make('span', { className: 'NB-archive-stat-value' }, archive.word_count_display),
                ' words'
            ]));
        }
        if (archive.has_content === false) {
            stats_items.push($.make('span', { className: 'NB-archive-item-stat NB-no-content' }, 'No content'));
        }

        // Create NewsBlur badge if matched to a feed
        var newsblur_link = '';
        if (archive.matched_feed_id) {
            var link_attrs = {
                className: 'NB-archive-item-newsblur-link',
                'data-feed-id': archive.matched_feed_id,
                title: 'Open this story in NewsBlur'
            };
            if (archive.matched_story_hash) {
                link_attrs['data-story-hash'] = archive.matched_story_hash;
            }
            newsblur_link = $.make('div', link_attrs, [
                $.make('span', { className: 'NB-archive-newsblur-text' }, 'In NewsBlur'),
                $.make('img', { src: '/media/img/favicon_16.png', className: 'NB-archive-newsblur-icon' })
            ]);
        }

        // Build favicon with fallback chain
        var favicon_url = this.get_favicon_url(archive);
        var favicon_fallback = archive.domain ? 'https://www.google.com/s2/favicons?domain=' + archive.domain + '&sz=32' : null;
        var $favicon = favicon_url ?
            $.make('img', {
                src: favicon_url,
                className: 'NB-archive-item-favicon-img'
            }) :
            $.make('div', { className: 'NB-archive-item-favicon-placeholder' });

        // Add error handler to fall back to Google Favicon API
        if (favicon_url && favicon_fallback && favicon_url !== favicon_fallback) {
            $favicon.on('error', function () {
                this.onerror = null;
                this.src = favicon_fallback;
            });
        }

        // Build meta line: domain, author (if available), date
        var meta_items = [$.make('span', { className: 'NB-archive-item-domain' }, archive.domain || '')];
        if (archive.author) {
            meta_items.push($.make('span', { className: 'NB-archive-item-author' }, archive.author));
        }
        meta_items.push($.make('span', { className: 'NB-archive-item-date' }, date_str));

        // Title - use highlighted version if available
        var $title = $.make('div', { className: 'NB-archive-item-title' });
        if (archive.highlights && archive.highlights.title && archive.highlights.title.length > 0) {
            $title.html(archive.highlights.title[0]);
        } else {
            $title.text(archive.title || 'Untitled');
        }

        // Content preview - show highlighted content when searching, otherwise plain preview
        var $content_preview = null;
        if (archive.highlights && archive.highlights.content && archive.highlights.content.length > 0) {
            var highlighted_content = archive.highlights.content.join(' ... ');
            $content_preview = $.make('div', { className: 'NB-archive-item-content-preview NB-highlighted' });
            $content_preview.html(highlighted_content);
        } else if (archive.content_preview) {
            $content_preview = $.make('div', { className: 'NB-archive-item-content-preview' }, archive.content_preview);
        }

        var content_elements = [
            $title,
            $.make('div', { className: 'NB-archive-item-meta' }, meta_items),
            stats_items.length > 0 ? $.make('div', { className: 'NB-archive-item-stats' }, stats_items) : '',
            $.make('div', { className: 'NB-archive-item-categories' }, categories_html)
        ];

        if ($content_preview) {
            content_elements.push($content_preview);
        }

        return $.make('div', { className: 'NB-archive-item', 'data-id': archive.id }, [
            $.make('div', { className: 'NB-archive-item-favicon' }, [$favicon]),
            $.make('div', { className: 'NB-archive-item-content' }, content_elements),
            newsblur_link
        ]);
    },

    format_relative_date: function (date) {
        if (!date || isNaN(date.getTime())) return '';

        var now = new Date();
        var diff = now - date;

        // Handle future dates or invalid timestamps
        if (diff < 0) return date.toLocaleDateString();

        var minutes = Math.floor(diff / 60000);
        var hours = Math.floor(diff / 3600000);

        // Show relative only for < 24 hours
        if (minutes < 1) return 'Just now';
        if (minutes < 60) return minutes + 'm ago';
        if (hours < 24) return hours + 'h ago';

        // For >= 24 hours, show absolute date in user's locale
        return date.toLocaleDateString(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
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

    check_scroll: function () {
        if (this.active_tab !== 'browser') return;
        if (this.is_loading || !this.has_more) return;

        var $content = this.$('.NB-archive-browser-content');
        if (!$content.length) return;

        var container_height = $content.height();
        var scroll_top = $content.scrollTop();
        var scroll_height = $content[0].scrollHeight;

        if (scroll_height - (scroll_top + container_height) < 200) {
            this.fetch_archives(false);
        }
    },

    open_archive_item: function (e) {
        // Don't trigger if clicking the NewsBlur link directly
        if ($(e.target).closest('.NB-archive-item-newsblur-link').length) return;

        var $item = $(e.currentTarget);
        var id = $item.data('id');
        var archive = _.find(this.archives, function (a) { return a.id === id; });

        if (!archive) return;

        if (archive.matched_feed_id && NEWSBLUR.reader) {
            // Open in NewsBlur
            var options = { router: true };
            if (archive.matched_story_hash) {
                options.story_id = archive.matched_story_hash;
            }

            var feed = NEWSBLUR.assets.get_feed(archive.matched_feed_id);
            if (feed && !feed.get('temp')) {
                NEWSBLUR.reader.open_feed(archive.matched_feed_id, options);
            } else {
                // Not subscribed - use tryfeed view
                NEWSBLUR.reader.load_feed_in_tryfeed_view(archive.matched_feed_id, options);
            }
        } else if (archive.url) {
            // No NewsBlur match - open original URL
            window.open(archive.url, '_blank');
        }
    },

    recategorize_item: function (e) {
        e.stopPropagation();  // Prevent opening the archive
        var self = this;
        var $item = $(e.currentTarget).closest('.NB-archive-item');
        var id = $item.data('id');

        // Show pending state immediately
        $item.find('.NB-archive-item-categories').html(
            $.make('span', { className: 'NB-archive-item-category NB-pending' }, 'Re-categorizing...')
        );

        this.model.make_request('/api/archive/recategorize', {
            archive_ids: JSON.stringify([id])
        }, function (data) {
            if (data.code === 0) {
                // Categories will be updated when the task completes
                // For now, show a subtle indicator that it's processing
                $item.addClass('NB-recategorizing');
            }
        }, function () {
            // On error, restore original categories
            var archive = _.find(self.archives, function (a) { return a.id === id; });
            if (archive && archive.ai_categories) {
                var categories_html = _.map(archive.ai_categories.slice(0, 2), function (cat) {
                    return $.make('span', { className: 'NB-archive-item-category' }, cat);
                });
                $item.find('.NB-archive-item-categories').html(categories_html);
            }
        });
    },

    open_story_in_newsblur: function (e) {
        e.stopPropagation();  // Prevent opening the archive URL

        var $link = $(e.currentTarget);
        var feed_id = $link.data('feed-id');
        var story_hash = $link.data('story-hash');

        if (feed_id && NEWSBLUR.reader) {
            var options = { router: true };
            if (story_hash) {
                options.story_id = story_hash;
            }

            var feed = NEWSBLUR.assets.get_feed(feed_id);
            if (feed && !feed.get('temp')) {
                // User is subscribed - open directly
                NEWSBLUR.reader.open_feed(feed_id, options);
            } else {
                // Not subscribed - use tryfeed view
                NEWSBLUR.reader.load_feed_in_tryfeed_view(feed_id, options);
            }
        }
    },

    use_suggestion: function (e) {
        var $suggestion = $(e.currentTarget);
        var query = $suggestion.text();

        this.$('.NB-archive-assistant-input').val(query);
        this.submit_assistant_query();
    },

    start_voice_recording: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }

        var self = this;
        var $voice_button = this.$('.NB-archive-assistant-voice-button');
        var $input = this.$('.NB-archive-assistant-input');

        // Get or create recorder instance for this view
        if (!this.voice_recorder) {
            this.voice_recorder = new NEWSBLUR.VoiceRecorder({
                on_recording_start: function () {
                    $voice_button.addClass('NB-recording');
                    $input.attr('placeholder', 'Recording...');
                    $voice_button.attr('title', 'Stop recording');
                },
                on_recording_stop: function () {
                    $voice_button.removeClass('NB-recording');
                    $voice_button.addClass('NB-transcribing');
                    $voice_button.css('transform', '');
                    $input.attr('placeholder', 'Transcribing...');
                    $voice_button.attr('title', 'Transcribing audio');
                },
                on_recording_cancel: function () {
                    $voice_button.removeClass('NB-recording NB-transcribing');
                    $voice_button.css('transform', '');
                    $voice_button.attr('title', 'Record voice question');
                    $input.attr('placeholder', 'Ask about your browsing history...');
                },
                on_transcription_start: function () {
                    // Already showing transcribing state
                },
                on_transcription_complete: function (text) {
                    $voice_button.removeClass('NB-transcribing');
                    $voice_button.css('transform', '');
                    $voice_button.attr('title', 'Record voice question');
                    $input.attr('placeholder', 'Ask about your browsing history...');

                    // Set the transcribed text and submit the question automatically
                    $input.val(text);

                    // Auto-submit the question
                    _.delay(function () {
                        self.submit_assistant_query();
                    }, 100);
                },
                on_transcription_error: function (error) {
                    $voice_button.removeClass('NB-recording NB-transcribing');
                    $voice_button.css('transform', '');

                    // Check error type
                    var is_quota_error = error && (error.includes('limit') || error.includes('used all') || error.includes('reached'));
                    var is_permission_error = error && (error.includes('microphone') || error.includes('permission') || error.includes('denied') || error.includes('not found'));

                    if (is_quota_error) {
                        // Show quota error as assistant error message
                        $voice_button.attr('title', 'Record voice question');
                        $input.attr('placeholder', 'Ask about your browsing history...');
                        self.handle_assistant_error(error);
                    } else if (is_permission_error) {
                        // Show permission error with helpful tooltip and placeholder
                        $voice_button.attr('title', 'Microphone blocked - click the lock icon in your browser\'s address bar to enable');
                        $input.attr('placeholder', 'Enable microphone in browser settings to use voice input');
                    } else {
                        // Show other errors in placeholder temporarily
                        $voice_button.attr('title', 'Record voice question');
                        $input.attr('placeholder', error || 'Voice recording failed. Please try again.');
                        // Reset placeholder after 3 seconds
                        setTimeout(function () {
                            $input.attr('placeholder', 'Ask about your browsing history...');
                        }, 3000);
                    }
                },
                on_audio_level: function (level) {
                    // Scale button based on audio level (1.0 to 1.3)
                    var scale = 1 + (level * 0.3);
                    $voice_button.css('transform', 'scale(' + scale + ')');
                }
            });
        }

        // Toggle recording
        if (this.voice_recorder.is_recording) {
            this.voice_recorder.stop_recording();
        } else {
            this.voice_recorder.start_recording();
        }
    },

    // ==================
    // Conversation History Sidebar Methods
    // ==================

    handle_conversation_click: function (e) {
        var $item = $(e.currentTarget);
        var conversation_id = $item.data('conversation-id');

        if (conversation_id && conversation_id !== this.active_conversation) {
            this.load_conversation(conversation_id);
        }
    },

    load_conversation: function (conversation_id) {
        var self = this;

        // Clear current conversation state
        this.conversation_history = [];
        this.active_conversation = conversation_id;
        this.is_streaming = false;
        this.response_text = '';
        this.tool_status = null;

        // Show loading state
        this.render_assistant_messages();

        this.model.make_request('/archive-assistant/conversation/' + conversation_id, {}, function (data) {
            if (data.code === 0 && data.queries) {
                // Rebuild conversation history from queries
                _.each(data.queries, function (query) {
                    self.conversation_history.push({
                        role: 'user',
                        content: query.query_text
                    });
                    if (query.response) {
                        self.conversation_history.push({
                            role: 'assistant',
                            content: query.response
                        });
                    }
                });
            }
            self.render_assistant_messages();
            self.scroll_to_bottom();
            self.render_conversation_sidebar();
        }, function () {
            self.handle_assistant_error('Failed to load conversation');
        }, { request_type: 'GET' });
    },

    start_new_conversation: function () {
        this.active_conversation = null;
        this.conversation_history = [];
        this.is_streaming = false;
        this.response_text = '';
        this.tool_status = null;

        this.render_assistant_messages();
        this.render_conversation_sidebar();

        // Show suggestions again
        this.$('.NB-archive-suggestions').show();

        // Focus input
        this.$('.NB-archive-assistant-input').focus();
    },

    toggle_sidebar: function () {
        this.sidebar_collapsed = !this.sidebar_collapsed;

        // Persist preference
        try {
            localStorage.setItem('NB:archive_sidebar_collapsed', this.sidebar_collapsed);
        } catch (e) {}

        // Re-render the assistant tab to properly move toggle button
        var $tab = this.$('.NB-archive-assistant-tab');
        var new_content = this.render_assistant_tab();
        $tab.empty().append(new_content);

        // Re-render messages if we have conversation history
        if (this.conversation_history.length > 0) {
            this.render_assistant_messages();
        }
    },

    render_conversation_sidebar: function () {
        var $list = this.$('.NB-archive-conversation-list');
        $list.html(this.render_conversation_list_items());
    },

    // ==================
    // Assistant Query Methods
    // ==================

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

        // Refresh conversations list to update titles for new conversations
        if (this.conversation_history.length <= 2) {
            var self = this;
            this.fetch_conversations(function () {
                self.render_conversation_sidebar();
            });
        }
    },

    show_error: function (error_message) {
        NEWSBLUR.log(['Archive Assistant: Error', error_message]);
        this.handle_assistant_error(error_message);
    },

    handle_truncation: function (data) {
        NEWSBLUR.log(['Archive Assistant: Response truncated', data]);

        this.is_streaming = false;
        this.tool_status = null;
        this.active_query_id = null;
        this.clear_websocket_timeout();

        // Add truncated response to history with premium notice
        if (this.response_text) {
            this.conversation_history.push({
                role: 'assistant',
                content: this.response_text,
                truncated: true
            });
        }

        this.response_text = '';
        this.render_assistant_messages();
        this.scroll_to_bottom();
    },

    open_premium_modal: function (e) {
        e.preventDefault();
        NEWSBLUR.reader.open_feedchooser_modal({ 'premium_only': true });
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

        var new_items_added = [];

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
                new_items_added.push(archive);
            }
        });

        // Animate in new items if on browser tab
        if (this.active_tab === 'browser' && new_items_added.length > 0) {
            var $list = this.$('.NB-archive-list');
            if ($list.length) {
                // Prepend new items with animation class (in reverse order so newest is on top)
                _.each(new_items_added.reverse(), function (archive) {
                    var $item = self.render_archive_item(archive);
                    $item.addClass('NB-archive-item-entering');
                    $list.prepend($item);

                    // Remove animation class after animation completes (500ms)
                    setTimeout(function () {
                        $item.removeClass('NB-archive-item-entering');
                    }, 500);
                });
            } else {
                // If list doesn't exist yet, do full render
                this.render_archives();
            }
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

    handle_archive_categories: function (data) {
        var archive_id = data.archive_id;
        var categories = data.categories || [];

        if (!archive_id || categories.length === 0) return;

        NEWSBLUR.log(['Archive View: Received categories for', archive_id, categories]);

        // Update the archive in our local data
        var archive = _.find(this.archives, function (a) {
            return a.id === archive_id || a.archive_id === archive_id;
        });

        if (archive) {
            archive.ai_categories = categories;
        }

        // Find the DOM element and update categories with animation
        var $item = this.$('.NB-archive-item[data-id="' + archive_id + '"]');
        if ($item.length) {
            // Remove re-categorizing state if present
            $item.removeClass('NB-recategorizing');

            var $categories_container = $item.find('.NB-archive-item-categories');
            if ($categories_container.length) {
                // Create new category elements with animation class
                var categories_html = _.map(categories.slice(0, 2), function (cat) {
                    var $cat = $.make('span', { className: 'NB-archive-item-category NB-category-entering' }, cat);
                    return $cat;
                });

                // Clear and append new categories
                $categories_container.empty().append(categories_html);

                // Remove animation class after animation completes
                setTimeout(function () {
                    $categories_container.find('.NB-category-entering').removeClass('NB-category-entering');
                }, 300);
            }
        }

        // Update sidebar category counts
        this.update_sidebar_for_categories(categories);
    },

    update_sidebar_for_categories: function (categories) {
        var self = this;

        // Update category counts in sidebar
        _.each(categories, function (cat) {
            var existing = _.find(self.categories, function (c) { return c._id === cat; });
            if (existing) {
                existing.count++;
            } else {
                self.categories.push({ _id: cat, count: 1 });
            }
        });

        // Re-sort categories by count and re-render
        this.categories = _.sortBy(this.categories, function (c) { return -c.count; });
        this.$('.NB-archive-categories').html(this.render_category_filters());
    },

    update_sidebar_for_search_results: function () {
        // Save original sidebar data if not already saved
        if (!this.original_categories) {
            this.original_categories = this.categories.slice();
            this.original_domains = this.domains.slice();
        }

        // Extract categories and domains from current search results
        var categories_in_results = {};
        var domains_in_results = {};

        _.each(this.archives, function (archive) {
            // Count categories
            if (archive.ai_categories) {
                _.each(archive.ai_categories, function (cat) {
                    categories_in_results[cat] = (categories_in_results[cat] || 0) + 1;
                });
            }
            // Count domains
            if (archive.domain) {
                domains_in_results[archive.domain] = (domains_in_results[archive.domain] || 0) + 1;
            }
        });

        // Convert to arrays sorted by count
        this.categories = _.map(categories_in_results, function (count, name) {
            return { _id: name, count: count };
        });
        this.categories = _.sortBy(this.categories, function (c) { return -c.count; });

        this.domains = _.map(domains_in_results, function (count, name) {
            return { _id: name, count: count };
        });
        this.domains = _.sortBy(this.domains, function (d) { return -d.count; });

        // Re-render sidebar
        this.$('.NB-archive-categories').html(this.render_category_filters());
        this.$('.NB-archive-domains').html(this.render_domain_filters());
    },

    restore_full_sidebar: function () {
        // Restore original sidebar data if we have it
        if (this.original_categories) {
            this.categories = this.original_categories;
            this.original_categories = null;
        }
        if (this.original_domains) {
            this.domains = this.original_domains;
            this.original_domains = null;
        }

        // Re-render sidebar
        this.$('.NB-archive-categories').html(this.render_category_filters());
        this.$('.NB-archive-domains').html(this.render_domain_filters());
    },

    show_archive_notification: function (count) {
        // Log notification (could be enhanced to show a toast)
        NEWSBLUR.log(['Archive: ' + count + ' new page(s) archived in real-time']);
    },

    // ==========================
    // = Category Management =
    // ==========================

    open_category_manager: function (e) {
        if (e) e.stopPropagation();
        var self = this;

        this.category_manager_open = true;
        this.selected_categories = [];

        // Fetch merge suggestions
        this.fetch_merge_suggestions();

        // Count uncategorized
        this.model.make_request('/api/archive/categories/bulk-categorize', { limit: 0 }, function (data) {
            if (data.total_uncategorized !== undefined) {
                self.uncategorized_count = data.total_uncategorized;
            }
            self.render_category_manager();
        }, function () {
            self.render_category_manager();
        }, { method: 'POST' });
    },

    close_category_manager: function (e) {
        if (e) e.stopPropagation();
        this.category_manager_open = false;
        this.selected_categories = [];
        this.inline_action = null;
        this.inline_action_data = null;
        this.$('.NB-category-manager-overlay, .NB-category-manager-modal').remove();
    },

    fetch_merge_suggestions: function () {
        var self = this;
        this.model.make_request('/api/archive/categories/suggest-merges', {}, function (data) {
            if (data.code === 0) {
                self.merge_suggestions = data.suggestions || [];
                self.render_merge_suggestions();
            }
        }, function () {
            self.merge_suggestions = [];
        }, { request_type: 'GET' });
    },

    render_category_manager: function () {
        // Remove existing modal if any
        this.$('.NB-category-manager-overlay, .NB-category-manager-modal').remove();

        // Create overlay
        var $overlay = $.make('div', { className: 'NB-category-manager-overlay' });

        // Create modal
        var $modal = $.make('div', { className: 'NB-category-manager-modal' }, [
            // Header
            $.make('div', { className: 'NB-category-manager-header' }, [
                $.make('h3', 'Manage Categories'),
                $.make('div', { className: 'NB-category-manager-close' }, '×')
            ]),

            // Status message area (hidden by default)
            $.make('div', { className: 'NB-category-manager-status NB-hidden' }),

            // Inline action panel (hidden by default)
            $.make('div', { className: 'NB-category-manager-inline-action NB-hidden' }),

            // Actions bar
            $.make('div', { className: 'NB-category-manager-actions' }, [
                $.make('button', {
                    className: 'NB-category-merge-btn NB-button NB-disabled',
                    disabled: true
                }, 'Merge Selected'),
                $.make('button', {
                    className: 'NB-category-bulk-btn NB-button' + (this.uncategorized_count === 0 ? ' NB-disabled' : '')
                }, this.uncategorized_count > 0 ?
                    'Categorize ' + this.uncategorized_count + ' Uncategorized' :
                    'All Categorized')
            ]),

            // Merge suggestions section
            $.make('div', { className: 'NB-category-manager-suggestions' }, [
                $.make('div', { className: 'NB-category-manager-section-title' }, 'Suggested Merges'),
                $.make('div', { className: 'NB-merge-suggestions-list' },
                    this.render_merge_suggestions_content()
                )
            ]),

            // Category list
            $.make('div', { className: 'NB-category-manager-list-wrapper' }, [
                $.make('div', { className: 'NB-category-manager-section-title' },
                    'All Categories (' + this.categories.length + ')'),
                $.make('div', { className: 'NB-category-manager-list' },
                    this.render_category_list_for_management()
                )
            ])
        ]);

        this.$el.append($overlay).append($modal);
    },

    show_category_status: function (message, type) {
        // type: 'success', 'error', 'info'
        var $status = this.$('.NB-category-manager-status');
        $status.removeClass('NB-hidden NB-success NB-error NB-info')
            .addClass('NB-' + (type || 'info'))
            .text(message);

        // Auto-hide success messages after 3 seconds
        if (type === 'success') {
            var self = this;
            setTimeout(function () {
                self.hide_category_status();
            }, 3000);
        }
    },

    hide_category_status: function () {
        this.$('.NB-category-manager-status').addClass('NB-hidden').text('');
    },

    show_inline_action: function (action_type, data) {
        this.inline_action = action_type;
        this.inline_action_data = data;
        this.hide_category_status();

        var $panel = this.$('.NB-category-manager-inline-action');
        var content;

        if (action_type === 'merge') {
            content = $.make('div', { className: 'NB-inline-action-content' }, [
                $.make('span', { className: 'NB-inline-action-label' },
                    'Merge ' + data.categories.length + ' categories into:'),
                $.make('input', {
                    type: 'text',
                    className: 'NB-inline-action-input',
                    value: data.default_target || '',
                    placeholder: 'Target category name'
                }),
                $.make('div', { className: 'NB-inline-action-buttons' }, [
                    $.make('button', { className: 'NB-inline-action-confirm NB-button NB-primary' }, 'Merge'),
                    $.make('button', { className: 'NB-inline-action-cancel NB-button' }, 'Cancel')
                ])
            ]);
        } else if (action_type === 'rename') {
            content = $.make('div', { className: 'NB-inline-action-content' }, [
                $.make('span', { className: 'NB-inline-action-label' },
                    'Rename "' + data.old_name + '" to:'),
                $.make('input', {
                    type: 'text',
                    className: 'NB-inline-action-input',
                    value: data.old_name,
                    placeholder: 'New category name'
                }),
                $.make('div', { className: 'NB-inline-action-buttons' }, [
                    $.make('button', { className: 'NB-inline-action-confirm NB-button NB-primary' }, 'Rename'),
                    $.make('button', { className: 'NB-inline-action-cancel NB-button' }, 'Cancel')
                ])
            ]);
        } else if (action_type === 'split') {
            var suggestions_html = _.map(data.suggestions, function (s, i) {
                return $.make('div', { className: 'NB-split-suggestion-item' }, [
                    $.make('span', { className: 'NB-split-suggestion-num' }, (i + 1) + '.'),
                    $.make('span', { className: 'NB-split-suggestion-name' }, s.name),
                    $.make('span', { className: 'NB-split-suggestion-count' },
                        '(' + (s.items ? s.items.length : 0) + ' items)')
                ]);
            });

            content = $.make('div', { className: 'NB-inline-action-content NB-split-content' }, [
                $.make('div', { className: 'NB-inline-action-label' },
                    'Split "' + data.category + '" (' + data.total_stories + ' stories) into:'),
                $.make('div', { className: 'NB-split-suggestions' }, suggestions_html),
                $.make('div', { className: 'NB-inline-action-buttons' }, [
                    $.make('button', { className: 'NB-inline-action-confirm NB-button NB-primary' }, 'Apply Split'),
                    $.make('button', { className: 'NB-inline-action-cancel NB-button' }, 'Cancel')
                ])
            ]);
        }

        $panel.removeClass('NB-hidden').html(content);

        // Focus the input if there is one
        $panel.find('.NB-inline-action-input').focus().select();
    },

    hide_inline_action: function () {
        this.inline_action = null;
        this.inline_action_data = null;
        this.$('.NB-category-manager-inline-action').addClass('NB-hidden').html('');
    },

    handle_inline_action_keypress: function (e) {
        if (e.which === 13) {  // Enter key
            e.preventDefault();
            this.confirm_inline_action();
        } else if (e.which === 27) {  // Escape key
            e.preventDefault();
            this.cancel_inline_action();
        }
    },

    confirm_inline_action: function () {
        if (!this.inline_action) return;

        if (this.inline_action === 'merge') {
            this.execute_merge();
        } else if (this.inline_action === 'rename') {
            this.execute_rename();
        } else if (this.inline_action === 'split') {
            this.execute_split();
        }
    },

    cancel_inline_action: function () {
        this.hide_inline_action();
    },

    render_merge_suggestions_content: function () {
        if (this.merge_suggestions.length === 0) {
            return $.make('div', { className: 'NB-merge-suggestions-empty' }, 'No merge suggestions');
        }

        return _.map(this.merge_suggestions.slice(0, 5), function (suggestion) {
            return $.make('div', { className: 'NB-merge-suggestion' }, [
                $.make('div', { className: 'NB-merge-suggestion-categories' },
                    _.map(suggestion.categories, function (cat) {
                        var count = suggestion.counts ? suggestion.counts[cat] : '';
                        return $.make('span', { className: 'NB-merge-suggestion-pill' }, cat + (count ? ' (' + count + ')' : ''));
                    })
                ),
                $.make('span', { className: 'NB-merge-suggestion-arrow' }, '→'),
                $.make('span', { className: 'NB-merge-suggestion-target' }, suggestion.suggested_target),
                $.make('button', {
                    className: 'NB-merge-suggestion-apply NB-button',
                    'data-categories': JSON.stringify(suggestion.categories),
                    'data-target': suggestion.suggested_target
                }, 'Apply')
            ]);
        });
    },

    render_merge_suggestions: function () {
        var $list = this.$('.NB-merge-suggestions-list');
        if ($list.length) {
            $list.html(this.render_merge_suggestions_content());
        }
    },

    render_category_list_for_management: function () {
        var self = this;
        return _.map(this.categories, function (cat) {
            var is_selected = _.contains(self.selected_categories, cat._id);
            return $.make('div', {
                className: 'NB-category-item' + (is_selected ? ' NB-selected' : ''),
                'data-category': cat._id
            }, [
                $.make('input', {
                    type: 'checkbox',
                    className: 'NB-category-checkbox',
                    checked: is_selected
                }),
                $.make('span', { className: 'NB-category-name' }, cat._id),
                $.make('span', { className: 'NB-category-count' }, cat.count),
                $.make('div', { className: 'NB-category-actions' }, [
                    $.make('button', {
                        className: 'NB-category-rename-btn',
                        'data-category': cat._id,
                        title: 'Rename'
                    }, '✏️'),
                    $.make('button', {
                        className: 'NB-category-split-btn',
                        'data-category': cat._id,
                        title: 'Split with AI'
                    }, '✂️')
                ])
            ]);
        });
    },

    handle_category_selection: function (e) {
        var $checkbox = $(e.currentTarget);
        var $item = $checkbox.closest('.NB-category-item');
        var category = $item.data('category');

        if ($checkbox.is(':checked')) {
            if (!_.contains(this.selected_categories, category)) {
                this.selected_categories.push(category);
            }
            $item.addClass('NB-selected');
        } else {
            this.selected_categories = _.without(this.selected_categories, category);
            $item.removeClass('NB-selected');
        }

        // Enable/disable merge button based on selection
        var $merge_btn = this.$('.NB-category-merge-btn');
        if (this.selected_categories.length >= 2) {
            $merge_btn.removeClass('NB-disabled').prop('disabled', false);
        } else {
            $merge_btn.addClass('NB-disabled').prop('disabled', true);
        }
    },

    merge_selected_categories: function (e) {
        if (e) e.stopPropagation();

        if (this.selected_categories.length < 2) {
            return;
        }

        // Show inline action panel for merge
        this.show_inline_action('merge', {
            categories: this.selected_categories.slice(),
            default_target: this.selected_categories[0]
        });
    },

    execute_merge: function () {
        var self = this;
        var data = this.inline_action_data;
        var target = this.$('.NB-inline-action-input').val().trim();

        if (!target) {
            this.show_category_status('Please enter a target category name', 'error');
            return;
        }

        // Disable buttons during request
        this.$('.NB-inline-action-confirm').prop('disabled', true).text('Merging...');

        this.model.make_request('/api/archive/categories/merge', {
            source_categories: JSON.stringify(data.categories),
            target_category: target
        }, function (response) {
            if (response.code === 0) {
                NEWSBLUR.log(['Merged', response.merged_count, 'stories into', target]);
                self.hide_inline_action();
                self.show_category_status('Merged ' + response.merged_count + ' stories into "' + target + '"', 'success');
                // Refresh categories
                self.fetch_filters(function () {
                    self.selected_categories = [];
                    self.render_category_manager();
                    // Also refresh the main category list
                    self.$('.NB-archive-categories').html(self.render_category_filters());
                });
            } else {
                self.show_category_status('Error: ' + (response.message || 'Unknown error'), 'error');
                self.$('.NB-inline-action-confirm').prop('disabled', false).text('Merge');
            }
        }, function () {
            self.show_category_status('Failed to merge categories', 'error');
            self.$('.NB-inline-action-confirm').prop('disabled', false).text('Merge');
        }, { method: 'POST' });
    },

    apply_merge_suggestion: function (e) {
        e.stopPropagation();
        var self = this;
        var $btn = $(e.currentTarget);
        var categories = JSON.parse($btn.data('categories'));
        var target = $btn.data('target');

        $btn.text('Merging...').prop('disabled', true);

        this.model.make_request('/api/archive/categories/merge', {
            source_categories: JSON.stringify(categories),
            target_category: target
        }, function (data) {
            if (data.code === 0) {
                NEWSBLUR.log(['Merged', data.merged_count, 'stories into', target]);
                self.show_category_status('Merged ' + data.merged_count + ' stories into "' + target + '"', 'success');
                // Refresh everything
                self.fetch_filters(function () {
                    self.fetch_merge_suggestions();
                    self.render_category_manager();
                    self.$('.NB-archive-categories').html(self.render_category_filters());
                });
            } else {
                $btn.text('Apply').prop('disabled', false);
                self.show_category_status('Error: ' + (data.message || 'Unknown error'), 'error');
            }
        }, function () {
            $btn.text('Apply').prop('disabled', false);
            self.show_category_status('Failed to merge categories', 'error');
        }, { method: 'POST' });
    },

    show_rename_dialog: function (e) {
        e.stopPropagation();
        var $btn = $(e.currentTarget);
        var old_name = $btn.data('category');

        // Show inline action panel for rename
        this.show_inline_action('rename', {
            old_name: old_name
        });
    },

    execute_rename: function () {
        var self = this;
        var data = this.inline_action_data;
        var new_name = this.$('.NB-inline-action-input').val().trim();

        if (!new_name) {
            this.show_category_status('Please enter a new category name', 'error');
            return;
        }

        if (new_name === data.old_name) {
            this.hide_inline_action();
            return;
        }

        // Disable buttons during request
        this.$('.NB-inline-action-confirm').prop('disabled', true).text('Renaming...');

        this.model.make_request('/api/archive/categories/rename', {
            old_name: data.old_name,
            new_name: new_name
        }, function (response) {
            if (response.code === 0) {
                NEWSBLUR.log(['Renamed', response.renamed_count, 'stories from', data.old_name, 'to', new_name]);
                self.hide_inline_action();
                self.show_category_status('Renamed ' + response.renamed_count + ' stories to "' + new_name + '"', 'success');
                // Refresh categories
                self.fetch_filters(function () {
                    self.render_category_manager();
                    self.$('.NB-archive-categories').html(self.render_category_filters());
                });
            } else {
                self.show_category_status('Error: ' + (response.message || 'Unknown error'), 'error');
                self.$('.NB-inline-action-confirm').prop('disabled', false).text('Rename');
            }
        }, function () {
            self.show_category_status('Failed to rename category', 'error');
            self.$('.NB-inline-action-confirm').prop('disabled', false).text('Rename');
        }, { method: 'POST' });
    },

    show_split_dialog: function (e) {
        e.stopPropagation();
        var self = this;
        var $btn = $(e.currentTarget);
        var category = $btn.data('category');

        // Show loading state
        $btn.text('⏳').prop('disabled', true);
        this.show_category_status('Getting AI suggestions for "' + category + '"...', 'info');

        // Get AI suggestions for split
        this.model.make_request('/api/archive/categories/split', {
            category: category,
            action: 'suggest'
        }, function (data) {
            $btn.text('✂️').prop('disabled', false);
            self.hide_category_status();

            if (data.code === 0 && data.suggestions && data.suggestions.length > 0) {
                // Show inline action panel for split
                self.show_inline_action('split', {
                    category: category,
                    suggestions: data.suggestions,
                    total_stories: data.total_stories
                });
            } else {
                self.show_category_status('No split suggestions available for this category', 'info');
            }
        }, function () {
            $btn.text('✂️').prop('disabled', false);
            self.show_category_status('Failed to get split suggestions', 'error');
        }, { method: 'POST' });
    },

    execute_split: function () {
        var self = this;

        // Disable buttons during request
        this.$('.NB-inline-action-confirm').prop('disabled', true).text('Applying...');
        this.show_category_status('Split functionality coming soon', 'info');

        // For now, just hide the panel after a short delay
        setTimeout(function () {
            self.hide_inline_action();
        }, 1500);
    },

    bulk_categorize: function (e) {
        if (e) e.stopPropagation();
        var self = this;
        var $btn = $(e.currentTarget);

        if (this.uncategorized_count === 0) return;

        $btn.text('Categorizing...').prop('disabled', true);
        this.show_category_status('Starting categorization...', 'info');

        this.model.make_request('/api/archive/categories/bulk-categorize', {
            limit: 100
        }, function (data) {
            if (data.code === 0) {
                var msg = 'Queued ' + data.queued_count + ' stories for categorization';
                if (data.total_uncategorized > data.queued_count) {
                    msg += ' (' + (data.total_uncategorized - data.queued_count) + ' remaining)';
                }
                NEWSBLUR.log([msg]);
                self.show_category_status(msg + '. Categories will appear as stories are processed.', 'success');

                // Update uncategorized count
                self.uncategorized_count = Math.max(0, self.uncategorized_count - data.queued_count);
                $btn.text(self.uncategorized_count > 0 ?
                    'Categorize ' + self.uncategorized_count + ' Uncategorized' :
                    'All Categorized');
                $btn.prop('disabled', self.uncategorized_count === 0);
                if (self.uncategorized_count === 0) {
                    $btn.addClass('NB-disabled');
                }
            } else {
                $btn.text('Categorize ' + self.uncategorized_count + ' Uncategorized').prop('disabled', false);
                self.show_category_status('Error: ' + (data.message || 'Unknown error'), 'error');
            }
        }, function () {
            $btn.text('Categorize ' + self.uncategorized_count + ' Uncategorized').prop('disabled', false);
            self.show_category_status('Failed to start categorization', 'error');
        }, { method: 'POST' });
    },

    // ===================
    // = Search Handlers =
    // ===================

    handle_search_input: function (e) {
        var query = $(e.currentTarget).val();
        this.search_debounced(query);
    },

    handle_search_keydown: function (e) {
        if (e.which === 27) {
            this.clear_search();
            e.preventDefault();
        }
    },

    perform_search: function (query) {
        this.search_query = query;
        this.fetch_archives(true);

        // Update clear button visibility
        if (query) {
            this.$('.NB-archive-search-wrapper').addClass('NB-has-query');
        } else {
            this.$('.NB-archive-search-wrapper').removeClass('NB-has-query');
        }
    },

    clear_search: function () {
        this.search_query = '';
        this.$('.NB-archive-search-input').val('');
        this.$('.NB-archive-search-wrapper').removeClass('NB-has-query');
        this.fetch_archives(true);
    },

    close: function () {
        this.clear_websocket_timeout();
        if (this.voice_recorder) {
            this.voice_recorder.cleanup();
        }
        this.$('.NB-archive-browser-content').off('scroll');
        this.remove();
    }

});
