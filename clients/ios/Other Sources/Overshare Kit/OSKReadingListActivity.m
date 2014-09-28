//
//  OSKReadingListActivity.m
//  OvershareKit
//
//  Created by Jared Sinclair on 1/10/14.
//  Copyright (c) 2014 OvershareKit. All rights reserved.
//

#import "OSKReadingListActivity.h"

@import SafariServices;

#import "OSKActivitiesManager.h"
#import "OSKShareableContentItem.h"

@interface OSKReadingListActivity ()

@end

@implementation OSKReadingListActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
    }
    return self;
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_ReadLater;
}

+ (BOOL)isAvailable {
    return YES;
}

+ (NSString *)activityType {
    return OSKActivityType_iOS_ReadingList;
}

+ (NSString *)activityName {
    return @"Reading List";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"ReadingList-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"ReadingList-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"ReadingList-Icon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_None;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    BOOL isReady = NO;
    if ([self readLaterItem].url != nil) {
        isReady = [SSReadingList supportsURL:[self readLaterItem].url];
    }
    return isReady;
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    
    if ([self readLaterItem].url) {
        OSKReadLaterContentItem *item = [self readLaterItem];
        NSError *error = nil;
        [[SSReadingList defaultReadingList] addReadingListItemWithURL:item.url
                                                                title:item.title
                                                          previewText:item.description
                                                                error:&error];
        __weak OSKReadingListActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                BOOL successful = (error == nil);
                completion(weakSelf, successful, error);
            }
        });
    } else {
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey : @"Unable to add item to Reading List. A valid URL is required."};
        NSError *error = [[NSError alloc] initWithDomain:@"com.oversharekit" code:400 userInfo:userInfo];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(weakSelf, NO, error);
            }
        });
    }
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

@end






