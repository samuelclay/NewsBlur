log = require './log.js'

# Handler for Ask AI streaming messages from Redis PubSub
handle_ask_ai_message = (socket, channel, message) =>
    # Message format: "ask_ai:TYPE:STORY_HASH:QUESTION_ID:PAYLOAD"
    # Examples:
    #   "ask_ai:start:1337:4fed36:sentence"
    #   "ask_ai:chunk:1337:4fed36:bullets:This is a chunk of text"
    #   "ask_ai:complete:1337:4fed36:paragraph"
    #   "ask_ai:error:1337:4fed36:custom:Error message"

    # Parse message
    if not message.startsWith('ask_ai:')
        return false  # Not an ask_ai message

    # Message format: "ask_ai:TYPE:STORY_HASH:QUESTION_ID:PAYLOAD"
    # Story hash contains a colon (e.g., "1337:4fed36"), so we need careful parsing
    parts = message.split(':')
    if parts.length < 4
        log.debug "Invalid ask_ai message format: #{message}"
        return true  # Handled but invalid

    message_type = parts[1]  # start, chunk, complete, error
    # Story hash is feed_id:hash_id (parts 2 and 3)
    story_hash = "#{parts[2]}:#{parts[3]}"
    # Question ID is parts[4]
    question_id = parts[4] || ''
    # Payload is everything after question_id
    payload = if parts.length > 5 then parts[5..].join(':') else ''

    # Emit appropriate Socket.IO event based on message type
    switch message_type
        when 'start'
            log.info "Emitting ask_ai:start event to client for story #{story_hash}, question #{question_id}"
            socket.emit 'ask_ai:start', {
                story_hash: story_hash,
                question_id: question_id
            }
            log.debug "Ask AI started for story #{story_hash}"

        when 'chunk'
            chunk_preview = if payload.length > 30 then payload.substring(0, 30) + '...' else payload
            log.info "Emitting ask_ai:chunk event to client for story #{story_hash}, question #{question_id}: #{chunk_preview}"
            socket.emit 'ask_ai:chunk', {
                story_hash: story_hash,
                question_id: question_id,
                chunk: payload
            }

        when 'complete'
            log.info "Emitting ask_ai:complete event to client for story #{story_hash}, question #{question_id}"
            socket.emit 'ask_ai:complete', {
                story_hash: story_hash,
                question_id: question_id
            }
            log.debug "Ask AI completed for story #{story_hash}"

        when 'error'
            socket.emit 'ask_ai:error', {
                story_hash: story_hash,
                question_id: question_id,
                error: payload
            }
            log.debug "Ask AI error for story #{story_hash}: #{payload}"

        else
            log.debug "Unknown ask_ai message type: #{message_type}"

    return true  # Message was handled

module.exports = {
    handle_ask_ai_message
}
