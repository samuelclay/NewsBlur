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
    privateKey = fs.readFileSync('/srv/newsblur/config/certificates/newsblur.com.key').toString()
    certificate = fs.readFileSync('/srv/newsblur/config/certificates/newsblur.com.crt').toString()
    # ca = fs.readFileSync('./config/certificates/intermediate.crt').toString()
    options = 
        port: 8889
        key: privateKey
        cert: certificate
    app = require('https').createServer options
    io = require('socket.io')(app, path: "/v2/socket.io")
    app.listen options.port
else
    options = 
        port: 8888
    app = require('http').createServer()
    io = require('socket.io')(app, path: "/v2/socket.io")
    app.listen options.port

# io.set('transports', ['websocket'])

# io.set 'store', new RedisStore
#     redisPub    : rpub
#     redisSub    : rsub
#     redisClient : rclient

io.on 'connection', (socket) ->
    ip = socket.handshake.headers['X-Forwarded-For'] || socket.handshake.address

    socket.on 'subscribe:feeds', (@feeds, @username) ->
        log.info @username, "Connecting (#{feeds.length} feeds, #{ip})," +
                 " (#{io.engine.clientsCount} connected) " +
                 " #{if SECURE then "(SSL)" else "(non-SSL)"}"
        
        if not @username
            return
        
        socket.on "error", (err) ->
            console.log " ---> Error (socket): #{err}"
        socket.subscribe?.quit()
        socket.subscribe = redis.createClient 6379, REDIS_SERVER
        socket.subscribe.on "error", (err) =>
            log.info @username, "Error: #{err} (#{@feeds.length} feeds)"
            socket.subscribe?.quit()
        socket.subscribe.on "connect", =>
            log.info @username, "Connected (#{@feeds.length} feeds, #{ip})," +
                     " (#{io.engine.clientsCount} connected) " +
                     " #{if SECURE then "(SSL)" else "(non-SSL)"}"
            socket.subscribe.subscribe @feeds
            feeds_story = @feeds.map (f) -> "#{f}:story"
            socket.subscribe.subscribe feeds_story
            socket.subscribe.subscribe @username

        socket.subscribe.on 'message', (channel, message) =>
            log.info @username, "Update on #{channel}: #{message}"
            if channel == @username
                socket.emit 'user:update', channel, message
            else if channel.indexOf(':story') >= 0
                socket.emit 'feed:story:new', channel, message
            else
                socket.emit 'feed:update', channel, message

    socket.on 'disconnect', () ->
        socket.subscribe?.quit()
        log.info @username, "Disconnect (#{@feeds?.length} feeds, #{ip})," +
                    " there are now #{io.engine.clientsCount} users. " +
                    " #{if SECURE then "(SSL)" else "(non-SSL)"}"

io.sockets.on 'error', (err) ->
    console.log " ---> Error (sockets): #{err}"
