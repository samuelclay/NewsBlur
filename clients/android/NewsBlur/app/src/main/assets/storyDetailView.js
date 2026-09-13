function loadImages() {
    var imgs = document.images;
    var inline_contexts = new WeakMap();
    for (var i = 0, len = imgs.length; i < len; i++) {
        setImage(imgs[i], inline_contexts);
    }
}

function hasClass(img, className) {
    return !!img.classList && img.classList.contains(className);
}

function hasProtectedImageClass(img) {
    return hasClass(img, 'NB-briefing-inline-favicon') ||
        hasClass(img, 'NB-briefing-section-icon') ||
        hasClass(img, 'NB-classifier-icon-like') ||
        hasClass(img, 'NB-classifier-icon-dislike') ||
        hasClass(img, 'NB-classifier-icon-dislike-inner');
}

function setImageClass(img, className) {
    if (img.classList) {
        img.classList.remove('NB-large-image');
        img.classList.remove('NB-small-image');
        img.classList.add(className);
        return;
    }

    var classAttr = img.getAttribute('class') || '';
    var classNames = classAttr.split(/\s+/);
    var filtered = [];
    for (var i = 0, len = classNames.length; i < len; i++) {
        if (classNames[i] && classNames[i] !== 'NB-large-image' && classNames[i] !== 'NB-small-image') {
            filtered.push(classNames[i]);
        }
    }
    filtered.push(className);
    img.setAttribute('class', filtered.join(' '));
}

function setImage(img, inline_contexts) {
    if (hasProtectedImageClass(img)) {
        return;
    }

    var pane_width = document.documentElement.clientWidth;
    img.style.removeProperty('--NB-image-offset');
    if (img.complete && pane_width > 0 && img.naturalWidth >= pane_width &&
        img.naturalHeight >= 50 && !NB_is_deliberately_small_image(img) &&
        NB_is_standalone_image(img, inline_contexts || new WeakMap())) {
        setImageClass(img, 'NB-large-image');
        // storyDetailView.js measures the image's actual inset, including nested wrapper padding.
        img.style.setProperty('--NB-image-offset', -img.getBoundingClientRect().left + 'px');
    } else {
        setImageClass(img, 'NB-small-image');
    }
}

function NB_is_deliberately_small_image(img) {
    var story = img.closest('.NB-story');
    if (!story) {
        return true;
    }
    var fixed_width = /^\d+(\.\d+)?(px)?$/i;
    var declared_width = img.style.width || img.getAttribute('width') || '';
    return fixed_width.test(declared_width) && parseFloat(declared_width) < story.clientWidth;
}

function NB_is_standalone_image(img, inline_contexts) {
    var branch = img;
    var parent = img.parentElement;
    while (parent) {
        if (/^(UL|OL|LI|DL|DT|DD|TABLE|THEAD|TBODY|TFOOT|TR|TD|TH|BLOCKQUOTE|PRE)$/.test(parent.tagName)) {
            return false;
        }
        var inline_content = inline_contexts.get(parent);
        if (!inline_content) {
            inline_content = [];
            for (var sibling = parent.firstChild; sibling; sibling = sibling.nextSibling) {
                if (sibling.nodeType === 3 && sibling.textContent.trim()) {
                    inline_content.push(sibling);
                } else if (sibling.nodeType === 1 &&
                    !/^(IMG|PICTURE|SOURCE|BR|FIGCAPTION)$/.test(sibling.tagName) &&
                    window.getComputedStyle(sibling).display.indexOf('inline') === 0 && sibling.textContent.trim()) {
                    inline_content.push(sibling);
                }
            }
            inline_contexts.set(parent, inline_content);
        }
        if (inline_content.length > 1 || (inline_content.length === 1 && inline_content[0] !== branch)) {
            return false;
        }
        if (hasClass(parent, 'NB-story')) {
            return true;
        }
        branch = parent;
        parent = parent.parentElement;
    }
    return false;
}

// storyDetailView.js also handles cached images and images arriving after WebView.onPageFinished.
if (!window.NB_image_listeners_installed) {
    window.NB_image_listeners_installed = true;
    document.addEventListener('load', function(event) {
        if (event.target.tagName === 'IMG') {
            setImage(event.target);
        }
    }, true);
    document.addEventListener('error', function(event) {
        if (event.target.tagName === 'IMG') {
            setImage(event.target);
        }
    }, true);
    var NB_image_resize_pending = false;
    var NB_image_pane_width = document.documentElement.clientWidth;
    window.addEventListener('resize', function() {
        var pane_width = document.documentElement.clientWidth;
        if (pane_width === NB_image_pane_width) {
            return;
        }
        NB_image_pane_width = pane_width;
        if (NB_image_resize_pending) {
            return;
        }
        NB_image_resize_pending = true;
        window.setTimeout(function() {
            NB_image_resize_pending = false;
            loadImages();
        }, 0);
    });
    loadImages();
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', loadImages, { once: true });
    }
}

function NB_reader_document_height() {
    var document_element = document.documentElement;
    var body = document.body;
    return Math.max(
        document_element ? document_element.scrollHeight : 0,
        body ? body.scrollHeight : 0,
        1
    );
}

function NB_reader_range_rect(range) {
    if (!range) {
        return null;
    }

    var rects = range.getClientRects();
    if (rects && rects.length > 0) {
        return rects[0];
    }
    return range.getBoundingClientRect();
}

function NB_reader_fallback_element(document_y) {
    var story = document.querySelector('.NB-story') || document.body;
    if (!story) {
        return null;
    }

    var candidates = story.querySelectorAll(
        'p,li,h1,h2,h3,h4,h5,h6,blockquote,pre,figcaption,figure,table,td,th,img'
    );
    var last_visible = null;
    for (var i = 0; i < candidates.length; i++) {
        var rect = candidates[i].getBoundingClientRect();
        if (rect.width <= 0 || rect.height <= 0) {
            continue;
        }
        last_visible = candidates[i];
        if (rect.bottom > document_y) {
            return candidates[i];
        }
    }
    return last_visible;
}

function NB_capture_reader_anchor(document_y_fraction) {
    var document_height = NB_reader_document_height();
    var document_y = Math.max(0, Math.min(document_height - 1, document_height * document_y_fraction));
    var document_width = document.documentElement ? document.documentElement.clientWidth : 0;
    var range = null;
    var x_positions = [document_width * 0.5, document_width * 0.25, document_width * 0.75];

    if (document.caretRangeFromPoint) {
        for (var i = 0; i < x_positions.length && !range; i++) {
            range = document.caretRangeFromPoint(x_positions[i], document_y);
        }
    } else if (document.caretPositionFromPoint) {
        for (var j = 0; j < x_positions.length && !range; j++) {
            var position = document.caretPositionFromPoint(x_positions[j], document_y);
            if (position) {
                range = document.createRange();
                range.setStart(position.offsetNode, position.offset);
                range.collapse(true);
            }
        }
    }

    var range_rect = NB_reader_range_rect(range);
    if (range && range_rect) {
        window.NB_reader_anchor = {
            range: range.cloneRange(),
            element: null,
            offset_y: document_y - range_rect.top,
            offset_fraction: 0,
            document_width: document_width,
            document_height: document_height
        };
        return true;
    }

    var element = NB_reader_fallback_element(document_y);
    if (!element) {
        window.NB_reader_anchor = null;
        return false;
    }

    var element_rect = element.getBoundingClientRect();
    window.NB_reader_anchor = {
        range: null,
        element: element,
        offset_y: 0,
        offset_fraction: Math.max(0, Math.min(1, (document_y - element_rect.top) / element_rect.height)),
        document_width: document_width,
        document_height: document_height
    };
    return true;
}

function NB_resolve_reader_anchor() {
    var anchor = window.NB_reader_anchor;
    if (!anchor) {
        return null;
    }

    var rect = anchor.range ? NB_reader_range_rect(anchor.range) : anchor.element.getBoundingClientRect();
    if (!rect) {
        return null;
    }

    var document_height = NB_reader_document_height();
    var document_width = document.documentElement ? document.documentElement.clientWidth : 0;
    var document_y = anchor.range
        ? rect.top + anchor.offset_y
        : rect.top + (rect.height * anchor.offset_fraction);
    var layout_changed =
        Math.abs(document_width - anchor.document_width) > 0.5 ||
        Math.abs(document_height - anchor.document_height) > 0.5;

    return [
        Math.max(0, Math.min(1, document_y / document_height)),
        layout_changed
    ];
}
