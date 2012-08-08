//
//  InteractionCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "InteractionCell.h"
#import "NSAttributedString+Attributes.h"
#import "UIImageView+AFNetworking.h"

@implementation InteractionCell

@synthesize interactionLabel;
@synthesize avatarView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        interactionLabel = nil;
        avatarView = nil;
        
        // create the label and the avatar
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.avatarView = avatar;
        [self.contentView addSubview:avatar];
        
        OHAttributedLabel *interaction = [[OHAttributedLabel alloc] initWithFrame:CGRectZero];
        interaction.backgroundColor = [UIColor whiteColor];
        interaction.automaticallyAddLinksForType = NO;
        self.interactionLabel = interaction;
        [self.contentView addSubview:interaction];
    }
    
    return self;
}

- (void)layoutSubviews {
    #define topMargin 15
    #define bottomMargin 15
    #define leftMargin 20
    #define rightMargin 20
    #define avatarSize 48
    
    [super layoutSubviews];
    
    // determine outer bounds
    CGRect contentRect = self.contentView.bounds;
                
    // position label to bounds
    CGRect labelRect = contentRect;
    labelRect.origin.x = labelRect.origin.x + leftMargin + avatarSize + leftMargin;
    labelRect.origin.y = labelRect.origin.y + topMargin - 1;
    labelRect.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin;
    labelRect.size.height = contentRect.size.height - topMargin - bottomMargin;
    self.interactionLabel.frame = labelRect;
}


- (int)setInteraction:(NSDictionary *)interaction withWidth:(int)width {
    // must set the height again for dynamic height in heightForRowAtIndexPath in 
    CGRect interactionLabelRect = self.interactionLabel.bounds;
    interactionLabelRect.size.width = width - leftMargin - avatarSize - leftMargin - rightMargin;
    interactionLabelRect.size.height = 300;
    
    self.interactionLabel.frame = interactionLabelRect;
    self.avatarView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    UIImage *placeholder = [UIImage imageNamed:@"user_dark"];
    
    // this is for the rare instance when the with_user doesn't return anything
    if ([[interaction objectForKey:@"with_user"] class] == [NSNull class]) {
        return 1;
    }
    
    [self.avatarView setImageWithURL:[NSURL URLWithString:[[interaction objectForKey:@"with_user"] objectForKey:@"photo_url"]]
        placeholderImage:placeholder];
        
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
        txt = [NSString stringWithFormat:@"%@ replied to your comment on %@:\n%@", username, title, comment];          
    } else if ([category isEqualToString:@"reply_reply"]) {
        txt = [NSString stringWithFormat:@"%@ replied to your reply on %@:\n%@", username, title, comment];  
    } else if ([category isEqualToString:@"story_reshare"]) {
        if ([content isEqualToString:@""] || content == nil) {
            txt = [NSString stringWithFormat:@"%@ re-shared %@.", username, title];
        } else {
            txt = [NSString stringWithFormat:@"%@ re-shared %@:\n%@", username, title, comment];
        }
    } else if ([category isEqualToString:@"comment_like"]) {
        txt = [NSString stringWithFormat:@"%@ favorited your comments on %@:\n%@", username, title, comment]; 
    }
    
    NSString *txtWithTime = [NSString stringWithFormat:@"%@\n%@", txt, time];
    NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txtWithTime];
    
    // for those calls we don't specify a range so it affects the whole string
    [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
    if (self.highlighted) {
        [attrStr setTextColor:UIColorFromRGB(0xffffff)];        
    } else {
        [attrStr setTextColor:UIColorFromRGB(0x333333)];

    }
    
    if (![username isEqualToString:@"You"]){
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txtWithTime rangeOfString:username]];
        [attrStr setTextBold:YES range:[txt rangeOfString:username]];
    }
    
    [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txtWithTime rangeOfString:title]];
    [attrStr setTextColor:UIColorFromRGB(0x666666) range:[txtWithTime rangeOfString:comment]]; 
        
    [attrStr setTextColor:UIColorFromRGB(0x999999) range:[txtWithTime rangeOfString:time]];
    [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:10] range:[txtWithTime rangeOfString:time]];
    [attrStr setTextAlignment:kCTLeftTextAlignment lineBreakMode:kCTLineBreakByWordWrapping lineHeight:4];
    
    self.interactionLabel.attributedText = attrStr; 
    
    [self.interactionLabel sizeToFit];
    
    int height = self.interactionLabel.frame.size.height;
    
    return height;
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