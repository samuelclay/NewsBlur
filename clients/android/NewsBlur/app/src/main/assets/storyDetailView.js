function loadImages() {
    var imgs = document.images;
    for (var i = 0, len = imgs.length; i < len; i++) {
        setImage(imgs[i])
    }
}

function setImage(img) {
    if (img.querySelector('tagName') == 'VIDEO') {
        img.setAttribute('class', 'NB-large-image');
    } else if (img.width >= 320 && img.height >= 50) {
        img.setAttribute('class', 'NB-large-image');
    } else {
        img.setAttribute('class', 'NB-small-image');
    }
}