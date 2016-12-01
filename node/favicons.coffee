app = require('express')()
server = require('http').Server(app)
mongo = require 'mongodb'

DEV = process.env.NODE_ENV == 'development'
MONGODB_SERVER = if DEV then 'localhost' else 'db_mongo'
MONGODB_PORT = parseInt(process.env.MONGODB_PORT or 27017, 10)

console.log " ---> Starting NewsBlur Favicon server..."
if !DEV and !process.env.NODE_ENV
    console.log " ---> Specify NODE_ENV=<development,production>"
    return
else if DEV
    console.log " ---> Running as development server"
else
    console.log " ---> Running as production server"
    
if DEV
    url = "mongodb://#{MONGODB_SERVER}:#{MONGODB_PORT}/newsblur"
else
    url = "mongodb://#{MONGODB_SERVER}:#{MONGODB_PORT}/newsblur?replicaSet=nbset&readPreference=secondaryPreferred"

mongo.MongoClient.connect url, (err, db) =>
    console.log " ---> Connected to #{db?.serverConfig.s.host}:#{db?.serverConfig.s.port} / #{err}"
    @collection = db?.collection "feed_icons"
    
app.get /\/rss_feeds\/icon\/(\d+)\/?/, (req, res) =>
    feed_id = parseInt(req.params[0], 10)
    etag = req.header('If-None-Match')
    console.log " ---> Feed: #{feed_id} " + if etag then " / #{etag}" else ""
    @collection.findOne _id: feed_id, (err, docs) ->
        if not err and etag and docs and docs?.color == etag
            console.log " ---> Cached: #{feed_id}, etag: #{etag}/#{docs?.color} " + if err then "(err: #{err})" else ""
            res.sendStatus 304
        else if not err and docs and docs.data
            console.log " ---> Req: #{feed_id}, etag: #{etag}/#{docs?.color} " + if err then "(err: #{err})" else ""
            res.header 'etag', docs.color
            body = new Buffer(docs.data, 'base64')
            res.set("Content-Type", "image/png")
            res.status(200).send body
        else
            console.log " ---> Redirect: #{feed_id}, etag: #{etag}/#{docs?.color} " + if err then "(err: #{err})" else ""
            if DEV
                res.redirect '/media/img/icons/circular/world.png' 
            else
                res.redirect 'https://www.newsblur.com/media/img/icons/circular/world.png' 

app.listen 3030
