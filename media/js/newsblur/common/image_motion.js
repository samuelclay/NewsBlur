// image_motion.js expands unlinked article images without changing linked-image navigation.
$(document).on('click.nb-image-motion', '.NB-feed-story-content img', function (event) {
    if (event.button || event.metaKey || event.ctrlKey || event.shiftKey ||
        $(this).closest('a, button').length || !this.naturalWidth || !window.HTMLDialogElement) return;
    var source = this;
    var previous_focus = document.activeElement;
    var dialog = document.createElement('dialog');
    dialog.className = 'NB-motion-image-viewer';
    var image = document.createElement('img');
    image.src = source.currentSrc || source.src;
    image.alt = source.alt || '';
    var close = document.createElement('button');
    close.type = 'button';
    close.textContent = '×';
    close.setAttribute('aria-label', gettext('Close'));
    dialog.appendChild(image);
    dialog.appendChild(close);
    document.body.appendChild(dialog);
    dialog.showModal();
    close.focus({ preventScroll: true });
    var closing = false;
    function source_transform() {
        var from = source.getBoundingClientRect();
        var to = image.getBoundingClientRect();
        if (!source.isConnected || !to.width || !from.width || from.bottom < 0 || from.top > innerHeight) return null;
        return 'translate(' + (from.left + from.width / 2 - to.left - to.width / 2) + 'px,' +
            (from.top + from.height / 2 - to.top - to.height / 2) + 'px) scale(' + from.width / to.width + ',' + from.height / to.height + ')';
    }
    function remove() {
        release_keyboard();
        dialog.close();
        dialog.remove();
        if (previous_focus && previous_focus.isConnected) previous_focus.focus({ preventScroll: true });
    }
    function dismiss() {
        if (closing) return;
        closing = true;
        var transform = source_transform();
        if (!transform || window.matchMedia('(prefers-reduced-motion: reduce)').matches) { remove(); return; }
        image.getAnimations().forEach(function (animation) { animation.cancel(); });
        var animation = image.animate([{ transform: 'none', opacity: 1 }, { transform: transform, opacity: 0 }],
            { duration: 220, easing: 'ease-in-out', fill: 'forwards' });
        animation.onfinish = remove;
        animation.oncancel = remove;
    }
    close.onclick = dismiss;
    dialog.onclick = function (e) { if (e.target === dialog || e.target === image) dismiss(); };
    function handle_keydown(e) {
        // image_motion.js keeps reader shortcuts outside the modal while preserving native buttons and Tab.
        // Modifier events still reach jquery.hotkeys.js so its pressed/released state stays current.
        if (['Shift', 'Control', 'Alt', 'Meta'].indexOf(e.key) !== -1 ||
            [16, 17, 18, 91, 93, 224].indexOf(e.keyCode || e.which) !== -1) return;
        e.stopImmediatePropagation();
        // image_motion.js also recognizes the key codes used by jquery.hotkeys.js and runs the same accessible dismissal.
        if (e.key === 'Escape' || e.key === 'Esc' || e.keyCode === 27 || e.which === 27) {
            e.preventDefault();
            dismiss();
        }
    }
    function handle_keypress(e) { e.stopImmediatePropagation(); }
    function release_keyboard() {
        document.removeEventListener('keydown', handle_keydown, true);
        document.removeEventListener('keypress', handle_keypress, true);
    }
    // image_motion.js uses document capture because native Tab can move focus outside the dialog's DOM subtree.
    document.addEventListener('keydown', handle_keydown, true);
    document.addEventListener('keypress', handle_keypress, true);
    dialog.addEventListener('close', release_keyboard);
    dialog.addEventListener('cancel', function (e) { e.preventDefault(); dismiss(); });
    function reveal() {
        if (closing || !dialog.isConnected) return;
        var transform = source_transform();
        if (!transform || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
        image.animate([{ transform: transform, opacity: .4 }, { transform: 'none', opacity: 1 }],
            { duration: 350, easing: 'cubic-bezier(.18,1.15,.36,1)' });
        NEWSBLUR.motion.enter(close, 80, 8);
    }
    if (image.complete) requestAnimationFrame(reveal);
    else image.onload = reveal;
});
