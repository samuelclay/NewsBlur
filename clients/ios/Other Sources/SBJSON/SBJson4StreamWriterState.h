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

#import <Foundation/Foundation.h>

@class SBJson4StreamWriter;

@interface SBJson4StreamWriterState : NSObject
+ (id)sharedInstance;
- (BOOL)isInvalidState:(SBJson4StreamWriter *)writer;
- (void)appendSeparator:(SBJson4StreamWriter *)writer;
- (BOOL)expectingKey:(SBJson4StreamWriter *)writer;
- (void)transitionState:(SBJson4StreamWriter *)writer;
- (void)appendWhitespace:(SBJson4StreamWriter *)writer;
@end

@interface SBJson4StreamWriterStateObjectStart : SBJson4StreamWriterState
@end

@interface SBJson4StreamWriterStateObjectKey : SBJson4StreamWriterStateObjectStart
@end

@interface SBJson4StreamWriterStateObjectValue : SBJson4StreamWriterState
@end

@interface SBJson4StreamWriterStateArrayStart : SBJson4StreamWriterState
@end

@interface SBJson4StreamWriterStateArrayValue : SBJson4StreamWriterState
@end

@interface SBJson4StreamWriterStateStart : SBJson4StreamWriterState
@end

@interface SBJson4StreamWriterStateComplete : SBJson4StreamWriterState
@end

@interface SBJson4StreamWriterStateError : SBJson4StreamWriterState
@end

