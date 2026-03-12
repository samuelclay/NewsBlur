log = require './log.js'

# Handler for briefing generation progress messages from Redis PubSub
handle_briefing_message = (socket, channel, message) =>
    prefix = 'briefing:'
    return false unless typeof message == 'string' and message.startsWith(prefix)

    try
        payload = message.substring(prefix.length)
        data = JSON.parse(payload)
    catch error
        log.debug "Invalid briefing payload on #{channel}: #{error}"
        return true

    message_type = data.type

    switch message_type
        when 'start'
            log.debug "briefing:start for #{channel}"
            socket.emit 'briefing:start', {}

        when 'progress'
            log.debug "briefing:progress #{data.step} for #{channel}"
            socket.emit 'briefing:progress', {
                step: data.step or '',
                message: data.message or ''
            }

        when 'complete'
            log.debug "briefing:complete for #{channel}"
            socket.emit 'briefing:complete', {}

        when 'error'
            log.info "briefing:error for #{channel}: #{data.error}"
            socket.emit 'briefing:error', {
                error: data.error or 'Unknown error'
            }

        else
            log.debug "Unknown briefing message type: #{message_type}"

    return true  # Message was handled

module.exports = {
    handle_briefing_message
}
