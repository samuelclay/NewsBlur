//
//  InteractionCell.h
//  NewsBlur
//
//  Created by Roy Yang on 7/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OHAttributedLabel.h"

@interface InteractionCell : UITableViewCell {
    OHAttributedLabel *interactionLabel;
    UIImageView *avatarView;
    int topMargin;
    int bottomMargin;
    int leftMargin;
    int rightMargin;
    int avatarSize;
}

@property (retain, nonatomic) OHAttributedLabel *interactionLabel;
@property (retain, nonatomic) UIImageView *avatarView;
@property (readwrite) int topMargin;
@property (readwrite) int bottomMargin;
@property (readwrite) int leftMargin;
@property (readwrite) int rightMargin;
@property (readwrite) int avatarSize;

- (int)setInteraction:(NSDictionary *)interaction withWidth:(int)width;
- (NSString *)stripFormatting:(NSString *)str;

@end