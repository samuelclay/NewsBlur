//
//  SHKDelicious.m
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

#import "SHKConfiguration.h"
#import "SHKDelicious.h"
#import "OAuthConsumer.h"


// You can leave this be.  The user will actually never see this url.  ShareKit just looks for
// when delicious redirects to this url and intercepts it.  It can be any url.
#define SHKDeliciousCallbackUrl		@"http://getsharekit.com/oauthcallback"


// http://github.com/jdg/oauthconsumer/blob/master/OATokenManager.m

@implementation SHKDelicious


- (id)init
{
	if (self = [super init])
	{		
		self.consumerKey = SHKCONFIG(deliciousConsumerKey);		
		self.secretKey = SHKCONFIG(deliciousSecretKey);
 		self.authorizeCallbackURL = [NSURL URLWithString:SHKDeliciousCallbackUrl];// HOW-TO: In your Twitter application settings, use the "Callback URL" field.  If you do not have this field in the settings, set your application type to 'Browser'.
		
		
		// -- //
		
		
		// You do not need to edit these, they are the same for everyone
	    self.authorizeURL = [NSURL URLWithString:@"https://api.login.yahoo.com/oauth/v2/request_auth"];
	    self.requestURL = [NSURL URLWithString:@"https://api.login.yahoo.com/oauth/v2/get_request_token"];
	    self.accessURL = [NSURL URLWithString:@"https://api.login.yahoo.com/oauth/v2/get_token"];
		
		self.signatureProvider = [[[OAPlaintextSignatureProvider alloc] init] autorelease];
	}	
	return self;
}


#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return @"Delicious";
}

+ (BOOL)canShareURL
{
	return YES;
}


#pragma mark -
#pragma mark Authentication

- (void)tokenRequestModifyRequest:(OAMutableURLRequest *)oRequest
{
	[oRequest setOAuthParameterName:@"oauth_callback" withValue:authorizeCallbackURL.absoluteString];
}

- (void)tokenAccessModifyRequest:(OAMutableURLRequest *)oRequest
{
	if (pendingAction == SHKPendingRefreshToken)
	{
		if (accessToken.sessionHandle != nil)
			[oRequest setOAuthParameterName:@"oauth_session_handle" withValue:accessToken.sessionHandle];	
	}
	
	else
		[oRequest setOAuthParameterName:@"oauth_verifier" withValue:[authorizeResponseQueryVars objectForKey:@"oauth_verifier"]];
}

- (BOOL)handleResponse:(SHKRequest *)aRequest
{
	if (aRequest.response.statusCode == 401)
	{
		[self sendDidFailShouldRelogin];		
		return NO;		
	} 
	
	return YES;
}


#pragma mark -
#pragma mark Share Form

- (NSArray *)shareFormFieldsForType:(SHKShareType)type
{
	if (type == SHKShareTypeURL)
		return [NSArray arrayWithObjects:
				[SHKFormFieldSettings label:SHKLocalizedString(@"Title") key:@"title" type:SHKFormFieldTypeText start:item.title],
				[SHKFormFieldSettings label:SHKLocalizedString(@"Tags") key:@"tags" type:SHKFormFieldTypeText start:item.tags],
				[SHKFormFieldSettings label:SHKLocalizedString(@"Notes") key:@"text" type:SHKFormFieldTypeText start:item.text],
				[SHKFormFieldSettings label:SHKLocalizedString(@"Shared") key:@"shared" type:SHKFormFieldTypeSwitch start:SHKFormFieldSwitchOff],
				nil];
	
	return nil;
}



#pragma mark -
#pragma mark Share API Methods

- (BOOL)send
{	
	if ([self validateItem])
	{			
		OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://api.del.icio.us/v2/posts/add"]
																		consumer:consumer
																		   token:accessToken
																		   realm:@"yahooapis.com"
															   signatureProvider:nil];
		
		[oRequest setHTTPMethod:@"GET"];
		
		
		OARequestParameter *urlParam = [OARequestParameter requestParameterWithName:@"url"
																			  value:[item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		
		OARequestParameter *descParam = [OARequestParameter requestParameterWithName:@"description"
																			   value:SHKStringOrBlank(item.title)];
		
		OARequestParameter *tagsParam = [OARequestParameter requestParameterWithName:@"tags"
																			   value:SHKStringOrBlank(item.tags)];
		
		OARequestParameter *extendedParam = [OARequestParameter requestParameterWithName:@"extended"
																				   value:SHKStringOrBlank(item.text)];
		
		OARequestParameter *sharedParam = [OARequestParameter requestParameterWithName:@"shared"
																				 value:[item customBoolForSwitchKey:@"shared"]?@"yes":@"no"];
		
		
		[oRequest setParameters:[NSArray arrayWithObjects:descParam, extendedParam, sharedParam, tagsParam, urlParam, nil]];
		
		OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
																							  delegate:self
																					 didFinishSelector:@selector(sendTicket:didFinishWithData:)
																					   didFailSelector:@selector(sendTicket:didFailWithError:)];	
		
		[fetcher start];
		[oRequest release];
		
		// Notify delegate
		[self sendDidStart];
		
		return YES;
	}
	
	return NO;
}


- (void)sendTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{		
	if (ticket.didSucceed && [ticket.body rangeOfString:@"\"done\""].location != NSNotFound) 
	{
		// Do anything?
	}
	
	else 
	{	
		if (SHKDebugShowLogs) // check so we don't have to alloc the string with the data if we aren't logging
			SHKLog(@"SHKDelicious sendTicket Response Body: %@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
		
		// Look for oauth problems		
		// TODO - I'd prefer to use regex for this but that would require OS4 or adding a regex library
		NSError *error;
		NSString *body = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		
		// Expired token
		if ([body rangeOfString:@"token_expired"].location != NSNotFound || [body rangeOfString:@"Please provide valid credentials"].location != NSNotFound)
		{
			[self refreshToken];
			return;
		}
		
		else
			error = [SHK error:SHKLocalizedString(@"There was a problem saving to Delicious.")];
		
		[self sendTicket:ticket didFailWithError:error];
	}
	
	// Notify delegate
	[self sendDidFinish];
}

- (void)sendTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	[self sendDidFailWithError:error];
}



@end
