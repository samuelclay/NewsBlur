express = require 'express'
mongo = require 'mongodb'

MONGODB_SERVER = if process.env.NODE_ENV == 'development' then 'localhost' else 'db04'
server = new mongo.Server(MONGODB_SERVER, 27017, 
    auto_reconnect: true
    poolSize: 12)
db = new mongo.Db('newsblur', server)

app = express.createServer()
app.use express.bodyParser()
    
db.open (err, client) =>
    client.collection "feed_icons", (err, @collection) =>
    
app.get /^\/rss_feeds\/icon\/(\d+)\/?/, (req, res) =>
    feed_id = parseInt(req.params, 10)
    etag = req.header('If-None-Match')
    @collection.findOne _id: feed_id, (err, docs) ->
        console.log "Req: #{feed_id}, etag: #{etag}"
        if not err and etag and docs and docs.color == etag
            res.send 304
        else if not err and docs and docs.data
                res.header 'etag', docs.color
                res.send new Buffer(docs.data, 'base64'), 
                    "Content-Type": "image/png"
        else
            res.redirect '/media/img/icons/silk/world.png' 

app.listen 3030
