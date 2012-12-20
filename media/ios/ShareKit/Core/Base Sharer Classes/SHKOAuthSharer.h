//
//  SHKOAuthSharer.h
//  ShareKit
//
//  Created by Nathan Weiner on 6/21/10.

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

#import <Foundation/Foundation.h>
#import "SHKSharer.h"
#import "SHKOAuthView.h"
#import "OAuthConsumer.h"

@interface SHKOAuthSharer : SHKSharer
{
	NSString *consumerKey;
	NSString *secretKey;
	NSURL *authorizeCallbackURL;
	
	NSURL *authorizeURL;
	NSURL *accessURL;
	NSURL *requestURL;
	
	OAConsumer *consumer;
	OAToken *requestToken;
	OAToken *accessToken;
	
	id<OASignatureProviding> signatureProvider;
	
	NSDictionary *authorizeResponseQueryVars;
}

@property (nonatomic, retain) NSString *consumerKey;
@property (nonatomic, retain) NSString *secretKey;
@property (nonatomic, retain) NSURL *authorizeCallbackURL;

@property (nonatomic, retain) NSURL *authorizeURL;
@property (nonatomic, retain) NSURL *accessURL;
@property (nonatomic, retain) NSURL *requestURL;

@property (retain) OAConsumer *consumer;
@property (retain) OAToken *requestToken;
@property (retain) OAToken *accessToken;

@property (retain) id<OASignatureProviding> signatureProvider;

@property (nonatomic, retain) NSDictionary *authorizeResponseQueryVars;



#pragma mark -
#pragma mark OAuth Authorization

- (void)tokenRequest;
- (void)tokenRequestModifyRequest:(OAMutableURLRequest *)oRequest;
- (void)tokenRequestTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data;
- (void)tokenRequestTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error;

- (void)tokenAuthorize;

- (void)tokenAccess;
- (void)tokenAccess:(BOOL)refresh;
- (void)tokenAccessModifyRequest:(OAMutableURLRequest *)oRequest;
- (void)tokenAccessTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data;
- (void)tokenAccessTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error;

- (void)storeAccessToken;
- (BOOL)restoreAccessToken;
- (void)refreshToken;


@end
