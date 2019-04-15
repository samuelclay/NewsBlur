# String Direction
String Direction is a JavaScript library for detection of direction of `String` objects in JavaScript.

## Usage

### `#getDirection`
``` javascript
var stringDirection = require('string-direction');

stringDirection.getDirection("Hello, world!"); // 'ltr'
stringDirection.getDirection("سلام دنیا"); // 'rtl'
```
### `#patch` Patching String objects globally
By using `patch()` method a `getDirection` method will be exposed in `String` object.

``` javascript
require('string-direction').patch();

"Hello, world!".getDirection(); // "ltr"
"سلام دنیا".getDirection(); // "rtl"
```

## Installation
String Direction works both in browser or NodeJS environment
### Node
Install via NPM
``` shell
npm install string-direction
```
### Browser
Use `script` tag to include the library


## Credits
This library is influenced by [string-direction](https://github.com/laMarciana/string-direction) Ruby library by Marc Busqué

### License
MIT

