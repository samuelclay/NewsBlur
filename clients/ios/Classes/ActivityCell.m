//
//  ActivityCell.m
//  NewsBluractivity
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityCell.h"
#import "UIImageView+AFNetworking.h"
#import "NewsBlurAppDelegate.h"

@implementation ActivityCell

@synthesize activityLabel;
@synthesize faviconView;
@synthesize topMargin;
@synthesize bottomMargin;
@synthesize leftMargin;
@synthesize rightMargin;
@synthesize avatarSize;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        activityLabel = nil;
        faviconView = nil;
        self.separatorInset = UIEdgeInsetsMake(0, 90, 0, 0);
        
        // create favicon and label in view
        UIImageView *favicon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.faviconView = favicon;
        [self.contentView addSubview:favicon];
        
        UILabel *activity = [[UILabel alloc] initWithFrame:CGRectZero];
        activity.backgroundColor = UIColorFromRGB(0xffffff);
        self.activityLabel = activity;
        [self.contentView addSubview:activity];

        
        topMargin = 15;
        bottomMargin = 15;
        leftMargin = 20;
        rightMargin = 20;
        avatarSize = 48;
    }
    
    return self;
}


- (void)layoutSubviews {    
    [super layoutSubviews];
    
    // determine outer bounds
    [self.activityLabel sizeToFit];
    CGRect contentRect = self.frame;
    CGRect labelFrame = self.activityLabel.frame;
    
    // position label to bounds
    labelFrame.origin.x = leftMargin*2 + avatarSize;
    labelFrame.origin.y = 0;
    labelFrame.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin - 20;
    labelFrame.size.height = contentRect.size.height;
    self.activityLabel.frame = labelFrame;
}

- (int)setActivity:(NSDictionary *)activity withUserProfile:(NSDictionary *)userProfile withWidth:(int)width {
    // must set the height again for dynamic height in heightForRowAtIndexPath in
    CGRect activityLabelRect = self.activityLabel.frame;
    activityLabelRect.size.width = width - leftMargin - avatarSize - leftMargin - rightMargin;
    
    self.activityLabel.frame = activityLabelRect;
    self.activityLabel.numberOfLines = 0;
    self.faviconView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);

    NSString *category = [activity objectForKey:@"category"];
    NSString *content = [activity objectForKey:@"content"];
    NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
    NSString *title = [self stripFormatting:[NSString stringWithFormat:@"%@", [activity objectForKey:@"title"]]];
    NSString *time = [[NSString stringWithFormat:@"%@ ago", [activity objectForKey:@"time_since"]] uppercaseString];
    NSString *withUserUsername = @"";
    NSString *username = [NSString stringWithFormat:@"%@", [userProfile objectForKey:@"username"]];
        
    NSString* txt;
    
    if ([category isEqualToString:@"follow"] ||
        [category isEqualToString:@"comment_reply"] ||
        [category isEqualToString:@"comment_like"] ||
        [category isEqualToString:@"signup"]) {
        // this is for the rare instance when the with_user doesn't return anything
        if ([[activity objectForKey:@"with_user"] class] == [NSNull class]) {
            self.faviconView.frame = CGRectZero;
            self.activityLabel.attributedText = nil;
            return 1;
        }

//        UIImage *placeholder = [UIImage imageNamed:@"user_light"];
        [self.faviconView setImageWithURL:[NSURL URLWithString:[[activity objectForKey:@"with_user"] objectForKey:@"photo_url"]]
                         placeholderImage:nil];
    } else if ([category isEqualToString:@"sharedstory"] ||
               [category isEqualToString:@"feedsub"] ||
               [category isEqualToString:@"star"]) {
//        UIImage *placeholder = [UIImage imageNamed:@"world"];
        id feedId;
        if ([category isEqualToString:@"feedsub"]) {
            feedId = [activity objectForKey:@"feed_id"];
        } else {
            feedId = [activity objectForKey:@"story_feed_id"];
        }
        if (feedId && [feedId class] != [NSNull class]) {
            NSString *url = [NewsBlurAppDelegate sharedAppDelegate].url;
            
            if ([url isEqualToString:DEFAULT_NEWSBLUR_URL]) {
                url = DEFAULT_ICONS_HOST;
            } else {
                url = [url stringByAppendingPathComponent:@"rss_feeds/icon"];
            }
            
            NSString *faviconUrl = [NSString stringWithFormat:@"%@/%i",
                                    url,
                                    [feedId intValue]];
            [self.faviconView setImageWithURL:[NSURL URLWithString:faviconUrl]
                             placeholderImage:nil];
            self.faviconView.contentMode = UIViewContentModeScaleAspectFit;
            self.faviconView.frame = CGRectMake(leftMargin+16, topMargin, 16, 16);
        }
    }
    
    if ([category isEqualToString:@"follow"]) {
        withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        txt = [NSString stringWithFormat:@"%@ followed %@.", username, withUserUsername];
    } else if ([category isEqualToString:@"comment_reply"]) {
        withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        txt = [NSString stringWithFormat:@"%@ replied to %@: \n \n%@", username, withUserUsername, comment];  
    } else if ([category isEqualToString:@"comment_like"]) {
        withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        txt = [NSString stringWithFormat:@"%@ favorited %@'s comment on %@:\n \n%@", username, withUserUsername, title, comment];
    } else if ([category isEqualToString:@"sharedstory"]) {
        if ([content class] == [NSNull class] || [content isEqualToString:@""] || content == nil) {
            txt = [NSString stringWithFormat:@"%@ shared %@.", username, title]; 
        } else {
            txt = [NSString stringWithFormat:@"%@ shared %@:\n \n%@", username, title, comment];
        }
        
    } else if ([category isEqualToString:@"star"]) {
        txt = [NSString stringWithFormat:@"You saved \"%@\".", content];
    } else if ([category isEqualToString:@"feedsub"]) {
        txt = [NSString stringWithFormat:@"You subscribed to %@.", content];
    } else if ([category isEqualToString:@"signup"]) {
        txt = [NSString stringWithFormat:@"You signed up for NewsBlur."];
    }

    NSString *txtWithTime = [NSString stringWithFormat:@"%@\n \n%@", txt, time];
    NSMutableAttributedString* attrStr = [[NSMutableAttributedString alloc] initWithString:txtWithTime];
    
    [attrStr setAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:13]} range:NSMakeRange(0, [txtWithTime length])];
    if (self.highlighted) {
        [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0xffffff)} range:NSMakeRange(0, [txtWithTime length])];
    } else {
        [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0x333333)} range:NSMakeRange(0, [txtWithTime length])];
    }
    
    if (![username isEqualToString:@"You"]){
        [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(NEWSBLUR_LINK_COLOR)} range:[txtWithTime rangeOfString:username]];
        [attrStr addAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13]} range:[txtWithTime rangeOfString:username]];
    }
    if (withUserUsername.length) {
        [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(NEWSBLUR_LINK_COLOR)} range:[txtWithTime rangeOfString:withUserUsername]];
        [attrStr addAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13]} range:[txtWithTime rangeOfString:withUserUsername]];
    }

    [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(NEWSBLUR_LINK_COLOR)} range:[txtWithTime rangeOfString:title]];
    [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0x666666)} range:[txtWithTime rangeOfString:comment]];
    [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0x999999)} range:[txtWithTime rangeOfString:time]];
    [attrStr addAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:11]} range:[txtWithTime rangeOfString:time]];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    [attrStr addAttributes:@{NSParagraphStyleAttributeName: paragraphStyle} range:NSMakeRange(0, [txtWithTime length])];
    
    NSRange commentRange = [txtWithTime rangeOfString:comment];
    if (commentRange.location != NSNotFound) {
        commentRange.location -= 2;
        commentRange.length = 1;
        if ([[txtWithTime substringWithRange:commentRange] isEqualToString:@" "]) {
            [attrStr addAttribute:NSFontAttributeName
                            value:[UIFont systemFontOfSize:4.0f]
                            range:commentRange];
        }
    }
    
    NSRange dateRange = [txtWithTime rangeOfString:time];
    if (dateRange.location != NSNotFound) {
        dateRange.location -= 2;
        dateRange.length = 1;
        [attrStr addAttribute:NSFontAttributeName
                        value:[UIFont systemFontOfSize:4.0f]
                        range:dateRange];
    }
    
    self.activityLabel.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.activityLabel.attributedText = attrStr;
    [self.activityLabel sizeToFit];
        
    int height = self.activityLabel.frame.size.height;
    
    return MAX(height + topMargin + bottomMargin, self.faviconView.frame.size.height + topMargin + bottomMargin);
}

- (NSString *)stripFormatting:(NSString *)str {
    while ([str rangeOfString:@"  "].location != NSNotFound) {
        str = [str stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    while ([str rangeOfString:@"\n"].location != NSNotFound) {
        str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    }
    return str;
}

@end
