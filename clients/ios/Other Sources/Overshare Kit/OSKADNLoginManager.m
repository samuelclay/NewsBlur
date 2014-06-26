//
//  OSKADNLoginManager.m
//  Overshare Kit
//
//  Based on code by Jamin Guy for Riposte http://alpha.app.net/jaminguy
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKADNLoginManager.h"

#import "ADNLogin.h"

typedef void(^OSKADNLoginCompletionBlock)(NSString *userID, NSString *token, NSError *error);

@interface OSKADNLoginManager ()
<
    ADNLoginDelegate
>

@property (strong, nonatomic) ADNLogin *adn;
@property (strong, nonatomic) NSMutableArray *completionBlocks;

@end

@implementation OSKADNLoginManager

+ (OSKADNLoginManager *)sharedInstance {
    static id sharedID;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedID = [[self alloc] init];
    });
    return sharedID;
}

- (id)init {
    self = [super init];
    if(self) {
        _completionBlocks = [[NSMutableArray alloc] init];
        self.adn = [ADNLogin sharedInstance];
        self.adn.delegate = self;
    }
    return self;
}

- (BOOL)appIsInstalled {
    return self.adn.loginAvailable;
}

- (BOOL)loginAvailable {
    return self.adn.loginAvailable;
}

- (void)loginWithScopes:(NSArray *)scopes withCompletion:(OSKADNLoginCompletionBlock)completion {
    [self.completionBlocks addObject:[completion copy]];
    self.adn.scopes = scopes;
    [self.adn login];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [self.adn openURL:url sourceApplication:sourceApplication annotation:annotation];
}

#pragma mark - ADNLoginDelegate

- (void)adnLoginDidSucceedForUserWithID:(NSString *)userID username:(NSString *)username token:(NSString *)accessToken {
    for (OSKADNLoginCompletionBlock completionBlock in self.completionBlocks) {
        completionBlock(userID, accessToken, nil);
    }
    [self.completionBlocks removeAllObjects];
}

- (void)adnLoginDidFailWithError:(NSError *)error {
    for (OSKADNLoginCompletionBlock completionBlock in self.completionBlocks) {
        completionBlock(nil, nil, error);
    }
    [self.completionBlocks removeAllObjects];
}

@end
