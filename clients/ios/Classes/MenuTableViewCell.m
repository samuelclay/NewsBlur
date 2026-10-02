//
//  MenuTableViewCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "MenuTableViewCell.h"

@implementation MenuTableViewCell

+ (UIFont *)menuFont {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:
            [UIFont fontWithName:@"WhitneySSm-Medium" size:16] ?: [UIFont systemFontOfSize:16]];
}

+ (UIColor *)menuBackgroundColor {
    return UIColorFromLightSepiaMediumDarkRGB(0xFFFFFF, 0xFAF5ED, 0x444444, 0x222222);
}

+ (UIColor *)menuTextColor {
    return UIColorFromLightSepiaMediumDarkRGB(0x303030, 0x4B4238, 0xE0E0E0, 0xDDDDDD);
}

+ (UIColor *)menuIconColor {
    return UIColorFromLightSepiaMediumDarkRGB(0x8C8C8C, 0x8C8C8C, 0xBFBFBF, 0xBFBFBF);
}

+ (UIColor *)menuSeparatorColor {
    return UIColorFromLightSepiaMediumDarkRGB(0xDADCD8, 0xDED3C3, 0x5C5C5C, 0x3E3E3E);
}

+ (CGFloat)heightForTitle:(NSString *)title width:(CGFloat)width {
    CGRect text = [title boundingRectWithSize:CGSizeMake(MAX(44, width - 80), CGFLOAT_MAX)
                                    options:NSStringDrawingUsesLineFragmentOrigin
                                 attributes:@{NSFontAttributeName: self.menuFont} context:nil];
    return MAX(44, ceil(text.size.height) + 22);
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.destructive = NO;
        self.textLabel.font = MenuTableViewCell.menuFont;
        self.textLabel.numberOfLines = 0;
        self.textLabel.adjustsFontForContentSizeCategory = YES;
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
    
    // MenuTableViewCell.m gives every menu the same monochrome icon column and readable action spacing.
    self.imageView.frame = CGRectMake(16 + indent, (self.contentView.bounds.size.height - 20) / 2, 20, 20);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.image = [self.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.imageView.tintColor = MenuTableViewCell.menuIconColor;
    
    self.textLabel.frame = CGRectMake(48 + indent, 0,
                                     MAX(0, self.contentView.bounds.size.width - 64 - indent),
                                     self.contentView.bounds.size.height);
    
    if (self.destructive) {
        self.textLabel.textColor = UIColorFromFixedRGB(0xff0000);
        self.textLabel.highlightedTextColor = UIColorFromFixedRGB(0xff0000);
    } else {
        self.textLabel.textColor = MenuTableViewCell.menuTextColor;
        self.textLabel.highlightedTextColor = MenuTableViewCell.menuTextColor;
    }
    
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.textLabel.shadowColor = nil;
    self.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    self.backgroundView.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    self.selectedBackgroundView.backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xECEEEA, 0xEFE4D5, 0x555555, 0x333333);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];    
}

@end
