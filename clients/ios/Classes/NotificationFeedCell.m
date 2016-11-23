//
//  NotificationFeedCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "NotificationFeedCell.h"
#import "NewsBlurAppDelegate.h"

@implementation NotificationFeedCell

@synthesize appDelegate;

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
