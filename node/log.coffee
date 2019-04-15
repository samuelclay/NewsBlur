info = (username, message) ->
    timestamp = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '')
    console.log "[#{timestamp}]  ---> [#{username}] #{message}"

debug = (message) ->
    timestamp = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '')
    console.log "[#{timestamp}]  ---> #{message}"

exports.info = info
exports.debug = debug