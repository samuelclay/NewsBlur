path = require 'path'
busboy = require 'connect-busboy'
fs = require 'fs'
mkdirp = require 'mkdirp'
log    = require './log.js'

original_page = (app) =>
    DEV = process.env.NODE_ENV == 'development' || process.env.NODE_ENV == 'docker' || process.env.NODE_ENV == 'debug'

    DB_PATH = if DEV then 'originals' else '/srv/originals'

    app.use busboy()

    app.get /^\/original_page\/(\d+)\/?/, (req, res) =>
        if req.query.test
            return res.end "OK"

        feedId = parseInt(req.params[0], 10)
        etag = req.header('If-None-Match')
        lastModified = req.header('If-Modified-Since')
        feedIdDir = splitFeedId feedId
        filePath = "#{DB_PATH}/#{feedIdDir}.zhtml"
        
        fs.exists filePath, (exists, err) ->
            log.debug "Loading: #{feedId} (#{filePath}). " +
                        "#{if exists then "" else "NOT FOUND"}"
            if not exists
                return res.sendStatus 404
            fs.stat filePath, (err, stats) ->
                if not err and etag and stats.mtime == etag
                    return res.sendStatus 304
                if not err and lastModified and stats.mtime == lastModified
                    return res.sendStatus 304
            
                fs.readFile filePath, (err, content) ->
                    res.header 'Etag', Date.parse(stats.mtime)
                    res.send content


    app.post /^\/original_page\/(\d+)\/?/, (req, res) =>
        feedId = parseInt(req.params[0], 10)
        feedIdDir = splitFeedId feedId
        req.pipe req.busboy
        req.busboy.on 'file', (fieldname, file, filename) ->
            # log.debug "Uploading #{fieldname} / #{file} / #{filename}"
            filePath = "#{DB_PATH}/#{feedIdDir}.zhtml"
            filePathDir = path.dirname filePath
            mkdirp filePathDir, (err) ->
                log.debug err if err
                fstream = fs.createWriteStream filePath
                file.pipe fstream
                fstream.on 'close', ->
                    fs.stat filePath, (err, stats) ->
                        log.debug err if err
                        log.debug "Saving: #{feedId} (#{filePath}) #{stats.size} bytes"
                        res.send "OK"


    splitFeedId = (feedId) ->
        feedId += ''
        # x2 = if feedId.length > 1 then '.' + feedId[1] else ''
        rgx = /(\d+)(\d{3})/
        feedId = feedId.replace rgx, '$1' + '/' + '$2' while rgx.test(feedId)
        return feedId;
        

    log.debug "Starting Original Page server #{if DEV then "on DEV" else "in production"}"


exports.original_page = original_page
