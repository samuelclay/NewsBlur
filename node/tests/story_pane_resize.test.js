const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repo_root = path.resolve(__dirname, '..', '..');

test('split story pane carousel stays aligned throughout live resizing', function () {
    const reader = fs.readFileSync(
        path.join(repo_root, 'media/js/newsblur/reader/reader.js'),
        'utf8'
    );
    const duration_uses = reader.match(/'duration': story_pane_animation_duration/g) || [];
    const view_moves = reader.match(/this\.position_story_pane\('(page|feed|text|story)', options\);/g) || [];

    assert.match(
        reader,
        /var story_pane_animation_duration\s*=\s*options\.resize\s*\?\s*0\s*:/
    );
    assert.equal(duration_uses.length, 1);
    assert.equal(view_moves.length, 4);
    assert.match(reader, /story_pane_view_for_resize:\s*function/);
    assert.match(reader, /'page':\s*0/);
    assert.match(reader, /'feed':\s*1/);
    assert.match(reader, /'text':\s*2/);
    assert.match(reader, /'story':\s*3/);
    assert.match(reader, /page_view_showing_feed_view/);
    assert.match(reader, /feed_view_showing_story_view/);
    assert.match(reader, /temporary_story_view/);
    assert.match(reader, /this\.align_story_pane_to_current_view\(\);/);
    assert.match(reader, /position_story_pane:\s*function/);
    assert.match(
        reader,
        /options\.resize\s*\?\s*-100 \* offset_multiplier \+ '%'\s*:/
    );
    assert.match(
        reader,
        /this\.\$s\.\$story_pane\.stop\(true\)\.css\('left', story_pane_position\);/
    );
});
