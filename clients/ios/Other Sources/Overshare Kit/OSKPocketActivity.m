//
//  OSKPocketActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKPocketActivity.h"

#import "PocketAPI.h"
#import "OSKShareableContentItem.h"

@interface OSKPocketActivity ()

@property (strong, nonatomic) NSTimer *authenticationTimeoutTimer;
@property (assign, nonatomic) BOOL authenticationTimedOut;
@property (copy, nonatomic) OSKGenericAuthenticationCompletionHandler completionHandler;

@end

@implementation OSKPocketActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    
}

#pragma mark - Generic Authentication

- (BOOL)isAuthenticated {
    return [[PocketAPI sharedAPI] isLoggedIn];
}

- (void)authenticate:(OSKGenericAuthenticationCompletionHandler)completion {
    [self setCompletionHandler:completion];
    [self startAuthenticationTimeoutTimer];
    __weak OSKPocketActivity *weakSelf = self;
    [[PocketAPI sharedAPI] loginWithHandler:^(PocketAPI *api, NSError *error) {
        if (completion && weakSelf.authenticationTimedOut == NO) {
            [weakSelf cancelAuthenticationTimeoutTimer];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion((error == nil), error);
            });
        }
    }];
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_ReadLater;
}

+ (BOOL)isAvailable {
    return ([[PocketAPI sharedAPI] consumerKey].length > 0);
}

+ (NSString *)activityType {
    return OSKActivityType_API_Pocket;
}

+ (NSString *)activityName {
    return @"Pocket";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"Pocket-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Pocket-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"Pocket-Icon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_Generic;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    return ([self readLaterItem].url != nil && [[PocketAPI sharedAPI] isLoggedIn]);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKPocketActivity *weakSelf = self;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    [[PocketAPI sharedAPI] saveURL:[self readLaterItem].url handler:^(PocketAPI *api, NSURL *url, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(weakSelf, (error == nil), error);
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
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

- (OSKReadLaterContentItem *)readLaterItem {
    return (OSKReadLaterContentItem *)self.contentItem;
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
        __weak OSKPocketActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKPocketActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Pocket authentication timed out."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}

@end







