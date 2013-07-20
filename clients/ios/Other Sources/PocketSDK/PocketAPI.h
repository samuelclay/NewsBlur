//
//  PocketAPI.h
//  PocketSDK
//
//  Created by Steve Streza on 5/29/12.
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

/**
 * The PocketAPI class represents a singleton for saving stuff to a user's Pocket list.
 * To begin, you will need to obtain an API token from https://getpocket.com/api/ and set it
 * on the PocketAPI singleton at some point at the beginning of your application's lifecycle.
 *
 * APIs are presented in one of four ways, but all behave fundamentally the same. Their differences
 * are presented for flexibility for your app. You can use:
 *
 * - a delegate-based API
 * - a block-based API
 * - an NSOperation based on a delegate (for advanced uses)
 * - an NSOperation based on a block (for advanced uses)
 *
 * All delegates and blocks are called on the main thread, so you can safely update UI from there.
 *
 * You can find more information on these in PocketAPITypes.h
 *
 * These classes are not implemented as ARC, but will interoperate with ARC. You will need to add the
 * -fno-objc-arc compiler flag to each of the files in the SDK.
 */

#import <Foundation/Foundation.h>
#import "PocketAPITypes.h"

@class PocketAPILogin;

@interface PocketAPI : NSObject {
	NSString *consumerKey;
	NSString *URLScheme;
	NSOperationQueue *operationQueue;
	
	PocketAPILogin *currentLogin;
	NSString *userAgent;
}

@property (nonatomic, retain) NSString *consumerKey;
@property (nonatomic, retain) NSString *URLScheme; // if you do not set this, it is derived from your consumer key

@property (nonatomic, copy, readonly) NSString *username;
@property (nonatomic, assign, readonly, getter=isLoggedIn) BOOL loggedIn;

@property (nonatomic, retain) NSOperationQueue *operationQueue;

+(PocketAPI *)sharedAPI;
+(BOOL)hasPocketAppInstalled;
+(NSString *)pocketAppURLScheme;

-(void)setConsumerKey:(NSString *)consumerKey;

-(NSUInteger)appID;

// Simple API
-(void)loginWithDelegate:(id<PocketAPIDelegate>)delegate;

-(void)saveURL:(NSURL *)url
	  delegate:(id<PocketAPIDelegate>)delegate;
-(void)saveURL:(NSURL *)url
	 withTitle:(NSString *)title
	  delegate:(id<PocketAPIDelegate>)delegate;
-(void)saveURL:(NSURL *)url
	 withTitle:(NSString *)title
	   tweetID:(NSString *)tweetID
	  delegate:(id<PocketAPIDelegate>)delegate;

-(void)callAPIMethod:(NSString *)apiMethod
	  withHTTPMethod:(PocketAPIHTTPMethod)HTTPMethod
		   arguments:(NSDictionary *)arguments
			delegate:(id<PocketAPIDelegate>)delegate;

#if NS_BLOCKS_AVAILABLE
-(void)loginWithHandler:(PocketAPILoginHandler)handler;

-(void)saveURL:(NSURL *)url
	   handler:(PocketAPISaveHandler)handler;
-(void)saveURL:(NSURL *)url
	 withTitle:(NSString *)title
	   handler:(PocketAPISaveHandler)handler;
-(void)saveURL:(NSURL *)url
	 withTitle:(NSString *)title
	   tweetID:(NSString *)tweetID
	   handler:(PocketAPISaveHandler)handler;

-(void)callAPIMethod:(NSString *)apiMethod
	  withHTTPMethod:(PocketAPIHTTPMethod)HTTPMethod
		   arguments:(NSDictionary *)arguments
			 handler:(PocketAPIResponseHandler)handler;
#endif

-(void)logout;

-(BOOL)handleOpenURL:(NSURL *)url;

@end

extern NSString *PocketAPITweetID(unsigned long long tweetID);
