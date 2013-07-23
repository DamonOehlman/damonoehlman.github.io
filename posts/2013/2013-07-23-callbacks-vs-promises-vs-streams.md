# Callbacks vs Promises vs Streams

Right, here's a really simple task for you to complete in node using non-blocking implementations only (no sync functions allowed):

For a single source directory, return the list of directory names in that directory.  Essentially, I'm after the equivalent of running `ls -d */` in a directory on a *nix based system.  And yes, if you're trying to be clever then you could just spawn that and parse the output as one solution.

Basically, here is the implementation using pure callbacks using the [async](https://github.com/caolan/async) library to help ease some of the pain:

```js
var fs = require('fs');
var path = require('path');
var async = require('async');

function findSamples(targetPath, callback) {
  fs.readdir(targetPath, function(err, files) {
    if (err) return callback(err);

    // get the full path names of the files
    files = files.map(path.join.bind(null, targetPath));

    // stat each of the files
    async.map(files, fs.stat, function(err, results) {
      var matchingFiles;

      if (err) return callback(err);

      // remove files that aren't a directory
      matchingFiles = files.filter(function(filename, index) {
        return results[index].isDirectory();
      });

      callback(null, matchingFiles.map(path.basename));
    });
  });
}
```

[@ForbesLindesay](http://www.forbeslindesay.co.uk/) submitted the following promise implementation using his [promise](https://github.com/then/promise) library:

```js
var path = require('path');
var Promise = require('promise');
var fs = {
  readdir: Promise.denodeify(require('fs').readdir),
  stat: Promise.denodeify(require('fs').stat)
};

function findSamples(targetPath, callback) {
  return fs.readdir(targetPath).then(function(files) {
    // get the full path names of the files
    files = files.map(path.join.bind(null, targetPath));

    //get a promise for all the `Stat` objects of each file
    var stats = Promise.all(files.map(function (path) {
      return fs.stat(path)
    }));
    
    //get the result of that promise
    return stats.then(function (stats) {
      //remove files that aren't a directory
      var matchingFiles = files.filter(function (filename, index) {
        return stats[index].isDirectory();
      })

      return matchingFiles.map(path.basename);
    });
  }).nodeify(callback);
}

//usage
findSamples(__dirname, function (err, res) {
  if (err) throw err;
  ...
})
//alternative usage
findSamples(__dirname).then(function (res) {
  ...
})
.done();//throws any unhandled errors
```

Finally, let me show you what the implementation looks like using [pull-streams](https://github.com/dominictarr/pull-streams):

```js
var fs = require('fs');
var path = require('path');
var pull = require('pull-stream');

function findSamples(targetPath, callback) {
  fs.readdir(targetPath, function(err, files) {
    if (err) return callback(err);

    pull(
      pull.values(files),

      // join the path names and stat the files        
      pull.map(path.join.bind(null, targetPath)),
      pull.asyncMap(function(filename, callback) {
        fs.stat(filename, function(err, stats) {
          // create a compound object so we don't lose the filename
          // in the map transformation
          callback(err, { stats: stats, filename : filename });
        });
      }),

      // only keep directories
      pull.filter(function(data) {
        return data.stats.isDirectory();
      }),

      // transform back to a simple list of filenames
      pull.map(function(data) {
        return path.basename(data.filename);
      }),

      pull.collect(callback)
    );
  });
}
```

While the implementation for the pull-stream is a little longer, IMO the control flow feels more linear and thus I think easier to comprehend.  Additionally, I went one step further and started creating some pull-stream filesystem helpers in the way of [fpath](https://github.com/DamonOehlman/fpath) which futher simplifies the code to:

```js
var fpath = require('fpath');
var pull = require('pull-stream');

function findSamples(targetPath, callback) {
  pull(
    fpath.entries(targetPath),
    fpath.filter(function(filename, stats) {
      return stats.isDirectory()
    }),
    pull.map(path.basename),
    pull.collect(callback)
  );
}
```

I don't know about you, but for me I'm sold on [pull-streams](https://github.com/dominictarr/pull-stream).

Feel free to [discuss](https://github.com/DamonOehlman/damonoehlman.github.io/issues/18).

Thanks go to people who have already contributed alternative examples in the issue comments already.  As a result I've started collecting some examples together in a separate [async-comparison](https://github.com/DamonOehlman/async-comparison) repo which will give you the opportunity to play around with some of the approaches outlined.
