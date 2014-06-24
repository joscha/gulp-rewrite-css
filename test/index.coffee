require 'mocha'
require 'should'
sinon = require 'sinon'
gulp = require 'gulp'
proxyquire = require 'proxyquire'
gutilStub =
  log: ->
    # console.log.apply(console, arguments);
rewriteCss = proxyquire '../src',
  'gulp-util': gutilStub
es = require 'event-stream'
Stream = require 'stream'
path = require 'path'
fs = require 'fs'
gutil = require 'gulp-util'
stripAnsi = require 'strip-ansi'

getFixturePath = (relativePath = '') ->
  path.join __dirname, 'fixtures', relativePath

loadFixture = (relativePath) ->
  p = getFixturePath relativePath
  fs.readFileSync p, 'utf8'

describe 'gulp-rewrite-css', ->
  opts = null
  expected = null
  inFile = null

  beforeEach ->
    sinon.spy gutilStub, 'log'
    opts =
      destination: getFixturePath 'another/dir'

    inFile = getFixturePath 'index.css'
    expected = loadFixture 'index.expected.css'

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

  describe 'with null file', ->
    it 'should return the file as-is', (done) ->
      file = new gutil.File
        base: getFixturePath()
        cwd: __dirname,
        path: inFile
        contents: null

      stream = rewriteCss opts
      stream.on 'data', (processed) ->
        file.should.be.exactly processed
        done()
      stream.write file

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

    describe 'absolute URLs', ->

      beforeEach ->
        inFile = getFixturePath 'absolute.css'
        expected = loadFixture 'absolute.css'

      it 'should not rewrite absolute URLs', (done) ->
        gulp.src(inFile)
        .pipe(rewriteCss(opts))
        .pipe es.map (file) ->
          expected.should.eql file.contents.toString()
          done()

      it 'shoud log that it did not rewrite absolute URLs', (done) ->
        opts.debug = true
        gulp.src(inFile)
        .pipe(rewriteCss(opts))
        .pipe es.map (file) ->
          gutilStub.log.calledOnce.should.be.true
          expectedLog = """rewrite-css not rewriting absolute path for url(http://www.fonts.com/OpenSans.woff) in #{inFile}"""
          stripAnsi(gutilStub.log.firstCall.args.join(' ')).should.eql expectedLog
          done()

    it 'should rewrite complex URLs', (done) ->
      cwd = process.cwd()
      opts.debug = true

      opts.destination = '/var/cdn/'
      opts.base = '/var/s/'
      opts.prefix = 'a/b/'

      file = new gutil.File
        cwd: '/var'
        path: '/var/s/min/group/style.css'
        base: '/var/s/'
        contents: new Buffer 'url(fonts/OpenSans.eot)', 'utf8'

      stream = rewriteCss opts
      stream.on 'data', (file) ->
        file.contents.toString('utf8').should.eql 'url("../../a/b/fonts/OpenSans.eot")'
        done()

      stream.write file

  describe 'with streams', ->
    it 'should return file.contents as a stream', (done) ->
      gulp.src(inFile, {
        buffer: false
      })
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        file.contents.should.be.an.instanceof Stream
        done()

    it 'should rewrite URLs', (done) ->
      gulp.src(inFile, {
        buffer: false
      })
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        file.contents.pipe es.wait (err, data) ->
          expected.should.be.eql data
          done()

  describe 'edge cases', ->

    assert = (file, done, expectedOverride = null) ->
      inFile = getFixturePath file
      if expectedOverride
        expected = loadFixture expectedOverride

      gulp.src(inFile)
      .pipe(rewriteCss(opts))
      .pipe es.map (file) ->
        expected.should.eql file.contents.toString()
        done()

    it 'should handle single quoted URLs', (done) ->
      assert 'index.quotes.single.css', done
    it 'should handle double quoted URLs', (done) ->
      assert 'index.quotes.double.css', done
    it 'should handle URLs with whitespaces', (done) ->
      assert 'index.whitespaces.css', done
    it 'should handle URLs with a double quote', (done) ->
      assert 'index.url.with.quotes.css', done, 'index.url.with.quotes.expected.css'
