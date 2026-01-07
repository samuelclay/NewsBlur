// Reusable icon picker component for folder and feed icons
// Used by reader_feed_exception.js for both folder and feed icon selection

NEWSBLUR.IconPicker = {
    // Lucide outline icons organized by category
    PRESET_ICON_CATEGORIES: [
        { label: 'Files', icons: ['folder', 'folder-open', 'file', 'file-text', 'files', 'archive', 'folder-archive', 'folder-check', 'folder-cog', 'folder-heart'] },
        { label: 'Places', icons: ['home', 'building', 'building-2', 'store', 'landmark', 'factory', 'warehouse', 'castle', 'church', 'hospital'] },
        { label: 'Favorites', icons: ['star', 'heart', 'bookmark', 'flag', 'tag', 'tags', 'award', 'crown', 'gem', 'diamond'] },
        { label: 'Reading', icons: ['book', 'book-open', 'book-marked', 'library', 'newspaper', 'scroll', 'notebook', 'graduation-cap', 'school', 'brain'] },
        { label: 'Audio', icons: ['music', 'headphones', 'mic', 'radio', 'podcast', 'disc', 'album', 'bluetooth', 'signal', 'atom'] },
        { label: 'Visual', icons: ['video', 'film', 'tv', 'monitor', 'camera', 'image', 'images', 'eye', 'gamepad-2', 'dice-5'] },
        { label: 'Travel', icons: ['trophy', 'medal', 'target', 'puzzle', 'bike', 'ship', 'rocket', 'plane', 'train', 'bus'] },
        { label: 'Tech', icons: ['code', 'terminal', 'database', 'server', 'cpu', 'hard-drive', 'wifi', 'globe', 'rss', 'git-merge'] },
        { label: 'Nature', icons: ['sun', 'moon', 'cloud', 'umbrella', 'tree-pine', 'flower-2', 'leaf', 'droplets', 'snowflake', 'wind'] },
        { label: 'Food', icons: ['coffee', 'utensils', 'chef-hat', 'pizza', 'apple', 'cake', 'cookie', 'ice-cream-cone', 'thermometer', 'flame'] },
        { label: 'Shopping', icons: ['shopping-cart', 'shopping-bag', 'gift', 'package', 'wallet', 'credit-card', 'coins', 'piggy-bank', 'box', 'briefcase'] },
        { label: 'Social', icons: ['mail', 'message-square', 'phone', 'at-sign', 'send', 'inbox', 'users', 'user', 'contact', 'hand'] }
    ],

    // Heroicons solid icons organized by category
    FILLED_ICON_CATEGORIES: [
        { label: 'Files', icons: ['folder', 'folder-open', 'document', 'document-text', 'document-chart-bar', 'archive-box', 'clipboard', 'clipboard-document', 'inbox', 'rectangle-stack'] },
        { label: 'Places', icons: ['home', 'building-office', 'building-library', 'building-storefront', 'map', 'map-pin', 'globe-alt', 'globe-americas', 'academic-cap', 'briefcase'] },
        { label: 'People', icons: ['users', 'user', 'face-smile', 'face-frown', 'identification', 'hand-raised', 'hand-thumb-up'] },
        { label: 'Messages', icons: ['envelope', 'phone', 'megaphone', 'chat-bubble-left', 'chat-bubble-bottom-center', 'chat-bubble-left-right', 'paper-airplane', 'at-symbol', 'hashtag', 'signal'] },
        { label: 'Media', icons: ['musical-note', 'film', 'camera', 'photo', 'video-camera', 'tv', 'radio', 'play', 'speaker-wave', 'microphone'] },
        { label: 'Markers', icons: ['star', 'heart', 'bookmark', 'flag', 'tag', 'sparkles', 'trophy', 'gift', 'ticket', 'cake'] },
        { label: 'Creative', icons: ['book-open', 'newspaper', 'pencil', 'paint-brush', 'scissors', 'paper-clip', 'light-bulb', 'puzzle-piece', 'swatch', 'eye'] },
        { label: 'Finance', icons: ['shopping-cart', 'wallet', 'banknotes', 'credit-card', 'currency-dollar', 'receipt-percent', 'calculator', 'chart-bar', 'chart-pie', 'table-cells'] },
        { label: 'Devices', icons: ['computer-desktop', 'device-phone-mobile', 'device-tablet', 'printer', 'server', 'server-stack', 'cpu-chip', 'wifi', 'code-bracket', 'command-line'] },
        { label: 'Tools', icons: ['cog-6-tooth', 'wrench', 'adjustments-horizontal', 'bars-3', 'magnifying-glass', 'key', 'lock-closed', 'lock-open', 'bell', 'trash'] },
        { label: 'Security', icons: ['finger-print', 'shield-check', 'link', 'qr-code', 'rss'] },
        { label: 'Weather', icons: ['sun', 'moon', 'cloud', 'fire', 'bolt', 'bolt-slash'] },
        { label: 'Science', icons: ['beaker', 'bug-ant', 'scale', 'lifebuoy'] },
        { label: 'Objects', icons: ['truck', 'rocket-launch', 'cube', 'square-2-stack', 'language', 'clock', 'calendar'] },
        { label: 'Arrows', icons: ['arrow-path', 'arrow-down-tray', 'arrow-up-tray', 'arrow-up-circle', 'arrow-down-circle', 'backspace'] },
        { label: 'Status', icons: ['check-circle', 'x-circle', 'plus-circle', 'minus-circle', 'question-mark-circle', 'exclamation-circle', 'exclamation-triangle', 'information-circle'] }
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
                        $.make('span', { className: 'NB-folder-icon-upload-hint' }, 'PNG, JPG, or GIF')
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
    },

    // Helper to get icon URL from icon data
    get_icon_url: function (icon_type, icon_data, icon_set) {
        if (icon_type === 'upload') {
            return 'data:image/png;base64,' + icon_data;
        } else if (icon_type === 'preset') {
            icon_set = icon_set || 'lucide';
            return NEWSBLUR.Globals.MEDIA_URL + 'img/icons/' + icon_set + '/' + icon_data + '.svg';
        } else if (icon_type === 'emoji') {
            return 'emoji:' + icon_data;
        }
        return null;
    },

    // Build an icon preview element from icon data
    make_icon_preview: function (icon_type, icon_data, icon_color, icon_set, size) {
        size = size || 16;
        var has_color = icon_color && icon_color !== '#000000';

        if (icon_type === 'emoji') {
            return $.make('span', { className: 'NB-folder-emoji', style: 'font-size: ' + size + 'px' }, icon_data);
        } else if (icon_type === 'preset') {
            icon_set = icon_set || 'lucide';
            var icon_url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/' + icon_set + '/' + icon_data + '.svg';
            if (has_color) {
                var $colored = $.make('span', { className: 'NB-folder-icon-colored' });
                $colored.css({
                    'display': 'inline-block',
                    'width': size + 'px',
                    'height': size + 'px',
                    'background-color': icon_color,
                    '-webkit-mask-image': 'url(' + icon_url + ')',
                    'mask-image': 'url(' + icon_url + ')',
                    '-webkit-mask-size': 'contain',
                    'mask-size': 'contain',
                    '-webkit-mask-repeat': 'no-repeat',
                    'mask-repeat': 'no-repeat',
                    '-webkit-mask-position': 'center',
                    'mask-position': 'center'
                });
                return $colored;
            } else {
                return $.make('img', { className: 'feed_favicon', src: icon_url, style: 'width: ' + size + 'px; height: ' + size + 'px' });
            }
        } else if (icon_type === 'upload') {
            return $.make('img', { className: 'feed_favicon', src: 'data:image/png;base64,' + icon_data, style: 'width: ' + size + 'px; height: ' + size + 'px' });
        }
        return null;
    }
};
