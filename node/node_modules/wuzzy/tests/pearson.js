/* Tests for the jaccard logic. */
var expect = require('chai').expect;
var wuzzy = require('../index');

describe('pearson tests', function () {
	it('should correctly calcuate the pearson correlation', function () {
		var tests = [
			{
				a: {a: 2.5, b: 1},
				b: {a: 2.5, b: 1},
				exp: 1
			},
			{
				a: {a: 2.5, b: 3.5, c: 3.0, d: 3.5, e: 2.5, f: 3.0},
				b: {a: 3.0, b: 3.5, c: 1.5, d: 5.0, e: 3.5, f: 3.0, g: 5.0},
				exp: .396
			},
			{
				a: {j: 5.5},
				b: {o: 3.5, e: 6.0},
				exp: 0
			}
		];
		tests.forEach(function (el) {
			var actual = Math.round(wuzzy.pearson(el.a, el.b) * 1000) / 1000;
			expect(actual).to.equal(el.exp);
		});
	});
});