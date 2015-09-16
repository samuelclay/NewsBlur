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

#import "SBJson4StreamParserState.h"

#define SINGLETON \
+ (id)sharedInstance { \
    static id state = nil; \
    if (!state) { \
        @synchronized(self) { \
            if (!state) state = [[self alloc] init]; \
        } \
    } \
    return state; \
}

@implementation SBJson4StreamParserState

+ (id)sharedInstance { return nil; }

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	return NO;
}

- (SBJson4ParserStatus)parserShouldReturn:(SBJson4StreamParser *)parser {
	return SBJson4ParserWaitingForData;
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {}

- (BOOL)needKey {
	return NO;
}

- (NSString*)name {
	return @"<aaiie!>";
}

- (BOOL)isError {
    return NO;
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateStart

SINGLETON

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	return token == sbjson4_token_array_open || token == sbjson4_token_object_open;
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {

	SBJson4StreamParserState *state = nil;
	switch (tok) {
		case sbjson4_token_array_open:
			state = [SBJson4StreamParserStateArrayStart sharedInstance];
			break;

		case sbjson4_token_object_open:
			state = [SBJson4StreamParserStateObjectStart sharedInstance];
			break;

		case sbjson4_token_array_close:
		case sbjson4_token_object_close:
			if ([parser.delegate respondsToSelector:@selector(parserShouldSupportManyDocuments)] && [parser.delegate parserShouldSupportManyDocuments])
				state = parser.state;
			else
				state = [SBJson4StreamParserStateComplete sharedInstance];
			break;

		case sbjson4_token_eof:
			return;

		default:
			state = [SBJson4StreamParserStateError sharedInstance];
			break;
	}


	parser.state = state;
}

- (NSString*)name { return @"before outer-most array or object"; }

@end

#pragma mark -

@implementation SBJson4StreamParserStateComplete

SINGLETON

- (NSString*)name { return @"after outer-most array or object"; }

- (SBJson4ParserStatus)parserShouldReturn:(SBJson4StreamParser *)parser {
	return SBJson4ParserComplete;
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateError

SINGLETON

- (NSString*)name { return @"in error"; }

- (SBJson4ParserStatus)parserShouldReturn:(SBJson4StreamParser *)parser {
	return SBJson4ParserError;
}

- (BOOL)isError {
    return YES;
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateObjectStart

SINGLETON

- (NSString*)name { return @"at beginning of object"; }

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	switch (token) {
		case sbjson4_token_object_close:
		case sbjson4_token_string:
        case sbjson4_token_encoded:
			return YES;
		default:
			return NO;
	}
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	parser.state = [SBJson4StreamParserStateObjectGotKey sharedInstance];
}

- (BOOL)needKey {
	return YES;
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateObjectGotKey

SINGLETON

- (NSString*)name { return @"after object key"; }

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	return token == sbjson4_token_entry_sep;
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	parser.state = [SBJson4StreamParserStateObjectSeparator sharedInstance];
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateObjectSeparator

SINGLETON

- (NSString*)name { return @"as object value"; }

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	switch (token) {
		case sbjson4_token_object_open:
		case sbjson4_token_array_open:
		case sbjson4_token_bool:
		case sbjson4_token_null:
        case sbjson4_token_integer:
        case sbjson4_token_real:
        case sbjson4_token_string:
        case sbjson4_token_encoded:
			return YES;

		default:
			return NO;
	}
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	parser.state = [SBJson4StreamParserStateObjectGotValue sharedInstance];
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateObjectGotValue

SINGLETON

- (NSString*)name { return @"after object value"; }

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	switch (token) {
		case sbjson4_token_object_close:
        case sbjson4_token_value_sep:
			return YES;

		default:
			return NO;
	}
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	parser.state = [SBJson4StreamParserStateObjectNeedKey sharedInstance];
}


@end

#pragma mark -

@implementation SBJson4StreamParserStateObjectNeedKey

SINGLETON

- (NSString*)name { return @"in place of object key"; }

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
    return sbjson4_token_string == token || sbjson4_token_encoded == token;
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	parser.state = [SBJson4StreamParserStateObjectGotKey sharedInstance];
}

- (BOOL)needKey {
	return YES;
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateArrayStart

SINGLETON

- (NSString*)name { return @"at array start"; }

- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	switch (token) {
		case sbjson4_token_object_close:
        case sbjson4_token_entry_sep:
        case sbjson4_token_value_sep:
			return NO;

		default:
			return YES;
	}
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	parser.state = [SBJson4StreamParserStateArrayGotValue sharedInstance];
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateArrayGotValue

SINGLETON

- (NSString*)name { return @"after array value"; }


- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	return token == sbjson4_token_array_close || token == sbjson4_token_value_sep;
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	if (tok == sbjson4_token_value_sep)
		parser.state = [SBJson4StreamParserStateArrayNeedValue sharedInstance];
}

@end

#pragma mark -

@implementation SBJson4StreamParserStateArrayNeedValue

SINGLETON

- (NSString*)name { return @"as array value"; }


- (BOOL)parser:(SBJson4StreamParser *)parser shouldAcceptToken:(sbjson4_token_t)token {
	switch (token) {
		case sbjson4_token_array_close:
        case sbjson4_token_entry_sep:
		case sbjson4_token_object_close:
		case sbjson4_token_value_sep:
			return NO;

		default:
			return YES;
	}
}

- (void)parser:(SBJson4StreamParser *)parser shouldTransitionTo:(sbjson4_token_t)tok {
	parser.state = [SBJson4StreamParserStateArrayGotValue sharedInstance];
}

@end

