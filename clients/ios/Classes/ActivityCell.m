//
//  ActivityCell.m
//  NewsBluractivity
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityCell.h"
#import "UIImageView+AFNetworking.h"

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
        
        // create favicon and label in view
        UIImageView *favicon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.faviconView = favicon;
        [self.contentView addSubview:favicon];
        
        UILabel *activity = [[UILabel alloc] initWithFrame:CGRectZero];
        activity.backgroundColor = [UIColor whiteColor];
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
    CGRect contentRect = self.contentView.bounds;
    
    // position label to bounds
    CGRect labelRect = contentRect;
    labelRect.origin.x = labelRect.origin.x + leftMargin + avatarSize + leftMargin;
    labelRect.origin.y = labelRect.origin.y + topMargin - 1;
    labelRect.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin;
    labelRect.size.height = contentRect.size.height - topMargin - bottomMargin;
    self.activityLabel.frame = labelRect;
}

- (int)setActivity:(NSDictionary *)activity withUserProfile:(NSDictionary *)userProfile withWidth:(int)width {
    // must set the height again for dynamic height in heightForRowAtIndexPath in 
    CGRect activityLabelRect = self.activityLabel.bounds;
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
            NSString *faviconUrl = [NSString stringWithFormat:@"%@/rss_feeds/icon/%i",
                                    NEWSBLUR_URL,
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
        txt = [NSString stringWithFormat:@"%@ replied to %@: \n%@", username, withUserUsername, comment];  
    } else if ([category isEqualToString:@"comment_like"]) {
        withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        txt = [NSString stringWithFormat:@"%@ favorited %@'s comment on %@:\n%@", username, withUserUsername, title, comment];
    } else if ([category isEqualToString:@"sharedstory"]) {
        if ([content class] == [NSNull class] || [content isEqualToString:@""] || content == nil) {
            txt = [NSString stringWithFormat:@"%@ shared %@.", username, title]; 
        } else {
            txt = [NSString stringWithFormat:@"%@ shared %@:\n%@", username, title, comment];      
        }
        
    } else if ([category isEqualToString:@"star"]) {
        txt = [NSString stringWithFormat:@"You saved \"%@\".", content];
    } else if ([category isEqualToString:@"feedsub"]) {
        txt = [NSString stringWithFormat:@"You subscribed to %@.", content];
    } else if ([category isEqualToString:@"signup"]) {
        txt = [NSString stringWithFormat:@"You signed up for NewsBlur."];
    }

    NSString *txtWithTime = [NSString stringWithFormat:@"%@\n%@", txt, time];
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
    NSMutableParagraphStyle* style= [NSMutableParagraphStyle new];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    [attrStr addAttributes:@{NSParagraphStyleAttributeName: style} range:NSMakeRange(0, [txtWithTime length])];
    
    self.activityLabel.attributedText = attrStr;
    
    CGRect rect = [attrStr boundingRectWithSize:CGSizeMake(self.activityLabel.frame.size.width, 0.0f)
                                        options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                        context:nil];
    self.activityLabel.frame = rect;
    
    int height = self.activityLabel.frame.size.height;
    
    return MAX(height, self.faviconView.frame.size.height);
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
