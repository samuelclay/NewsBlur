<a href="http://promisesaplus.com/">
    <img src="https://promises-aplus.github.io/promises-spec/assets/logo-small.png" align="right" alt="Promises/A+ logo" />
</a>

# Request-Promise

[![Gitter](https://img.shields.io/badge/gitter-join_chat-blue.svg?style=flat-square&maxAge=2592000)](https://gitter.im/request/request-promise?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://img.shields.io/travis/request/request-promise/master.svg?style=flat-square&maxAge=2592000)](https://travis-ci.org/request/request-promise)
[![Coverage Status](https://img.shields.io/coveralls/request/request-promise.svg?style=flat-square&maxAge=2592000)](https://coveralls.io/r/request/request-promise)
[![Dependency Status](https://img.shields.io/david/request/request-promise.svg?style=flat-square&maxAge=2592000)](https://david-dm.org/request/request-promise)
[![Known Vulnerabilities](https://snyk.io/test/npm/request-promise/badge.svg?style=flat-square&maxAge=2592000)](https://snyk.io/test/npm/request-promise)

The simplified HTTP request client 'request' with Promise support. Powered by Bluebird.

[Request](https://github.com/request/request) and [Bluebird](https://github.com/petkaantonov/bluebird) are pretty awesome, but I found myself using the same design pattern. Request-Promise adds a Bluebird-powered `.then(...)` method to Request call objects. By default, http response codes other than 2xx will cause the promise to be rejected. This can be overwritten by setting `options.simple = false`.

Also check out the new libraries that are **very similar to `request-promise` v4**:
- [`request-promise-native`](https://github.com/request/request-promise-native) v1 &ndash; Does not depend on Bluebird and uses native ES6 promises instead.
- [`request-promise-any`](https://github.com/request/request-promise-any) v1 &ndash; Allows you to register any Promise library supported by [`any-promise`](https://www.npmjs.com/package/any-promise).

---

## Migration from v3 to v4

1. `request` became a peer dependency. Thus make sure that `request` is installed into your project as a direct dependency. (`npm install --save request`)
2. Continuation Local Storage is no longer supported. However, you [can get back the support](https://github.com/request/request-promise/wiki/Getting-Back-Support-for-Continuation-Local-Storage) by using `request-promise-any`.
3. When you migrated your `transform` function to v3 and had to add `if (!(/^2/.test('' + response.statusCode))) { return resolveWithFullResponse ? response : body; }` you may now set the option `transform2xxOnly = true` instead.

## Migration from v2 to v3

1. The handling of the `transform` function got overhauled. This has two effects:
    - `StatusCodeError.response` is the transformed instead of the original response now. This error is thrown for non-2xx responses when `options.simple` is `true` (default). Please update your `transform` functions to also cover the transformation of non-2xx responses. To get the old behavior you may add `if (!(/^2/.test('' + response.statusCode))) { return resolveWithFullResponse ? response : body; }` to the first line of your `transform` functions that are used for requests with `options.simple === true`. However, you may prefer updating your `transform` functions to being able to transform 2xx as well as non-2xx responses because this decouples their implementation from the use of the `simple` option when doing requests.
    - If a transform operation throws an error, the request will be rejected with a `TransformError`. Its `cause` attribute contains the error thrown by the transform operation. Previously, the request was rejected directly with the error thrown by the transform operation. Wrapping it into a `TransformError` makes the error handling easier.

2. Bluebird got updated from v2 to v3. This won't make a difference for most use cases. However, if you use advanced Promise chains starting with the Promise returned by Request-Promise, please check [Bluebird's new features and changes](http://bluebirdjs.com/docs/new-in-bluebird-3.html).

---

## Installation

This module is installed via npm:

```
npm install --save request
npm install --save request-promise
```

`request` is defined as a peer-dependency and thus has to be installed separately.

## Cheat Sheet

``` js
var rp = require('request-promise');
```

Since `request-promise` wraps around `request` everything that works with `request` also works with `request-promise`. Also check out the [`request` docs](https://github.com/request/request) for more examples.

### Crawl a webpage

``` js
rp('http://www.google.com')
    .then(function (htmlString) {
        // Process html...
    })
    .catch(function (err) {
        // Crawling failed...
    });
```

### Crawl a webpage better

``` js
var cheerio = require('cheerio'); // Basically jQuery for node.js

var options = {
    uri: 'http://www.google.com',
    transform: function (body) {
        return cheerio.load(body);
    }
};

rp(options)
    .then(function ($) {
        // Process html like you would with jQuery...
    })
    .catch(function (err) {
        // Crawling failed or Cheerio choked...
    });
```

### GET something from a JSON REST API

``` js
var options = {
    uri: 'https://api.github.com/user/repos',
    qs: {
        access_token: 'xxxxx xxxxx' // -> uri + '?access_token=xxxxx%20xxxxx'
    },
    headers: {
        'User-Agent': 'Request-Promise'
    },
    json: true // Automatically parses the JSON string in the response
};

rp(options)
    .then(function (repos) {
        console.log('User has %d repos', repos.length);
    })
    .catch(function (err) {
        // API call failed...
    });
```

### POST data to a JSON REST API

Set `option.body` to your data and `json: true` to encode the body as JSON. See below for HTML forms.

``` js
var options = {
    method: 'POST',
    uri: 'http://api.posttestserver.com/post',
    body: {
        some: 'payload'
    },
    json: true // Automatically stringifies the body to JSON
};

rp(options)
    .then(function (parsedBody) {
        // POST succeeded...
    })
    .catch(function (err) {
        // POST failed...
    });
```

### POST like HTML forms do

Pass your data to `options.form` to encode the body the same way as HTML forms do:

``` js
var options = {
    method: 'POST',
    uri: 'http://posttestserver.com/post.php',
    form: {
        // Like <input type="text" name="name">
        name: 'Josh'
    },
    headers: {
        /* 'content-type': 'application/x-www-form-urlencoded' */ // Is set automatically
    }
};

rp(options)
    .then(function (body) {
        // POST succeeded...
    })
    .catch(function (err) {
        // POST failed...
    });
```

If you want to include a file upload then use `options.formData`:

``` js
var options = {
    method: 'POST',
    uri: 'http://posttestserver.com/post.php',
    formData: {
        // Like <input type="text" name="name">
        name: 'Jenn',
        // Like <input type="file" name="file">
        file: {
            value: fs.createReadStream('test/test.jpg'),
            options: {
                filename: 'test.jpg',
                contentType: 'image/jpg'
            }
        }
    },
    headers: {
        /* 'content-type': 'multipart/form-data' */ // Is set automatically
    }
};

rp(options)
    .then(function (body) {
        // POST succeeded...
    })
    .catch(function (err) {
        // POST failed...
    });
```

### Include a cookie

``` js
var tough = require('tough-cookie');

// Easy creation of the cookie - see tough-cookie docs for details
let cookie = new tough.Cookie({
    key: "some_key",
    value: "some_value",
    domain: 'api.mydomain.com',
    httpOnly: true,
    maxAge: 31536000
});

// Put cookie in an jar which can be used across multiple requests
var cookiejar = rp.jar();
cookiejar.setCookie(cookie, 'https://api.mydomain.com');
// ...all requests to https://api.mydomain.com will include the cookie

var options = {
    uri: 'https://api.mydomain.com/...',
    jar: cookiejar // Tells rp to include cookies in jar that match uri
};

rp(options)
    .then(function (body) {
        // Request succeeded...
    })
    .catch(function (err) {
        // Request failed...
    });
```

### Get the full response instead of just the body

``` js
var options = {
    method: 'DELETE',
    uri: 'http://my-server/path/to/resource/1234',
    resolveWithFullResponse: true    //  <---  <---  <---  <---
};

rp(options)
    .then(function (response) {
        console.log("DELETE succeeded with status %d", response.statusCode);
    })
    .catch(function (err) {
        // Delete failed...
    });
```

### Get a rejection only if the request failed for technical reasons

``` js
var options = {
    uri: 'http://www.google.com/this-page-does-not-exist.html',
    simple: false    //  <---  <---  <---  <---
};

rp(options)
    .then(function (body) {
        // Request succeeded but might as well be a 404
        // Usually combined with resolveWithFullResponse = true to check response.statusCode
    })
    .catch(function (err) {
        // Request failed due to technical reasons...
    });
```

---

**For more options checkout the [Request docs](https://github.com/request/request#requestoptions-callback).**

---

## API in Detail

Consider Request-Promise being:

- A Request object
	- With an [identical API](https://github.com/request/request): `require('request-promise') == require('request')` so to say
	- However, **STREAMING THE RESPONSE** (e.g. `.pipe(...)`) is **DISCOURAGED** because Request-Promise would grow the memory footprint for large requests unnecessarily high. Use the original Request library for that. You can use both libraries in the same project.
- Plus some methods on a request call object:
	- `rp(...).then(...)` or e.g. `rp.post(...).then(...)` which turn `rp(...)` and `rp.post(...)` into promises
	- `rp(...).catch(...)` or e.g. `rp.del(...).catch(...)` which is the same method as provided by Bluebird promises
	    - Errors that the `request` library would pass to the callback are wrapped by `request-promise` and then passed to the catch handler. See [code example](https://github.com/request/request-promise#thenonfulfilled-onrejected) below. 
	- `rp(...).finally(...)` or e.g. `rp.put(...).finally(...)` which is the same method as provided by Bluebird promises
	- `rp(...).cancel()` or e.g. `rp.get(...).cancel()` which cancels the request
	- `rp(...).promise()` or e.g. `rp.head(...).promise()` which returns the underlying promise so you can access the full [Bluebird API](https://github.com/petkaantonov/bluebird/blob/master/API.md)
- Plus some additional options:
	- `simple = true` which is a boolean to set whether status codes other than 2xx should also reject the promise
	- `resolveWithFullResponse = false` which is a boolean to set whether the promise should be resolved with the full response or just the response body
	- `transform` which takes a function to transform the response into a custom value with which the promise is resolved
	- `transform2xxOnly = false` which is a boolean to set whether the transform function is applied to all responses or only to those with a 2xx status code

The objects returned by request calls like `rp(...)` or e.g. `rp.post(...)` are regular Promises/A+ compliant promises and can be assimilated by any compatible promise library.

The methods `.then(...)`, `.catch(...)`, and `.finally(...)` - which you can call on the request call objects - return a full-fledged Bluebird promise. That means you have the full [Bluebird API](https://github.com/petkaantonov/bluebird/blob/master/API.md) available for further chaining. E.g.: `rp(...).then(...).spread(...)` If, however, you need a method other than `.then(...)`, `.catch(...)`, or `.finally(...)` to be **FIRST** in the chain, use `.promise()`: `rp(...).promise().bind(...).then(...)`

### .then(onFulfilled, onRejected)

``` js
// As a Request user you would write:
var request = require('request');

request('http://google.com', function (err, response, body) {
    if (err) {
        handleError({ error: err, response: response, ... });
    } else if (!(/^2/.test('' + response.statusCode))) { // Status Codes other than 2xx
        handleError({ error: body, response: response, ... });
    } else {
        process(body);
    }
});

// As a Request-Promise user you can now write the equivalent code:
var rp = require('request-promise');

rp('http://google.com')
    .then(process, handleError);
```

``` js
// The same is available for all http method shortcuts:
request.post('http://example.com/api', function (err, response, body) { ... });
rp.post('http://example.com/api').then(...);
```

### .catch(onRejected)

``` js
rp('http://google.com')
    .catch(handleError);

// ... is syntactical sugar for:

rp('http://google.com')
    .then(null, handleError);


// However, this:
rp('http://google.com')
    .then(process)
    .catch(handleError);

// ... is safer than:
rp('http://google.com')
    .then(process, handleError);
```

For more info on `.then(process).catch(handleError)` versus `.then(process, handleError)`, see Bluebird docs on [promise anti-patterns](http://bluebirdjs.com/docs/anti-patterns.html#the-.then).

### .finally(onFinished)

``` js
rp('http://google.com')
    .finally(function () {
	    // This is called after the request finishes either successful or not successful.
	});
```

### .cancel()

This method cancels the request using [Bluebird's cancellation feature](http://bluebirdjs.com/docs/api/cancellation.html).

When `.cancel()` is called:

- the promise will neither be resolved nor rejected and
- the request is [aborted](https://nodejs.org/dist/latest-v6.x/docs/api/http.html#http_request_abort).

### .promise() - For advanced use cases

In order to not pollute the Request call objects with the methods of the underlying Bluebird promise, only `.then(...)`, `.catch(...)`, and `.finally(...)` were exposed to cover most use cases. The effect is that any methods of a Bluebird promise other than `.then(...)`, `.catch(...)`, or `.finally(...)` cannot be used as the **FIRST** method in the promise chain:

``` js
// This works:
rp('http://google.com').then(function () { ... });
rp('http://google.com').catch(function () { ... });

// This works as well since additional methods are only used AFTER the FIRST call in the chain:
rp('http://google.com').then(function () { ... }).spread(function () { ... });
rp('http://google.com').catch(function () { ... }).error(function () { ... });

// Using additional methods as the FIRST call in the chain does not work:
// rp('http://google.com').bind(this).then(function () { ... });

// Use .promise() in these cases:
rp('http://google.com').promise().bind(this).then(function () { ... });
```

### Fulfilled promises and the `resolveWithFullResponse` option

``` js
// Per default the body is passed to the fulfillment handler:
rp('http://google.com')
    .then(function (body) {
        // Process the html of the Google web page...
    });

// The resolveWithFullResponse options allows to pass the full response:
rp({ uri: 'http://google.com', resolveWithFullResponse: true })
    .then(function (response) {
        // Access response.statusCode, response.body etc.
    });

```

### Rejected promises and the `simple` option

``` js
// The rejection handler is called with a reason object...
rp('http://google.com')
    .catch(function (reason) {
        // Handle failed request...
	});

// ... and would be equivalent to this Request-only implementation:
var options = { uri: 'http://google.com' };

request(options, function (err, response, body) {
    var reason;
    if (err) {
        reason = {
            cause: err,
            error: err,
            options: options,
            response: response
        };
	} else if (!(/^2/.test('' + response.statusCode))) { // Status Codes other than 2xx
        reason = {
            statusCode: response.statusCode,
            error: body,
            options: options,
            response: response
        };
    }

    if (reason) {
        // Handle failed request...
    }
});


// If you pass the simple option as false...
rp({ uri: 'http://google.com', simple: false })
    .catch(function (reason) {
        // Handle failed request...
	});

// ... the equivalent Request-only code would be:
request(options, function (err, response, body) {
    if (err) {
        var reason = {
            cause: err,
            error: err,
            options: options,
            response: response
        };
        // Handle failed request...
	}
});
// E.g. a 404 would now fulfill the promise.
// Combine it with resolveWithFullResponse = true to check the status code in the fulfillment handler.
```

With version 0.4 the reason objects became Error objects with identical properties to ensure backwards compatibility. These new Error types allow targeted catch blocks:

``` js
var errors = require('request-promise/errors');

rp('http://google.com')
	.catch(errors.StatusCodeError, function (reason) {
        // The server responded with a status codes other than 2xx.
        // Check reason.statusCode
	})
    .catch(errors.RequestError, function (reason) {
        // The request failed due to technical reasons.
        // reason.cause is the Error object Request would pass into a callback.
	});
```

### The `transform` function

You can pass a function to `options.transform` to generate a custom fulfillment value when the promise gets resolved.

``` js
// Just for fun you could reverse the response body:
var options = {
	uri: 'http://google.com',
    transform: function (body, response, resolveWithFullResponse) {
        return body.split('').reverse().join('');
    }
};

rp(options)
    .then(function (reversedBody) {
        // ;D
    });


// However, you could also do something useful:
var $ = require('cheerio'); // Basically jQuery for node.js

function autoParse(body, response, resolveWithFullResponse) {
    // FIXME: The content type string could contain additional values like the charset.
    // Consider using the `content-type` library for a robust comparison.
    if (response.headers['content-type'] === 'application/json') {
        return JSON.parse(body);
    } else if (response.headers['content-type'] === 'text/html') {
        return $.load(body);
    } else {
        return body;
    }
}

options.transform = autoParse;

rp(options)
    .then(function (autoParsedBody) {
        // :)
    });


// You can go one step further and set the transform as the default:
var rpap = rp.defaults({ transform: autoParse });

rpap('http://google.com')
    .then(function (autoParsedBody) {
        // :)
    });

rpap('http://echojs.com')
    .then(function (autoParsedBody) {
        // =)
    });
```

The third `resolveWithFullResponse` parameter of the transform function is equivalent to the option passed with the request. This allows to distinguish whether just the transformed body or the whole response shall be returned by the transform function:

``` js
function reverseBody(body, response, resolveWithFullResponse) {
    response.body = response.body.split('').reverse().join('');
    return resolveWithFullResponse ? response : response.body;
}
```

As of Request-Promise v3 the transform function is ALWAYS executed for non-2xx responses. When `options.simple` is set to `true` (default) then non-2xx responses are rejected with a `StatusCodeError`. In this case the error contains the transformed response:

``` js
var options = {
	uri: 'http://the-server.com/will-return/404',
	simple: true,
    transform: function (body, response, resolveWithFullResponse) { /* ... */ }
};

rp(options)
    .catch(errors.StatusCodeError, function (reason) {
        // reason.response is the transformed response
    });
```

You may set `options.transform2xxOnly = true` to only execute the transform function for responses with a 2xx status code. For other status codes &ndash; independent of any other settings, e.g. `options.simple` &ndash; the transform function is not executed.

#### Error handling

If the transform operation fails (throws an error) the request will be rejected with a `TransformError`:

``` js
var errors = require('request-promise/errors');

var options = {
	uri: 'http://google.com',
    transform: function (body, response, resolveWithFullResponse) {
        throw new Error('Transform failed!');
    }
};

rp(options)
    .catch(errors.TransformError, function (reason) {
        console.log(reason.cause.message); // => Transform failed!
        // reason.response is the original response for which the transform operation failed
    });
```

## Experimental Support for Continuation Local Storage

Continuation Local Storage is no longer supported. However, you [can get back the support](https://github.com/request/request-promise/wiki/Getting-Back-Support-for-Continuation-Local-Storage) by using `request-promise-any`.

## Debugging

The ways to debug the operation of Request-Promise are the same [as described](https://github.com/request/request#debugging) for Request. These are:

1. Launch the node process like `NODE_DEBUG=request node script.js` (`lib,request,otherlib` works too).
2. Set `require('request-promise').debug = true` at any time (this does the same thing as #1).
3. Use the [request-debug module](https://github.com/nylen/request-debug) to view request and response headers and bodies. Instrument Request-Promise with `require('request-debug')(rp);`.

## Mocking Request-Promise

Usually you want to mock the whole request function which is returned by `require('request-promise')`. This is not possible by using a mocking library like [sinon.js](http://sinonjs.org) alone. What you need is a library that ties into the module loader and makes sure that your mock is returned whenever the tested code is calling `require('request-promise')`. [Mockery](https://github.com/mfncooper/mockery) is one of such libraries.

@florianschmidt1994 kindly shared his solution:
```javascript
before(function (done) {

    var filename = "fileForResponse";
    mockery.enable({
        warnOnReplace: false,
        warnOnUnregistered: false,
        useCleanCache: true
    });

    mockery.registerMock('request-promise', function () {
        var response = fs.readFileSync(__dirname + '/data/' + filename, 'utf8');
        return Bluebird.resolve(response.trim());
    });

    done();
});

after(function (done) {
    mockery.disable();
    mockery.deregisterAll();
    done();
});

describe('custom test case', function () {
    //  Test some function/module/... which uses request-promise
    //  and it will always receive the predefined "fileForResponse" as data, e.g.:
    var rp = require('request-promise');
    rp(...).then(function(data) {
        // ➞ data is what is in fileForResponse
    });
});
```

Based on that you may now build a more sophisticated mock. [Sinon.js](http://sinonjs.org) may be of help as well.

## Contributing

To set up your development environment:

1. clone the repo to your desktop,
2. in the shell `cd` to the main folder,
3. hit `npm install`,
4. hit `npm install gulp -g` if you haven't installed gulp globally yet, and
5. run `gulp dev`. (Or run `node ./node_modules/.bin/gulp dev` if you don't want to install gulp globally.)

`gulp dev` watches all source files and if you save some changes it will lint the code and execute all tests. The test coverage report can be viewed from `./coverage/lcov-report/index.html`.

If you want to debug a test you should use `gulp test-without-coverage` to run all tests without obscuring the code by the test coverage instrumentation.

## Change History

- v4.2.4 (2019-02-14)
    - Corrected mistakenly set `tough-cookie` version, now `^2.3.3`
      *(Thanks to @evocateur for pointing this out.)*
    - If you installed `request-promise@4.2.3` please make sure after the upgrade that `request` and `request-promise` use the same physical copy of `tough-cookie`.
- v4.2.3 (2019-02-14)
    - Using stricter `tough-cookie@~2.3.3` to avoid installing `tough-cookie@3` which introduces breaking changes
      *(Thanks to @aomdoa for pull request [#299](https://github.com/request/request-promise/pull/299))*
    - Security fix: bumped `lodash` to `^4.17.11`, see [vulnerabilty reports](https://snyk.io/vuln/search?q=lodash&type=npm)
- v4.2.2 (2017-09-22)
    - Upgraded `tough-cookie` to a version without regex DoS vulnerability
      *(Thanks to @rouanw for [pull request #226](https://github.com/request/request-promise/pull/226))*
- v4.2.1 (2017-05-07)
    - Fix that allows to use `tough-cookie` for cookie creation
      *(Thanks to @ScottyMJacobson for reporting [issue #183](https://github.com/request/request-promise/issues/183))*
    - Added [cookie handling example](https://github.com/request/request-promise#include-a-cookie) to the cheat sheet
      *(Thanks to @chovy and @ProfessorTom for [asking for it](https://github.com/request/request-promise/issues/79))*
- v4.2.0 (2017-03-16)
    - Updated `bluebird` to v3.5
      *(Thanks to @acinader for [pull request #181](https://github.com/request/request-promise/pull/181))*
- v4.1.1 (2016-08-08)
    - Renamed internally used package `@request/promise-core` to `request-promise-core` because there where [too](https://github.com/request/request-promise/issues/137) [many](https://github.com/request/request-promise/issues/141) issues with the scoped package name
      *(Thanks to @cabrinoob, @crazy4groovy, @dsandor, @KpjComp, @lorenwest, @Reisyukaku, @tehChromic, @todd for providing helpful information.)*
- v4.1.0 (2016-07-30)
    - Added cancellation support
      *(Thanks to @not-an-aardvark for [pull request #123](https://github.com/request/request-promise/pull/123))*
- v4.0.2 (2016-07-18)
    - Fix for using with module bundlers like Webpack and Browserify
- v4.0.1 (2016-07-17)
    - Fixed `@request/promise-core` version for safer versioning
- v4.0.0 (2016-07-15)
    - **Breaking Change**: `request` is declared as a peer dependency which has to be installed separately by the user now
    - **Breaking Change**: Dropped support for Continuation Local Storage since [`request-promise-any`](https://github.com/request/request-promise-any) can be [used](https://github.com/request/request-promise/wiki/Getting-Back-Support-for-Continuation-Local-Storage) for that now
    - Introduced the `transform2xxOnly` option to ease the breaking change regarding the new `transform` handling in v3.0.0
      *(Thanks to @stevage for pointing out the effect of the breaking change in [issue #131](https://github.com/request/request-promise/issues/131))*
    - Resolved issues [#65](https://github.com/request/request-promise/issues/65) and [#71](https://github.com/request/request-promise/issues/71) by publishing nearly identical libraries to support other Promise implementations: [`request-promise-native`](https://github.com/request/request-promise-native) and [`request-promise-any`](https://github.com/request/request-promise-any)
      *(Thanks to @benjamingr, @eilgin, @gillesdemey, @hildjj, @iggycoloma, @jonathanong, @knpwrs, @MarkHerhold, @massimocode, @mikeal, @niftylettuce, @raitucarp, @sherdeadlock, @tonylukasavage, and @vgoloviznin for the valuable discussions!)*
    - Relicensed this library with the ISC license
- v3.0.0 (2016-04-16)
    - **Breaking Change**: Overhauled the handling of the `transform` function
      *(Thanks to @Limess for explaining the need in [issue #86](https://github.com/request/request-promise/issues/86))*
    - **Breaking Change**: Updated `bluebird` to v3
      *(Thanks to @BrandonSmith for [pull request #103](https://github.com/request/request-promise/pull/103))*
    - Improved `StatusCodeError.message`
    - Updated `lodash` to v4.6
    - Improved README in regard to `.catch(...)` best practice
      *(Thanks to @RebootJeff for [pull request #98](https://github.com/request/request-promise/pull/98))*
- v2.0.1 (2016-02-17)
    - Updated `lodash` to v4
      *(Thanks to @ratson for [pull request #94](https://github.com/request/request-promise/pull/94))*
- v2.0.0 (2016-01-12)
    - **Breaking Change**: Removed explicit `cls-bluebird` dependency which has to be installed by the user now
      *(Thanks to @hildjj for his [pull request #75](https://github.com/request/request-promise/pull/75))*
	- `npm shrinkwrap` now works for `npm@3` users who don't use `continuation-local-storage`
	  *(Thanks to @toboid and @rstacruz for reporting the issue in [issue #70](https://github.com/request/request-promise/issues/70) and [issue #82](https://github.com/request/request-promise/issues/82))*
- v1.0.2 (2015-10-22)
    - Removed `continuation-local-storage` from peer dependencies as it was unnecessary
      *(Thanks to @mrhyde for working on a better solution discussed in [issue #70](https://github.com/request/request-promise/issues/70))*
- v1.0.1 (2015-10-14)
    - Fixed a npm warning by marking `continuation-local-storage` as a peer dependency
- v1.0.0 (2015-10-11)
    - **Breaking Change**: Some errors that were previously thrown synchronously - e.g. for wrong input parameters - are now passed to the rejected promise instead
      *(Thanks to @josnidhin for suggesting that in [issue #43](https://github.com/request/request-promise/issues/43))*
    - **Breaking Change**: Request-Promise does not load its own Bluebird prototype anymore. If you use Bluebird in your project and altered the prototype then Request-Promise may use your altered Bluebird prototype internally.
    - For HEAD requests the headers instead of an empty body is returned (unless `resolveWithFullResponse = true` is used)
      *(Thanks to @zcei for proposing the change in [issue #58](https://github.com/request/request-promise/issues/58))*
    - Extended `transform` function by a third `resolveWithFullResponse` parameter
    - Added experimental support for continuation local storage
      *(Thanks to @silverbp preparing this in [issue #64](https://github.com/request/request-promise/issues/64))*
	- Added node.js 4 to the Travis CI build
	- Updated the README
	  *(Thanks to many people for their feedback in issues [#55](https://github.com/request/request-promise/issues/55) and [#59](https://github.com/request/request-promise/issues/59))*
- v0.4.3 (2015-07-27)
    - Reduced overhead by just requiring used lodash functions instead of the whole lodash library
      *(Thanks to @luanmuniz for [pull request #54](https://github.com/request/request-promise/pull/54))*
    - Updated dependencies
- v0.4.2 (2015-04-12)
    - Updated dependencies
- v0.4.1 (2015-03-20)
    - Improved Error types to work in browsers without v8 engine
      *(Thanks to @nodiis for [pull request #40](https://github.com/request/request-promise/pull/40))*
- v0.4.0 (2015-02-08)
    - Introduced Error types used for the reject reasons (See last part [this section](#rejected-promises-and-the-simple-option))
      *(Thanks to @jakecraige for starting the discussion in [issue #38](https://github.com/request/request-promise/issues/38))*
    - **Minor Breaking Change:** The reject reason objects became actual Error objects. However, `typeof reason === 'object'` still holds true and the error objects have the same properties as the previous reason objects. If the reject handler only accesses the properties on the reason object - which is usually the case - no migration is required.
    - Added io.js and node.js 0.12 to the Travis CI build
- v0.3.3 (2015-01-19)
    - Fixed handling possibly unhandled rejections to work with the latest version of Bluebird
      *(Thanks to @slang800 for reporting this in [issue #36](https://github.com/request/request-promise/issues/36))*
- v0.3.2 (2014-11-17)
	- Exposed `.finally(...)` to allow using it as the first method in the promise chain
	  *(Thanks to @hjpbarcelos for his [pull request #28](https://github.com/request/request-promise/pull/28))*
- v0.3.1 (2014-11-11)
	- Added the `.promise()` method for advanced Bluebird API usage
	  *(Thanks to @devo-tox for his feedback in [issue #27](https://github.com/request/request-promise/issues/27))*
- v0.3.0 (2014-11-10)
	- Carefully rewritten from scratch to make Request-Promise a drop-in replacement for Request

## License (ISC)

In case you never heard about the [ISC license](http://en.wikipedia.org/wiki/ISC_license) it is functionally equivalent to the MIT license.

See the [LICENSE file](LICENSE) for details.
