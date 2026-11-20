# Listen stream server: streams one story segment of ElevenLabs speech to a player and caches it in S3.
#
# Django (apps/listen/manifest.py) decides who may hear what and stores each segment as a job in the pubsub
# Redis under an unguessable id. This handler reads the job, streams the MP3 from ElevenLabs straight to the
# player while buffering it, then uploads the buffer to S3 through the job's presigned PUT URL and marks it
# cached so later requests (other devices, rewinds, other listeners) redirect to S3 instead.
{ promisify } = require 'util'
log    = require './log.js'

ELEVENLABS_STREAM_URL = "https://api.elevenlabs.io/v1/text-to-speech"
LOCK_SECONDS = 90
CACHED_MARKER_SECONDS = 29 * 24 * 60 * 60
LIBRARY_BLOCKED_SECONDS = 10 * 60
# A job whose audio couldn't be cached (S3 failure, a broken stream) may be regenerated once, never without end.
# Only requests ElevenLabs accepted count, so an outage can't use up a job before any audio exists.
MAX_GENERATIONS_PER_JOB = 2
# Requests ElevenLabs refused or never answered generate nothing, so they don't count against the job. A job may
# fail this often per window, then waits out the window instead of hammering ElevenLabs.
MAX_FAILURES_PER_WINDOW = 3
FAILURE_WINDOW_SECONDS = 60
# When to ask again after finding another server still generating the segment.
BUSY_RETRY_SECONDS = 5
JOB_SECONDS = 6 * 60 * 60
BYTES_PER_SECOND = 64000 / 8
# How long to wait on other servers and outside services. Everything a generation does under its lock (both
# ElevenLabs requests, the stream and the S3 upload) ends within speech_deadline_ms + s3_upload_ms, 75 seconds,
# so the 90 second lock never expires while its generation is still running. node/tests/listen_stream.test.js
# shortens these through listen(app, timing: {...}) so it runs in milliseconds.
DEFAULT_TIMING =
    # A request waiting on another server answers within HAProxy's 30 second node_text server timeout
    # (docker/haproxy/haproxy.consul.cfg.j2).
    wait_for_cache_ms: 20000
    poll_ms: 300
    # How long ElevenLabs may take to answer a request, and the longest silence allowed between audio chunks.
    speech_response_ms: 15000
    speech_stall_ms: 15000
    # A whole generation: a segment is at most 700 characters (apps/listen/text.py MAX_SEGMENT_CHARACTERS), under
    # a minute of speech, and ElevenLabs streams it faster than it plays.
    speech_deadline_ms: 60000
    s3_upload_ms: 15000

# node/newsblur.coffee calls listen(app). node/tests/listen_stream.test.js also passes a fake redis_client, fetch
# and timing so the handler runs without Redis, ElevenLabs or S3.
listen = (app, options = {}) =>
    ENV_DEV = process.env.NODE_ENV == 'development' or process.env.NODE_ENV == 'debug'
    ENV_PROD = process.env.NODE_ENV == 'production'
    ENV_DOCKER = process.env.NODE_ENV == 'docker'
    REDIS_SERVER = "newsblur_db_redis"
    if ENV_DEV
        REDIS_SERVER = 'localhost'
    else if ENV_PROD
        REDIS_SERVER = 'db-redis-pubsub.service.nyc1.consul'
    REDIS_PORT = if ENV_DOCKER then 6579 else 6383
    API_KEY = process.env.ELEVENLABS_API_KEY

    log.debug "Starting NewsBlur Listen stream server..."
    if not API_KEY
        log.debug "Listen: ELEVENLABS_API_KEY isn't set in node/.env, so uncached segments will fail"

    timing = Object.assign {}, DEFAULT_TIMING, options.timing
    http_fetch = options.fetch or fetch

    create_redis_client = ->
        redis = require 'redis'
        redis_client = redis.createClient
            host: REDIS_SERVER
            port: REDIS_PORT
            retry_strategy: (retry) -> Math.min(retry.attempt * 100, 3000)
            connect_timeout: 10000
        redis_client.on "error", (err) -> log.debug "Listen Redis error: #{err}"
        redis_client

    client = options.redis_client or create_redis_client()
    redis_get = promisify(client.get).bind(client)
    redis_set = promisify(client.set).bind(client)
    redis_del = promisify(client.del).bind(client)
    redis_incr = promisify(client.incr).bind(client)
    redis_ttl = promisify(client.ttl).bind(client)

    sleep = (ms) -> new Promise (resolve) -> setTimeout(resolve, ms)

    # Adds one to a counter that expires seconds after its first count. The expiry is set with the key rather than
    # after INCR, so a crash between the two can't leave a counter that never expires.
    count = (key, seconds) ->
        await redis_set key, 0, 'NX', 'EX', seconds
        redis_incr key

    # Settles like promise, but rejects as soon as signal aborts, so no await on an outside service outlives its
    # timeout even if the service ignores the signal.
    until_aborted = (promise, signal) ->
        new Promise (resolve, reject) ->
            on_abort = -> reject signal.reason
            signal.addEventListener 'abort', on_abort, once: true
            stop_listening = -> signal.removeEventListener 'abort', on_abort
            promise.then ((value) -> stop_listening(); resolve value), ((err) -> stop_listening(); reject err)
            on_abort() if signal.aborted

    # Bounds the time spent on one service (listen.coffee). Every await on the service goes through
    # watchdog.wait, which rejects once the service is silent for idle_ms or deadline_ms has passed in all. Either
    # one aborts watchdog.signal, which also makes fetch drop the connection.
    start_watchdog = (service, deadline_ms) ->
        controller = new AbortController()
        give_up = (reason) -> controller.abort new Error(reason) unless controller.signal.aborted
        deadline = setTimeout (-> give_up "#{service} took longer than #{deadline_ms}ms"), deadline_ms
        signal: controller.signal
        wait: (promise, idle_ms) ->
            idle = setTimeout (-> give_up "#{service} sent nothing for #{idle_ms}ms"), idle_ms
            try
                await until_aborted promise, controller.signal
            finally
                clearTimeout idle
        stop: -> clearTimeout deadline

    # Only one server generates a given segment. Returns 'locked' once this request holds the segment's lock and may
    # generate it, 'cached' once another server has put it in S3, or 'busy' when another server is still generating
    # it after wait_for_cache_ms, so the player asks again instead of paying for the same audio twice.
    claim_segment = (job_id, cache_key) ->
        lock_key = "listen:lock:#{cache_key}"
        cached_key = "listen:cached:#{cache_key}"
        started = Date.now()
        # Each failed attempt means another server holds the lock. Wait for its audio to land in S3, and take the
        # lock if that server gives up (its lock is gone and nothing was cached).
        until await redis_set lock_key, job_id, 'NX', 'EX', LOCK_SECONDS
            return 'busy' if Date.now() - started >= timing.wait_for_cache_ms
            await sleep timing.poll_ms
            return 'cached' if await redis_get(cached_key)
        # The lock may have been free because another server had just cached this segment and let it go.
        if await redis_get(cached_key)
            await redis_del lock_key
            return 'cached'
        'locked'

    # Why this job may not generate right now, or null when it may.
    generation_refusal = (job_id) ->
        generations = Number(await redis_get("listen:generations:#{job_id}")) or 0
        if generations >= MAX_GENERATIONS_PER_JOB
            log.debug "Listen: job #{job_id} already generated #{generations} times, refusing"
            return status: 429, error: "This segment can't be generated again"
        failures = Number(await redis_get("listen:failures:#{job_id}")) or 0
        if failures >= MAX_FAILURES_PER_WINDOW
            retry_after = Math.max(1, await redis_ttl("listen:failures:#{job_id}"))
            log.debug "Listen: job #{job_id} failed #{failures} times, waiting #{retry_after}s"
            return status: 503, error: "Speech generation is failing, try again shortly", retry_after: retry_after
        null

    request_speech = (job, voice_id, signal) ->
        body =
            text: job.text
            model_id: job.model_id
            voice_settings: job.voice_settings
        body.language_code = job.language_code if job.language_code
        body.previous_text = job.previous_text if job.previous_text
        body.next_text = job.next_text if job.next_text
        # Django only stores well-formed voice ids (apps/listen/voices.py is_known_voice); encode anyway so a voice id
        # can never steer the request to another ElevenLabs endpoint with our key.
        http_fetch "#{ELEVENLABS_STREAM_URL}/#{encodeURIComponent(voice_id)}/stream?output_format=#{encodeURIComponent(job.output_format)}",
            method: 'POST'
            headers:
                'xi-api-key': API_KEY
                'Content-Type': 'application/json'
                'Accept': 'audio/mpeg'
            body: JSON.stringify body
            signal: signal

    # A free ElevenLabs plan can't use library voices over the API. Remember that so Django substitutes a
    # premade voice up front (apps/listen/voices.py library_voices_blocked), and retry this request with one.
    is_library_refusal = (status, detail) ->
        status == 402 or (status in [401, 403] and /library|paid_plan/i.test(detail))

    # Asks ElevenLabs for the job's audio, with the stand-in voice when a library voice is refused. Returns
    # ElevenLabs' final answer, and throws when ElevenLabs can't be reached or the watchdog gives up on it.
    start_speech = (job, watchdog) ->
        voice_id = job.voice_id
        response = await watchdog.wait request_speech(job, voice_id, watchdog.signal), timing.speech_response_ms
        return { response, voice_id, used_fallback: false } if response.ok
        detail = await watchdog.wait response.text(), timing.speech_response_ms
        if is_library_refusal(response.status, detail) and job.fallback_voice_id and not job.is_premade_voice
            log.debug "Listen: library voice #{voice_id} refused (#{response.status}), using #{job.fallback_voice_id}"
            await redis_set "listen:library_blocked", "1", 'EX', LIBRARY_BLOCKED_SECONDS
            voice_id = job.fallback_voice_id
            response = await watchdog.wait request_speech(job, voice_id, watchdog.signal), timing.speech_response_ms
            return { response, voice_id, used_fallback: true } if response.ok
            detail = await watchdog.wait response.text(), timing.speech_response_ms
        { response, voice_id, detail, used_fallback: false }

    # Streams ElevenLabs' audio to the player while buffering it. Returns the buffered chunks, or null when the
    # stream broke or stalled.
    relay_audio = (req, res, job_id, response, watchdog) ->
        res.writeHead 200,
            'Content-Type': 'audio/mpeg'
            'Cache-Control': 'no-store'
            'Accept-Ranges': 'none'
            'X-Listen-Cache': 'miss'
        client_gone = false
        req.on 'close', -> client_gone = true
        chunks = []
        reader = response.body.getReader()
        try
            loop
                { done, value } = await watchdog.wait reader.read(), timing.speech_stall_ms
                break if done
                chunk = Buffer.from value
                chunks.push chunk
                res.write chunk unless client_gone
        catch err
            log.debug "Listen: stream from ElevenLabs broke for job #{job_id}: #{err}"
            # Cancelling the reader lets go of a stalled ElevenLabs connection.
            reader.cancel(err).catch(->)
            # Destroying the response (rather than ending it cleanly) tells the player the segment is incomplete,
            # so it retries instead of skipping the rest of the paragraph.
            res.destroy() unless client_gone
            return null
        res.end() unless client_gone
        chunks

    upload = (job, chunks) ->
        audio = Buffer.concat chunks
        return if audio.length == 0
        watchdog = start_watchdog 'S3', timing.s3_upload_ms
        try
            response = await watchdog.wait http_fetch(job.s3_put_url,
                method: 'PUT'
                headers: { 'Content-Type': 'audio/mpeg' }
                body: audio
                signal: watchdog.signal
            ), timing.s3_upload_ms
        catch err
            log.debug "Listen: S3 upload failed (#{err}) for #{job.cache_key}"
            return
        finally
            watchdog.stop()
        if not response.ok
            log.debug "Listen: S3 upload failed (#{response.status}) for #{job.cache_key}"
            return
        marker = JSON.stringify
            duration: Math.round(audio.length / BYTES_PER_SECOND * 100) / 100
            bytes: audio.length
        await redis_set "listen:cached:#{job.cache_key}", marker, 'EX', CACHED_MARKER_SECONDS

    stream_segment = (req, res, job_id, job) ->
        watchdog = start_watchdog 'ElevenLabs', timing.speech_deadline_ms
        try
            try
                { response, voice_id, detail, used_fallback } = await start_speech job, watchdog
            catch err
                log.debug "Listen: ElevenLabs didn't answer job #{job_id}: #{err}"
                await count "listen:failures:#{job_id}", FAILURE_WINDOW_SECONDS
                res.status(if watchdog.signal.aborted then 504 else 502).json error: "Speech generation failed"
                return false
            if not response.ok
                log.debug "Listen: ElevenLabs #{response.status} for job #{job_id}: #{detail.substr(0, 300)}"
                await count "listen:failures:#{job_id}", FAILURE_WINDOW_SECONDS
                res.status(502).json error: "Speech generation failed", status: response.status
                return false
            # ElevenLabs accepted the request, so this audio is paid for and counts against the job.
            await count "listen:generations:#{job_id}", JOB_SECONDS
            chunks = await relay_audio req, res, job_id, response, watchdog
        finally
            watchdog.stop()
        return false unless chunks
        # Keep generating after the player hangs up: the audio is already paid for, so cache it. The stand-in
        # voice's audio doesn't belong under this job's cache key, so retire the job instead: the player's next
        # request goes back through Django, which rebuilds the manifest with the stand-in's own keys.
        if used_fallback
            await redis_del "listen:job:#{job_id}"
        else
            await upload job, chunks
        log.debug "Listen: streamed job #{job_id} (#{Math.round(Buffer.concat(chunks).length / 1024)}KB, voice #{voice_id}#{if used_fallback then '' else ', cached'})"
        true

    app.get /^\/listen\/stream\/([a-f0-9]{32})\.mp3$/, (req, res) =>
        job_id = req.params[0]
        try
            raw = await redis_get "listen:job:#{job_id}"
            return res.status(404).json(error: "Unknown or expired stream") unless raw
            job = JSON.parse raw

            if await redis_get("listen:cached:#{job.cache_key}")
                return res.redirect 302, job.s3_get_url
            # HEAD probes (some players send them) must not start a paid generation.
            if req.method == 'HEAD'
                res.writeHead 200, { 'Content-Type': 'audio/mpeg', 'Accept-Ranges': 'none' }
                return res.end()
            return res.status(503).json(error: "Listen isn't configured") unless API_KEY

            claim = await claim_segment job_id, job.cache_key
            return res.redirect 302, job.s3_get_url if claim == 'cached'
            if claim == 'busy'
                res.set 'Retry-After', String(BUSY_RETRY_SECONDS)
                return res.status(503).json(error: "This segment is still being generated")
            # Every exit from here on, refusals included, releases the lock.
            try
                refusal = await generation_refusal job_id
                if refusal
                    res.set 'Retry-After', String(refusal.retry_after) if refusal.retry_after
                    return res.status(refusal.status).json(error: refusal.error)
                await stream_segment req, res, job_id, job
            finally
                await redis_del "listen:lock:#{job.cache_key}"
        catch err
            log.debug "Listen: job #{job_id} failed: #{err}"
            if res.headersSent then res.destroy() else res.status(500).json(error: "Listen stream failed")

exports.listen = listen
