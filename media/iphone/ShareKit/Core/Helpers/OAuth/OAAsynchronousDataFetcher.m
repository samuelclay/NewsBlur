//
//  OAAsynchronousDataFetcher.m
//  OAuthConsumer
//
//  Created by Zsombor Szabó on 12/3/08.
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

#import "OAAsynchronousDataFetcher.h"

#import "OAServiceTicket.h"

@implementation OAAsynchronousDataFetcher

+ (id)asynchronousFetcherWithRequest:(OAMutableURLRequest *)aRequest delegate:(id)aDelegate didFinishSelector:(SEL)finishSelector didFailSelector:(SEL)failSelector
{
	return [[[OAAsynchronousDataFetcher alloc] initWithRequest:aRequest delegate:aDelegate didFinishSelector:finishSelector didFailSelector:failSelector] autorelease];
}

- (id)initWithRequest:(OAMutableURLRequest *)aRequest delegate:(id)aDelegate didFinishSelector:(SEL)finishSelector didFailSelector:(SEL)failSelector
{
	if (self = [super init])
	{
		request = [aRequest retain];
		delegate = aDelegate;
		didFinishSelector = finishSelector;
		didFailSelector = failSelector;	
	}
	return self;
}

- (void)start
{    
    [request prepare];
	
	if (connection)
		[connection release];
	
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
	if (connection)
	{
		if (responseData)
			[responseData release];
		responseData = [[NSMutableData data] retain];
	}
	else
	{
        OAServiceTicket *ticket= [[OAServiceTicket alloc] initWithRequest:request
                                                                 response:nil
                                                               didSucceed:NO];
        [delegate performSelector:didFailSelector
                       withObject:ticket
                       withObject:nil];
		[ticket release];
	}
}

- (void)cancel
{
	if (connection)
	{
		[connection cancel];
		[connection release];
		connection = nil;
	}
}

- (void)dealloc
{
	if (request) [request release];
	if (connection) [connection release];
	if (response) [response release];
	if (responseData) [responseData release];
	[super dealloc];
}

#pragma mark -
#pragma mark NSURLConnection methods

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)aResponse
{
	if (response)
		[response release];
	response = (NSHTTPURLResponse *)[aResponse retain];
	[responseData setLength:0];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
	[responseData appendData:data];
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error
{
	OAServiceTicket *ticket= [[OAServiceTicket alloc] initWithRequest:request
															 response:response
														   didSucceed:NO];
	[delegate performSelector:didFailSelector
				   withObject:ticket
				   withObject:error];
	
	[ticket release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
	OAServiceTicket *ticket = [[OAServiceTicket alloc] initWithRequest:request
															  response:response
															didSucceed:[(NSHTTPURLResponse *)response statusCode] < 400];
	[delegate performSelector:didFinishSelector
				   withObject:ticket
				   withObject:responseData];
	
	[ticket release];
}

@end
