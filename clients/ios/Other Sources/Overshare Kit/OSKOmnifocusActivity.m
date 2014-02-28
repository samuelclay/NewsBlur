//
//  OSKOmnifocusActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/20/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKOmnifocusActivity.h"

#import "OSKShareableContentItem.h"

static NSString * OSKOmnifocusActivity_BaseURL = @"omnifocus://";
static NSString * OSKOmnifocusActivity_AddEntryWithNoteURL = @"/add?name=%@&note=%@";

@implementation OSKOmnifocusActivity

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
    return OSKShareableContentItemType_ToDoListEntry;
}

+ (BOOL)isAvailable {
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:OSKOmnifocusActivity_BaseURL]];
}

+ (NSString *)activityType {
    return OSKActivityType_URLScheme_Omnifocus;
}

+ (NSString *)activityName {
    return @"OmniFocus";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"Omnifocus-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Omnifocus-Icon-72.png"];
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
    return [(OSKToDoListEntryContentItem *)self.contentItem title].length > 0;
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    NSString *baseURL = OSKOmnifocusActivity_BaseURL;
    NSString *title = [self toDoListItem].title;
    NSString *notes = [self toDoListItem].notes;
    title = (title.length) ? title : @"New entry";
    notes = (notes.length) ? notes : @" ";
    NSString *fullQuery = [NSString stringWithFormat:OSKOmnifocusActivity_AddEntryWithNoteURL, title, notes];
    NSString *encodedQuery = [fullQuery stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *fullURL = [NSString stringWithFormat:@"%@%@", baseURL, encodedQuery];
    NSURL *URL = [NSURL URLWithString:fullURL];
    if (URL) {
        [[UIApplication sharedApplication] openURL:URL];
        if (completion) {
            completion(self, YES, nil);
        }
    } else {
        NSError *error = [NSError errorWithDomain:@"OSKOmnifocusActivity" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Invalid URL, unable to send new entry to Omnifocus."}];
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
                       
#pragma mark - Convenience

- (OSKToDoListEntryContentItem *)toDoListItem {
    return (OSKToDoListEntryContentItem *)self.contentItem;
}

@end





