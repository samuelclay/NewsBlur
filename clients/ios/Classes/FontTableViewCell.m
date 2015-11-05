//
//  FontTableViewCell.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-10-30.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "FontTableViewCell.h"

@implementation FontTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.textLabel.textColor = UIColorFromRGB(0x303030);
        self.textLabel.highlightedTextColor = UIColorFromRGB(0x303030);
        self.textLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
        self.textLabel.shadowOffset = CGSizeMake(0, 1);
        self.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
        [self setSeparatorInset:UIEdgeInsetsMake(0, 38, 0, 0)];
        UIView *background = [[UIView alloc] init];
        [background setBackgroundColor:UIColorFromRGB(0xFFFFFF)];
        [self setBackgroundView:background];
        
        UIView *selectedBackground = [[UIView alloc] init];
        [selectedBackground setBackgroundColor:UIColorFromRGB(0xECEEEA)];
        [self setSelectedBackgroundView:selectedBackground];
    }
    
    return self;
}

@end
