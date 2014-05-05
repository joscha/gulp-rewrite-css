es = require 'event-stream'
BufferStreams = require 'bufferstreams'
gutil = require 'gulp-util'
path = require 'path'

PLUGIN_NAME = 'rewrite-css'

URL_REGEX = ///
            url
            \s* # Arbitrary white-spaces
            \(  # An opening bracket
            \s* # Arbitrary white-spaces
            ([^\)]+) # Anything but a closing bracket
            \) # A closing bracket
            ///g # We want to replace all the matches

cleanMatch = (url) ->
  url = url.trim()
  if (firstChar = url.substr 0, 1) is (url.substr -1) and (firstChar is '"' or firstChar is "'")
    url = url.substr 1, url.length - 2
  url

module.exports = (opt) ->
  opt ?= {}
  opt.debug ?= false

  throw new gutil.PluginError PLUGIN_NAME, 'destination directory is mssing' unless opt.destination

  rewriteUrls = (sourceFilePath, data) ->
    sourceDir = path.dirname sourceFilePath
    destinationDir = opt.destination
    data.replace URL_REGEX, (match, file) =>
      file = cleanMatch file
      allegedTarget = path.join sourceDir, file
      targetUrl = path.join (path.relative destinationDir, sourceDir), file
      ret = """url("#{targetUrl.replace('"', '\\"')}")"""
      gutil.log (gutil.colors.magenta PLUGIN_NAME), 'rewriting path for', (gutil.colors.magenta match), 'in', (gutil.colors.magenta sourceFilePath), 'to', (gutil.colors.magenta ret) if opt.debug
      ret

  bufferReplace = (file, data) ->
    rewriteUrls file.path, data

  streamReplace = (file) ->
    (err, buf, cb) ->
      cb gutil.PluginError PLUGIN_NAME, err if err

      # Use the buffered content
      buf = Buffer bufferReplace file, String buf

      # Bring it back to streams
      cb null, buf
      return

  es.map (file, callback) ->
    if file.isNull()
      callback null, file

    if file.isStream()
      replacementFn = streamReplace opt, file
      file.contents = file.contents.pipe new BufferStreams streamReplace file
      callback null, file

    if file.isBuffer()
      newFile = file.clone()
      newContents = bufferReplace file, String newFile.contents
      newFile.contents = new Buffer newContents
      callback null, newFile
