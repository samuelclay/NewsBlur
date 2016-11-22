//
//  NotificationService.m
//  Story Notification Service Extension
//
//  Created by Samuel Clay on 11/21/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "NotificationService.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    // Modify the notification content here...
    // self.bestAttemptContent.title = [NSString stringWithFormat:@"%@ [modified]", self.bestAttemptContent.title];
    NSString *imageUrl = [request.content.userInfo objectForKey:@"image_url"];
    NSLog(@"Attaching image: %@", imageUrl);
    if ([imageUrl isKindOfClass:[NSNull class]]) {
        NSString *feedId = [request.content.userInfo objectForKey:@"story_feed_id"];
        imageUrl = [NSString stringWithFormat:@"https://www.newsblur.com/rss_feeds/icon/%@.png", feedId];
        NSLog(@"Attaching favicon image: %@", imageUrl);
    }

    [self loadAttachmentForUrlString:imageUrl completionHandler:^(UNNotificationAttachment *attachment) {
        if (attachment) {
            NSLog(@"Adding attachment: %@", attachment.URL);
            self.bestAttemptContent.attachments = @[attachment];
        }
        self.contentHandler(self.bestAttemptContent);
    }];
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    self.contentHandler(self.bestAttemptContent);
}

- (void)loadAttachmentForUrlString:(NSString *)urlString
                 completionHandler:(void(^)(UNNotificationAttachment *))completionHandler  {
    
    __block UNNotificationAttachment *attachment = nil;
    NSURL *attachmentURL = [NSURL URLWithString:urlString];
    NSString *extension = [self findExtensionOfFileInUrl:attachmentURL];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session downloadTaskWithURL:attachmentURL
                completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
                    if (error != nil) {
                        NSLog(@"%@", error.localizedDescription);
                    } else {
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        NSURL *localURL = [NSURL fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:[NSString stringWithFormat:@".%@",extension]]];
                        [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&error];
                        
                        NSError *attachmentError = nil;
                        attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:localURL options:nil error:&attachmentError];
                        if (attachmentError) {
                            NSLog(@"%@", attachmentError.localizedDescription);
                        }
                    }
                    completionHandler(attachment);
                }] resume];
}

- (NSString *)findExtensionOfFileInUrl:(NSURL *)url {
    NSString *urlString = [url absoluteString];
    NSArray *componentsArray = [urlString componentsSeparatedByString:@"."];
    NSString *fileExtension = [componentsArray lastObject];
    return  fileExtension;
}

@end
