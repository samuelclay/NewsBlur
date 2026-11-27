log = require './log.js'

# Handler for Reorganize with AI progress messages from Redis PubSub, which
# apps/reorganize/tasks.py publishes while it makes a proposal
handle_reorganize_message = (socket, channel, message) =>
    prefix = 'reorganize:'
    return false unless typeof message == 'string' and message.startsWith(prefix)

    try
        payload = message.substring(prefix.length)
        data = JSON.parse(payload)
    catch error
        log.debug "Invalid reorganize payload on #{channel}: #{error}"
        return true

    message_type = data.type
    request_id = data.request_id or ''
    proposal_id = data.proposal_id or ''

    switch message_type
        when 'start'
            log.debug "reorganize:start #{proposal_id}"
            socket.emit 'reorganize:start', {
                request_id: request_id,
                proposal_id: proposal_id
            }

        when 'progress'
            log.debug "reorganize:progress #{proposal_id} #{data.step} #{data.done}/#{data.total}"
            socket.emit 'reorganize:progress', {
                request_id: request_id,
                proposal_id: proposal_id,
                step: data.step or '',
                done: data.done or 0,
                total: data.total or 0
            }

        when 'ready'
            log.debug "reorganize:ready #{proposal_id}"
            socket.emit 'reorganize:ready', {
                request_id: request_id,
                proposal_id: proposal_id
            }

        when 'error'
            log.info channel, "reorganize:error #{proposal_id}: #{data.code}"
            socket.emit 'reorganize:error', {
                request_id: request_id,
                proposal_id: proposal_id,
                code: data.code or ''
            }

        else
            log.debug "Unknown reorganize message type: #{message_type}"

    return true  # Message was handled

module.exports = {
    handle_reorganize_message
}
