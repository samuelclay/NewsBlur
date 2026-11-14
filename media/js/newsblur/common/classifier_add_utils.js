// classifier_add_utils.js: Pure helpers behind the Manage Training add row in
// media/js/newsblur/reader/reader_classifier.js, where a reader types a classifier
// and picks where it applies instead of finding it in a story first (forum #13907).
// Kept free of jQuery and Backbone so node/tests/classifier_add_utils.test.js can load it.
(function (root, factory) {
    var api = factory();

    root.NEWSBLUR = root.NEWSBLUR || {};
    root.NEWSBLUR.classifier_add_utils = api;

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    // Classifier types a reader can type in. Feed (publisher) classifiers have
    // nothing to type, and AI prompts have their own sections in the trainer.
    var TYPES = ['title', 'author', 'tag', 'text', 'url'];
    var REGEX_TYPES = ['title', 'author', 'text', 'url'];

    function supports_regex(type) {
        return REGEX_TYPES.indexOf(type) !== -1;
    }

    // Scope picker values are 'global', 'folder:<folder path>' or 'feed:<feed id>'.
    function parse_scope(scope_value) {
        if (scope_value && scope_value.indexOf('folder:') === 0) {
            return { scope: 'folder', folder_name: scope_value.slice('folder:'.length), feed_id: 0 };
        }
        if (scope_value && scope_value.indexOf('feed:') === 0) {
            return { scope: 'feed', folder_name: '', feed_id: parseInt(scope_value.slice('feed:'.length), 10) };
        }
        return { scope: 'global', folder_name: '', feed_id: 0 };
    }

    // Matches UserSubscriptionFolders.flatten_folders() in apps/reader/models.py,
    // which is how folder-scoped classifiers name their folder.
    function folder_path(parent_path, folder_title) {
        return parent_path ? parent_path + ' - ' + folder_title : folder_title;
    }

    // Opinion prefixes for the add row's Like, Dislike and Hide buttons. Hide is the
    // super dislike, score -2, which overrides every like.
    var SENTIMENT_OPINIONS = { like: 'like_', dislike: 'dislike_', super_dislike: 'super_dislike_' };

    // POST body for /classifier/save (apps/analyzer/views.py:save_classifier).
    function build_save_data(entry) {
        var scope = parse_scope(entry.scope_value);
        var opinion = SENTIMENT_OPINIONS[entry.sentiment] || 'like_';
        var is_regex = entry.is_regex && supports_regex(entry.type);
        var data = {
            feed_id: scope.feed_id,
            scope: scope.scope,
            folder_name: scope.folder_name
        };
        data[opinion + entry.type + (is_regex ? '_regex' : '')] = String(entry.value || '').trim();
        return data;
    }

    // The first tier the reader is missing for this entry, or null. Mirrors the
    // story trainer's gates: scope and text need Archive, URL needs Premium, regex needs Pro.
    function required_tier(entry, tiers) {
        if (parse_scope(entry.scope_value).scope !== 'feed' && !tiers.is_archive) {
            return { tier: 'archive', reason: 'scope' };
        }
        if (entry.type === 'text' && !tiers.is_archive) {
            return { tier: 'archive', reason: 'text' };
        }
        if (entry.type === 'url' && !tiers.is_premium) {
            return { tier: 'premium', reason: 'url' };
        }
        if (entry.is_regex && supports_regex(entry.type) && !tiers.is_pro) {
            return { tier: 'pro', reason: 'regex' };
        }
        return null;
    }

    // One classifier's identity in Manage Training. Global and folder pills all carry
    // feed id 0, so scope and folder are part of it, and a regex is a separate classifier
    // from plain text with the same pattern. Accepts model values or the string data
    // attributes on .NB-manage-classifier-item; JSON keeps a ':' inside a folder name or
    // value from colliding with another classifier.
    function classifier_key(classifier) {
        return JSON.stringify([
            String(classifier.feed_id || 0),
            classifier.type,
            classifier.scope || 'feed',
            classifier.folder_name || '',
            String(classifier.is_regex) === 'true',
            String(classifier.value)
        ]);
    }

    // Form field name for saving one Manage Training pill edit, such as "like_title" or
    // "remove_dislike_author_regex". Without the regex suffix the server would write a
    // regex pill's edit onto the plain classifier with the same text.
    function opinion_name(type, score, original_score, is_regex) {
        var opinion;
        if (score === 1) {
            opinion = 'like_';
        } else if (score === -2) {
            opinion = 'super_dislike_';
        } else if (score === -1) {
            opinion = 'dislike_';
        } else if (original_score > 0) {
            opinion = 'remove_like_';
        } else {
            opinion = 'remove_dislike_';
        }
        return opinion + type + (is_regex && supports_regex(type) ? '_regex' : '');
    }

    // Lowercased and accent-free, so a search for "cafe" finds "Café".
    function normalize_search_text(text) {
        var lowered = String(text || '').toLowerCase();
        return lowered.normalize ? lowered.normalize('NFD').replace(/[̀-ͯ]/g, '') : lowered;
    }

    // What the phrase field holds once an add saves. The field stays editable while the save
    // is out, so anything typed since then is the reader's next classifier and is kept.
    function input_after_add(current_value, submitted_value) {
        return String(current_value || '').trim() === submitted_value ? '' : String(current_value || '');
    }

    // Picker options for a search (views/feed_folder_picker_view.js). Every word must
    // appear in the option's title or, for a nested folder, its parent folders.
    function filter_scope_options(options, query) {
        var words = normalize_search_text(query).split(/\s+/).filter(Boolean);
        if (!words.length) return options;

        return options.filter(function (option) {
            var haystack = normalize_search_text(option.title + ' ' + (option.parent_path || ''));
            return words.every(function (word) {
                return haystack.indexOf(word) !== -1;
            });
        });
    }

    return {
        TYPES: TYPES,
        filter_scope_options: filter_scope_options,
        input_after_add: input_after_add,
        supports_regex: supports_regex,
        parse_scope: parse_scope,
        folder_path: folder_path,
        build_save_data: build_save_data,
        required_tier: required_tier,
        classifier_key: classifier_key,
        opinion_name: opinion_name
    };
});
