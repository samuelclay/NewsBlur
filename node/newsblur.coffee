app = require('express')()
server = require('http').createServer(app)
log    = require './log.js'
Sentry = require "@sentry/node"
Tracing = require "@sentry/tracing"
require('dotenv').config()

original_page = require('./original_page.js').original_page
original_text = require('./original_text.js').original_text
favicons = require('./favicons.js').favicons
unread_counts = require('./unread_counts.js').unread_counts


Sentry.init({
  dsn: process.env.SENTRY_DSN,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Tracing.Integrations.Express({ 
      app
    })
  ],
  tracesSampleRate: 1.0
})

app.use(Sentry.Handlers.requestHandler())
app.use(Sentry.Handlers.tracingHandler())

original_page(app)
original_text(app)
favicons(app)
unread_counts(server)

app.get "/debug", (req, res) ->
  throw new Error("Debugging Sentry")

app.use(Sentry.Handlers.errorHandler())

log.debug "Starting NewsBlur Node Server"
server.listen(8008)
