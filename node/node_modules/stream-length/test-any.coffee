# This is a test case for petkaantonov/bluebird#432, encountered during development of this module.

Promise = require "bluebird"

successPromise = (val) ->
	new Promise (resolve, reject) ->
		process.nextTick -> resolve(val)

failurePromise = (val) ->
	new Promise (resolve, reject) ->
		process.nextTick -> reject(val)


successSyncPromise = (val) ->
	new Promise (resolve, reject) ->
		resolve(val)

failureSyncPromise = (val) ->
	new Promise (resolve, reject) ->
		reject(val)

failureSyncPromiseTwo = (val) ->
	Promise.reject(val)


Promise.any [
	successSyncPromise()
	successPromise()
	failureSyncPromise("fail a").catch (err) -> console.log err
]
.then -> console.log "success a"

Promise.any [
	successSyncPromise()
	successPromise()
	failurePromise("fail b").catch (err) -> console.log err
]
.then -> console.log "success b"

Promise.any [
	successPromise()
	successPromise()
	failurePromise("fail c").catch (err) -> console.log err
]
.then -> console.log "success c"

Promise.any [
	successSyncPromise()
	successSyncPromise()
	failureSyncPromise("fail d").catch (err) -> console.log err
]
.then -> console.log "success d"

Promise.any [
	successSyncPromise()
	successSyncPromise()
	failureSyncPromiseTwo("fail e").catch (err) -> console.log err
]
.then -> console.log "success e"
