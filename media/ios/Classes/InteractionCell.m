//
//  InteractionCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "InteractionCell.h"
#import "NSAttributedString+Attributes.h"

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
    self.interactionLabel = [[OHAttributedLabel alloc] init];
    self.interactionLabel.frame = CGRectMake(10, 10, width - 20, 120);
    self.interactionLabel.backgroundColor = [UIColor clearColor];
    self.interactionLabel.automaticallyAddLinksForType = NO;
    
    NSString *category = [interaction objectForKey:@"category"];
    NSString *content = [interaction objectForKey:@"content"];
    NSString *title = [self stripFormatting:[NSString stringWithFormat:@"%@", [interaction objectForKey:@"title"]]];
    NSString *username = [[interaction objectForKey:@"with_user"] objectForKey:@"username"];
    
    if ([category isEqualToString:@"follow"]) {        
        NSString* txt = [NSString stringWithFormat:@"%@ is now following you", username];        
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        // for those calls we don't specify a range so it affects the whole string
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
        [attrStr setTextBold:YES range:[txt rangeOfString:username]];
                
        self.interactionLabel.attributedText = attrStr;
        
    } else if ([category isEqualToString:@"comment_reply"]) {
        NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
        
        NSString* txt = [NSString stringWithFormat:@"%@ replied to your comment: %@", username, comment];  
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
            
        [attrStr setTextColor:UIColorFromRGB(0x999999) range:[txt rangeOfString:comment]];  
        
        self.interactionLabel.attributedText = attrStr;
        
    } else if ([category isEqualToString:@"reply_reply"]) {
        NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
        
        NSString* txt = [NSString stringWithFormat:@"%@ replied to your reply: %@", username, comment];  
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
                
        [attrStr setTextColor:UIColorFromRGB(0x999999) range:[txt rangeOfString:comment]];  
        
        self.interactionLabel.attributedText = attrStr;
        
    } else if ([category isEqualToString:@"story_reshare"]) {
        NSString *txt;
        NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
        if (![content isEqualToString:@""]) {
            txt = [NSString stringWithFormat:@"%@ re-shared %@: %@", username, title, comment];
        } else {
            txt = [NSString stringWithFormat:@"%@ re-shared %@.", username, title];
        }
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:title]];
        [attrStr setTextColor:UIColorFromRGB(0x666666) range:[txt rangeOfString:comment]]; 

        self.interactionLabel.attributedText = attrStr;        
    }
    
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