log = require './log.js'

# Handler for Ask AI streaming messages from Redis PubSub
handle_ask_ai_message = (socket, channel, message) =>
    prefix = 'ask_ai:'
    return false unless typeof message == 'string' and message.startsWith(prefix)

    try
        payload = message.substring(prefix.length)
        data = JSON.parse(payload)
    catch error
        log.debug "Invalid ask_ai payload on #{channel}: #{error}"
        return true

    message_type = data.type
    story_hash = data.story_hash
    question_id = data.question_id or ''
    request_id = data.request_id or ''

    if not story_hash
        log.debug "Ask AI message missing story hash: #{message}"
        return true

    switch message_type
        when 'start'
            log.debug "ask_ai:start #{story_hash} #{question_id}"
            socket.emit 'ask_ai:start', {
                story_hash: story_hash,
                question_id: question_id,
                request_id: request_id
            }

        when 'chunk'
            socket.emit 'ask_ai:chunk', {
                story_hash: story_hash,
                question_id: question_id,
                request_id: request_id,
                chunk: data.chunk or ''
            }

        when 'complete'
            log.debug "ask_ai:complete #{story_hash} #{question_id}"
            socket.emit 'ask_ai:complete', {
                story_hash: story_hash,
                question_id: question_id,
                request_id: request_id
            }

        when 'usage'
            socket.emit 'ask_ai:usage', {
                story_hash: story_hash,
                question_id: question_id,
                request_id: request_id,
                message: data.message or ''
            }

        when 'error'
            log.info "ask_ai:error #{story_hash} #{question_id}: #{data.error}"
            socket.emit 'ask_ai:error', {
                story_hash: story_hash,
                question_id: question_id,
                request_id: request_id,
                error: data.error or 'Unknown error'
            }

        else
            log.debug "Unknown ask_ai message type: #{message_type}"

    return true  # Message was handled

module.exports = {
    handle_ask_ai_message
}
