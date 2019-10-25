# Postman URL encoding

## Simple url string encoder based on RFC 3986

```
  npm install postman-url-encoder --save
```

```js
var urlEncoder = require('postman-url-encoder');
console.log(urlEncoder.encode('http://foo.bar.com?a=b'))
```
