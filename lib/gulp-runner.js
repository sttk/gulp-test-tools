'use strict';

var child = require('child_process');
var path = require('path');
var os = require('os');

var fs = require('fs-extra');
var semver = require('semver');

var cmdsep = '; ';
var escapeBs = path.join;
var needRedirect = false;
var tempDirId = 0;

if (os.platform() === 'win32') {
  cmdsep = ' & ';

  escapeBs = function() {
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

  function basedirFn(dir) {
    inst._basedir = dir;
    return {
      chdir: chdirFn,
      gulp: gulpFn,
    };
  }

  function chdirFn(dir) {
    inst._command = 'cd ' + escapeBs(dir);
    return { gulp: gulpFn };
  }

  function gulpFn(/*...args*/) {
    if (inst._command) {
      inst._command += cmdsep;
    }
    inst._command += 'node ' + escapeBs(gulpPath);
    for (var i = 0, n = arguments.length; i < n; i++) {
      inst._command += ' ' + arguments[i];
    }
    return { run: runFn };
  }

  function runFn(cb) {
    var redirectDir = path.resolve(__dirname, '.temp' + tempDirId);
    tempDirId++;
    var redirectStdout = path.join(redirectDir, 'result.out');
    var redirectStderr = path.join(redirectDir, 'result.err');

    if (needRedirect) {
      fs.mkdirpSync(redirectDir);
    }

    var cmd = '';
    if (inst._basedir) {
      cmd += 'cd ' + escapeBs(path.resolve(inst._basedir)) + cmdsep;
    }
    cmd += inst._command;

    if (needRedirect) {
      cmd += ' > ' + redirectStdout + ' 2> ' + redirectStderr;
    }

    if (!inst._verbose) {
      if (needRedirect) {
        child.exec(cmd, function(err, stdout, stderr) {
          stdout = fs.readFileSync(redirectStdout, 'utf8');
          stderr = fs.readFileSync(redirectStderr, 'utf8');
          fs.remove(redirectDir);
          cb(err, stdout, stderr);
        });
      } else {
        child.exec(cmd, cb);
      }
      inst._command = '';
      return;
    }

    console.log('---- command');
    console.log(insertEol(cmd));

    child.exec(cmd, function(err, stdout, stderr) {
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
    });
  }
};
