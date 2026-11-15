log = require './log.js'

# node/describe.coffee: relays Describe feed search events from Redis PubSub
# (published by apps/describe/tasks.py with a "describe:" prefix) to the
# browser as "describe:<type>" socket events. The payload is passed through
# untouched so new event types need no node change.
handle_describe_message = (socket, channel, message) =>
    prefix = 'describe:'
    return false unless typeof message == 'string' and message.startsWith(prefix)

    try
        payload = message.substring(prefix.length)
        data = JSON.parse(payload)
    catch error
        log.debug "Invalid describe payload on #{channel}: #{error}"
        return true

    message_type = data.type
    search_id = data.search_id or ''

    if not message_type or not search_id
        log.debug "Describe message missing type or search id: #{message.substring(0, 80)}"
        return true

    if message_type in ['start', 'complete', 'error']
        log.debug "describe:#{message_type} #{search_id}"
    socket.emit "describe:#{message_type}", data

    return true  # Message was handled

module.exports = {
    handle_describe_message
}
