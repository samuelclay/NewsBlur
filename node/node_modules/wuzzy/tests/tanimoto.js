/* Tests for the tanimoto logic. */
var expect = require('chai').expect;
var wuzzy = require('../index');

describe('tanimoto tests', function () {
	it('should correctly calcuate the tanimoto distance', function () {
		var tests = [
			{
				a: [1, 2, 3, 3, 4, 5, 6, 6],
				b: [2, 3, 5],
				exp: (3 / (3 + 8 - 3))
			},
			{
				a: ['a', 'b', 'c', 'd', 'd', 'e', 'f', 'f'],
				b: ['a', 'e', 'f'],
				exp: (3 / (3 + 8 - 3))
			},
			{
				a: 'abcddeff',
				b: 'aef',
				exp: (3 / (3 + 8 - 3))
			},
			{
				a: ['abe', 'babe', 'cabe', 'dabe', 'eabe', 'fabe', 'fabe'],
				b: ['babe'],
				exp: (1 / (1 + 7 - 1))
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
			expect(wuzzy.tanimoto(el.a, el.b)).to.equal(el.exp);
		});
	});
});