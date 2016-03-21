//
//  InteractionCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "InteractionCell.h"
#import "UIImageView+AFNetworking.h"
#import <CoreText/CoreText.h>

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
    }
    
    return self;
}

- (void)layoutSubviews {    
    [super layoutSubviews];
    
    // determine outer bounds
    [self.interactionLabel sizeToFit];
    CGRect contentRect = self.frame;
    CGRect labelFrame = self.interactionLabel.frame;
    
    // position avatar to bounds
    self.avatarView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    // position label to bounds
    labelFrame.origin.x = leftMargin*2 + avatarSize;
    labelFrame.origin.y = 0;
    labelFrame.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin - 20;
    labelFrame.size.height = contentRect.size.height;
    self.interactionLabel.frame = labelFrame;
}


- (int)setInteraction:(NSDictionary *)interaction withWidth:(int)width {
    // must set the height again for dynamic height in heightForRowAtIndexPath in 
    CGRect interactionLabelRect = self.interactionLabel.bounds;
    interactionLabelRect.size.width = width - leftMargin - avatarSize - leftMargin - rightMargin;
    interactionLabelRect.size.height = 300;

    self.interactionLabel.frame = interactionLabelRect;
    self.interactionLabel.numberOfLines = 0;
    self.avatarView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    // this is for the rare instance when the with_user doesn't return anything
    if ([[interaction objectForKey:@"with_user"] class] == [NSNull class]) {
        return 1;
    }
    
    [self.avatarView setImageWithURL:[NSURL URLWithString:[[interaction objectForKey:@"with_user"] objectForKey:@"photo_url"]]
        placeholderImage:nil ];
        
    NSString *category = [interaction objectForKey:@"category"];
    NSString *content = [interaction objectForKey:@"content"];
    NSString *title = [self stripFormatting:[NSString stringWithFormat:@"%@", [interaction objectForKey:@"title"]]];
    NSString *username = [[interaction objectForKey:@"with_user"] objectForKey:@"username"];
    NSString *time = [[NSString stringWithFormat:@"%@ ago", [interaction objectForKey:@"time_since"]] uppercaseString];
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
    
    [attrStr addAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:13]} range:NSMakeRange(0, [txtWithTime length])];
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

    [attrStr addAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:11]} range:[txtWithTime rangeOfString:time]];
    
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
    [self.interactionLabel sizeToFit];
    
    int height = self.interactionLabel.frame.size.height;
    
    return MAX(height + topMargin + bottomMargin, self.avatarView.frame.size.height + topMargin + bottomMargin);
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