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

#if !__has_feature(objc_arc)
#error "This source file must be compiled with ARC enabled!"
#endif

#import "SBJson4Writer.h"
#import "SBJson4StreamWriter.h"


@interface SBJson4Writer () < SBJson4StreamWriterDelegate >
@property (nonatomic, copy) NSString *error;
@property (nonatomic, strong) NSMutableData *acc;
@end

@implementation SBJson4Writer

- (id)init {
    self = [super init];
    if (self) {
        self.maxDepth = 32u;
    }
    return self;
}


- (NSString*)stringWithObject:(id)value {
	NSData *data = [self dataWithObject:value];
	if (data)
		return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	return nil;
}

- (NSData*)dataWithObject:(id)object {
    self.error = nil;

    self.acc = [[NSMutableData alloc] initWithCapacity:8096u];

    SBJson4StreamWriter *streamWriter = [[SBJson4StreamWriter alloc] init];
	streamWriter.sortKeys = self.sortKeys;
	streamWriter.maxDepth = self.maxDepth;
	streamWriter.sortKeysComparator = self.sortKeysComparator;
	streamWriter.humanReadable = self.humanReadable;
    streamWriter.delegate = self;

	BOOL ok = NO;
	if ([object isKindOfClass:[NSDictionary class]])
		ok = [streamWriter writeObject:object];

	else if ([object isKindOfClass:[NSArray class]])
		ok = [streamWriter writeArray:object];

	else if ([object respondsToSelector:@selector(proxyForJson)])
		return [self dataWithObject:[object proxyForJson]];
	else {
		self.error = @"Not valid type for JSON";
		return nil;
	}

	if (ok)
		return self.acc;

	self.error = streamWriter.error;
	return nil;
}

#pragma mark SBJson4StreamWriterDelegate

- (void)writer:(SBJson4StreamWriter *)writer appendBytes:(const void *)bytes length:(NSUInteger)length {
    [self.acc appendBytes:bytes length:length];
}



@end
