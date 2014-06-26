//
//  OSKAppDotNetActivity.m
//  Overshare
//
//
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKInstapaperActivity.h"

#import "OSKActivitiesManager.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKManagedAccount.h"
#import "OSKShareableContentItem.h"
#import "OSKInstapaperUtility.h"

@interface OSKInstapaperActivity ()

@end

@implementation OSKInstapaperActivity

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

- (OSKUsernameNomenclature)usernameNomenclatureForSignInScreen {
    return OSKUsernameNomenclature_Email;
}

- (void)authenticateNewAccountWithUsername:(NSString *)username password:(NSString *)password appCredential:(OSKApplicationCredential *)appCredential completion:(OSKManagedAccountAuthenticationHandler)completion {
    [OSKInstapaperUtility createNewAccountWithUsername:username password:password completion:^(OSKManagedAccount *account, NSError *error) {
        if (completion) {
            completion(account, error);
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
    return OSKActivityType_API_Instapaper;
}

+ (NSString *)activityName {
    return @"Instapaper";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"Instapaper-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Instapaper-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"Instapaper-Icon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_ManagedAccounts;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    return ([self readLaterItem].url && self.activeManagedAccount.credential);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKInstapaperActivity *weakSelf = self;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    OSKReadLaterContentItem *readLaterItem = [self readLaterItem];
    [OSKInstapaperUtility saveURL:readLaterItem.url credential:self.activeManagedAccount.credential completion:^(BOOL success, NSError *error) {
        if (completion) {
            completion(self, success, error);
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
        }
    }];
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}
     
#pragma mark - Convenience
     
 - (OSKReadLaterContentItem *)readLaterItem {
     return (OSKReadLaterContentItem *)self.contentItem;
 }

@end






