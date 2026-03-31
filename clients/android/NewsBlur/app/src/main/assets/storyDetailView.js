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
