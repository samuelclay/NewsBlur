//
//  USArrayWrapper.h
//  Underscore
//
//  Created by Robert Böhnke on 5/13/12.
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

#import "USConstants.h"

@interface USArrayWrapper : NSObject

+ (USArrayWrapper *)wrap:(NSArray *)array;

- (id)init __attribute__((deprecated("You should Underscore.array() instead")));

@property (readonly) NSArray *unwrap;

@property (readonly) id first;
@property (readonly) id last;

@property (readonly) USArrayWrapper *(^head)(NSUInteger n);
@property (readonly) USArrayWrapper *(^tail)(NSUInteger n);

@property (readonly) NSUInteger (^indexOf)(id obj);

@property (readonly) USArrayWrapper *flatten;
@property (readonly) USArrayWrapper *(^without)(NSArray *values);

@property (readonly) USArrayWrapper *shuffle;

@property (readonly) id (^reduce)(id memo, UnderscoreReduceBlock block);
@property (readonly) id (^reduceRight)(id memo, UnderscoreReduceBlock block);

@property (readonly) USArrayWrapper *(^each)(UnderscoreArrayIteratorBlock block);
@property (readonly) USArrayWrapper *(^map)(UnderscoreArrayMapBlock block);

@property (readonly) USArrayWrapper *(^pluck)(NSString *keyPath);

@property (readonly) USArrayWrapper *uniq;

@property (readonly) id (^find)(UnderscoreTestBlock block);

@property (readonly) USArrayWrapper *(^filter)(UnderscoreTestBlock block);
@property (readonly) USArrayWrapper *(^reject)(UnderscoreTestBlock block);

@property (readonly) BOOL (^all)(UnderscoreTestBlock block);
@property (readonly) BOOL (^any)(UnderscoreTestBlock block);

@property (readonly) USArrayWrapper *(^sort)(UnderscoreSortBlock block);

@end
