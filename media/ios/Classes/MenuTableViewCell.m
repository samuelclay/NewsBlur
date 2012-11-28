//
//  MenuTableViewCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "MenuTableViewCell.h"

@implementation MenuTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.textLabel.textColor = UIColorFromRGB(0x303030);
        self.textLabel.shadowColor = UIColorFromRGB(0xF0FFF0);
        self.textLabel.shadowOffset = CGSizeMake(0, 1);
        self.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
        UIView *background = [[UIView alloc] init];
        [background setBackgroundColor:UIColorFromRGB(0xBAE3A8)];
        [self setBackgroundView:background];
        
        UIView *selectedBackground = [[UIView alloc] init];
        [selectedBackground setBackgroundColor:UIColorFromRGB(0x639510)];
        [self setSelectedBackgroundView:selectedBackground];

    }
    if (self.selected) {
        self.textLabel.shadowColor = [UIColor blackColor];
    } else {
        self.textLabel.shadowColor = UIColorFromRGB(0xF0FFF0);
    }

    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    if (selected) {
        self.textLabel.shadowColor = [UIColor blackColor];
        self.textLabel.textColor = UIColorFromRGB(0xF0FFF0);
    } else {
//        self.textLabel.shadowColor = UIColorFromRGB(0xF0FFF0);
        self.textLabel.textColor = UIColorFromRGB(0x303030);
    }
    
    [super setSelected:selected animated:animated];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    
    if (highlighted) {
        self.textLabel.shadowColor = [UIColor blackColor];
        self.textLabel.textColor = UIColorFromRGB(0xF0FFF0);
    } else {
        self.textLabel.shadowColor = UIColorFromRGB(0xF0FFF0);
        self.textLabel.textColor = UIColorFromRGB(0x303030);
    }
    
    [super setHighlighted:highlighted animated:animated];
}

@end
