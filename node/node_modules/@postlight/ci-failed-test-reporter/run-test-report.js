const path = require('path');

const comment = require(path.join(__dirname, '/index.js')).comment;

comment(path.join(__dirname, '/test-output.json'));
