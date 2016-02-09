fs     = require 'fs'
redis  = require 'redis'
log    = require './log.js'

REDIS_SERVER = if process.env.NODE_ENV == 'development' then 'localhost' else 'db_redis_pubsub'
SECURE = !!process.env.NODE_SSL
# client = redis.createClient 6379, REDIS_SERVER

# RedisStore  = require 'socket.io/lib/stores/redis'
# rpub        = redis.createClient 6379, REDIS_SERVER
# rsub        = redis.createClient 6379, REDIS_SERVER
# rclient     = redis.createClient 6379, REDIS_SERVER


if SECURE
    privateKey = fs.readFileSync('./config/certificates/newsblur.com.key').toString()
    certificate = fs.readFileSync('./config/certificates/newsblur.com.crt').toString()
    # ca = fs.readFileSync('./config/certificates/intermediate.crt').toString()
    options = 
        key: privateKey
        cert: certificate
    io = require('socket.io').listen 8889, options

else
    io = require('socket.io').listen 8888

io.configure 'production', ->
    io.set 'log level', 1
    io.enable 'browser client minification'
    io.enable 'browser client etag'
    io.enable 'browser client gzip'


io.configure 'development', ->
    io.set 'log level', 2

# io.set 'store', new RedisStore
#     redisPub    : rpub
#     redisSub    : rsub
#     redisClient : rclient

io.sockets.on 'connection', (socket) ->
    ip = socket.handshake.headers['X-Forwarded-For'] || socket.handshake.address.address
    
    socket.on 'subscribe:feeds', (@feeds, @username) ->
        log.info @username, "Connecting (#{feeds.length} feeds, #{ip})," +
                 " (#{io.sockets.clients().length} users on) " +
                 " #{if SECURE then "(SSL)" else "(non-SSL)"}"
        
        if not @username
            return
        
        socket.on "error", (err) ->
            console.log " ---> Error (socket): #{err}"
        socket.subscribe?.end()
        socket.subscribe = redis.createClient 6379, REDIS_SERVER
        socket.subscribe.on "error", (err) ->
            console.log " ---> Error: #{err}"
            socket.subscribe.end()
        socket.subscribe.on "connect", =>
            socket.subscribe.subscribe @feeds
            socket.subscribe.subscribe @username

        socket.subscribe.on 'message', (channel, message) =>
            log.info @username, "Update on #{channel}: #{message}"
            if channel == @username
                socket.emit 'user:update', channel, message
            else
                socket.emit 'feed:update', channel, message

    socket.on 'disconnect', () ->
        socket.subscribe?.end()
        log.info @username, "Disconnect (#{@feeds?.length} feeds, #{ip})," +
                    " there are now #{io.sockets.clients().length-1} users. " +
                    " #{if SECURE then "(SSL)" else "(non-SSL)"}"

io.sockets.on 'error', (err) ->
    console.log " ---> Error (sockets): #{err}"
