(function() {
  var MONGODB_SERVER, app, db, express, findFeedIcon, mongo, server,
    _this = this;

  express = require('express');

  mongo = require('mongodb');

  MONGODB_SERVER = process.env.NODE_ENV === 'dev' ? 'localhost' : 'db04';

  server = new mongo.Server(MONGODB_SERVER, 27017, {
    auto_reconnect: true,
    poolSize: 12
  });

  db = new mongo.Db('newsblur', server);

  app = express.createServer();

  app.use(express.bodyParser());

  db.open(function(err, client) {
    return client.collection("feed_icons", function(err, collection) {
      _this.collection = collection;
    });
  });

  app.get(/^\/rss_feeds\/icon\/(\d+)\/?/, function(req, res) {
    var etag, feed_id;
    feed_id = parseInt(req.params, 10);
    etag = req.header('If-None-Match');
    if (etag) {
      console.log("Req: " + feed_id + ", etag: " + etag);
      return _this.collection.findOne({
        _id: feed_id
      }, {
        color: true
      }, function(err, docs) {
        if (!err && docs && docs.color === etag) {
          return res.send(304);
        } else {
          return findFeedIcon(feed_id, res);
        }
      });
    } else {
      return findFeedIcon(feed_id, res);
    }
  });

  findFeedIcon = function(feed_id, res) {
    console.log("No etag, finding: " + feed_id);
    return _this.collection.findOne({
      _id: feed_id
    }, function(err, docs) {
      if (!err && docs && docs.data) {
        res.header('etag', docs.color);
        return res.send(new Buffer(docs.data, 'base64'), {
          "Content-Type": "image/png"
        });
      } else {
        return res.redirect('/media/img/icons/silk/world.png');
      }
    });
  };

  app.listen(3030);

}).call(this);
