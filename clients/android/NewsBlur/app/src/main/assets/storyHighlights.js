(function () {
  if (window.NB_HIGHLIGHTS_BOOT) return;
  window.NB_HIGHLIGHTS_BOOT = true;

  function apply(list) {
    try {
      var arr = (list || []).filter(Boolean);
      if (!arr.length) return;
      var ctx = document.querySelector('.NB-story') || document.body;
      var mk = new Mark(ctx);
      mk.mark(arr, {
        className: 'NB-starred-story-selection-highlight',
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
    var ctx = document.querySelector('.NB-story') || document.body;
    var mk = new Mark(ctx);
    mk.unmark({
      className: 'NB-starred-story-selection-highlight',
      done: function () { apply(list); }
    });
  }

  // Expose for runtime updates
  window.NB_applyHighlights = unmarkThenApply;

  // Optional initial run if NB_HIGHLIGHTS is preset
  function ready() {
    if (Array.isArray(window.NB_HIGHLIGHTS)) apply(window.NB_HIGHLIGHTS);
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ready, { once: true });
  } else {
    ready();
  }
})();
