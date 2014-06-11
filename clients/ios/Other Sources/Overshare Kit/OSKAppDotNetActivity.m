//
//  OSKAppDotNetActivity.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKAppDotNetActivity.h"
#import "OSKMicrobloggingActivity.h"

#import "OSKActivitiesManager.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKADNLoginManager.h"
#import "OSKAppDotNetUtility.h"
#import "OSKLogger.h"
#import "OSKManagedAccount.h"
#import "OSKShareableContentItem.h"
#import "NSString+OSKEmoji.h"

static NSInteger OSKAppDotNetActivity_MaxCharacterCount = 256;
static NSInteger OSKAppDotNetActivity_MaxUsernameLength = 20;
static NSInteger OSKAppDotNetActivity_MaxImageCount = 4;

@interface OSKAppDotNetActivity ()

@property (strong, nonatomic) NSTimer *authenticationTimeoutTimer;
@property (assign, nonatomic) BOOL authenticationTimedOut;
@property (copy, nonatomic) OSKManagedAccountAuthenticationHandler completionHandler;

@end

@implementation OSKAppDotNetActivity

@synthesize activeManagedAccount = _activeManagedAccount;
@synthesize remainingCharacterCount = _remainingCharacterCount;

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    [self cancelAuthenticationTimeoutTimer];
}

#pragma mark - System Account Methods

+ (OSKManagedAccountAuthenticationViewControllerType)authenticationViewControllerType {
    OSKManagedAccountAuthenticationViewControllerType method;
    if ([[OSKADNLoginManager sharedInstance] loginAvailable]) {
        method = OSKManagedAccountAuthenticationViewControllerType_None;
    } else {
        method = OSKManagedAccountAuthenticationViewControllerType_OneOfAKindCustomBespokeViewController;
    }
    return method;
}

- (OSKUsernameNomenclature)usernameNomenclatureForSignInScreen {
    return OSKUsernameNomenclature_Username;
}

- (void)authenticateNewAccountWithoutViewController:(OSKManagedAccountAuthenticationHandler)completion {
    [self authenticateWithADNLogin:completion];
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_MicroblogPost;
}

+ (BOOL)isAvailable {
    return YES;
}

+ (NSString *)activityType {
    return OSKActivityType_API_AppDotNet;
}

+ (NSString *)activityName {
    return @"App.net";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"osk-appDotNetIcon-60.png"];
    } else {
        image = [UIImage imageNamed:@"osk-appDotNetIcon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"osk-appDotNetIcon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_ManagedAccounts;
}

+ (BOOL)requiresApplicationCredential {
    return YES;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_ViewController_Microblogging;
}

- (BOOL)isReadyToPerform {
    BOOL appCredentialPreset = ([self.class applicationCredential] != nil);
    BOOL credentialPresent = (self.activeManagedAccount.credential != nil);
    BOOL accountPresent = (self.activeManagedAccount != nil);
    
    NSInteger maxCharacterCount = [self maximumCharacterCount];
    BOOL textIsValid = (0 <= self.remainingCharacterCount && self.remainingCharacterCount < maxCharacterCount);
    
    return (appCredentialPreset && credentialPresent && accountPresent && textIsValid);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKAppDotNetActivity *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [OSKAppDotNetUtility
         postContentItem:(OSKMicroblogPostContentItem *)weakSelf.contentItem
         withCredential:weakSelf.activeManagedAccount.credential
         appCredential:[weakSelf.class applicationCredential]
         completion:^(BOOL success, NSError *error) {
             OSKLog(@"Success! Sent new post to App.net.");
             if (completion) {
                 completion(weakSelf, success, error);
             }
         }];
    });
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

#pragma mark - Microblogging Activity Protocol

- (NSInteger)maximumCharacterCount {
    return OSKAppDotNetActivity_MaxCharacterCount;
}

- (NSInteger)maximumImageCount {
    return OSKAppDotNetActivity_MaxImageCount;
}

- (OSKSyntaxHighlighting)syntaxHighlighting {
    return OSKSyntaxHighlighting_Hashtags | OSKSyntaxHighlighting_Links | OSKSyntaxHighlighting_Usernames;
}

- (NSInteger)maximumUsernameLength {
    return OSKAppDotNetActivity_MaxUsernameLength;
}

- (NSInteger)updateRemainingCharacterCount:(OSKMicroblogPostContentItem *)contentItem urlEntities:(NSArray *)urlEntities {
    
    NSString *text = contentItem.text;
    NSInteger composedLength = [text osk_lengthAdjustingForComposedCharacters];
    NSInteger remainingCharacterCount = [self maximumCharacterCount] - composedLength;
    
    [self setRemainingCharacterCount:remainingCharacterCount];
    
    return remainingCharacterCount;
}

#pragma mark - ADNLogin

- (void)authenticateWithADNLogin:(OSKManagedAccountAuthenticationHandler)completion {
    __weak OSKAppDotNetActivity *weakSelf = self;
    [[OSKADNLoginManager sharedInstance] loginWithScopes:@[@"basic",@"write_post"] withCompletion:^(NSString *userID, NSString *token, NSError *error) {
        if (weakSelf.authenticationTimedOut == NO && completion) {
            OSKApplicationCredential *appCredential = [[OSKActivitiesManager sharedInstance] applicationCredentialForActivityType:[weakSelf.class activityType]];
            [OSKAppDotNetUtility createNewUserWithAccessToken:token appCredential:appCredential completion:^(OSKManagedAccount *account, NSError *error) {
                completion(account, error);
            }];
        }
    }];
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
        __weak OSKAppDotNetActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKAppDotNetActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"ADN authentication via the Passport app timed out."}];
            weakSelf.completionHandler(nil, error);
        });
    }
}

@end






