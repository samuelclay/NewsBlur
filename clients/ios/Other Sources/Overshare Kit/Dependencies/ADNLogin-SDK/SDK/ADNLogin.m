//
//  ADNLogin.m
//  ADNSDK
//
//  Created by Bryan Berg on 3/28/13.
//  Copyright (c) 2013 Mixed Media Labs, Inc. All rights reserved.
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

#import "ADNLogin.h"


#ifndef ADNLOGIN_SDK_SCHEME
	#define ADNLOGIN_SDK_SCHEME @""
#endif

#define kADNLoginShortPollingDuration 30.0
#define kADNLoginLongPollingDuration 300.0

#define kADNLoginPollingInterval 1.0

static NSString *const kADNLoginSDKScheme = ADNLOGIN_SDK_SCHEME;
static NSString *const kADNLoginURLNamePrefix = @"net.app.client.";
static NSString *const kADNLoginSDKVersion = @"2.0.0";

static NSString *const kADNLoginAppInstallURLTemplate = @"itms-apps://itunes.apple.com/us/app/id%@";
static NSString *const kADNLoginAppInstalliTunesID = @"534414475";


static NSString *queryStringEscape(NSString *string, NSStringEncoding encoding) {
	static NSString *const kAFCharactersToBeEscaped = @":/?&=;+!@#$()~',*";
	static NSString *const kAFCharactersToLeaveUnescaped = @"[].";

	return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kAFCharactersToLeaveUnescaped, (__bridge CFStringRef)kAFCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(encoding));
}

static NSString *queryStringForParameters(NSDictionary *parameters) {
	NSMutableArray *a = [NSMutableArray arrayWithCapacity:[parameters count]];
	[parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if (obj == [NSNull null]) {
			return;
		}

		if ([obj isKindOfClass:[NSValue class]]) {
			obj = [obj stringValue];
		}

		if (![obj isKindOfClass:[NSString class]]) {
			return;
		}

		if ([obj length]) {
			[a addObject:[NSString stringWithFormat:@"%@=%@",
						  queryStringEscape(key, NSUTF8StringEncoding),
						  queryStringEscape(obj, NSUTF8StringEncoding)]];
		}
	}];

	return [a componentsJoinedByString:@"&"];
}

static NSDictionary *parametersForQueryString(NSString *queryString) {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	NSArray *items = [queryString componentsSeparatedByString:@"&"];
	for (NSString *item in items) {
		NSArray *keyAndValue = [item componentsSeparatedByString:@"="];
		if (keyAndValue.count == 2) {
			NSString *key = [keyAndValue[0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			NSString *value = [keyAndValue[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

			parameters[key] = value;
		}
	}

	return parameters;
}


@interface ADNLogin ()

@property (strong, nonatomic) NSString *clientID;
@property (assign, nonatomic) int64_t appPK;
@property (strong, nonatomic) NSString *primaryScheme;
@property (strong, nonatomic) NSString *schemeSuffix;

@property (assign, atomic, getter=isPolling) BOOL polling;

- (NSString *)findLoginSchemeWithSuffix:(NSString *)suffix forStoreDetection:(BOOL)forStoreDetection;
- (void)beginPollingWithDuration:(NSTimeInterval)duration;

@end


@implementation ADNLogin

+ (instancetype)sharedInstance {
	static ADNLogin *sharedInstance;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[[self class] alloc] init];
	});

	return sharedInstance;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		self.clientID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"ADNLoginClientID"];
		self.scopes = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"ADNLoginScopes"] componentsSeparatedByString:@","];

		NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
		for (NSDictionary *urlType in urlTypes) {
			NSString *urlName = urlType[@"CFBundleURLName"];
			if ([urlName hasPrefix:kADNLoginURLNamePrefix]) {
				self.clientID = [urlName substringFromIndex:[kADNLoginURLNamePrefix length]];
			}

			for (NSString *urlScheme in urlType[@"CFBundleURLSchemes"]) {
				NSString *suffix;
				int64_t appPK;

				NSScanner *schemeScanner = [NSScanner scannerWithString:urlScheme];
				if (![schemeScanner scanString:@"adn" intoString:NULL]) {
					continue;
				}

				// possibly scan over "dev"
				[schemeScanner scanString:kADNLoginSDKScheme intoString:NULL];


				if (![schemeScanner scanLongLong:&appPK] || appPK <= 0) {
					continue;
				}

				[schemeScanner scanCharactersFromSet:[NSCharacterSet lowercaseLetterCharacterSet]
										  intoString:&suffix];

				if (![schemeScanner isAtEnd]) {
					continue;
				}

				// if we got here, this could be a URL scheme for login
				self.primaryScheme = urlScheme;
				self.appPK = appPK;
				self.schemeSuffix = suffix;
			}
		}

		if (self.appPK <= 0 || !self.clientID.length || !self.primaryScheme.length) {
			[NSException raise:@"ADNLogin requires the app register for a URL scheme in the format 'adnNNNNsuffix'" format:nil];
		}
	}

	return self;
}

#pragma mark - URL Callbacks

- (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
	if ([url.scheme isEqualToString:self.primaryScheme]) {
		if (sourceApplication != nil && !([sourceApplication isEqualToString:@"net.app.moana"] || [sourceApplication hasPrefix:@"net.app.moana."])) {
			return NO;
		}

		NSDictionary *parameters = parametersForQueryString(url.fragment);

		if ([url.host isEqualToString:@"return"]) {
			NSString *accessToken = parameters[@"access_token"];
			NSString *userID = parameters[@"user_id"];
			NSString *username = parameters[@"username"];
			NSString *errorMessage = parameters[@"error"];

			if (accessToken) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if ([self.delegate respondsToSelector:@selector(adnLoginDidSucceedForUserWithID:username:token:)]) {
						[self.delegate adnLoginDidSucceedForUserWithID:userID username:username token:accessToken];
					}
				});
			} else if (errorMessage) {
				NSError *error = [NSError errorWithDomain:kADNLoginErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: errorMessage}];

				dispatch_async(dispatch_get_main_queue(), ^{
					if ([self.delegate respondsToSelector:@selector(adnLoginDidFailWithError:)]) {
						[self.delegate adnLoginDidFailWithError:error];
					}
				});
			}
		}

		return YES;
	}

	return NO;
}

#pragma mark - Launching Passport

- (BOOL)canOpenURLWithScheme:(NSString *)scheme {
	return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://test-install", scheme]]];
}

- (NSString *)findLoginSchemeWithSuffix:(NSString *)suffix forStoreDetection:(BOOL)forStoreDetection {
	NSArray *schemes;

	if (forStoreDetection) {
		schemes = @[@""];
	} else if (kADNLoginSDKScheme.length) {
		schemes = @[kADNLoginSDKScheme];
	} else {
		schemes = @[@"beta", @""];
	}

	for (NSString *scheme in schemes) {
		NSString *fullScheme = [NSString stringWithFormat:@"adnlogin%@%@", scheme, suffix ?: @""];
		if ([self canOpenURLWithScheme:fullScheme]) {
			return fullScheme;
		}
	}

	return nil;
}

- (BOOL)isLoginAvailable {
	return [self findLoginSchemeWithSuffix:nil forStoreDetection:YES] != nil;
}

- (BOOL)isFindFriendsActionAvailable {
	return [self findLoginSchemeWithSuffix:@"ff" forStoreDetection:NO] != nil;
}

- (BOOL)login {
	NSString *scheme = [self findLoginSchemeWithSuffix:nil forStoreDetection:NO];

	NSDictionary *parameters = @{
		@"client_id": self.clientID,
		@"app_pk": @(self.appPK),
		@"suffix": self.schemeSuffix ?: [NSNull null],
		@"scope": [self.scopes componentsJoinedByString:@" "] ?: @"",
		@"sdk_version": kADNLoginSDKVersion,
	};

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://token?%@", scheme, queryStringForParameters(parameters)]];
	return [[UIApplication sharedApplication] openURL:url];
}

- (BOOL)launchFindFriends {
	return [self launchFindFriendsAction:@"find-friends"];
}

- (BOOL)launchRecommendedUsers {
	return [self launchFindFriendsAction:@"recommended"];
}

- (BOOL)launchInviteFriends {
	return [self launchFindFriendsAction:@"invite/send"];
}

- (BOOL)launchFindFriendsAction:(NSString *)action {
	NSString *scheme = [self findLoginSchemeWithSuffix:@"ff" forStoreDetection:NO];

	NSDictionary *parameters = @{
		@"client_id": self.clientID,
		@"app_pk": @(self.appPK),
		@"suffix": self.schemeSuffix ?: [NSNull null],
		@"sdk_version": kADNLoginSDKVersion,
	};

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@?%@", scheme, action, queryStringForParameters(parameters)]];
	return [[UIApplication sharedApplication] openURL:url];
}

- (BOOL)openStoreForPassport {
	NSURL *installURL = [NSURL URLWithString:[NSString stringWithFormat:kADNLoginAppInstallURLTemplate, kADNLoginAppInstalliTunesID]];
	if ([[UIApplication sharedApplication] openURL:installURL]) {
		[self beginPollingWithDuration:kADNLoginLongPollingDuration];

		return YES;
	}

	return NO;
}

#pragma mark - Delegate calls

- (BOOL)willBeginPolling {
	[[NSNotificationCenter defaultCenter] postNotificationName:kADNLoginWillBeginPollingNotification object:nil userInfo:nil];

	return !([self.delegate respondsToSelector:@selector(adnLoginWillBeginPolling)] && [self.delegate adnLoginWillBeginPolling]);
}

- (BOOL)didEndPollingWithSuccess:(BOOL)success {
	[[NSNotificationCenter defaultCenter] postNotificationName:kADNLoginDidEndPollingNotification object:nil userInfo:@{@"success": @(success)}];

	return !([self.delegate respondsToSelector:@selector(adnLoginDidEndPollingWithSuccess:)] && [self.delegate adnLoginDidEndPollingWithSuccess:success]);
}

#ifdef __IPHONE_6_0

#pragma mark - StoreKit usage (iOS 6 SDK and higher)

- (SKStoreProductViewController *)passportProductViewControllerWithCompletionBlock:(ADNLoginStoreCompletionBlock)completionBlock {
	if ([SKStoreProductViewController class]) {
		// if already polling for Passport, stop
		[self cancelPolling];

		SKStoreProductViewController *storeController = [[SKStoreProductViewController alloc] init];
		NSDictionary *productInfo = @{SKStoreProductParameterITunesItemIdentifier: kADNLoginAppInstalliTunesID};
		storeController.delegate = self;

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[storeController loadProductWithParameters:productInfo completionBlock:^(BOOL result, NSError *error) {
				if (completionBlock) {
					completionBlock(storeController, result, error);
				}

				if (!result) {
					NSLog(@"[ADNLogin] Error loading product info: %@", error);

					[self didEndPollingWithSuccess:NO];
				}
			}];
		});

		return storeController;
	}

	return nil;
}

#pragma mark - SKStoreProductViewControllerDelegate

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
	[self beginPollingWithDuration:kADNLoginShortPollingDuration];

	// Do not dismiss if the delegate has been changed.
	if (viewController.delegate == self) {
		[viewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
	}
}

#endif

#pragma mark - Polling

- (void)beginPollingWithDuration:(NSTimeInterval)duration {
	if (self.polling) return;

	if (!([self.delegate respondsToSelector:@selector(adnLoginWillBeginPolling)] && [self.delegate adnLoginWillBeginPolling])) {
		dispatch_time_t timeoutTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC));
		dispatch_after(timeoutTime, dispatch_get_main_queue(), ^(void){
			[self cancelPolling];
			[self didEndPollingWithSuccess:NO];
		});

		self.polling = YES;
		[self enqueuePoll];
	}
}

- (void)enqueuePoll {
	if (!self.polling) return;

	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kADNLoginPollingInterval * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		BOOL isInstalled = 	[self findLoginSchemeWithSuffix:nil forStoreDetection:NO] != nil;

		if (self.polling) {
			if (isInstalled && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
				[self cancelPolling];

				if ([self didEndPollingWithSuccess:YES]) {
					[self login];
				}
			} else {
				[self enqueuePoll];
			}
		}
	});
}

- (void)cancelPolling {
	self.polling = NO;
}

@end
