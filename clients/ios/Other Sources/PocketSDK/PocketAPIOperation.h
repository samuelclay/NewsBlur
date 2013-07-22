//
//  PocketAPIOperation.h
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

#import <Foundation/Foundation.h>
#import "PocketAPI.h"
#import "PocketAPITypes.h"

@interface NSDictionary (PocketAdditions)

-(NSString *)pkt_URLEncodedFormString;
+(NSDictionary *)pkt_dictionaryByParsingURLEncodedFormString:(NSString *)formString;

@end

@interface PocketAPIOperation : NSOperation <NSURLConnectionDelegate, NSCopying, PocketAPIDelegate> {
	PocketAPI *API;
	id<PocketAPIDelegate> delegate;
	
	PocketAPIDomain domain;
	PocketAPIHTTPMethod HTTPMethod;
	NSString *APIMethod;
	NSDictionary *arguments;
	
	NSURLConnection *connection;
	NSHTTPURLResponse *response;
	NSMutableData *data;
	NSError *error;
	
	NSString *baseURLPath;
	
	BOOL finishedLoading;
	BOOL attemptedRelogin;
}

@property (nonatomic, retain) PocketAPI *API;
@property (nonatomic, retain) id<PocketAPIDelegate> delegate; // we break convention here to ensure the delegate exists for operation lifetime, release on complete

@property (nonatomic, readonly, retain) NSString *baseURLPath;
@property (nonatomic, assign) PocketAPIDomain domain;
@property (nonatomic, assign) PocketAPIHTTPMethod HTTPMethod;
@property (nonatomic, retain) NSString *APIMethod;
@property (nonatomic, retain) NSDictionary *arguments;

@property (nonatomic, readonly, retain) NSURLConnection *connection;
@property (nonatomic, readonly, retain) NSHTTPURLResponse *response;
@property (nonatomic, readonly, retain) NSMutableData *data;

@property (nonatomic, readonly, retain) NSError *error;

+(NSString *)encodeForURL:(NSString *)urlStr;

@end

NSString *PocketAPINameForHTTPMethod(PocketAPIHTTPMethod method);