fs     = require 'fs'
redis  = require 'redis'

REDIS_SERVER = if process.env.NODE_ENV == 'development' then 'localhost' else 'db01'
SECURE = !!process.env.NODE_SSL
client = redis.createClient 6379, REDIS_SERVER

if SECURE
    privateKey = fs.readFileSync('./config/certificates/newsblur.com.key').toString()
    certificate = fs.readFileSync('./config/certificates/newsblur.com.crt').toString()
    ca = fs.readFileSync('./config/certificates/intermediate.crt').toString()
    io = require('socket.io').listen 8889
        key: privateKey
        cert: certificate
        ca: ca
else
    io = require('socket.io').listen 8888

io.configure 'production', ->
    io.set 'log level', 1
    io.enable 'browser client minification'
    io.enable 'browser client etag'
    io.enable 'browser client gzip'


io.configure 'development', ->
    io.set 'log level', 2

io.sockets.on 'connection', (socket) ->
    socket.on 'subscribe:feeds', (@feeds, @username) ->
        console.log "   ---> [#{@username}] Subscribing to #{feeds.length} feeds " +
                    " (#{io.sockets.clients().length} users on)"

        socket.subscribe?.end()
        socket.subscribe = redis.createClient 6379, REDIS_SERVER
        socket.subscribe.subscribe @feeds
        socket.subscribe.subscribe @username
        
        socket.subscribe.on 'message', (channel, message) =>
            console.log "   ---> [#{@username}] Update on #{channel}: #{message}"
            if channel == @username
                socket.emit 'user:update', channel, message
            else
                socket.emit 'feed:update', channel, message
    
    socket.on 'disconnect', () ->
        socket.subscribe?.end()
        console.log "   ---> [#{@username}] Disconnect, there are now" +
                    " #{io.sockets.clients().length-1} users. " +
                    " #{if SECURE then "(SSL)"}"
    