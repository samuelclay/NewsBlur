/*
 Copyright (c) 2010-2013, Stig Brautaset.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:
 
   Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
  
   Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
 
   Neither the name of the the author nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if !__has_feature(objc_arc)
#error "This source file must be compiled with ARC enabled!"
#endif

#import "SBJson4Parser.h"

@interface SBJson4Parser () <SBJson4StreamParserDelegate>

- (void)pop;

@end

typedef enum {
    SBJson4ChunkNone,
    SBJson4ChunkArray,
    SBJson4ChunkObject,
} SBJson4ChunkType;

@implementation SBJson4Parser {
    SBJson4StreamParser *_parser;
    NSUInteger depth;
    NSMutableArray *array;
    NSMutableDictionary *dict;
    NSMutableArray *keyStack;
    NSMutableArray *stack;
    NSMutableArray *path;
    SBJson4ProcessBlock processBlock;
    SBJson4ErrorBlock errorHandler;
    SBJson4ValueBlock valueBlock;
    SBJson4ChunkType currentType;
    BOOL supportManyDocuments;
    BOOL supportPartialDocuments;
    NSUInteger _maxDepth;
}

#pragma mark Housekeeping

- (id)init {
    @throw @"Not Implemented";
}

+ (id)multiRootParserWithBlock:(SBJson4ValueBlock)block errorHandler:(SBJson4ErrorBlock)eh {
    return [self parserWithBlock:block
                  allowMultiRoot:YES
                 unwrapRootArray:NO
                    errorHandler:eh];
}

+ (id)unwrapRootArrayParserWithBlock:(SBJson4ValueBlock)block errorHandler:(SBJson4ErrorBlock)eh {
    return [self parserWithBlock:block
                  allowMultiRoot:NO
                 unwrapRootArray:YES
                    errorHandler:eh];
}

+ (id)parserWithBlock:(SBJson4ValueBlock)block
       allowMultiRoot:(BOOL)allowMultiRoot
      unwrapRootArray:(BOOL)unwrapRootArray
         errorHandler:(SBJson4ErrorBlock)eh {

    return [[self alloc] initWithBlock:block
                          processBlock:nil
                             multiRoot:allowMultiRoot
                       unwrapRootArray:unwrapRootArray
                              maxDepth:32
                          errorHandler:eh];
}

- (id)initWithBlock:(SBJson4ValueBlock)block
       processBlock:(SBJson4ProcessBlock)initialProcessBlock
          multiRoot:(BOOL)multiRoot
    unwrapRootArray:(BOOL)unwrapRootArray
           maxDepth:(NSUInteger)maxDepth
       errorHandler:(SBJson4ErrorBlock)eh {

	self = [super init];
	if (self) {
        _parser = [[SBJson4StreamParser alloc] init];
        _parser.delegate = self;

        supportManyDocuments = multiRoot;
        supportPartialDocuments = unwrapRootArray;

        valueBlock = block;
		keyStack = [[NSMutableArray alloc] initWithCapacity:32];
		stack = [[NSMutableArray alloc] initWithCapacity:32];
        if (initialProcessBlock)
            path = [[NSMutableArray alloc] initWithCapacity:32];
        processBlock = initialProcessBlock;
        errorHandler = eh ? eh : ^(NSError*err) { NSLog(@"%@", err); };
		currentType = SBJson4ChunkNone;
        _maxDepth = maxDepth;
	}
	return self;
}


#pragma mark Private methods

- (void)pop {
	[stack removeLastObject];
	array = nil;
	dict = nil;
	currentType = SBJson4ChunkNone;
	
	id value = [stack lastObject];
	
	if ([value isKindOfClass:[NSArray class]]) {
		array = value;
		currentType = SBJson4ChunkArray;
	} else if ([value isKindOfClass:[NSDictionary class]]) {
		dict = value;
		currentType = SBJson4ChunkObject;
	}
}

- (void)parserFound:(id)obj isValue:(BOOL)isValue {
	NSParameterAssert(obj);
	
    if(processBlock&&path) {
        if(isValue) {
            obj = processBlock(obj,[NSString stringWithFormat:@"%@.%@",[self pathString],[keyStack lastObject]]);
        }
        else {
            [path removeLastObject];
        }
    }

	switch (currentType) {
		case SBJson4ChunkArray:
			[array addObject:obj];
			break;

		case SBJson4ChunkObject:
			NSParameterAssert(keyStack.count);
			[dict setObject:obj forKey:[keyStack lastObject]];
			[keyStack removeLastObject];
			break;

		case SBJson4ChunkNone: {
            __block BOOL stop = NO;
            valueBlock(obj, &stop);
            if (stop) [_parser stop];
        }
			break;

		default:
			break;
	}
}


#pragma mark Delegate methods

- (void)parserFoundObjectStart {
    ++depth;
    if (depth > _maxDepth)
        [self maxDepthError];

    if (path)
        [self addToPath];
    dict = [NSMutableDictionary new];
	[stack addObject:dict];
    currentType = SBJson4ChunkObject;
}

- (void)parserFoundObjectKey:(NSString *)key_ {
    [keyStack addObject:key_];
}

- (void)parserFoundObjectEnd {
    depth--;
	id value = dict;
	[self pop];
    [self parserFound:value isValue:NO ];
}

- (void)parserFoundArrayStart {
    depth++;
    if (depth > _maxDepth)
        [self maxDepthError];

    if (depth > 1 || !supportPartialDocuments) {
        if(path)
            [self addToPath];
		array = [NSMutableArray new];
		[stack addObject:array];
		currentType = SBJson4ChunkArray;
    }
}

- (void)parserFoundArrayEnd {
    depth--;
    if (depth > 1 || !supportPartialDocuments) {
		id value = array;
		[self pop];
        [self parserFound:value isValue:NO ];
    }
}

- (void)maxDepthError {
    id ui = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Input depth exceeds max depth of %lu", (unsigned long)_maxDepth]};
    errorHandler([NSError errorWithDomain:@"org.sbjson.parser" code:3 userInfo:ui]);
    [_parser stop];
}

- (void)parserFoundBoolean:(BOOL)x {
	[self parserFound:[NSNumber numberWithBool:x] isValue:YES ];
}

- (void)parserFoundNull {
    [self parserFound:[NSNull null] isValue:YES ];
}

- (void)parserFoundNumber:(NSNumber *)num {
    [self parserFound:num isValue:YES ];
}

- (void)parserFoundString:(NSString *)string {
    [self parserFound:string isValue:YES ];
}

- (void)parserFoundError:(NSError *)err {
    errorHandler(err);
}

- (void)addToPath {
    if([path count]==0)
        [path addObject:@"$"];
    else if([[stack lastObject] isKindOfClass:[NSArray class]])
        [path addObject:@([[stack lastObject] count])];
    else
        [path addObject:[keyStack lastObject]];
}

- (NSString *)pathString {
    NSMutableString *pathString = [NSMutableString stringWithString:@"$"];
    for(NSUInteger i=1;i<[path count];i++) {
        if([[path objectAtIndex:i] isKindOfClass:[NSNumber class]])
            [pathString appendString:[NSString stringWithFormat:@"[%@]",[path objectAtIndex:i]]];
        else
            [pathString appendString:[NSString stringWithFormat:@".%@",[path objectAtIndex:i]]];
    }
    return pathString;
}

- (BOOL)parserShouldSupportManyDocuments {
    return supportManyDocuments;
}

- (SBJson4ParserStatus)parse:(NSData *)data {
    return [_parser parse:data];
}

@end
