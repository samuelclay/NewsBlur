//
//  OSKTwitterActivity.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Accounts;

#import "OSKTwitterActivity.h"
#import "OSKTwitterUtility.h"
#import "OSKMicrobloggingActivity.h"
#import "OSKShareableContentItem.h"

#import "OSKSystemAccountStore.h"
#import "OSKActivity_SystemAccounts.h"

static NSInteger OSKTwitterActivity_MaxCharacterCount = 140;
static NSInteger OSKTwitterActivity_MaxUsernameLength = 20;
static NSInteger OSKTwitterActivity_MaxImageCount = 1;

@interface OSKTwitterActivity ()

@end

@implementation OSKTwitterActivity

@synthesize activeSystemAccount = _activeSystemAccount;

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        //
    }
    return self;
}

#pragma mark - System Accounts

+ (NSString *)systemAccountTypeIdentifier {
    return ACAccountTypeIdentifierTwitter;
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_MicroblogPost;
}

+ (BOOL)isAvailable {
    return YES; // This is *in general*, not whether account access has been granted.
}

+ (NSString *)activityType {
    return OSKActivityType_iOS_Twitter;
}

+ (NSString *)activityName {
    return @"Twitter";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"osk-twitterIcon-60.png"];
    } else {
        image = [UIImage imageNamed:@"osk-twitterIcon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [self iconForIdiom:UIUserInterfaceIdiomPhone];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_SystemAccounts;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingViewControllerType)publishingViewControllerType {
    return OSKPublishingViewControllerType_Microblogging;
}

- (BOOL)isReadyToPerform {
    BOOL accountPresent = (self.activeSystemAccount != nil);
    
    OSKMicroblogPostContentItem *contentItem = (OSKMicroblogPostContentItem *)self.contentItem;
    NSInteger maxCharacterCount = [self maximumCharacterCount];
    BOOL textIsValid = (contentItem.text.length > 0 && contentItem.text.length <= maxCharacterCount);
    
    return (accountPresent && textIsValid);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKTwitterActivity *weakSelf = self;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    [OSKTwitterUtility
     postContentItem:(OSKMicroblogPostContentItem *)self.contentItem
     toSystemAccount:self.activeSystemAccount
     completion:^(BOOL success, NSError *error) {
         if (completion) {
             completion(weakSelf, (error == nil), error);
         }
         [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
     }];
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

#pragma mark - Microblogging Activity Protocol

- (NSInteger)maximumCharacterCount {
    return OSKTwitterActivity_MaxCharacterCount;
}

- (NSInteger)maximumImageCount {
    return OSKTwitterActivity_MaxImageCount;
}

- (OSKMicroblogSyntaxHighlightingStyle)syntaxHighlightingStyle {
    return OSKMicroblogSyntaxHighlightingStyle_Twitter;
}

- (NSInteger)maximumUsernameLength {
    return OSKTwitterActivity_MaxUsernameLength;
}

@end




