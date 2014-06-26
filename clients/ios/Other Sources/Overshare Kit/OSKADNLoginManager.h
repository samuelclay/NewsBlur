//
//  OSKADNLoginManager.h
//  Overshare Kit
//
//  Based on code by Jamin Guy for Riposte http://alpha.app.net/jaminguy
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class ADNLogin;

@interface OSKADNLoginManager : NSObject

@property (strong, nonatomic, readonly) ADNLogin *adn;

+ (OSKADNLoginManager *)sharedInstance;

- (void)loginWithScopes:(NSArray *)scopes withCompletion:(void (^)(NSString *userID, NSString *token, NSError *error))completion;
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;
- (BOOL)loginAvailable;

@end
