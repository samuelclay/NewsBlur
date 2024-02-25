path = require 'path'
busboy = require 'connect-busboy'
fs = require 'fs'
mkdirp = require 'mkdirp'
log    = require './log.js'

fsPromises = fs.promises
mkdirpPromise = require('util').promisify(mkdirp)

original_page = (app) =>
    DEV = process.env.NODE_ENV == 'development' || process.env.NODE_ENV == 'docker' || process.env.NODE_ENV == 'debug'

    DB_PATH = '/srv/originals'

    app.use busboy()

    app.get /^\/original_page\/(\d+)\/?/, (req, res) ->
        return res.end "OK" if req.query.test

        feedId = parseInt req.params[0], 10
        etag = req.header 'If-None-Match'
        lastModified = req.header 'If-Modified-Since'
        feedIdDir = splitFeedId feedId
        filePath = "#{DB_PATH}/#{feedIdDir}.zhtml"

        # Convert to async flow with try/catch using CoffeeScript's then/catch for Promises
        fsPromises.stat(filePath).then (stats) ->
            fileEtag = Date.parse(stats.mtime).toString()
            if etag is fileEtag or lastModified is stats.mtime.toISOString()
                log.debug "Not modified: #{feedId} (#{filePath})"
                res.sendStatus 304
            else
                fsPromises.readFile(filePath).then (content) ->
                    log.debug "Sending: #{feedId} (#{filePath}) #{stats.size} bytes"
                    res.header 'Etag', fileEtag
                    res.send content
        .catch (err) ->
            if err.code is 'ENOENT'
                log.debug "Original page not found: #{feedId} (#{filePath})"
                res.sendStatus 404
            else
                log.debug "Error reading original page: #{feedId} (#{filePath}) #{err}"
                res.sendStatus 500


    app.post /^\/original_page\/(\d+)\/?/, (req, res) ->
        feedId = parseInt req.params[0], 10
        feedIdDir = splitFeedId feedId
        filePath = "#{DB_PATH}/#{feedIdDir}.zhtml"
        filePathDir = path.dirname filePath

        # Ensure directory exists before proceeding
        mkdirpPromise(filePathDir).then ->
            fstream = fs.createWriteStream filePath
            req.pipe req.busboy

            req.busboy.on 'file', (fieldname, file, filename) ->
                file.pipe fstream

                fstream.on 'close', ->
                    fsPromises.stat(filePath).then (stats) ->
                        log.debug "Saving: #{feedId} (#{filePath}) #{stats.size} bytes"
                        res.send "OK"
        .catch (err) ->
            log.debug err
            res.sendStatus 500


    splitFeedId = (feedId) ->
        feedId += ''
        # x2 = if feedId.length > 1 then '.' + feedId[1] else ''
        rgx = /(\d+)(\d{3})/
        feedId = feedId.replace rgx, '$1' + '/' + '$2' while rgx.test(feedId)
        return feedId;
        

    log.debug "Starting Original Page server #{if DEV then "on DEV" else "in production"}"


exports.original_page = original_page
