//
//  PocketAPI.h
//  PocketSDK
//
//  Created by James Yopp on 2012/08/21.
//  Copyright (c) 2012 Read It Later, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this
//  software and associated documentation files (the "Software"), to deal in the Software
//  without restriction, including without limitation the rights to use, copy, modify,
//  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//


// Advanced use if you use your own NSOperationQueues for handling network traffic.
// If you don't need tight control over network requests, just use the simple API.
// Note: May not behave predictably if recoverable errors are encountered.

@interface PocketAPI (NSOperations)

-(NSOperation *)saveOperationWithURL:(NSURL *)url
							delegate:(id<PocketAPIDelegate>)delegate;

-(NSOperation *)saveOperationWithURL:(NSURL *)url
							   title:(NSString *)title
							delegate:(id<PocketAPIDelegate>)delegate;

-(NSOperation *)saveOperationWithURL:(NSURL *)url
							   title:(NSString *)title
							 tweetID:(NSString *)tweetID
							delegate:(id<PocketAPIDelegate>)delegate;

-(NSOperation *)methodOperationWithAPIMethod:(NSString *)APIMethod
							   forHTTPMethod:(PocketAPIHTTPMethod)HTTPMethod
								   arguments:(NSDictionary *)arguments
									delegate:(id<PocketAPIDelegate>)delegate;

#if NS_BLOCKS_AVAILABLE
-(NSOperation *)saveOperationWithURL:(NSURL *)url
							 handler:(PocketAPISaveHandler)handler;

-(NSOperation *)saveOperationWithURL:(NSURL *)url
							   title:(NSString *)title
							 handler:(PocketAPISaveHandler)handler;

-(NSOperation *)saveOperationWithURL:(NSURL *)url
							   title:(NSString *)title
							 tweetID:(NSString *)tweetID
							 handler:(PocketAPISaveHandler)handler;

-(NSOperation *)methodOperationWithAPIMethod:(NSString *)APIMethod
							   forHTTPMethod:(PocketAPIHTTPMethod)HTTPMethod
								   arguments:(NSDictionary *)arguments
									 handler:(PocketAPIResponseHandler)handler;
#endif

@end