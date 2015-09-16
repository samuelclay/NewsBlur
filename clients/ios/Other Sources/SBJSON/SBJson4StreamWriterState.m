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

#import "SBJson4StreamWriterState.h"
#import "SBJson4StreamWriter.h"

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


@implementation SBJson4StreamWriterState
+ (id)sharedInstance { return nil; }
- (BOOL)isInvalidState:(SBJson4StreamWriter *)writer { return NO; }
- (void)appendSeparator:(SBJson4StreamWriter *)writer {}
- (BOOL)expectingKey:(SBJson4StreamWriter *)writer { return NO; }
- (void)transitionState:(SBJson4StreamWriter *)writer {}
- (void)appendWhitespace:(SBJson4StreamWriter *)writer {
	[writer appendBytes:"\n" length:1];
	for (NSUInteger i = 0; i < writer.stateStack.count; i++)
	    [writer appendBytes:"  " length:2];
}
@end

@implementation SBJson4StreamWriterStateObjectStart

SINGLETON

- (void)transitionState:(SBJson4StreamWriter *)writer {
	writer.state = [SBJson4StreamWriterStateObjectValue sharedInstance];
}
- (BOOL)expectingKey:(SBJson4StreamWriter *)writer {
	writer.error = @"JSON object key must be string";
	return YES;
}
@end

@implementation SBJson4StreamWriterStateObjectKey

SINGLETON

- (void)appendSeparator:(SBJson4StreamWriter *)writer {
	[writer appendBytes:"," length:1];
}
@end

@implementation SBJson4StreamWriterStateObjectValue

SINGLETON

- (void)appendSeparator:(SBJson4StreamWriter *)writer {
	[writer appendBytes:":" length:1];
}
- (void)transitionState:(SBJson4StreamWriter *)writer {
    writer.state = [SBJson4StreamWriterStateObjectKey sharedInstance];
}
- (void)appendWhitespace:(SBJson4StreamWriter *)writer {
	[writer appendBytes:" " length:1];
}
@end

@implementation SBJson4StreamWriterStateArrayStart

SINGLETON

- (void)transitionState:(SBJson4StreamWriter *)writer {
    writer.state = [SBJson4StreamWriterStateArrayValue sharedInstance];
}
@end

@implementation SBJson4StreamWriterStateArrayValue

SINGLETON

- (void)appendSeparator:(SBJson4StreamWriter *)writer {
	[writer appendBytes:"," length:1];
}
@end

@implementation SBJson4StreamWriterStateStart

SINGLETON


- (void)transitionState:(SBJson4StreamWriter *)writer {
    writer.state = [SBJson4StreamWriterStateComplete sharedInstance];
}
- (void)appendSeparator:(SBJson4StreamWriter *)writer {
}
@end

@implementation SBJson4StreamWriterStateComplete

SINGLETON

- (BOOL)isInvalidState:(SBJson4StreamWriter *)writer {
	writer.error = @"Stream is closed";
	return YES;
}
@end

@implementation SBJson4StreamWriterStateError

SINGLETON

@end

