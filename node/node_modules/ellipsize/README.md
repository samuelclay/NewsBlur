# ellipsize

[![Build Status](https://travis-ci.org/mvhenten/ellipsize.svg?branch=master)](https://travis-ci.org/mvhenten/ellipsize)

Ellipsizes a string near a word boundary.

An ellipsized text looks much better if the ellipsize was added at the end of the
last full word instead of somewhere in the middle - especially if there are very
few characters remaining.

## Why make a module for something sooo simple

Off by one errors.

I've written a couple of ellipsize functions, and got it wrong on edge cases
several times. It's not rocket science, but something as simple as this you should
write in five minutes right? Never mind the unit test.

This ellipsize function is robust and tested against a couple of edge cases.
It's written to be fast, work in any browser and have no dependencies at all.

It simply loops over all the characters using a single function call, storing the
last location of an allowed break point, if any. Otherwise it just truncates the string
or return empty string if `truncate` options set up to `false` (in some cases its just better).

## Examples

```javascript

    var ellipsize = require('ellipsize');

    ellipsize('');
    // ''
    ellipsize(undefined);
    // ''
    ellipsize('one two three four', 8 );
    // 'one two…'
    ellipsize('one two-three four', 8 );
    // 'one two…'
    ellipsize('one two three four', 100 );
    // 'one two three four'
    ellipsize('12345678910')
    // '1234567…'
    ellipsize('abc', 0 );
    // ''

```
You may provide an alternative ellipse character, or "break points" like so:

```javascript
    var ellipsize = require('ellipsize');

    ellipsize( 'one two&three four', 8, { chars: [' ', '&'], ellipse: '→' });
    // 'one two→'

```

Also you may provide a setting to `truncate` words:

```javascript
    var ellipsize = require('ellipsize');

    ellipsize( '123456789ABCDEF', 8, { truncate: false });
    // '' 

    // its default settings
    ellipsize( '123456789ABCDEF', 8, { truncate: true });
    // '1234567…'

```

## Copyright

The MIT License (MIT)

Copyright (c) 2014 Matthijs van Henten

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE


