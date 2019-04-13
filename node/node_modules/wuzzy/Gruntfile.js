var mocha = require('mocha');

module.exports = function (grunt) {

	/* add the grunt-mocha-test task */
	grunt.loadNpmTasks('grunt-mocha-test');

	/* grunt configuration */
	grunt.initConfig({
		mochaTest: {
			test: {
				options: {
					reporter: 'spec'
				},
				src: ['tests/*.js']
			}
		}
	});

	/* test task */
	grunt.registerTask('test', 'mochaTest');

	/* documentation generation task */
	grunt.registerTask('documentation', function () {
		var markdox = require('markdox');
		var done = this.async();

		var files = [
			'./index.js'
		];

		markdox.process(files, 'documentation.md', done);
	});
};