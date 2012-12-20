//
//  DefaultSHKConfigurationDelegate.h
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

/*
 Debugging
 ------
 To show ShareKit specific debug output in the console, define _SHKDebugShowLogs (uncomment next line).
 */
//#define _SHKDebugShowLogs

#ifdef _SHKDebugShowLogs
#define SHKDebugShowLogs			1
#define SHKLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define SHKDebugShowLogs			0
#define SHKLog( s, ... )
#endif

#import <Foundation/Foundation.h>

@interface DefaultSHKConfigurator : NSObject 

- (NSString*)appName;
- (NSString*)appURL;
- (NSString*)deliciousConsumerKey;
- (NSString*)deliciousSecretKey;
- (NSString*)facebookAppId;
- (NSString*)facebookLocalAppId;
- (NSString*)readItLaterKey;
- (NSString*)twitterConsumerKey;
- (NSString*)twitterSecret;
- (NSString*)twitterCallbackUrl;
- (NSNumber*)twitterUseXAuth;
- (NSString*)twitterUsername;
- (NSString*)evernoteUserStoreURL;
- (NSString*)evernoteNetStoreURLBase;
- (NSString*)evernoteConsumerKey;
- (NSString*)evernoteSecret;
- (NSString*)flickrConsumerKey;
- (NSString*)flickrSecretKey;
- (NSString*)flickrCallbackUrl;
- (NSString*)bitLyLogin;
- (NSString*)bitLyKey;
- (NSNumber*)shareMenuAlphabeticalOrder;
- (NSNumber*)sharedWithSignature;
- (NSString*)barStyle;
- (UIColor*)barTintForView:(UIViewController*)vc;
- (NSNumber*)formFontColorRed;
- (NSNumber*)formFontColorGreen;
- (NSNumber*)formFontColorBlue;
- (NSNumber*)formBgColorRed;
- (NSNumber*)formBgColorGreen;
- (NSNumber*)formBgColorBlue;
- (NSString*)modalPresentationStyle;
- (NSString*)modalTransitionStyle;
- (NSNumber*)maxFavCount;
- (NSString*)favsPrefixKey;
- (NSString*)authPrefix;
- (NSString*)sharersPlistName;
- (NSNumber*)allowOffline;
- (NSNumber*)allowAutoShare;
- (NSNumber*)usePlaceholders;

@end
