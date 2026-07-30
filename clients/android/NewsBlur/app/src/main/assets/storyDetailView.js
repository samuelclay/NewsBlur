function loadImages() {
    var imgs = document.images;
    for (var i = 0, len = imgs.length; i < len; i++) {
        setImage(imgs[i])
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

function setImage(img) {
    if (hasProtectedImageClass(img)) {
        return;
    }

    if (img.querySelector('tagName') == 'VIDEO') {
        setImageClass(img, 'NB-large-image');
    } else if (img.width >= 320 && img.height >= 50) {
        setImageClass(img, 'NB-large-image');
    } else {
        setImageClass(img, 'NB-small-image');
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
