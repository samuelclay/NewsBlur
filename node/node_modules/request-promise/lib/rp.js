'use strict';

var Bluebird = require('bluebird').getNewLibraryCopy(),
    configure = require('request-promise-core/configure/request2'),
    stealthyRequire = require('stealthy-require');

try {

    // Load Request freshly - so that users can require an unaltered request instance!
    var request = stealthyRequire(require.cache, function () {
        return require('request');
    },
    function () {
        require('tough-cookie');
    }, module);

} catch (err) {
    /* istanbul ignore next */
    var EOL = require('os').EOL;
    /* istanbul ignore next */
    console.error(EOL + '###' + EOL + '### The "request" library is not installed automatically anymore.' + EOL + '### But is a dependency of "request-promise".' + EOL + '### Please install it with:' + EOL + '### npm install request --save' + EOL + '###' + EOL);
    /* istanbul ignore next */
    throw err;
}

Bluebird.config({cancellation: true});

configure({
    request: request,
    PromiseImpl: Bluebird,
    expose: [
        'then',
        'catch',
        'finally',
        'cancel',
        'promise'
        // Would you like to expose more Bluebird methods? Try e.g. `rp(...).promise().tap(...)` first. `.promise()` returns the full-fledged Bluebird promise.
    ],
    constructorMixin: function (resolve, reject, onCancel) {
        var self = this;
        onCancel(function () {
            self.abort();
        });
    }
});

request.bindCLS = function RP$bindCLS() {
    throw new Error('CLS support was dropped. To get it back read: https://github.com/request/request-promise/wiki/Getting-Back-Support-for-Continuation-Local-Storage');
};


module.exports = request;
