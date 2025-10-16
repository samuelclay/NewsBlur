NEWSBLUR.Views.StoryDetailView = Backbone.View.extend({

    tagName: 'li',

    className: 'NB-feed-story',

    FUDGE_CONTENT_HEIGHT_OVERAGE: 260,

    STORY_CONTENT_MAX_HEIGHT: 460, // ALSO CHANGE IN reader.css: .NB-story-content-wrapper-height-truncated

    events: {
        "click": "mark_read",
        "click .NB-feed-story-content a": "click_link_in_story",
        "click .NB-feed-story-share-container a": "click_link_in_story",
        "click .NB-feed-story-comments a": "click_link_in_story",
        "click .NB-feed-story-title": "click_link_in_story",
        "mouseenter .NB-feed-story-manage-icon": "mouseenter_manage_icon",
        "mouseleave .NB-feed-story-manage-icon": "mouseleave_manage_icon",
        "mouseenter .NB-sideoption-thirdparty": "mouseenter_thirdparty",
        "mouseleave .NB-sideoption-thirdparty": "mouseleave_thirdparty",
        "contextmenu .NB-feed-story-header": "show_manage_menu_rightclick",
        "mouseup .NB-story-content-wrapper": "mouseup_check_selection",
        "click .NB-feed-story-manage-icon": "show_manage_menu",
        "click .NB-feed-story-show-changes": "show_story_changes",
        "click .NB-feed-story-header-title": "open_feed",
        "click .NB-feed-story-tag": "save_classifier",
        "click .NB-feed-story-author": "save_classifier",
        "click .NB-feed-story-train": "open_story_trainer",
        "click .NB-feed-story-email": "maybe_open_email",
        "click .NB-feed-story-save": "toggle_starred",
        "click .NB-story-comments-label": "scroll_to_comments",
        "click .NB-story-content-expander": "expand_story",
        "click .NB-highlight-selection": "highlight_selected_text",
        "click .NB-unhighlight-selection": "unhighlight_selected_text",
        "click .NB-feed-story-discover": "toggle_feed_story_discover_dialog"
    },

    initialize: function () {
        _.bindAll(this, 'mouseleave', 'mouseenter', 'mouseup_check_selection', 'highlight_selected_text', 'unhighlight_selected_text');
        this.model.bind('change', this.toggle_classes, this);
        this.model.bind('change:read_status', this.toggle_read_status, this);
        this.model.bind('change:selected', this.toggle_selected, this);
        this.model.bind('change:starred', this.render_starred, this);
        this.model.bind('change:intelligence', this.render_header, this);
        this.model.bind('change:intelligence', this.toggle_intelligence, this);
        this.model.bind('change:shared', this.render_comments, this);
        this.model.bind('change:comments', this.render_comments, this);
        this.model.bind('change:story_content', this.render_story_content, this);
        if (this.collection) {
            this.collection.bind('render:intelligence', this.render_intelligence, this);
        }

        // Binding directly instead of using event delegation. Need for speed.
        // this.$el.bind('mouseenter', this.mouseenter);
        // this.$el.bind('mouseleave', this.mouseleave);

        if (!this.options.feed_floater &&
            !this.options.text_view &&
            !this.options.inline_story_title) {
            this.model.story_view = this;
        } else if (this.options.inline_story_title) {
            this.model.story_view = this;
            this.model.inline_story_detail_view = this;
        }
        if (!this.options.feed_floater) {
            this.model.latest_story_detail_view = this;
        }
    },

    // =============
    // = Rendering =
    // =============

    render: function () {
        var params = this.get_render_params();
        params['story_header'] = this.story_header_template(params);
        this.sideoptions_view = new NEWSBLUR.Views.StorySideoptionsView({
            model: this.model,
            el: this.el
        });
        this.save_view = this.sideoptions_view.save_view;
        this.share_view = this.sideoptions_view.share_view;

        params['story_save_view'] = this.sideoptions_view.save_view.render();
        params['story_share_view'] = this.sideoptions_view.share_view.template({
            story: this.model,
            social_services: NEWSBLUR.assets.social_services,
            profile: NEWSBLUR.assets.user_profile
        });
        this.$el.html(this.template(params));

        if (this.feed) {
            this.$el.toggleClass('NB-inverse', this.feed.is_light());
        }

        this.setup_classes();
        this.toggle_classes();
        this.toggle_read_status();
        this.toggle_intelligence();
        this.generate_gradients();
        this.render_comments();
        this.attach_handlers();
        // if (!this.model.get('image_urls') || (this.model.get('image_urls') && this.model.get('image_urls').length == 0)) {
        // }

        return this;
    },

    setElement: function ($el) {
        Backbone.View.prototype.setElement.call(this, $el);
        if (this.share_view) this.share_view.setElement($el);
    },

    render_starred_tags: function () {
        if (this.model.get('starred')) {
            this.save_view.toggle_feed_story_save_dialog();
        }
    },

    resize_starred_tags: function () {
        if (this.model.get('starred')) {
            this.save_view.reset_height({ immediate: true });
        }
    },

    attach_handlers: function () {
        this.watch_images_for_story_height();
        this.attach_syntax_highlighter_handler();
        this.attach_fitvid_handler();
        this.render_starred_tags();
        this.apply_starred_story_selections();
        this.watch_images_load();
        this.attach_custom_handler();
    },

    attach_custom_handler: function () {
        // Use this to create your own story_content handler.
        // Add this to your Manage > Account > Custom CSS:
        // 
        // NEWSBLUR.Views.StoryDetailView.prototype.attach_custom_handler = () => { console.log(['Story selected', NEWSBLUR.reader.active_story.get('story_title'), NEWSBLUR.reader.active_story.get('story_content').length + " bytes"]); }
    },

    watch_images_load: function () {
        var pane_width;
        if (this.options.inline_story_title) {
            pane_width = this.$el.width();
        }
        if (!pane_width) {
            pane_width = NEWSBLUR.reader.$s.$story_pane.width()
        }
        if (!pane_width) {
            pane_width = NEWSBLUR.reader.$s.$story_titles.width();
        }
        pane_width = pane_width - (28 + 2); // 28px to compensate for both margins
        var has_tables = this.$("table").length;

        this.$el.imagesLoaded(_.bind(function () {
            var largest = 0;
            var $largest;
            // console.log(["Images loaded", this.model.get('story_title').substr(0, 30), this.$("img")]);
            this.$("img").each(function () {
                // console.log(["Largest?", this.width, this.naturalWidth, this.height, this.naturalHeight, largest, pane_width, this.src]);
                if (this.width > 60 && this.width > largest) {
                    largest = this.width;
                    $largest = $(this);
                }
                $(this)
                    .removeClass('NB-large-image')
                    .removeClass('NB-large-image-widen')
                    .removeClass('NB-medium-image')
                    .removeClass('NB-medium-image-widen')
                    .removeClass('NB-small-image')
                    .removeClass('NB-small-image-widen');
                var auto_widen = true;
                if (pane_width >= 900) {
                    auto_widen = false;
                }

                if (has_tables) {
                    // Can't even calculate widths because with tables, nothing fits
                    $(this).addClass('NB-table-image');
                }
                if (this.naturalWidth >= pane_width && this.naturalHeight >= 50) {
                    $(this).addClass('NB-large-image');
                    if (auto_widen) {
                        $(this).addClass('NB-large-image-widen');
                    }
                } else if (this.naturalWidth >= 100 && this.naturalHeight >= 50) {
                    $(this).addClass('NB-medium-image');
                    if (auto_widen) {
                        $(this).addClass('NB-medium-image-widen');
                    }
                } else {
                    $(this).addClass('NB-small-image');
                    if (auto_widen) {
                        $(this).addClass('NB-small-image-widen');
                    }
                }
            });
            if ($largest) {
                // console.log(["Largest!", $largest, this.model.get('story_title').substr(0, 30), this.model, $largest.attr('src')]);
                this.model.story_title_view.found_largest_image($largest.attr('src'));
            }
        }, this));
    },

    render_header: function (model, value, options) {
        var params = this.get_render_params();
        this.$('.NB-feed-story-header-feed').remove();
        this.$('.NB-feed-story-header').replaceWith($(this.story_header_template(params)));
        this.generate_gradients();
    },

    get_render_params: function () {
        this.feed = NEWSBLUR.assets.get_feed(this.model.get('story_feed_id'));
        this.classifiers = NEWSBLUR.assets.classifiers[this.model.get('story_feed_id')];
        var show_feed_title = NEWSBLUR.reader.flags.river_view ||
            NEWSBLUR.reader.flags.social_view ||
            this.options.show_feed_title;
        return {
            story: this.model,
            feed: show_feed_title && this.feed,
            tag: _.first(this.model.get("story_tags")),
            title: this.make_story_title(),
            authors_score: this.classifiers &&
                this.classifiers.authors[this.model.get('story_authors')],
            tags_score: this.classifiers && this.classifiers.tags,
            options: this.options,
            truncatable: this.is_truncatable(),
            inline_story_title: this.options.inline_story_title,
            show_sideoption_email: NEWSBLUR.assets.preference("show_sideoption_email"),
            show_sideoption_train: NEWSBLUR.assets.preference("show_sideoption_train"),
            show_sideoption_save: NEWSBLUR.assets.preference("show_sideoption_save"),
            show_sideoption_share: NEWSBLUR.assets.preference("show_sideoption_share"),
            show_sideoption_related: NEWSBLUR.assets.preference("show_sideoption_related"),
        };
    },

    story_header_template: _.template('\
        <div class="NB-feed-story-header-feed">\
            <% if (feed) { %>\
                <div class="NB-feed-story-feed">\
                    <img class="feed_favicon" src="<%= $.favicon(feed) %>">\
                    <span class="NB-feed-story-header-title"><%= feed.get("feed_title") %></span>\
                </div>\
            <% } %>\
        </div>\
        <div class="NB-feed-story-header">\
            <div class="NB-feed-story-header-info">\
                <div class="NB-feed-story-title-container">\
                    <div class="NB-feed-story-sentiment"></div>\
                    <div class="NB-feed-story-manage-icon"></div>\
                    <a class="NB-feed-story-title" href="<%= story.get("story_permalink") %>"><%= title %></a>\
                </div>\
                <div class="NB-feed-story-date-line">\
                    <% if (story.get("has_modifications")) { %>\
                        <div class="NB-feed-story-show-changes">\
                            <span class="NB-feed-story-show-changes-text">\
                                <%= story.get("showing_diff") ? "Hide" : "Show" %> story changes\
                            </span>\
                            <span class="NB-middot">&middot;</span>\
                        </div>\
                    <% } %>\
                    <div class="NB-feed-story-date">\
                        <%= story.formatted_long_date() %>\
                    </div>\
                    <% if (story.story_authors()) { %>\
                        <div class="NB-feed-story-author-wrapper">\
                            <span class="NB-middot">&middot;</span>\
                            <span class="NB-feed-story-author <% if (authors_score) { %>NB-score-<%= authors_score %><% } %>">\
                                <%= story.story_authors() %>\
                            </span>\
                        </div>\
                    <% } %>\
                    <% if (story.get("story_tags", []).length) { %>\
                        <div class="NB-feed-story-tags">\
                            <span class="NB-middot">&middot;</span>\
                            <% _.each(story.get("story_tags"), function(tag) { %>\
                                <div class="NB-feed-story-tag <% if (tags_score && tags_score[tag]) { %>NB-score-<%= tags_score[tag] %><% } %>">\
                                    <%= tag %>\
                                </div>\
                            <% }) %>\
                        </div>\
                    <% } %>\
                </div>\
                <% if (story.get("starred_date")) { %>\
                    <div class="NB-feed-story-starred-date">\
                        <span class="NB-icon"></span>\
                        <span class="NB-title">Saved: </span>\
                        <span class="NB-date"><%= story.get("starred_date") %></span>\
                    </div >\
                <% } %>\
            </div>\
        </div>\
    '),

    template: _.template('\
        <%= story_header %>\
        <div class="NB-feed-story-shares-container"></div>\
        <div class="NB-story-content-container">\
            <div class="NB-story-content-wrapper <% if (truncatable) { %>NB-story-content-truncatable<% } %>">\
                <div class="NB-feed-story-content <% if (feed && feed.get("is_newsletter")) { %>NB-newsletter<% } %>">\
                    <% if (!options.skip_content) { %>\
                        <%= story.story_content() %>\
                    <% } %>\
                </div>\
                <div class="NB-story-content-expander" role="button">\
                    <div class="NB-story-content-expander-inner">\
                        <div class="NB-story-cutoff"></div>\
                        <div class="NB-story-content-expander-text">Read the whole story</div>\
                        <div class="NB-story-content-expander-pages"></div>\
                    </div>\
                </div>\
                <div class="NB-story-content-discover-wrapper"></div>\
            </div>\
            <div class="NB-feed-story-comments-container"></div>\
            <div class="NB-feed-story-sideoptions-container">\
                <% if (show_sideoption_email) { %>\
                    <div class="NB-sideoption NB-feed-story-email" role="button">\
                        <div class="NB-sideoption-title">Email</div>\
                        <div class="NB-sideoption-thirdparty NB-sideoption-icon NB-sideoption-icon-email">&nbsp;</div>\
                        <div class="NB-flex-break"></div>\
                        <div class="NB-sideoption-thirdparty-services">\
                            <div class="NB-sideoption-icons">\
                                <% _.each(NEWSBLUR.assets.third_party_sharing_services, function(label, key) { %>\
                                    <% if (NEWSBLUR.Preferences["story_share_"+key]) { %>\
                                        <div class="NB-sideoption-thirdparty NB-sideoption-thirdparty-<%= key %>" data-service-name="<%= key %>" data-service-label="<%= label %>" role="button">\
                                        </div>\
                                    <% } %>\
                                <% }) %>\
                            </div>\
                        </div>\
                    </div>\
                <% } %>\
                <% if (show_sideoption_train) { %>\
                    <div class="NB-sideoption NB-feed-story-train" role="button">\
                        <div class="NB-sideoption-title">Train</div>\
                        <div class="NB-sideoption-icon">&nbsp;</div>\
                    </div>\
                <% } %>\
                <% if (show_sideoption_save) { %>\
                    <div class="NB-sideoption NB-feed-story-save" role="button">\
                        <div class="NB-sideoption-title"><%= story.get("starred") ? "Saved" : "Save" %></div>\
                        <div class="NB-sideoption-icon">&nbsp;</div>\
                    </div>\
                    <%= story_save_view %>\
                    <% } %>\
                <% if (show_sideoption_share) { %>\
                    <div class="NB-sideoption NB-feed-story-share" role="button">\
                        <div class="NB-sideoption-title"><%= story.get("shared") ? "Shared" : "Share" %></div>\
                        <div class="NB-sideoption-icon">&nbsp;</div>\
                    </div>\
                    <%= story_share_view %>\
                <% } %>\
                <% if (show_sideoption_related) { %>\
                    <div class="NB-sideoption NB-feed-story-discover" role="button">\
                        <div class="NB-sideoption-title">Related</div>\
                        <div class="NB-sideoption-icon">&nbsp;</div>\
                    </div>\
                <% } %>\
            </div>\
        </div>\
        <% if (inline_story_title) { %>\
            <div class="NB-feed-story-header-feed">\
            </div>\
        <% } %>\
    '),

    generate_gradients: function () {
        var $header = this.$('.NB-feed-story-header-feed');

        if (!this.feed) return;

        var favicon_color = this.feed.get('favicon_color');
        if (favicon_color) {
            $header.css('backgroundColor', '#' + favicon_color);
            $header.css('background-image', 'none');
        }
        $header.css('background-image', NEWSBLUR.utils.generate_gradient(this.feed, 'webkit'));
        $header.css('background-image', NEWSBLUR.utils.generate_gradient(this.feed, 'moz'));
        // $header.css('borderTop',        NEWSBLUR.utils.generate_gradient(this.feed, 'border'));
        // $header.css('borderBottom',     NEWSBLUR.utils.generate_gradient(this.feed, 'border'));
        $header.css('textShadow', NEWSBLUR.utils.generate_shadow(this.feed));
    },

    is_truncatable: function () {
        return NEWSBLUR.assets.preference("truncate_story") == 'all' ||
            (NEWSBLUR.assets.preference("truncate_story") == 'social' &&
                NEWSBLUR.reader.flags['social_view']);
    },

    make_story_title: function (story) {
        story = story || this.model;
        var title = story.get('story_title');
        var classifiers = NEWSBLUR.assets.classifiers[story.get('story_feed_id')];
        var feed_titles = classifiers && classifiers.titles || [];

        _.each(feed_titles, function (score, title_classifier) {
            if (!title_classifier || title.toLowerCase().indexOf(title_classifier.toLowerCase()) != -1) {
                var pos = title.toLowerCase().indexOf(title_classifier.toLowerCase());
                title = title.substr(0, pos) + '<span class="NB-score-' + score + '">' + title.substr(pos, title_classifier.length) + '</span>' + title.substr(pos + title_classifier.length);
            }
        });

        return title;
    },

    render_comments: function () {
        var $original_comments = this.$('.NB-feed-story-comments-container,.NB-feed-story-comments');
        var $original_shares = this.$('.NB-feed-story-shares-container,.NB-feed-story-shares');

        if (this.model.get("comment_count") || this.model.get("share_count")) {
            var comments_view = new NEWSBLUR.Views.StoryCommentsView({ model: this.model });
            this.comments_view = comments_view.render();
            var $comments = this.comments_view.el;
            $original_comments.html($comments);
            var $shares = $('.NB-story-comments-shares-teaser-wrapper', $comments);
            $original_shares.replaceWith($shares);
        } else if ($original_comments.length) {
            $original_comments.replaceWith($.make('div', { className: 'NB-feed-story-comments-container' }));
            $original_shares.replaceWith($.make('div', { className: 'NB-feed-story-shares-container' }));
        }
    },

    render_story_content: function () {
        this.$(".NB-feed-story-show-changes-text").text((this.model.get('showing_diff') ? "Hide" : "Show") + " story changes");
        this.$(".NB-feed-story-content").html(this.model.story_content());

        this.attach_handlers();
    },

    destroy: function () {
        // console.log(["destroy story detail", this.model.get('story_title')]);
        clearTimeout(this.truncate_delay_function);
        this.images_to_load = null;
        this.model.unbind(null, null, this);
        if (this.collection) this.collection.unbind(null, null, this);
        // this.sideoptions_view.destroy();
        if (this.comments_view) this.comments_view.destroy();
        delete this.model.inline_story_detail_view;
        this.remove();
    },

    render_intelligence: function (options) {
        options = options || {};
        var score = this.model.score();
        var unread_view = NEWSBLUR.reader.get_unread_view_score();

        if (score >= unread_view) {
            this.$el.removeClass('NB-hidden');
            this.model.set('visible', true);
        } else {
            this.$el.addClass('NB-hidden');
            this.model.set('visible', false);
        }
    },

    // ============
    // = Bindings =
    // ============

    toggle_classes: function () {
        var changes = this.model.changedAttributes();
        var onlySelected = changes && _.all(_.keys(changes), function (change) {
            return _.contains(['selected', 'read', 'intelligence', 'visible'], change);
        });

        if (onlySelected) return;

        if (this.model.changedAttributes()) {
            // NEWSBLUR.log(["Story changed", this.model.changedAttributes(), this.model.previousAttributes()]);
        }

        this.setup_classes();
    },

    setup_classes: function () {
        var story = this.model;
        var unread_view = NEWSBLUR.reader.get_unread_view_score();

        this.$el.toggleClass('NB-river-story', NEWSBLUR.reader.flags.river_view ||
            NEWSBLUR.reader.flags.social_view);
        this.$el.toggleClass('NB-story-starred', !!story.get('starred'));
        this.$el.toggleClass('NB-story-shared', !!story.get('shared'));
        this.toggle_intelligence();
        this.render_intelligence();

        if (NEWSBLUR.assets.preference('show_tooltips')) {
            this.$('.NB-story-sentiment').tipsy({
                delayIn: 375,
                gravity: 's'
            });
            this.$('.NB-feed-story-show-changes').tipsy({
                delayIn: 375
            });
        }
    },

    toggle_read_status: function () {
        this.$el.toggleClass('read', !!this.model.get('read_status'));
    },

    toggle_intelligence: function () {
        var score = this.model.score();
        this.$el.removeClass('NB-story-negative NB-story-neutral NB-story-postiive')
            .addClass('NB-story-' + this.model.score_name(score));
    },

    toggle_selected: function (model, selected, options) {
        options = options || {};
        this.$el.toggleClass('NB-selected', !!this.model.get('selected'));
        NEWSBLUR.app.taskbar_info.hide_stories_error();

        if (selected && options.scroll_to_comments) {
            NEWSBLUR.app.story_list.scroll_to_selected_story(model, {
                scroll_offset: -50,
                scroll_to_comments: true
            });
        } else if (NEWSBLUR.assets.preference('feed_view_single_story')) {
            NEWSBLUR.app.story_list.scroll_to_selected_story(model, {
                'scroll_to_top': true
            });
        } else if (selected &&
            !options.selected_by_scrolling &&
            (NEWSBLUR.reader.story_view == 'feed' ||
                (NEWSBLUR.reader.story_view == 'page' &&
                    NEWSBLUR.reader.flags['page_view_showing_feed_view']))) {
            // NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
            NEWSBLUR.app.story_list.scroll_to_selected_story(model, options);
        }

        if (NEWSBLUR.reader.flags['feed_view_showing_story_view'] ||
            NEWSBLUR.reader.flags['temporary_story_view']) {
            NEWSBLUR.reader.switch_to_correct_view();
        }
    },

    // ============
    // = Expander =
    // ============

    truncate_story_height: function () {
        if (this._truncated) return;
        if (!this.is_truncatable()) return;

        if (NEWSBLUR.assets.preference('feed_view_single_story')) return;

        // console.log(["Checking truncate", this.$el, this.images_to_load, this.truncate_delay / 1000 + " sec delay"]);
        var $expander = this.$(".NB-story-content-expander");
        var $expander_cutoff = this.$(".NB-story-cutoff");
        var $wrapper = this.$(".NB-story-content-wrapper");
        var $content = this.$(".NB-feed-story-content");
        var max_height = parseInt($wrapper.css('maxHeight'), 10) || this.STORY_CONTENT_MAX_HEIGHT;
        var content_height = $content.outerHeight(true);

        if (content_height > max_height &&
            content_height < max_height + this.FUDGE_CONTENT_HEIGHT_OVERAGE) {
            // console.log(["Height over but within fudge", this.model.get('story_title').substr(0, 30), content_height, max_height]);
            $wrapper.addClass('NB-story-content-wrapper-height-fudged');
        } else if (content_height > max_height) {
            $expander.css('display', 'block');
            $expander_cutoff.css('display', 'block');
            $wrapper.removeClass('NB-story-content-wrapper-height-fudged');
            $wrapper.addClass('NB-story-content-wrapper-height-truncated');
            var pages = Math.round(content_height / max_height, true);
            var dots = _.map(_.range(pages), function () { return '&middot;'; }).join(' ');

            // console.log(["Height over, truncating...", this.model.get('story_title').substr(0, 30), content_height, max_height, pages]);
            this.$(".NB-story-content-expander-pages").html(dots);
            this._truncated = true;
        } else {
            // console.log(["Height under.", this.model.get('story_title').substr(0, 30), content_height, max_height]);
        }

        if (this.images_to_load > 0) {
            this.truncate_delay *= 1 + Math.random();
            clearTimeout(this.truncate_delay_function);
            this.truncate_delay_function = _.delay(_.bind(this.truncate_story_height, this), this.truncate_delay);
        }
    },

    watch_images_for_story_height: function () {
        this.model.on('change:images_loaded', _.bind(function () {
            this.resize_starred_tags();
        }, this));
        var is_truncatable = this.is_truncatable();

        // console.log(['truncatable', is_truncatable, this.images_to_load]);
        if (!is_truncatable) return;

        this.truncate_delay = 100;
        this.images_to_load = this.$('img').length;
        if (is_truncatable) this.truncate_story_height();
        this.$('img').on('load', _.bind(function () {
            this.images_to_load -= 1;
            if (is_truncatable) this.truncate_story_height();
            if (this.images_to_load <= 0) {
                this.model.set('images_loaded', true);
            } else {
                this.model.set('images_loaded', false);
            }
        }, this));
    },

    expand_story: function (options) {
        options = options || {};
        var $expander = this.$(".NB-story-content-expander");
        var $expander_cutoff = this.$(".NB-story-cutoff");
        var $wrapper = this.$(".NB-story-content-wrapper");
        var $content = this.$(".NB-feed-story-content");
        var max_height = parseInt($wrapper.css('maxHeight'), 10) || this.STORY_CONTENT_MAX_HEIGHT;
        var content_height = $content.outerHeight(true);
        var height_ratio = content_height / max_height;

        if (content_height < max_height) return;
        // console.log(["max height", max_height, content_height, content_height / max_height]);
        clearInterval(this._fetch_interval);
        this._fetch_interval = setInterval(function () {
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }, 250);

        $wrapper.animate({
            maxHeight: content_height
        }, {
            duration: options.instant ? 0 : Math.min(2 * 1000, parseInt(200 * height_ratio, 10)),
            easing: 'easeInOutQuart',
            complete: _.bind(function () {
                clearInterval(this._fetch_interval);
                NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                $wrapper.removeClass('NB-story-content-wrapper-height-truncated');
            }, this)
        });

        $expander.add($expander_cutoff).animate({
            bottom: -1 * $expander.outerHeight() - 76
        }, {
            duration: options.instant ? 0 : Math.min(2 * 1000, parseInt(200 * height_ratio, 10)),
            easing: 'easeInOutQuart'
        });

    },

    // ===========
    // = Actions =
    // ===========

    mark_read: function () {
        this.model.mark_read({ force: true });
    },

    preserve_classifier_color: function (classifier_type, value, score) {
        var $tag;
        this.$('.NB-feed-story-' + classifier_type).each(function () {
            if (_.string.trim($(this).text()) == value) {
                $tag = $(this);
                return false;
            }
        });
        $tag.removeClass('NB-score-now-1')
            .removeClass('NB-score-now--1')
            .removeClass('NB-score-now-0')
            .addClass('NB-score-now-' + score)
            .one('mouseleave', function () {
                // console.log(["leave", score]);
                $tag.removeClass('NB-score-now-' + score);
                _.delay(function () {
                    $tag.one('mouseenter', function () {
                        // console.log(["enter", score]);
                        $tag.removeClass('NB-score-now-' + score);
                    });
                }, 100);
            });
    },

    render_starred: function () {
        var story = this.model;
        var $sideoption_title = this.$('.NB-feed-story-save .NB-sideoption-title');

        if (story.get('starred')) {
            $sideoption_title.text('Saved');
        } else {
            $sideoption_title.text('Removed');
            $sideoption_title.one('mouseleave', function () {
                _.delay(function () {
                    if (!story.get('starred')) {
                        $sideoption_title.text('Save');
                    }
                }, 200);
            });
        }
    },

    attach_syntax_highlighter_handler: function () {
        _.delay(_.bind(function () {
            // hljs.configure({useBR: true}); // Don't use
            this.$('pre').each(function (i, e) {
                hljs.highlightBlock(e);
            });
        }, this), 100);
    },

    attach_fitvid_handler: function () {
        // Thanks to feedbin for the custom selector
        _.delay(_.bind(function () {
            this.$el.fitVids({
                customSelector: "iframe[src*='youtu.be'],iframe[src*='www.flickr.com'],iframe[src*='view.vzaar.com']"
            });
        }, this), 50);
    },

    // ==========
    // = Events =
    // ==========

    click_link_in_story: function (e) {
        if (NEWSBLUR.hotkeys.shift) return;
        var $target = $(e.currentTarget);

        e.preventDefault();
        e.stopPropagation();
        if (e.which >= 2) return;
        if (e.which == 1 && $('.NB-menu-manage-container:visible').length) return;

        var href = $target.attr('href');

        // Fix footnotes
        if (_.string.contains(href, "#")) {
            try {
                footnote_href = href.replace(/^.*?\#(.*?)$/, "\#$1")
                    .replace(':', "\\\:");
                var $footnote = $(footnote_href);
            } catch (err) {
                $footnote = [];
            }
            if ($footnote.length) {
                href = footnote_href;
                var offset = $(href).offset().top;
                var $scroll;
                if (_.contains(['list', 'grid', 'magazine'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
                    $scroll = NEWSBLUR.reader.$s.$story_titles;
                } else if (NEWSBLUR.reader.flags['temporary_story_view'] ||
                    NEWSBLUR.reader.story_view == 'text') {
                    $scroll = NEWSBLUR.reader.$s.$text_view;
                } else {
                    $scroll = NEWSBLUR.reader.$s.$feed_scroll;
                }
                offset += $scroll.scrollTop();
                $scroll.stop().scrollTo(offset - 60, {
                    duration: 340,
                    axis: 'y',
                    easing: 'easeInOutQuint'
                });
                return;
            }
        }

        if (NEWSBLUR.assets.preference('new_window') == 1) {
            window.open(href, '_blank');
        } else {
            window.open(href);
        }

        this.model.set('selected', true, { selected_by_scrolling: true });

        return false;
    },

    mouseenter_manage_icon: function () {
        var menu_height = 270;
        if (this.$el.offset().top > $(window).height() - menu_height) {
            this.$el.addClass('NB-hover-inverse');
        }
    },

    mouseleave_manage_icon: function () {
        this.$el.removeClass('NB-hover-inverse');
    },

    mouseenter: function () {
        if (this.model.get('selected')) return;

        if (NEWSBLUR.reader.flags['scrolling_by_selecting_story_title'] ||
            NEWSBLUR.assets.preference('feed_view_single_story')) {
            return;
        }

        this.model.set('selected', true, { selected_by_scrolling: true });
    },

    mouseleave: function () {

    },

    mouseenter_thirdparty: function (event) {
        var serviceName = $(event.currentTarget).data("service-label");
        $(event.currentTarget).closest(".NB-sideoption").find(".NB-sideoption-title").text(serviceName);
        $(event.currentTarget).addClass("NB-hover");
        $(event.currentTarget).siblings(".NB-sideoption-icon").addClass("NB-dimmed");
        if ($(event.currentTarget).closest(".NB-sideoption-thirdparty-services").length) {
            $(event.currentTarget).closest(".NB-sideoption").find(".NB-sideoption-icon-email").addClass("NB-dimmed");
        } else {
            $(event.currentTarget).closest(".NB-sideoption").find(".NB-sideoption-icon-email").removeClass("NB-dimmed");
        }
    },

    mouseleave_thirdparty: function (event) {
        $(event.currentTarget).closest(".NB-sideoption").find(".NB-sideoption-title").text("Email");

        $(event.currentTarget).siblings(".NB-sideoption-icon").removeClass("NB-dimmed");
        $(event.currentTarget).removeClass("NB-hover");
        $(event.currentTarget).closest(".NB-sideoption").find(".NB-sideoption-icon-email").removeClass("NB-dimmed");
    },

    mouseup_check_selection: function (e) {
        var $doc = this.$(".NB-feed-story-content");
        // console.log(['mouseup_check_selection', e, e.which, $(e.target)]);
        if (e.which == 3) {
            // Right click
            return;
        }
        if ($(e.target).hasClass("NB-highlight")) {
            this.show_unhighlight_tooltip($(e.target));
            return;
        }

        if (!NEWSBLUR.assets.preference('highlights')) return;

        this.$(".NB-starred-story-selection-highlight,[data-tippy]").contents().unwrap();
        $doc.attr('id', 'NB-highlighting');

        var text = "";
        var selection;
        if (window.getSelection) {
            selection = window.getSelection();
            text = window.getSelection().toString();
        } else if (document.selection && document.selection.type != "Control") {
            selection = document.selection.createRange();
            text = document.selection.createRange().text;
        }
        this.serialized_highlight = _.string.trim(text);
        // console.log(['mouseup_check_selection 1', this.serialized_highlight]);

        if (this.tooltip && this.tooltip.tooltips && this.tooltip.tooltips.length) {
            this.tooltip.tooltips[0].hide();
        }
        if (!this.serialized_highlight) {
            $doc.removeAttr('id');
            this.apply_starred_story_selections();
            return;
        }

        $doc.mark(this.serialized_highlight, {
            "className": "NB-starred-story-selection-highlight",
            "separateWordSearch": false,
            "acrossElements": true,
            "filter": function (node, term, total_counter, counter) {
                if (!selection.containsNode(node)) return false;
                // Highlighting the second 'baz' will fail, and the entire 'baz quz baz' will be highlighted instead.
                //     foo bar baz quz baz bar foo
                // console.log(['filter', node, term, total_counter, counter, selection.anchorNode, selection.anchorOffset, selection.focusNode, selection.focusOffset, selection.anchorNode == node, selection.containsNode(node), node.textContent.indexOf(term)]);
                // if (node.textContent.indexOf(term) != selection.anchorOffset) return false;
                return true;
            },
            "done": _.bind(function () {
                var $selection = $(".NB-starred-story-selection-highlight", $doc);
                console.log(['$selection', $selection, $selection.first().get(0), $selection.last().get(0)]);
                $selection.attr('title', "<div class='NB-highlight-selection'>Highlight</div>");
                var $t = tippy($selection.get(0), {
                    // delay: 100,
                    appendTo: this.el,
                    arrow: true,
                    arrowType: 'round',
                    size: 'large',
                    duration: 350,
                    animation: 'scale',
                    trigger: 'click',
                    interactive: true,
                    performance: true,
                    onHide: _.bind(function () {
                        $selection.removeClass("NB-starred-story-selection-highlight");
                    }, this)
                });
                this.tooltip = $t;
                _.defer(function () {
                    if ($t.tooltips && $t.tooltips.length) $t.tooltips[0].show();
                });

                $doc.removeAttr('id');
                // this.apply_starred_story_selections();

                var doc = window.document, range;
                if (window.getSelection && doc.createRange) {
                    if ($selection.length) {
                        selection.removeAllRanges();
                        range = doc.createRange();
                        range.setStart($selection.first().get(0), 0);
                        range.setEndAfter($selection.last().get(0), 0);
                        selection.addRange(range);
                    }
                    // } else if (doc.body.createTextRange) {
                    //     range = doc.body.createTextRange();
                    //     range.moveToElementText($selection[0]);
                    //     range.select();
                }
            }, this)
        });
    },

    show_unhighlight_tooltip: function ($highlight) {
        this.$highlight = $highlight;
        $highlight.attr('title', "<div class='NB-unhighlight-selection'>Unhighlight</div>");
        var $t = tippy($highlight.get(0), {
            // delay: 100,
            appendTo: this.el,
            arrow: true,
            arrowType: 'round',
            size: 'large',
            duration: 350,
            animation: 'scale',
            trigger: 'click',
            interactive: true,
            performance: true,
            onHide: _.bind(function () {
                // $highlight.removeClass('NB-starred-story-selection-highlight');
            }, this)
        });
        this.tooltip = $t;
        _.defer(function () {
            if ($t.tooltips && $t.tooltips.length) $t.tooltips[0].show();
        });

    },

    highlight_selected_text: function () {
        var highlights = this.model.get('highlights');
        if (!highlights || !$.isArray(highlights)) highlights = [];
        highlights.push(this.serialized_highlight);
        this.model.set('highlights', highlights, { silent: true });
        this.model.trigger('change:highlights');
        console.log(['highlight_selected_text', this.serialized_highlight, highlights]);

        if (this.tooltip && this.tooltip.tooltips && this.tooltip.tooltips.length) {
            this.tooltip.tooltips[0].hide();
        }

        this.apply_starred_story_selections();

        return true;
    },

    unhighlight_selected_text: function (el) {
        var remove_highlight = this.$highlight.text();
        var highlights = this.model.get('highlights');
        if (!highlights || !$.isArray(highlights)) highlights = [];
        highlights = _.filter(highlights, function (value) { return !_.string.contains(value, remove_highlight); });

        this.model.set('highlights', highlights, { silent: true });
        this.model.trigger('change:highlights');
        console.log(['UNhighlighting', remove_highlight, highlights]);

        if (this.tooltip && this.tooltip.tooltips && this.tooltip.tooltips.length) {
            this.tooltip.tooltips[0].hide();
        }

        this.apply_starred_story_selections(true);

        return true;
    },

    apply_starred_story_selections: function (force) {
        var highlights = this.model.user_highlights();
        if (!force) {
            if (!highlights || !highlights.length) return;
        }
        console.log(['Applying highlights', highlights]);

        var $doc = this.$(".NB-feed-story-content");
        $doc.unmark();

        $doc.attr('id', 'NB-highlighting');
        $doc.mark(highlights, {
            "className": "NB-highlight",
            "separateWordSearch": false,
            "acrossElements": true
        });
        $doc.removeAttr('id');
    },

    show_manage_menu_rightclick: function (e) {
        if (!NEWSBLUR.assets.preference('show_contextmenus')) return;

        return this.show_manage_menu(e);
    },

    show_manage_menu: function (e) {
        e.preventDefault();
        e.stopPropagation();
        NEWSBLUR.reader.show_manage_menu('story', this.$el, {
            story_id: this.model.id,
            feed_id: this.model.get('story_feed_id'),
            rightclick: e.which >= 2
        });
        return false;
    },

    show_story_changes: function () {
        NEWSBLUR.assets.fetch_story_changes(this.model.get('story_hash'), !this.model.get('showing_diff'), _.bind(function (data) {
            this.model.set('showing_diff', !this.model.get('showing_diff'));
            this.model.set('story_content', data.story['story_content']);
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }, this), function () {
            console.log(['Failed to fetch story changes']);
        });
    },

    open_feed: function () {
        NEWSBLUR.reader.open_feed(this.model.get('story_feed_id'));
    },

    save_classifier: function (e) {
        var $tag = $(e.currentTarget);
        var classifier_type = $tag.hasClass('NB-feed-story-tag') ? 'tag' : 'author';
        var value = _.string.trim($tag.text());
        var score = $tag.hasClass('NB-score-1') ? -1 : $tag.hasClass('NB-score--1') ? 0 : 1;
        var feed_id = this.model.get('story_feed_id');
        var data = {
            'feed_id': feed_id
        };

        if (score == 0) {
            data['remove_like_' + classifier_type] = value;
        } else if (score == 1) {
            data['like_' + classifier_type] = value;
        } else if (score == -1) {
            data['dislike_' + classifier_type] = value;
        }
        this.model.set('visible', true, { silent: true });
        NEWSBLUR.assets.classifiers[feed_id][classifier_type + 's'][value] = score;
        NEWSBLUR.assets.recalculate_story_scores(feed_id, { story_view: this });
        NEWSBLUR.assets.save_classifier(data, function (resp) {
            NEWSBLUR.reader.feed_unread_count(feed_id);
        });

        this.model.trigger('change:intelligence');
        this.preserve_classifier_color(classifier_type, value, score);
    },

    open_story_trainer: function () {
        var feed_id = this.model.get('story_feed_id');
        var options = {};
        if (NEWSBLUR.reader.flags['social_view']) {
            options['social_feed'] = true;
            options['feed_loaded'] = true;
        }
        NEWSBLUR.reader.open_story_trainer(this.model.id, feed_id, options);
    },

    maybe_open_email: function (e) {
        // Check if target has .NB-sideoption-thirdparty class
        if (!$(e.target).hasClass('NB-sideoption-thirdparty')) {
            return this.open_email();
        }

        var service = $(e.target).data('service-name');
        console.log(['maybe_open_email', e.target, service]);
        NEWSBLUR.reader.send_story_to_thirdparty(this.model.id, service);

        if (service == 'copyurl') {
            this.$(".NB-feed-story-email .NB-sideoption-title").text("Copied");
        } else if (service == 'copytext') {
            this.$(".NB-feed-story-email .NB-sideoption-title").text("Copied");
        }
    },

    open_email: function () {
        NEWSBLUR.reader.send_story_to_email(this.model);
    },

    toggle_starred: function () {
        this.model.toggle_starred();
    },

    scroll_to_comments: function () {
        if (_.contains(['list', 'grid', 'magazine'], NEWSBLUR.assets.view_setting(NEWSBLUR.reader.active_feed, 'layout'))) {
            NEWSBLUR.app.story_titles.scroll_to_selected_story(this.model, {
                scroll_to_comments: true,
                scroll_offset: -50
            });
        } else {
            NEWSBLUR.app.story_list.scroll_to_selected_story(this.model, {
                scroll_to_comments: true,
                scroll_offset: -50
            });
        }
    },

    toggle_feed_story_discover_dialog: function (options) {
        if (!this.discover_view) {
            this.discover_view = new NEWSBLUR.Views.DiscoverStoriesView({
                model: this.model,
                el: this.$('.NB-story-content-container'),
                sideoptions_view: this.sideoptions_view
            }).render();
        }

        this.discover_view.toggle_feed_story_discover_dialog(options);
    }


});
