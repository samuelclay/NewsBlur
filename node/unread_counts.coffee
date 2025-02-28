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
        
    # Create Redis clients for Socket.IO adapter with improved configuration
    redis_opts = {
        host: REDIS_SERVER,
        port: REDIS_PORT,
        retry_strategy: (options) ->
            # Exponential backoff with a cap
            return Math.min(options.attempt * 100, 3000)
        connect_timeout: 10000
    }
    
    pub_client = redis.createClient(redis_opts)
    sub_client = redis.createClient(redis_opts)

    # Handle Redis adapter client errors
    pub_client.on "error", (err) ->
        log.debug "Redis Pub Error: #{err}"
        
    sub_client.on "error", (err) ->
        log.debug "Redis Sub Error: #{err}"
        
    pub_client.on "reconnecting", (attempt) ->
        log.debug "Redis Pub reconnecting... Attempt #{attempt}"
        
    sub_client.on "reconnecting", (attempt) ->
        log.debug "Redis Sub reconnecting... Attempt #{attempt}"

    io = require('socket.io')(server, {
        path: "/v3/socket.io",
        pingTimeout: 120000,        # Increased from 60s to 120s
        pingInterval: 30000,        # Increased from 25s to 30s
        connectTimeout: 60000,      # Increased from 45s to 60s
        transports: ['websocket'],  # Prefer websocket transport
        maxHttpBufferSize: 1e8,     # Increase buffer size to 100MB
        cors: {
            origin: "*",
            methods: ["GET", "POST"]
        },
        allowEIO3: true,            # Allow compatibility with Socket.IO v3 clients
        adapter: require('@socket.io/redis-adapter').createAdapter(pub_client, sub_client)
    })

    # Setup Redis error handling and reconnection
    setup_redis_client = (socket, username) ->
        client = redis.createClient({
            host: REDIS_SERVER,
            port: REDIS_PORT,
            retry_strategy: (options) ->
                return Math.min(options.attempt * 100, 3000)
            connect_timeout: 10000
        })
        
        client.on "error", (err) =>
            log.info username, "Redis Error: #{err}"
            # Don't quit on error, let retry strategy handle it
            
        client.on "reconnecting", (attempt) =>
            log.info username, "Redis reconnecting... Attempt #{attempt}"
            
        return client

    # Track active connections by username for debugging
    active_connections = {}
    
    # Log engine events for debugging
    io.engine.on 'connection', (socket) ->
        log.debug "Engine connection established: #{socket.id}"
        
    io.engine.on 'close', (socket) ->
        log.debug "Engine connection closed: #{socket.id}"

    io.on 'connection', (socket) ->
        ip = socket.handshake.headers['X-Forwarded-For'] || socket.handshake.address
        socket_id = socket.id
        log.debug "Socket connected: #{socket_id} from #{ip}"
        
        # Store socket data for tracking
        socket.data = {
            ip: ip,
            socket_id: socket_id,
            connected_at: Date.now()
        }
        
        # Set a longer ping timeout for this socket
        socket.conn.pingTimeout = 120000
        
        socket.conn.on 'error', (err) ->
            log.debug "Socket #{socket_id} - connection error: #{err}"
            
        socket.conn.on 'close', (reason) ->
            log.debug "Socket #{socket_id} - connection closed: #{reason}"

        socket.on 'subscribe:feeds', (feeds, username) =>
            # Store user data directly on the socket for access during disconnect
            socket.data.feeds = feeds
            socket.data.username = username
            socket.data.subscribed_at = Date.now()
            
            log.info username, "Connecting (#{feeds.length} feeds, #{ip}), (#{io.engine.clientsCount} connected) #{if SECURE then "(SSL)" else ""}"
            
            # Track connections by username for debugging
            active_connections[username] = active_connections[username] || {}
            active_connections[username][socket_id] = {
                connected_at: socket.data.connected_at,
                subscribed_at: socket.data.subscribed_at,
                feed_count: feeds.length
            }
            log.debug "#{username} now has #{Object.keys(active_connections[username]).length} active connections, adding #{socket_id}"
            
            if not username
                return
                
            socket.on "error", (err) ->
                log.debug "Error (socket): #{err}"
                
            socket.subscribe?.quit()
            socket.subscribe = setup_redis_client(socket, username)
            
            socket.subscribe.on "connect", =>
                log.info username, "Connected (#{feeds.length} feeds, #{ip}), (#{io.engine.clientsCount} connected) #{if SECURE then "(SSL)" else "(non-SSL)"}"
                socket.subscribe.subscribe feeds
                feeds_story = feeds.map (f) -> "#{f}:story"
                socket.subscribe.subscribe feeds_story
                socket.subscribe.subscribe username

            socket.subscribe.on 'message', (channel, message) =>
                event_name = 'feed:update'
                if channel == username
                    event_name = 'user:update'
                else if channel.indexOf(':story') >= 0
                    event_name = 'feed:story:new'
                log.info username, "Update on #{channel}: #{event_name} - #{message}"
                socket.emit event_name, channel, message

        socket.on 'disconnect', (reason) ->
            # Use the data stored on the socket
            username = socket.data.username
            feeds = socket.data.feeds
            ip = socket.data.ip
            socket_id = socket.data.socket_id
            connected_at = socket.data.connected_at
            subscribed_at = socket.data.subscribed_at
            
            # Calculate connection duration
            now = Date.now()
            connection_duration = now - (connected_at || now)
            subscription_duration = if subscribed_at then (now - subscribed_at) else 0
            
            log.debug "Socket #{socket_id} disconnected: #{reason}, username: #{username}, connection duration: #{connection_duration}ms, subscription duration: #{subscription_duration}ms"
            
            # Update connection tracking
            if username and active_connections[username]
                if active_connections[username][socket_id]
                    delete active_connections[username][socket_id]
                    log.debug "#{username} now has #{Object.keys(active_connections[username]).length} active connections after removing #{socket_id}"
                else
                    log.debug "Socket #{socket_id} not found in active connections for #{username}"
                
                if Object.keys(active_connections[username]).length == 0
                    delete active_connections[username]
            
            socket.subscribe?.quit()
            if username and feeds
                log.info username, "Disconnect (#{feeds.length} feeds, #{ip}), there are now #{io.engine.clientsCount} users. #{if SECURE then "(SSL)" else "(non-SSL)"}"

    io.engine.on 'connection_error', (err) ->
        log.debug "Connection Error: #{err.code} - #{err.message}"

    io.sockets.on 'error', (err) ->
        log.debug "Error (sockets): #{err}"
        
    # Periodically log connection stats
    setInterval ->
        total_users = Object.keys(active_connections).length
        total_connections = io.engine.clientsCount
        total_tracked = 0
        for username, sockets of active_connections
            total_tracked += Object.keys(sockets).length
        log.debug "Connection stats: #{total_users} users with #{total_connections} total connections (#{total_tracked} tracked)"
    , 60000

    return io

exports.unread_counts = unread_counts
