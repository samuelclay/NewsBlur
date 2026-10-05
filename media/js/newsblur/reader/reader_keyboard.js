NEWSBLUR.ReaderKeyboard = function (options) {
  var defaults = {
    width: 700
  };

  this.options = $.extend({}, defaults, options);
  this.runner();
};

NEWSBLUR.ReaderKeyboard.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderKeyboard.prototype.constructor = NEWSBLUR.ReaderKeyboard;

_.extend(NEWSBLUR.ReaderKeyboard.prototype, {

  runner: function () {
    this.make_modal();
    this.handle_cancel();
    this.open_modal();

    this.$modal.bind('click', $.rescope(this.handle_click, this));
  },

  make_modal: function () {
    var self = this;

    this.$modal = $.make('div', { className: 'NB-modal-keyboard NB-modal' }, [
      $.make('div', { className: 'NB-modal-tabs' }, [
        $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-general' }, gettext('General')),
        $.make('div', { className: 'NB-modal-tab NB-modal-tab-feeds' }, gettext('Feeds')),
        $.make('div', { className: 'NB-modal-tab NB-modal-tab-stories' }, gettext('Stories'))
      ]),
      $.make('h2', { className: 'NB-modal-title' }, [
        $.make('div', { className: 'NB-icon' }),
        gettext('Keyboard shortcuts'),
        $.make('div', { className: 'NB-icon-dropdown' })
      ]),

      // General

      $.make('div', { className: 'NB-tab NB-tab-general NB-active' }, [
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Switch views')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('&#x2190;')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('&#x2192;')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Quick search for a site')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('g')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Dashboard')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('esc')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('d')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Open Everything')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('e')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Hide sites')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('u')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Full screen')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('f')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Switch focus/unread')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              '+'
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              '-'
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('View keyboard shortcuts')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              '?'
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Add site/folder')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('a')
            ])
          ])
        ])
      ]),

      // Feeds

      $.make('div', { className: 'NB-tab NB-tab-feeds' }, [
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Next site')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('&#x2193;')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('j')
            ])
            // TODO: Mention "shift + n" here? It will be too wide.
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Prev. site')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('&#x2191;')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('k')
            ])
            // TODO: Mention "shift + p" here? It will be too wide.
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Open site/feed trainer')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('t')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Open story trainer')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('t')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Mark all as read')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('a')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Oldest unread story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('m')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Reload feed/folder')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('r')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Search feed')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              '/'
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Toggle unread/all')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('L')
            ])
          ])
        ])
      ]),

      // Stories

      $.make('div', { className: 'NB-tab NB-tab-stories' }, [
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Next story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('&#x2193;')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('j')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Previous story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('&#x2191;')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('k')
            ])
          ])
        ]),

        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Open in Story view')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('enter')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Open in Text view')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('enter')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Page down')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('space')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Page up')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('space')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Next Unread Story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('n')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Toggle read/unread')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('u')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('m')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Mark below stories read')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('b')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Mark above stories read')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('y')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Save/Unsave story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('s')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Email story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('e')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Open in background tab')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('o')
            ]),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('v')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Open in new window')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('v')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Expand story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('x')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Collapse story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('x')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Share this story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('shift'),
              $.make('span', '+'),
              gettext('s')
            ])
          ]),
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Save comments')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('ctrl'),
              $.make('span', '+'),
              gettext('enter')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Scroll to comments')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('c')
            ])
          ])
        ]),
        $.make('div', { className: 'NB-keyboard-group' }, [
          $.make('div', { className: 'NB-keyboard-shortcut' }, [
            $.make('div', { className: 'NB-keyboard-shortcut-explanation' }, gettext('Ask AI about story')),
            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
              gettext('i')
            ])
          ])
        ])
      ])
    ]);
  },

  handle_cancel: function () {
    var $cancel = $('.NB-modal-cancel', this.$modal);

    $cancel.click(function (e) {
      e.preventDefault();
      $.modal.close();
    });
  },

  // ===========
  // = Actions =
  // ===========

  handle_click: function (elem, e) {
    var self = this;

    $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function ($t, $p) {
      e.preventDefault();
      var newtab;
      if ($t.hasClass('NB-modal-tab-general')) {
        newtab = 'general';
      } else if ($t.hasClass('NB-modal-tab-feeds')) {
        newtab = 'feeds';
      } else if ($t.hasClass('NB-modal-tab-stories')) {
        newtab = 'stories';
      }
      self.switch_tab(newtab);
    });
  }

});
