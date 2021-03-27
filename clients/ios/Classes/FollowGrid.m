//
//  FollowGrid.m
//  NewsBlur
//
//  Created by Roy Yang on 8/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FollowGrid.h"

@implementation FollowGrid

@synthesize appDelegate;

@synthesize profiles;
@synthesize followList;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        profiles = nil;
        followList = nil;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)refreshWithWidth:(int)width {
    // username
    UILabel *user = [[UILabel alloc] initWithFrame:CGRectZero];
    user.textColor = UIColorFromRGB(NEWSBLUR_LINK_COLOR);
    user.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:11];
    user.backgroundColor = [UIColor clearColor];
    user.frame = CGRectMake(0, 10, 100, 22);
    user.text = @"roy"; 
    [self.contentView addSubview:user];
}

@end
