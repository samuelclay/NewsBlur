//
//  ActivityCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityCell.h"
#import "NSAttributedString+Attributes.h"

@implementation ActivityCell

@synthesize activityLabel;

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


- (int)refreshActivity:(NSDictionary *)activity withUsername:(NSString *)username withWidth:(int)width {
    self.activityLabel = [[OHAttributedLabel alloc] init];
    self.activityLabel.frame = CGRectMake(10, 10, width - 20, 120);
    self.activityLabel.backgroundColor = [UIColor clearColor];
    self.activityLabel.automaticallyAddLinksForType = NO;

    NSString *category = [activity objectForKey:@"category"];
    NSString *content = [activity objectForKey:@"content"];
    NSString *title = [self stripFormatting:[NSString stringWithFormat:@"%@", [activity objectForKey:@"title"]]];
    
    if ([category isEqualToString:@"follow"]) {

        NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];

        NSString* txt = [NSString stringWithFormat:@"%@ followed %@", username, withUserUsername];        
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        // for those calls we don't specify a range so it affects the whole string
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:withUserUsername]];
        [attrStr setTextBold:YES range:[txt rangeOfString:withUserUsername]];
                
        self.activityLabel.attributedText = attrStr;
                
    } else if ([category isEqualToString:@"comment_reply"]) {
        NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
        NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        
        NSString* txt = [NSString stringWithFormat:@"%@ replied to %@: %@", username, withUserUsername, comment];  
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:withUserUsername]];
        [attrStr setTextBold:YES range:[txt rangeOfString:withUserUsername]];
 
        [attrStr setTextColor:UIColorFromRGB(0x999999) range:[txt rangeOfString:comment]];  

        self.activityLabel.attributedText = attrStr;
        
    } else if ([category isEqualToString:@"comment_like"]) {
        NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
        NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        NSString* txt = [NSString stringWithFormat:@"%@ favorited %@'s comment on %@: %@", username, withUserUsername, title, comment];
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:withUserUsername]];
        [attrStr setTextBold:YES range:[txt rangeOfString:withUserUsername]];
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:title]];

        [attrStr setTextColor:UIColorFromRGB(0x999999) range:[txt rangeOfString:comment]];        
        
        self.activityLabel.attributedText = attrStr;
        
        
    } else if ([category isEqualToString:@"sharedstory"]) {
        NSString *comment = [NSString stringWithFormat:@"\"%@\"", content];
        NSString *txt = [NSString stringWithFormat:@"%@ shared %@: %@", username, title, comment];
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:title]];
                
        [attrStr setTextColor:UIColorFromRGB(0x666666) range:[txt rangeOfString:comment]]; 
        self.activityLabel.attributedText = attrStr;
        
    // star and feedsub are always private.
    } else if ([category isEqualToString:@"star"]) {
        NSString *txt = [NSString stringWithFormat:@"%@ saved %@: %@", content];
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:content]];
        
        self.activityLabel.attributedText = attrStr;
    } else if ([category isEqualToString:@"feedsub"]) {
        NSString *txt = [NSString stringWithFormat:@"You subscribed to %@", content];
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];

        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:content]];
        self.activityLabel.attributedText = attrStr;
    }
    
    [self.activityLabel sizeToFit];
    
    [self addSubview:self.activityLabel];
    
    int height = self.activityLabel.frame.size.height;
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
