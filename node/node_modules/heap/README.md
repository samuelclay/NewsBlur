Heap.js
=======

[![Build Status](https://travis-ci.org/qiao/heap.js.svg?branch=master)](https://travis-ci.org/qiao/heap.js)

A binary heap implementation in CoffeeScript/JavaScript. Ported from Python's [heapq](http://docs.python.org/library/heapq.html) module.


Download
--------

This module can be used in either the browser or node.js.

for browser use, you may [download the script](https://raw.github.com/qiao/heap.js/master/lib/heap.js) and include it in you web page.

```html
<script type="text/javascript" src="./heap.js"></script>
```

for node.js, you may install it via npm:

```bash
npm install heap
```

then require it:

```
var Heap = require('heap');
```

Examples
-------


push and pop

```js
var heap = new Heap();
heap.push(3);
heap.push(1);
heap.push(2);
heap.pop(); // 1
```

custom comparison function

```js
var heap = new Heap(function(a, b) {
    return a.foo - b.foo;
});
heap.push({foo: 3});
heap.push({foo: 1});
heap.push({foo: 2});
heap.pop(); // {foo: 1}
```

find 3 largest/smallest items in an array

```js
var array = [1, 3, 4, 2, 5];
Heap.nlargest(array, 3);  // [5, 4, 3]
Heap.nsmallest(array, 3); // [1, 2, 3]
```

Document
--------

This module exposes only one object, namely the Heap class.

### Constructor: Heap([cmp]) ###

The constructor receives a comparison function as an optional parameter. If omitted, the heap is built as a min-heap, which means that the smallest element will be popped out first.

If the comparison function is supplied, the heap will be built according to the 
return value of the comparison function.

* if cmp(a, b) < 0, then item a will come prior to b
* if cmp(a, b) > 0, then item b will come prior to a

So, the comparison function has the following form:

```js
function cmp(a, b) {
  if (a is prior to b) {
    return -1;
  } 
  if (b is prior to a) {
    return 1;
  }
  return 0;
}
```

To compare numbers, simply: 

```js
function cmp(a, b) {
  return a - b;
}
```

### Instance Methods ###

**push(item)** (alias: **insert**) 

Push item onto heap.

**pop()**

Pop the smallest item off the heap and return it.

**peek()** (alias: **top** / **front**)

Return the smallest item of the heap.

**replace(item)**

Pop and return the current smallest value, and add the new item.

This is more efficient than pop() followed by push(), and can be 
more appropriate when using a fixed size heap. Note that the value
returned may be larger than item! 

**pushpop(item)**

Fast version of a push followed by a pop.

**heapify()**

Rebuild the heap. This method may come handy when the priority of the 
internal data is being modified.

**updateItem(item)**

Update the position of the given item in the heap.
This function should be called every time the item is being modified.

**empty()**

Determine whether the heap is empty.

**size()**

Get the number of elements stored in the heap.

**toArray()**

Return the array representation of the heap. (note: the array is a shallow copy of the heap's internal nodes)

**clone()** (alias: **copy**)

Return a clone of the heap. (note: the internal data is a shallow copy of the original one)

### Static Methods ###

NOTE: All the static methods are designed to be applied on arrays.

**push(array, item, [cmp])** 

Push item onto array, maintaining the heap invariant.

**pop(array, [cmp])**

Pop the smallest item off the array, maintaining the heap invariant.

**replace(array, item, [cmp])**

Pop and return the current smallest value, and add the new item.

This is more efficient than heappop() followed by heappush(), and can be 
more appropriate when using a fixed size heap. Note that the value
returned may be larger than item! 

**pushpop(array, item, [cmp])**

Fast version of a heappush followed by a heappop.

**heapify(array, [cmp])**

Build the heap.

**updateItem(array, item, [cmp])**

Update the position of the given item in the heap.
This function should be called every time the item is being modified.

**nlargest(array, n, [cmp])**

Find the n largest elements in a dataset.

**nsmallest(array, n, [cmp])**

Find the n smallest elements in a dataset.


License
-------

Ported by Xueqiao Xu &lt;xueqiaoxu@gmail.com&gt;

PSF LICENSE AGREEMENT FOR PYTHON 2.7.2

1. This LICENSE AGREEMENT is between the Python Software Foundation (“PSF”), and the Individual or Organization (“Licensee”) accessing and otherwise using Python 2.7.2 software in source or binary form and its associated documentation.
2. Subject to the terms and conditions of this License Agreement, PSF hereby grants Licensee a nonexclusive, royalty-free, world-wide license to reproduce, analyze, test, perform and/or display publicly, prepare derivative works, distribute, and otherwise use Python 2.7.2 alone or in any derivative version, provided, however, that PSF’s License Agreement and PSF’s notice of copyright, i.e., “Copyright © 2001-2012 Python Software Foundation; All Rights Reserved” are retained in Python 2.7.2 alone or in any derivative version prepared by Licensee.
3. In the event Licensee prepares a derivative work that is based on or incorporates Python 2.7.2 or any part thereof, and wants to make the derivative work available to others as provided herein, then Licensee hereby agrees to include in any such work a brief summary of the changes made to Python 2.7.2.
4. PSF is making Python 2.7.2 available to Licensee on an “AS IS” basis. PSF MAKES NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED. BY WAY OF EXAMPLE, BUT NOT LIMITATION, PSF MAKES NO AND DISCLAIMS ANY REPRESENTATION OR WARRANTY OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE OR THAT THE USE OF PYTHON 2.7.2 WILL NOT INFRINGE ANY THIRD PARTY RIGHTS.
5. PSF SHALL NOT BE LIABLE TO LICENSEE OR ANY OTHER USERS OF PYTHON 2.7.2 FOR ANY INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES OR LOSS AS A RESULT OF MODIFYING, DISTRIBUTING, OR OTHERWISE USING PYTHON 2.7.2, OR ANY DERIVATIVE THEREOF, EVEN IF ADVISED OF THE POSSIBILITY THEREOF.
6. This License Agreement will automatically terminate upon a material breach of its terms and conditions.
7. Nothing in this License Agreement shall be deemed to create any relationship of agency, partnership, or joint venture between PSF and Licensee. This License Agreement does not grant permission to use PSF trademarks or trade name in a trademark sense to endorse or promote products or services of Licensee, or any third party.
8. By copying, installing or otherwise using Python 2.7.2, Licensee agrees to be bound by the terms and conditions of this License Agreement.
