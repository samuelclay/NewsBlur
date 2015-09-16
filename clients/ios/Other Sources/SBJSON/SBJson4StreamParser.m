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

#import "SBJson4StreamParser.h"
#import "SBJson4StreamTokeniser.h"
#import "SBJson4StreamParserState.h"

#define SBStringIsSurrogateHighCharacter(character) ((character >= 0xD800UL) && (character <= 0xDBFFUL))

@implementation SBJson4StreamParser {
@private
  SBJson4StreamTokeniser *tokeniser;
  BOOL stopped;
  NSMutableArray *_stateStack;
}

#pragma mark Housekeeping

- (id)init {
	self = [super init];
	if (self) {
        _stateStack = [[NSMutableArray alloc] initWithCapacity:32];
        _state = [SBJson4StreamParserStateStart sharedInstance];
		tokeniser = [[SBJson4StreamTokeniser alloc] init];
	}
	return self;
}


#pragma mark Methods

- (NSString*)tokenName:(sbjson4_token_t)token {
	switch (token) {
		case sbjson4_token_array_open:
			return @"start of array";

		case sbjson4_token_array_close:
			return @"end of array";

        case sbjson4_token_integer:
        case sbjson4_token_real:
			return @"number";

        case sbjson4_token_string:
        case sbjson4_token_encoded:
			return @"string";

        case sbjson4_token_bool:
			return @"boolean";

		case sbjson4_token_null:
			return @"null";

        case sbjson4_token_entry_sep:
			return @"key-value separator";

        case sbjson4_token_value_sep:
			return @"value separator";

		case sbjson4_token_object_open:
			return @"start of object";

		case sbjson4_token_object_close:
			return @"end of object";

		case sbjson4_token_eof:
		case sbjson4_token_error:
			break;
	}
	NSAssert(NO, @"Should not get here");
	return @"<aaiiie!>";
}

- (void)handleObjectStart {
    [_delegate parserFoundObjectStart];
    [_stateStack addObject:_state];
    _state = [SBJson4StreamParserStateObjectStart sharedInstance];
}

- (void)handleObjectEnd: (sbjson4_token_t) tok  {
    _state = [_stateStack lastObject];
    [_stateStack removeLastObject];
    [_state parser:self shouldTransitionTo:tok];
    [_delegate parserFoundObjectEnd];
}

- (void)handleArrayStart {
	[_delegate parserFoundArrayStart];
    [_stateStack addObject:_state];
    _state = [SBJson4StreamParserStateArrayStart sharedInstance];
}

- (void)handleArrayEnd: (sbjson4_token_t) tok  {
    _state = [_stateStack lastObject];
    [_stateStack removeLastObject];
    [_state parser:self shouldTransitionTo:tok];
    [_delegate parserFoundArrayEnd];
}

- (void) handleTokenNotExpectedHere: (sbjson4_token_t) tok  {
    NSString *tokenName = [self tokenName:tok];
    NSString *stateName = [_state name];

    _state = [SBJson4StreamParserStateError sharedInstance];
    id ui = @{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Token '%@' not expected %@", tokenName, stateName]};
    [_delegate parserFoundError:[NSError errorWithDomain:@"org.sbjson.parser" code:2 userInfo:ui]];
}

- (SBJson4ParserStatus)parse:(NSData *)data_ {
    @autoreleasepool {
        [tokeniser appendData:data_];
        
        for (;;) {

            if (stopped)
                return SBJson4ParserStopped;
            
            if ([_state isError])
                return SBJson4ParserError;

            char *token;
            NSUInteger token_len;
            sbjson4_token_t tok = [tokeniser getToken:&token length:&token_len];
            
            switch (tok) {
                case sbjson4_token_eof:
                    return [_state parserShouldReturn:self];

                case sbjson4_token_error:
                    _state = [SBJson4StreamParserStateError sharedInstance];
                    [_delegate parserFoundError:[NSError errorWithDomain:@"org.sbjson.parser" code:3
                                                                userInfo:@{NSLocalizedDescriptionKey : tokeniser.error}]];
                    return SBJson4ParserError;

                default:
                    
                    if (![_state parser:self shouldAcceptToken:tok]) {
                        [self handleTokenNotExpectedHere: tok];
                        return SBJson4ParserError;
                    }
                    
                    switch (tok) {
                        case sbjson4_token_object_open:
                            [self handleObjectStart];
                            break;
                            
                        case sbjson4_token_object_close:
                            [self handleObjectEnd: tok];
                            break;
                            
                        case sbjson4_token_array_open:
                            [self handleArrayStart];
                            break;
                            
                        case sbjson4_token_array_close:
                            [self handleArrayEnd: tok];
                            break;
                            
                        case sbjson4_token_value_sep:
                        case sbjson4_token_entry_sep:
                            [_state parser:self shouldTransitionTo:tok];
                            break;
                            
                        case sbjson4_token_bool:
                            [_delegate parserFoundBoolean:token[0] == 't'];
                            [_state parser:self shouldTransitionTo:tok];
                            break;
                            

                        case sbjson4_token_null:
                            [_delegate parserFoundNull];
                            [_state parser:self shouldTransitionTo:tok];
                            break;

                        case sbjson4_token_integer: {
                            const int UNSIGNED_LONG_LONG_MAX_DIGITS = 20;
                            if (token_len <= UNSIGNED_LONG_LONG_MAX_DIGITS) {
                                if (*token == '-')
                                    [_delegate parserFoundNumber:@(strtoll(token, NULL, 10))];
                                else
                                    [_delegate parserFoundNumber:@(strtoull(token, NULL, 10))];
                                
                                [_state parser:self shouldTransitionTo:tok];
                                break;
                            }
                        }
                            // FALL THROUGH

                        case sbjson4_token_real: {
                            [_delegate parserFoundNumber:@(strtod(token, NULL))];
                            [_state parser:self shouldTransitionTo:tok];
                            break;
                        }

                        case sbjson4_token_string: {
                            NSString *string = [[NSString alloc] initWithBytes:token length:token_len encoding:NSUTF8StringEncoding];
                            if ([_state needKey])
                                [_delegate parserFoundObjectKey:string];
                            else
                                [_delegate parserFoundString:string];
                            [_state parser:self shouldTransitionTo:tok];
                            break;
                        }

                        case sbjson4_token_encoded: {
                            NSString *string = [self decodeStringToken:token length:token_len];
                            if ([_state needKey])
                                [_delegate parserFoundObjectKey:string];
                            else
                                [_delegate parserFoundString:string];
                            [_state parser:self shouldTransitionTo:tok];
                            break;
                        }

                        default:
                            break;
                    }
                    break;
            }
        }
        return SBJson4ParserComplete;
    }
}

- (unichar)decodeHexQuad:(char *)quad {
    unichar ch = 0;
    for (NSUInteger i = 0; i < 4; i++) {
        int c = quad[i];
        ch *= 16;
        switch (c) {
            case '0' ... '9': ch += c - '0'; break;
            case 'a' ... 'f': ch += 10 + c - 'a'; break;
            case 'A' ... 'F': ch += 10 + c - 'A'; break;
            default: @throw @"FUT FUT FUT";
        }
    }
    return ch;
}

- (NSString*)decodeStringToken:(char*)bytes length:(NSUInteger)len {
    NSMutableData *buf = [NSMutableData dataWithCapacity:len];
    for (NSUInteger i = 0; i < len;) {
        switch ((unsigned char)bytes[i]) {
            case '\\': {
                switch ((unsigned char)bytes[++i]) {
                    case '"': [buf appendBytes:"\"" length:1]; i++; break;
                    case '/': [buf appendBytes:"/" length:1]; i++; break;
                    case '\\': [buf appendBytes:"\\" length:1]; i++; break;
                    case 'b': [buf appendBytes:"\b" length:1]; i++; break;
                    case 'f': [buf appendBytes:"\f" length:1]; i++; break;
                    case 'n': [buf appendBytes:"\n" length:1]; i++; break;
                    case 'r': [buf appendBytes:"\r" length:1]; i++; break;
                    case 't': [buf appendBytes:"\t" length:1]; i++; break;
                    case 'u': {
                        unichar hi = [self decodeHexQuad:bytes + i + 1];
                        i += 5;
                        if (SBStringIsSurrogateHighCharacter(hi)) {
                            // Skip past \u that we know is there..
                            unichar lo = [self decodeHexQuad:bytes + i + 2];
                            i += 6;
                            [buf appendData:[[NSString stringWithFormat:@"%C%C", hi, lo] dataUsingEncoding:NSUTF8StringEncoding]];
                        } else {
                            [buf appendData:[[NSString stringWithFormat:@"%C", hi] dataUsingEncoding:NSUTF8StringEncoding]];
                        }
                        break;
                    }
                    default: @throw @"FUT FUT FUT";
                }
                break;
            }
            default:
                [buf appendBytes:bytes + i length:1];
                i++;
                break;
        }
    }
    return [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding];
}

- (void)stop {
    stopped = YES;
}

@end
