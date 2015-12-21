//
//  NBActivityItemProvider.m
//  NewsBlur
//
//  Created by Samuel Clay on 12/15/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NBActivityItemProvider.h"

@implementation NBActivityItemProvider

- (instancetype)initWithUrl:(NSURL *)_url authorName:(NSString *)_authorName text:(NSString *)_text title:(NSString *)_title feedTitle:(NSString *)_feedTitle {
    if (self = [super initWithPlaceholderItem:_url]) {
        url = _url;
        authorName = _authorName;
        text = _text;
        title = _title;
        feedTitle = _feedTitle;
    }
    
    return self;
}

- (id)item {
    if ([self.placeholderItem isKindOfClass:[NSString class]]) {
        if ([self.activityType isEqualToString:UIActivityTypeMessage]) {
            return [NSString stringWithFormat:@"%@\n%@", title, url];
        } else if ([self.activityType isEqualToString:UIActivityTypePostToFacebook] ||
            [self.activityType isEqualToString:UIActivityTypeMail]) {
            
            return [NSString stringWithFormat:@"%@\n%@\n%@", title, url, text];
        } else if ([self.activityType isEqualToString:@"NBCopyLinkActivity"] ||
                   [self.activityType isEqualToString:@"TUSafariActivity"] ||
                   [self.activityType isEqualToString:@"ARChromeActivity"] ||
                   [self.activityType isEqualToString:@"com.apple.mobilenotes.SharingExtension"]) {
            return url;
        } else {
            return [NSString stringWithFormat:@"%@\n%@", title, url];
        }
    } else if ([self.placeholderItem isKindOfClass:[NSURL class]]) {
        return url;
    }
    
    return [NSString stringWithFormat:@"%@\n%@", title, url];
}

-(id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    if ([activityType isEqualToString:UIActivityTypeMail]) {
        return text ?: (url ?: @"");
    } else if ([activityType isEqualToString:@"com.evernote.iPhone.Evernote.EvernoteShare"]) {
        return @{@"body": text ?: (url ?: @""), @"subject": title};
    } else if ([activityType isEqualToString:UIActivityTypePostToTwitter] ||
               [activityType isEqualToString:UIActivityTypePostToFacebook] ||
               [activityType isEqualToString:UIActivityTypePostToWeibo]) {
        return [NSString stringWithFormat:@"%@\n%@", title, url];
    } else if ([activityType isEqualToString:@"NBCopyLinkActivity"] ||
               [self.activityType isEqualToString:@"TUSafariActivity"] ||
               [self.activityType isEqualToString:@"ARChromeActivity"] ||
               [self.activityType isEqualToString:@"com.apple.mobilenotes.SharingExtension"]) {
        return url;
    }
    
    return [NSString stringWithFormat:@"%@\n%@", title, url];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType {
    return title;
}

@end
