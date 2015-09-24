#[gulp](https://github.com/gulpjs/gulp)-rewrite-css

[![NPM version][npm-image]][npm-url]
[![Build Status][travis-image]][travis-url]
[![Coverage Status][coveralls-image]][coveralls-url]
[![Dependency Status][depstat-image]][depstat-url]
[![devDependency Status][devdepstat-image]][devdepstat-url]

A gulp plugin that allows rewriting url references in CSS

## Information

<table>
<tr>
<td>Package</td><td>gulp-rewrite-css</td>
</tr>
<tr>
<td>Description</td>
<td>Rewrite `url(...)` references in CSS files.</td>
</tr>
<tr>
<td>Node Version</td>
<td>>= 0.10</td>
</tr>
</table>

## Installation

```console
npm install --save gulp-rewrite-css
```

## Usage

```javascript
var gulp = require('gulp'),
    rewriteCSS = require('gulp-rewrite-css');

gulp.task('my-rewrite', function() {
  var dest = './dist/'
  return gulp.src('./static/css/*.css')
    .pipe(rewriteCSS({destination:dest}))
    .pipe(gulp.dest(dest));
});
```
### Options
* `destination` (required) - the target directory for the processed CSS. Paths are rewritten relatively to that directory.
* `[debug]` (optional, defaults to false) - whether to log what gulp-rewrite-css is doing

#### Advanced Usage

If you know exactly how you want your URLs rewritten, the following alternate syntax is allowed:

* `enhanced.re` (required) - a [RegExp](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp) object.  It will be matched against the bare URL (url() and quotes are stripped)
* `enhanced.subst` (required) - the substitution string for the eventual call to [String.prototype.replace()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace).

## License

MIT (c) 2015 Joscha Feth <joscha@feth.com>

[npm-url]: https://npmjs.org/package/gulp-rewrite-css
[npm-image]: http://img.shields.io/npm/v/gulp-rewrite-css.svg

[travis-url]: https://travis-ci.org/joscha/gulp-rewrite-css
[travis-image]: http://img.shields.io/travis/joscha/gulp-rewrite-css.svg

[coveralls-url]: https://coveralls.io/r/joscha/gulp-rewrite-css
[coveralls-image]: http://img.shields.io/coveralls/joscha/gulp-rewrite-css.svg
[coveralls-original-image]: https://coveralls.io/repos/joscha/gulp-rewrite-css/badge.png

[depstat-url]: https://david-dm.org/joscha/gulp-rewrite-css
[depstat-image]: https://david-dm.org/joscha/gulp-rewrite-css.svg?theme=shields.io

[devdepstat-url]: https://david-dm.org/joscha/gulp-rewrite-css#info=devDependencies
[devdepstat-image]: https://david-dm.org/joscha/gulp-rewrite-css/dev-status.svg?theme=shields.io
