require 'mocha'
require 'should'
sinon = require 'sinon'
gulp = require 'gulp'
proxyquire = require 'proxyquire'
gutilStub =
  log: ->
    #console.log(arguments);
rewriteCss = proxyquire '../src',
  'gulp-util': gutilStub
es = require 'event-stream'
Stream = require 'stream'
path = require 'path'
fs = require 'fs'
stripAnsi = require 'strip-ansi'

describe 'gulp-rewrite-css', ->
  opts = null
  expected = null
  inFile = null

  beforeEach ->
    sinon.spy gutilStub, 'log'
    opts =
      destination: path.join __dirname, './fixtures/another/dir'

    inFile = path.join __dirname, './fixtures/index.css'
    expectedFile = path.join __dirname, './fixtures/index.expected.css'
    expected = fs.readFileSync expectedFile, 'utf8'

  afterEach ->
    gutilStub.log.restore()

  describe 'params', ->
    it 'should throw an error if no destination path is passed', ->
      rewriteCss.should.throw 'destination directory is mssing'

    it 'should give debug output if debug is set to true', (done) ->
      opts.debug = true
      true.should.be.true
      gulp.src(inFile)
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        gutilStub.log.calledOnce.should.be.true
        log = """rewrite-css rewriting path for url(fonts/OpenSans.woff) in #{inFile} to url("../../fonts/OpenSans.woff")"""
        stripAnsi(gutilStub.log.firstCall.args.join(' ')).should.eql log
        done()

  describe 'with buffers', ->
    it 'should return file.contents as a buffer', (done) ->
      gulp.src(inFile)
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        file.contents.should.be.an.instanceof Buffer
        done()

    it 'should rewrite URLs', (done) ->
      gulp.src(inFile)
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        expected.should.eql file.contents.toString()
        done()

  describe 'with streams', ->
    it 'should return file.contents as a stream', (done) ->
      gulp.src(inFile, {buffer: false})
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        file.contents.should.be.an.instanceof Stream
        done()

    it 'should rewrite URLs', (done) ->
      gulp.src(inFile, {buffer: false})
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        file.contents.pipe es.wait (err, data) ->
          expected.should.be.eql data
          done()

  describe 'edge cases', ->

    assert = (file, done, expectedOverride = null) ->
      inFile = path.join __dirname, file
      if expectedOverride
        expectedFile = path.join __dirname, expectedOverride
        expected = fs.readFileSync expectedFile, 'utf8'

      gulp.src(inFile)
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        expected.should.eql file.contents.toString()
        done()

    it 'should handle single quoted URLs', (done) ->
      assert './fixtures/index.quotes.single.css', done
    it 'should handle double quoted URLs', (done) ->
      assert './fixtures/index.quotes.double.css', done
    it 'should handle URLs with whitespaces', (done) ->
      assert './fixtures/index.whitespaces.css', done
    it 'should handle URLs with a double quote', (done) ->
      assert './fixtures/index.url.with.quotes.css', done, './fixtures/index.url.with.quotes.expected.css'
