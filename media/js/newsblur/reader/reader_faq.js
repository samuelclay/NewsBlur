NEWSBLUR.ReaderFaq = function (options) {
    var defaults = {
        // Taller than wide: fixed content column, height fills the viewport.
        width: 900,
        modal_container_class: "NB-full-container NB-faq-modal-container"
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.data = null;
    this.search_query = '';
    this.expanded_mode = false; // default shown: every Q&A collapsed
    this.runner();
};

NEWSBLUR.ReaderFaq.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderFaq.prototype, {

    runner: function () {
        this.make_modal();
        this.open_modal(_.bind(function () {
            this.resize_modal();
        }, this));

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('input', $.rescope(this.handle_input, this));
        this.$modal.bind('keydown', $.rescope(this.handle_keydown, this));
        $(window).bind('resize.NB-faq', $.rescope(this.resize_modal, this));

        this.fetch_data();
    },

    make_modal: function () {
        this.$modal = $.make('div', { className: 'NB-modal NB-modal-faq' }, [
            $.make('div', { className: 'NB-modal-titlebar' }, [
                $.make('h2', { className: 'NB-modal-title' }, [
                    $.make('div', { className: 'NB-icon' }),
                    'Frequently Asked Questions'
                ]),
                $.make('div', { className: 'NB-faq-controls' }, [
                    $.make('ul', { className: 'segmented-control NB-faq-expand-toggle' }, [
                        $.make('li', {
                            className: 'NB-taskbar-button NB-faq-expand-option NB-faq-expand-all',
                            'data-mode': 'expanded'
                        }, [$.make('span', { className: 'NB-task-title' }, 'Expanded')]),
                        $.make('li', {
                            className: 'NB-taskbar-button NB-faq-expand-option NB-faq-collapse-all NB-active',
                            'data-mode': 'collapsed'
                        }, [$.make('span', { className: 'NB-task-title' }, 'Collapsed')])
                    ]),
                    $.make('div', { className: 'NB-faq-search' }, [
                        $.make('input', {
                            type: 'text',
                            className: 'NB-faq-search-input',
                            placeholder: 'Search the FAQ...',
                            autocomplete: 'off',
                            spellcheck: 'false'
                        }),
                        $.make('div', { className: 'NB-faq-search-clear', title: 'Clear search' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-modal-body NB-faq-modal-body' }, [
                $.make('div', { className: 'NB-faq-loading' }, 'Loading...')
            ]),
            $.make('div', { className: 'NB-modal-footer NB-faq-modal-footer' }, [
                $.make('div', { className: 'NB-faq-footer-text' }, [
                    'Browse the full ',
                    $.make('a', { href: '/faq', target: '_blank', className: 'NB-splash-link' }, 'FAQ page'),
                    ' or ',
                    $.make('a', { href: 'https://forum.newsblur.com', target: '_blank', className: 'NB-splash-link' }, 'ask the community'),
                    '.'
                ])
            ])
        ]);
    },

    fetch_data: function () {
        $.ajax({
            url: '/api/faq/',
            type: 'GET',
            dataType: 'json',
            cache: true,
            success: _.bind(function (data) {
                this.data = data;
                this.render_body();
                this.resize_modal();
                _.defer(_.bind(function () {
                    $('.NB-faq-search-input', this.$modal).trigger('focus');
                }, this));
            }, this),
            error: _.bind(function () {
                $('.NB-faq-modal-body', this.$modal).html(
                    '<div class="NB-faq-error">Could not load FAQ. Please try again.</div>'
                );
            }, this)
        });
    },

    render_body: function () {
        if (!this.data) return;

        var $body = $('.NB-faq-modal-body', this.$modal);
        $body.empty();

        // The tier block lives inline inside the "What are the differences..."
        // Q&A (via show_tier_grid) rather than as a special header. Go straight
        // to sections.
        var sections = this.data.sections || [];
        for (var i = 0; i < sections.length; i++) {
            $body.append(this.render_section(sections[i]));
        }

        $body.append($.make('div', { className: 'NB-faq-empty-state' }, [
            $.make('div', { className: 'NB-faq-empty-state-title' }, 'No questions match that search.'),
            $.make('div', { className: 'NB-faq-empty-state-subtitle' }, 'Try different keywords, or clear the search to see everything.')
        ]));
    },

    render_tiers: function (tiers) {
        if (!tiers || !tiers.length) return $();
        var $grid = $.make('div', { className: 'NB-faq-tier-summary NB-faq-tier-summary-modal' });
        for (var i = 0; i < tiers.length; i++) {
            var t = tiers[i];
            var name_parts = [t.name];
            if (t.price) name_parts.push(' — ', t.price);
            $grid.append(
                $.make('a', {
                    className: 'NB-faq-tier NB-faq-tier-' + t.id,
                    href: t.href,
                    target: '_blank'
                }, [
                    $.make('div', { className: 'NB-faq-tier-name' }, name_parts),
                    $.make('p', { className: 'NB-faq-tier-desc' }, t.description)
                ])
            );
        }
        return $.make('div', { className: 'NB-faq-tiers-block' }, [
            $.make('div', { className: 'NB-faq-tiers-label' }, 'Subscription tiers'),
            $grid
        ]);
    },

    render_section: function (section) {
        var $items = $.make('div', { className: 'NB-faq-items' });
        for (var i = 0; i < section.items.length; i++) {
            $items.append(this.render_item(section.items[i]));
        }
        return $.make('div', {
            className: 'NB-faq-section',
            'data-section-id': section.id
        }, [
            $.make('h3', { className: 'NB-faq-section-title' }, section.title),
            $items
        ]);
    },

    render_item: function (item) {
        var $question_text = $.make('span', { className: 'NB-faq-question-text' }, item.question);
        var $chevron = $.make('span', { className: 'NB-faq-question-chevron' });

        var $answer_inner = $.make('div', { className: 'NB-faq-answer' });
        // The YAML answer is HTML; inject it and then layer feature/blog links below.
        $answer_inner.get(0).innerHTML = item.answer || '';

        if (item.show_tier_grid && this.data && this.data.tiers) {
            // Used by the "What are the differences between tiers?" entry.
            $answer_inner.append(this.render_tiers(this.data.tiers).addClass('NB-faq-tier-summary-inline'));
        }

        if (item.feature_image) {
            $answer_inner.append(
                $.make('figure', { className: 'NB-faq-feature-image' }, [
                    $.make('img', {
                        src: item.feature_image,
                        alt: item.feature_image_alt || item.feature_label || '',
                        loading: 'lazy'
                    })
                ])
            );
        }

        var $links = this.render_item_links(item);
        if ($links) $answer_inner.append($links);

        var $answer_wrapper = $.make('div', { className: 'NB-faq-answer-wrapper' }, $answer_inner);

        // Items render per the current Expanded/Collapsed toggle (defaults to
        // expanded). Search will re-apply open state to matches only.
        var item_class = 'NB-faq-item' + (this.expanded_mode ? ' NB-faq-item-open' : '');
        return $.make('div', {
            className: item_class,
            'data-item-id': item.id
        }, [
            $.make('button', {
                type: 'button',
                className: 'NB-faq-question'
            }, [$question_text, $chevron]),
            $answer_wrapper
        ]);
    },

    render_item_links: function (item) {
        var has_feature = !!item.feature_url;
        var has_blog = !!item.blog_url;
        if (!has_feature && !has_blog) return null;

        var $links = $.make('div', { className: 'NB-faq-item-links' });
        if (has_feature) {
            var label = item.feature_label ? ('See ' + item.feature_label) : 'See feature';
            $links.append($.make('a', {
                className: 'NB-faq-button NB-faq-button-primary',
                href: item.feature_url,
                target: '_blank'
            }, [label, ' →']));
        }
        if (has_blog) {
            $links.append($.make('a', {
                className: 'NB-faq-button NB-faq-button-secondary',
                href: item.blog_url,
                target: '_blank',
                rel: 'noopener'
            }, [
                $.make('span', { className: 'NB-faq-blog-icon' }),
                'Read more on the NewsBlur Blog'
            ]));
        }
        return $links;
    },

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-faq-expand-option' }, function ($t) {
            e.preventDefault();
            var mode = $t.attr('data-mode');
            self.set_expanded_mode(mode === 'expanded');
        });

        $.targetIs(e, { tagSelector: '.NB-faq-question' }, function ($t) {
            e.preventDefault();
            self.toggle_item($t.closest('.NB-faq-item'));
        });

        $.targetIs(e, { tagSelector: '.NB-faq-search-clear' }, function () {
            e.preventDefault();
            self.clear_search();
        });
    },

    set_expanded_mode: function (expanded) {
        this.expanded_mode = !!expanded;

        var $options = $('.NB-faq-expand-option', this.$modal);
        $options.removeClass('NB-active');
        $options.filter(expanded ? '.NB-faq-expand-all' : '.NB-faq-collapse-all').addClass('NB-active');

        // If the user is actively searching, matches stay expanded so the
        // highlight is visible; only non-search state is governed by this toggle.
        if (this.search_query) return;

        var $items = $('.NB-faq-item', this.$modal);
        if (expanded) {
            $items.addClass('NB-faq-item-open');
        } else {
            $items.removeClass('NB-faq-item-open');
        }
    },

    handle_input: function (elem, e) {
        var $target = $(e.target);
        if (!$target.hasClass('NB-faq-search-input')) return;
        this.apply_search($target.val() || '');
    },

    handle_keydown: function (elem, e) {
        if (e.key === 'Escape') {
            var $input = $('.NB-faq-search-input', this.$modal);
            if ($input.is(e.target) && $input.val()) {
                e.preventDefault();
                this.clear_search();
            }
        }
    },

    toggle_item: function ($item) {
        $item.toggleClass('NB-faq-item-open');
    },

    clear_search: function () {
        $('.NB-faq-search-input', this.$modal).val('').trigger('focus');
        this.apply_search('');
    },

    apply_search: function (query) {
        query = (query || '').trim();
        this.search_query = query;

        var $modal = this.$modal;
        $modal.toggleClass('NB-faq-searching', !!query);
        $('.NB-faq-search', $modal).toggleClass('NB-faq-search-active', !!query);

        var $items = $('.NB-faq-item', $modal);
        var $sections = $('.NB-faq-section', $modal);

        if (!query) {
            // Reset: un-highlight, reveal everything, return items to whatever
            // the Expanded/Collapsed segmented control says.
            $items.removeClass('NB-faq-item-match');
            if (this.expanded_mode) {
                $items.addClass('NB-faq-item-open');
            } else {
                $items.removeClass('NB-faq-item-open');
            }
            $sections.removeClass('NB-faq-section-hidden');
            this.unhighlight_all();
            $('.NB-faq-empty-state', $modal).removeClass('NB-faq-empty-state-visible');
            return;
        }

        var terms = this.tokenize(query);
        var match_count = 0;

        $items.each(_.bind(function (_i, item_el) {
            var $item = $(item_el);
            var $question = $item.find('.NB-faq-question-text');
            var $answer = $item.find('.NB-faq-answer');
            var question_text = $question.text();
            var answer_text = $answer.text();
            var haystack = (question_text + ' \n ' + answer_text).toLowerCase();
            var is_match = _.every(terms, function (t) { return haystack.indexOf(t) !== -1; });

            $item.toggleClass('NB-faq-item-match', is_match);
            // Auto-expand matching items so the highlighted answer is visible.
            $item.toggleClass('NB-faq-item-open', is_match);

            if (is_match) {
                this.highlight_in($question, terms);
                this.highlight_in($answer, terms);
                match_count++;
            } else {
                this.unhighlight_in($question);
                this.unhighlight_in($answer);
            }
        }, this));

        // Hide section headers that have zero matches so the list stays tight.
        $sections.each(function () {
            var $s = $(this);
            $s.toggleClass('NB-faq-section-hidden', $s.find('.NB-faq-item-match').length === 0);
        });

        $('.NB-faq-empty-state', $modal).toggleClass('NB-faq-empty-state-visible', match_count === 0);
    },

    tokenize: function (query) {
        return _.compact(query.toLowerCase().split(/\s+/));
    },

    highlight_in: function ($el, terms) {
        // Remove previous highlights before applying new ones. We stash the
        // original HTML on first call so successive searches don't re-wrap
        // already-wrapped nodes.
        var original = $el.data('faq-original-html');
        if (original == null) {
            original = $el.get(0).innerHTML;
            $el.data('faq-original-html', original);
        }
        $el.get(0).innerHTML = this.wrap_matches(original, terms);
    },

    unhighlight_in: function ($el) {
        var original = $el.data('faq-original-html');
        if (original != null) {
            $el.get(0).innerHTML = original;
        }
    },

    unhighlight_all: function () {
        var $modal = this.$modal;
        $('.NB-faq-question-text, .NB-faq-answer', $modal).each(function () {
            var $el = $(this);
            var original = $el.data('faq-original-html');
            if (original != null) $el.get(0).innerHTML = original;
        });
    },

    wrap_matches: function (html, terms) {
        // Operate on text nodes only so we don't wreck HTML structure. Build a
        // single regex that matches any term; case-insensitive. Escape special
        // regex chars in each term first.
        if (!terms.length) return html;
        var escaped = _.map(terms, function (t) {
            return t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        });
        var regex = new RegExp('(' + escaped.join('|') + ')', 'gi');

        var wrapper = document.createElement('div');
        wrapper.innerHTML = html;
        this.walk_text_nodes(wrapper, function (text_node) {
            var text = text_node.nodeValue;
            if (!regex.test(text)) return;
            regex.lastIndex = 0;
            var frag = document.createDocumentFragment();
            var last = 0;
            var m;
            while ((m = regex.exec(text)) !== null) {
                if (m.index > last) {
                    frag.appendChild(document.createTextNode(text.substring(last, m.index)));
                }
                var mark = document.createElement('mark');
                mark.className = 'NB-faq-highlight';
                mark.textContent = m[0];
                frag.appendChild(mark);
                last = m.index + m[0].length;
            }
            if (last < text.length) {
                frag.appendChild(document.createTextNode(text.substring(last)));
            }
            text_node.parentNode.replaceChild(frag, text_node);
        });
        return wrapper.innerHTML;
    },

    walk_text_nodes: function (node, fn) {
        // Recursive, snapshot child list so replacing a node doesn't break the loop.
        var children = Array.prototype.slice.call(node.childNodes);
        for (var i = 0; i < children.length; i++) {
            var child = children[i];
            if (child.nodeType === 3) {
                fn(child);
            } else if (child.nodeType === 1 && child.tagName !== 'MARK' && child.tagName !== 'SCRIPT' && child.tagName !== 'STYLE') {
                this.walk_text_nodes(child, fn);
            }
        }
    },

    resize_modal: function () {
        // If the modal was closed (detached from the DOM) we can't resize it.
        // Belt-and-braces: also unbind our resize handler here so it self-cleans
        // after a close that doesn't route through our own close() method.
        if (!this.$modal || !this.$modal.closest('body').length) {
            $(window).off('resize.NB-faq');
            return;
        }

        var MIN_WIDTH = 720;
        var MAX_WIDTH = 1100;
        var MIN_HEIGHT = 520;
        // Taller than wide: fill the viewport minus some chrome.
        var available_width = Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, window.innerWidth - 80));
        var available_height = Math.max(MIN_HEIGHT, window.innerHeight - 60);

        var $container = this.$modal.closest('#simplemodal-container.NB-faq-modal-container');
        if ($container.length) {
            $container.css({
                height: available_height,
                width: available_width
            });
        }
        this.resize();
    },

    close: function (callback) {
        $(window).off('resize.NB-faq');
        $.modal.close(callback);
    }

});
