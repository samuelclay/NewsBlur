var _ = require('lodash');

function sum (arr) {
	return arr.reduce(function (p, c, i, a) {
		return p + c;
	});
}

function ensureArr (arr) {
	if (_.isArray(arr)) {
		return arr;
	} else if (typeof arr === 'string') {
		return arr.split('');
	} else {
		throw Error('Parameter must be a string or array.');
	}
}

/**
 * Computes the jaro-winkler distance for two given arrays.
 *
 * NOTE: this implementation is based on the one found in the
 * Lucene Java library.
 *
 * h3 Examples:
 *
 *     wuzzy.jarowinkler(
 *     		['D', 'W', 'A', 'Y', 'N', 'E'],
 *     		['D', 'U', 'A', 'N', 'E']
 *     	);
 *     	// -> 0.840
 *
 *     wuzzy.jarowinkler(
 *     		'DWAYNE',
 *     		'DUANE'
 *     	);
 *     	// -> 0.840
 *
 * @param  {String/Array} a - the first string/array to compare
 * @param  {String/Array} b - the second string/array to compare
 * @param  {Number} t - the threshold for adding
 * the winkler bonus (defaults to 0.7)
 * @return {Number}   returns the jaro-winkler distance for
 * the two provided arrays.
 */
exports.jarowinkler = function (a, b, t) {
	a = ensureArr(a);
	b = ensureArr(b);

	var max, min;
	if (a.length > b.length) {
		max = a;
		min = b;
	} else {
		max = b;
		min = a;
	}
	var threshold = t ? t : .7;
	var weight = .1;
	var range = Math.floor(Math.max((max.length / 2) - 1, 0));
	var mIdx = [];
	var mFlg = [];
	var mi, xi, xn, c1;
	var matches = 0;
	for (mi = 0; mi < min.length; mi++) {
		c1 = min[mi];
		for (xi = Math.max(mi - range, 0), xn = Math.min(mi + range + 1, max.length);
			 xi < xn;
			 xi++) {
			if (!mFlg[xi] && (c1 === max[xi])) {
				mIdx[mi] = xi;
				mFlg[xi] = true;
				matches++;
				break;
			}
		}
	}

	var ma = [];
	var mb = [];
	var i, si;
	var trans = 0;
	var prefix = 0;
	for (i = 0, si = 0; i < min.length; i++) {
		if (mIdx[i] > -1) {
			ma[si] = min[i];
			si++;
		}
	}
	for(i = 0, si = 0; i < max.length; i++) {
		if (mFlg[i]) {
			mb[si] = max[i];
			si++;
		}
	}
	for (mi = 0; mi < ma.length; mi++) {
		if (ma[mi] !== mb[mi]) {
			trans++;
		}
	}
	for (mi = 0; mi < min.length; mi++) {
		if (a[mi] === b[mi]) {
			prefix++;
		} else {
			break;
		}
	}

	var m = matches;
	var t = trans / 2;
	if (!m) {
		return 0;
	} else {
		var j = (m / a.length + m / b.length + (m - t) / m) / 3
		var jw = (j < threshold
			? j
			: (j + Math.min(weight, 1 / max.length) * prefix * (1 - j)));
		return jw;
	}

}

/**
 * Calculates the levenshtein distance for the
 * two provided arrays and returns the normalized
 * distance.
 *
 * h3 Examples:
 *
 *     wuzzy.levenshtein(
 *     		['D', 'W', 'A', 'Y', 'N', 'E'],
 *     		['D', 'U', 'A', 'N', 'E']
 *     	);
 *     	// -> 0.66666667
 *
 * 		or
 *
 *     wuzzy.levenshtein(
 *     		'DWAYNE',
 *     		'DUANE'
 *     	);
 *     	// -> 0.66666667
 * 
 * @param  {String/Array} a - the first string/array to compare
 * @param  {String/Array} b - the second string/array to compare
 * @param  {Object} w - (optional) a set of key/value pairs
 * definining weights for the deletion (key: d), insertion
 * (key: i), and substitution (key: s). default values are
 * 1 for all operations.
 * @return {Number}   returns the levenshtein distance for
 * the two provided arrays.
 */
exports.levenshtein = function (a, b, w) {
	a = ensureArr(a);
	b = ensureArr(b);

	if (a.length === 0) {
		return b.length;
	}
	if (b.length === 0) {
		return a.length;
	}

	var weights = (w ? w : {
		d: 1,
		i: 1,
		s: 1
	});
	var v0 = [];
	var v1 = [];
	var vlen = b.length + 1;
	var i,j;
	var cost;
	var mlen;

	for (i = 0; i < vlen; i++) {
		v0[i] = i;
	}

	for (i = 0; i < a.length; i++) {
		v1[0] = i + 1;

		for (j = 0; j < b.length; j++) {
			cost = (a[i] === b[j]) ? 0 : weights.s;
			v1[j + 1] = Math.min(
				v1[j] + weights.d,
				v0[j + 1] + weights.i,
				v0[j] + cost
			);
		}

		for (j = 0; j < vlen; j++) {
			v0[j] = v1[j];
		}
	}

	mlen = Math.max(a.length, b.length);

	return (mlen - v1[b.length]) / mlen;
}

/**
 * Computes the n-gram edit distance for any n (defaults to 2).
 *
 * NOTE: this implementation is based on the one found in the
 * Lucene Java library.
 *
 * h3 Examples:
 *
 *     wuzzy.ngram(
 *     		['D', 'W', 'A', 'Y', 'N', 'E'],
 *     		['D', 'U', 'A', 'N', 'E']
 *     	);
 *     	// -> 0.583
 *
 * 		or
 *
 *     wuzzy.ngram(
 *     		'DWAYNE',
 *     		'DUANE'
 *     	);
 *     	// -> 0.583
 * 
 * @param  {String/Array} a - the first string/array to compare
 * @param  {String/Array} b - the second string/array to compare
 * @param  {Number} ng - (optional) the n-gram size to work with (defaults to 2)
 * @return {Number}   returns the ngram distance for
 * the two provided arrays.
 */
exports.ngram = function (a, b, ng) {
	a = ensureArr(a);
	b = ensureArr(b);

	var al = a.length;
	var bl = b.length;
	var n = (ng ? ng : 2);
	var cost;
	var i, j, ni, ti, tn, ec;
	var sa = [];
	var p  = [];
	var d = [];
	var _d = [];
	var t_j = [];
	var pdl = al + 1;

	// empty string situation
	if ((al === 0) || (bl === 0)) {
		if (al === bl) {
			return 1;
		} else {
			return 0;
		}
	}

	// smaller than n situation
	cost = 0;
	if ((al < n) || (bl < n)) {
		for (i = 0, ni = Math.min(al, bl); i < ni; i++) {
			if (a[i] === b[i]) {
				cost++;
			}
		}
		return cost / Math.max(al, bl);
	}

	for (i = 0; i < (al + n - 1); i++) {
		if (i < (n - 1)) {
			sa[i] = 0;
		} else {
			sa[i] = a[i - n + 1];
		}
	}

	for (i = 0; i <= al; i++) {
		p[i] = i;
	}

	for (j = 1; j <= bl; j++) {
		if (j < n) {
			for (ti = 0; ti < (n - j); ti++) {
				t_j[ti] = 0;
			}
			for (ti = (n - j); ti < n; ti++) {
				t_j[ti] = b[ti - (n - j)];
			}
		} else {
			t_j = b.slice(j - n, j);
		}
		d[0] = j;
		for (i = 1; i <= al; i++) {
			cost = 0;
			tn = n;
			for (ni = 0; ni < n; ni++) {
				if (sa[i - 1 + ni] !== t_j[ni]) {
					cost++;
				} else if (sa[i - 1 + ni] === 0) {
					tn--;
				}
			}
			ec = cost / tn;
			d[i] = Math.min(
				Math.min(
					d[i - 1] + 1,
					p[i] + 1
				),
				p[i - 1] + ec
			);
		}

		_d = p;
		p = d;
		d = _d;
	}

	return 1.0 - (p[al] / Math.max(al, bl));
}

/**
 * Calculates a pearson correlation score for two given
 * objects (compares values of similar keys).
 *
 * h3 Examples:
 *
 *     wuzzy.pearson(
 *     		{a: 2.5, b: 3.5, c: 3.0, d: 3.5, e: 2.5, f: 3.0},
 *     		{a: 3.0, b: 3.5, c: 1.5, d: 5.0, e: 3.5, f: 3.0, g: 5.0}
 *     	);
 *     	// -> 0.396
 *
 * 		or
 *
 *     wuzzy.pearson(
 *     		{a: 2.5, b: 1},
 *     		{o: 3.5, e: 6.0}
 *     	);
 *     	// -> 1.0
 * 
 * @param  {Object} a - the first object to compare
 * @param  {Object} b - the second object to compare
 * @return {Number}   returns the pearson correlation for
 * the two provided arrays.
 */
exports.pearson = function (a, b) {
	var sk = [];
	Object.keys(a).forEach(function (k) {
		if (b[k]) {
			sk.push(k);
		}
	});
	var n = sk.length;

	if (n === 0) {
		return 0;
	}

	var sa = sum(sk.map(function (k) {
		return a[k];
	}));
	var sb = sum(sk.map(function (k) {
		return b[k];
	}));

	var sas = sum(sk.map(function (k) {
		return Math.pow(a[k], 2);
	}));

	var sbs = sum(sk.map(function (k) {
		return Math.pow(b[k], 2);
	}));

	var sp = sum(sk.map(function (k) {
		return a[k] * b[k];
	}));

	var num = sp - (sa * sb / n);
	var den = Math.sqrt((sas - Math.pow(sa, 2) / n) * (sbs - Math.pow(sb, 2) / n));

	if (den === 0) {
		return 0;
	} else {
		return num / den;
	}
}

/**
 * Calculates the jaccard index for the two
 * provided arrays.
 *
 * h3 Examples:
 *
 *     wuzzy.jaccard(
 *     		['a', 'b', 'c', 'd', 'e', 'f'],
 *     		['a', 'e', 'f']
 *     	);
 *     	// -> 0.5
 *
 * 		or
 *
 *     wuzzy.jaccard(
 *     		'abcdef',
 *     		'aef'
 *     	);
 *     	// -> 0.5
 *
 * 		or 
 *
 *     wuzzy.jaccard(
 *     		['abe', 'babe', 'cabe', 'dabe', 'eabe', 'fabe'],
 *     		['babe']
 *     	);
 *     	// -> 0.16666667
 * 
 * @param  {String/Array} a - the first string/array to compare
 * @param  {String/Array} b - the second string/array to compare
 * @return {Number}   returns the jaccard index for
 * the two provided arrays.
 */
exports.jaccard = function (a, b) {
	a = ensureArr(a);
	b = ensureArr(b);

	return (_.intersection(a, b).length / _.union(a, b).length);
}

/**
 * Calculates the tanimoto distance (weighted jaccard index).
 *
 * h3 Examples:
 *
 *     wuzzy.tanimoto(
 *     		['a', 'b', 'c', 'd', 'd', 'e', 'f', 'f'],
 *     		['a', 'e', 'f']
 *     	);
 *     	// -> 0.375
 *
 * 		or
 *
 *     wuzzy.tanimoto(
 *     		'abcddeff',
 *     		'aef'
 *     	);
 *     	// -> 0.375
 *
 * 		or 
 *
 *     wuzzy.tanimoto(
 *     		['abe', 'babe', 'cabe', 'dabe', 'eabe', 'fabe', 'fabe'],
 *     		['babe']
 *     	);
 *     	// -> 0.14285714
 * 
 * @param  {String/Array} a - the first string/array to compare
 * @param  {String/Array} b - the second string/array to compare
 * @return {Number}   returns the tanimoto distance for
 * the two provided arrays.
 */
exports.tanimoto = function (a, b) {
	a = ensureArr(a);
	b = ensureArr(b);

	var both = _.intersection(a, b).length;
	return  (both / (a.length + b.length - both));
}
