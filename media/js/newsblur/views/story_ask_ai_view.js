NEWSBLUR.Views.StoryAskAiView = Backbone.View.extend({

    className: function () {
        return this.options.inline ? 'NB-story-ask-ai-inline' : 'NB-story-ask-ai-pane';
    },

    events: {
        "click .NB-story-ask-ai-close": "close_pane",
        "click .NB-story-ask-ai-submit": "submit_custom_question"
    },

    initialize: function (options) {
        this.story = options.story;
        this.question_id = options.question_id;
        this.question_text = this.get_question_text(this.question_id);
        this.inline = options.inline || false;
        this.story_hash = this.story.get('story_hash');
        this.streaming_started = false;
        this.response_text = '';  // Accumulate response for final formatting

        // Send request immediately for non-custom questions
        if (this.question_id !== 'custom') {
            this.send_question();
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
            <% if (question_id === "custom") { %>\
                <div class="NB-story-ask-ai-custom-input-wrapper">\
                    <input type="text" class="NB-story-ask-ai-custom-input" placeholder="Enter your question..." />\
                    <div class="NB-button NB-story-ask-ai-submit">Ask</div>\
                </div>\
            <% } %>\
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

    submit_custom_question: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var custom_question = this.$('.NB-story-ask-ai-custom-input').val();
        if (!custom_question || !custom_question.trim()) {
            return;
        }

        this.custom_question = custom_question;
        this.streaming_started = false;

        // Set up initial timeout for custom question
        this.initial_timeout = setTimeout(_.bind(this.handle_initial_timeout, this), 15000);

        this.send_question(custom_question);

        // Update UI to show processing
        this.$('.NB-story-ask-ai-custom-input').prop('disabled', true);
        this.$('.NB-story-ask-ai-submit').addClass('NB-disabled');
        this.$el.addClass('NB-thinking');
        this.$('.NB-story-ask-ai-loading').show();
    },

    send_question: function (custom_question) {
        var params = {
            story_hash: this.story_hash,
            question_id: this.question_id
        };

        if (custom_question) {
            params.custom_question = custom_question;
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

        // Append the chunk (line breaks will be preserved by CSS white-space: pre-wrap)
        $answer.append(document.createTextNode(chunk));

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
    }

});
