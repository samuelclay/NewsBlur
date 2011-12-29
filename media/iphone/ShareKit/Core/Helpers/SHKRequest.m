//
//  SHKRequest.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/9/10.

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
//
//

#import "SHKRequest.h"
#import "DefaultSHKConfigurator.h"

#define SHK_TIMEOUT 90

@implementation SHKRequest

@synthesize url, params, method, headerFields;
@synthesize delegate, isFinishedSelector;
@synthesize data, result, headers, response, connection;
@synthesize success;

- (void)dealloc
{
	[url release];
	[params release];
	[method release];
	[headerFields release];
	[connection release];
	[data release];
	[result release];
	[response release];
    [headers release];
	[super dealloc];
}

- (id)initWithURL:(NSURL *)u params:(NSString *)p delegate:(id)d isFinishedSelector:(SEL)s method:(NSString *)m autostart:(BOOL)autostart
{
	if (self = [super init])
	{
		self.url = u;
		self.params = p;
		self.method = m;
		
		self.delegate = d;
		self.isFinishedSelector = s;
		
		if (autostart)
			[self start];
	}
	
	return self;
}


#pragma mark -

- (void)start
{
	NSMutableData *aData = [[NSMutableData alloc] initWithLength:0];
    self.data = aData;
	[aData release];
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
																  cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
															  timeoutInterval:SHK_TIMEOUT];
	
	// overwrite header fields (generally for cookies)
	if (headerFields != nil)
		[request setAllHTTPHeaderFields:headerFields];	
	
	// Setup Request Data/Params
	if (params != nil)
	{
		NSData *paramsData = [ NSData dataWithBytes:[params UTF8String] length:[params length] ];
		
		// Fill Request
		[request setHTTPMethod:method];
		[request setHTTPBody:paramsData];
	}
	
	// Start Connection
	SHKLog(@"Start SHKRequest:\nURL: %@\nparams: %@", url, params);
	NSURLConnection *aConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    [request release];
    self.connection = aConnection;	
	[aConnection release];
}


#pragma mark -

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)theResponse 
{
	self.response = theResponse;
	NSDictionary *aHeaders = [[response allHeaderFields] mutableCopy];
	self.headers = aHeaders;
	[aHeaders release];
	
	[data setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)d 
{
	[data appendData:d];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection 
{
	[self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error 
{
	[self finish];
}

#pragma mark -

- (void)finish
{
	self.success = (response.statusCode == 200 || response.statusCode == 201);
	
	if ([delegate respondsToSelector:isFinishedSelector])
		[delegate performSelector:isFinishedSelector withObject:self];
}

- (NSString *)getResult
{
	if (result == nil)
		self.result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	return result;
}


@end
