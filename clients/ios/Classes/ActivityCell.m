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
#import "NewsBlur-Swift.h"
#import "NSString+HTML.h"

@interface ActivityCell ()
@property (nonatomic, strong) NSLayoutConstraint *labelLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *labelTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *labelTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *labelBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *minimumContentHeightConstraint;
@end

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
        self.backgroundColor = UIColorFromRGB(0xffffff);
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

        activity.translatesAutoresizingMaskIntoConstraints = NO;
        activity.numberOfLines = 0;
        self.labelLeadingConstraint = [activity.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:leftMargin * 2 + avatarSize];
        self.labelTrailingConstraint = [activity.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-rightMargin];
        self.labelTopConstraint = [activity.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:topMargin];
        self.labelBottomConstraint = [activity.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-bottomMargin];
        self.minimumContentHeightConstraint = [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:avatarSize + topMargin + bottomMargin];
        self.minimumContentHeightConstraint.priority = UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[self.labelLeadingConstraint, self.labelTrailingConstraint,
                                                 self.labelTopConstraint, self.labelBottomConstraint,
                                                 self.minimumContentHeightConstraint]];
    }
    
    return self;
}


- (void)updateConstraints {
    // ActivityCell.m leaves multiline height calculation to the table's actual content area and accessory layout.
    self.labelLeadingConstraint.constant = leftMargin * 2 + avatarSize;
    self.labelTrailingConstraint.constant = -rightMargin;
    self.labelTopConstraint.constant = topMargin;
    self.labelBottomConstraint.constant = -bottomMargin;
    self.minimumContentHeightConstraint.constant = avatarSize + topMargin + bottomMargin;
    [super updateConstraints];
}

+ (BOOL)shouldCollapseActivity:(NSDictionary *)activity {
    // ActivityCell.m only requires another user for these activity categories.
    return activity[@"with_user"] == NSNull.null &&
        [@[@"follow", @"comment_reply", @"comment_like", @"signup"] containsObject:activity[@"category"]];
}

- (void)setActivity:(NSDictionary *)activity withUserProfile:(NSDictionary *)userProfile {
    [self setNeedsUpdateConstraints];
    self.faviconView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);

    NSString *category = [activity objectForKey:@"category"];
    NSString *content = [self plainTextComment:[activity objectForKey:@"content"]];
    NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
    NSString *title = [self stripFormatting:[NSString stringWithFormat:@"%@", [activity objectForKey:@"title"]]];
    NSString *time = [NSString stringWithFormat:@"%@ ago", [activity objectForKey:@"time_since"]];
    NSString *withUserUsername = @"";
    NSString *username = [NSString stringWithFormat:@"%@", [userProfile objectForKey:@"username"]];
        
    NSString* txt;
    
    if ([category isEqualToString:@"follow"] ||
        [category isEqualToString:@"comment_reply"] ||
        [category isEqualToString:@"comment_like"] ||
        [category isEqualToString:@"signup"]) {
        // this is for the rare instance when the with_user doesn't return anything
        if ([ActivityCell shouldCollapseActivity:activity]) {
            self.faviconView.frame = CGRectZero;
            self.activityLabel.attributedText = nil;
            return;
        }

        UIImage *placeholder = [[NewsBlurAppDelegate sharedAppDelegate] defaultUserAvatar];
        [self.faviconView setImageWithURL:[NSURL URLWithString:[[activity objectForKey:@"with_user"] objectForKey:@"photo_url"]]
                         placeholderImage:placeholder];
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
    
    [attrStr setAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"WhitneySSm-Book" size:14]} range:NSMakeRange(0, [txtWithTime length])];
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
    [attrStr addAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"WhitneySSm-Book" size:12]} range:[txtWithTime rangeOfString:time]];
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
}

- (NSString *)plainTextComment:(id)content {
    if (![content isKindOfClass:[NSString class]]) {
        return @"";
    }

    NSString *text = content;
    NSString *tagPattern = @"</?[A-Za-z][^>]*>";
    if ([text rangeOfString:tagPattern options:NSRegularExpressionSearch].location == NSNotFound) {
        return [text stringByDecodingHTMLEntities];
    }

    // ActivityCell.m preserves comment paragraphs while NSString+HTML decodes their entities without loading web content.
    text = [text stringByReplacingOccurrencesOfString:@"(?i)</(?:p|div|blockquote|li|h[1-6])\\s*>"
                                          withString:@"\n\n" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)];
    text = [text stringByReplacingOccurrencesOfString:@"(?i)<br\\s*/?>"
                                          withString:@"\n" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)];
    text = [text stringByReplacingOccurrencesOfString:tagPattern
                                          withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)];
    text = [text stringByReplacingOccurrencesOfString:@"[ \\t]*\\n[ \\t]*"
                                          withString:@"\n" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)];
    text = [text stringByReplacingOccurrencesOfString:@"\\n{3,}"
                                          withString:@"\n\n" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)];
    return [[text stringByDecodingHTMLEntities] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
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
