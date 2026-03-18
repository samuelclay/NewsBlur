(function () {
  if (window.NB_HIGHLIGHTS_BOOT) return;
  window.NB_HIGHLIGHTS_BOOT = true;

  var CLASS = 'NB-starred-story-selection-highlight';

  function apply(list) {
    try {
      var arr = (list || []).filter(Boolean);
      if (!arr.length) return;
      var ctx = document.querySelector('.NB-story') || document.body;
      if (!ctx) return;

      var mk = new Mark(ctx);
      mk.mark(arr, {
        className: CLASS,
        separateWordSearch: false,
        accuracy: 'exactly',
        diacritics: true,
        acrossElements: true,
        ignoreJoiners: true,
        ignorePunctuation: ['.', ',', '!', '?', ':', ';', '—', '–', '·', ')', '(', ']', '[', '}', '{', '"', "'"],
      });
    } catch (e) {}
  }

  function unmarkThenApply(list) {
    try {
      var ctx = document.querySelector('.NB-story') || document.body;
      if (!ctx) return;

      var mk = new Mark(ctx);
      mk.unmark({
        className: CLASS,
        done: function () { apply(list); }
      });
    } catch (e) {}
  }

  function applyWhenReady() {
    var attempts = 0;

    function go() {
      var ctx = document.querySelector('.NB-story') || document.body;

      if (typeof window.Mark !== 'function' || !ctx) {
        if (attempts++ < 60) return setTimeout(go, 50); // 3s total
        return;
      }

      // Always apply the latest list we’ve been asked to apply
      unmarkThenApply(window.NB_HIGHLIGHTS || []);
    }

    go();
  }

  // Expose for runtime updates
  window.NB_applyHighlights = function (list) {
    // Save latest list so retries use newest data
    window.NB_HIGHLIGHTS = list || [];
    applyWhenReady();
  };

  // Optional initial run if NB_HIGHLIGHTS is preset
  function ready() {
    if (Array.isArray(window.NB_HIGHLIGHTS) && window.NB_HIGHLIGHTS.length) {
      applyWhenReady(); // important: retry-safe initial apply
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ready, { once: true });
  } else {
    ready();
  }
})();