//
//  SmallActivityCell.m
//  NewsBlur
//
//  Created by Roy Yang on 7/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "SmallActivityCell.h"
#import "NSAttributedString+Attributes.h"
#import "UIImageView+AFNetworking.h"
#import <QuartzCore/QuartzCore.h>

@implementation SmallActivityCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        activityLabel = nil;
        faviconView = nil;
        
        // create favicon and label in view
        UIImageView *favicon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.faviconView = favicon;
        [self.contentView addSubview:favicon];
        
        OHAttributedLabel *activity = [[OHAttributedLabel alloc] initWithFrame:CGRectZero];
        activity.backgroundColor = [UIColor whiteColor];
        activity.automaticallyAddLinksForType = NO;
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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.activityLabel.backgroundColor = UIColorFromRGB(0xd7dadf);
    } else {
        self.activityLabel.backgroundColor = UIColorFromRGB(0xf6f6f6);
    }
    self.activityLabel.backgroundColor = [UIColor clearColor];
}

@end
