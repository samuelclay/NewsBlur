log = require './log.js'

# Handler for Archive Assistant streaming messages from Redis PubSub
handle_archive_assistant_message = (socket, channel, message) =>
    prefix = 'archive_assistant:'
    return false unless typeof message == 'string' and message.startsWith(prefix)

    try
        payload = message.substring(prefix.length)
        data = JSON.parse(payload)
    catch error
        log.debug "Invalid archive_assistant payload on #{channel}: #{error}"
        return true

    message_type = data.type
    query_id = data.query_id or ''
    conversation_id = data.conversation_id or ''

    if not query_id
        log.debug "Archive Assistant message missing query_id: #{message}"
        return true

    switch message_type
        when 'start'
            log.debug "archive_assistant:start #{query_id}"
            socket.emit 'archive_assistant:start', {
                query_id: query_id,
                conversation_id: conversation_id
            }

        when 'chunk'
            socket.emit 'archive_assistant:chunk', {
                query_id: query_id,
                conversation_id: conversation_id,
                content: data.content or ''
            }

        when 'tool_call'
            log.debug "archive_assistant:tool_call #{query_id} #{data.tool}"
            socket.emit 'archive_assistant:tool_call', {
                query_id: query_id,
                conversation_id: conversation_id,
                tool: data.tool or '',
                input: data.input or {}
            }

        when 'complete'
            log.debug "archive_assistant:complete #{query_id}"
            socket.emit 'archive_assistant:complete', {
                query_id: query_id,
                conversation_id: conversation_id,
                duration_ms: data.duration_ms or 0,
                tokens_used: data.tokens_used or 0
            }

        when 'error'
            log.info "archive_assistant:error #{query_id}: #{data.error}"
            socket.emit 'archive_assistant:error', {
                query_id: query_id,
                conversation_id: conversation_id,
                error: data.error or 'Unknown error'
            }

        else
            log.debug "Unknown archive_assistant message type: #{message_type}"

    return true  # Message was handled

module.exports = {
    handle_archive_assistant_message
}
