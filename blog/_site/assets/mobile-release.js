// mobile-release.js plays visible demonstrations and honors reduced motion and manual pauses.
(function () {
    var reduced_motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    document.querySelectorAll('.mobile-release-phone video').forEach(function (video) {
        var button = video.closest('figure').querySelector('.mobile-release-phone__play');
        var manually_paused = false;
        var manually_played = false;
        var visible = false;
        video.muted = true;
        video.controls = false;
        button.hidden = false;

        function update_button() {
            button.textContent = video.paused ? 'Play animation' : 'Pause animation';
        }
        function play() {
            video.play().catch(update_button);
        }
        function update_playback() {
            var motion_allowed = manually_played || !reduced_motion.matches;
            if (visible && !document.hidden && motion_allowed && !manually_paused) play();
            else video.pause();
        }
        button.addEventListener('click', function () {
            if (video.paused) { manually_paused = false; manually_played = true; play(); }
            else { manually_paused = true; manually_played = false; video.pause(); }
        });
        video.addEventListener('play', update_button);
        video.addEventListener('pause', update_button);
        document.addEventListener('visibilitychange', update_playback);
        if (typeof reduced_motion.addEventListener === 'function') {
            reduced_motion.addEventListener('change', update_playback);
        } else {
            reduced_motion.addListener(update_playback);
        }
        new IntersectionObserver(function (entries) {
            visible = entries[0].isIntersecting;
            update_playback();
        }, { threshold: 0.25 }).observe(video);
    });
})();
