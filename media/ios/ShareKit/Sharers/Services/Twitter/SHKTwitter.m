//
//  SHKTwitter.m
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

// TODO - SHKTwitter supports offline sharing, however the url cannot be shortened without an internet connection.  Need a graceful workaround for this.


#import "SHKConfiguration.h"
#import "SHKTwitter.h"
//#import "JSONKit.h"
#import "JSON.h"
#import "SHKiOS5Twitter.h"

static NSString *const kSHKTwitterUserInfo=@"kSHKTwitterUserInfo";

@interface SHKTwitter ()

- (BOOL)prepareItem;
- (BOOL)shortenURL;
- (void)shortenURLFinished:(SHKRequest *)aRequest;
- (BOOL)validateItemAfterUserEdit;
- (void)handleUnsuccessfulTicket:(NSData *)data;
- (void)convertNSNullsToEmptyStrings:(NSMutableDictionary *)dict;

@end

@implementation SHKTwitter

@synthesize xAuth;

- (id)init
{
	if (self = [super init])
	{	
		// OAUTH		
		self.consumerKey = SHKCONFIG(twitterConsumerKey);		
		self.secretKey = SHKCONFIG(twitterSecret);
 		self.authorizeCallbackURL = [NSURL URLWithString:SHKCONFIG(twitterCallbackUrl)];// HOW-TO: In your Twitter application settings, use the "Callback URL" field.  If you do not have this field in the settings, set your application type to 'Browser'.
		
		// XAUTH
		self.xAuth = [SHKCONFIG(twitterUseXAuth) boolValue]?YES:NO;
		
		
		// -- //
		
		
		// You do not need to edit these, they are the same for everyone
	    self.authorizeURL = [NSURL URLWithString:@"https://twitter.com/oauth/authorize"];
	    self.requestURL = [NSURL URLWithString:@"https://twitter.com/oauth/request_token"];
	    self.accessURL = [NSURL URLWithString:@"https://twitter.com/oauth/access_token"]; 
	}	
	return self;
}


#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return @"Twitter";
}

+ (BOOL)canShareURL
{
	return YES;
}

+ (BOOL)canShareText
{
	return YES;
}

// TODO use img.ly to support this
+ (BOOL)canShareImage
{
	return YES;
}

+ (BOOL)canGetUserInfo
{
    return YES;
}

#pragma mark -
#pragma mark Configuration : Dynamic Enable

- (BOOL)shouldAutoShare
{
	return NO;
}

#pragma mark -
#pragma mark Commit Share

- (void)share {
    
    if (NSClassFromString(@"TWTweetComposeViewController")) {
        
        [SHKiOS5Twitter shareItem:self.item];
        return;
    }
    
    BOOL itemPrepared = [self prepareItem];
    
    //the only case item is not prepared is when we wait for URL to be shortened on background thread. In this case [super share] is called in callback method
    if (itemPrepared) {
        [super share];
    }
}

#pragma mark -

- (BOOL)prepareItem {
    
    BOOL result = YES;
    
    if (item.shareType == SHKShareTypeURL)
	{
		BOOL isURLAlreadyShortened = [self shortenURL];
        result = isURLAlreadyShortened;
        
	}
	
	else if (item.shareType == SHKShareTypeImage)
	{
		[item setCustomValue:item.title forKey:@"status"];
	}
	
	else if (item.shareType == SHKShareTypeText)
	{
		[item setCustomValue:item.text forKey:@"status"];
	}
    
    return result;
}

#pragma mark -
#pragma mark Authorization

- (BOOL)isAuthorized
{		
	return [self restoreAccessToken];
}

- (void)promptAuthorization
{		
	if (xAuth)
		[super authorizationFormShow]; // xAuth process
	
	else
		[super promptAuthorization]; // OAuth process		
}

+ (void)logout {
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSHKTwitterUserInfo];
    [super logout];    
}

#pragma mark xAuth

+ (NSString *)authorizationFormCaption
{
	return SHKLocalizedString(@"Create a free account at %@", @"Twitter.com");
}

+ (NSArray *)authorizationFormFields
{
	if ([SHKCONFIG(twitterUsername) isEqualToString:@""])
		return [super authorizationFormFields];
	
	return [NSArray arrayWithObjects:
			[SHKFormFieldSettings label:SHKLocalizedString(@"Username") key:@"username" type:SHKFormFieldTypeTextNoCorrect start:nil],
			[SHKFormFieldSettings label:SHKLocalizedString(@"Password") key:@"password" type:SHKFormFieldTypePassword start:nil],
			[SHKFormFieldSettings label:SHKLocalizedString(@"Follow %@", SHKCONFIG(twitterUsername)) key:@"followMe" type:SHKFormFieldTypeSwitch start:SHKFormFieldSwitchOn],			
			nil];
}

- (void)authorizationFormValidate:(SHKFormController *)form
{
	self.pendingForm = form;
	[self tokenAccess];
}

- (void)tokenAccessModifyRequest:(OAMutableURLRequest *)oRequest
{	
	if (xAuth)
	{
		NSDictionary *formValues = [pendingForm formValues];
		
		OARequestParameter *username = [[[OARequestParameter alloc] initWithName:@"x_auth_username"
																		   value:[formValues objectForKey:@"username"]] autorelease];
		
		OARequestParameter *password = [[[OARequestParameter alloc] initWithName:@"x_auth_password"
																		   value:[formValues objectForKey:@"password"]] autorelease];
		
		OARequestParameter *mode = [[[OARequestParameter alloc] initWithName:@"x_auth_mode"
																	   value:@"client_auth"] autorelease];
		
		[oRequest setParameters:[NSArray arrayWithObjects:username, password, mode, nil]];
	}
}

- (void)tokenAccessTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{
	if (xAuth) 
	{
		if (ticket.didSucceed)
		{
			[item setCustomValue:[[pendingForm formValues] objectForKey:@"followMe"] forKey:@"followMe"];
			[pendingForm close];
		}
		
		else
		{
			NSString *response = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			
			SHKLog(@"tokenAccessTicket Response Body: %@", response);
			
			[self tokenAccessTicket:ticket didFailWithError:[SHK error:response]];
			return;
		}
	}
	
	[super tokenAccessTicket:ticket didFinishWithData:data];		
}


#pragma mark -
#pragma mark UI Implementation

- (void)show
{
	if (item.shareType == SHKShareTypeURL)
	{
		[self showTwitterForm];
	}
	
	else if (item.shareType == SHKShareTypeImage)
	{
		[self showTwitterForm];
	}
	
	else if (item.shareType == SHKShareTypeText)
	{
		[self showTwitterForm];
	}
    
    else if (item.shareType == SHKShareTypeUserInfo)
    {
        [self setQuiet:YES];
        [self tryToSend];
    }
}

- (void)showTwitterForm
{
	SHKTwitterForm *rootView = [[SHKTwitterForm alloc] initWithNibName:nil bundle:nil];	
	rootView.delegate = self;
	
	// force view to load so we can set textView text
	[rootView view];
	
	rootView.textView.text = [item customValueForKey:@"status"];
	rootView.hasAttachment = item.image != nil;
    self.navigationBar.tintColor = SHKCONFIG_WITH_ARGUMENT(barTintForView:,rootView);
	
	[self pushViewController:rootView animated:NO];
    [rootView release];
	
	[[SHK currentHelper] showViewController:self];	
}

- (void)sendForm:(SHKTwitterForm *)form
{	
	[item setCustomValue:form.textView.text forKey:@"status"];
	[self tryToSend];
}

#pragma mark -

- (BOOL)shortenURL
{	
	if (![SHK connected])
	{
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.title, [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] forKey:@"status"];
		return YES;
	}
	
	if (!quiet)
		[[SHKActivityIndicator currentIndicator] displayActivity:SHKLocalizedString(@"Shortening URL...")];
    
	[self retain];//must retain, because it is a delegate of shorten URL request
    
	self.request = [[[SHKRequest alloc] initWithURL:[NSURL URLWithString:[NSMutableString stringWithFormat:@"http://api.bit.ly/v3/shorten?login=%@&apikey=%@&longUrl=%@&format=txt",
																		 SHKCONFIG(bitLyLogin),
																		  SHKCONFIG(bitLyKey),																		  
																		  SHKEncodeURL(item.URL)
																		  ]]
											 params:nil
										   delegate:self
								 isFinishedSelector:@selector(shortenURLFinished:)
											 method:@"GET"
										  autostart:YES] autorelease];
    return NO;
}

- (void)shortenURLFinished:(SHKRequest *)aRequest
{
	[[SHKActivityIndicator currentIndicator] hide];
	
	NSString *result = [[aRequest getResult] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	
	if (result == nil || [NSURL URLWithString:result] == nil)
	{
		// TODO - better error message
		[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Shorten URL Error")
									 message:SHKLocalizedString(@"We could not shorten the URL.")
									delegate:nil
						   cancelButtonTitle:SHKLocalizedString(@"Continue")
						   otherButtonTitles:nil] autorelease] show];
		
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.text ? item.text : item.title, [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] forKey:@"status"];
	}
	
	else
	{		
		///if already a bitly login, use url instead
		if ([result isEqualToString:@"ALREADY_A_BITLY_LINK"])
			result = [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.text ? item.text : item.title, result] forKey:@"status"];
	}
	
	[super share];
    [self release];
}


#pragma mark -
#pragma mark Share API Methods

- (BOOL)validateItem
{
	if (self.item.shareType == SHKShareTypeUserInfo) {
        return YES;
    }
    
	NSString *status = [item customValueForKey:@"status"];
	return status != nil;
}

- (BOOL)validateItemAfterUserEdit {
    
    BOOL result = NO;
    
    BOOL isValid = [self validateItem];    
    NSString *status = [item customValueForKey:@"status"];
    
    if (isValid && status.length <= 140) {
        result = YES;
    }
    
    return result;
}

- (BOOL)send
{	
	// Check if we should send follow request too
	if (xAuth && [item customBoolForSwitchKey:@"followMe"])
		[self followMe];	
	
	if (![self validateItemAfterUserEdit])
		return NO;
	
	switch (item.shareType) {
            
        case SHKShareTypeImage:            
            [self sendImage];
            break;
            
        case SHKShareTypeUserInfo:            
            [self sendUserInfo];
            break;
            
        default:
            [self sendStatus];
            break;
    }
	
	// Notify delegate
	[self sendDidStart];	
	
	return YES;
}

- (void)sendUserInfo {
    
    OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://api.twitter.com/1/account/verify_credentials.json"]
																	consumer:consumer
																	   token:accessToken
																	   realm:nil
														   signatureProvider:nil];	
	[oRequest setHTTPMethod:@"GET"];
    OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
																						  delegate:self
																				 didFinishSelector:@selector(sendUserInfo:didFinishWithData:)
																				   didFailSelector:@selector(sendUserInfo:didFailWithError:)];		
	[fetcher start];
	[oRequest release];
}

- (void)sendUserInfo:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{	
	if (ticket.didSucceed) {
        
        NSError *error = nil;
        NSMutableDictionary *userInfo;
        if ([NSJSONSerialization class]) {
            userInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        } else {
            userInfo = [[NSString stringWithFormat:@"%@", data] JSONValue];
//            userInfo = [[JSONDecoder decoder] mutableObjectWithData:data error:&error];
        }    
        
        if (error) {
            SHKLog(@"Error when parsing json twitter user info request:%@", [error description]);
        }
        
        [self convertNSNullsToEmptyStrings:userInfo];
        [[NSUserDefaults standardUserDefaults] setObject:userInfo forKey:kSHKTwitterUserInfo];
        
        [self sendDidFinish];
        
    } else {
        
		[self handleUnsuccessfulTicket:data];
	}
}

- (void)sendUserInfo:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	[self sendDidFailWithError:error];
}

- (void)sendStatus
{
	OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://api.twitter.com/1/statuses/update.json"]
																	consumer:consumer
																	   token:accessToken
																	   realm:nil
														   signatureProvider:nil];
	
	[oRequest setHTTPMethod:@"POST"];
	
	OARequestParameter *statusParam = [[OARequestParameter alloc] initWithName:@"status"
																		 value:[item customValueForKey:@"status"]];
	NSArray *params = [NSArray arrayWithObjects:statusParam, nil];
	[oRequest setParameters:params];
	[statusParam release];
	
	OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
																						  delegate:self
																				 didFinishSelector:@selector(sendStatusTicket:didFinishWithData:)
																				   didFailSelector:@selector(sendStatusTicket:didFailWithError:)];	
	
	[fetcher start];
	[oRequest release];
}

- (void)sendStatusTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{	
	// TODO better error handling here
	
	if (ticket.didSucceed) 
		[self sendDidFinish];
	
	else
	{		
		[self handleUnsuccessfulTicket:data];
	}
}

- (void)sendStatusTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	[self sendDidFailWithError:error];
}

- (void)sendImage {
	
	NSURL *serviceURL = nil;
	if([item customValueForKey:@"profile_update"]){
		serviceURL = [NSURL URLWithString:@"http://api.twitter.com/1/account/update_profile_image.json"];
	} else {
		serviceURL = [NSURL URLWithString:@"https://api.twitter.com/1/account/verify_credentials.json"];
	}
	
	OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:serviceURL
																	consumer:consumer
																	   token:accessToken
																	   realm:@"http://api.twitter.com/"
														   signatureProvider:signatureProvider];
	[oRequest setHTTPMethod:@"GET"];
	
	if([item customValueForKey:@"profile_update"]){
		[oRequest prepare];
	} else {
		[oRequest prepare];
		
		NSDictionary * headerDict = [oRequest allHTTPHeaderFields];
		NSString * oauthHeader = [NSString stringWithString:[headerDict valueForKey:@"Authorization"]];
		
		[oRequest release];
		oRequest = nil;
		
		serviceURL = [NSURL URLWithString:@"http://img.ly/api/2/upload.xml"];
		oRequest = [[OAMutableURLRequest alloc] initWithURL:serviceURL
												   consumer:consumer
													  token:accessToken
													  realm:@"http://api.twitter.com/"
										  signatureProvider:signatureProvider];
		[oRequest setHTTPMethod:@"POST"];
		[oRequest setValue:@"https://api.twitter.com/1/account/verify_credentials.json" forHTTPHeaderField:@"X-Auth-Service-Provider"];
		[oRequest setValue:oauthHeader forHTTPHeaderField:@"X-Verify-Credentials-Authorization"];
	}
	
	CGFloat compression = 0.9f;
	NSData *imageData = UIImageJPEGRepresentation([item image], compression);
	
	// TODO
	// Note from Nate to creator of sendImage method - This seems like it could be a source of sluggishness.
	// For example, if the image is large (say 3000px x 3000px for example), it would be better to resize the image
	// to an appropriate size (max of img.ly) and then start trying to compress.
	
	while ([imageData length] > 700000 && compression > 0.1) {
		// NSLog(@"Image size too big, compression more: current data size: %d bytes",[imageData length]);
		compression -= 0.1;
		imageData = UIImageJPEGRepresentation([item image], compression);
		
	}
	
	NSString *boundary = @"0xKhTmLbOuNdArY";
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
	[oRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
	
	NSMutableData *body = [NSMutableData data];
	NSString *dispKey = @"";
	if([item customValueForKey:@"profile_update"]){
		dispKey = @"Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n";
	} else {
		dispKey = @"Content-Disposition: form-data; name=\"media\"; filename=\"upload.jpg\"\r\n";
	}
	
	
	[body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[dispKey dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[@"Content-Type: image/jpg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:imageData];
	[body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	
	if([item customValueForKey:@"profile_update"]){
		// no ops
	} else {
		[body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"message\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[[item customValueForKey:@"status"] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];	
	}
	
	[body appendData:[[NSString stringWithFormat:@"--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	
	// setting the body of the post to the reqeust
	[oRequest setHTTPBody:body];
	
	// Notify delegate
	[self sendDidStart];
	
	// Start the request
	OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
																						  delegate:self
																				 didFinishSelector:@selector(sendImageTicket:didFinishWithData:)
																				   didFailSelector:@selector(sendImageTicket:didFailWithError:)];	
	
	[fetcher start];
	
	
	[oRequest release];
}

- (void)sendImageTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
	// TODO better error handling here
	// NSLog([[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
	
	if (ticket.didSucceed) {
		// Finished uploading Image, now need to posh the message and url in twitter
		NSString *dataString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		NSRange startingRange = [dataString rangeOfString:@"<url>" options:NSCaseInsensitiveSearch];
		//NSLog(@"found start string at %d, len %d",startingRange.location,startingRange.length);
		NSRange endingRange = [dataString rangeOfString:@"</url>" options:NSCaseInsensitiveSearch];
		//NSLog(@"found end string at %d, len %d",endingRange.location,endingRange.length);
		
		if (startingRange.location != NSNotFound && endingRange.location != NSNotFound) {
			NSString *urlString = [dataString substringWithRange:NSMakeRange(startingRange.location + startingRange.length, endingRange.location - (startingRange.location + startingRange.length))];
			//NSLog(@"extracted string: %@",urlString);
			[item setCustomValue:[NSString stringWithFormat:@"%@ %@",[item customValueForKey:@"status"],urlString] forKey:@"status"];
			[self sendStatus];
		}
		
		
	} else {
		[self sendDidFailWithError:nil];
	}
}

- (void)sendImageTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error {
	[self sendDidFailWithError:error];
}


- (void)followMe
{
	// remove it so in case of other failures this doesn't get hit again
	[item setCustomValue:nil forKey:@"followMe"];
	
	OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://api.twitter.com/1/friendships/create/%@.json", SHKCONFIG(twitterUsername)]]
																	consumer:consumer
																	   token:accessToken
																	   realm:nil
														   signatureProvider:nil];
	
	[oRequest setHTTPMethod:@"POST"];
	
	OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
																						  delegate:nil // Currently not doing any error handling here.  If it fails, it's probably best not to bug the user to follow you again.
																				 didFinishSelector:nil
																				   didFailSelector:nil];	
	
	[fetcher start];
	[oRequest release];
}

#pragma mark -

- (void)handleUnsuccessfulTicket:(NSData *)data
{
    if (SHKDebugShowLogs)
        SHKLog(@"Twitter Send Status Error: %@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
    
    // CREDIT: Oliver Drobnik
    
    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];		
    
    // in case our makeshift parsing does not yield an error message
    NSString *errorMessage = @"Unknown Error";		
    
    NSScanner *scanner = [NSScanner scannerWithString:string];
    
    // skip until error message
    [scanner scanUpToString:@"\"error\":\"" intoString:nil];
    
    
    if ([scanner scanString:@"\"error\":\"" intoString:nil])
    {
        // get the message until the closing double quotes
        [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\""] intoString:&errorMessage];
    }
    
    
    // this is the error message for revoked access
    if ([errorMessage isEqualToString:@"Invalid / used nonce"] || [errorMessage isEqualToString:@"Could not authenticate with OAuth."])
    {
        [self sendDidFailShouldRelogin];
    }
    else 
    {
        NSError *error = [NSError errorWithDomain:@"Twitter" code:2 userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
        [self sendDidFailWithError:error];
    }
}

- (void)convertNSNullsToEmptyStrings:(NSMutableDictionary *)dict
{
    NSArray *responseObjectKeys = [dict allKeys];
    for (NSString *key in responseObjectKeys) {
        id object = [dict objectForKey:key];
        if (object == [NSNull null]) {
            [dict setObject:@"" forKey:key];
        }
        if ([object isKindOfClass:[NSDictionary class]]) {
            [self convertNSNullsToEmptyStrings:object];
        }
    }
}

@end
