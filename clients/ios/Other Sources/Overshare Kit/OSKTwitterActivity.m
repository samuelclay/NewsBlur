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
#import "OSKTwitterText.h"
#import "NSString+OSKEmoji.h"

static NSInteger OSKTwitterActivity_MaxCharacterCount = 140;
static NSInteger OSKTwitterActivity_MaxUsernameLength = 20;
static NSInteger OSKTwitterActivity_MaxImageCount = 1;
static NSInteger OSKTwitterActivity_FallbackShortURLEstimate = 24;

@interface OSKTwitterActivity ()

@property (copy, nonatomic) NSNumber *estimatedShortURLLength_http;
@property (copy, nonatomic) NSNumber *estimatedShortURLLength_https;

@end

@implementation OSKTwitterActivity

@synthesize activeSystemAccount = _activeSystemAccount;
@synthesize remainingCharacterCount = _remainingCharacterCount;

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

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_ViewController_Microblogging;
}

- (BOOL)isReadyToPerform {

    BOOL accountPresent = (self.activeSystemAccount != nil);
    BOOL textIsValid = (0 <= self.remainingCharacterCount && self.remainingCharacterCount < [self maximumCharacterCount]);
    
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

- (NSInteger)maximumUsernameLength {
    return OSKTwitterActivity_MaxUsernameLength;
}

- (NSInteger)updateRemainingCharacterCount:(OSKMicroblogPostContentItem *)contentItem urlEntities:(NSArray *)urlEntities {
    
    NSString *text = contentItem.text;
    NSInteger estimatedShortURLLength_http = [self estimatedShortURLLength_http].integerValue;
    NSInteger estimatedShortURLLength_https = [self estimatedShortURLLength_https].integerValue;
    
    NSInteger textLengthAdjustmentForTCOLinks = 0;
    
    for (OSKTwitterTextEntity *entity in urlEntities) {
        NSString *urlText = [text substringWithRange:entity.range];
        NSUInteger composedLength = [urlText osk_lengthAdjustingForComposedCharacters];
        NSUInteger difference;
        if ([urlText rangeOfString:@"https://"].location == 0) {
            difference = estimatedShortURLLength_https - composedLength;
        } else {
            difference = estimatedShortURLLength_http - composedLength;
        }
        textLengthAdjustmentForTCOLinks += difference;
    }
    
    NSInteger composedLength = [text osk_lengthAdjustingForComposedCharacters];
    NSInteger reservedLengthForImageAttachment = (contentItem.images.count) ? estimatedShortURLLength_http : 0;
    NSInteger estimatedLength = composedLength + textLengthAdjustmentForTCOLinks + reservedLengthForImageAttachment;
    NSInteger remainingCharacterCount = [self maximumCharacterCount] - estimatedLength;
    
    [self setRemainingCharacterCount:remainingCharacterCount];
    
    return remainingCharacterCount;
}

- (OSKSyntaxHighlighting)syntaxHighlighting {
    return OSKSyntaxHighlighting_Usernames | OSKSyntaxHighlighting_Links | OSKSyntaxHighlighting_Hashtags;
}

- (BOOL)allowLinkShortening {
    // Twitter's API wraps all links in t.co links that count as 23/24 characters,
    // even short links. So there's no point in using a link shortening service.
    return NO;
}

#pragma mark - Updating Estimated Short URL Lengths

- (NSNumber *)estimatedShortURLLength_http {
    
    NSNumber *estimatedLength = nil;
    
    if (_estimatedShortURLLength_http != nil) {
        estimatedLength = _estimatedShortURLLength_http;
    } else {
        estimatedLength = @(OSKTwitterActivity_FallbackShortURLEstimate);
        __weak OSKTwitterActivity *weakSelf = self;
        [self updateOfficialShortURLLengths:^(NSInteger httpLength, NSInteger httpsLength, BOOL retrievedFromOfficialSource) {
            [weakSelf setEstimatedShortURLLength_http:@(httpLength)];
            [weakSelf setEstimatedShortURLLength_http:@(httpsLength)];
        }];
    }
    
    return estimatedLength;
}

- (NSNumber *)estimatedShortURLLength_https {
    
    NSNumber *estimatedLength = nil;
    
    if (_estimatedShortURLLength_https != nil) {
        estimatedLength = _estimatedShortURLLength_https;
    } else {
        estimatedLength = @(OSKTwitterActivity_FallbackShortURLEstimate);
        __weak OSKTwitterActivity *weakSelf = self;
        [self updateOfficialShortURLLengths:^(NSInteger httpLength, NSInteger httpsLength, BOOL retrievedFromOfficialSource) {
            [weakSelf setEstimatedShortURLLength_http:@(httpLength)];
            [weakSelf setEstimatedShortURLLength_http:@(httpsLength)];
        }];
    }
    
    return estimatedLength;
}

- (void)updateOfficialShortURLLengths:(void(^)(NSInteger httpLength, NSInteger httpsLength, BOOL retrievedFromOfficialSource))completion {
    if (self.activeSystemAccount) {
        [OSKTwitterUtility
         requestTwitterConfiguration:self.activeSystemAccount
         completion:^(NSError *error, NSDictionary *configurationParameters) {
            NSNumber *httpNumber = configurationParameters[OSKTwitterImageHttpURLLengthKey];
            CGFloat httpEstimate = (httpNumber.integerValue)
                                    ? httpNumber.integerValue
                                    : OSKTwitterActivity_FallbackShortURLEstimate;

             NSNumber *httpsNumber = configurationParameters[OSKTwitterImageHttpsURLLengthKey];
             CGFloat httpsEstimate = (httpsNumber.integerValue)
                                    ? httpsNumber.integerValue
                                    : OSKTwitterActivity_FallbackShortURLEstimate;

             if (completion) {
                completion(httpEstimate, httpsEstimate, (httpNumber != nil && httpsNumber != nil));
            }
        }];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(OSKTwitterActivity_FallbackShortURLEstimate, OSKTwitterActivity_FallbackShortURLEstimate, NO);
            }
        });
    }
}

@end




