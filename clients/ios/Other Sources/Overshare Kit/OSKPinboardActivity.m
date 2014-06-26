//
//  OSKPinboardActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKPinboardActivity.h"

#import "OSKShareableContentItem.h"
#import "OSKPinboardUtility.h"
#import "OSKManagedAccount.h"
#import "OSKManagedAccountCredential.h"

@implementation OSKPinboardActivity

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
    return OSKUsernameNomenclature_Username;
}

- (void)authenticateNewAccountWithUsername:(NSString *)username password:(NSString *)password appCredential:(OSKApplicationCredential *)appCredential completion:(OSKManagedAccountAuthenticationHandler)completion {
    [OSKPinboardUtility signIn:username password:password completion:^(OSKManagedAccount *account, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(account, error);
            });
        }
    }];
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_LinkBookmark;
}

+ (BOOL)isAvailable {
    return YES;
}

+ (NSString *)activityType {
    return OSKActivityType_API_Pinboard;
}

+ (NSString *)activityName {
    return @"Pinboard";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"osk-pinboardIcon-60.png"];
    } else {
        image = [UIImage imageNamed:@"osk-pinboardIcon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"osk-pinboardIcon-29.png"];
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
    return ([self linkBookmarkItem].url.absoluteString.length > 0
            && self.activeManagedAccount.credential.accountID != nil
            && self.activeManagedAccount.credential.token != nil);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKPinboardActivity *weakSelf = self;
    [OSKPinboardUtility addBookmark:[self linkBookmarkItem] withAccountCredential:self.activeManagedAccount.credential completion:^(BOOL success, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(weakSelf, success, error);
            });
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

- (OSKLinkBookmarkContentItem *)linkBookmarkItem {
    return (OSKLinkBookmarkContentItem *)self.contentItem;
}

@end


