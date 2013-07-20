//
//  Underscore+Functional.h
//  Underscore
//
//  Created by Robert Böhnke on 7/15/12.
//  Copyright (c) 2012 Robert Böhnke. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "Underscore.h"

@interface Underscore (FunctionalStyle)

#pragma mark NSArray functional style methods

+ (USArrayWrapper *(^)(NSArray *))array;

+ (id (^)(NSArray *))first;
+ (id (^)(NSArray *))last;

+ (NSArray *(^)(NSArray *array, NSUInteger n))head;
+ (NSArray *(^)(NSArray *array, NSUInteger n))tail;

+ (NSUInteger (^)(NSArray *array, id obj))indexOf;

+ (NSArray *(^)(NSArray *array))flatten;
+ (NSArray *(^)(NSArray *array, NSArray *values))without;

+ (NSArray *(^)(NSArray *array))shuffle;

+ (id (^)(NSArray *array, id memo, UnderscoreReduceBlock block))reduce;
+ (id (^)(NSArray *array, id memo, UnderscoreReduceBlock block))reduceRight;

+ (void (^)(NSArray *array, UnderscoreArrayIteratorBlock block))arrayEach;
+ (NSArray *(^)(NSArray *array, UnderscoreArrayMapBlock block))arrayMap;

+ (NSArray *(^)(NSArray *array, NSString *keyPath))pluck;

+ (NSArray *(^)(NSArray *array))uniq;

+ (id (^)(NSArray *array, UnderscoreTestBlock block))find;

+ (NSArray *(^)(NSArray *array, UnderscoreTestBlock block))filter;
+ (NSArray *(^)(NSArray *array, UnderscoreTestBlock block))reject;

+ (BOOL (^)(NSArray *array, UnderscoreTestBlock block))all;
+ (BOOL (^)(NSArray *array, UnderscoreTestBlock block))any;

+ (NSArray *(^)(NSArray *array, UnderscoreSortBlock block))sort;

#pragma mark NSDictionary style methods

+ (USDictionaryWrapper *(^)(NSDictionary *dictionary))dict;

+ (NSArray *(^)(NSDictionary *dictionary))keys;
+ (NSArray *(^)(NSDictionary *dictionary))values;

+ (void (^)(NSDictionary *dictionary, UnderscoreDictionaryIteratorBlock block))dictEach;
+ (NSDictionary *(^)(NSDictionary *dictionary, UnderscoreDictionaryMapBlock block))dictMap;

+ (NSDictionary *(^)(NSDictionary *dictionary, NSArray *keys))pick;

+ (NSDictionary *(^)(NSDictionary *dictionary, NSDictionary *source))extend;
+ (NSDictionary *(^)(NSDictionary *dictionary, NSDictionary *defaults))defaults;

+ (NSDictionary *(^)(NSDictionary *dictionary, UnderscoreTestBlock block))filterKeys;
+ (NSDictionary *(^)(NSDictionary *dictionary, UnderscoreTestBlock block))filterValues;

+ (NSDictionary *(^)(NSDictionary *dictionary, UnderscoreTestBlock block))rejectKeys;
+ (NSDictionary *(^)(NSDictionary *dictionary, UnderscoreTestBlock block))rejectValues;

@end
