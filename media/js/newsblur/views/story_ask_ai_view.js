NEWSBLUR.Views.StoryAskAiView = Backbone.View.extend({

    className: function () {
        return this.options.inline ? 'NB-story-ask-ai-inline' : 'NB-story-ask-ai-pane';
    },

    events: {
        "click .NB-story-ask-ai-close": "close_pane",
        "click .NB-story-ask-ai-reask-button": "toggle_reask_dropdown",
        "click .NB-story-ask-ai-send-button": "submit_followup_question",
        "click .NB-story-ask-ai-send-dropdown-trigger": "toggle_send_dropdown",
        "click .NB-story-ask-ai-voice-button": "start_voice_recording",
        "click .NB-story-ask-ai-finish-recording-button": "finish_voice_recording",
        "click .NB-story-ask-ai-finish-recording-dropdown-trigger": "toggle_finish_recording_dropdown",
        "keypress .NB-story-ask-ai-followup-input": "handle_followup_keypress",
        "input .NB-story-ask-ai-followup-input": "handle_input_change",
        "click .NB-story-ask-ai-usage-message a": "open_premium_modal",
        "click .NB-reask-dropdown .NB-model-option": "handle_reask_model_click",
        "click .NB-send-dropdown .NB-model-option": "handle_send_model_click",
        "click .NB-finish-recording-dropdown .NB-model-option": "handle_finish_recording_model_click",
        "click .NB-thinking-toggle-option": "handle_thinking_toggle"
    },

    initialize: function (options) {
        this.story = options.story;
        this.question_id = options.question_id;
        this.custom_question = options.custom_question;
        this.transcription_error = options.transcription_error;
        this.model = options.model || 'opus';  // Default to opus
        this.thinking = options.thinking || false;

        // If there's a transcription error, show "Audio not transcribed" as the question text
        if (this.transcription_error) {
            this.question_text = '<em>Audio not transcribed</em>';
        } else {
            this.question_text = this.custom_question || this.get_question_text(this.question_id);
        }

        this.inline = options.inline || false;
        this.story_hash = this.story.get('story_hash');
        this.streaming_started = false;
        this.response_text = '';  // Accumulate full visual display text
        this.current_response_text = '';  // Track only the current response for conversation history
        this.conversation_history = [];  // Track conversation for follow-ups
        this.active_request_id = null;
        this.original_question_id = this.question_id;  // Store for re-ask
        this.original_custom_question = this.custom_question;  // Store for re-ask
        this.response_model = this.model;  // Track which model produced current response
        this.response_thinking = this.thinking;  // Track thinking mode of current response
        this.is_comparison_response = false;  // Track if comparing multiple model responses
        this.section_models = [];  // Track models for each answer section (for pills)

        // If there's a transcription error, don't send a question - we'll display the error instead
        if (this.transcription_error) {
            // Don't send question, we'll show the error after render
        } else if (this.question_id !== 'custom' || this.custom_question) {
            // Send request immediately if we have a question (either preset or custom)
            this.send_question(this.custom_question);
        }
    },

    render: function () {
        this.$el.html(this.template({
            story: this.story,
            question_text: this.question_text,
            question_id: this.question_id
        }));

        // Populate model dropdowns from backend data
        var dropdown_html = this.build_model_dropdown_html();
        this.$('.NB-story-ask-ai-model-dropdown').html(dropdown_html);

        // Store view instance on DOM element for Socket.IO handler access
        this.$el.data('view', this);

        // Set the model dropdown to the current model and thinking toggle
        this.update_model_dropdown_selection();
        this.update_thinking_toggle_selection();

        // If there's a transcription error, display it instead of sending a question
        if (this.transcription_error) {
            this.$el.removeClass('NB-thinking');
            this.show_usage_message(this.transcription_error);
        } else if (this.inline) {
            // Add thinking class and set up initial timeout (15s to wait for first response)
            this.$el.addClass('NB-thinking');
            this.show_loading_pill();
            this.initial_timeout = setTimeout(_.bind(this.handle_initial_timeout, this), 15000);
        }

        return this;
    },

    show_loading_pill: function () {
        // Show model pill in answer area with pulsating loading state
        var $answer = this.$('.NB-story-ask-ai-answer');
        var pill_html = this.create_model_pill_html(this.model, true, true);  // visible=true, loading=true

        if ($answer.html() && $answer.html().trim()) {
            // Has existing content (follow-up) - append loading pill
            $answer.append(pill_html);
        } else {
            // Empty (initial question) - just show the pill
            $answer.html(pill_html);
        }
        $answer.show();
    },

    stop_loading_pill: function () {
        // Stop the pulsating animation on the model pill
        this.$('.NB-story-ask-ai-answer .NB-story-ask-ai-model-pill').removeClass('NB-loading');
    },

    show_loading_pill_error: function () {
        this.$('.NB-story-ask-ai-answer .NB-story-ask-ai-model-pill').addClass('NB-error').removeClass('NB-loading');
    },

    get_provider_display_name: function (provider) {
        var models = (NEWSBLUR.Globals && NEWSBLUR.Globals.ask_ai_models) || [];
        var match = _.find(models, function (m) { return m.vendor === provider; });
        if (match) return match.vendor_display;
        var names = {
            'anthropic': 'Anthropic',
            'openai': 'OpenAI',
            'google': 'Google',
            'xai': 'xAI'
        };
        return names[provider] || provider;
    },

    handle_initial_timeout: function () {
        // No response received within 15 seconds
        this.$el.removeClass('NB-thinking');
        this.show_loading_pill_error();

        var error_text = 'Request timed out. The AI service took too long to respond. Please try again.';

        // Track error separately so it can be cleared if response arrives late
        this.pending_error = error_text;
        this.render_with_pending_error();

        // Show followup wrapper so user can try again
        this.$('.NB-story-ask-ai-followup-wrapper').show();
    },

    handle_streaming_timeout: function () {
        // No chunk received for 10 seconds during streaming
        this.$el.removeClass('NB-thinking');
        this.show_loading_pill_error();

        var error_text = 'Stream interrupted. No response received for 10 seconds.';

        // Track error separately so it can be cleared if response arrives late
        this.pending_error = error_text;
        this.render_with_pending_error();

        // Show followup wrapper so user can try again
        this.$('.NB-story-ask-ai-followup-wrapper').show();
    },

    render_with_pending_error: function () {
        // Render response with pending error appended (but not baked into response_text)
        var $answer = this.$('.NB-story-ask-ai-answer');
        if (this.response_text) {
            var display_text = this.response_text + '\n\n**Error:** ' + this.pending_error;
            var html = this.markdown_to_html(display_text);
            $answer.html(html);
        } else {
            this.$('.NB-story-ask-ai-error')
                .text(this.pending_error)
                .addClass('NB-active');
        }
    },

    template: _.template('\
        <div class="NB-story-ask-ai-content">\
            <div class="NB-story-ask-ai-question-wrapper">\
                <div class="NB-story-ask-ai-question-border"></div>\
                <div class="NB-story-ask-ai-question">\
                    <div class="NB-story-ask-ai-close" role="button">\
                        <div class="NB-icon"></div>\
                    </div>\
                    <div class="NB-story-ask-ai-question-text"><%= question_text %></div>\
                </div>\
            </div>\
            <div class="NB-story-ask-ai-response">\
                <div class="NB-story-ask-ai-error">\
                    <strong>Request timed out.</strong> The AI service took too long to respond. Please try again.\
                </div>\
                <div class="NB-story-ask-ai-answer" style="display: none;"></div>\
                <div class="NB-story-ask-ai-usage-message" style="display: none;"></div>\
            </div>\
            <div class="NB-story-ask-ai-followup-wrapper" style="display: none;">\
                <div class="NB-story-ask-ai-input-row">\
                    <div class="NB-story-ask-ai-voice-button" title="Record voice question">\
                        <img src="/media/img/icons/nouns/microphone.svg" class="NB-story-ask-ai-voice-icon" />\
                    </div>\
                    <input type="text" class="NB-story-ask-ai-followup-input" placeholder="Follow up..." />\
                    <div class="NB-story-ask-ai-reask-menu">\
                        <div class="NB-button NB-story-ask-ai-reask-button" title="Re-ask original question">\
                            <span>Re-ask</span>\
                            <span class="NB-dropdown-arrow">▾</span>\
                        </div>\
                        <div class="NB-story-ask-ai-model-dropdown NB-reask-dropdown"></div>\
                    </div>\
                    <div class="NB-story-ask-ai-send-menu" style="display: none;">\
                        <div class="NB-button NB-story-ask-ai-send-button">Send</div>\
                        <div class="NB-story-ask-ai-send-dropdown-trigger" title="Choose model">\
                            <span class="NB-dropdown-arrow">▾</span>\
                        </div>\
                        <div class="NB-story-ask-ai-model-dropdown NB-send-dropdown"></div>\
                    </div>\
                    <div class="NB-story-ask-ai-finish-recording-menu" style="display: none;">\
                        <div class="NB-button NB-story-ask-ai-finish-recording-button">Finish recording...</div>\
                        <div class="NB-story-ask-ai-finish-recording-dropdown-trigger" title="Choose model">\
                            <span class="NB-dropdown-arrow">▾</span>\
                        </div>\
                        <div class="NB-story-ask-ai-model-dropdown NB-finish-recording-dropdown"></div>\
                    </div>\
                </div>\
            </div>\
        </div>\
    '),

    get_prompt_short_text: function (question_id, fallback) {
        var prompts = (NEWSBLUR.Globals && NEWSBLUR.Globals.ask_ai_prompts) || [];
        var match = _.find(prompts, function (prompt) {
            return prompt.id === question_id;
        });
        return (match && match.short_text) || fallback;
    },

    get_question_text: function (question_id) {
        var questions = {
            'sentence': 'Summarize in one sentence',
            'bullets': 'Summarize in bullet points',
            'paragraph': 'Summarize in a paragraph',
            'context': "What's the context and background?",
            'people': 'Identify key people and relationships',
            'arguments': 'What are the main arguments?',
            'factcheck': 'Fact check this story',
            'custom': 'Ask a custom question...'
        };
        return this.get_prompt_short_text(question_id, questions[question_id] || 'Unknown question');
    },

    generate_request_id: function () {
        if (window.crypto && window.crypto.randomUUID) {
            return window.crypto.randomUUID();
        }
        return 'askai-' + (Date.now().toString(36) + Math.random().toString(36).slice(2, 10));
    },

    remove: function () {
        // Override Backbone's remove to ensure cleanup
        if (this.voice_recorder) {
            this.voice_recorder.cleanup();
        }
        if (this.initial_timeout) {
            clearTimeout(this.initial_timeout);
        }
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
        }
        Backbone.View.prototype.remove.call(this);
    },

    close_pane: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        // Stop any active voice recording before closing
        if (this.voice_recorder) {
            this.voice_recorder.cleanup();
        }
        // Clear all timeouts
        if (this.initial_timeout) {
            clearTimeout(this.initial_timeout);
        }
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
        }
        // Close with reverse animation
        this.$el.addClass('NB-closing');
        _.delay(_.bind(function () {
            this.remove();
        }, this), 600);
    },

    send_question: function (custom_question, conversation_history) {
        var params = {
            story_hash: this.story_hash,
            question_id: this.question_id,
            model: this.model,
            thinking: this.thinking
        };

        // Track which model and thinking mode is producing this response
        this.response_model = this.model;
        this.response_thinking = this.thinking;

        var request_id = this.generate_request_id();
        this.active_request_id = request_id;
        params.request_id = request_id;

        if (custom_question) {
            params.custom_question = custom_question;
        }

        if (conversation_history && conversation_history.length > 0) {
            params.conversation_history = JSON.stringify(conversation_history);
        }

        // Hide usage message from previous request when starting a new request
        this.$('.NB-story-ask-ai-usage-message').hide();

        NEWSBLUR.assets.make_request(
            '/ask-ai/question',
            params,
            _.bind(this.handle_response_success, this),
            _.bind(this.handle_response_error, this),
            { timeout: 120000 }
        );
    },

    handle_response_success: function (data) {
        if (data.code === 1) {
            if (data.request_id && data.request_id !== this.active_request_id) {
                this.active_request_id = data.request_id;
            }
            return;
        }
        this.handle_response_error(data.message || 'Unknown error');
    },

    handle_response_error: function (error) {
        this.$el.removeClass('NB-thinking');
        this.show_loading_pill_error();

        // Extract error message from various error formats
        var error_message = error;
        if (typeof error === 'object') {
            if (error.message) {
                error_message = error.message;
            } else if (error.statusText) {
                // jQuery XHR object
                error_message = 'Server error: ' + error.statusText;
            } else if (error.responseText) {
                error_message = 'Server error';
            }
        }

        // Ensure error_message is a string
        if (typeof error_message !== 'string') {
            error_message = 'An error occurred. Please try again.';
        }

        // Check if this is a usage limit error
        var is_usage_limit = error_message.includes('limit') || error_message.includes('used all');

        if (is_usage_limit) {
            // Show as usage message instead of error
            this.show_usage_message(error_message);
            this.$('.NB-story-ask-ai-error').removeClass('NB-active');
        } else {
            // Show as error, hide usage message
            this.$('.NB-story-ask-ai-error').text(error_message).addClass('NB-active');
            this.$('.NB-story-ask-ai-usage-message').hide();
        }

        // Show followup wrapper so user can change model and re-ask
        this.$('.NB-story-ask-ai-followup-wrapper').show();
        this.update_model_dropdown_selection();

        if (this.initial_timeout) {
            clearTimeout(this.initial_timeout);
            this.initial_timeout = null;
        }
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
            this.debounce_timeout = null;
        }
    },

    markdown_to_html: function (text) {
        // Simple markdown to HTML converter for common patterns
        var html = text;

        // Escape HTML to prevent XSS
        html = html.replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');

        // Bold: **text** or __text__ (do bold first, before italic)
        html = html.replace(/\*\*([^\n]+?)\*\*/g, '<strong>$1</strong>');
        html = html.replace(/__([^\n]+?)__/g, '<strong>$1</strong>');

        // Italic: *text* or _text_ (avoid matching already-converted bold)
        html = html.replace(/\*([^\n*]+?)\*/g, '<em>$1</em>');
        html = html.replace(/_([^\n_]+?)_/g, '<em>$1</em>');

        // Horizontal rule: ---
        html = html.replace(/^---$/gm, '<hr>');

        // Split into lines for list and paragraph processing
        var lines = html.split('\n');
        var result = [];
        var in_list = false;
        var list_type = null;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var trimmed = line.trim();

            // Skip if it's an HR (already converted)
            if (trimmed === '<hr>') {
                if (in_list) {
                    result.push('</' + list_type + '>');
                    in_list = false;
                    list_type = null;
                }
                result.push('<hr>');
                continue;
            }

            // Headers: # H1, ## H2, ### H3, etc.
            var header_match = trimmed.match(/^(#{1,6})\s+(.+)$/);
            if (header_match) {
                if (in_list) {
                    result.push('</' + list_type + '>');
                    in_list = false;
                    list_type = null;
                }
                var level = header_match[1].length;
                var header_text = header_match[2];
                result.push('<h' + level + '>' + header_text + '</h' + level + '>');
                continue;
            }

            // Numbered list: 1. item, 2. item, etc.
            if (/^\d+\.\s/.test(trimmed)) {
                if (!in_list || list_type !== 'ol') {
                    if (in_list) result.push('</' + list_type + '>');
                    result.push('<ol>');
                    in_list = true;
                    list_type = 'ol';
                }
                result.push('<li>' + trimmed.replace(/^\d+\.\s/, '') + '</li>');
            }
            // Bullet list: - item, * item, or • item
            else if (/^[-*•]\s/.test(trimmed)) {
                if (!in_list || list_type !== 'ul') {
                    if (in_list) result.push('</' + list_type + '>');
                    result.push('<ul>');
                    in_list = true;
                    list_type = 'ul';
                }
                result.push('<li>' + trimmed.replace(/^[-*•]\s/, '') + '</li>');
            }
            // Regular line
            else {
                if (in_list) {
                    result.push('</' + list_type + '>');
                    in_list = false;
                    list_type = null;
                }
                if (trimmed) {
                    result.push('<p>' + line + '</p>');
                }
                // Skip empty lines
            }
        }

        // Close any open list
        if (in_list) {
            result.push('</' + list_type + '>');
        }

        var html = result.join('\n');

        // Inject model pills at section boundaries (hidden by default, shown when model differs from previous)
        if (this.section_models && this.section_models.length > 0) {
            var self = this;
            var section_index = 0;

            // Check if any models differ - if so, we'll show pills where changes occur
            var has_any_model_change = false;
            for (var i = 1; i < this.section_models.length; i++) {
                if (this.section_models[i] !== this.section_models[i - 1]) {
                    has_any_model_change = true;
                    break;
                }
            }

            // Add pill for first section at the beginning (always show to reinforce which model was used)
            if (this.section_models[0]) {
                html = this.create_model_pill_html(this.section_models[0], true) + '\n' + html;
                section_index = 1;
            }

            // Add pills after each <hr> for subsequent sections
            // Always show pill in comparison mode, otherwise only show if model differs
            html = html.replace(/<hr>/g, function () {
                var pill_html = '';
                if (self.section_models[section_index]) {
                    var current_model = self.section_models[section_index];
                    var prev_model = self.section_models[section_index - 1];
                    var is_different = current_model !== prev_model;
                    var should_show = self.is_comparison_response || (has_any_model_change && is_different);
                    pill_html = self.create_model_pill_html(current_model, should_show);
                    section_index++;
                }
                return '<hr>\n' + pill_html;
            });
        }

        return html;
    },

    append_chunk: function (chunk) {
        // Append streaming chunk to answer
        var $answer = this.$('.NB-story-ask-ai-answer');

        // Clear any pending error when new chunks arrive (response came through after timeout)
        if (this.pending_error) {
            this.pending_error = null;
            this.$('.NB-story-ask-ai-error').removeClass('NB-active');
        }

        if (!this.streaming_started) {
            // First chunk - clear initial timeout, show answer, hide loading
            this.streaming_started = true;
            this.current_response_text = '';  // Reset current response for new stream
            if (this.initial_timeout) {
                clearTimeout(this.initial_timeout);
                this.initial_timeout = null;
            }
            this.$el.removeClass('NB-thinking');
            this.stop_loading_pill();
            this.$('.NB-story-ask-ai-error').removeClass('NB-active');
            $answer.show();

            // Track this section's model for pill display
            this.section_models.push(this.response_model);
        }

        // Accumulate full visual display text
        this.response_text += chunk;
        // Also track just this response for conversation history
        this.current_response_text += chunk;

        // Convert markdown to HTML and update the answer
        var html = this.markdown_to_html(this.response_text);
        $answer.html(html);

        // Reset debounce timeout - if no chunk for 10s, show timeout error
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
        }
        this.debounce_timeout = setTimeout(_.bind(this.handle_streaming_timeout, this), 10000);
    },

    complete_response: function () {
        // Mark as complete, clear debounce timeout and any pending error
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
            this.debounce_timeout = null;
        }
        if (this.initial_timeout) {
            clearTimeout(this.initial_timeout);
            this.initial_timeout = null;
        }
        this.pending_error = null;

        // Add only the current response (not accumulated visual text) to conversation history
        this.conversation_history.push({
            role: 'assistant',
            content: this.current_response_text
        });

        // Show and re-enable follow-up input
        this.$('.NB-story-ask-ai-followup-wrapper').show();
        this.$('.NB-story-ask-ai-followup-input').prop('disabled', false);

        // Reset button visibility (input is empty, so show Re-ask, hide Send)
        this.$('.NB-story-ask-ai-reask-menu').show();
        this.$('.NB-story-ask-ai-send-menu').hide();

        // Update model dropdown and thinking toggle selection
        this.update_model_dropdown_selection();
        this.update_thinking_toggle_selection();
    },

    show_error: function (error_message) {
        // Show error, clear all timeouts, hide usage message
        this.$el.removeClass('NB-thinking');
        this.show_loading_pill_error();
        this.$('.NB-story-ask-ai-error').text(error_message).addClass('NB-active');
        this.$('.NB-story-ask-ai-usage-message').hide();
        if (this.initial_timeout) {
            clearTimeout(this.initial_timeout);
            this.initial_timeout = null;
        }
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
            this.debounce_timeout = null;
        }
    },

    show_usage_message: function (message) {
        // Display usage message below the answer
        // Convert "Upgrade to Premium/Premium Archive" text to a clickable link
        var html_message = _.escape(message);

        // Replace "Upgrade to Premium Archive" with a link (do this first, more specific)
        html_message = html_message.replace(
            /Upgrade to Premium Archive/g,
            '<a href="#" class="NB-story-ask-ai-upgrade-link">Upgrade to Premium Archive</a>'
        );

        // Replace "Upgrade to Premium" with a link (for free users)
        // Use negative lookahead to not match "Upgrade to Premium Archive"
        html_message = html_message.replace(
            /Upgrade to Premium(?! Archive)/g,
            '<a href="#" class="NB-story-ask-ai-upgrade-link">Upgrade to Premium</a>'
        );

        // Convert newlines to <br> tags
        html_message = html_message.replace(/\n/g, '<br>');

        this.$('.NB-story-ask-ai-usage-message').html(html_message).show();
    },

    open_premium_modal: function (e) {
        e.preventDefault();
        NEWSBLUR.reader.open_feedchooser_modal({ premium_only: true });
    },

    handle_followup_keypress: function (e) {
        if (e.which === 13) {  // Enter key
            e.preventDefault();
            this.submit_followup_question();
        }
    },

    submit_followup_question: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }

        var followup_text = this.$('.NB-story-ask-ai-followup-input').val();
        if (!followup_text || !followup_text.trim()) {
            return;
        }

        // Add user's follow-up to conversation history
        this.conversation_history.push({
            role: 'user',
            content: followup_text
        });

        // Add a visual separator for the follow-up to response_text
        this.response_text += '\n\n---\n\n**You:** ' + followup_text + '\n\n';

        // Render the updated text with markdown
        var $answer = this.$('.NB-story-ask-ai-answer');
        var html = this.markdown_to_html(this.response_text);
        $answer.html(html);

        // Don't reset response_text - we want to keep the conversation history
        this.streaming_started = false;

        // Hide follow-up input while processing
        this.$('.NB-story-ask-ai-followup-wrapper').hide();
        this.$('.NB-story-ask-ai-followup-input').val('').prop('disabled', true);
        this.$el.addClass('NB-thinking');
        this.show_loading_pill();

        // Set up initial timeout
        this.initial_timeout = setTimeout(_.bind(this.handle_initial_timeout, this), 15000);

        // Send follow-up with conversation history
        this.send_question(null, this.conversation_history);
    },

    start_voice_recording: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }

        var self = this;
        var $voice_button = this.$('.NB-story-ask-ai-voice-button');
        var $input = this.$('.NB-story-ask-ai-followup-input');

        // Get or create recorder instance for this view
        if (!this.voice_recorder) {
            this.voice_recorder = new NEWSBLUR.VoiceRecorder({
                on_recording_start: function () {
                    $voice_button.addClass('NB-recording');
                    $input.attr('placeholder', 'Recording...');
                    $voice_button.attr('title', 'Stop recording');
                    // Hide Re-ask and Send, show Finish Recording during recording
                    self.$('.NB-story-ask-ai-reask-menu').hide();
                    self.$('.NB-story-ask-ai-send-menu').hide();
                    self.$('.NB-story-ask-ai-finish-recording-menu').show();
                },
                on_recording_stop: function () {
                    $voice_button.removeClass('NB-recording');
                    $voice_button.addClass('NB-transcribing');
                    $input.attr('placeholder', 'Transcribing...');
                    $voice_button.attr('title', 'Transcribing audio');
                    // Hide finish recording menu during transcription
                    self.$('.NB-story-ask-ai-finish-recording-menu').hide();
                },
                on_recording_cancel: function () {
                    $voice_button.removeClass('NB-recording NB-transcribing');
                    $voice_button.attr('title', 'Record voice question');
                    $input.attr('placeholder', 'Follow up...');
                    // Reset button visibility
                    self.$('.NB-story-ask-ai-finish-recording-menu').hide();
                    if (!$input.val().trim()) {
                        self.$('.NB-story-ask-ai-send-menu').hide();
                        self.$('.NB-story-ask-ai-reask-menu').show();
                    } else {
                        self.$('.NB-story-ask-ai-send-menu').show();
                        self.$('.NB-story-ask-ai-reask-menu').hide();
                    }
                },
                on_transcription_start: function () {
                    // Already showing transcribing state
                },
                on_transcription_complete: function (text) {
                    $voice_button.removeClass('NB-transcribing');
                    $voice_button.attr('title', 'Record voice question');
                    $input.attr('placeholder', 'Follow up...');

                    // Set the transcribed text and submit the question automatically
                    $input.val(text);

                    // Auto-submit the question
                    _.delay(function () {
                        self.submit_followup_question();
                    }, 100);
                },
                on_transcription_error: function (error) {
                    $voice_button.removeClass('NB-recording NB-transcribing');
                    $voice_button.attr('title', 'Record voice question');

                    // Check if this is a quota/limit error
                    var is_quota_error = error && (error.includes('limit') || error.includes('used all') || error.includes('reached'));

                    if (is_quota_error) {
                        // Show quota error in the usage message box (blue box)
                        self.show_usage_message(error);
                        // Put a subtle placeholder in the input
                        $input.attr('placeholder', 'Quota exceeded');
                    } else {
                        // Show other errors as notifications
                        $input.attr('placeholder', 'Follow up...');
                        NEWSBLUR.reader.show_feed_hidden_story_title_indicator(error, false);
                    }
                    // Reset buttons if no text
                    self.$('.NB-story-ask-ai-finish-recording-menu').hide();
                    if (!$input.val().trim()) {
                        self.$('.NB-story-ask-ai-send-menu').hide();
                        self.$('.NB-story-ask-ai-reask-menu').show();
                    } else {
                        self.$('.NB-story-ask-ai-send-menu').show();
                        self.$('.NB-story-ask-ai-reask-menu').hide();
                    }
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

    handle_input_change: function (e) {
        var has_text = this.$(e.target).val().trim().length > 0;
        this.$('.NB-story-ask-ai-send-menu').toggle(has_text);
        this.$('.NB-story-ask-ai-reask-menu').toggle(!has_text);
    },

    toggle_send_dropdown: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        var $menu = this.$('.NB-story-ask-ai-send-menu');
        $menu.toggleClass('NB-dropdown-open');

        // Close on outside click
        if ($menu.hasClass('NB-dropdown-open')) {
            var self = this;
            setTimeout(function () {
                $(document).one('click', function () {
                    self.$('.NB-story-ask-ai-send-menu').removeClass('NB-dropdown-open');
                });
            }, 0);
        }
    },

    toggle_reask_dropdown: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        var $menu = this.$('.NB-story-ask-ai-reask-menu');
        $menu.toggleClass('NB-dropdown-open');

        // Close on outside click
        if ($menu.hasClass('NB-dropdown-open')) {
            var self = this;
            setTimeout(function () {
                $(document).one('click', function () {
                    self.$('.NB-story-ask-ai-reask-menu').removeClass('NB-dropdown-open');
                });
            }, 0);
        }
    },

    handle_reask_model_click: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        var selected_model = this.$(e.target).closest('.NB-model-option').data('model');

        // Close dropdown
        this.$('.NB-story-ask-ai-reask-menu').removeClass('NB-dropdown-open');

        // Only re-ask if model or thinking mode is different from current response
        if (selected_model === this.response_model && this.thinking === this.response_thinking) {
            return;
        }

        this.model = selected_model;
        NEWSBLUR.assets.preference('ask_ai_model', selected_model);
        this.update_model_dropdown_selection();
        this.reask_with_new_model();
    },

    handle_send_model_click: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        var selected_model = this.$(e.target).closest('.NB-model-option').data('model');
        this.model = selected_model;
        NEWSBLUR.assets.preference('ask_ai_model', selected_model);
        this.update_model_dropdown_selection();
        this.$('.NB-story-ask-ai-send-menu').removeClass('NB-dropdown-open');
        // User will click Send to actually send
    },

    update_model_dropdown_selection: function () {
        var current_model = this.model;
        this.$('.NB-model-option').each(function () {
            var $option = $(this);
            if ($option.data('model') === current_model) {
                $option.addClass('NB-selected');
            } else {
                $option.removeClass('NB-selected');
            }
        });
    },

    update_thinking_toggle_selection: function () {
        var thinking = this.thinking;
        this.$('.NB-thinking-toggle-option').each(function () {
            var $option = $(this);
            var is_thinking = $option.data('thinking') === true || $option.data('thinking') === 'true';
            if (is_thinking === thinking) {
                $option.addClass('NB-selected');
            } else {
                $option.removeClass('NB-selected');
            }
        });
    },

    handle_thinking_toggle: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        var $option = this.$(e.currentTarget);
        var thinking = $option.data('thinking') === true || $option.data('thinking') === 'true';

        // Update selected state
        this.$('.NB-thinking-toggle-option').removeClass('NB-selected');
        $option.addClass('NB-selected');

        // Save preference
        this.thinking = thinking;
        NEWSBLUR.assets.preference('ask_ai_thinking', thinking);

        // Re-ask if thinking mode changed from what produced the current response
        if (thinking !== this.response_thinking) {
            this.reask_with_new_model();
        }
    },

    get_model_display_name: function (model) {
        var models = (NEWSBLUR.Globals && NEWSBLUR.Globals.ask_ai_models) || [];
        var match = _.find(models, function (m) { return m.key === model; });
        return (match && match.display_name) || model;
    },

    get_model_provider: function (model) {
        var models = (NEWSBLUR.Globals && NEWSBLUR.Globals.ask_ai_models) || [];
        var match = _.find(models, function (m) { return m.key === model; });
        return (match && match.vendor) || 'unknown';
    },

    build_model_dropdown_html: function () {
        var models = (NEWSBLUR.Globals && NEWSBLUR.Globals.ask_ai_models) || [];
        var html = '';
        _.each(models, function (m) {
            html += '<div class="NB-model-option" data-model="' + _.escape(m.key) + '">' +
                    '<span class="NB-provider-pill NB-provider-' + _.escape(m.vendor) + '">' +
                    _.escape(m.vendor_display) + '</span> ' +
                    _.escape(m.display_name) + '</div>';
        });
        html += '<div class="NB-thinking-toggle-wrapper">' +
            '<div class="NB-thinking-toggle-segmented">' +
                '<div class="NB-thinking-toggle-option NB-thinking-fast NB-selected" data-thinking="false">' +
                    '<img src="/media/img/icons/nouns/lightning-bolt.svg" class="NB-thinking-toggle-icon" />' +
                    '<span>Fast</span>' +
                '</div>' +
                '<div class="NB-thinking-toggle-option NB-thinking-thinking" data-thinking="true">' +
                    '<img src="/media/img/icons/nouns/ai-brain.svg" class="NB-thinking-toggle-icon" />' +
                    '<span>Thinking</span>' +
                '</div>' +
            '</div>' +
        '</div>';
        return html;
    },

    create_model_pill_html: function (model, visible, loading) {
        var name = this.get_model_display_name(model);
        var provider = this.get_model_provider(model);
        var visible_class = visible ? ' NB-visible' : '';
        var loading_class = loading ? ' NB-loading' : '';
        return '<div class="NB-story-ask-ai-model-pill-wrapper' + visible_class + '"><div class="NB-story-ask-ai-model-pill NB-provider-' + provider + loading_class + '">' + name + '</div></div>';
    },

    replace_model_pill_markers: function (html) {
        // Replace {{MODEL_PILL:model_name}} markers with actual HTML pills
        var self = this;
        return html.replace(/(<p>)?\{\{MODEL_PILL:([^}]+)\}\}(<\/p>)?/g, function (match, p1, model) {
            return self.create_model_pill_html(model);
        });
    },

    reask_with_new_model: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }

        // Add separator after existing response (if any)
        var annotated_response = this.response_text ? this.response_text + '\n\n---\n\n' : '';
        if (this.response_text) {
            this.is_comparison_response = true;
        }

        // Update the displayed answer with separator
        var $answer = this.$('.NB-story-ask-ai-answer');
        if (annotated_response) {
            var html = this.markdown_to_html(annotated_response);
            $answer.html(html);
        }

        // Reset for new response but keep the annotated text
        this.question_id = this.original_question_id;
        this.custom_question = this.original_custom_question;
        this.response_text = annotated_response;
        this.current_response_text = '';
        this.conversation_history = [];
        this.streaming_started = false;

        // Keep answer visible while re-asking
        this.$('.NB-story-ask-ai-followup-wrapper').hide();
        this.$('.NB-story-ask-ai-error').removeClass('NB-active');
        this.$('.NB-story-ask-ai-usage-message').hide();
        this.$el.addClass('NB-thinking');
        this.show_loading_pill();

        // Set up initial timeout
        this.initial_timeout = setTimeout(_.bind(this.handle_initial_timeout, this), 15000);

        // Send the original question with the new model
        this.send_question(this.custom_question);
    },

    finish_voice_recording: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        // Stop recording (will trigger transcription)
        if (this.voice_recorder && this.voice_recorder.is_recording) {
            this.voice_recorder.stop_recording();
        }
    },

    toggle_finish_recording_dropdown: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        var $menu = this.$('.NB-story-ask-ai-finish-recording-menu');
        $menu.toggleClass('NB-dropdown-open');

        // Close on outside click
        if ($menu.hasClass('NB-dropdown-open')) {
            var self = this;
            setTimeout(function () {
                $(document).one('click', function () {
                    self.$('.NB-story-ask-ai-finish-recording-menu').removeClass('NB-dropdown-open');
                });
            }, 0);
        }
    },

    handle_finish_recording_model_click: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        var selected_model = this.$(e.target).closest('.NB-model-option').data('model');
        this.model = selected_model;
        NEWSBLUR.assets.preference('ask_ai_model', selected_model);
        this.update_model_dropdown_selection();
        this.$('.NB-story-ask-ai-finish-recording-menu').removeClass('NB-dropdown-open');
        // User can continue recording or click finish to send with this model
    },

    is_recording: function () {
        return this.voice_recorder && this.voice_recorder.is_recording;
    },

    cancel_recording: function () {
        if (this.voice_recorder && this.voice_recorder.is_recording) {
            this.voice_recorder.cancel_recording();
            return true;
        }
        return false;
    }

});
