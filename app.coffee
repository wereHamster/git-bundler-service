
{ spawn } = require 'child_process'
String::trim = -> this.replace /^\s+|\s+$/g, ''


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# How long the bundles are cached (in milliseconds)
TIMEOUT = 7 * 24 * 60 * 60 * 1000


# ---------------------------------------------------------------------------
# Mongoose
# ---------------------------------------------------------------------------

mongoose = require('mongoose')
mongoose.connect('mongodb://localhost/bundler');

BundleSchema = new mongoose.Schema({
  timestamp: { type: Date, required: true, default: Date.now }
  status: { type: String }
})

BundleSchema.methods.bundlePath = ->
  process.env.PWD + '/data/bundles/' + this._id + '/bundle'

BundleSchema.methods.iso8601 = ->
  d = this.timestamp
  pad = (n) -> n < 10 and '0'+n or n
  date = [d.getUTCFullYear(), pad(d.getUTCMonth()+1), pad(d.getUTCDate())].join '-'
  time = [pad(d.getUTCHours()), pad(d.getUTCMinutes()), pad(d.getUTCSeconds())].join ':'
  return "#{date}T#{time}Z"

mongoose.model('Bundle', BundleSchema);
Bundle = mongoose.model('Bundle');


# ---------------------------------------------------------------------------
# Mojo
# ---------------------------------------------------------------------------

mojo = require 'mojo'
mojoConnection = new mojo.Connection db: 'bundler'

class Job extends mojo.Template

  perform: (id, source) ->
    console.log 'perform'
    Bundle.findById id, (err, bundle) =>
      bundle.status = 'building'
      bundle.save =>

      proc = spawn './bundle.sh', [ process.env.PWD, id, source ]

      proc.stdout.on 'data', (data) -> console.log '' + data
      proc.stderr.on 'data', (data) -> console.log '' + data

      proc.on 'exit', (code) =>
        bundle.status = code == 0 and 'complete' or 'failed'
        bundle.save => @complete()


# ---------------------------------------------------------------------------
# Express
# ---------------------------------------------------------------------------

express = require('express')
app = express.createServer();
app.set('view engine', 'jade');

app.configure ->
  app.use(express.logger());
  app.use(express.static(__dirname + '/public'));
  app.use(express.bodyParser());

app.configure 'development', ->
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));

# Middleware
countBundles = (req, res, next) ->
  Bundle.count { 'status': 'complete' }, (err, count) ->
    return next err if err
    req.count = count; next()

# Custom url params
app.param 'bundle', (req, res, next, id) ->
  Bundle.findById id, (err, bundle) ->
    if (err)
      return next(err)
    if (!bundle)
      return next(new Error('Bundle ' + id + ' not found'))

    req.bundle = bundle; next();

createBundle = (source, fn) ->
  source = source.trim()

  Bundle.where('source', source).where('status').in(['complete', 'building']).desc('timestamp').limit(1).exec (err, bundles) ->
    if err
      fn(err);
    else if (bundles and bundles[0] and bundles[0].timestamp > new Date(Date.now() - TIMEOUT))
      fn(null, bundles[0])
    else
      bundle = new Bundle({ source: source, status: 'queued' })
      bundle.save (err) ->
        if err?
          fn(err)
        else
          mojoConnection.enqueue Job.name, '' + bundle._id, source, ->
            fn(null, bundle)


# ---------------------------------------------------------------------------
# Here be the routes
# ---------------------------------------------------------------------------

app.get '/', countBundles, (req, res) ->
  res.render('index', { count: req.count, title: 'git bundler service' });

app.post '/bundle', (req, res) ->
  source = req.param('source')
  if source and source.length > 10
    createBundle source, (err, bundle) ->
      res.partial('bundle', { bundle: bundle });
  else
    res.send(400)

app.get '/bundle/:bundle', countBundles, (req, res) ->
  res.render('bundle', { count: req.count, title: "bundle #{req.bundle._id}", bundle: req.bundle });

app.get '/bundle/:bundle/download', (req, res) ->
  res.download(req.bundle.bundlePath(), "#{req.bundle._id}.bundle");

app.post '/site/deploy', (req, res) ->
  payload = JSON.parse req.body.payload
  if payload.ref is 'refs/heads/master' and payload.after?
    process.send cmd: 'zion:fork', deploy: payload.after
  res.send 201


# ---------------------------------------------------------------------------
# API v1 (unsupported at the moment)
# ---------------------------------------------------------------------------

# POST /v1/bundle; params: source=<url>
app.post '/v1/bundle', (req, res) ->
  # Create a new bundle and redirect the client to the bundle resource.
  createBundle req.param('source'), (err, bundle) ->
    res.redirect('/v1/bundle/' + bundle._id);

# GET /v1/bundle/:bundle
app.get '/v1/bundle/:bundle', (req, res) ->
  switch req.bundle.status
    when 'failed'
      res.send(500)
    when 'complete'
      res.download(req.bundle.bundlePath(), "#{req.bundle._id}.bundle");
    else
      res.send(204)

app.listen(parseInt(process.env.PORT) || 3000)


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------

(new mojo.Worker mojoConnection, [ Job ]).poll()
