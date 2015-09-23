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

#import <Foundation/Foundation.h>

@class SBJson4StreamParser;
@class SBJson4StreamParserState;

typedef enum {
    SBJson4ParserComplete,
    SBJson4ParserStopped,
    SBJson4ParserWaitingForData,
    SBJson4ParserError,
} SBJson4ParserStatus;


/**
 Delegate for interacting directly with the low-level parser

 You will most likely find it much more convenient to use the SBJson4Parser instead.
 */
@protocol SBJson4StreamParserDelegate < NSObject >

/// Called when object start is found
- (void)parserFoundObjectStart;

/// Called when object key is found
- (void)parserFoundObjectKey:(NSString *)key;

/// Called when object end is found
- (void)parserFoundObjectEnd;

/// Called when array start is found
- (void)parserFoundArrayStart;

/// Called when array end is found
- (void)parserFoundArrayEnd;

/// Called when a boolean value is found
- (void)parserFoundBoolean:(BOOL)x;

/// Called when a null value is found
- (void)parserFoundNull;

/// Called when a number is found
- (void)parserFoundNumber:(NSNumber *)num;

/// Called when a string is found
- (void)parserFoundString:(NSString *)string;

/// Called when an error occurs
- (void)parserFoundError:(NSError *)err;

@optional

/// Called to determine whether to allow multiple whitespace-separated documents
- (BOOL)parserShouldSupportManyDocuments;

@end

/**
 Low-level Stream parser

 You most likely want to use the SBJson4Parser instead, but if you
 really need low-level access to tokens one-by-one you can use this class.
 */
@interface SBJson4StreamParser : NSObject

@property (nonatomic, weak) SBJson4StreamParserState *state; // Private

/**
 Delegate to receive messages

 The object set here receives a series of messages as the parser breaks down the JSON stream
 into valid tokens.

 Usually this should be an instance of SBJson4Parser, but you can
 substitute your own implementation of the SBJson4StreamParserDelegate protocol if you need to.
 */
@property (nonatomic, weak) id<SBJson4StreamParserDelegate> delegate;

/**
 Parse some JSON

 The JSON is assumed to be UTF8 encoded. This can be a full JSON document, or a part of one.

 @param data An NSData object containing the next chunk of JSON

 @return
 - SBJson4ParserComplete if a full document was found
 - SBJson4ParserWaitingForData if a partial document was found and more data is required to complete it
 - SBJson4ParserError if an error occurred.

 */
- (SBJson4ParserStatus)parse:(NSData*)data;

/**
 Call this to cause parsing to stop.
 */
- (void)stop;

@end
