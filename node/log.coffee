info = (username, message) ->
    timestamp = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '')
    console.log "[#{timestamp}]  ---> [#{username}] #{message}"
    
exports.info = info