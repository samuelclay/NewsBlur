streamLength = require "./"
fs = require "fs"
request = require "request"
http = require "http"
Promise = require "bluebird"

Promise.try ->
	console.log "Length of fs:README.md..."
	streamLength fs.createReadStream("README.md")
.then (length) ->
	console.log "Length", length
.catch (err) ->
	console.log "No-Length", err

.then ->
	console.log "Length of Buffer..."
	streamLength new Buffer("testing buffer content length retrieval...")
.then (length) ->
	console.log "Length", length
.catch (err) ->
	console.log "No-Length", err

.then ->
	console.log "Length of http:Google"
	new Promise (resolve, reject) ->
		http.get "http://www.google.com/images/srpr/logo11w.png", (res) ->
			resolve res
		.on "error", (err) ->
			reject err
.then (res) ->
	res.resume() # Drain the stream
	streamLength res
.then (length) ->
	console.log "Length", length
.catch (err) ->
	console.log "No-Length", err

.then ->
	console.log "Length of request:Google..."
	streamLength request "http://www.google.com/images/srpr/logo11w.png", (err, res, body) ->
		# Ignore...
.then (length) ->
	console.log "Length", length
.catch (err) ->
	console.log "No-Length", err

.then ->
	console.log "Length of request:Google:fail..."
	streamLength request "http://www.google.com/", (err, res, body) ->
		# Ignore...
.then (length) ->
	console.log "Length", length
.catch (err) ->
	console.log "No-Length", err



