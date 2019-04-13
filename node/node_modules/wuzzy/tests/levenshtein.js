/* Tests for the levenshtein logic. */
var expect = require('chai').expect;
var wuzzy = require('../index');

describe('levenshtein tests', function () {
	it('should correctly calcuate the levenshtein distance', function () {
		var tests = [
			{
				a: ['M', 'A', 'R', 'T', 'H', 'A'],
				b: ['M', 'A', 'R', 'H', 'T', 'A'],
				exp: 4 / 6
			},
			{
				a: 'MARTHA',
				b: 'MARHTA',
				exp: 4 / 6
			}, 
			{
				a: ['D', 'W', 'A', 'Y', 'N', 'E'],
				b: ['D', 'U', 'A', 'N', 'E'],
				exp: 4 / 6
			},
			{
				a: 'DWAYNE',
				b: 'DUANE',
				exp: 4 / 6
			},
			{
				a: ['D', 'I', 'X', 'O', 'N'],
				b: ['D', 'I', 'C', 'K', 'S', 'O', 'N', 'X'],
				exp: 4 / 8
			},
			{
				a: 'DIXON',
				b: 'DICKSONX',
				exp: 4 / 8
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
			var actual = wuzzy.levenshtein(el.a, el.b);
			expect(actual).to.equal(el.exp);
		});
	});
});