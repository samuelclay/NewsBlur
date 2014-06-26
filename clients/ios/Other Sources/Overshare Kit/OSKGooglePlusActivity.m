//
// Created by Peter Friese on 2/5/14.
//  Copyright (c) 2014 Google. All rights reserved.
//

#import "OSKGooglePlusActivity.h"

@import CoreMotion;

#import <GooglePlus/GooglePlus.h>
#import <GoogleOpenSource/GoogleOpenSource.h>

#import "OSKShareableContentItem.h"
#import "OSKApplicationCredential.h"
#import "NSString+OSKEmoji.h"
#import "OSKActivitiesManager.h"

static NSInteger OSKGooglePlusActivity_MaxCharacterCount = 6000;
static NSInteger OSKGooglePlusActivity_MaxUsernameLength = 20;
static NSInteger OSKGooglePlusActivity_MaxImageCount = 3;

@interface OSKGooglePlusActivity () <GPPSignInDelegate, GPPShareDelegate>
@property (strong, nonatomic) NSTimer *authenticationTimeoutTimer;
@property (assign, nonatomic) BOOL authenticationTimedOut;
@property (copy, nonatomic) OSKGenericAuthenticationCompletionHandler completionHandler;
@end

@implementation OSKGooglePlusActivity

@synthesize remainingCharacterCount = _remainingCharacterCount;

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
    }
    return self;
}

#pragma mark - Generic Authentication

- (BOOL)isAuthenticated {
    return [[GPPSignIn sharedInstance] authentication] != nil;
}

- (void)authenticate:(OSKGenericAuthenticationCompletionHandler)completion {
    [self setCompletionHandler:completion];
    [self startAuthenticationTimeoutTimer];

    GPPSignIn *signIn = [GPPSignIn sharedInstance];
    signIn.shouldFetchGooglePlusUser = YES;

    OSKApplicationCredential *appCredential = [[OSKActivitiesManager sharedInstance] applicationCredentialForActivityType:[self.class activityType]];
    signIn.clientID = appCredential.applicationKey;

    signIn.scopes = @[kGTLAuthScopePlusLogin];
    signIn.delegate = self;

    [signIn authenticate];
}

#pragma mark - Google Plus Sign In

- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth error:(NSError *)error {
    __weak OSKGooglePlusActivity *weakSelf = self;
    if (self.completionHandler && weakSelf.authenticationTimedOut == NO) {
        [weakSelf cancelAuthenticationTimeoutTimer];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionHandler((error == nil), error);
        });
    }
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_MicroblogPost;
}

+ (BOOL)isAvailable {
    return YES; // This is *in general*, not whether account access has been granted.
}

+ (NSString *)activityType {
    return OSKActivityType_API_GooglePlus;
}

+ (NSString *)activityName {
    return @"Google+";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"GooglePlus-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"GooglePlus-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"GooglePlus-Icon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_Generic;
}

+ (BOOL)requiresApplicationCredential {
    return YES;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    BOOL accountPresent = ([[GPPSignIn sharedInstance] authentication] != nil);

    NSInteger maxCharacterCount = [self maximumCharacterCount];
    BOOL textIsValid = (0 <= self.remainingCharacterCount && self.remainingCharacterCount < maxCharacterCount);

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
    self.activityCompletionHandler = completion;
    [GPPShare sharedInstance].delegate = self;
    id <GPPNativeShareBuilder> shareDialog = [[GPPShare sharedInstance] nativeShareDialog];

    OSKMicroblogPostContentItem *item = (OSKMicroblogPostContentItem *)self.contentItem;
    [shareDialog setPrefillText:item.text];

    if (item.images != nil && item.images.count > 0) {
        for (UIImage *image in item.images) {
            [shareDialog attachImage:image];
        }
    }

    [shareDialog open];
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

#pragma mark - Microblogging Activity Protocol

- (NSInteger)maximumCharacterCount {
    return OSKGooglePlusActivity_MaxCharacterCount;
}

- (NSInteger)maximumImageCount {
    return OSKGooglePlusActivity_MaxImageCount;
}

- (OSKSyntaxHighlighting)syntaxHighlighting {
    return OSKSyntaxHighlighting_Links;
}

- (NSInteger)maximumUsernameLength {
    return OSKGooglePlusActivity_MaxUsernameLength;
}

#pragma mark - Authentication Timeout

- (void)startAuthenticationTimeoutTimer {
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:60*2]
                                              interval:0
                                                target:self
                                              selector:@selector(authenticationTimedOut:)
                                              userInfo:nil
                                               repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)cancelAuthenticationTimeoutTimer {
    [_authenticationTimeoutTimer invalidate];
    _authenticationTimeoutTimer = nil;
}

- (void)authenticationTimedOut:(NSTimer *)timer {
    [self setAuthenticationTimedOut:YES];
    if (self.completionHandler) {
        __weak OSKGooglePlusActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKGooglePlusActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Google+ authentication timed out."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}

#pragma mark - GPPShareDelegate

- (void)finishedSharingWithError:(NSError *)error {
    if (self.activityCompletionHandler) {
        self.activityCompletionHandler(self, error == nil, error);
    }
}

@end
