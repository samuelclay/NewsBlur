//
//  OSKReadabilityActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKReadabilityActivity.h"

#import "OSKActivitiesManager.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKManagedAccount.h"
#import "OSKShareableContentItem.h"
#import "OSKReadabilityUtility.h"

@interface OSKReadabilityActivity ()

@end

@implementation OSKReadabilityActivity

@synthesize activeManagedAccount = _activeManagedAccount;

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
    }
    return self;
}

#pragma mark - Managed Account Methods

+ (OSKManagedAccountAuthenticationViewControllerType)authenticationViewControllerType {
    return OSKManagedAccountAuthenticationViewControllerType_DefaultUsernamePasswordViewController;
}

- (void)authenticateNewAccountWithUsername:(NSString *)username password:(NSString *)password appCredential:(OSKApplicationCredential *)appCredential completion:(OSKManagedAccountAuthenticationHandler)completion {
    [OSKReadabilityUtility signIn:username password:password appCredential:appCredential completion:^(OSKManagedAccount *account, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(account, error);
            });
        }
    }];
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_ReadLater;
}

+ (BOOL)isAvailable {
    return YES;
}

+ (NSString *)activityType {
    return OSKActivityType_API_Readability;
}

+ (NSString *)activityName {
    return @"Readability";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"osk-readabilityIcon-60.png"];
    } else {
        image = [UIImage imageNamed:@"osk-readabilityIcon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"osk-readabilityIcon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_ManagedAccounts;
}

+ (BOOL)requiresApplicationCredential {
    return YES;
}

+ (OSKPublishingViewControllerType)publishingViewControllerType {
    return OSKPublishingViewControllerType_None;
}

- (BOOL)isReadyToPerform {
    return NO;
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKReadabilityActivity *weakSelf = self;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *URL = [weakSelf readLaterItem].url;
        [OSKReadabilityUtility saveURL:URL withAccountCredential:weakSelf.activeManagedAccount.credential appCredential:[weakSelf.class applicationCredential] completion:^(BOOL success, NSError *error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(weakSelf, success, error);
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            }
        }];
    });
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    OSKActivityOperation *op = nil;
    return op;
}
        
#pragma mark - Convenience

- (OSKReadLaterContentItem *)readLaterItem {
    return (OSKReadLaterContentItem *)self.contentItem;
}

@end




