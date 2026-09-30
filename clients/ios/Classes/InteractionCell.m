//
//  InteractionCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "InteractionCell.h"
#import "UIImageView+AFNetworking.h"
#import "NewsBlurAppDelegate.h"
#import <CoreText/CoreText.h>

@interface InteractionCell ()
@property (nonatomic, strong) NSLayoutConstraint *labelLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *labelTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *labelTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *labelBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *minimumContentHeightConstraint;
@end

@implementation InteractionCell

@synthesize interactionLabel;
@synthesize avatarView;
@synthesize topMargin;
@synthesize bottomMargin;
@synthesize leftMargin;
@synthesize rightMargin;
@synthesize avatarSize;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        interactionLabel = nil;
        avatarView = nil;
        self.backgroundColor = UIColorFromRGB(0xffffff);
        self.separatorInset = UIEdgeInsetsMake(0, 90, 0, 0);
        
        // create the label and the avatar
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.avatarView = avatar;
        [self.contentView addSubview:avatar];
        
        UILabel *interaction = [[UILabel alloc] initWithFrame:CGRectZero];
        interaction.backgroundColor = UIColorFromRGB(0xffffff);
//        interaction.automaticallyAddLinksForType = NO;
        self.interactionLabel = interaction;
        [self.contentView addSubview:interaction];
        
        UIView *myBackView = [[UIView alloc] initWithFrame:self.frame];
        myBackView.backgroundColor = UIColorFromRGB(NEWSBLUR_HIGHLIGHT_COLOR);
        self.selectedBackgroundView = myBackView;
        
        topMargin = 12;
        bottomMargin = 12;
        leftMargin = 20;
        rightMargin = 20;
        avatarSize = 48;

        interaction.translatesAutoresizingMaskIntoConstraints = NO;
        interaction.numberOfLines = 0;
        self.labelLeadingConstraint = [interaction.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:leftMargin * 2 + avatarSize];
        self.labelTrailingConstraint = [interaction.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-rightMargin];
        self.labelTopConstraint = [interaction.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:topMargin];
        self.labelBottomConstraint = [interaction.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-bottomMargin];
        self.minimumContentHeightConstraint = [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:avatarSize + topMargin + bottomMargin];
        self.minimumContentHeightConstraint.priority = UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[self.labelLeadingConstraint, self.labelTrailingConstraint,
                                                 self.labelTopConstraint, self.labelBottomConstraint,
                                                 self.minimumContentHeightConstraint]];
    }
    
    return self;
}

- (void)updateConstraints {
    // InteractionCell.m measures text in UIKit's actual content area, including small-cell margins.
    self.labelLeadingConstraint.constant = leftMargin * 2 + avatarSize;
    self.labelTrailingConstraint.constant = -rightMargin;
    self.labelTopConstraint.constant = topMargin;
    self.labelBottomConstraint.constant = -bottomMargin;
    self.minimumContentHeightConstraint.constant = avatarSize + topMargin + bottomMargin;
    [super updateConstraints];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.avatarView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
}


+ (BOOL)shouldCollapseInteraction:(NSDictionary *)interaction {
    return interaction[@"with_user"] == NSNull.null;
}

- (void)setInteraction:(NSDictionary *)interaction {
    [self setNeedsUpdateConstraints];
    self.avatarView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    // this is for the rare instance when the with_user doesn't return anything
    if ([InteractionCell shouldCollapseInteraction:interaction]) {
        self.interactionLabel.attributedText = nil;
        return;
    }
    
    UIImage *placeholder = [[NewsBlurAppDelegate sharedAppDelegate] defaultUserAvatar];
    [self.avatarView setImageWithURL:[NSURL URLWithString:[[interaction objectForKey:@"with_user"] objectForKey:@"photo_url"]]
        placeholderImage:placeholder];
        
    NSString *category = [interaction objectForKey:@"category"];
    NSString *content = [interaction objectForKey:@"content"];
    NSString *title = [self stripFormatting:[NSString stringWithFormat:@"%@", [interaction objectForKey:@"title"]]];
    NSString *username = [[interaction objectForKey:@"with_user"] objectForKey:@"username"];
    NSString *time = [NSString stringWithFormat:@"%@ ago", [interaction objectForKey:@"time_since"]];
    NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
    NSString *txt;
    
    if ([category isEqualToString:@"follow"]) {        
        txt = [NSString stringWithFormat:@"%@ is now following you.", username];                
    } else if ([category isEqualToString:@"comment_reply"]) {
        txt = [NSString stringWithFormat:@"%@ replied to your comment on %@:\n \n%@", username, title, comment];          
    } else if ([category isEqualToString:@"reply_reply"]) {
        txt = [NSString stringWithFormat:@"%@ replied to your reply on %@:\n \n%@", username, title, comment];  
    } else if ([category isEqualToString:@"story_reshare"]) {
        if ([content isEqualToString:@""] || content == nil) {
            txt = [NSString stringWithFormat:@"%@ re-shared %@.", username, title];
        } else {
            txt = [NSString stringWithFormat:@"%@ re-shared %@:\n \n%@", username, title, comment];
        }
    } else if ([category isEqualToString:@"comment_like"]) {
        txt = [NSString stringWithFormat:@"%@ favorited your comments on %@.", username, title];
    }
    
    NSString *txtWithTime = [NSString stringWithFormat:@"%@\n \n%@", txt, time];
    NSMutableAttributedString* attrStr = [[NSMutableAttributedString alloc] initWithString:txtWithTime];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    paragraphStyle.lineSpacing = 1.0f;
    [attrStr setAttributes:@{NSParagraphStyleAttributeName: paragraphStyle}
                     range:NSMakeRange(0, [txtWithTime length])];
    
    [attrStr addAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"WhitneySSm-Book" size:14]} range:NSMakeRange(0, [txtWithTime length])];
    if (self.highlighted) {
        [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0xffffff)} range:NSMakeRange(0, [txtWithTime length])];
    } else {
        [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0x333333)} range:NSMakeRange(0, [txtWithTime length])];

    }
    
    if (![username isEqualToString:@"You"]){
        [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(NEWSBLUR_LINK_COLOR)} range:[txtWithTime rangeOfString:username]];
        [attrStr addAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13]} range:[txtWithTime rangeOfString:username]];
    }
    [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(NEWSBLUR_LINK_COLOR)} range:[txtWithTime rangeOfString:title]];
    [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0x666666)} range:[txtWithTime rangeOfString:comment]];
    [attrStr addAttributes:@{NSForegroundColorAttributeName:UIColorFromRGB(0x999999)} range:[txtWithTime rangeOfString:time]];

    [attrStr addAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"WhitneySSm-Book" size:12]} range:[txtWithTime rangeOfString:time]];
    
    NSRange commentRange = [txtWithTime rangeOfString:comment];
    if (commentRange.location != NSNotFound) {
        commentRange.location -= 2;
        commentRange.length = 1;
        if ([[txtWithTime substringWithRange:commentRange] isEqualToString:@" "]) {
            [attrStr addAttribute:NSFontAttributeName
                            value:[UIFont systemFontOfSize:6.0f]
                            range:commentRange];
        }
    }
    
    NSRange dateRange = [txtWithTime rangeOfString:time];
    if (dateRange.location != NSNotFound) {
        dateRange.location -= 2;
        dateRange.length = 1;
        [attrStr addAttribute:NSFontAttributeName
                        value:[UIFont systemFontOfSize:6.0f]
                        range:dateRange];
    }
    
    self.interactionLabel.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.interactionLabel.attributedText = attrStr;
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
