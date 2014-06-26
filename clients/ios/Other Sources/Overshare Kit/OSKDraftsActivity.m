//
//  OSKDraftsActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKDraftsActivity.h"

#import "OSKShareableContentItem.h"
#import "NSString+OSKDerp.h"

static NSString * OSKDraftsActivity_URLScheme = @"drafts://";
static NSString * OSKDraftsActivity_Path_CreateNote = @"x-callback-url/create";
static NSString * OSKDraftsActivity_QueryKey_Text = @"text";

@interface OSKDraftsActivity ()

@property (copy, nonatomic) NSString *url_encoded_x_success;
@property (copy, nonatomic) NSString *url_encoded_x_error;

@end

@implementation OSKDraftsActivity

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
    if ([info respondsToSelector:@selector(xCallbackSuccessForActivity:)]) {
        [self setUrl_encoded_x_success:[info xCallbackSuccessForActivity:self]];
    }
    if ([info respondsToSelector:@selector(xCallbackErrorForActivity:)]) {
        [self setUrl_encoded_x_error:[info xCallbackErrorForActivity:self]];
    }
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_TextEditing;
}

+ (BOOL)isAvailable {
    NSURL *url = [NSURL URLWithString:OSKDraftsActivity_URLScheme];
    return [[UIApplication sharedApplication] canOpenURL:url];
}

+ (NSString *)activityType {
    return OSKActivityType_URLScheme_Drafts;
}

+ (NSString *)activityName {
    return @"Drafts";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"Drafts-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Drafts-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"Drafts-Icon-29.png"];
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
    return ([self textEditingItem].text.length > 0);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    
    NSMutableString *draftsURLstring = [[NSMutableString alloc] init];
    [draftsURLstring appendString:OSKDraftsActivity_URLScheme];
    [draftsURLstring appendString:OSKDraftsActivity_Path_CreateNote];
    
    NSString *text = [[self textEditingItem] text];
    NSString *encodedText = [text osk_derp_stringByEscapingPercents];
    [draftsURLstring appendFormat:@"?%@=%@", OSKDraftsActivity_QueryKey_Text, encodedText];
    
    if (self.url_encoded_x_success) {
        [draftsURLstring appendFormat:@"&x-success=%@", self.url_encoded_x_success];
    }
    
    if (self.url_encoded_x_error) {
        [draftsURLstring appendFormat:@"&x-error=%@", self.url_encoded_x_error];
    }
    
    NSURL *draftsURL = [NSURL URLWithString:draftsURLstring];
    [[UIApplication sharedApplication] openURL:draftsURL];
    
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

- (OSKTextEditingContentItem *)textEditingItem {
    return (OSKTextEditingContentItem *)self.contentItem;
}

@end


