//
//  OSKFacebookActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Accounts;

#import "OSKFacebookActivity.h"
#import "OSKShareableContentItem.h"
#import "OSKFacebookUtility.h"
#import "OSKApplicationCredential.h"
#import "NSString+OSKEmoji.h"

static NSInteger OSKFacebookActivity_MaxCharacterCount = 6000;
static NSInteger OSKFacebookActivity_MaxUsernameLength = 20;
static NSInteger OSKFacebookActivity_MaxImageCount = 3;

@implementation OSKFacebookActivity

@synthesize activeSystemAccount = _activeSystemAccount;
@synthesize remainingCharacterCount = _remainingCharacterCount;

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        _currentAudience = ACFacebookAudienceEveryone;
    }
    return self;
}

#pragma mark - System Accounts

+ (NSString *)systemAccountTypeIdentifier {
    return ACAccountTypeIdentifierFacebook;
}

+ (NSDictionary *)readAccessRequestOptions {
    OSKApplicationCredential *appCredential = [self applicationCredential];
    return @{ACFacebookPermissionsKey:@[@"email"],
             ACFacebookAudienceKey:ACFacebookAudienceEveryone,
             ACFacebookAppIdKey:appCredential.applicationKey};
}

+ (NSDictionary *)writeAccessRequestOptions {
    OSKApplicationCredential *appCredential = [self applicationCredential];
    return @{ACFacebookPermissionsKey:@[@"publish_actions"],
             ACFacebookAudienceKey:ACFacebookAudienceEveryone,
             ACFacebookAppIdKey:appCredential.applicationKey};
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_MicroblogPost;
}

+ (BOOL)isAvailable {
    return YES; // This is *in general*, not whether account access has been granted.
}

+ (NSString *)activityType {
    return OSKActivityType_iOS_Facebook;
}

+ (NSString *)activityName {
    return @"Facebook";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"osk-facebookIcon-60.png"];
    } else {
        image = [UIImage imageNamed:@"osk-facebookIcon-76.png"];
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
    return YES;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_ViewController_Facebook;
}

- (BOOL)isReadyToPerform {
    BOOL accountPresent = (self.activeSystemAccount != nil);
    
    OSKMicroblogPostContentItem *contentItem = (OSKMicroblogPostContentItem *)[self contentItem];
    
    NSInteger maxCharacterCount = [self maximumCharacterCount];
    BOOL textIsValid = (0 <= self.remainingCharacterCount && self.remainingCharacterCount < maxCharacterCount && contentItem.text.length > 0);
    
    return (accountPresent && textIsValid);
}

- (NSInteger)updateRemainingCharacterCount:(OSKMicroblogPostContentItem *)contentItem urlEntities:(NSArray *)urlEntities {
    
    NSString *text = contentItem.text;
    NSInteger composedLength = [text osk_lengthAdjustingForComposedCharacters];
    NSInteger remainingCharacterCount = [self maximumCharacterCount] - composedLength;
    
    [self setRemainingCharacterCount:remainingCharacterCount];
    
    return remainingCharacterCount;
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKFacebookActivity *weakSelf = self;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    [OSKFacebookUtility postContentItem:(OSKMicroblogPostContentItem *)self.contentItem
                        toSystemAccount:self.activeSystemAccount
                                options:@{ACFacebookAudienceKey:[self currentAudience]}
                             completion:^(BOOL success, NSError *error) {
                                 if (completion) {
                                     completion(weakSelf, success, error);
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
    return OSKFacebookActivity_MaxCharacterCount;
}

- (NSInteger)maximumImageCount {
    return OSKFacebookActivity_MaxImageCount;
}

- (OSKMicroblogSyntaxHighlightingStyle)syntaxHighlightingStyle {
    return OSKMicroblogSyntaxHighlightingStyle_LinksOnly;
}

- (NSInteger)maximumUsernameLength {
    return OSKFacebookActivity_MaxUsernameLength;
}

@end
