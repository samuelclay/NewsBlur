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
#import "Utilities.h"

@implementation InteractionCell

@synthesize interactionLabel;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect
 {
 // Drawing code
 }
 */

- (int)refreshInteraction:(NSDictionary *)interaction withWidth:(int)width {    
    UIImageView *avatarView = [[UIImageView alloc] init];
    UIImage *placeholder = [UIImage imageNamed:@"user"];
    [avatarView setImageWithURL:[NSURL URLWithString:[[interaction objectForKey:@"with_user"] objectForKey:@"photo_url"]]
        placeholderImage:placeholder];
    
    avatarView.frame = CGRectMake(20, 15, 48, 48);
    [self addSubview:avatarView];

    self.interactionLabel = [[OHAttributedLabel alloc] init];
    self.interactionLabel.frame = CGRectMake(83, 14, 365, 120);
    self.interactionLabel.backgroundColor = [UIColor clearColor];
    self.interactionLabel.automaticallyAddLinksForType = NO;
    
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
        txt = [NSString stringWithFormat:@"%@ replied to your comment:\n%@", username, comment];          
    } else if ([category isEqualToString:@"reply_reply"]) {
        txt = [NSString stringWithFormat:@"%@ replied to your reply:\n%@", username, comment];  
    } else if ([category isEqualToString:@"story_reshare"]) {
        if ([content isEqualToString:@""] || content == nil) {
            txt = [NSString stringWithFormat:@"%@ re-shared %@.", username, title];
        } else {
            txt = [NSString stringWithFormat:@"%@ re-shared %@:\n%@", username, title, comment];
        }
    }
    
    NSString *txtWithTime = [NSString stringWithFormat:@"%@\n%@", txt, time];
    NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txtWithTime];

    [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
    [attrStr setTextColor:UIColorFromRGB(0x333333)];
    
    if (![username isEqualToString:@"You"]){
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txtWithTime rangeOfString:username]];
        [attrStr setTextBold:YES range:[txt rangeOfString:username]];
    }
    
    [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txtWithTime rangeOfString:title]];
    [attrStr setTextColor:UIColorFromRGB(0x666666) range:[txtWithTime rangeOfString:comment]]; 
        
    [attrStr setTextColor:UIColorFromRGB(0x999999) range:[txtWithTime rangeOfString:time]];
    [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:10] range:[txtWithTime rangeOfString:time]];

    self.interactionLabel.attributedText = attrStr; 
    

    [self.interactionLabel sizeToFit];
    
    
    [self addSubview:self.interactionLabel];
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