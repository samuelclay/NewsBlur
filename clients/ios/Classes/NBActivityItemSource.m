//
//  NBActivityItemSource.m
//  NewsBlur
//
//  Created by Samuel Clay on 12/15/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NBActivityItemSource.h"

@implementation NBActivityItemSource

- (instancetype)initWithUrl:(NSURL *)_url authorName:(NSString *)_authorName text:(NSString *)_text title:(NSString *)_title feedTitle:(NSString *)_feedTitle {
    if (self = [super init]) {
        url = _url;
        authorName = _authorName;
        text = _text;
        title = _title;
        feedTitle = _feedTitle;
    }

    return self;
}

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController {
    return @"";
}

-(id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    if ([activityType isEqualToString:UIActivityTypeMail]) {
        return text;
    } else if ([activityType isEqualToString:@"com.evernote.iPhone.Evernote.EvernoteShare"]) {
        return @{@"body": text ?: (url ?: @""), @"subject": title};
    } else if ([activityType isEqualToString:UIActivityTypeAddToReadingList] ||
               [activityType isEqualToString:UIActivityTypePostToTwitter] ||
               [activityType isEqualToString:UIActivityTypePostToFacebook] ||
               [activityType isEqualToString:UIActivityTypePostToWeibo] ||
               [activityType isEqualToString:@"NBCopyLinkActivity"] ||
               [activityType isEqualToString:@"TUSafariActivity"] ||
               [activityType isEqualToString:@"ARChromeActivity"] ||
               [activityType isEqualToString:@"com.apple.mobilenotes.SharingExtension"] ||
               [activityType isEqualToString:@"com.omnigroup.OmniFocus2.iPad.QuickEntry"]) {
        return title;
    }
    
    return [NSString stringWithFormat:@"%@\n%@", title, url];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType {
    return title;
}

@end
