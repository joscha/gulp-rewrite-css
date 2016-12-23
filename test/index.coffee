require 'mocha'
require 'should'
sinon = require 'sinon'
gulp = require 'gulp'
proxyquire = require 'proxyquire'
gutilStub =
  log: ->
    #console.log(arguments)
path = require 'path'
rewriteCss = proxyquire '../src',
  'gulp-util': gutilStub
  'path': path
es = require 'event-stream'
Stream = require 'stream'
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

  assert = (file, done, expectedOverride = null) ->
    inFile = getFixturePath file
    if expectedOverride
      expected = loadFixture expectedOverride

    gulp.src(inFile)
    .pipe(rewriteCss(opts))
    .pipe es.map (file) ->
      file.contents.toString().should.eql expected
      done()

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
        log = """
              rewrite-css rewriting path for url(fonts/OpenSans.woff) \
              in #{inFile} to url("../../fonts/OpenSans.woff")
              """
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
          expectedLog = """
          rewrite-css not rewriting absolute path for \
          url(http://www.fonts.com/OpenSans.woff) in #{inFile}
          """
          args = stripAnsi(gutilStub.log.firstCall.args.join(' '))
          args.should.eql expectedLog
          done()

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
          expected.should.be.eql data.toString()
          done()

  describe 'edge cases', ->

    it 'should handle single quoted URLs', (done) ->
      assert 'index.quotes.single.css', done
    it 'should handle double quoted URLs', (done) ->
      assert 'index.quotes.double.css', done
    it 'should handle URLs with whitespaces', (done) ->
      assert 'index.whitespaces.css', done
    it 'should handle URLs with a double quote', (done) ->
      assert 'index.url.with.quotes.css',
              done,
              'index.url.with.quotes.expected.css'
    it 'should leave relative URLs starting with slash alone', (done) ->
      assert 'relative-slash.css', done, 'relative-slash.css'
    it 'should leave svgView URLs alone', (done) ->
      assert 'index.svgPath.css', done, 'index.svgPath.expected.css'

    describe 'data-urls', ->
      it 'should be left alone', (done) ->
        assert 'data-urls.css', done, 'data-urls.css'
      it 'should not break on weird characters within a data-url', (done) ->
        assert 'data-urls-svg.css', done, 'data-urls-svg.css'

    describe 'Windows', ->
      origSeparator = path.sep

      beforeEach ->
        path.sep = '\\'

      afterEach ->
        path.sep = origSeparator

      it 'should fix path separators', (done) ->
        assert 'index.windows.css',
                done,
                'index.windows.expected.css'

  describe '@import rewriting', ->
    beforeEach ->
      opts =
        destination: getFixturePath 'another/dir'

    it 'should rewrite @import statements', (done) ->
      assert 'imports.css', done, 'imports.expected.css'

  describe 'use adaptPath option', ->
    opts =
      destination: 'path/to/destination'

    it 'should call adaptPath with the correct parameters', (done) ->
      opts.adaptPath = sinon.stub().returns('../my/arbitrary/file.css')

      test = ->
        opts.adaptPath.calledTwice.should.be.true
        opts.adaptPath.getCall(0).args[0].should.be.eql
          sourceDir: getFixturePath()
          sourceFile: getFixturePath('opt.adaptPath.css')
          destinationDir: opts.destination
          targetFile: 'my/1.css'

        opts.adaptPath.getCall(1).args[0].should.be.eql
          sourceDir: getFixturePath()
          sourceFile: getFixturePath('opt.adaptPath.css')
          destinationDir: opts.destination
          targetFile: 'my/2.css'

        done()
      assert 'opt.adaptPath.css', test, 'opt.adaptPath.expected.css'

  describe 'minified css', ->
    beforeEach ->
      opts =
        destination: getFixturePath 'another/dir'

    it 'should rewrite urls in minified css', (done) ->
      assert 'minified.css', done, 'minified.expected.css'
