# stream-length

Attempts to determine the total content length of a Stream or Buffer.

Supports both Promises and nodebacks.

## License

[WTFPL](http://www.wtfpl.net/txt/copying/) or [CC0](https://creativecommons.org/publicdomain/zero/1.0/), whichever you prefer. A donation and/or attribution are appreciated, but not required.

## Donate

My income consists entirely of donations for my projects. If this module is useful to you, consider [making a donation](http://cryto.net/~joepie91/donate.html)!

You can donate using Bitcoin, PayPal, Gratipay, Flattr, cash-in-mail, SEPA transfers, and pretty much anything else.

## Contributing

Pull requests welcome. Please make sure your modifications are in line with the overall code style, and ensure that you're editing the `.coffee` files, not the `.js` files.

Build tool of choice is `gulp`; simply run `gulp` while developing, and it will watch for changes.

Be aware that by making a pull request, you agree to release your modifications under the licenses stated above.

## Supported stream types

* Buffers
* `fs.createReadStream` streams
* `http.request` and `http.get` responses
* `request` requests
* `combined-stream2` streams

## Usage

Using Promises:

```javascript
var streamLength = require("stream-length");

Promise.try(function(){
	return streamLength(fs.createReadStream("README.md"));
})
.then(function(result){
	console.log("The length of README.md is " + result);
})
.catch(function(err){
	console.log("Could not determine length. Error: " + err.toString());
});
```

Using nodebacks:

```javascript
var streamLength = require("stream-length");

streamLength(fs.createReadStream("README.md"), {}, function(err, result){
	if(err)
	{
		console.log("Could not determine length. Error: " + err.toString());
	}
	else
	{
		console.log("The length of README.md is " + result);
	}
});
```

Custom lengthRetrievers:

```javascript
Promise.try(function(){
	return streamLength(fs.createReadStream("README.md"), [
		function(stream, callback){
			doSomethingWith(stream, function(err, len){
				callback(err ? err : len);
			})
		}
	]);
})
.then(function(result){
	console.log("The length of README.md is " + result);
})
.catch(function(err){
	console.log("Could not determine length. Error: " + err.toString());
});
```


## API

### streamLength(stream, [options, [callback]])

Determines the length of `stream`, which can be a supported type of Stream or a Buffer. Optionally you can specify `options`:

* __lengthRetrievers__: An array of (potentially asynchronous) functions for establishing stream lengths. You can specify one or more of these if you wish to extend `stream-length`s list of supported Stream types. Each retriever function is called with a signature of `(stream, callback)` where `stream` is the stream in question, and `callback` can be called with the result. If an Error occurs, simply pass the Error to the callback instead of the value.

If you define a `callback`, it will be treated as a nodeback and called when the function completes. If you don't, the function will return a Promise that resolves when the function completes.
