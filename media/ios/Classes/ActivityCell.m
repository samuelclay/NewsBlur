//
//  ActivityCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityCell.h"

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

- (void)refreshActivity:(NSDictionary *)activity withUsername:(NSString *)username {
    self.activityLabel = [[[UILabel alloc] init] autorelease];
    self.activityLabel.frame = CGRectMake(10, 10, 280, 22);
    self.activityLabel.text = @"Tester";
    self.activityLabel.backgroundColor = [UIColor clearColor];

    NSString *category = [activity objectForKey:@"category"];
    NSString *content = [activity objectForKey:@"content"];
    NSString *title = [activity objectForKey:@"title"];
    
    if ([category isEqualToString:@"follow"]) {
        
        NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        self.activityLabel.text = [NSString stringWithFormat:@"%@ followed %@", username, withUserUsername];
        
    } else if ([category isEqualToString:@"comment_reply"]) {
        NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
        self.activityLabel.text = [NSString stringWithFormat:@"%@ replied to %@: \"%@\"", username, withUserUsername, content];
        
    } else if ([category isEqualToString:@"sharedstory"]) {
        self.activityLabel.text = [NSString stringWithFormat:@"%@ shared %@ : \"%@\"", username, title, content];
        
        // star and feedsub are always private.
    } else if ([category isEqualToString:@"star"]) {
        self.activityLabel.text = [NSString stringWithFormat:@"You saved %@", content];
        
    } else if ([category isEqualToString:@"feedsub"]) {
        
        self.activityLabel.text = [NSString stringWithFormat:@"You subscribed to %@", content];
    }
    
    self.activityLabel.font = [UIFont systemFontOfSize:12];

    
    [self addSubview:self.activityLabel];
}

@end
