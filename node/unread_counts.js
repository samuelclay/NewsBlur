(function() {
  var REDIS_SERVER, client, fs, io, redis;

  fs = require('fs');

  io = require('socket.io').listen(8888);

  redis = require('redis');

  REDIS_SERVER = process.env.NODE_ENV === 'dev' ? 'localhost' : 'db01';

  client = redis.createClient(6379, REDIS_SERVER);

  io.sockets.on('connection', function(socket) {
    socket.on('subscribe:feeds', function(feeds, username) {
      var _ref,
        _this = this;
      this.feeds = feeds;
      this.username = username;
      console.log(("   ---> [" + this.username + "] Subscribing to " + feeds.length + " feeds ") + (" (" + (io.sockets.clients().length) + " users on)"));
      if ((_ref = socket.subscribe) != null) _ref.end();
      socket.subscribe = redis.createClient(6379, REDIS_SERVER);
      socket.subscribe.subscribe(this.feeds);
      return socket.subscribe.on('message', function(channel, message) {
        console.log("   ---> [" + _this.username + "] Update on " + channel + ": " + message);
        return socket.emit('feed:update', channel);
      });
    });
    return socket.on('disconnect', function() {
      var _ref;
      if ((_ref = socket.subscribe) != null) _ref.end();
      return console.log(("   ---> [" + this.username + "] Disconnect, there are now") + (" " + (io.sockets.clients().length - 1) + " users."));
    });
  });

}).call(this);
