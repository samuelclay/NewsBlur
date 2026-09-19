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
#import "NewsBlurAppDelegate.h"

@implementation SmallActivityCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.separatorInset = UIEdgeInsetsMake(0, 52, 0, 0);
        self.backgroundColor = UIColorFromRGB(0xFFFFFF);
        UIView *bgView = [[UIView alloc] init];
        bgView.backgroundColor = UIColorFromRGB(0xffffff);
        self.backgroundView = bgView;
//        self.contentView.backgroundColor = [UIColor clearColor];

        topMargin = 10;
        bottomMargin = 10;
        leftMargin = 10;
        rightMargin = 10;
        avatarSize = 32;
        [self setNeedsUpdateConstraints];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // SmallActivityCell.m inherits ActivityCell.m's content-area label sizing with its smaller margins.
    // position avatar to bounds
    self.faviconView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    if (!((NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]).isPhone) {
        self.activityLabel.backgroundColor = UIColorFromRGB(0xd7dadf);
    } else {
        self.activityLabel.backgroundColor = UIColorFromRGB(0xf6f6f6);
    }
    self.backgroundColor = [UIColor clearColor];
    self.activityLabel.backgroundColor = [UIColor clearColor];
}

@end
