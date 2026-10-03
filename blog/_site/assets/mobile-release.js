// mobile-release.js plays visible demonstrations and honors reduced motion and manual pauses.
(function () {
    var reduced_motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    document.querySelectorAll('.mobile-release-phone video').forEach(function (video) {
        var caption = video.closest('figure').querySelector('figcaption');
        var button = document.createElement('button');
        button.type = 'button';
        button.className = 'mobile-release-phone__play';
        caption.insertBefore(button, caption.querySelector('.mobile-release-phone__download'));
        var manually_paused = false;
        var manually_played = false;
        var visible = false;
        video.muted = true;
        video.controls = false;

        function update_button() {
            button.textContent = video.paused ? 'Play animation' : 'Pause animation';
            button.setAttribute('aria-label', button.textContent + ': ' + video.getAttribute('aria-label'));
        }
        function play() {
            video.play().catch(update_button);
        }
        function update_playback() {
            var motion_allowed = manually_played || !reduced_motion.matches;
            if (visible && !document.hidden && motion_allowed && !manually_paused) play();
            else video.pause();
        }
        update_button();
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
            visible = entries[entries.length - 1].isIntersecting;
            update_playback();
        }, { threshold: 0.25 }).observe(video);
    });
})();
