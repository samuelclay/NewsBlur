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

@implementation SmallInteractionCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        interactionLabel = nil;
        avatarView = nil;
        self.separatorInset = UIEdgeInsetsMake(0, 52, 0, 0);
        
        // create favicon and label in view
        UIImageView *favicon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.avatarView = favicon;
        [self.contentView addSubview:favicon];
        
        UILabel *interaction = [[UILabel alloc] initWithFrame:CGRectZero];
        interaction.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
        self.interactionLabel = interaction;
        [self.contentView addSubview:interaction];
        
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
    [self.interactionLabel sizeToFit];
    CGRect contentRect = self.frame;
    CGRect labelFrame = self.interactionLabel.frame;
    
    // position avatar to bounds
    self.avatarView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    // position label to bounds
    labelFrame.origin.x = leftMargin*2 + avatarSize;
    labelFrame.origin.y = 0;
    labelFrame.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin - 20;
    labelFrame.size.height = contentRect.size.height;
    self.interactionLabel.frame = labelFrame;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.interactionLabel.backgroundColor = UIColorFromRGB(0xd7dadf);
    } else {
        self.interactionLabel.backgroundColor = UIColorFromRGB(0xf6f6f6);
    }
    self.interactionLabel.backgroundColor = [UIColor clearColor];
}

@end
