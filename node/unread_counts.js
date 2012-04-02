(function() {
  var REDIS_SERVER, client, fs, io, redis;

  fs = require('fs');

  io = require('socket.io').listen(8888);

  redis = require('redis');

  REDIS_SERVER = process.env.NODE_ENV === 'dev' ? 'localhost' : 'db01';

  client = redis.createClient(6379, REDIS_SERVER);

  io.sockets.on('connection', function(socket) {
    console.log("   ---> New connection brings total to " + (io.sockets.clients().length) + " consumers.");
    socket.on('subscribe:feeds', function(feeds, username) {
      var _ref;
      if ((_ref = socket.subscribe) != null) _ref.end();
      socket.subscribe = redis.createClient(6379, REDIS_SERVER);
      console.log("   ---> [" + username + "] Subscribing to " + feeds.length + " feeds");
      socket.subscribe.subscribe(feeds);
      return socket.subscribe.on('message', function(channel, message) {
        console.log("   ---> [" + username + "] Update on " + channel + ": " + message);
        return socket.emit('feed:update', channel);
      });
    });
    return socket.on('disconnect', function() {
      var _ref;
      if ((_ref = socket.subscribe) != null) _ref.end();
      return console.log("   ---> [] Disconnect, there are now " + (io.sockets.clients().length - 1) + " consumers.");
    });
  });

}).call(this);
