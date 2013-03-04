//
//  Underscore+Functional.m
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

#import "Underscore+Functional.h"

@implementation Underscore (Functional)

#pragma mark NSArray shortcuts

+ (USArrayWrapper *(^)(NSArray *))array
{
    return ^(NSArray *array) {
        return [USArrayWrapper wrap:array];
    };
}

+ (id (^)(NSArray *))first
{
    return ^(NSArray *array) {
        return Underscore.array(array).first;
    };
}

+ (id (^)(NSArray *))last
{
    return ^(NSArray *array) {
        return Underscore.array(array).last;
    };
}

+ (NSArray *(^)(NSArray *, NSUInteger))head
{
    return ^(NSArray *array, NSUInteger n) {
        return Underscore.array(array).head(n).unwrap;
    };
}

+ (NSArray *(^)(NSArray *, NSUInteger))tail
{
    return ^(NSArray *array, NSUInteger n) {
        return Underscore.array(array).tail(n).unwrap;
    };
}

+ (NSUInteger (^)(NSArray *, id))indexOf
{
    return ^(NSArray *array, id obj) {
        return Underscore.array(array).indexOf(obj);
    };
}

+ (NSArray *(^)(NSArray *))flatten
{
    return ^(NSArray *array) {
        return Underscore.array(array).flatten.unwrap;
    };
}

+ (NSArray *(^)(NSArray *))uniq
{
    return ^(NSArray *array) {
        return Underscore.array(array).uniq.unwrap;
    };
}

+ (NSArray *(^)(NSArray *, NSArray *))without
{
    return ^(NSArray *array, NSArray *values) {
        return Underscore.array(array).without(values).unwrap;
    };
}

+ (NSArray *(^)(NSArray *))shuffle
{
    return ^(NSArray *array) {
        return Underscore.array(array).shuffle.unwrap;
    };
}

+(id (^)(NSArray *, id, UnderscoreReduceBlock))reduce
{
    return ^(NSArray *array, id memo, UnderscoreReduceBlock block) {
        return Underscore.array(array).reduce(memo, block);
    };
}

+ (id (^)(NSArray *, id, UnderscoreReduceBlock))reduceRight
{
    return ^(NSArray *array, id memo, UnderscoreReduceBlock block) {
        return Underscore.array(array).reduceRight(memo, block);
    };
}

+ (void (^)(NSArray *, UnderscoreArrayIteratorBlock))arrayEach
{
    return ^(NSArray *array, UnderscoreArrayIteratorBlock block) {
        Underscore.array(array).each(block);
    };
}

+ (NSArray *(^)(NSArray *array, UnderscoreArrayMapBlock block))arrayMap
{
    return ^(NSArray *array, UnderscoreArrayMapBlock block) {
        return Underscore.array(array).map(block).unwrap;
    };
}

+ (NSArray *(^)(NSArray *, NSString *))pluck
{
    return ^(NSArray *array, NSString *keyPath) {
        return Underscore.array(array).pluck(keyPath).unwrap;
    };
}

+ (id (^)(NSArray *, UnderscoreTestBlock))find
{
    return ^(NSArray *array, UnderscoreTestBlock block) {
        return Underscore.array(array).find(block);
    };
}

+ (NSArray *(^)(NSArray *, UnderscoreTestBlock))filter
{
    return ^(NSArray *array, UnderscoreTestBlock block) {
        return Underscore.array(array).filter(block).unwrap;
    };
}
+ (NSArray *(^)(NSArray *, UnderscoreTestBlock))reject
{
    return ^(NSArray *array, UnderscoreTestBlock block) {
        return Underscore.array(array).reject(block).unwrap;
    };
}

+ (BOOL (^)(NSArray *, UnderscoreTestBlock))all
{
    return ^(NSArray *array, UnderscoreTestBlock block) {
        return Underscore.array(array).all(block);
    };
}
+ (BOOL (^)(NSArray *, UnderscoreTestBlock))any
{
    return ^(NSArray *array, UnderscoreTestBlock block) {
        return Underscore.array(array).any(block);
    };
}

+ (NSArray *(^)(NSArray *, UnderscoreSortBlock))sort
{
    return ^(NSArray *array, UnderscoreSortBlock block) {
        return Underscore.array(array).sort(block).unwrap;
    };
}

#pragma mark NSDictionary shortcuts

+ (USDictionaryWrapper *(^)(NSDictionary *))dict
{
    return ^(NSDictionary *dictionary) {
        return [USDictionaryWrapper wrap:dictionary];
    };
}

+ (NSArray *(^)(NSDictionary *))keys
{
    return ^(NSDictionary *dictionary) {
        return [USDictionaryWrapper wrap:dictionary].keys.unwrap;
    };
}
+ (NSArray *(^)(NSDictionary *))values
{
    return ^(NSDictionary *dictionary) {
        return [USDictionaryWrapper wrap:dictionary].values.unwrap;
    };
}

+ (void (^)(NSDictionary *, UnderscoreDictionaryIteratorBlock))dictEach
{
    return ^(NSDictionary *dictionary, UnderscoreDictionaryIteratorBlock block) {
        Underscore.dict(dictionary).each(block);
    };
}

+ (NSDictionary *(^)(NSDictionary *, UnderscoreDictionaryMapBlock))dictMap
{
    return ^(NSDictionary *dictionary, UnderscoreDictionaryMapBlock block) {
        return Underscore.dict(dictionary).map(block).unwrap;
    };
}

+ (NSDictionary *(^)(NSDictionary *, NSArray *))pick
{
    return ^(NSDictionary *dictionary, NSArray *keys) {
        return [USDictionaryWrapper wrap:dictionary].pick(keys).unwrap;
    };
}

+ (NSDictionary *(^)(NSDictionary *, NSDictionary *))extend
{
    return ^(NSDictionary *dictionary, NSDictionary *source) {
        return [USDictionaryWrapper wrap:dictionary].extend(source).unwrap;
    };
}
+ (NSDictionary *(^)(NSDictionary *, NSDictionary *))defaults
{
    return ^(NSDictionary *dictionary, NSDictionary *defaults) {
        return [USDictionaryWrapper wrap:dictionary].defaults(defaults).unwrap;
    };
}

+ (NSDictionary *(^)(NSDictionary *, UnderscoreTestBlock))filterKeys
{
    return ^(NSDictionary *dictionary, UnderscoreTestBlock block) {
        return [USDictionaryWrapper wrap:dictionary].filterKeys(block).unwrap;
    };
}
+ (NSDictionary *(^)(NSDictionary *, UnderscoreTestBlock))filterValues
{
    return ^(NSDictionary *dictionary, UnderscoreTestBlock block) {
        return [USDictionaryWrapper wrap:dictionary].filterValues(block).unwrap;
    };
}

+ (NSDictionary *(^)(NSDictionary *, UnderscoreTestBlock))rejectKeys
{
    return ^(NSDictionary *dictionary, UnderscoreTestBlock block) {
        return [USDictionaryWrapper wrap:dictionary].rejectKeys(block).unwrap;
    };
}

+ (NSDictionary *(^)(NSDictionary *, UnderscoreTestBlock))rejectValues
{
    return ^(NSDictionary *dictionary, UnderscoreTestBlock block) {
        return [USDictionaryWrapper wrap:dictionary].rejectValues(block).unwrap;
    };
}

@end
