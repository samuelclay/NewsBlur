    //
//  SHKReadItLater.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/8/10.

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

// SHOULD FUNCS - can these be implemented like dataSource and delegate on tableview?

#import "SHKConfiguration.h"
#import "SHKReadItLater.h"


/**
 Private helper methods
 */
@interface SHKReadItLater ()
- (void)authFinished:(SHKRequest *)aRequest;
- (void)sendFinished:(SHKRequest *)aRequest;
@end

@implementation SHKReadItLater


#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return @"Read It Later";
}

+ (BOOL)canShareURL
{
	return YES;
}


#pragma mark -
#pragma mark Configuration : Dynamic Enable

// Though manual sharing is supported (by changing removing this subclass), one tap to save is the ideal 'read later' behavior
- (BOOL)shouldAutoShare
{
	return YES; 
}



#pragma mark -
#pragma mark Authorization

+ (NSString *)authorizationFormCaption
{
	return SHKLocalizedString(@"Create a free account at %@", @"Readitlaterlist.com");
}

- (void)authorizationFormValidate:(SHKFormController *)form
{
	// Display an activity indicator
	if (!quiet)
		[[SHKActivityIndicator currentIndicator] displayActivity:SHKLocalizedString(@"Logging In...")];
	
	
	// Authorize the user through the server
	NSDictionary *formValues = [form formValues];
	
	NSString *params = [NSMutableString stringWithFormat:@"apikey=%@&username=%@&password=%@",
						SHKCONFIG(readItLaterKey),
						SHKEncode([formValues objectForKey:@"username"]),
						SHKEncode([formValues objectForKey:@"password"])
						];
	
	self.request = [[[SHKRequest alloc] initWithURL:[NSURL URLWithString:@"http://readitlaterlist.com/v2/auth"]
								 params:params
							   delegate:self
					 isFinishedSelector:@selector(authFinished:)
								 method:@"POST"
							  autostart:YES] autorelease];
	
	self.pendingForm = form;
}

- (void)authFinished:(SHKRequest *)aRequest
{		
	// Hide the activity indicator
	[[SHKActivityIndicator currentIndicator] hide];
	
	if (aRequest.success)
		[pendingForm saveForm];
	
	else
	{
		[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Login Error")
									 message:[request.headers objectForKey:@"X-Error"]
									delegate:nil
						   cancelButtonTitle:SHKLocalizedString(@"Close")
						   otherButtonTitles:nil] autorelease] show];
	}
	[self authDidFinish:aRequest.success];
}



#pragma mark -
#pragma mark Share Form

- (NSArray *)shareFormFieldsForType:(SHKShareType)type
{	
	if (type == SHKShareTypeURL)
		return [NSArray arrayWithObjects:
				[SHKFormFieldSettings label:SHKLocalizedString(@"Title") key:@"title" type:SHKFormFieldTypeText start:item.title],
				[SHKFormFieldSettings label:SHKLocalizedString(@"Tags") key:@"tags" type:SHKFormFieldTypeText start:item.tags],
				nil];
	
	return nil;
}


#pragma mark -
#pragma mark Share API Methods

- (BOOL)send
{		
	if ([self validateItem])
	{	
		NSString *new = [NSString stringWithFormat:@"&new={\"0\":{\"url\":\"%@\",\"title\":\"%@\"}}",
						 SHKEncodeURL(item.URL),
						 SHKEncode(item.title)];
		
		NSString *tags = item.tags == nil || !item.tags.length ? @"" :
		[NSString stringWithFormat:@"&update_tags={\"0\":{\"url\":\"%@\",\"tags\":\"%@\"}}",
						  SHKEncodeURL(item.URL), SHKEncode(item.tags)];
		
		NSString *params = [NSMutableString stringWithFormat:@"apikey=%@&username=%@&password=%@%@%@",
									SHKCONFIG(readItLaterKey),
							SHKEncode([self getAuthValueForKey:@"username"]),
							SHKEncode([self getAuthValueForKey:@"password"]),
							new,
							tags];
		
		self.request = [[[SHKRequest alloc] initWithURL:[NSURL URLWithString:@"http://readitlaterlist.com/v2/send"]
									 params:params
								   delegate:self
						 isFinishedSelector:@selector(sendFinished:)
									 method:@"POST"
								  autostart:YES] autorelease];
		
		
		// Notify delegate
		[self sendDidStart];
		
		return YES;
	}
	
	return NO;
}

- (void)sendFinished:(SHKRequest *)aRequest
{		
	if (!aRequest.success)
	{
		if (aRequest.response.statusCode == 401)
		{
			[self sendDidFailShouldRelogin];
			return;
		}
		
		[self sendDidFailWithError:[SHK error:[request.headers objectForKey:@"X-Error"]]];
		return;
	}

	[self sendDidFinish];
}



@end
