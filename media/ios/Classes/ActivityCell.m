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

- (void)dealloc {
    [activityLabel release];
    [super dealloc];
}

- (int)refreshActivity:(NSDictionary *)activity withUsername:(NSString *)username {
    self.activityLabel = [[[OHAttributedLabel alloc] init] autorelease];
    self.activityLabel.frame = CGRectMake(10, 10, 280, 80);
    self.activityLabel.backgroundColor = [UIColor clearColor];

    NSString *category = [activity objectForKey:@"category"];
    NSString *content = [activity objectForKey:@"content"];
    NSString *title = [activity objectForKey:@"title"];
    
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
        NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        
        NSString* txt = [NSString stringWithFormat:@"%@ replied to %@:\n\"%@\"", username, withUserUsername, content];  
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:withUserUsername]];
        [attrStr setTextBold:YES range:[txt rangeOfString:withUserUsername]];
 
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:13] range:[txt rangeOfString:content]];

        self.activityLabel.attributedText = attrStr;
        
    } else if ([category isEqualToString:@"sharedstory"]) {
        NSString* txt = [NSString stringWithFormat:@"%@ shared %@:\n\"%@\"", username, title, content];
        NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithString:txt];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [attrStr setTextColor:UIColorFromRGB(0x333333)];
        
        if (![username isEqualToString:@"You"]){
            [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:username]];
            [attrStr setTextBold:YES range:[txt rangeOfString:username]];
        }
        
        [attrStr setTextColor:UIColorFromRGB(NEWSBLUR_ORANGE) range:[txt rangeOfString:title]];
        
        [attrStr setFont:[UIFont fontWithName:@"Helvetica" size:13] range:[txt rangeOfString:content]];
        
        self.activityLabel.attributedText = attrStr;
        
        // star and feedsub are always private.
    } else if ([category isEqualToString:@"star"]) {
        self.activityLabel.text = [NSString stringWithFormat:@"You saved %@", content];
        
    } else if ([category isEqualToString:@"feedsub"]) {
        
        self.activityLabel.text = [NSString stringWithFormat:@"You subscribed to %@", content];
    }
    
    [self.activityLabel sizeToFit];
    
    [self addSubview:self.activityLabel];
    
    int height = self.activityLabel.frame.size.height;
    return height;
}

@end
