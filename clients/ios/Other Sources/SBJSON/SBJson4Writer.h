/*
 Copyright (C) 2009 Stig Brautaset. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 * Neither the name of the author nor the names of its contributors may be used
   to endorse or promote products derived from this software without specific
   prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

/**
 The JSON writer class.

 This uses SBJson4StreamWriter internally.

 */

@interface SBJson4Writer : NSObject

/**
 The maximum depth.

 Defaults to 32. If the input is nested deeper than this the input will be deemed to be
 malicious and the parser returns nil, signalling an error. ("Nested too deep".) You can
 turn off this security feature by setting the maxDepth value to 0.
 */
@property(nonatomic) NSUInteger maxDepth;

/**
 Return an error trace, or nil if there was no errors.

 Note that this method returns the trace of the last method that failed.
 You need to check the return value of the call you're making to figure out
 if the call actually failed, before you know call this method.
 */
@property (nonatomic, readonly, copy) NSString *error;

/**
 Whether we are generating human-readable (multi line) JSON.

 Set whether or not to generate human-readable JSON. The default is NO, which produces
 JSON without any whitespace. (Except inside strings.) If set to YES, generates human-readable
 JSON with line breaks after each array value and dictionary key/value pair, indented two
 spaces per nesting level.
 */
@property(nonatomic) BOOL humanReadable;

/**
 Whether or not to sort the dictionary keys in the output.

 If this is set to YES, the dictionary keys in the JSON output will be in sorted order.
 (This is useful if you need to compare two structures, for example.) The default is NO.
 */
@property(nonatomic) BOOL sortKeys;

/**
 An optional comparator to be used if sortKeys is YES.

 If this is nil, sorting will be done via @selector(compare:).
 */
@property (nonatomic, copy) NSComparator sortKeysComparator;

/**
 Generates string with JSON representation for the given object.

 Returns a string containing JSON representation of the passed in value, or nil on error.
 If nil is returned and error is not NULL, *error can be interrogated to find the cause of the error.

 @param value any instance that can be represented as JSON text.
 */
- (NSString*)stringWithObject:(id)value;

/**
 Generates JSON representation for the given object.

 Returns an NSData object containing JSON represented as UTF8 text, or nil on error.

 @param value any instance that can be represented as JSON text.
 */
- (NSData*)dataWithObject:(id)value;

@end
