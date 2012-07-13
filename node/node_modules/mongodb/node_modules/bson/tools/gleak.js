
var gleak = require('gleak')();
gleak.ignore('AssertionError');
gleak.ignore('testFullSpec_param_found');
gleak.ignore('events');
gleak.ignore('Uint8Array');

module.exports = gleak;
