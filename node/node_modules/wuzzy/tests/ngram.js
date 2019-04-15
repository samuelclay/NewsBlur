/* Tests for the n-gram edit logic. */
var expect = require('chai').expect;
var wuzzy = require('../index');

describe('n-gram tests', function () {
	it('should correctly calcuate the n-gram distance', function () {
		var tests = [
			{
				a: ['M', 'A', 'R', 'T', 'H', 'A'],
				b: ['M', 'A', 'R', 'H', 'T', 'A'],
				exp: .667
			},
			{
				a: 'MARTHA',
				b: 'MARHTA',
				exp: .667
			},  
			{
				a: ['D', 'W', 'A', 'Y', 'N', 'E'],
				b: ['D', 'U', 'A', 'N', 'E'],
				exp: .583
			},
			{
				a: 'DWAYNE',
				b: 'DUANE',
				exp: .583
			},
			{
				a: ['D', 'I', 'X', 'O', 'N'],
				b: ['D', 'I', 'C', 'K', 'S', 'O', 'N', 'X'],
				exp: .5
			},
			{
				a: 'DIXON',
				b: 'DICKSONX',
				exp: .5
			},
			{
				a: ['A', 'B', 'C', 'V', 'W', 'X', 'Y', 'Z'],
				b: ['C', 'A', 'B', 'V', 'W', 'X', 'Y', 'Z'],
				exp: .625
			},
			{
				a: 'ABCVWXYZ',
				b: 'CABVWXYZ',
				exp: .625
			},
			{
				a: ['A', 'L'],
				b: ['A', 'L'],
				exp: 1
			},
			{
				a: 'AL',
				b: 'AL',
				exp: 1
			},
			{
				a: ['A'],
				b: ['A', 'A'],
				exp: .5
			},
			{
				a: 'A',
				b: 'AA',
				exp: .5
			},
			{
				a: ['A'],
				b: ['A'],
				exp: 1
			},
			{
				a: 'A',
				b: 'A',
				exp: 1
			},
			{
				a: ['A'],
				b: ['B'],
				exp: 0
			},
			{
				a: 'A',
				b: 'B',
				exp: 0
			},
			{
				a: ['J', 'O', 'E'],
				b: ['M', 'A', 'T', 'T'],
				exp: 0
			},
			{
				a: 'JOE',
				b: 'MATT',
				exp: 0
			},
			{
				a: ['J', 'O', 'E'],
				b: ['J', 'O', 'E'],
				exp: 1
			},
			{
				a: 'JOE',
				b: 'JOE',
				exp: 1
			}
		];
		tests.forEach(function (el) {
			var actual = Math.round(wuzzy.ngram(el.a, el.b) * 1000) / 1000;
			expect(actual).to.equal(el.exp);
		});
	});
});