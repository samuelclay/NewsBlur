//
//  OAServiceTicket.m
//  OAuthConsumer
//
//  Created by Jon Crosby on 11/5/07.
//  Copyright 2007 Kaboomerang LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import "OAServiceTicket.h"


@implementation OAServiceTicket
@synthesize request, response, data, didSucceed;

- (id)initWithRequest:(OAMutableURLRequest *)aRequest response:(NSHTTPURLResponse *)aResponse didSucceed:(BOOL)success 
{
	return [self initWithRequest:aRequest response:aResponse data:nil didSucceed:success];
}

- (id)initWithRequest:(OAMutableURLRequest *)aRequest response:(NSHTTPURLResponse *)aResponse data:(NSData *)aData didSucceed:(BOOL)success {
    self = [super init];
    request = aRequest;
    response = aResponse;
	data = aData;
    didSucceed = success;
    return self;
}

- (NSString *)body
{
	if (!data) {
		return nil;
	}
	
	return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

@end
