//
//  OSK1PasswordBrowserActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/20/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSK1PasswordBrowserActivity.h"

#import "OSKShareableContentItem.h"
#import "OSKRPSTPasswordManagementAppService.h"

@implementation OSK1PasswordBrowserActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        //
    }
    return self;
}

#pragma mark - OSKURLSchemeActivity

- (BOOL)targetApplicationSupportsXCallbackURL {
    return NO;
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_WebBrowser;
}

+ (BOOL)isAvailable {
    return [OSKRPSTPasswordManagementAppService passwordManagementAppSupportsOpenWebView];
}

+ (NSString *)activityType {
    return OSKActivityType_URLScheme_1Password_Browser;
}

+ (NSString *)activityName {
    return @"1Password Browser";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"1Password-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"1Password-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [self iconForIdiom:UIUserInterfaceIdiomPhone];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_None;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_URLScheme;
}

- (BOOL)isReadyToPerform {
    NSURL *sourceURL = [(OSKWebBrowserContentItem *)self.contentItem url];
    NSString *scheme = [sourceURL scheme].lowercaseString;
    return ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    NSURL *sourceURL = [(OSKWebBrowserContentItem *)self.contentItem url];
    NSString *scheme = [sourceURL scheme].lowercaseString;
    NSURL *appURL = nil;
    if ([scheme isEqualToString:@"http"]) {
        appURL = [OSKRPSTPasswordManagementAppService passwordManagementAppCompleteURLForOpenWebViewHTTP:sourceURL.absoluteString];
    }
    else if ([scheme isEqualToString:@"https"]) {
        appURL = [OSKRPSTPasswordManagementAppService passwordManagementAppCompleteURLForOpenWebViewHTTP:sourceURL.absoluteString];        
    }
    if (appURL) {
        [[UIApplication sharedApplication] openURL:appURL];
        if (completion) {
            completion(self, YES, nil);
        }
    } else {
        NSError *error = [NSError errorWithDomain:@"Overshare" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Invalid URL, unable to open in 1Password."}];
        if (completion) {
            completion(self, NO, error);
        }
    }
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

@end
