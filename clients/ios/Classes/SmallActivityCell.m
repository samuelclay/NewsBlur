//
//  SmallActivityCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "SmallActivityCell.h"
#import "UIImageView+AFNetworking.h"
#import <QuartzCore/QuartzCore.h>

@implementation SmallActivityCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        activityLabel = nil;
        faviconView = nil;
        self.separatorInset = UIEdgeInsetsMake(0, 52, 0, 0);
        
        // create favicon and label in view
        UIImageView *favicon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.faviconView = favicon;
        [self.contentView addSubview:favicon];
        
        UILabel *activity = [[UILabel alloc] initWithFrame:CGRectZero];
        activity.backgroundColor = UIColorFromRGB(0xffffff);
        self.activityLabel = activity;
        [self.contentView addSubview:activity];
        
        topMargin = 10;
        bottomMargin = 10;
        leftMargin = 10;
        rightMargin = 10;
        avatarSize = 32;
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // determine outer bounds
    [self.activityLabel sizeToFit];
    CGRect contentRect = self.frame;
    CGRect labelFrame = self.activityLabel.frame;
    
    // position avatar to bounds
    self.faviconView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    // position label to bounds
    labelFrame.origin.x = leftMargin*2 + avatarSize;
    labelFrame.origin.y = 0;
    labelFrame.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin - 20;
    labelFrame.size.height = contentRect.size.height;
    self.activityLabel.frame = labelFrame;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.activityLabel.backgroundColor = UIColorFromRGB(0xd7dadf);
    } else {
        self.activityLabel.backgroundColor = UIColorFromRGB(0xf6f6f6);
    }
    self.backgroundColor = [UIColor clearColor];
    self.activityLabel.backgroundColor = [UIColor clearColor];
}

@end
