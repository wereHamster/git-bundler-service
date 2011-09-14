
{ spawn } = require 'child_process'

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

mongoose.model('Bundle', BundleSchema);
Bundle = mongoose.model('Bundle');


# ---------------------------------------------------------------------------
# Mojo
# ---------------------------------------------------------------------------

mojo = require 'mojo'
mojoConnection = new mojo.Connection db: 'bundler'

class Job extends mojo.Template

  perform: (id, source) ->
    Bundle.findById id, (err, bundle) =>
      bundle.status = 'building'
      bundle.save ->

      proc = spawn './bundle.sh', [ process.env.PWD, id, source ]
      proc.on 'exit', (code) =>
        bundle.status = code == 0 and 'complete' or 'failed'
        bundle.save ->
        @complete()
      proc.stdout.on 'data', (data) -> console.log '' + data
      proc.stderr.on 'data', (data) -> console.log '' + data


# ---------------------------------------------------------------------------
# Express
# ---------------------------------------------------------------------------

express = require('express')
app = express.createServer();
app.configure ->
  app.use(express.logger());
  app.use(express.static(__dirname + '/public'));
  app.use(express.bodyParser());

app.configure 'development', ->
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));


# Custom url params
app.param 'bundle', (req, res, next, id) ->
  Bundle.findById id, (err, bundle) ->
    if (err)
      return next(err)
    if (!bundle)
      return next(new Error('Bundle ' + id + ' not found'))

    req.bundle = bundle; next();

createBundle = (source, fn) ->
  Bundle.where({ source: source }).desc('timestamp').limit(1).run (err, bundles) ->
    if err
      fn(err);
    else if (bundles and bundles[0] and bundles[0].timestamp > new Date(Date.now() - 3600))
      fn(null, bundles[0])
    else
      bundle = new Bundle({ source: source })
      bundle.save (err) ->
        unless err
          mojoConnection.enqueue Job.name, bundle._id, source, ->
        fn(err, bundle)


# ---------------------------------------------------------------------------
# Here be the routes
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
