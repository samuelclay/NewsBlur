// Fills every .wave element with rounded bars shaped like a speech waveform. Deterministic, so renders repeat.
document.querySelectorAll('.wave').forEach(function (wave) {
  var count = parseInt(wave.dataset.bars || '90', 10);
  var bar = parseFloat(wave.dataset.bar || '8');
  var gap = parseFloat(wave.dataset.gap || '8');
  var height = parseFloat(wave.dataset.height || '300');
  var seed = parseFloat(wave.dataset.seed || '1');
  wave.style.gap = gap + 'px';
  for (var i = 0; i < count; i++) {
    var t = i / count;
    // Words: bursts of energy with short pauses between them, inside a gentle envelope.
    var envelope = 0.35 + 0.65 * Math.sin(Math.PI * t);
    var syllables = Math.abs(Math.sin(i * 0.9 + seed) * 0.6 + Math.sin(i * 0.37 + seed * 2) * 0.4);
    var pause = (Math.sin(i * 0.21 + seed * 3) > 0.82) ? 0.15 : 1;
    var h = Math.max(bar, height * envelope * (0.18 + 0.82 * syllables) * pause);
    var span = document.createElement('span');
    span.style.width = bar + 'px';
    span.style.height = h + 'px';
    wave.appendChild(span);
  }
});
