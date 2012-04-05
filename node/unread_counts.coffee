fs     = require 'fs'
io     = require('socket.io').listen 8888
redis  = require 'redis'

REDIS_SERVER = if process.env.NODE_ENV == 'dev' then 'localhost' else 'db01'
client = redis.createClient 6379, REDIS_SERVER

io.sockets.on 'connection', (socket) ->
    socket.on 'subscribe:feeds', (@feeds, @username) ->
        console.log "   ---> [#{@username}] Subscribing to #{feeds.length} feeds " +
                    " (#{io.sockets.clients().length} users on)"

        socket.subscribe?.end()
        socket.subscribe = redis.createClient 6379, REDIS_SERVER
        socket.subscribe.subscribe @feeds
        
        socket.subscribe.on 'message', (channel, message) =>
            console.log "   ---> [#{@username}] Update on #{channel}: #{message}"
            socket.emit 'feed:update', channel
    
    socket.on 'disconnect', () ->
        socket.subscribe?.end()
        console.log "   ---> [#{@username}] Disconnect, there are now" +
                    " #{io.sockets.clients().length-1} users."
    