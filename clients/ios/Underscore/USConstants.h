//
//  USConstants.h
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

#import <Foundation/Foundation.h>

typedef BOOL (^UnderscoreTestBlock)(id obj);
typedef id   (^UnderscoreReduceBlock)(id memo, id obj);

typedef void (^UnderscoreArrayIteratorBlock)(id obj);
typedef id   (^UnderscoreArrayMapBlock)(id obj);

typedef void (^UnderscoreDictionaryIteratorBlock)(id key, id obj);
typedef id   (^UnderscoreDictionaryMapBlock)(id key, id obj);

typedef NSComparisonResult (^UnderscoreSortBlock)(id a, id b);
