// mobile-release.js plays visible demonstrations and honors reduced motion. With reduced motion
// on, clips stay still and show the browser's own controls so they can still be played by hand.
(function () {
    var reduced_motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    document.querySelectorAll('.mobile-release-phone video').forEach(function (video) {
        var visible = false;
        video.muted = true;
        video.controls = reduced_motion.matches;

        function update_playback() {
            video.controls = reduced_motion.matches;
            if (!visible || document.hidden) video.pause();
            else if (!reduced_motion.matches) video.play().catch(function () {});
        }
        document.addEventListener('visibilitychange', update_playback);
        if (typeof reduced_motion.addEventListener === 'function') {
            reduced_motion.addEventListener('change', update_playback);
        } else {
            reduced_motion.addListener(update_playback);
        }
        new IntersectionObserver(function (entries) {
            visible = entries[entries.length - 1].isIntersecting;
            update_playback();
        }, { threshold: 0.25 }).observe(video);
    });
})();
