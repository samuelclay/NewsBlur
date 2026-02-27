//
//  NotificationService.m
//  Story Notification Service Extension
//
//  Created by Samuel Clay on 11/21/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "NotificationService.h"
#import <Intents/Intents.h>

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];

    NSString *feedId = [[request.content.userInfo objectForKey:@"story_feed_id"] description];
    NSString *imageUrl = [request.content.userInfo objectForKey:@"image_url"];
    NSString *faviconUrl = [NSString stringWithFormat:@"https://www.newsblur.com/rss_feeds/icon/%@.png", feedId];

    if ([imageUrl isKindOfClass:[NSNull class]] || ![imageUrl isKindOfClass:[NSString class]]) {
        imageUrl = nil;
    }

    dispatch_group_t downloadGroup = dispatch_group_create();
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    __block NSData *faviconData = nil;
    __block NSURL *storyImageLocalURL = nil;

    // Always download favicon for the avatar overlay
    dispatch_group_enter(downloadGroup);
    NSURL *faviconNSURL = [NSURL URLWithString:faviconUrl];
    [[session dataTaskWithURL:faviconNSURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error && data) {
            faviconData = data;
        }
        dispatch_group_leave(downloadGroup);
    }] resume];

    // Download story image if available
    if (imageUrl) {
        dispatch_group_enter(downloadGroup);
        NSURL *imageNSURL = [NSURL URLWithString:imageUrl];
        NSString *extension = [self findExtensionOfFileInUrl:imageNSURL];
        [[session downloadTaskWithURL:imageNSURL completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
            if (!error && temporaryFileLocation) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSURL *localURL = [NSURL fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:[NSString stringWithFormat:@".%@", extension]]];
                NSError *moveError = nil;
                [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&moveError];
                if (!moveError) {
                    storyImageLocalURL = localURL;
                }
            }
            dispatch_group_leave(downloadGroup);
        }] resume];
    }

    dispatch_group_notify(downloadGroup, dispatch_get_main_queue(), ^{
        // Apply favicon as communication notification avatar overlay
        if (faviconData) {
            [self applyAvatarOverlayWithFaviconData:faviconData feedId:feedId request:request];
        }

        // Attach story image as rich thumbnail, or favicon as fallback
        if (storyImageLocalURL) {
            NSError *attachmentError = nil;
            UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"story_image"
                                                                                                 URL:storyImageLocalURL
                                                                                             options:nil
                                                                                               error:&attachmentError];
            if (attachment) {
                self.bestAttemptContent.attachments = @[attachment];
            }
        } else if (faviconData) {
            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                  [NSString stringWithFormat:@"favicon_%@.png", feedId]];
            [faviconData writeToFile:tempPath atomically:YES];
            NSURL *faviconFileURL = [NSURL fileURLWithPath:tempPath];
            NSError *attachmentError = nil;
            UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"favicon"
                                                                                                 URL:faviconFileURL
                                                                                             options:nil
                                                                                               error:&attachmentError];
            if (attachment) {
                self.bestAttemptContent.attachments = @[attachment];
            }
        }

        self.contentHandler(self.bestAttemptContent);
    });
}

- (void)applyAvatarOverlayWithFaviconData:(NSData *)faviconData
                                   feedId:(NSString *)feedId
                                  request:(UNNotificationRequest *)request {
    INPersonHandle *handle = [[INPersonHandle alloc] initWithValue:feedId type:INPersonHandleTypeUnknown];
    INImage *avatar = [INImage imageWithImageData:faviconData];

    INPerson *sender = [[INPerson alloc] initWithPersonHandle:handle
                                               nameComponents:nil
                                                  displayName:request.content.title
                                                        image:avatar
                                            contactIdentifier:nil
                                             customIdentifier:feedId
                                                         isMe:NO
                                               suggestionType:INPersonSuggestionTypeNone];

    INSendMessageIntent *intent = [[INSendMessageIntent alloc] initWithRecipients:nil
                                                              outgoingMessageType:INOutgoingMessageTypeOutgoingMessageText
                                                                          content:nil
                                                               speakableGroupName:nil
                                                         conversationIdentifier:feedId
                                                                    serviceName:nil
                                                                         sender:sender
                                                                    attachments:nil];

    [intent setImage:avatar forParameterNamed:@"sender"];

    INInteraction *interaction = [[INInteraction alloc] initWithIntent:intent response:nil];
    interaction.direction = INInteractionDirectionIncoming;
    [interaction donateInteractionWithCompletion:nil];

    NSError *error = nil;
    UNNotificationContent *updatedContent = [self.bestAttemptContent contentByUpdatingWithProvider:intent error:&error];
    if (updatedContent && !error) {
        self.bestAttemptContent = [updatedContent mutableCopy];
    }
}

- (void)serviceExtensionTimeWillExpire {
    self.contentHandler(self.bestAttemptContent);
}

- (NSString *)findExtensionOfFileInUrl:(NSURL *)url {
    NSString *extension = [url.path pathExtension];
    if (extension.length == 0) {
        extension = @"jpg";
    }
    return extension;
}

@end
