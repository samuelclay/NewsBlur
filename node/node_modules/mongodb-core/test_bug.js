var ReplSet = require('./').ReplSet;
var replSet = new ReplSet([
  { host: '10.211.55.6', port: 31000 },
  { host: '10.211.55.12', port: 31001 },
  { host: '10.211.55.13', port: 31002 }
], {
  connectionTimeout: 10000,
});

replSet.on('connect', function(_server) {
  setInterval(function() {
    _server.command('system.$cmd', { ping: 1 }, function(err, result) {
      if (err) {
        console.error(err);
      } else {
        console.log(result.result);
      }
    });
  }, 1000);
});

replSet.connect()
