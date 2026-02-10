function normalizeMedia() {
  var imgs = document.images;
  for (var i = 0; i < imgs.length; i++) {
    var img = imgs[i];
    if (img.width >= 320 && img.height >= 50) {
      img.classList.add('NB-large-image');
    } else {
      img.classList.add('NB-small-image');
    }
  }

  var videos = document.getElementsByTagName('video');
  for (var j = 0; j < videos.length; j++) {
    var v = videos[j];

    v.classList.add('NB-large-image');

    // Make sure videos are usable without site-specific players
    if (!v.hasAttribute('controls')) v.setAttribute('controls', 'controls');
    v.setAttribute('playsinline', 'playsinline');
    if (!v.hasAttribute('preload')) v.setAttribute('preload', 'metadata');
  }
}