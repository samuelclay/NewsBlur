//
//  USDictionaryWrapper.h
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

#import "USArrayWrapper.h"

#import "USConstants.h"

@interface USDictionaryWrapper : NSObject

+ (USDictionaryWrapper *)wrap:(NSDictionary *)dictionary;
- (NSDictionary *)unwrap;

- (id)init __attribute__((deprecated("You should Underscore.dict() instead")));

@property (readonly) USArrayWrapper *keys;
@property (readonly) USArrayWrapper *values;

@property (readonly) USDictionaryWrapper *(^each)(UnderscoreDictionaryIteratorBlock block);
@property (readonly) USDictionaryWrapper *(^map)(UnderscoreDictionaryMapBlock block);

@property (readonly) USDictionaryWrapper *(^pick)(NSArray *keys);

@property (readonly) USDictionaryWrapper *(^extend)(NSDictionary *source);
@property (readonly) USDictionaryWrapper *(^defaults)(NSDictionary *defaults);

@property (readonly) USDictionaryWrapper *(^filterKeys)(UnderscoreTestBlock block);
@property (readonly) USDictionaryWrapper *(^filterValues)(UnderscoreTestBlock block);

@property (readonly) USDictionaryWrapper *(^rejectKeys)(UnderscoreTestBlock block);
@property (readonly) USDictionaryWrapper *(^rejectValues)(UnderscoreTestBlock block);

@end
