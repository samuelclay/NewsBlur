document.addEventListener("beforeload", function(e) {
  if (/feed:\/\//.test(window.location.href)) {
    window.location = "http://www.newsblur.com/?url=" + encodeURIComponent(window.location.href.replace('feed://', 'http://'));
  }
}, true);