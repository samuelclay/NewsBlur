(function (root, factory) {
    var api = factory();

    root.NEWSBLUR = root.NEWSBLUR || {};
    root.NEWSBLUR.story_selection_utils = api;

    if (root.NEWSBLUR.utils) {
        root.NEWSBLUR.utils.story_selection_utils = api;
    }

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    var named_entities = {
        amp: '&',
        apos: "'",
        gt: '>',
        lt: '<',
        nbsp: ' ',
        quot: '"'
    };

    function to_story_list(stories) {
        if (!stories) return [];
        if (stories.models) return stories.models;
        return stories;
    }

    function read_story_attr(story, key) {
        if (!story) return null;
        if (typeof story.get === 'function') {
            return story.get(key);
        }
        return story[key];
    }

    function decode_html_entities(value) {
        if (typeof value !== 'string' || !value.length) {
            return '';
        }

        return value.replace(/&(#x?[0-9a-f]+|[a-z]+);/ig, function (entity, token) {
            var normalized = token.toLowerCase();

            if (named_entities[normalized]) {
                return named_entities[normalized];
            }

            if (normalized.charAt(0) === '#') {
                var is_hex = normalized.charAt(1) === 'x';
                var codepoint = parseInt(normalized.slice(is_hex ? 2 : 1), is_hex ? 16 : 10);
                if (!isNaN(codepoint)) {
                    return String.fromCharCode(codepoint);
                }
            }

            return entity;
        });
    }

    function normalize_story_title(title) {
        if (typeof title !== 'string' || !title.length) {
            return '';
        }

        return decode_html_entities(title)
            .replace(/\s+/g, ' ')
            .trim()
            .toLowerCase();
    }

    function find_story_by_hash_or_title(stories, options) {
        options = options || {};

        var story_list = to_story_list(stories);
        var story_id = options.story_id;
        var story_title = normalize_story_title(options.story_title);
        var allow_title_fallback = !!options.allow_title_fallback;
        var title_match = null;

        for (var i = 0; i < story_list.length; i++) {
            var story = story_list[i];

            if (story_id && read_story_attr(story, 'story_hash') == story_id) {
                return story;
            }

            if (!title_match &&
                allow_title_fallback &&
                story_title &&
                normalize_story_title(read_story_attr(story, 'story_title')) === story_title) {
                title_match = story;
            }
        }

        return title_match;
    }

    function unread_view_name_for_story_score(score) {
        if (score > 0) return 'positive';
        if (score < 0) return 'negative';
        return 'neutral';
    }

    return {
        decode_html_entities: decode_html_entities,
        find_story_by_hash_or_title: find_story_by_hash_or_title,
        normalize_story_title: normalize_story_title,
        unread_view_name_for_story_score: unread_view_name_for_story_score
    };
});
