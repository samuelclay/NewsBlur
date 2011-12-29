//
//  SHKOAuthSharer.m
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

#import "SHKOAuthSharer.h"
#import "SHKOAuthView.h"
#import "OAuthConsumer.h"


@implementation SHKOAuthSharer

@synthesize consumerKey, secretKey, authorizeCallbackURL;
@synthesize authorizeURL, requestURL, accessURL;
@synthesize consumer, requestToken, accessToken;
@synthesize signatureProvider;
@synthesize authorizeResponseQueryVars;


- (void)dealloc
{
	[consumerKey release];
	[secretKey release];
	[authorizeCallbackURL release];
	[authorizeURL release];
	[requestURL release];
	[accessURL release];
	[consumer release];
	[requestToken release];
	[accessToken release];
	[signatureProvider release];
	[authorizeResponseQueryVars release];
	
	[super dealloc];
}



#pragma mark -
#pragma mark Authorization

- (BOOL)isAuthorized
{		
	return [self restoreAccessToken];
}

- (void)promptAuthorization
{		
	[self tokenRequest];
}


#pragma mark Request

- (void)tokenRequest
{
	[[SHKActivityIndicator currentIndicator] displayActivity:SHKLocalizedString(@"Connecting...")];
	
    OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:requestURL
                                                                   consumer:consumer
                                                                      token:nil   // we don't have a Token yet
                                                                      realm:nil   // our service provider doesn't specify a realm
														   signatureProvider:signatureProvider];
																
	
	[oRequest setHTTPMethod:@"POST"];
	
	[self tokenRequestModifyRequest:oRequest];
	
    OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
                         delegate:self
                didFinishSelector:@selector(tokenRequestTicket:didFinishWithData:)
                  didFailSelector:@selector(tokenRequestTicket:didFailWithError:)];
	[fetcher start];	
	[oRequest release];
}

- (void)tokenRequestModifyRequest:(OAMutableURLRequest *)oRequest
{
	// Subclass to add custom paramaters and headers
}

- (void)tokenRequestTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{
	if (SHKDebugShowLogs) // check so we don't have to alloc the string with the data if we aren't logging
		SHKLog(@"tokenRequestTicket Response Body: %@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
	
	[[SHKActivityIndicator currentIndicator] hide];
	
	if (ticket.didSucceed) 
	{
		NSString *responseBody = [[NSString alloc] initWithData:data
													   encoding:NSUTF8StringEncoding];
		OAToken *aToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
        [responseBody release];
        self.requestToken =  aToken;
        [aToken release];		
		
		[self tokenAuthorize];
	}
	
	else
		// TODO - better error handling here
		[self tokenRequestTicket:ticket didFailWithError:[SHK error:SHKLocalizedString(@"There was a problem requesting authorization from %@", [self sharerTitle])]];
}

- (void)tokenRequestTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	[[SHKActivityIndicator currentIndicator] hide];
	
	[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Request Error")
								 message:error!=nil?[error localizedDescription]:SHKLocalizedString(@"There was an error while sharing")
								delegate:nil
					   cancelButtonTitle:SHKLocalizedString(@"Close")
					   otherButtonTitles:nil] autorelease] show];
}


#pragma mark Authorize 

- (void)tokenAuthorize
{	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?oauth_token=%@", authorizeURL.absoluteString, requestToken.key]];
	
	SHKOAuthView *auth = [[SHKOAuthView alloc] initWithURL:url delegate:self];
	[[SHK currentHelper] showViewController:auth];	
	[auth release];
}

- (void)tokenAuthorizeView:(SHKOAuthView *)authView didFinishWithSuccess:(BOOL)success queryParams:(NSMutableDictionary *)queryParams error:(NSError *)error;
{
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
	
	if (!success)
	{
		[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Authorize Error")
									 message:error!=nil?[error localizedDescription]:SHKLocalizedString(@"There was an error while authorizing")
									delegate:nil
						   cancelButtonTitle:SHKLocalizedString(@"Close")
						   otherButtonTitles:nil] autorelease] show];
	}	
	
	else 
	{
		self.authorizeResponseQueryVars = queryParams;
		
		[self tokenAccess];
	}
}

- (void)tokenAuthorizeCancelledView:(SHKOAuthView *)authView
{
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];	
}


#pragma mark Access

- (void)tokenAccess
{
	[self tokenAccess:NO];
}

- (void)tokenAccess:(BOOL)refresh
{
	if (!refresh)
		[[SHKActivityIndicator currentIndicator] displayActivity:SHKLocalizedString(@"Authenticating...")];
	
    OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:accessURL
                                                                   consumer:consumer
																	   token:(refresh ? accessToken : requestToken)
                                                                      realm:nil   // our service provider doesn't specify a realm
                                                          signatureProvider:signatureProvider]; // use the default method, HMAC-SHA1
	
    [oRequest setHTTPMethod:@"POST"];
	
	[self tokenAccessModifyRequest:oRequest];
	
    OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
                         delegate:self
                didFinishSelector:@selector(tokenAccessTicket:didFinishWithData:)
                  didFailSelector:@selector(tokenAccessTicket:didFailWithError:)];
	[fetcher start];
	[oRequest release];
}

- (void)tokenAccessModifyRequest:(OAMutableURLRequest *)oRequest
{
	// Subclass to add custom paramaters or headers	
}

- (void)tokenAccessTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{
	if (SHKDebugShowLogs) // check so we don't have to alloc the string with the data if we aren't logging
		SHKLog(@"tokenAccessTicket Response Body: %@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
	
	[[SHKActivityIndicator currentIndicator] hide];
	
	if (ticket.didSucceed) 
	{
		NSString *responseBody = [[NSString alloc] initWithData:data
													   encoding:NSUTF8StringEncoding];
		OAToken *aAccesToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
        [responseBody release];
        self.accessToken = aAccesToken;
        [aAccesToken release];	
        
		[self storeAccessToken];
		
		[self tryPendingAction];
	}
	
	
	else
		// TODO - better error handling here
		[self tokenAccessTicket:ticket didFailWithError:[SHK error:SHKLocalizedString(@"There was a problem requesting access from %@", [self sharerTitle])]];

	[self authDidFinish:ticket.didSucceed];
}

- (void)tokenAccessTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	[[SHKActivityIndicator currentIndicator] hide];
	
	[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Access Error")
								 message:error!=nil?[error localizedDescription]:SHKLocalizedString(@"There was an error while sharing")
								delegate:nil
					   cancelButtonTitle:SHKLocalizedString(@"Close")
					   otherButtonTitles:nil] autorelease] show];
}

- (void)storeAccessToken
{	
	[SHK setAuthValue:accessToken.key
					 forKey:@"accessKey"
				  forSharer:[self sharerId]];
	
	[SHK setAuthValue:accessToken.secret
					 forKey:@"accessSecret"
			forSharer:[self sharerId]];
	
	[SHK setAuthValue:accessToken.sessionHandle
			   forKey:@"sessionHandle"
			forSharer:[self sharerId]];
}

+ (void)deleteStoredAccessToken
{
	NSString *sharerId = [self sharerId];
	
	[SHK removeAuthValueForKey:@"accessKey" forSharer:sharerId];
	[SHK removeAuthValueForKey:@"accessSecret" forSharer:sharerId];
	[SHK removeAuthValueForKey:@"sessionHandle" forSharer:sharerId];
}

+ (void)logout
{
	[self deleteStoredAccessToken];
	
	// Clear cookies (for OAuth, doesn't affect XAuth)
	// TODO - move the authorizeURL out of the init call (into a define) so we don't have to create an object just to get it
	SHKOAuthSharer *sharer = [[self alloc] init];
	if (sharer.authorizeURL)
	{
		NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
		NSArray *cookies = [storage cookiesForURL:sharer.authorizeURL];
		for (NSHTTPCookie *each in cookies) 
		{
			[storage deleteCookie:each];
		}
	}
	[sharer release];
}

- (BOOL)restoreAccessToken
{
	self.consumer = [[[OAConsumer alloc] initWithKey:consumerKey secret:secretKey] autorelease];
	
	if (accessToken != nil)
		return YES;
		
	NSString *key = [SHK getAuthValueForKey:@"accessKey"
				  forSharer:[self sharerId]];
	
	NSString *secret = [SHK getAuthValueForKey:@"accessSecret"
									 forSharer:[self sharerId]];
	
	NSString *sessionHandle = [SHK getAuthValueForKey:@"sessionHandle"
									 forSharer:[self sharerId]];
	
	if (key != nil && secret != nil)
	{
		self.accessToken = [[[OAToken alloc] initWithKey:key secret:secret] autorelease];
		
		if (sessionHandle != nil)
			accessToken.sessionHandle = sessionHandle;
		
		return accessToken != nil;
	}
	
	return NO;
}


#pragma mark Expired

- (void)refreshToken
{
	self.pendingAction = SHKPendingRefreshToken;
	[self tokenAccess:YES];
}

#pragma mark -
#pragma mark Pending Actions
#pragma mark -
#pragma mark Pending Actions

- (void)tryPendingAction
{
	switch (pendingAction) 
	{
		case SHKPendingRefreshToken:
			[self tryToSend]; // try to resend
			break;
			
		default:			
			[super tryPendingAction];			
	}
}


@end
