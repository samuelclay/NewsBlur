# SyncChannel

A SyncChannel is a readable/writable communication channel. 
Communication is synchronous, i.e. the callback of a write gets called only when it's value has been read.
Reading/writing from/to a SyncChannel can be aborted by calling the abort function returned by 
the read/write methods.

## Installation
```
$ npm install sync-channel
```

# Examples

## read/write

``` js
var SyncChannel = require('sync-channel');

var channel = new SyncChannel();

channel.read(function(value) {
	console.log('value read', value);
});

channel.write(123, function() {
	console.log('value written');
});
```

## Aborting a read/write operation

``` js
var SyncChannel = require('sync-channel');

var channel = new SyncChannel();

var abortRead = channel.read(function(value) {
	console.log('value read', value);
});

setTimeout(function() {
	abortRead();
	console.log('you are so slow!');
}, 500);

setTimeout(function() {
	channel.write(123, function() {
		console.log('value written');
	});
}, 1000);
```

## tryRead

``` js
var SyncChannel = require('sync-channel');
var channel = new SyncChannel();
var result = channel.tryRead();
if(result !== null) {
	console.log('value read', result.value);
} else {
	console.log('no writers');         
}
```

## tryWrite
``` js
var SyncChannel = require('sync-channel');
var channel = new SyncChannel();
var result = channel.tryWrite(123);
if(result === true) {
	console.log('value written');
} else {
	console.log('no readers');
}
```
