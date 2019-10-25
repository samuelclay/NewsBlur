/* Tests for the jaccard logic. */
var expect = require('chai').expect;
var wuzzy = require('../index');

describe('jaccard tests', function () {
	it('should correctly calcuate the jaccard index', function () {
		var tests = [
			{
				a: [1, 2, 3, 4, 5, 6],
				b: [2, 3, 5],
				exp: 3/6
			},
			{
				a: ['a', 'b', 'c', 'd', 'e', 'f'],
				b: ['a', 'e', 'f'],
				exp: 3/6
			},
			{
				a: 'abcdef',
				b: 'aef',
				exp: 3/6
			},
			{
				a: ['abe', 'babe', 'cabe', 'dabe', 'eabe', 'fabe'],
				b: ['babe'],
				exp: 1/6
			},
			{
				a: [1, 2, 3, 4, 5, 6],
				b: [7, 8, 9, 10, 11, 12],
				exp: 0
			},
			{
				a: [1, 2, 3, 4, 5, 6],
				b: [1, 2, 3, 4, 5, 6],
				exp: 1
			}
		];
		tests.forEach(function (el) {
			expect(wuzzy.jaccard(el.a, el.b)).to.equal(el.exp);
		});
	});
});