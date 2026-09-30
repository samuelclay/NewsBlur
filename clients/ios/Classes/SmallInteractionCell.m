//
//  SmallInteractionCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 2/21/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "SmallInteractionCell.h"
#import "UIImageView+AFNetworking.h"
#import <QuartzCore/QuartzCore.h>
#import "NewsBlurAppDelegate.h"

@implementation SmallInteractionCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.separatorInset = UIEdgeInsetsMake(0, 52, 0, 0);
        self.backgroundColor = UIColorFromRGB(0xffffff);
        self.interactionLabel.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
        
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
    
    // SmallInteractionCell.m inherits content-area sizing from InteractionCell.m with its smaller margins and avatar.
    if (!((NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]).isPhone) {
        self.interactionLabel.backgroundColor = UIColorFromRGB(0xd7dadf);
    } else {
        self.interactionLabel.backgroundColor = UIColorFromRGB(0xf6f6f6);
    }
    self.interactionLabel.backgroundColor = [UIColor clearColor];
}

@end
