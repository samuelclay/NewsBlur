(function() {
  var client, fs, io, redis;

  fs = require('fs');

  io = require('socket.io').listen(8888);

  redis = require('redis');

  client = redis.createClient(6379, 'db01');

  io.sockets.on('connection', function(socket) {
    socket.on('subscribe:feeds', function(feeds) {
      socket.subscribe = redis.createClient(6379, 'db01');
      console.log("Subscribing to " + feeds.length + " feeds");
      socket.subscribe.subscribe(feeds);
      return socket.subscribe.on('message', function(channel, message) {
        console.log("Update on " + channel + ": " + message);
        return socket.emit('feed:update', channel);
      });
    });
    return socket.on('disconnect', function() {
      var _ref;
      if ((_ref = socket.subscribe) != null) _ref.end();
      return console.log('Disconnect');
    });
  });

}).call(this);
