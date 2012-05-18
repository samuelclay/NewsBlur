//
//  LegacySHKConfigurationDelegate.m
//  ShareKit
//
//  Created by Edward Dale on 10/16/10.

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

#import "LegacySHKConfigurator.h"
#import "SHKConfig.h"

@interface LegacySHKConfigurator ()

@property (readonly, retain) NSDictionary *configuration;

@end

@implementation LegacySHKConfigurator

@synthesize configuration;

- (void)dealloc 
{
    [configuration release];
}

- (id)init
{
    if ((self = [super init])) {
		configuration = [[NSDictionary alloc] initWithObjectsAndKeys:
						 SHKMyAppName, @"appName", 
						 SHKMyAppURL, @"appURL", 
						 SHKDeliciousConsumerKey, @"deliciousConsumerKey", 
						 SHKDeliciousSecretKey, @"deliciousSecretKey",
                         [NSNumber numberWithBool:SHKFacebookUseSessionProxy], @"facebookUseSessionProxy",
						 SHKFacebookAppID, @"facebookAppId",
						 SHKFacebookLocalAppID, @"facebookLocalAppId",
                         SHKFacebookSessionProxyURL, @"facebookSessionProxyURL",
						 SHKReadItLaterKey, @"readItLaterKey", 
						 SHKTwitterConsumerKey, @"twitterConsumerKey", 
						 SHKTwitterSecret, @"twitterSecret", 
						 SHKTwitterCallbackUrl, @"twitterCallbackUrl", 
						 [NSNumber numberWithInt:SHKTwitterUseXAuth], @"twitterUseXAuth", 
						 SHKTwitterUsername, @"twitterUsername", 
						 SHKEvernoteUserStoreURL, @"evernoteUserStoreURL", 
						 SHKEvernoteNetStoreURLBase, @"evernoteNetStoreURLBase", 
						 SHKEvernoteConsumerKey, @"evernoteConsumerKey", 
						 SHKEvernoteSecretKey, @"evernoteSecret", 
						 SHKFlickrConsumerKey, @"flickrConsumerKey", 
						 SHKFlickrSecretKey, @"flickrSecretKey", 
						 SHKFlickrCallbackUrl, @"flickrCallbackUrl", 
						 SHKBitLyLogin, @"bitLyLogin",
                         SHKBitLyKey, @"bitLyKey", 
						 [NSNumber numberWithInt:SHKShareMenuAlphabeticalOrder], @"shareMenuAlphabeticalOrder", 
						 [NSNumber numberWithInt:SHKSharedWithSignature], @"sharedWithSignature", 
						 SHKBarStyle, @"barStyle", 
						 [NSNumber numberWithInt:SHKBarTintColorRed], @"barTintColorRed", 
						 [NSNumber numberWithInt:SHKBarTintColorGreen], @"barTintColorGreen", 
						 [NSNumber numberWithInt:SHKBarTintColorBlue], @"barTintColorBlue", 
						 [NSNumber numberWithInt:SHKFormFontColorRed], @"formFontColorRed", 
						 [NSNumber numberWithInt:SHKFormFontColorGreen], @"formFontColorGreen", 
						 [NSNumber numberWithInt:SHKFormFontColorBlue], @"formFontColorBlue", 
						 [NSNumber numberWithInt:SHKFormBgColorRed], @"formBgColorRed", 
						 [NSNumber numberWithInt:SHKFormBgColorGreen], @"formBgColorGreen", 
						 [NSNumber numberWithInt:SHKFormBgColorBlue], @"formBgColorBlue", 
						 SHKModalPresentationStyle, @"modalPresentationStyle", 
						 SHKModalTransitionStyle, @"modalTransitionStyle", 
						 [NSNumber numberWithInt:SHK_MAX_FAV_COUNT], @"maxFavCount", 
						 SHK_FAVS_PREFIX_KEY, @"favsPrefixKey", 
						 SHK_AUTH_PREFIX, @"authPrefix", 
						 SHKSSharersPlistName, @"sharersPlistName",
						 [NSNumber numberWithInt:SHK_ALLOW_OFFLINE], @"allowOffline", 
						 [NSNumber numberWithInt:SHK_ALLOW_AUTOSHARE], @"allowAutoShare", 
						 [NSNumber numberWithInt:SHKUsePlaceholders], @"usePlaceholders", 
						 nil];
	}
	
	if(SHKDebugShowLogs) {
		SHKLog(@"Legacy configuration: %@", configuration);
	}

    return self;	
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	BOOL implementsSuper = [super respondsToSelector:aSelector];
    BOOL implementedHere = ([self.configuration objectForKey:NSStringFromSelector(aSelector)] != nil);
	return  implementsSuper|| implementedHere;
}

- (id) performSelector:(SEL)aSelector
{
	id configValue = [self.configuration objectForKey:NSStringFromSelector(aSelector)];
	if(configValue == nil) {
		return [super performSelector:aSelector];
	} else {
		return configValue;
	}
}
@end
