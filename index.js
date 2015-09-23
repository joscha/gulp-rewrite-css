'use strict';
var BufferStreams, PLUGIN_NAME, URL_REGEX, cleanMatch, es, gutil, isRelativeToBase, isRelativeUrl, magenta, path, url;

es = require('event-stream');

BufferStreams = require('bufferstreams');

gutil = require('gulp-util');

magenta = gutil.colors.magenta;

path = require('path');

url = require('url');

PLUGIN_NAME = 'rewrite-css';

URL_REGEX = /url\s*\(\s*([^\)]+)\)/g;

cleanMatch = function(url) {
    var firstChar;
    url = url.trim();
    firstChar = url.substr(0, 1);
    if (firstChar === (url.substr(-1)) && (firstChar === '"' || firstChar === "'")) {
        url = url.substr(1, url.length - 2);
    }
    return url;
};

isRelativeUrl = function(u) {
    var parts;
    parts = url.parse(u, false, true);
    return !parts.protocol && !parts.host;
};

isRelativeToBase = function(u) {
    return '/' === u.substr(0, 1);
};

module.exports = function(opt) {
    var bufferReplace, rewriteUrls, streamReplace;
    if (opt == null) {
        opt = {};
    }
    if (opt.debug == null) {
        opt.debug = false;
    }
    if (!opt.destination) {
        throw new gutil.PluginError(PLUGIN_NAME, 'destination directory is mssing');
    }
    rewriteUrls = function(sourceFilePath, data) {
        var destinationDir, sourceDir;
        sourceDir = path.dirname(sourceFilePath);
        destinationDir = opt.destination;
        return data.replace(URL_REGEX, function(match, file) {
            var ret, targetUrl;
            ret = match;
            file = cleanMatch(file);
            if ((isRelativeUrl(file)) && !(isRelativeToBase(file))) {
                targetUrl = path.join(path.relative(destinationDir, sourceDir), file);
                if (path.sep === '\\') {
                    targetUrl = targetUrl.replace(/\\/g, '/');
                }
                ret = "url(\"" + (targetUrl.replace('"', '\\"')) + "\")";
                if (opt.debug) {
                    gutil.log(magenta(PLUGIN_NAME), 'rewriting path for', magenta(match), 'in', magenta(sourceFilePath), 'to', magenta(ret));
                }
            } else {
                if (opt.debug) {
                    gutil.log(magenta(PLUGIN_NAME), 'not rewriting absolute path for', magenta(match), 'in', magenta(sourceFilePath));
                }
            }
            return ret;
        });
    };
    bufferReplace = function(file, data) {
        return rewriteUrls(file.path, data);
    };
    streamReplace = function(file) {
        return function(err, buf, cb) {
            if (err) {
                cb(gutil.PluginError(PLUGIN_NAME, err));
            }
            buf = Buffer(bufferReplace(file, String(buf)));
            cb(null, buf);
        };
    };
    return es.map(function(file, callback) {
        var newContents, newFile, replacementFn;
        if (file.isNull()) {
            callback(null, file);
        }
        if (file.isStream()) {
            replacementFn = streamReplace(opt, file);
            file.contents = file.contents.pipe(new BufferStreams(streamReplace(file)));
            callback(null, file);
        }
        if (file.isBuffer()) {
            newFile = file.clone();
            newContents = bufferReplace(file, String(newFile.contents));
            newFile.contents = new Buffer(newContents);
            return callback(null, newFile);
        }
    });
};

