//
//  OSKThingsActivity.m
//  Overshare
//
//  Created by Jared Sinclair on 10/20/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKThingsActivity.h"

#import "OSKShareableContentItem.h"

static NSString * OSKThingsActivity_BaseURL = @"things:";
static NSString * OSKThingsActivity_AddEntryWithNoteURL = @"add?title=%@&notes=%@";

@implementation OSKThingsActivity

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
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:OSKThingsActivity_BaseURL]];
}

+ (NSString *)activityType {
    return OSKActivityType_URLScheme_Things;
}

+ (NSString *)activityName {
    return @"Things";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"Things-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Things-Icon-76.png"];
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
    NSString *baseURL = OSKThingsActivity_BaseURL;
    NSString *title = [self toDoListItem].title;
    NSString *notes = [self toDoListItem].notes;
    title = (title.length) ? title : @"New entry";
    notes = (notes.length) ? notes : @" ";
    NSString *fullQuery = [NSString stringWithFormat:OSKThingsActivity_AddEntryWithNoteURL, title, notes];
    NSString *encodedQuery = [fullQuery stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *fullURL = [NSString stringWithFormat:@"%@%@", baseURL, encodedQuery];
    NSURL *URL = [NSURL URLWithString:fullURL];
    if (URL) {
        [[UIApplication sharedApplication] openURL:URL];
        if (completion) {
            completion(self, YES, nil);
        }
    } else {
        NSError *error = [NSError errorWithDomain:@"OSKThingsActivity" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Invalid URL, unable to send new entry to Things."}];
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
