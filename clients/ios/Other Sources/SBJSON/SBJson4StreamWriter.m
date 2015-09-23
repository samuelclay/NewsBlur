/*
 Copyright (c) 2010, Stig Brautaset.
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

#import "SBJson4StreamWriter.h"
#import "SBJson4StreamWriterState.h"

static NSNumber *kTrue;
static NSNumber *kFalse;
static NSNumber *kPositiveInfinity;
static NSNumber *kNegativeInfinity;


@implementation SBJson4StreamWriter

+ (void)initialize {
    kPositiveInfinity = [NSNumber numberWithDouble:+HUGE_VAL];
    kNegativeInfinity = [NSNumber numberWithDouble:-HUGE_VAL];
    kTrue = [NSNumber numberWithBool:YES];
    kFalse = [NSNumber numberWithBool:NO];
}

#pragma mark Housekeeping

- (id)init {
	self = [super init];
	if (self) {
		_maxDepth = 32u;
        _stateStack = [[NSMutableArray alloc] initWithCapacity:_maxDepth];
        _state = [SBJson4StreamWriterStateStart sharedInstance];
        cache = [[NSMutableDictionary alloc] initWithCapacity:32];
    }
	return self;
}

#pragma mark Methods

- (void)appendBytes:(const void *)bytes length:(NSUInteger)length {
    [_delegate writer:self appendBytes:bytes length:length];
}

- (BOOL)writeObject:(NSDictionary *)dict {
	if (![self writeObjectOpen])
		return NO;

	NSArray *keys = [dict allKeys];

	if (_sortKeys) {
		if (_sortKeysComparator) {
			keys = [keys sortedArrayWithOptions:NSSortStable usingComparator:_sortKeysComparator];
		}
		else{
			keys = [keys sortedArrayUsingSelector:@selector(compare:)];
		}
	}

	for (id k in keys) {
		if (![k isKindOfClass:[NSString class]]) {
			self.error = [NSString stringWithFormat:@"JSON object key must be string: %@", k];
			return NO;
		}

		if (![self writeString:k])
			return NO;
		if (![self writeValue:[dict objectForKey:k]])
			return NO;
	}

	return [self writeObjectClose];
}

- (BOOL)writeArray:(NSArray*)array {
	if (![self writeArrayOpen])
		return NO;
	for (id v in array)
		if (![self writeValue:v])
			return NO;
	return [self writeArrayClose];
}


- (BOOL)writeObjectOpen {
	if ([_state isInvalidState:self]) return NO;
	if ([_state expectingKey:self]) return NO;
	[_state appendSeparator:self];
	if (_humanReadable && _stateStack.count) [_state appendWhitespace:self];

    [_stateStack addObject:_state];
    self.state = [SBJson4StreamWriterStateObjectStart sharedInstance];

	if (_maxDepth && _stateStack.count > _maxDepth) {
		self.error = @"Nested too deep";
		return NO;
	}

	[_delegate writer:self appendBytes:"{" length:1];
	return YES;
}

- (BOOL)writeObjectClose {
	if ([_state isInvalidState:self]) return NO;

    SBJson4StreamWriterState *prev = _state;

    self.state = [_stateStack lastObject];
    [_stateStack removeLastObject];

	if (_humanReadable) [prev appendWhitespace:self];
	[_delegate writer:self appendBytes:"}" length:1];

	[_state transitionState:self];
	return YES;
}

- (BOOL)writeArrayOpen {
	if ([_state isInvalidState:self]) return NO;
	if ([_state expectingKey:self]) return NO;
	[_state appendSeparator:self];
	if (_humanReadable && _stateStack.count) [_state appendWhitespace:self];

    [_stateStack addObject:_state];
	self.state = [SBJson4StreamWriterStateArrayStart sharedInstance];

	if (_maxDepth && _stateStack.count > _maxDepth) {
		self.error = @"Nested too deep";
		return NO;
	}

	[_delegate writer:self appendBytes:"[" length:1];
	return YES;
}

- (BOOL)writeArrayClose {
	if ([_state isInvalidState:self]) return NO;
	if ([_state expectingKey:self]) return NO;

    SBJson4StreamWriterState *prev = _state;

    self.state = [_stateStack lastObject];
    [_stateStack removeLastObject];

	if (_humanReadable) [prev appendWhitespace:self];
	[_delegate writer:self appendBytes:"]" length:1];

	[_state transitionState:self];
	return YES;
}

- (BOOL)writeNull {
	if ([_state isInvalidState:self]) return NO;
	if ([_state expectingKey:self]) return NO;
	[_state appendSeparator:self];
	if (_humanReadable) [_state appendWhitespace:self];

	[_delegate writer:self appendBytes:"null" length:4];
	[_state transitionState:self];
	return YES;
}

- (BOOL)writeBool:(BOOL)x {
	if ([_state isInvalidState:self]) return NO;
	if ([_state expectingKey:self]) return NO;
	[_state appendSeparator:self];
	if (_humanReadable) [_state appendWhitespace:self];

	if (x)
		[_delegate writer:self appendBytes:"true" length:4];
	else
		[_delegate writer:self appendBytes:"false" length:5];
	[_state transitionState:self];
	return YES;
}


- (BOOL)writeValue:(id)o {
	if ([o isKindOfClass:[NSDictionary class]]) {
		return [self writeObject:o];

	} else if ([o isKindOfClass:[NSArray class]]) {
		return [self writeArray:o];

	} else if ([o isKindOfClass:[NSString class]]) {
		[self writeString:o];
		return YES;

	} else if ([o isKindOfClass:[NSNumber class]]) {
		return [self writeNumber:o];

	} else if ([o isKindOfClass:[NSNull class]]) {
		return [self writeNull];

	} else if ([o respondsToSelector:@selector(proxyForJson)]) {
		return [self writeValue:[o proxyForJson]];

	}

	self.error = [NSString stringWithFormat:@"JSON serialisation not supported for %@", [o class]];
	return NO;
}

static const char *strForChar(int c) {
	switch (c) {
		case 0: return "\\u0000";
		case 1: return "\\u0001";
		case 2: return "\\u0002";
		case 3: return "\\u0003";
		case 4: return "\\u0004";
		case 5: return "\\u0005";
		case 6: return "\\u0006";
		case 7: return "\\u0007";
		case 8: return "\\b";
		case 9: return "\\t";
		case 10: return "\\n";
		case 11: return "\\u000b";
		case 12: return "\\f";
		case 13: return "\\r";
		case 14: return "\\u000e";
		case 15: return "\\u000f";
		case 16: return "\\u0010";
		case 17: return "\\u0011";
		case 18: return "\\u0012";
		case 19: return "\\u0013";
		case 20: return "\\u0014";
		case 21: return "\\u0015";
		case 22: return "\\u0016";
		case 23: return "\\u0017";
		case 24: return "\\u0018";
		case 25: return "\\u0019";
		case 26: return "\\u001a";
		case 27: return "\\u001b";
		case 28: return "\\u001c";
		case 29: return "\\u001d";
		case 30: return "\\u001e";
		case 31: return "\\u001f";
		case 34: return "\\\"";
		case 92: return "\\\\";
		default:
			[NSException raise:@"Illegal escape char" format:@"-->%c<-- is not a legal escape character", c];
			return NULL;
	}
}

- (BOOL)writeString:(NSString*)string {
	if ([_state isInvalidState:self]) return NO;
	[_state appendSeparator:self];
	if (_humanReadable) [_state appendWhitespace:self];

	NSMutableData *buf = [cache objectForKey:string];
	if (!buf) {

        NSUInteger len = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        const char *utf8 = [string UTF8String];
        NSUInteger written = 0, i = 0;

        buf = [NSMutableData dataWithCapacity:(NSUInteger)(len * 1.1f)];
        [buf appendBytes:"\"" length:1];

        for (i = 0; i < len; i++) {
            int c = utf8[i];
            BOOL isControlChar = c >= 0 && c < 32;
            if (isControlChar || c == '"' || c == '\\') {
                if (i - written)
                    [buf appendBytes:utf8 + written length:i - written];
                written = i + 1;

                const char *t = strForChar(c);
                [buf appendBytes:t length:strlen(t)];
            }
        }

        if (i - written)
            [buf appendBytes:utf8 + written length:i - written];

        [buf appendBytes:"\"" length:1];
        [cache setObject:buf forKey:string];
    }

	[_delegate writer:self appendBytes:[buf bytes] length:[buf length]];
	[_state transitionState:self];
	return YES;
}

- (BOOL)writeNumber:(NSNumber*)number {
	if (number == kTrue || number == kFalse)
		return [self writeBool:[number boolValue]];

	if ([_state isInvalidState:self]) return NO;
	if ([_state expectingKey:self]) return NO;
	[_state appendSeparator:self];
	if (_humanReadable) [_state appendWhitespace:self];

	if ([kPositiveInfinity isEqualToNumber:number]) {
		self.error = @"+Infinity is not a valid number in JSON";
		return NO;

	} else if ([kNegativeInfinity isEqualToNumber:number]) {
		self.error = @"-Infinity is not a valid number in JSON";
		return NO;

	} else if (isnan([number doubleValue])) {
		self.error = @"NaN is not a valid number in JSON";
		return NO;
	}

	const char *objcType = [number objCType];
	char num[128];
	size_t len;

	switch (objcType[0]) {
		case 'c': case 'i': case 's': case 'l': case 'q':
			len = snprintf(num, sizeof num, "%lld", [number longLongValue]);
			break;
		case 'C': case 'I': case 'S': case 'L': case 'Q':
			len = snprintf(num, sizeof num, "%llu", [number unsignedLongLongValue]);
			break;
		case 'f': case 'd': default: {
            len = snprintf(num, sizeof num, "%.17g", [number doubleValue]);
			break;
        }
	}
	[_delegate writer:self appendBytes:num length: len];
	[_state transitionState:self];
	return YES;
}

@end
