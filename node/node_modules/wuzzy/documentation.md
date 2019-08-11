

<!-- Start ./index.js -->

## jarowinkler(a, b, t)

Computes the jaro-winkler distance for two given arrays.

NOTE: this implementation is based on the one found in the
Lucene Java library.
### Examples:

    wuzzy.jarowinkler(
    		['D', 'W', 'A', 'Y', 'N', 'E'],
    		['D', 'U', 'A', 'N', 'E']
    	);
    	// -> 0.840

    wuzzy.jarowinkler(
    		'DWAYNE',
    		'DUANE'
    	);
    	// -> 0.840

### Params: 

* **String|Array** *a* - the first string/array to compare
* **String|Array** *b* - the second string/array to compare
* **Number** *t* - the threshold for adding

### Return:

* **Number** returns the jaro-winkler distance for

## levenshtein(a, b, w)

Calculates the levenshtein distance for the
two provided arrays and returns the normalized
distance.
### Examples:

    wuzzy.levenshtein(
    		['D', 'W', 'A', 'Y', 'N', 'E'],
    		['D', 'U', 'A', 'N', 'E']
    	);
    	// -> 0.66666667

		or

    wuzzy.levenshtein(
    		'DWAYNE',
    		'DUANE'
    	);
    	// -> 0.66666667

### Params: 

* **String|Array** *a* - the first string/array to compare
* **String|Array** *b* - the second string/array to compare
* **Object** *w* - (optional) a set of key/value pairs

### Return:

* **Number** returns the levenshtein distance for

## ngram(a, b, ng)

Computes the n-gram edit distance for any n (defaults to 2).

NOTE: this implementation is based on the one found in the
Lucene Java library.
### Examples:

    wuzzy.ngram(
    		['D', 'W', 'A', 'Y', 'N', 'E'],
    		['D', 'U', 'A', 'N', 'E']
    	);
    	// -> 0.583

		or

    wuzzy.ngram(
    		'DWAYNE',
    		'DUANE'
    	);
    	// -> 0.583

### Params: 

* **String|Array** *a* - the first string/array to compare
* **String|Array** *b* - the second string/array to compare
* **Number** *ng* - (optional) the n-gram size to work with (defaults to 2)

### Return:

* **Number** returns the ngram distance for

## pearson(a, b)

Calculates a pearson correlation score for two given
objects (compares values of similar keys).
### Examples:

    wuzzy.pearson(
    		{a: 2.5, b: 3.5, c: 3.0, d: 3.5, e: 2.5, f: 3.0},
    		{a: 3.0, b: 3.5, c: 1.5, d: 5.0, e: 3.5, f: 3.0, g: 5.0}
    	);
    	// -> 0.396

		or

    wuzzy.pearson(
    		{a: 2.5, b: 1},
    		{o: 3.5, e: 6.0}
    	);
    	// -> 1.0

### Params: 

* **Object** *a* - the first object to compare
* **Object** *b* - the second object to compare

### Return:

* **Number** returns the pearson correlation for

## jaccard(a, b)

Calculates the jaccard index for the two
provided arrays.
### Examples:

    wuzzy.jaccard(
    		['a', 'b', 'c', 'd', 'e', 'f'],
    		['a', 'e', 'f']
    	);
    	// -> 0.5

		or

    wuzzy.jaccard(
    		'abcdef',
    		'aef'
    	);
    	// -> 0.5

		or 

    wuzzy.jaccard(
    		['abe', 'babe', 'cabe', 'dabe', 'eabe', 'fabe'],
    		['babe']
    	);
    	// -> 0.16666667

### Params: 

* **String|Array** *a* - the first string/array to compare
* **String|Array** *b* - the second string/array to compare

### Return:

* **Number** returns the jaccard index for

## tanimoto(a, b)

Calculates the tanimoto distance (weighted jaccard index).
### Examples:

    wuzzy.tanimoto(
    		['a', 'b', 'c', 'd', 'd', 'e', 'f', 'f'],
    		['a', 'e', 'f']
    	);
    	// -> 0.375

		or

    wuzzy.tanimoto(
    		'abcddeff',
    		'aef'
    	);
    	// -> 0.375

		or 

    wuzzy.tanimoto(
    		['abe', 'babe', 'cabe', 'dabe', 'eabe', 'fabe', 'fabe'],
    		['babe']
    	);
    	// -> 0.14285714

### Params: 

* **String|Array** *a* - the first string/array to compare
* **String|Array** *b* - the second string/array to compare

### Return:

* **Number** returns the tanimoto distance for

<!-- End ./index.js -->

