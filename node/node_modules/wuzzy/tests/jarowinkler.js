/* Tests for the jaro-winkler logic. */
var expect = require('chai').expect;
var wuzzy = require('../index');

describe('jaro-winkler tests', function () {
	it('should correctly calcuate the jaro-winkler distance', function () {
		var tests = [
			{
				a: ['M', 'A', 'R', 'T', 'H', 'A'],
				b: ['M', 'A', 'R', 'H', 'T', 'A'],
				exp: 0.961
			}, 
			{
				a: 'MARTHA',
				b: 'MARHTA',
				exp: 0.961
			}, 
			{
				a: ['D', 'W', 'A', 'Y', 'N', 'E'],
				b: ['D', 'U', 'A', 'N', 'E'],
				exp: 0.840
			},
			{
				a: 'DWAYNE',
				b: 'DUANE',
				exp: 0.840
			},
			{
				a: ['D', 'I', 'X', 'O', 'N'],
				b: ['D', 'I', 'C', 'K', 'S', 'O', 'N', 'X'],
				exp: 0.813
			},
			{
				a: 'DIXON',
				b: 'DICKSONX',
				exp: 0.813
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
			var actual = Number(wuzzy.jarowinkler(el.a, el.b).toFixed(3));
			expect(actual).to.equal(el.exp);
		});
	});
});