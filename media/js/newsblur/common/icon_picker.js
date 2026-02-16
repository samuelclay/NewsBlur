// Reusable icon picker component for folder and feed icons
// Used by reader_feed_exception.js for both folder and feed icon selection

NEWSBLUR.IconPicker = {
    // Lucide outline icons organized by category
    PRESET_ICON_CATEGORIES: [
        { label: 'Files', icons: ['folder', 'folder-open', 'folder-archive', 'folder-check', 'folder-cog', 'folder-heart', 'folder-minus', 'folder-plus', 'folders', 'file', 'file-text', 'file-badge', 'file-check', 'file-cog', 'file-lock', 'files', 'archive', 'clipboard', 'inbox', 'layers'] },
        { label: 'Places', icons: ['home', 'house', 'building', 'building-2', 'store', 'landmark', 'factory', 'warehouse', 'castle', 'church', 'hospital', 'tent', 'mountain', 'fence', 'school'] },
        { label: 'Favorites', icons: ['star', 'heart', 'heart-handshake', 'bookmark', 'flag', 'tag', 'tags', 'award', 'crown', 'gem', 'diamond', 'sparkles', 'trophy', 'medal'] },
        { label: 'Reading', icons: ['book', 'book-open', 'book-marked', 'library', 'newspaper', 'scroll', 'notebook', 'graduation-cap', 'brain', 'kanban', 'sticker'] },
        { label: 'Audio', icons: ['music', 'headphones', 'headset', 'mic', 'radio', 'podcast', 'disc', 'album', 'boom-box', 'cassette-tape', 'speaker', 'drum', 'bluetooth', 'signal'] },
        { label: 'Visual', icons: ['video', 'video-off', 'film', 'tv', 'monitor', 'camera', 'image', 'images', 'eye', 'eye-off', 'picture-in-picture', 'youtube'] },
        { label: 'Games', icons: ['gamepad-2', 'joystick', 'dice-5', 'puzzle', 'drama', 'wand', 'wand-2', 'origami'] },
        { label: 'Sports', icons: ['volleyball', 'dumbbell', 'target', 'bike', 'trophy', 'medal', 'thumbs-up'] },
        { label: 'Travel', icons: ['plane', 'ship', 'sailboat', 'rocket', 'train', 'bus', 'car', 'tractor', 'cable-car', 'backpack', 'compass', 'navigation', 'map', 'map-pin'] },
        { label: 'Tech', icons: ['code', 'terminal', 'database', 'server', 'cpu', 'hard-drive', 'laptop', 'computer', 'keyboard', 'mouse', 'printer', 'usb', 'wifi', 'globe', 'rss', 'git-merge', 'git-branch', 'webhook', 'scan', 'settings'] },
        { label: 'Nature', icons: ['sun', 'sun-dim', 'sun-snow', 'sunrise', 'sunset', 'moon', 'cloud', 'umbrella', 'tree-pine', 'tree-deciduous', 'flower-2', 'leaf', 'clover', 'droplets', 'snowflake', 'wind', 'haze', 'orbit', 'earth'] },
        { label: 'Animals', icons: ['bird', 'cat', 'dog', 'fish', 'rabbit', 'turtle', 'bug', 'feather', 'egg', 'baby', 'shrimp'] },
        { label: 'Food', icons: ['coffee', 'utensils', 'chef-hat', 'pizza', 'sandwich', 'croissant', 'apple', 'banana', 'cherry', 'citrus', 'grape', 'carrot', 'beef', 'drumstick', 'soup', 'popcorn', 'cake', 'cookie', 'lollipop', 'popsicle', 'ice-cream-cone', 'flame', 'wine', 'martini', 'bottle-wine', 'cup-soda', 'milk'] },
        { label: 'Shopping', icons: ['shopping-cart', 'shopping-bag', 'shopping-basket', 'gift', 'package', 'wallet', 'credit-card', 'coins', 'piggy-bank', 'box', 'briefcase', 'ticket', 'barcode'] },
        { label: 'Home', icons: ['bed', 'bath', 'lamp', 'lamp-ceiling', 'lamp-desk', 'lamp-floor', 'refrigerator', 'washing-machine'] },
        { label: 'Health', icons: ['stethoscope', 'syringe', 'thermometer', 'thermometer-sun', 'test-tube', 'microscope'] },
        { label: 'Fashion', icons: ['shirt', 'glasses', 'watch'] },
        { label: 'Tools', icons: ['hammer', 'wrench', 'scissors', 'ruler', 'highlighter', 'paintbrush', 'palette', 'brush', 'pen', 'pencil-line', 'stamp', 'key', 'lock', 'link', 'magnet', 'plug', 'battery', 'flashlight', 'hourglass', 'timer', 'clock', 'calendar'] },
        { label: 'Social', icons: ['mail', 'mailbox', 'message-square', 'message-circle', 'phone', 'at-sign', 'send', 'users', 'user', 'contact', 'hand', 'handshake', 'megaphone', 'share-2'] },
        { label: 'Status', icons: ['circle-check', 'circle-x', 'repeat', 'undo', 'upload', 'search', 'trash', 'x', 'recycle'] },
        { label: 'Misc', icons: ['anchor', 'axe', 'barrel', 'bell', 'binoculars', 'bone', 'candy', 'cone', 'construction', 'fan', 'fuel', 'hash', 'hop', 'logs', 'milestone', 'pin', 'satellite', 'skull', 'slice', 'sword', 'table', 'telescope', 'traffic-cone', 'vegan', 'weight', 'wheat', 'zap', 'atom', 'dna', 'hexagon', 'triangle', 'circle', 'square', 'octagon', 'lightbulb'] }
    ],

    // Heroicons solid icons organized by category
    FILLED_ICON_CATEGORIES: [
        { label: 'Files', icons: ['folder', 'folder-open', 'folder-plus', 'folder-minus', 'folder-arrow-down', 'document', 'document-text', 'document-chart-bar', 'document-check', 'document-duplicate', 'document-plus', 'document-minus', 'document-arrow-down', 'document-arrow-up', 'document-magnifying-glass', 'archive-box', 'clipboard', 'clipboard-document', 'clipboard-document-check', 'clipboard-document-list', 'inbox', 'inbox-arrow-down', 'inbox-stack', 'rectangle-stack', 'circle-stack', 'square-3-stack-3d'] },
        { label: 'Places', icons: ['home', 'home-modern', 'building-office', 'building-office-2', 'building-library', 'building-storefront', 'map', 'map-pin', 'globe-alt', 'globe-americas', 'globe-asia-australia', 'globe-europe-africa', 'academic-cap', 'briefcase'] },
        { label: 'People', icons: ['users', 'user', 'user-circle', 'user-group', 'user-plus', 'user-minus', 'face-smile', 'face-frown', 'identification', 'hand-raised', 'hand-thumb-up', 'hand-thumb-down'] },
        { label: 'Messages', icons: ['envelope', 'envelope-open', 'phone', 'megaphone', 'chat-bubble-left', 'chat-bubble-bottom-center', 'chat-bubble-left-right', 'chat-bubble-oval-left', 'chat-bubble-oval-left-ellipsis', 'paper-airplane', 'at-symbol', 'hashtag', 'signal', 'signal-slash', 'share'] },
        { label: 'Media', icons: ['musical-note', 'film', 'camera', 'photo', 'video-camera', 'tv', 'radio', 'play', 'play-circle', 'pause', 'pause-circle', 'play-pause', 'stop', 'backward', 'forward', 'speaker-wave', 'speaker-x-mark', 'microphone', 'gif'] },
        { label: 'Markers', icons: ['star', 'heart', 'bookmark', 'bookmark-square', 'bookmark-slash', 'flag', 'tag', 'sparkles', 'trophy', 'gift', 'ticket', 'cake', 'check-badge'] },
        { label: 'Creative', icons: ['book-open', 'newspaper', 'pencil', 'paint-brush', 'scissors', 'paper-clip', 'light-bulb', 'puzzle-piece', 'swatch', 'eye', 'eye-slash', 'eye-dropper', 'viewfinder-circle', 'italic', 'underline', 'strikethrough'] },
        { label: 'Finance', icons: ['shopping-cart', 'shopping-bag', 'wallet', 'banknotes', 'credit-card', 'currency-dollar', 'receipt-percent', 'calculator', 'chart-bar', 'chart-bar-square', 'chart-pie', 'presentation-chart-bar', 'presentation-chart-line', 'table-cells', 'arrow-trending-up', 'arrow-trending-down'] },
        { label: 'Devices', icons: ['computer-desktop', 'device-phone-mobile', 'device-tablet', 'printer', 'server', 'server-stack', 'cpu-chip', 'wifi', 'code-bracket', 'command-line', 'window', 'battery-100', 'battery-50', 'battery-0', 'power'] },
        { label: 'Tools', icons: ['cog-6-tooth', 'cog-8-tooth', 'cog', 'wrench', 'wrench-screwdriver', 'adjustments-horizontal', 'funnel', 'bars-3', 'bars-2', 'bars-4', 'list-bullet', 'numbered-list', 'queue-list', 'magnifying-glass', 'key', 'lock-closed', 'lock-open', 'bell', 'bell-alert', 'bell-slash', 'trash'] },
        { label: 'Security', icons: ['finger-print', 'shield-check', 'link', 'qr-code', 'rss', 'no-symbol'] },
        { label: 'Weather', icons: ['sun', 'moon', 'cloud', 'cloud-arrow-down', 'cloud-arrow-up', 'fire', 'bolt', 'bolt-slash'] },
        { label: 'Science', icons: ['beaker', 'bug-ant', 'scale', 'lifebuoy', 'variable', 'cube', 'cube-transparent'] },
        { label: 'Objects', icons: ['truck', 'rocket-launch', 'square-2-stack', 'squares-2x2', 'squares-plus', 'view-columns', 'language', 'clock', 'calendar', 'calendar-days', 'calendar-date-range'] },
        { label: 'Arrows', icons: ['arrow-path', 'arrow-down-tray', 'arrow-up-tray', 'arrow-up-circle', 'arrow-down-circle', 'arrows-pointing-out', 'arrows-pointing-in', 'chevron-up', 'chevron-down', 'chevron-left', 'chevron-right', 'chevron-double-up', 'chevron-double-down', 'chevron-double-left', 'chevron-double-right', 'backspace'] },
        { label: 'Status', icons: ['check-circle', 'check', 'x-circle', 'x-mark', 'plus-circle', 'plus', 'minus-circle', 'minus', 'question-mark-circle', 'exclamation-circle', 'exclamation-triangle', 'information-circle', 'ellipsis-horizontal', 'ellipsis-vertical', 'ellipsis-horizontal-circle'] },
        { label: 'Cursors', icons: ['cursor-arrow-rays', 'cursor-arrow-ripple'] }
    ],

    // Emojis organized by category
    EMOJI_CATEGORIES: [
        { label: 'Files', emojis: ['📁', '📂', '📚', '📖', '📰', '📄', '📑', '📋', '📝', '✏️'] },
        { label: 'Tech', emojis: ['💻', '📱', '📺', '🎬', '🎵', '🎧', '🎮', '📷', '📹', '🖨️'] },
        { label: 'Stars', emojis: ['⭐', '🌟', '✨', '💫', '⚡', '🔥', '💥', '❄️', '🌈', '🎇'] },
        { label: 'Weather', emojis: ['☀️', '🌙', '☁️', '🌧️', '⛈️', '🌪️', '🌊', '💧', '🌤️', '🌥️'] },
        { label: 'Nature', emojis: ['🌲', '🌳', '🌴', '🌻', '🌺', '🌸', '🌷', '🌹', '🍀', '🌿'] },
        { label: '', emojis: ['🍂', '🍁', '🌵', '🌾', '🌱', '🪴', '🎋', '🎍', '🍃', '☘️'] },
        { label: 'Food', emojis: ['☕', '🍵', '🍺', '🍷', '🥤', '🧃', '🍽️', '🍴', '🥢', '🧂'] },
        { label: '', emojis: ['🍕', '🍔', '🍟', '🌮', '🍜', '🍣', '🍰', '🍩', '🍎', '🍇'] },
        { label: 'Animals', emojis: ['🐶', '🐱', '🐦', '🐟', '🦋', '🐝', '🦊', '🐼', '🦁', '🐸'] },
        { label: '', emojis: ['🦄', '🐯', '🐻', '🐨', '🐰', '🦉', '🦅', '🐢', '🐬', '🦈'] },
        { label: 'Places', emojis: ['🏠', '🏢', '🏫', '🏥', '🏰', '⛪', '🕌', '🗼', '🏛️', '🎪'] },
        { label: 'Transport', emojis: ['✈️', '🚗', '🚲', '🚀', '⛵', '🚂', '🚁', '🛸', '🏎️', '🚌'] },
        { label: 'Sports', emojis: ['⚽', '🏀', '🎾', '🎯', '🏆', '🎭', '🎨', '🎸', '🎹', '🏋️'] },
        { label: 'Hearts', emojis: ['❤️', '💛', '💚', '💙', '💜', '🧡', '🖤', '🤍', '💖', '💝'] },
        { label: 'Status', emojis: ['✅', '❌', '⚠️', 'ℹ️', '❓', '🔔', '🔒', '🔑', '💡', '🎁'] },
        { label: 'Objects', emojis: ['💰', '💼', '🎓', '🏅', '💎', '🛒', '🌍', '🌎', '🌏', '🗺️'] },
        { label: 'Faces', emojis: ['😀', '😊', '🥳', '🤔', '😎', '🤩', '🙄', '😴', '🤗', '🥰'] },
        { label: 'Gestures', emojis: ['👍', '👎', '👋', '✋', '🤝', '🙏', '👏', '🎉', '🎊', '🔖'] }
    ],

    // Color palette organized by columns (each column is one hue, rows go light to dark)
    // 12 columns: Gray, Red, Pink, Purple, Indigo, Blue, Cyan, Teal, Green, Lime, Yellow, Orange
    COLOR_PALETTE: [
        // Row 1: Lightest
        '#f5f5f5', '#ffcdd2', '#f8bbd0', '#e1bee7', '#c5cae9', '#bbdefb', '#b3e5fc', '#b2dfdb', '#c8e6c9', '#dcedc8', '#fff9c4', '#ffe0b2',
        // Row 2: Light
        '#e0e0e0', '#ef9a9a', '#f48fb1', '#ce93d8', '#9fa8da', '#90caf9', '#81d4fa', '#80cbc4', '#a5d6a7', '#c5e1a5', '#fff59d', '#ffcc80',
        // Row 3: Medium-Light
        '#bdbdbd', '#e57373', '#f06292', '#ba68c8', '#7986cb', '#64b5f6', '#4fc3f7', '#4db6ac', '#81c784', '#aed581', '#fff176', '#ffb74d',
        // Row 4: Medium
        '#9e9e9e', '#f44336', '#ec407a', '#ab47bc', '#5c6bc0', '#42a5f5', '#29b6f6', '#26a69a', '#66bb6a', '#9ccc65', '#ffee58', '#ffa726',
        // Row 5: Medium-Dark
        '#757575', '#e53935', '#d81b60', '#8e24aa', '#3f51b5', '#1e88e5', '#039be5', '#00897b', '#43a047', '#7cb342', '#fdd835', '#ff9800',
        // Row 6: Dark
        '#616161', '#c62828', '#ad1457', '#6a1b9a', '#303f9f', '#1565c0', '#0277bd', '#00695c', '#2e7d32', '#558b2f', '#f9a825', '#ef6c00',
        // Row 7: Darkest
        '#424242', '#b71c1c', '#880e4f', '#4a148c', '#1a237e', '#0d47a1', '#01579b', '#004d40', '#1b5e20', '#33691e', '#f57f17', '#e65100'
    ],

    // Build the preset icons (Lucide outline) grid
    make_preset_icons: function () {
        var $container = $.make('div', { className: 'NB-folder-icon-presets-container' });

        _.each(this.PRESET_ICON_CATEGORIES, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-preset-row' }, [
                $.make('div', { className: 'NB-folder-icon-preset-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-preset-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-preset-items');
            _.each(category.icons, function (icon_name) {
                var $icon = $.make('div', { className: 'NB-folder-icon-preset', 'data-icon': icon_name }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/lucide/' + icon_name + '.svg' })
                ]);
                $items.append($icon);
            });
            $container.append($row);
        });

        return $container;
    },

    // Build the filled icons (Heroicons solid) grid
    make_filled_icons: function () {
        var $container = $.make('div', { className: 'NB-folder-icon-filled-container' });

        _.each(this.FILLED_ICON_CATEGORIES, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-filled-row' }, [
                $.make('div', { className: 'NB-folder-icon-filled-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-filled-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-filled-items');
            _.each(category.icons, function (icon_name) {
                var $icon = $.make('div', { className: 'NB-folder-icon-preset NB-folder-icon-filled', 'data-icon': icon_name, 'data-icon-set': 'heroicons-solid' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/heroicons-solid/' + icon_name + '.svg' })
                ]);
                $items.append($icon);
            });
            $container.append($row);
        });

        return $container;
    },

    // Build the emoji picker grid
    make_emoji_picker: function () {
        var $container = $.make('div', { className: 'NB-folder-icon-emojis-container' });

        _.each(this.EMOJI_CATEGORIES, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-emoji-row' }, [
                $.make('div', { className: 'NB-folder-icon-emoji-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-emoji-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-emoji-items');
            _.each(category.emojis, function (emoji) {
                var $emoji = $.make('div', { className: 'NB-folder-icon-emoji-option', 'data-emoji': emoji }, emoji);
                $items.append($emoji);
            });
            $container.append($row);
        });

        return $container;
    },

    // Build the color palette grid
    make_color_palette: function () {
        var $colors = $.make('div', { className: 'NB-folder-icon-colors-grid' });
        _.each(this.COLOR_PALETTE, function (color) {
            var $color = $.make('div', {
                className: 'NB-folder-icon-color',
                style: 'background-color: ' + color + (color === '#ffffff' ? '; border: 1px solid #ddd' : ''),
                'data-color': color
            });
            $colors.append($color);
        });

        return $colors;
    },

    // Build the upload section
    make_upload_section: function () {
        return $.make('div', { className: 'NB-folder-icon-section NB-folder-icon-upload-section' }, [
            $.make('div', { className: 'NB-folder-icon-upload-container' }, [
                $.make('input', { type: 'file', className: 'NB-folder-icon-file-input', accept: 'image/*' }),
                $.make('div', { className: 'NB-folder-icon-upload-button' }, [
                    $.make('div', { className: 'NB-folder-icon-upload-icon' }),
                    $.make('div', { className: 'NB-folder-icon-upload-text' }, [
                        $.make('span', { className: 'NB-folder-icon-upload-label' }, 'Upload Custom Image'),
                        $.make('span', { className: 'NB-folder-icon-upload-hint' }, 'PNG, JPG, GIF, SVG, or WebP \u2014 max 5 MB, any size')
                    ]),
                    $.make('div', { className: 'NB-loading' })
                ]),
                $.make('div', { className: 'NB-folder-icon-upload-preview' }),
                $.make('div', { className: 'NB-folder-icon-upload-error' })
            ])
        ]);
    },

    // Build the complete icon editor with all sections
    // Options:
    //   include_upload: boolean (default true) - whether to show upload section
    //   include_reset: boolean (default false) - whether to show reset button
    //   reset_label: string (default 'Clear icon') - label for reset button
    make_icon_editor: function (options) {
        options = options || {};
        var include_upload = options.include_upload !== false;
        var include_reset = options.include_reset === true;
        var reset_label = options.reset_label || 'Clear icon';

        var sections = [];

        if (include_upload) {
            sections.push(this.make_upload_section());
        }

        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Color'),
                this.make_color_palette()
            ])
        );

        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Outline Icons'),
                this.make_preset_icons()
            ])
        );

        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Filled Icons'),
                this.make_filled_icons()
            ])
        );

        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Emoji'),
                this.make_emoji_picker()
            ])
        );

        if (include_reset) {
            sections.push(
                $.make('div', { className: 'NB-folder-icon-section NB-folder-icon-reset-section' }, [
                    $.make('a', { className: 'NB-folder-icon-clear', href: '#' }, reset_label)
                ])
            );
        }

        return $.make('div', { className: 'NB-folder-icon-editor' }, sections);
    },

    // Update icon grid colors using mask-image technique
    update_icon_grid_colors: function ($container, color) {
        var has_color = color && color !== '#000000';

        $('.NB-folder-icon-preset img', $container).each(function () {
            var $img = $(this);
            var icon_url = $img.attr('src');

            if (has_color) {
                // Replace img with colored span using mask-image
                var $colored = $.make('span', { className: 'NB-folder-icon-colored-preview' });
                $colored.css({
                    'display': 'inline-block',
                    'width': '20px',
                    'height': '20px',
                    'background-color': color,
                    '-webkit-mask-image': 'url(' + icon_url + ')',
                    'mask-image': 'url(' + icon_url + ')',
                    '-webkit-mask-size': 'contain',
                    'mask-size': 'contain',
                    '-webkit-mask-repeat': 'no-repeat',
                    'mask-repeat': 'no-repeat',
                    '-webkit-mask-position': 'center',
                    'mask-position': 'center'
                });
                $colored.attr('data-original-src', icon_url);
                $img.replaceWith($colored);
            }
        });

        // Also handle already-colored previews
        $('.NB-folder-icon-preset .NB-folder-icon-colored-preview', $container).each(function () {
            var $preview = $(this);
            if (has_color) {
                $preview.css('background-color', color);
            } else {
                // Restore to original img
                var icon_url = $preview.attr('data-original-src');
                var $img = $.make('img', { src: icon_url });
                $preview.replaceWith($img);
            }
        });
    }
};
