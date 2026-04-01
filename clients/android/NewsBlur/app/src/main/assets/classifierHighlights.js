(function () {
  if (window.NB_CLASSIFIER_BOOT) return;
  window.NB_CLASSIFIER_BOOT = true;

  function scoreIconHtml(score) {
    if (score >= 1) {
      return '<img src="thumbs-up.svg" class="NB-classifier-icon-like" />';
    } else if (score <= -2) {
      return '<img src="thumbs-down.svg" class="NB-classifier-icon-dislike" />' +
             '<img src="thumbs-down.svg" class="NB-classifier-icon-dislike-inner" />';
    } else if (score <= -1) {
      return '<img src="thumbs-down.svg" class="NB-classifier-icon-dislike" />';
    }
    return '';
  }

  function classNameForScore(score) {
    if (score >= 1) return 'NB-classifier-highlight-positive';
    if (score <= -2) return 'NB-classifier-highlight-super-negative';
    if (score <= -1) return 'NB-classifier-highlight-negative';
    return '';
  }

  function markText(mk, text, score) {
    var cn = classNameForScore(score);
    if (!cn) return;
    var icon = scoreIconHtml(score);
    mk.mark(text, {
      className: cn,
      separateWordSearch: false,
      acrossElements: true,
      caseSensitive: false,
      each: function (element) {
        if (icon) {
          var span = document.createElement('span');
          span.innerHTML = icon;
          while (span.firstChild) {
            element.appendChild(span.firstChild);
          }
        }
      }
    });
  }

  function markRegex(mk, pattern, score) {
    var cn = classNameForScore(score);
    if (!cn) return;
    var icon = scoreIconHtml(score);
    try {
      var regex = new RegExp(pattern, 'gi');
      mk.markRegExp(regex, {
        className: cn,
        acrossElements: true,
        each: function (element) {
          if (icon) {
            var span = document.createElement('span');
            span.innerHTML = icon;
            while (span.firstChild) {
              element.appendChild(span.firstChild);
            }
          }
        }
      });
    } catch (e) {
      console.log('Invalid regex pattern: ' + pattern + ' - ' + e);
    }
  }

  function applyClassifiers(classifierData) {
    try {
      var ctx = document.querySelector('.NB-story') || document.body;
      var mk = new Mark(ctx);

      // Remove previous classifier marks
      mk.unmark({ className: 'NB-classifier-highlight-positive', done: function () {} });
      mk.unmark({ className: 'NB-classifier-highlight-negative', done: function () {} });
      mk.unmark({ className: 'NB-classifier-highlight-super-negative', done: function () {} });

      // Remove orphaned score icons
      ctx.querySelectorAll('.NB-classifier-icon-like, .NB-classifier-icon-dislike, .NB-classifier-icon-dislike-inner').forEach(function (el) {
        el.remove();
      });

      // Apply text classifier highlights (global/feed text matchers)
      if (classifierData.texts) {
        Object.keys(classifierData.texts).forEach(function (text) {
          markText(mk, text, classifierData.texts[text]);
        });
      }

      // Apply text regex classifier highlights
      if (classifierData.text_regex) {
        Object.keys(classifierData.text_regex).forEach(function (pattern) {
          markRegex(mk, pattern, classifierData.text_regex[pattern]);
        });
      }

      // Apply author highlights
      if (classifierData.authors) {
        Object.keys(classifierData.authors).forEach(function (author) {
          markText(mk, author, classifierData.authors[author]);
        });
      }

      // Apply tag highlights
      if (classifierData.tags) {
        Object.keys(classifierData.tags).forEach(function (tag) {
          markText(mk, tag, classifierData.tags[tag]);
        });
      }

      // Apply title keyword highlights
      if (classifierData.titles) {
        Object.keys(classifierData.titles).forEach(function (title) {
          markText(mk, title, classifierData.titles[title]);
        });
      }

      // Apply title regex highlights
      if (classifierData.title_regex) {
        Object.keys(classifierData.title_regex).forEach(function (pattern) {
          markRegex(mk, pattern, classifierData.title_regex[pattern]);
        });
      }

      // Apply URL highlights
      if (classifierData.urls) {
        Object.keys(classifierData.urls).forEach(function (url) {
          markText(mk, url, classifierData.urls[url]);
        });
      }

      // Apply URL regex highlights
      if (classifierData.url_regex) {
        Object.keys(classifierData.url_regex).forEach(function (pattern) {
          markRegex(mk, pattern, classifierData.url_regex[pattern]);
        });
      }
    } catch (e) {
      console.log('Classifier highlighting error: ' + e);
    }
  }

  window.NB_applyClassifiers = applyClassifiers;
})();
