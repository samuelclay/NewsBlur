log = require './log.js'

# Handler for Web Feed streaming messages from Redis PubSub
handle_webfeed_message = (socket, channel, message) =>
    prefix = 'webfeed:'
    return false unless typeof message == 'string' and message.startsWith(prefix)

    try
        payload = message.substring(prefix.length)
        data = JSON.parse(payload)
    catch error
        log.debug "Invalid webfeed payload on #{channel}: #{error}"
        return true

    message_type = data.type
    url = data.url or ''
    request_id = data.request_id or ''

    switch message_type
        when 'start'
            log.debug "webfeed:start #{url}"
            socket.emit 'webfeed:start', {
                url: url,
                request_id: request_id
            }

        when 'variants'
            log.debug "webfeed:variants #{url} (#{data.variants?.length or 0} variants)"
            socket.emit 'webfeed:variants', {
                url: url,
                request_id: request_id,
                variants: data.variants or [],
                html_hash: data.html_hash or '',
                page_title: data.page_title or '',
                favicon_url: data.favicon_url or ''
            }

        when 'complete'
            log.debug "webfeed:complete #{url}"
            socket.emit 'webfeed:complete', {
                url: url,
                request_id: request_id
            }

        when 'error'
            log.info "webfeed:error #{url}: #{data.error}"
            socket.emit 'webfeed:error', {
                url: url,
                request_id: request_id,
                error: data.error or 'Unknown error'
            }

        else
            log.debug "Unknown webfeed message type: #{message_type}"

    return true  # Message was handled

module.exports = {
    handle_webfeed_message
}
