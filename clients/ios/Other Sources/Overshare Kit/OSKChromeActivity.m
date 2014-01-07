//
//  OSKChromeActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

// ======================================================================
// Portions of this code from Google Inc:
// ======================================================================
//
// Copyright 2012, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ======================================================================

#import "OSKChromeActivity.h"

#import "OSKShareableContentItem.h"

static NSString * OSKChromeActivity_ChromeURLScheme = @"googlechrome:";
static NSString * kGoogleChromeHTTPScheme = @"googlechrome:";
static NSString * kGoogleChromeHTTPSScheme = @"googlechromes:";

@implementation OSKChromeActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        //
    }
    return self;
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_WebBrowser;
}

+ (BOOL)isAvailable {
    NSURL *url = [NSURL URLWithString:OSKChromeActivity_ChromeURLScheme];
    return [[UIApplication sharedApplication] canOpenURL:url];
}

+ (NSString *)activityType {
    return OSKActivityType_URLScheme_Chrome;
}

+ (NSString *)activityName {
    return @"Chrome";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"Chrome-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Chrome-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"Chrome-Icon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_None;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingViewControllerType)publishingViewControllerType {
    return OSKPublishingViewControllerType_None;
}

- (BOOL)isReadyToPerform {
    return ([(OSKWebBrowserContentItem *)self.contentItem url] != nil);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    NSURL *url = [[self browserItem] url];
    NSString *scheme = [url.scheme lowercaseString];
    
    // Replace the URL Scheme with the Chrome equivalent.
    NSString *chromeScheme = nil;
    if ([scheme isEqualToString:@"http"]) {
        chromeScheme = kGoogleChromeHTTPScheme;
    } else if ([scheme isEqualToString:@"https"]) {
        chromeScheme = kGoogleChromeHTTPSScheme;
    }
    
    // Proceed only if a valid Google Chrome URI Scheme is available.
    if (chromeScheme) {
        NSString *absoluteString = [url absoluteString];
        NSRange rangeForScheme = [absoluteString rangeOfString:@":"];
        NSString *urlNoScheme =
        [absoluteString substringFromIndex:rangeForScheme.location + 1];
        NSString *chromeURLString =
        [chromeScheme stringByAppendingString:urlNoScheme];
        NSURL *chromeURL = [NSURL URLWithString:chromeURLString];
        
        // Open the URL with Google Chrome.
        [[UIApplication sharedApplication] openURL:chromeURL];
    }
    if (completion) {
        completion(self, YES, nil);
    }
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

#pragma mark - Convenience

- (OSKWebBrowserContentItem *)browserItem {
    return (OSKWebBrowserContentItem *)self.contentItem;
}

@end


