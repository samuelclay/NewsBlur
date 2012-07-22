//
//  SmallActivityCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "SmallActivityCell.h"

@implementation SmallActivityCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)layoutSubviews {
    #define topMargin 10
    #define bottomMargin 10
    #define leftMargin 10
    #define rightMargin 10
    #define avatarSize 32
    
    [super layoutSubviews];
    
    // determine outer bounds
    CGRect contentRect = self.contentView.bounds;
    
    // position avatar to bounds
    self.faviconView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    // position label to bounds
    CGRect labelRect = contentRect;
    labelRect.origin.x = labelRect.origin.x + leftMargin + avatarSize + leftMargin;
    labelRect.origin.y = labelRect.origin.y + topMargin - 1;
    labelRect.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin;
    labelRect.size.height = contentRect.size.height - topMargin - bottomMargin;
    self.activityLabel.frame = labelRect;
    self.activityLabel.backgroundColor = self.superview.backgroundColor;
}

@end
