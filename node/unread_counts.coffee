fs     = require 'fs'
redis  = require 'redis'
log    = require './log.js'

unread_counts = (server) =>
    ENV_DEV = process.env.NODE_ENV == 'development' or process.env.NODE_ENV == 'debug'
    ENV_PROD = process.env.NODE_ENV == 'production'
    ENV_DOCKER = process.env.NODE_ENV == 'docker'
    REDIS_SERVER = "db_redis"
    if ENV_DEV
        REDIS_SERVER = 'localhost'
    else if ENV_PROD
        REDIS_SERVER = 'db-redis-pubsub.service.nyc1.consul'
    SECURE = !!process.env.NODE_SSL
    REDIS_PORT = if ENV_DOCKER then 6579 else 6383

    # client = redis.createClient 6379, REDIS_SERVER

    # RedisStore  = require 'socket.io/lib/stores/redis'
    # rpub        = redis.createClient 6379, REDIS_SERVER
    # rsub        = redis.createClient 6379, REDIS_SERVER
    # rclient     = redis.createClient 6379, REDIS_SERVER


    log.debug "Starting NewsBlur unread count server..."
    if !ENV_DEV and !process.env.NODE_ENV
        log.debug "Specify NODE_ENV=<development,production>"
        return
    else if ENV_DEV
        log.debug "Running as development server"
    else if ENV_DOCKER
        log.debug "Running as docker server"
    else
        log.debug "Running as production server"
        
    # Create Redis clients for Socket.IO adapter
    pub_client = redis.createClient(REDIS_PORT, REDIS_SERVER)
    sub_client = redis.createClient(REDIS_PORT, REDIS_SERVER)

    io = require('socket.io')(server, {
        path: "/v3/socket.io",
        pingTimeout: 60000,        # Increase ping timeout to 60 seconds
        pingInterval: 25000,       # Send ping every 25 seconds
        connectTimeout: 45000,     # Connection timeout
        transports: ['websocket'], # Prefer websocket transport
        adapter: require('@socket.io/redis-adapter').createAdapter(pub_client, sub_client)
    })

    # Handle Redis adapter client errors
    pub_client.on "error", (err) ->
        log.debug "Redis Pub Error: #{err}"
        
    sub_client.on "error", (err) ->
        log.debug "Redis Sub Error: #{err}"

    # Setup Redis error handling and reconnection
    setup_redis_client = (socket, username) ->
        client = redis.createClient({
            host: REDIS_SERVER,
            port: REDIS_PORT,
            retry_strategy: (options) ->
                return Math.min(options.attempt * 100, 3000)
        })
        
        client.on "error", (err) =>
            log.info username, "Redis Error: #{err}"
            # Don't quit on error, let retry strategy handle it
            
        client.on "reconnecting", (attempt) =>
            log.info username, "Redis reconnecting... Attempt #{attempt}"
            
        return client

    io.on 'connection', (socket) ->
        ip = socket.handshake.headers['X-Forwarded-For'] || socket.handshake.address

        socket.on 'subscribe:feeds', (@feeds, @username) =>
            log.info @username, "Connecting (#{@feeds.length} feeds, #{ip})," +
                    " (#{io.engine.clientsCount} connected) " +
                    " #{if SECURE then "(SSL)" else ""}"
            
            if not @username
                return
                
            socket.on "error", (err) ->
                log.debug "Error (socket): #{err}"
                
            socket.subscribe?.quit()
            socket.subscribe = setup_redis_client(socket, @username)
            
            socket.subscribe.on "connect", =>
                log.info @username, "Connected (#{@feeds.length} feeds, #{ip})," +
                        " (#{io.engine.clientsCount} connected) " +
                        " #{if SECURE then "(SSL)" else "(non-SSL)"}"
                socket.subscribe.subscribe @feeds
                feeds_story = @feeds.map (f) -> "#{f}:story"
                socket.subscribe.subscribe feeds_story
                socket.subscribe.subscribe @username

            socket.subscribe.on 'message', (channel, message) =>
                event_name = 'feed:update'
                if channel == @username
                    event_name = 'user:update'
                else if channel.indexOf(':story') >= 0
                    event_name = 'feed:story:new'
                log.info @username, "Update on #{channel}: #{event_name} - #{message}"
                socket.emit event_name, channel, message

        socket.on 'disconnect', () =>
            socket.subscribe?.quit()
            log.info @username, "Disconnect (#{@feeds?.length} feeds, #{ip})," +
                        " there are now #{io.engine.clientsCount} users. " +
                        " #{if SECURE then "(SSL)" else "(non-SSL)"}"

    io.sockets.on 'error', (err) ->
        log.debug "Error (sockets): #{err}"

    return io

exports.unread_counts = unread_counts
