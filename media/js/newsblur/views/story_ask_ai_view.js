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
    },

    render: function () {
        this.$el.html(this.template({
            story: this.story,
            question_text: this.question_text,
            question_id: this.question_id
        }));

        // Add thinking class and set up timeout
        if (this.inline) {
            this.$el.addClass('NB-thinking');
            this.timeout = setTimeout(_.bind(this.handle_timeout, this), 5000);
        }

        return this;
    },

    handle_timeout: function () {
        this.$el.removeClass('NB-thinking');
        this.$('.NB-story-ask-ai-loading').hide();
        this.$('.NB-story-ask-ai-error').addClass('NB-active');
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
        // Clear timeout if exists
        if (this.timeout) {
            clearTimeout(this.timeout);
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
        console.log(['Submit custom question', custom_question, this.story.get('story_title')]);
        // TODO: Make AJAX call to backend with custom question
    }

});
