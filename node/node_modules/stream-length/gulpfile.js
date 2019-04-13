var gulp = require('gulp');

/* CoffeeScript compile deps */
var path = require('path');
var gutil = require('gulp-util');
var concat = require('gulp-concat');
var rename = require('gulp-rename');
var coffee = require('gulp-coffee');
var cache = require('gulp-cached');
var remember = require('gulp-remember');
var plumber = require('gulp-plumber');

var source = ["lib/**/*.coffee", "index.coffee"]

gulp.task('coffee', function() {
	return gulp.src(source, {base: "."})
		.pipe(plumber())
		.pipe(cache("coffee"))
		.pipe(coffee({bare: true}).on('error', gutil.log)).on('data', gutil.log)
		.pipe(remember("coffee"))
		.pipe(gulp.dest("."));
});

gulp.task('watch', function () {
	gulp.watch(source, ['coffee']);
});

gulp.task('default', ['coffee', 'watch']);