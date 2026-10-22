// listenFollowAlong.js: the story WebView's half of Listen's follow-along highlight (ListenStoryFollower.kt).
// It lists the story's text blocks for ListenParagraphMatcher.kt, highlights the blocks being read, and
// reports taps on a block so playback can jump to that paragraph.
(function () {
    if (window.NB_listen_installed) return;
    window.NB_listen_installed = true;

    var HIGHLIGHT_CLASS = 'NB-listen-highlight';
    var BLOCK_TAGS = /^(P|H1|H2|H3|H4|H5|H6|LI|BLOCKQUOTE|DD|DT|DIV)$/;
    var INNER_BLOCKS = 'p,h1,h2,h3,h4,h5,h6,li,blockquote,dd,dt';
    // listenFollowAlong.js skips what apps/listen/text.py leaves out of the paragraphs it reads: these tags,
    // aria-hidden decoration, and short caption, credit or gallery elements marked by class or id.
    var SKIPPED_TAGS = /^(SCRIPT|STYLE|NOSCRIPT|SVG|CANVAS|IFRAME|PRE|CODE|TABLE|THEAD|TBODY|TFOOT|TR|TD|TH|FIGURE|FIGCAPTION|AUDIO|VIDEO|OBJECT|EMBED|FORM|BUTTON|NAV|ASIDE|FOOTER|SELECT|TEXTAREA)$/;
    var NOT_PROSE = /caption|credit|gallery/i;
    var MAX_CAPTION_CHARACTERS = 1000;
    var blocks = [];
    var block_paragraphs = {};
    var active = false;

    function normalize(text) {
        return (text || '').replace(/[\s   ]+/g, ' ').trim();
    }

    function is_skipped(node) {
        if (SKIPPED_TAGS.test(node.tagName.toUpperCase())) return true;
        if (node.getAttribute('aria-hidden') === 'true') return true;
        var marks = (node.getAttribute('class') || '') + ' ' + (node.id || '');
        // A long element is an article wrapper that happens to mention galleries, not a caption.
        return NOT_PROSE.test(marks) && (node.textContent || '').length < MAX_CAPTION_CHARACTERS;
    }

    function inside_skipped(element, story) {
        for (var node = element; node && node !== story; node = node.parentElement) {
            if (is_skipped(node)) return true;
        }
        return false;
    }

    function has_direct_text(element) {
        for (var child = element.firstChild; child; child = child.nextSibling) {
            if (child.nodeType === 3 && normalize(child.textContent)) return true;
        }
        return false;
    }

    function is_block(element, story) {
        if (!BLOCK_TAGS.test(element.tagName) || inside_skipped(element, story)) return false;
        if (element.tagName === 'DIV') return has_direct_text(element);
        // Containers like a blockquote of paragraphs are matched through their inner blocks instead.
        return !element.querySelector(INNER_BLOCKS);
    }

    window.NB_listen_collect_blocks = function () {
        var story = document.querySelector('.NB-story');
        blocks = [];
        block_paragraphs = {};
        if (!story) return [];
        var elements = story.querySelectorAll('p,h1,h2,h3,h4,h5,h6,li,blockquote,dd,dt,div');
        var texts = [];
        for (var i = 0; i < elements.length; i++) {
            var element = elements[i];
            if (!is_block(element, story)) continue;
            var text = normalize(element.textContent);
            if (!text) continue;
            element.setAttribute('data-nb-listen-block', String(blocks.length));
            blocks.push(element);
            texts.push(text.substring(0, 120));
        }
        return texts;
    };

    window.NB_listen_set_map = function (map) {
        block_paragraphs = map || {};
    };

    window.NB_listen_set_active = function (is_active) {
        active = !!is_active;
        if (!active) window.NB_listen_clear();
    };

    window.NB_listen_clear = function () {
        var highlighted = document.querySelectorAll('.' + HIGHLIGHT_CLASS);
        for (var i = 0; i < highlighted.length; i++) highlighted[i].classList.remove(HIGHLIGHT_CLASS);
    };

    // Highlights the given blocks and returns where the first one sits, in CSS pixels from the document top.
    window.NB_listen_highlight = function (indexes) {
        var wanted = {};
        for (var i = 0; i < indexes.length; i++) wanted[indexes[i]] = true;
        var first = null;
        var last = null;
        for (var j = 0; j < blocks.length; j++) {
            var element = blocks[j];
            if (wanted[j]) {
                element.classList.add(HIGHLIGHT_CLASS);
                if (!first) first = element;
                last = element;
            } else {
                element.classList.remove(HIGHLIGHT_CLASS);
            }
        }
        if (!first) return null;
        var top = first.getBoundingClientRect().top + window.scrollY;
        var bottom = last.getBoundingClientRect().bottom + window.scrollY;
        return {top: top, bottom: bottom, viewportWidth: document.documentElement.clientWidth};
    };

    document.addEventListener('click', function (event) {
        if (!active || !window.NewsBlurListen) return;
        var target = event.target;
        if (!target || !target.closest) return;
        // Links and photos keep their own taps.
        if (target.closest('a[href]') || target.tagName === 'IMG') return;
        var selection = window.getSelection && window.getSelection();
        if (selection && !selection.isCollapsed) return;
        var block = target.closest('[data-nb-listen-block]');
        if (!block) return;
        var paragraph = block_paragraphs[block.getAttribute('data-nb-listen-block')];
        if (paragraph === undefined) return;
        window.NewsBlurListen.postMessage(JSON.stringify({type: 'paragraph', paragraph: paragraph}));
    });
})();
