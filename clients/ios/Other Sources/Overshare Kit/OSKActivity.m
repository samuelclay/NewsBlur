//
//  OSKActivity.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivity.h"

#import "OSKActivitiesManager.h"
#import "OSKApplicationCredential.h"

// ACTIVITY OPTIONS
NSString * const OSKActivityOption_ExcludedTypes = @"OSKActivityOption_ExcludedTypes";
NSString * const OSKActivityOption_BespokeActivities = @"OSKActivityOption_BespokeActivities";
NSString * const OSKActivityOption_RequireOperations = @"OSKActivityOption_RequireOperations";

// ACTIVITY TYPES
NSString * const OSKActivityType_iOS_Twitter = @"OSKActivityType_iOS_Twitter";
NSString * const OSKActivityType_iOS_Facebook = @"OSKActivityType_iOS_Facebook";
NSString * const OSKActivityType_iOS_Safari = @"OSKActivityType_iOS_Safari";
NSString * const OSKActivityType_iOS_SMS = @"OSKActivityType_iOS_SMS";
NSString * const OSKActivityType_iOS_Email = @"OSKActivityType_iOS_Email";
NSString * const OSKActivityType_iOS_CopyToPasteboard = @"OSKActivityType_iOS_CopyToPasteboard";
NSString * const OSKActivityType_iOS_AirDrop = @"OSKActivityType_iOS_AirDrop";
NSString * const OSKActivityType_iOS_ReadingList = @"OSKActivityType_iOS_ReadingList";
NSString * const OSKActivityType_iOS_SaveToCameraRoll = @"OSKActivityType_iOS_SaveToCameraRoll";
NSString * const OSKActivityType_API_AppDotNet = @"OSKActivityType_API_AppDotNet";
NSString * const OSKActivityType_API_500Pixels = @"OSKActivityType_API_500Pixels";
NSString * const OSKActivityType_API_Instapaper = @"OSKActivityType_API_Instapaper";
NSString * const OSKActivityType_API_Readability = @"OSKActivityType_API_Readability";
NSString * const OSKActivityType_API_Pocket = @"OSKActivityType_API_Pocket";
NSString * const OSKActivityType_API_Pinboard = @"OSKActivityType_API_Pinboard";
NSString * const OSKActivityType_API_GooglePlus = @"OSKActivityType_API_GooglePlus";
NSString * const OSKActivityType_URLScheme_Instagram = @"OSKActivityType_URLScheme_Instagram";
NSString * const OSKActivityType_URLScheme_Riposte = @"OSKActivityType_URLScheme_Riposte";
NSString * const OSKActivityType_URLScheme_Tweetbot = @"OSKActivityType_URLScheme_Tweetbot";
NSString * const OSKActivityType_URLScheme_1Password_Search = @"OSKActivityType_URLScheme_1Password_Search";
NSString * const OSKActivityType_URLScheme_1Password_Browser = @"OSKActivityType_URLScheme_1Password_Browser";
NSString * const OSKActivityType_URLScheme_Chrome = @"OSKActivityType_URLScheme_Chrome";
NSString * const OSKActivityType_URLScheme_Omnifocus = @"OSKActivityType_URLScheme_Omnifocus";
NSString * const OSKActivityType_URLScheme_Things = @"OSKActivityType_URLScheme_Things";
NSString * const OSKActivityType_URLScheme_Drafts = @"OSKActivityType_URLScheme_Drafts";
NSString * const OSKActivityType_SDK_Pocket = @"OSKActivityType_SDK_Pocket";

@interface OSKActivity ()

@property (strong, nonatomic, readonly) OSKActivitiesManager *manager;
@property (strong, nonatomic, readwrite) OSKShareableContentItem *contentItem;

@end

@implementation OSKActivity

@synthesize manager = _manager;

#pragma mark - Initialization

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super init];
    if (self) {
        _contentItem = item;
    }
    return self;
}

#pragma mark - Do Not Override

+ (OSKApplicationCredential *)applicationCredential {
    return [[OSKActivitiesManager sharedInstance] applicationCredentialForActivityType:[self activityType]];
}

- (OSKActivitiesManager *)manager {
    if (_manager == nil) {
        _manager = [OSKActivitiesManager sharedInstance];
    }
    return _manager;
}

- (BOOL)requiresPurchase {
    return [self.manager activityTypeRequiresPurchase:[self.class activityType]];
}

- (BOOL)isAlreadyPurchased {
    return [self.manager activityTypeIsPurchased:[self.class activityType]];
}

#pragma mark - Methods for Subclasses

+ (NSString *)supportedContentItemType {
    NSAssert(NO, @"OSKActivity subclasses must override `supportedContentItemType` without calling super.");
    return nil;
}

+ (BOOL)isAvailable {
    NSAssert(NO, @"OSKActivity subclasses must override `isAvailable` without calling super.");
    return NO;
}

+ (NSString *)activityType {
    NSAssert(NO, @"OSKActivity subclasses must override `activityType` without calling super.");
    return nil;
}

+ (NSString *)activityName {
    NSAssert(NO, @"OSKActivity subclasses must override `activityName` without calling super.");
    return nil;
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    NSAssert(NO, @"OSKActivity subclasses must override `iconForIdiom:` without calling super.");
    return nil;
}

+ (UIImage *)settingsIcon {
    // Optional
    return nil;
}

+ (OSKAuthenticationMethod)authenticationMethod {
    NSAssert(NO, @"OSKActivity subclasses must override `authenticationMethod` without calling super.");
    return OSKAuthenticationMethod_None;
}

+ (BOOL)requiresApplicationCredential {
    NSAssert(NO, @"OSKActivity subclasses must override `requiresApplicationCredential` without calling super.");
    return NO;
}

+ (OSKPublishingMethod)publishingMethod {
    NSAssert(NO, @"OSKActivity subclasses must override `usesPublishingViewController` without calling super.");
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    NSAssert(NO, @"OSKActivity subclasses must override `isReadyToPerform` without calling super.");
    return NO;
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    NSAssert(NO, @"OSKActivity subclasses must override `performActivity:` without calling super.");
}

+ (BOOL)canPerformViaOperation {
    NSAssert(NO, @"OSKActivity subclasses must override `canPerformViaOperation` without calling super.");
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    NSAssert(NO, @"OSKActivity subclasses must override `operationForActivityWithCompletion:` without calling super.");
    return nil;
}

@end









