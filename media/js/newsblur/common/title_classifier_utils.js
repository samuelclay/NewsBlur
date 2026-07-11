(function (root, factory) {
    var api = factory();

    root.NEWSBLUR = root.NEWSBLUR || {};
    root.NEWSBLUR.title_classifier_utils = api;

    if (root.NEWSBLUR.utils) {
        root.NEWSBLUR.utils.title_classifier_utils = api;
    }

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    var unicode_word_character_regex;
    var fallback_combining_mark_regex = /[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]/;

    try {
        unicode_word_character_regex = new RegExp('[\\p{L}\\p{M}\\p{N}_]', 'u');
    } catch (e) {
        unicode_word_character_regex = /[A-Za-z0-9_]/;
    }

    function previous_character(value, position) {
        var previous_position = position - 1;
        var previous_code_unit = value.charCodeAt(previous_position);

        if (previous_position > 0 && previous_code_unit >= 0xDC00 && previous_code_unit <= 0xDFFF) {
            var leading_code_unit = value.charCodeAt(previous_position - 1);
            if (leading_code_unit >= 0xD800 && leading_code_unit <= 0xDBFF) {
                return value.slice(previous_position - 1, position);
            }
        }

        return value.charAt(previous_position);
    }

    function first_character(value) {
        var first_code_unit = value.charCodeAt(0);

        if (value.length > 1 && first_code_unit >= 0xD800 && first_code_unit <= 0xDBFF) {
            var trailing_code_unit = value.charCodeAt(1);
            if (trailing_code_unit >= 0xDC00 && trailing_code_unit <= 0xDFFF) {
                return value.slice(0, 2);
            }
        }

        return value.charAt(0);
    }

    function is_word_character(character) {
        if (!character) return false;

        // media/js/newsblur/common/title_classifier_utils.js: Standard combining-mark blocks
        // preserve NFD word boundaries even without Unicode property escape support.
        if (fallback_combining_mark_regex.test(character)) return true;

        if (unicode_word_character_regex.test(character)) return true;

        // media/js/newsblur/common/title_classifier_utils.js: Preserve other caseable-letter
        // boundaries in browsers that predate Unicode property escapes.
        return character.toLowerCase() !== character.toUpperCase();
    }

    function find_match_position(story_title, classifier_title) {
        if (typeof story_title !== 'string' || typeof classifier_title !== 'string' ||
            !story_title.length || !classifier_title.length) {
            return -1;
        }

        var normalized_title = story_title.toLowerCase();
        var normalized_classifier = classifier_title.toLowerCase();
        var match_position = normalized_title.indexOf(normalized_classifier);

        // media/js/newsblur/common/title_classifier_utils.js: Punctuation-leading rules retain
        // legacy substring matching because their first character already supplies a boundary.
        if (!is_word_character(first_character(normalized_classifier))) {
            return match_position;
        }

        while (match_position !== -1) {
            if (match_position === 0 ||
                !is_word_character(previous_character(normalized_title, match_position))) {
                return match_position;
            }

            match_position = normalized_title.indexOf(normalized_classifier, match_position + 1);
        }

        return -1;
    }

    return {
        find_match_position: find_match_position
    };
});
