'use strict';

var child = require('child_process');
var path = require('path');
var os = require('os');
var fs = require('fs-extra');
var semver = require('semver');

var cmdsep = '; ';
var normalizePath = path.join;
var needRedirect = true;
var tempDirId = 0;

if (os.platform() === 'win32') {
  cmdsep = ' & ';

  normalizePath = function escapeBackslash(/*...args*/) {
    var pth = path.join.apply(path, arguments);
    return pth.replace(/\\/g, '\\\\');
  };

  needRedirect = semver.lt(process.version, '0.12.0');
}

var regexpInsEol = new RegExp(cmdsep, 'g');

function insertEol(cmd) {
  return cmd.replace(regexpInsEol, cmdsep + '\n');
}


var gulpPath = path.join(require.resolve('gulp-cli'), '../bin/gulp.js');
var basePath = process.cwd();

function GulpRunner(opt) {
  function Constructor(opt) {
    this._command = '';
    this._verbose = !!opt.verbose;
    this._basedir = basePath;
  }
  Constructor.prototype = GulpRunner.prototype;
  return new Constructor(opt || {});
}

GulpRunner.prototype.basedir = function(dir) {
  this._basedir = dir;
  return {
    chdir: this.chdir,
    gulp: this.gulp,
  };
};

GulpRunner.prototype.chdir = function(/*...args*/) {
  this._command = 'cd ' + normalizePath.apply(this, arguments));
  return { gulp: this.gulp };
};

GulpRunner.prototype.gulp = function(/*...args*/) {
  if (this._command) {
    this._command += cmdsep;
  }
  this._command += 'node ' + normalizePath(gulpPath);
  for (var i = 0, n = arguments.length; i < n; i++) {
    inst._command += ' ' + arguments[i];
  }
  return { run: this.run };
};

GulpRunner.prototype.run = function(cb) {
  var redirectDir = path.resolve(__dirname, '.temp' + tempDirId);
  var redirectStdout = path.join(redirectDir, 'result.out');
  var redirectStderr = path.join(redirectDir, 'result.err');
  tempDirId++;

  fs.mkdirpSync(redirectDir);

  var cmd = '';
  if (this._basedir) {
    cmd += 'cd ' + normalizePath(path.resolve(this._basedir)) + cmdsep;
  }
  cmd += this._command;

  if (needRedirect) {
    cmd += ' > ' + redirectStdout + ' 2> ' + redirectStderr;
  }

  if (this._verbose) {
    console.log('---- command');
    console.log(insertEol(cmd));
  }
  child.exec(cmd, createCallback(cb));
};

module.exports = function(opt) {
  opt = opt || {};
  var inst = {};
  inst.basedir = basedirFn;
  inst.chdir = chdirFn;
  inst.gulp = gulpFn;
  inst._command = '';
  inst._verbose = !!opt.verbose;
  inst._basedir = basePath;
  return inst;
};

  function createCommand() {

    return cmd;
  }

  function createCallback(cb) {
    return function(err, stdout, stderr) {
      if (!inst._verbose) {
        if (needRedirect) {
          stdout = fs.readFileSync(redirectStdout, 'utf8');
          stderr = fs.readFileSync(redirectStderr, 'utf8');
          fs.remove(redirectDir);
        }
        cb(err, stdout, stderr);
        inst._command = '';
      } else {
        if (needRedirect) {
          stdout = fs.readFileSync(redirectStdout, 'utf8');
          stderr = fs.readFileSync(redirectStderr, 'utf8');
          fs.remove(redirectDir);
        }
        console.log('---- error');
        console.log(err);
        console.log('---- stdout');
        console.log(stdout);
        console.log('---- stderr');
        console.log(stderr);
        console.log('----.');
        cb(err, stdout, stderr);
        inst._command = '';
      }
    };
  }
};
