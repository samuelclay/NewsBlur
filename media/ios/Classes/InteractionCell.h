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
}

@property (retain, nonatomic) OHAttributedLabel *interactionLabel;
@property (retain, nonatomic) UIImageView *avatarView;

- (int)setInteraction:(NSDictionary *)interaction withWidth:(int)width;
- (NSString *)stripFormatting:(NSString *)str;

@end