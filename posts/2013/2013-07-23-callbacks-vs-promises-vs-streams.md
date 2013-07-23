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

Now, ideally I'd like to go quiet here while someone illustrates how a solid promise based implementation might look.  That I suspect may not happen.  So I've done my best to show what an implementation might look given the assumption that `fs.readdir` and `fs.stat` returned promise objects:

```js
var fs = require('fs');
var path = require('path');
var promiselib = require('some-promise-lib');

function findSamples(targetPath, callback) {
  fs.readdir(targetPath).then(function(files) {
    // get the full path names of the files
    files = files.map(path.join.bind(null, targetPath), callback);

    promiselib.every(files.map(fs.stat), function(results) {
      // remove files that aren't a directory
      var matchingFiles = files.filter(function(filename, index) {
        return results[index].isDirectory();
      });

      callback(null, matchingFiles.map(path.basename));      
    }, callback);
  });
}
```

The reality I think is that it looks pretty similar.  Feel free to provide a more "correct" implementation in the comments - I'm all ears.

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

I don't know about you, but for me I'm sold on [pull-streams](https://github.com/dominictarr/pull-streams).

Feel free to [discuss](https://github.com/DamonOehlman/damonoehlman.github.io/issues/18).