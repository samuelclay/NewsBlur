//
//  SmallInteractionCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 2/21/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "SmallInteractionCell.h"
#import "NSAttributedString+Attributes.h"
#import "UIImageView+AFNetworking.h"
#import <QuartzCore/QuartzCore.h>

@implementation SmallInteractionCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        interactionLabel = nil;
        avatarView = nil;
        
        // create favicon and label in view
        UIImageView *favicon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.avatarView = favicon;
        [self.contentView addSubview:favicon];
        
        OHAttributedLabel *interaction = [[OHAttributedLabel alloc] initWithFrame:CGRectZero];
        interaction.backgroundColor = [UIColor whiteColor];
        interaction.automaticallyAddLinksForType = NO;
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
    CGRect contentRect = self.contentView.bounds;
    
    // position avatar to bounds
    self.avatarView.frame = CGRectMake(leftMargin, topMargin, avatarSize, avatarSize);
    
    // position label to bounds
    CGRect labelRect = contentRect;
    labelRect.origin.x = labelRect.origin.x + leftMargin + avatarSize + leftMargin;
    labelRect.origin.y = labelRect.origin.y + topMargin - 1;
    labelRect.size.width = contentRect.size.width - leftMargin - avatarSize - leftMargin - rightMargin;
    labelRect.size.height = contentRect.size.height - topMargin - bottomMargin;
    self.interactionLabel.frame = labelRect;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.interactionLabel.backgroundColor = UIColorFromRGB(0xd7dadf);
    } else {
        self.interactionLabel.backgroundColor = UIColorFromRGB(0xf6f6f6);
    }
    self.interactionLabel.backgroundColor = [UIColor clearColor];
}

@end
