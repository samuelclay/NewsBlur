//
//  Underscore.m
//  Underscore
//
//  Created by Robert Böhnke on 5/14/12.
//  Copyright (C) 2012 Robert Böhnke
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

#if !__has_feature(objc_arc)
# error Underscore.m requires Automatic Reference Counting to be enabled
#endif

@implementation Underscore

+ (UnderscoreTestBlock (^)(UnderscoreTestBlock))negate
{
    return ^UnderscoreTestBlock (UnderscoreTestBlock test) {
        return ^BOOL (id obj) {
            return !test(obj);
        };
    };
}

+ (UnderscoreTestBlock(^)(id obj))isEqual
{
    return ^UnderscoreTestBlock (id obj) {
        return ^BOOL (id other) {
            return [obj isEqual:other];
        };
    };
}

+ (UnderscoreTestBlock)isArray
{
    return ^BOOL (id obj) {
        return [obj isKindOfClass:[NSArray class]];
    };
}

+ (UnderscoreTestBlock)isDictionary
{
    return ^BOOL (id obj) {
        return [obj isKindOfClass:[NSDictionary class]];
    };
}

+ (UnderscoreTestBlock)isNull
{
    return ^BOOL (id obj) {
        return [obj isKindOfClass:[NSNull class]];
    };
}

+ (UnderscoreTestBlock)isNumber
{
    return ^BOOL (id obj) {
        return [obj isKindOfClass:[NSNumber class]];
    };
}

+ (UnderscoreTestBlock)isString
{
    return ^BOOL (id obj) {
        return [obj isKindOfClass:[NSString class]];
    };
}

+ (UnderscoreSortBlock)compare
{
    return ^NSComparisonResult(id a, id b){
        return [a compare:b];
    };
}

- (id)init
{
    return [super init];
}

@end
