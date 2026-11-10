// storyMedia.js: a story's audio files, like podcast episodes, play in the app's own player (ListenManager.kt)
// instead of inside this WebView, so they get the lock screen, notification and Bluetooth controls, skips, and the
// position the web media player shares. utils/story_functions.py turns a feed's audio enclosures into <audio>
// elements; each one becomes a card with Play, Play Next and Play Last, the web's buttons (story_detail_view.js).
// Taps go to ReadingItemFragment.kt through the NewsBlurMedia listener (NewsblurWebview.java); without that
// listener the <audio> element stays as it was. Videos and YouTube still play here.
(function () {
    if (window.NB_media_installed) return;
    window.NB_media_installed = true;

    var SVG_PLAY = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.14v13.72a1 1 0 0 0 1.52.85l10.6-6.86a1 1 0 0 0 0-1.7L9.52 4.29A1 1 0 0 0 8 5.14z"/></svg>';
    var SVG_PAUSE = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="4.5" width="4" height="15" rx="1.2"/><rect x="14" y="4.5" width="4" height="15" rx="1.2"/></svg>';
    var SVG_LOADING = '<svg viewBox="0 0 24 24" aria-hidden="true" class="NB-media-card-spinner"><path d="M12 3a9 9 0 1 0 9 9h-2.4A6.6 6.6 0 1 1 12 5.4z"/></svg>';

    var cards = [];
    var loaded_url = null;
    var loaded_state = '';

    function labels() {
        return window.NB_media_labels || {};
    }

    // storyMedia.js only hands the app web addresses it can stream; a relative src has no server to come from.
    function source_of(audio) {
        var source = audio.querySelector('source[src]');
        var src = (source && source.getAttribute('src')) || audio.getAttribute('src') || '';
        src = src.trim();
        return /^https?:\/\//i.test(src) ? src : null;
    }

    function post(action, url) {
        window.NewsBlurMedia.postMessage(JSON.stringify({type: 'media', action: action, url: url}));
    }

    function make_button(class_name, text, action, url) {
        var button = document.createElement('button');
        button.type = 'button';
        button.className = class_name;
        button.textContent = text;
        button.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            post(action, url);
        });
        return button;
    }

    function make_card(audio, url) {
        var card = document.createElement('div');
        card.className = 'NB-media-card';
        card.setAttribute('data-nb-media-url', url);

        var main = document.createElement('button');
        main.type = 'button';
        main.className = 'NB-media-card-main';
        var icon = document.createElement('span');
        icon.className = 'NB-media-card-icon';
        var label = document.createElement('span');
        label.className = 'NB-media-card-label';
        main.appendChild(icon);
        main.appendChild(label);
        main.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            post('play', url);
        });

        var actions = document.createElement('span');
        actions.className = 'NB-media-card-actions';
        actions.appendChild(make_button('NB-media-card-queue', labels().play_next || 'Play Next', 'next', url));
        actions.appendChild(make_button('NB-media-card-queue', labels().play_last || 'Play Last', 'last', url));

        card.appendChild(main);
        card.appendChild(actions);
        audio.parentNode.insertBefore(card, audio);
        cards.push({card: card, icon: icon, label: label, actions: actions, url: url});
    }

    // The card for the file the app has loaded shows Pause or Resume, and the queue buttons only make sense for
    // the others.
    function render(entry) {
        var state = entry.url === loaded_url ? loaded_state : '';
        var text = labels().play || 'Play audio';
        var svg = SVG_PLAY;
        if (state === 'playing') {
            text = labels().pause || 'Pause';
            svg = SVG_PAUSE;
        } else if (state === 'loading') {
            text = labels().pause || 'Pause';
            svg = SVG_LOADING;
        } else if (state === 'paused') {
            text = labels().resume || 'Resume';
        }
        entry.card.setAttribute('data-nb-media-state', state || 'idle');
        entry.icon.innerHTML = svg;
        entry.label.textContent = text;
        entry.actions.style.display = state ? 'none' : '';
    }

    function install() {
        if (!window.NewsBlurMedia) return;
        var story = document.querySelector('.NB-story');
        if (!story) return;
        var audios = story.querySelectorAll('audio');
        for (var i = 0; i < audios.length; i++) {
            var audio = audios[i];
            if (audio.getAttribute('data-nb-media-card')) continue;
            var url = source_of(audio);
            if (!url) continue;
            audio.setAttribute('data-nb-media-card', 'true');
            audio.removeAttribute('autoplay');
            audio.pause();
            audio.style.setProperty('display', 'none', 'important');
            // A hidden element can't be started by a tap, but a script in the story could start it; the app plays it.
            audio.addEventListener('play', (function (element, src) {
                return function () {
                    element.pause();
                    post('play', src);
                };
            })(audio, url));
            make_card(audio, url);
        }
        cards.forEach(render);
    }

    // ReadingItemFragment.kt reports which file the app's player has loaded and whether it's playing, paused or
    // loading; an empty url means none of this story's files.
    window.NB_media_set_state = function (url, state) {
        loaded_url = url || null;
        loaded_state = state || '';
        cards.forEach(render);
    };

    install();
    document.addEventListener('DOMContentLoaded', install);
})();
