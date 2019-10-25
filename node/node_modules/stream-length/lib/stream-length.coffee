Promise = require "bluebird"
fs = Promise.promisifyAll(require "fs")

nodeifyWrapper = (callback, func) ->
	func().nodeify(callback)

createRetrieverPromise = (stream, retriever) ->
	new Promise (resolve, reject) ->
		retriever stream, (result) ->
			if result?
				if result instanceof Error
					reject result
				else
					resolve result
			else
				reject new Error("Could not find a length using this lengthRetriever.")

retrieveBuffer = (stream, callback) ->
	if stream instanceof Buffer
		callback stream.length
	else
		callback null

retrieveFilesystemStream = (stream, callback) ->
	if stream.hasOwnProperty "fd"
		# FIXME: https://github.com/joyent/node/issues/7819
		if stream.end != undefined and stream.end != Infinity and stream.start != undefined
			# A stream start and end were defined, we can calculate the size just from that information.
			callback(stream.end + 1 - (stream.start ? 0))
		else
			# We have the start offset at most, stat the file and work off the filesize.
			Promise.try ->
				fs.statAsync stream.path
			.then (stat) ->
				callback(stat.size - (stream.start ? 0))
			.catch (err) ->
				callback err
	else
		callback null

retrieveCoreHttpStream = (stream, callback) ->
	if stream.hasOwnProperty("httpVersion") and stream.headers["content-length"]?
		callback parseInt(stream.headers["content-length"])
	else
		callback null

retrieveRequestHttpStream = (stream, callback) ->
	if stream.hasOwnProperty "httpModule"
		stream.on "response", (response) ->
			if response.headers["content-length"]?
				callback parseInt(response.headers["content-length"])
			else
				callback null
	else
		callback null

retrieveCombinedStream = (stream, callback) ->
	if stream.getCombinedStreamLength?
		stream.getCombinedStreamLength()
			.then (length) -> callback(length)
			.catch (err) -> callback(err)
	else
		callback null


module.exports = (stream, options = {}, callback) ->
	nodeifyWrapper callback, ->
		retrieverPromises = []

		if options.lengthRetrievers?
			# First, the custom length retrievers, if any.
			for retriever in options.lengthRetrievers
				retrieverPromises.push createRetrieverPromise(stream, retriever)

		# Then, the standard ones.
		for retriever in [retrieveBuffer, retrieveFilesystemStream, retrieveCoreHttpStream, retrieveRequestHttpStream, retrieveCombinedStream]
			retrieverPromises.push createRetrieverPromise(stream, retriever)

		Promise.any retrieverPromises



