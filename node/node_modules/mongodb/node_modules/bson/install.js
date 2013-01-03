var spawn = require('child_process').spawn,
  exec = require('child_process').exec;

process.stdout.write("================================================================================\n");
process.stdout.write("=                                                                              =\n");
process.stdout.write("=  Attempting to build bson c++ extension                                      =\n");
process.stdout.write("=   Windows: no build will be attempted as binaries are prepackaged            =\n");
process.stdout.write("=   Unix: on failure the package will still install without the C++ extension  =\n");
process.stdout.write("=                                                                              =\n");
process.stdout.write("================================================================================\n");

// Check if we want to build the native code
var build_native = process.env['npm_package_config_mongodb_native'] != null ? process.env['npm_package_config_mongodb_native'] : 'false';
if(process.env['npm_config_mongodb_debug']) {
  console.log("== process.env['npm_package_config_mongodb_native'] :: " + process.env['npm_package_config_mongodb_native']);
  console.log("== build_native :: " + build_native);
}

build_native = process.env['npm_config_mongodb_native'] != null ? process.env['npm_config_mongodb_native'] : build_native;
if(process.env['npm_config_mongodb_debug']) {
  console.log("== process.env['npm_config_mongodb_native'] :: " + process.env['npm_config_mongodb_native']);
  console.log("== build_native :: " + build_native);
}

build_native = build_native == 'true' ? true : false;
if(process.env['npm_config_mongodb_debug']) {
  console.log("== build_native :: " + build_native);
}

// If we are building the native bson extension ensure we use gmake if available
if(process.platform != "win32" && process.platform != "win64") {
  // Check if we need to use gmake
  exec('which gmake', function(err, stdout, stderr) {
    // Set up spawn command
    var make = null;
    // No gmake build using make
    if(err != null) {
      make = spawn('make', ['node_gyp'], {cwd:process.env['PWD']});
    } else {
      make = spawn('gmake', ['node_gyp'], {cwd:process.env['PWD']});
    }

    // Execute spawn
    make.stdout.on('data', function(data) {
      process.stdout.write(data);
    })

    make.stderr.on('data', function(data) {
      process.stdout.write(data);
    })

    make.on('exit', function(code) {
      process.stdout.write('child process exited with code ' + code + "\n");
    })
  });
}
