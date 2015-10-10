'use strict'

es = require 'event-stream'
BufferStreams = require 'bufferstreams'
gutil = require 'gulp-util'
magenta = gutil.colors.magenta
green = gutil.colors.green
path = require 'path'
url = require 'url'

PLUGIN_NAME = 'rewrite-css'

URL_REGEX = ///
            url
            \s* # Arbitrary white-spaces
            \(  # An opening bracket
            \s* # Arbitrary white-spaces
            (?!["']?data:) # explicitly don't match data-urls
            ([^\)]+) # Anything but a closing bracket
            \) # A closing bracket
            ///g # We want to replace all the matches

IMPORT_REGEX = ///
  @import
  \s* # Arbitrary white-spaces
  (["']) # the path must be quoted
  \s* # Arbitrary white-spaces
  ([^'"]+) # Anything but a closing quote
  \1 # The right closing quote
  ///g # We want to replace all the matches

cleanMatch = (url) ->
  url = url.trim()
  firstChar = url.substr 0, 1
  if firstChar is (url.substr -1) and (firstChar is '"' or firstChar is "'")
    url = url.substr 1, url.length - 2
  url

isRelativeUrl = (u) ->
  parts = url.parse u, false, true
  not parts.protocol and not parts.host

isRelativeToBase = (u) -> '/' is u.substr 0, 1

module.exports = (opt) ->
  opt ?= {}
  opt.debug ?= false
  opt.adaptPath ?= (ctx) ->
    path.join (path.relative ctx.destinationDir, ctx.sourceDir), ctx.targetFile

  unless typeof opt.adaptPath is 'function'
    throw new gutil.PluginError PLUGIN_NAME, 'adaptPath method is mssing'

  unless opt.destination
    throw new gutil.PluginError PLUGIN_NAME, 'destination directory is mssing'

  mungePath = (match, sourceFilePath, file) ->
    if (isRelativeUrl file) and not (isRelativeToBase file)
      destinationDir = opt.destination
      sourceDir = path.dirname sourceFilePath
      targetUrl = opt.adaptPath
        sourceDir: sourceDir
        sourceFile: sourceFilePath
        destinationDir: destinationDir
        targetFile: file

      if typeof targetUrl is 'string'
        # fix for windows paths
        targetUrl = targetUrl.replace ///\\///g, '/' if path.sep is '\\'
        return targetUrl.replace "'", "\\'"
    else if opt.debug
      gutil.log (magenta PLUGIN_NAME),
                'not rewriting absolute path for',
                (magenta match),
                'in',
                (magenta sourceFilePath)

  logRewrite = (match, sourceFilePath, destinationFilePath) ->
    if opt.debug
      gutil.log (magenta PLUGIN_NAME),
                'rewriting path for',
                (magenta match),
                'in',
                (magenta sourceFilePath),
                'to',
                (green destinationFilePath)

  rewriteUrls = (sourceFilePath, data) ->

    replaceCallback = (match, file, prefix) ->
      file = cleanMatch file
      newPath = mungePath match, sourceFilePath, file
      return match unless newPath

      ret = """#{prefix}url("#{newPath.replace('"', '\\"')}")"""
      logRewrite match, sourceFilePath, ret
      return ret

    data
    .replace URL_REGEX, (match, file) ->
      replaceCallback match, file, ''
    .replace IMPORT_REGEX, (match, _, file) ->
      replaceCallback match, file, '@import '

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
