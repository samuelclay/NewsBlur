NEWSBLUR.Views.StoryAskAiView = Backbone.View.extend({

    className: function () {
        return this.options.inline ? 'NB-story-ask-ai-inline' : 'NB-story-ask-ai-pane';
    },

    events: {
        "click .NB-story-ask-ai-close": "close_pane",
        "click .NB-story-ask-ai-followup-submit": "submit_followup_question",
        "keypress .NB-story-ask-ai-followup-input": "handle_followup_keypress"
    },

    initialize: function (options) {
        this.story = options.story;
        this.question_id = options.question_id;
        this.custom_question = options.custom_question;
        this.question_text = this.custom_question || this.get_question_text(this.question_id);
        this.inline = options.inline || false;
        this.story_hash = this.story.get('story_hash');
        this.streaming_started = false;
        this.response_text = '';  // Accumulate response for final formatting
        this.conversation_history = [];  // Track conversation for follow-ups

        // Send request immediately if we have a question (either preset or custom)
        if (this.question_id !== 'custom' || this.custom_question) {
            this.send_question(this.custom_question);
        }
    },

    render: function () {
        this.$el.html(this.template({
            story: this.story,
            question_text: this.question_text,
            question_id: this.question_id
        }));

        // Store view instance on DOM element for Socket.IO handler access
        this.$el.data('view', this);

        // Add thinking class and set up initial timeout (15s to wait for first response)
        if (this.inline) {
            this.$el.addClass('NB-thinking');
            this.initial_timeout = setTimeout(_.bind(this.handle_initial_timeout, this), 15000);
        }

        return this;
    },

    handle_initial_timeout: function () {
        // No response received within 15 seconds
        this.$el.removeClass('NB-thinking');
        this.$('.NB-story-ask-ai-loading').hide();
        this.$('.NB-story-ask-ai-error')
            .text('Request timed out. The AI service took too long to respond. Please try again.')
            .addClass('NB-active');
    },

    handle_streaming_timeout: function () {
        // No chunk received for 10 seconds during streaming
        this.$el.removeClass('NB-thinking');
        this.$('.NB-story-ask-ai-loading').hide();
        this.$('.NB-story-ask-ai-error')
            .text('Stream interrupted. No response received for 10 seconds.')
            .addClass('NB-active');
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
                <div class="NB-story-ask-ai-loading">\
                    <div class="NB-spinner"></div>\
                    <div class="NB-loading-text">Thinking...</div>\
                </div>\
                <div class="NB-story-ask-ai-error">\
                    <strong>Request timed out.</strong> The AI service took too long to respond. Please try again.\
                </div>\
                <div class="NB-story-ask-ai-answer" style="display: none;"></div>\
            </div>\
            <div class="NB-story-ask-ai-followup-wrapper" style="display: none;">\
                <input type="text" class="NB-story-ask-ai-followup-input" placeholder="Continue the discussion..." />\
                <div class="NB-button NB-story-ask-ai-followup-submit">Send</div>\
            </div>\
        </div>\
    '),

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
        return questions[question_id] || 'Unknown question';
    },

    close_pane: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
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
            question_id: this.question_id
        };

        if (custom_question) {
            params.custom_question = custom_question;
        }

        if (conversation_history && conversation_history.length > 0) {
            params.conversation_history = JSON.stringify(conversation_history);
        }

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
            console.log(['Ask AI request sent successfully', data]);
            // Response will come via Socket.IO
        } else {
            this.handle_response_error(data.message || 'Unknown error');
        }
    },

    handle_response_error: function (error) {
        console.log(['Ask AI request error', error]);
        this.$el.removeClass('NB-thinking');
        this.$('.NB-story-ask-ai-loading').hide();
        this.$('.NB-story-ask-ai-error').addClass('NB-active');
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
            // Bullet list: - item (but not if it's part of converted markdown)
            else if (/^[-]\s/.test(trimmed) && trimmed.indexOf('<') === -1) {
                if (!in_list || list_type !== 'ul') {
                    if (in_list) result.push('</' + list_type + '>');
                    result.push('<ul>');
                    in_list = true;
                    list_type = 'ul';
                }
                result.push('<li>' + trimmed.replace(/^[-]\s/, '') + '</li>');
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

        return result.join('\n');
    },

    append_chunk: function (chunk) {
        // Append streaming chunk to answer
        var $answer = this.$('.NB-story-ask-ai-answer');

        if (!this.streaming_started) {
            // First chunk - clear initial timeout, show answer, hide loading
            this.streaming_started = true;
            if (this.initial_timeout) {
                clearTimeout(this.initial_timeout);
                this.initial_timeout = null;
            }
            this.$el.removeClass('NB-thinking');
            this.$('.NB-story-ask-ai-loading').hide();
            this.$('.NB-story-ask-ai-error').removeClass('NB-active');
            $answer.show();
        }

        // Accumulate full response text
        this.response_text += chunk;

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
        // Mark as complete, clear debounce timeout
        console.log(['Ask AI response complete']);
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
            this.debounce_timeout = null;
        }
        if (this.initial_timeout) {
            clearTimeout(this.initial_timeout);
            this.initial_timeout = null;
        }

        // Add assistant's response to conversation history
        this.conversation_history.push({
            role: 'assistant',
            content: this.response_text
        });

        // Show and re-enable follow-up input
        this.$('.NB-story-ask-ai-followup-wrapper').show();
        this.$('.NB-story-ask-ai-followup-input').prop('disabled', false).focus();
    },

    show_error: function (error_message) {
        // Show error, clear all timeouts
        this.$el.removeClass('NB-thinking');
        this.$('.NB-story-ask-ai-loading').hide();
        this.$('.NB-story-ask-ai-error').text(error_message).addClass('NB-active');
        if (this.initial_timeout) {
            clearTimeout(this.initial_timeout);
            this.initial_timeout = null;
        }
        if (this.debounce_timeout) {
            clearTimeout(this.debounce_timeout);
            this.debounce_timeout = null;
        }
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

        // Hide follow-up input, show loading
        this.$('.NB-story-ask-ai-followup-wrapper').hide();
        this.$('.NB-story-ask-ai-followup-input').val('').prop('disabled', true);
        this.$el.addClass('NB-thinking');
        this.$('.NB-story-ask-ai-loading').show();

        // Set up initial timeout
        this.initial_timeout = setTimeout(_.bind(this.handle_initial_timeout, this), 15000);

        // Send follow-up with conversation history
        this.send_question(null, this.conversation_history);
    }

});
