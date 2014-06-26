//
//  OSKChromeActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKChromeActivity.h"

#import "OSKShareableContentItem.h"
#import "NSString+OSKDerp.h"

static NSString * OSKChromeActivity_ChromeURLScheme = @"googlechrome-x-callback:";
static NSString * OSKChromeActivity_Path = @"//x-callback-url/open/";
static NSString * OSKChromeActivity_URLQueryKey = @"url";

@interface OSKChromeActivity ()

@property (copy, nonatomic) NSString *url_encoded_x_source;
@property (copy, nonatomic) NSString *url_encoded_x_success;
@property (copy, nonatomic) NSString *url_encoded_x_cancel;
@property (copy, nonatomic) NSString *url_encoded_x_error;

@end

@implementation OSKChromeActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        //
    }
    return self;
}

#pragma mark - OSKURLSchemeActivity

- (BOOL)targetApplicationSupportsXCallbackURL {
    return YES;
}

- (void)prepareToPerformActionUsingXCallbackURLInfo:(id<OSKXCallbackURLInfo>)info {
    if ([info respondsToSelector:@selector(xCallbackSourceForActivity:)]) {
        [self setUrl_encoded_x_source:[info xCallbackSourceForActivity:self]];
    }
    if ([info respondsToSelector:@selector(xCallbackCancelForActivity:)]) {
        [self setUrl_encoded_x_cancel:[info xCallbackCancelForActivity:self]];
    }
    if ([info respondsToSelector:@selector(xCallbackSuccessForActivity:)]) {
        [self setUrl_encoded_x_success:[info xCallbackSuccessForActivity:self]];
    }
    if ([info respondsToSelector:@selector(xCallbackErrorForActivity:)]) {
        [self setUrl_encoded_x_error:[info xCallbackErrorForActivity:self]];
    }
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

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_URLScheme;
}

- (BOOL)isReadyToPerform {
    return ([(OSKWebBrowserContentItem *)self.contentItem url] != nil);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    NSURL *url = [[self browserItem] url];
    
    NSMutableString *chromeURLString = [[NSMutableString alloc] init];
    [chromeURLString appendString:OSKChromeActivity_ChromeURLScheme];
    [chromeURLString appendString:OSKChromeActivity_Path];
    
    NSString *encodedURL = [url.absoluteString osk_derp_stringByEscapingPercents];
    [chromeURLString appendFormat:@"?%@=%@", OSKChromeActivity_URLQueryKey, encodedURL];
    
    if (self.url_encoded_x_source) {
        [chromeURLString appendFormat:@"&x-source=%@", self.url_encoded_x_source];
    }
    
    if (self.url_encoded_x_success) {
        [chromeURLString appendFormat:@"&x-success=%@", self.url_encoded_x_success];
    }
    
    if (self.url_encoded_x_cancel) {
        [chromeURLString appendFormat:@"&x-cancel=%@", self.url_encoded_x_cancel];
    }
    
    if (self.url_encoded_x_error) {
        [chromeURLString appendFormat:@"&x-error=%@", self.url_encoded_x_error];
    }

    NSURL *chromeURL = [NSURL URLWithString:chromeURLString];
    [[UIApplication sharedApplication] openURL:chromeURL];
    
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


