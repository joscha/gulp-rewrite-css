'use strict'

es = require 'event-stream'
BufferStreams = require 'bufferstreams'
gutil = require 'gulp-util'
path = require 'path'
url = require 'url'

PLUGIN_NAME = 'rewrite-css'

URL_REGEX = ///
            url
            \s* # Arbitrary white-spaces
            \(  # An opening bracket
            \s* # Arbitrary white-spaces
            ([^\)]+) # Anything but a closing bracket
            \) # A closing bracket
            ///g # We want to replace all the matches

# from http://stackoverflow.com/questions/3446170
escapeRegExp = (str) ->
  str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"

stripPrefix = (prefix, string) ->
  rgx = new RegExp '^' + escapeRegExp prefix
  string.replace rgx, ''

cleanMatch = (url) ->
  url = url.trim()
  if (firstChar = url.substr 0, 1) is (url.substr -1) and (firstChar is '"' or firstChar is "'")
    url = url.substr 1, url.length - 2
  url

isRelativeUrl = (u) ->
  parts = url.parse u, false, true
  not parts.protocol and not parts.host

module.exports = (opt) ->
  opt ?= {}
  opt.debug ?= false

  throw new gutil.PluginError PLUGIN_NAME, 'destination directory is mssing' unless opt.destination

  rewriteUrls = (file, data) ->
    sourceFilePath = file.path
    sourceDir = path.dirname sourceFilePath

    data.replace URL_REGEX, (match, file) =>
      ret = match
      file = cleanMatch file

      if isRelativeUrl file
        if opt.base and opt.prefix
          pathToNewCssFile = stripPrefix opt.base, sourceFilePath
          realImportFileLocation = path.join opt.destination, opt.prefix, file
          actualCssFile = (path.join opt.destination, pathToNewCssFile)
          relativeRealTargetImportFile = path.relative path.dirname(actualCssFile), realImportFileLocation
          targetUrl = relativeRealTargetImportFile
        else
          targetUrl = path.join (path.relative opt.destination, sourceDir), file

        ret = """url("#{targetUrl.replace('"', '\\"')}")"""
        gutil.log (gutil.colors.magenta PLUGIN_NAME), 'rewriting path for', (gutil.colors.magenta match), 'in', (gutil.colors.magenta sourceFilePath), 'to', (gutil.colors.magenta ret) if opt.debug
      else
        gutil.log (gutil.colors.magenta PLUGIN_NAME), 'not rewriting absolute path for', (gutil.colors.magenta match), 'in', (gutil.colors.magenta sourceFilePath) if opt.debug
      ret

  bufferReplace = (file, data) ->
    rewriteUrls file, data

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
