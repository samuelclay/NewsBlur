//
//  ActivityCell.m
//  NewsBluractivity
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityCell.h"
#import "NSAttributedString+Attributes.h"
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
        
        OHAttributedLabel *activity = [[OHAttributedLabel alloc] initWithFrame:CGRectZero];
        activity.backgroundColor = [UIColor whiteColor];
        activity.automaticallyAddLinksForType = NO;
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
        [category isEqualToString:@"comment_like"]) {
        // this is for the rare instance when the with_user doesn't return anything
        if ([[activity objectForKey:@"with_user"] class] == [NSNull class]) {
            self.faviconView.frame = CGRectZero;
            self.activityLabel.attributedText = nil;
            return 1;
        }

        UIImage *placeholder = [UIImage imageNamed:@"user_light"];
        [self.faviconView setImageWithURL:[NSURL URLWithString:[[activity objectForKey:@"with_user"] objectForKey:@"photo_url"]]
                         placeholderImage:placeholder];
    } else if ([category isEqualToString:@"sharedstory"]) {
        UIImage *placeholder = [UIImage imageNamed:@"user_light"];
        [self.faviconView setImageWithURL:[NSURL URLWithString:[userProfile objectForKey:@"photo_url"]]
                         placeholderImage:placeholder];
    } else {
        UIImage *placeholder = [UIImage imageNamed:@"world"];
        NSString *faviconUrl = [NSString stringWithFormat:@"http://%@/rss_feeds/icon/%i", 
                                NEWSBLUR_URL,
                                [[activity objectForKey:@"feed_id"] intValue]];
        [self.faviconView setImageWithURL:[NSURL URLWithString:faviconUrl ]
                         placeholderImage:placeholder];
        self.faviconView.contentMode = UIViewContentModeScaleAspectFit;
        self.faviconView.frame = CGRectMake(leftMargin+16, topMargin, 16, 16);
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
        if ([content isEqualToString:@""] || content == nil) {
            txt = [NSString stringWithFormat:@"%@ shared %@.", username, title]; 
        } else {
            txt = [NSString stringWithFormat:@"%@ shared %@:\n%@", username, title, comment];      
        }
        
    } else if ([category isEqualToString:@"star"]) {
        txt = [NSString stringWithFormat:@"You saved \"%@\".", content];
    } else if ([category isEqualToString:@"feedsub"]) {
        txt = [NSString stringWithFormat:@"You subscribed to %@.", content];
    }

    NSString *txtWithTime = [NSString stringWithFormat:@"%@\n%@", txt, time];
    NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txtWithTime];
    
    // for those calls we don't specify a range so it affects the whole string
    [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
    [attrStr setTextColor:UIColorFromRGB(0x333333)];
    
    if (![username isEqualToString:@"You"]){
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_LINK_COLOR) range:[txtWithTime rangeOfString:username]];
        [attrStr setTextBold:YES range:[txt rangeOfString:username]];
    }
    
    [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_LINK_COLOR) range:[txtWithTime rangeOfString:title]];
    
    if(withUserUsername.length) {
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_LINK_COLOR) range:[txtWithTime rangeOfString:withUserUsername]];
        [attrStr setTextBold:YES range:[txtWithTime rangeOfString:withUserUsername]]; 
    }
    
    [attrStr setTextColor:UIColorFromRGB(0x666666) range:[txtWithTime rangeOfString:comment]];
    
    [attrStr setTextColor:UIColorFromRGB(0x999999) range:[txtWithTime rangeOfString:time]];
    [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:10] range:[txtWithTime rangeOfString:time]];
    [attrStr setTextAlignment:kCTLeftTextAlignment lineBreakMode:kCTLineBreakByWordWrapping lineHeight:4];
    
    self.activityLabel.attributedText = attrStr;
    
    [self.activityLabel sizeToFit];
    
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
