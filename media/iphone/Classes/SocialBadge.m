//
//  SocialBadge.m
//  NewsBlur
//
//  Created by Roy Yang on 7/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "SocialBadge.h"
#import "NewsBlurAppDelegate.h"

@implementation SocialBadge

@synthesize appDelegate;
@synthesize userAvatar;
@synthesize username = _username;
@synthesize userLocation;
@synthesize userDescription;
@synthesize userStats;
@synthesize followButton;

- (void)baseInit {
    username = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 200, 20)];
    NSLog(@"in baseInit");
    [self setNeedsLayout];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self baseInit];
    }
    return self;
}


- (void)dealloc {
    [appDelegate release];
    [userAvatar release];
    [username release];
    [userLocation release];
    [userDescription release];
    [userStats release];
    [followButton release];
    [super dealloc];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)layoutSubviews {
    [super layoutSubviews];    
    [username setText:@"Royus!"];
    
    // Relayout and refresh
//    [self setNeedsLayout];
}
    

@end
