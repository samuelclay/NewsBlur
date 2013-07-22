//
//  PocketAPILogin.m
//  iOS Test App
//
//  Created by Steve Streza on 7/23/12.
//  Copyright (c) 2012 Read It Later, Inc. All rights reserved.
//

#import "PocketAPILogin.h"
#import "PocketAPIOperation.h"

const NSString *PocketAPIErrorDomain = @"PocketAPIErrorDomain";

const NSString *PocketAPILoginStartedNotification = @"PocketAPILoginStartedNotification";
const NSString *PocketAPILoginFinishedNotification = @"PocketAPILoginFinishedNotification";
const NSString *PocketAPILoginFailedNotification = @"PocketAPILoginFailedNotification";

@interface PocketAPIOperation (Private)

-(void)pkt_setBaseURLPath:(NSString *)baseURLPath;

@end

@interface PocketAPILogin (Private)

-(void)loginDidStart;
-(void)loginDidFinish:(BOOL)success;

-(void)_setReverseAuth:(BOOL)isReverseAuth;

@end

@implementation PocketAPILogin

@synthesize API, uuid, requestToken, accessToken;

-(void)encodeWithCoder:(NSCoder *)aCoder{
	[aCoder encodeObject:self.requestToken forKey:@"requestToken"];
	[aCoder encodeObject:self.accessToken  forKey:@"accessToken" ];
	[aCoder encodeObject:self.uuid         forKey:@"uuid"        ];
}

-(id)initWithCoder:(NSCoder *)aDecoder{
	if(self = [self init]){
		requestToken = [[aDecoder decodeObjectForKey:@"requestToken"] retain];
		accessToken  = [[aDecoder decodeObjectForKey:@"accessToken" ] retain];
		uuid         = [[aDecoder decodeObjectForKey:@"uuid"        ] retain];
	}
	return self;
}

-(void)_setRequestToken:(NSString *)aRequestToken{
	[self willChangeValueForKey:@"requestToken"];
	[requestToken autorelease];
	requestToken = [aRequestToken copy];
	[self  didChangeValueForKey:@"requestToken"];
}

-(void)_setReverseAuth:(BOOL)isReverseAuth{
	reverseAuth = isReverseAuth;
}

-(void)openURL:(NSURL *)url{
#if TARGET_OS_IPHONE
	[[UIApplication sharedApplication] openURL:url];
#else
	[[NSWorkspace sharedWorkspace] openURL:url];
#endif
}

-(void)dealloc{
	[operationQueue waitUntilAllOperationsAreFinished];
	[operationQueue release], operationQueue = nil;
	
	[requestToken release], requestToken = nil;
	[accessToken  release], accessToken  = nil;
	[API release], API = nil;
	[delegate release], delegate = nil;
	
	[super dealloc];
}

-(id)init{
	if(self = [super init]){
		operationQueue = [[NSOperationQueue alloc] init];
		API = [[PocketAPI sharedAPI] retain];
		
		CFUUIDRef uuidRef = CFUUIDCreate(NULL);
		uuid = (NSString *)CFUUIDCreateString(NULL, uuidRef);
		CFRelease(uuidRef);
	}
	return self;
}

-(id)initWithAPI:(PocketAPI *)newAPI delegate:(id<PocketAPIDelegate>)aDelegate{
	if(self = [self init]){
		[newAPI retain];
		[API release];
		API = newAPI;
		
		delegate = [aDelegate retain];
	}
	return self;
}

-(NSURL *)redirectURL{
	return [NSURL URLWithString:[NSString stringWithFormat:@"%@:authorizationFinished", [self.API URLScheme]]];
}

-(void)fetchRequestToken{
	[self loginDidStart];
	
	PocketAPIOperation *operation = [[PocketAPIOperation alloc] init];
	operation.API = API;
	operation.delegate = self;
	operation.domain = PocketAPIDomainAuth;
	operation.HTTPMethod = PocketAPIHTTPMethodPOST;
	operation.APIMethod = @"request";
	
	NSString *redirectURLPath = [[self redirectURL] absoluteString];
	
	operation.arguments = [NSDictionary dictionaryWithObjectsAndKeys:
						   self.uuid, @"state",
						   redirectURLPath, @"redirect_uri",
						   nil];
	[operationQueue addOperation:operation];
	[operation release];
}

-(void)convertRequestTokenToAccessToken{
	PocketAPIOperation *operation = [[PocketAPIOperation alloc] init];
	operation.API = API;
	operation.delegate = self;
	operation.domain = PocketAPIDomainAuth;
	operation.HTTPMethod = PocketAPIHTTPMethodPOST;
	operation.APIMethod = @"authorize";
	
	NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0];
	NSString *country = [[NSLocale currentLocale] objectForKey: NSLocaleCountryCode];
	int timeZone = round([[NSTimeZone systemTimeZone] secondsFromGMT] / 60);
	
	operation.arguments = [NSDictionary dictionaryWithObjectsAndKeys:
						   self.requestToken, @"code",
						   locale, @"locale",
						   country, @"country",
						   [NSString stringWithFormat:@"%i", timeZone], @"timezone",
						   nil];
	[operationQueue addOperation:operation];
	[operation release];
}

#pragma mark Pocket API Delegate

-(void)pocketAPI:(PocketAPI *)api receivedRequestToken:(NSString *)aRequestToken{
	[self _setRequestToken:aRequestToken];
	
	NSURL *authorizeURL = nil;
	NSString *encodedRedirectURLString = [PocketAPIOperation encodeForURL:[[self redirectURL] absoluteString]];
	if([PocketAPI hasPocketAppInstalled]){
		authorizeURL = [NSURL URLWithString:[NSString stringWithFormat:@"pocket-oauth-v1:///authorize?request_token=%@&redirect_uri=%@",requestToken, encodedRedirectURLString]];
	}else{
		authorizeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://getpocket.com/auth/authorize?request_token=%@&redirect_uri=%@",requestToken, encodedRedirectURLString]];
	}
	
	[self openURL:authorizeURL];
}

-(void)pocketAPILoggedIn:(PocketAPI *)api{
	if(delegate && [delegate respondsToSelector:@selector(pocketAPILoggedIn:)]){
		[delegate pocketAPILoggedIn:self.API];
	}
	
	[self loginDidFinish:YES];

	[delegate release], delegate = nil;
}

-(void)pocketAPI:(PocketAPI *)api hadLoginError:(NSError *)error{
	if(delegate && [delegate respondsToSelector:@selector(pocketAPI:hadLoginError:)]){
		[delegate pocketAPI:api hadLoginError:error];
	}
	
	[self loginDidFinish:NO];
	
	[delegate release], delegate = nil;
}

-(void)loginDidStart{
	if(!didStart){
		didStart = YES;
		
		if(delegate && [delegate respondsToSelector:@selector(pocketAPIDidStartLogin:)]){
			[delegate pocketAPIDidStartLogin:self.API];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)PocketAPILoginStartedNotification object:nil];
	}
}

-(void)loginDidFinish:(BOOL)success{
	if(!didFinish){
		didFinish = YES;
		
		if(delegate && [delegate respondsToSelector:@selector(pocketAPIDidFinishLogin:)]){
			[delegate pocketAPIDidFinishLogin:self.API];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)PocketAPILoginFinishedNotification object:nil];
		
		if(reverseAuth && [PocketAPI hasPocketAppInstalled]){
			NSString *responseURLString = [NSString stringWithFormat:@"%@://reverse/%@/%i",[PocketAPI pocketAppURLScheme], (success ? @"success" : @"failed"), (int)[self.API appID]];
			NSURL *responseURL = [NSURL URLWithString:responseURLString];
			[self openURL:responseURL];
		}
	}
}

@end
