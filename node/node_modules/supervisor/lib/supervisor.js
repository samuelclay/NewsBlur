var util = require("util");
var fs = require("fs");
var spawn = require("child_process").spawn;
var fileExtensionPattern;

exports.run = run;

function run (args) {
  var arg, next, watch, program, programArgs, extensions, executor, poll_interval;
  while (arg = args.shift()) {
    if (arg === "--help" || arg === "-h" || arg === "-?") {
      return help();
    } else if (arg === "--watch" || arg === "-w") {
      watch = args.shift();
    } else if (arg === "--poll-interval" || arg === "-p") {
      poll_interval = parseInt(args.shift());
    } else if (arg === "--extensions" || arg === "-e") {
      extensions = args.shift();
    } else if (arg === "--exec" || arg === "-x") {
      executor = args.shift();
    } else if (arg === "--") {
      // Remaining args are: program [args, ...]
      program = args.shift();
      programArgs = args.slice(0);
      break;
    } else if (arg.indexOf("-") && !args.length) {
      // Assume last arg is the program
      program = arg;
    }
  }
  if (!program) {
    return help();
  }
  if (!watch) {
    watch = ".";
  }
  if (!poll_interval) {
    poll_interval = 0;
  }

  var programExt = program.match(/.*\.(.*)/);
  programExt = programExt && programExt[1];

  if (!extensions) {
    // If no extensions passed try to guess from the program
    extensions = "node|js";
    if (programExt && extensions.indexOf(programExt) == -1)
      extensions += "|" + programExt;
  }
  fileExtensionPattern = new RegExp("^.*\.(" + extensions + ")$");

  if (!executor) {
    executor = (programExt === "coffee") ? "coffee" : "node";
  }

  util.puts("")
  util.debug("Running node-supervisor with");
  util.debug("  program '" + program + "'");
  util.debug("  --watch '" + watch + "'");
  util.debug("  --extensions '" + extensions + "'");
  util.debug("  --exec '" + executor + "'");
  util.puts("");

  // if we have a program, then run it, and restart when it crashes.
  // if we have a watch folder, then watch the folder for changes and restart the prog
  startProgram(program, executor, programArgs);
  var watchItems = watch.split(',');
  watchItems.forEach(function (watchItem) {
    if (!watchItem.match(/^\/.*/)) { // watch is not an absolute path
      // convert watch item to absolute path
      watchItem = process.cwd() + '/' + watchItem;
    }
    util.debug("Watching directory '" + watchItem + "' for changes.");
    findAllWatchFiles(watchItem, function(f) {
      watchGivenFile( f, poll_interval );
    });
  });
};

function print (m, n) { util.print(m+(!n?"\n":"")); return print; }

function help () {
  print
    ("")
    ("Node Supervisor is used to restart programs when they crash.")
    ("It can also be used to restart programs when a *.js file changes.")
    ("")
    ("Usage:")
    ("  supervisor [options] <program>")
    ("")
    ("Required:")
    ("  <program>")
    ("    The program to run.")
    ("")
    ("Options:")
    ("  -w|--watch <watchItems>")
    ("    A comma-delimited list of folders or js files to watch for changes.")
    ("    When a change to a js file occurs, reload the program")
    ("    Default is '.'")
    ("")
    ("  -p|--poll-interval <milliseconds>")
    ("    How often to poll watched files for changes.")
    ("    Defaults to Node default.")
    ("")
    ("  -e|--extensions <extensions>")
    ("    Specific file extensions to watch in addition to defaults.")
    ("    Used when --watch option includes folders")
    ("    Default is 'node|js'")
    ("")
    ("  -x|--exec <executable>")
    ("    The executable that runs the specified program.")
    ("    Default is 'node'")
    ("")
    ("  -h|--help|-?")
    ("    Display these usage instructions.")
    ("")
    ("Examples:")
    ("  supervisor myapp.js")
    ("  supervisor myapp.coffee")
    ("  supervisor -w scripts -e myext -x myrunner myapp")
    ("");
};

function startProgram (prog, exec, args) {
  if (args)
    util.debug("Starting child process with '" + exec + " " + prog + " " + args + "'");
  else
    util.debug("Starting child process with '" + exec + " " + prog + "'");
  var spawnme = args ? [prog].concat(args) : [prog];
  var child = exports.child = spawn(exec, spawnme);
  child.stdout.addListener("data", function (chunk) { chunk && util.print(chunk); });
  child.stderr.addListener("data", function (chunk) { chunk && util.debug(chunk); });
  child.addListener("exit", function () { startProgram(prog, exec, args); });
}

var timer = null, mtime = null; crash_queued = false;
function crash (oldStat, newStat) {

  // we only care about modification time, not access time.
  if (
    newStat.mtime.getTime() === oldStat.mtime.getTime()
    || crash_queued
  ) return;

  crash_queued = true;
  var child = exports.child;
  setTimeout(function() {
    util.debug("crashing child");
    process.kill(child.pid);
    crash_queued = false;
  }, 50);
}

function watchGivenFile (watch, poll_interval) {
  fs.watchFile(watch, { persistent: true, interval: poll_interval }, crash);
}

var findAllWatchFiles = function(path, callback) {
  fs.stat(path, function(err, stats){
    if (err) {
      util.error('Error retrieving stats for file: ' + path);
    } else {
      if (stats.isDirectory()) {
        fs.readdir(path, function(err, fileNames) {
          if(err) {
            util.puts('Error reading path: ' + path);
          }
          else {
            fileNames.forEach(function (fileName) {
              findAllWatchFiles(path + '/' + fileName, callback);
            });
          }
        });
      } else {
        if (path.match(fileExtensionPattern)) {
          callback(path);
        }
      }
    }
  });
};
