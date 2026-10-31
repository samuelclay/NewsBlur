// feed_list_cache.js: keeps the last /reader/feeds response in localStorage, per user, so the
// reader draws the feed list the moment the page loads (common/assetmodel.js load_feeds), as the
// iOS and Android apps do, and then brings it up to date from the server.
//
// Only what the feed list draws is kept. The share token, connected services, profile and Listen
// position never touch storage, and the unread counts are the ones last on screen, written back
// when the page is hidden. A browser without storage, or with a full one, simply loads as before.
(function () {
    var KEY_PREFIX = 'NB:feed_list:v1:';
    // The response keys left out of storage: secrets, the account, and state the server must decide.
    var UNCACHED_KEYS = ['share_ext_token', 'social_services', 'user_profile', 'playback_state', 'categories'];
    var COUNT_KEYS = ['ps', 'nt', 'ng'];
    // What a feed row shows besides its counts. A change to any of it redraws the list.
    var FEED_DISPLAY_KEYS = ['id', 'feed_title', 'active', 'has_exception', 'exception_type'];

    function cache_key(user_id) {
        return KEY_PREFIX + user_id;
    }

    function storable(data) {
        var stored = {};
        Object.keys(data || {}).forEach(function (key) {
            if (UNCACHED_KEYS.indexOf(key) === -1) stored[key] = data[key];
        });
        return stored;
    }

    function pick(object, keys) {
        return keys.map(function (key) {
            return object[key] === undefined ? null : object[key];
        });
    }

    function by_id(a, b) {
        return String(a[0]) < String(b[0]) ? -1 : String(a[0]) > String(b[0]) ? 1 : 0;
    }

    // Everything the feed list draws apart from unread counts and the saved and search sections,
    // which redraw on their own. Two responses with the same signature draw the same list.
    function structure_signature(data) {
        data = data || {};
        var feeds = (data.feeds || []).map(function (feed) {
            return pick(feed, FEED_DISPLAY_KEYS);
        }).sort(by_id);
        var social_feeds = (data.social_feeds || []).map(function (feed) {
            return pick(feed, ['id', 'feed_title', 'username']);
        }).sort(by_id);
        return JSON.stringify([
            data.user_id || null,
            data.folders || [],
            feeds,
            social_feeds,
            data.dashboard_rivers || [],
            data.folder_icons || {},
            data.feed_icons || {}
        ]);
    }

    function without_counts(feeds) {
        return (feeds || []).map(function (feed) {
            var copy = {};
            Object.keys(feed).forEach(function (key) {
                if (COUNT_KEYS.indexOf(key) === -1) copy[key] = feed[key];
            });
            return copy;
        });
    }

    // Copies the unread counts on screen into a stored response, keyed by feed id.
    function with_counts(data, counts_by_id) {
        var patch = function (feeds) {
            return (feeds || []).map(function (feed) {
                var counts = counts_by_id[feed.id];
                if (!counts) return feed;
                var copy = {};
                Object.keys(feed).forEach(function (key) {
                    copy[key] = feed[key];
                });
                COUNT_KEYS.forEach(function (key) {
                    if (counts[key] !== undefined) copy[key] = counts[key];
                });
                return copy;
            });
        };
        var patched = {};
        Object.keys(data).forEach(function (key) {
            patched[key] = data[key];
        });
        patched.feeds = patch(data.feeds);
        patched.social_feeds = patch(data.social_feeds);
        return patched;
    }

    // localStorage can be missing, blocked or full; every access falls back to no cache.
    function storage() {
        try {
            return window.localStorage || null;
        } catch (e) {
            return null;
        }
    }

    function read(user_id) {
        var store = user_id && storage();
        if (!store) return null;
        try {
            var data = JSON.parse(store.getItem(cache_key(user_id)));
            return data && data.user_id == user_id && data.feeds ? data : null;
        } catch (e) {
            return null;
        }
    }

    function write(user_id, data) {
        var store = user_id && storage();
        if (!store || !data) return;
        try {
            store.setItem(cache_key(user_id), JSON.stringify(storable(data)));
        } catch (e) {
            try {
                store.removeItem(cache_key(user_id));
            } catch (ignored) {
                // feed_list_cache.js: storage that refuses both is simply not used.
            }
        }
    }

    // Removes every user's cached list except keep_user_id's (none when it's empty), so a shared
    // browser doesn't keep a previous reader's subscriptions.
    function clear(keep_user_id) {
        var store = storage();
        if (!store) return;
        try {
            var keys = [];
            for (var i = 0; i < store.length; i++) {
                var key = store.key(i);
                if (key && key.indexOf(KEY_PREFIX) === 0 && key !== cache_key(keep_user_id)) keys.push(key);
            }
            keys.forEach(function (key) {
                store.removeItem(key);
            });
        } catch (e) {
            // feed_list_cache.js: nothing to clear when storage can't be read.
        }
    }

    var feed_list_cache = {
        KEY_PREFIX: KEY_PREFIX,
        cache_key: cache_key,
        storable: storable,
        structure_signature: structure_signature,
        without_counts: without_counts,
        with_counts: with_counts,
        read: read,
        write: write,
        clear: clear
    };

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = feed_list_cache;
    }
    if (typeof window !== 'undefined') {
        window.NEWSBLUR = window.NEWSBLUR || {};
        window.NEWSBLUR.feed_list_cache = feed_list_cache;
    }
})();
