var logger = console.log;
var logs = "";
console.log = function(msg){
//	logger(msg);
	logs += msg;
};

var testScript = "test/fixture.js"
var testCase  = require('nodeunit').testCase;
var supervisor = require('../lib/supervisor.js');

var assertValueExists = function(assertion, test){
	test.ok(assertion);
	test.done();
	setTimeout(function(){
		logs = "";
		process.kill();
	}, 20)
};

var tests = {
	tearDown:function testGroupOneTearDown(cb){
		logs = "";
		console.log = logger;
		cb();
	},
	"should exist when supervisor is imported": function (test) {
		test.ok(!!supervisor);
		test.done();
	},
	"should accept a debug port when passed through": function(test){
		var EXPECTED = '--debug=1234';
		supervisor.run([ EXPECTED, "--no-restart-on", "exit", "--", testScript]);
		assertValueExists(logs.indexOf(EXPECTED) > -1, test);
	},
	"should use debug alone when no port number passed through": function(test){
		var EXPECTED = '--debug';
		supervisor.run([ EXPECTED, "--no-restart-on", "exit", "--", testScript]);
		assertValueExists(logs.indexOf(EXPECTED) > -1, test);
	},
	"should not overwrite with debug-brk value if debug-brk also passed through": function(test){
		var EXPECTED = '--debug=1236';
		supervisor.run([ EXPECTED, "--debug-brk", "--no-restart-on", "exit", "--", testScript]);
		assertValueExists(logs.indexOf(EXPECTED) > -1, test);
	},
	"should pass the debug-brk flag through": function(test){
		var EXPECTED = '--debug-brk';
		supervisor.run([ EXPECTED, "--no-restart-on", "exit", "--", testScript]);
		assertValueExists(logs.indexOf(EXPECTED) > -1, test);
	},
	"should pass the debug-brk port number arg through with debug-brk flag": function(test){
		var EXPECTED = '--debug-brk=5859';
		supervisor.run([ EXPECTED, "--no-restart-on", "exit", "--", testScript]);
		assertValueExists(logs.indexOf(EXPECTED) > -1, test);
	}
};

module.exports.testGroupOne = testCase(tests);
