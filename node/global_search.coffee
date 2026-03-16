log = require './log.js'

handle_global_search_message = (socket, channel, message) =>
    prefix = 'global_search:'
    return false unless typeof message == 'string' and message.startsWith(prefix)

    try
        payload = message.substring(prefix.length)
        data = JSON.parse(payload)
    catch error
        log.debug "Invalid global_search payload on #{channel}: #{error}"
        return true

    message_type = data.type
    search_id = data.search_id or ''

    switch message_type
        when 'results'
            socket.emit 'global_search:results', {
                search_id: search_id
                stories: data.stories or []
                feeds: data.feeds or {}
                chunk_index: data.chunk_index
                total_chunks: data.total_chunks
            }
        when 'complete'
            log.debug "global_search:complete #{search_id}"
            socket.emit 'global_search:complete', {
                search_id: search_id
            }
        when 'error'
            log.info "global_search:error #{search_id}: #{data.error}"
            socket.emit 'global_search:error', {
                search_id: search_id
                error: data.error or 'Unknown error'
            }
        else
            log.debug "Unknown global_search message type: #{message_type}"

    return true

module.exports = { handle_global_search_message }
