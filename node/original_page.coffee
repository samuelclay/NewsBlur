express = require 'express'
path = require 'path'
fs = require 'fs'
mkdirp = require 'mkdirp'

DEV = process.env.NODE_ENV == 'development'

DB_PATH = if DEV then 'originals' else '/srv/originals'
app = express.createServer()
app.use express.bodyParser()

app.listen 3060

app.get /^\/original_page\/(\d+)\/?/, (req, res) =>
    feedId = parseInt(req.params, 10)
    etag = req.header('If-None-Match')
    lastModified = req.header('If-Modified-Since')
    feedIdDir = splitFeedId feedId
    filePath = "#{DB_PATH}/#{feedIdDir}.zhtml"
    
    path.exists filePath, (exists, err) ->
        console.log " ---> Loading: #{feedId} (#{filePath}). " +
                    "#{if exists then "" else "NOT FOUND"}"
        if not exists
            return res.send 404
        fs.stat filePath, (err, stats) ->
            if not err and etag and stats.mtime == etag
                return res.send 304
            if not err and lastModified and stats.mtime == lastModified
                return res.send 304
        
            fs.readFile filePath, (err, content) ->
                res.header 'Etag', Date.parse(stats.mtime)
                res.send content


app.post /^\/original_page\/(\d+)\/?/, (req, res) =>
    feedId = parseInt(req.params, 10)
    feedIdDir = splitFeedId feedId
    html = req.param "original_page"
    filePath = "#{DB_PATH}/#{feedIdDir}.zhtml"
    filePathDir = path.dirname filePath
    mkdirp filePathDir, (err) ->
        fs.rename req.files.original_page.path, filePath, (err) ->
            console.log err if err
            console.log " ---> Saving: #{feedId} (#{filePath})"
            res.send "OK"


splitFeedId = (feedId) ->
    feedId += ''
    # x2 = if feedId.length > 1 then '.' + feedId[1] else ''
    rgx = /(\d+)(\d{3})/
    feedId = feedId.replace rgx, '$1' + '/' + '$2' while rgx.test(feedId)
    return feedId;
    
