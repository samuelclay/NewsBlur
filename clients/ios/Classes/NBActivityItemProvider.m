//
//  NBActivityItemProvider.m
//  NewsBlur
//
//  Created by Samuel Clay on 12/15/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NBActivityItemProvider.h"

@implementation NBActivityItemProvider

- (instancetype)initWithUrl:(NSURL *)_url authorName:(NSString *)_authorName text:(NSString *)_text title:(NSString *)_title feedTitle:(NSString *)_feedTitle images:(NSArray *)_images {
    if (self = [self initWithUrl:_url authorName:_authorName text:_text title:_title feedTitle:_feedTitle images:_images]) {
        url = _url;
        authorName = _authorName;
        text = _text;
        title = _title;
        feedTitle = _feedTitle;
        images = _images;
        
    }
    return self;
}

- (id)item {
    return [NSDictionary dictionary];
}

-(id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    if ([activityType isEqualToString:UIActivityTypeMail] ||
        [activityType isEqualToString:@"com.evernote.iPhone.Evernote.EvernoteShare"]) {
        return @{@"body": text ?: @"", @"subject": title};
    } else if ([activityType isEqualToString:UIActivityTypePostToTwitter] ||
               [activityType isEqualToString:UIActivityTypePostToFacebook] ||
               [activityType isEqualToString:UIActivityTypePostToWeibo]) {
        return title;
    }
    return title;
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType {
    return title;
}

@end
