Mercury = require('@postlight/mercury-parser')
log    = require './log.js'

original_text = (app) =>
    DEV = process.env.NODE_ENV == 'development' or process.env.NODE_ENV == 'docker' or process.env.NODE_ENV == 'debug'

    log.debug "Starting NewsBlur Original Text Fetcher / Mercury Parser..."
    if !DEV and !process.env.NODE_ENV
        log.debug "Specify NODE_ENV=<debug,development,docker,production>"
        return
    else if DEV
        log.debug "Running as development server"
    else
        log.debug "Running as production server"

    app.get /\/rss_feeds\/original_text_fetcher\/?/, (req, res) =>
        res.setHeader 'Content-Type', 'application/json'
        if req.query.test
            return res.end "OK"
        
        url = req.query.url
        if !url
            log.debug "Missing url"
            return res.end JSON.stringify error: "Missing `url` query parameter."
        
        api_key = req.header('x-api-key') or req.query.apikey
        if not DEV and (!api_key or api_key.indexOf("djtXZrSIEfDa3Dex9FQ9AR") == -1)
            log.debug "Mismatched API key: #{url} / #{api_key}"
            return res.end JSON.stringify error: "Invalid API key. You need to set up your own Original Text server."
            
        Mercury.parse(url).then (result) => 
            log.debug "Fetched: #{url}"
            res.end JSON.stringify result
        .catch (error) =>
            log.debug "Failed to fetch: #{url}: #{error}"
            # throw new Error("Failed to fetch: #{url}: #{error}")
            return res.end JSON.stringify error: "Failed to fetch #{url}: #{error}"


exports.original_text = original_text
