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
        self.destructive = NO;
        self.textLabel.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:15.0];
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
- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat indent = self.indentationLevel * self.indentationWidth;
    
    self.imageView.bounds = CGRectMake(indent, 0, self.frame.size.height, self.frame.size.height);
    self.imageView.frame = CGRectMake(indent, 0, self.frame.size.height, self.frame.size.height);
    self.imageView.contentMode = UIViewContentModeCenter;
    
    self.textLabel.frame = CGRectMake(indent + self.imageView.frame.size.width, 0,
                                      self.frame.size.width - self.imageView.frame.size.width - indent,
                                      self.frame.size.height);
    
    if (self.destructive) {
        self.textLabel.textColor = UIColorFromFixedRGB(0xff0000);
        self.textLabel.highlightedTextColor = UIColorFromFixedRGB(0xff0000);
    } else {
        self.textLabel.textColor = UIColorFromRGB(0x303030);
        self.textLabel.highlightedTextColor = UIColorFromRGB(0x303030);
    }
    
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.textLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
    self.textLabel.shadowOffset = CGSizeMake(0, 1);
    self.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.backgroundView.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.selectedBackgroundView.backgroundColor = UIColorFromRGB(0xECEEEA);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];    
}

@end
