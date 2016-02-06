//
//  FeedChooserViewCell.m
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "FeedChooserViewCell.h"

@implementation FeedChooserViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        // Initialization code
        self.tintColor = UIColorFromRGB(0x707070);
        self.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
        self.detailTextLabel.font = [UIFont fontWithName:@"Helvetica" size:13.0];
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
    
    self.imageView.frame = CGRectMake(10.0, 10.0, 16.0, 16.0);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    CGRect frame = self.textLabel.frame;
    frame.origin.x = 35.0;
    frame.size.width = self.detailTextLabel.frame.origin.x - self.textLabel.frame.origin.x;
    self.textLabel.frame = frame;
    
    if (self.isMuteOperation) {
        frame = self.detailTextLabel.frame;
        frame.origin.x -= 10.0;
        self.detailTextLabel.frame = frame;
    }
    
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.textLabel.textColor = UIColorFromRGB(0x303030);
    self.textLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
    self.textLabel.shadowOffset = CGSizeMake(0, 1);
    
    if (self.isMuteOperation) {
        self.textLabel.highlightedTextColor = UIColorFromRGB(0x808080);
        self.detailTextLabel.highlightedTextColor = UIColorFromRGB(0xa0a0a0);
    } else {
        self.textLabel.highlightedTextColor = UIColorFromRGB(0x303030);
        self.detailTextLabel.highlightedTextColor = UIColorFromRGB(0x505050);
    }
    
    self.detailTextLabel.textColor = UIColorFromRGB(0x505050);
    
    self.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.backgroundView.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.selectedBackgroundView.backgroundColor = UIColorFromRGB(0xECEEEA);

    CGFloat detailTextLabelWidth = self.detailTextLabel.attributedText.size.width;
    CGRect detailTextLabelFrame = self.detailTextLabel.frame;
    CGFloat detailTextLabelExtraWidth = detailTextLabelWidth - detailTextLabelFrame.size.width;
    if (detailTextLabelExtraWidth > 0) {
        detailTextLabelFrame.origin.x -= detailTextLabelExtraWidth;
        detailTextLabelFrame.size.width = detailTextLabelWidth;
        self.detailTextLabel.frame = detailTextLabelFrame;

        CGRect textLabelFrame = self.textLabel.frame;
        textLabelFrame.size.width -= detailTextLabelExtraWidth;
        self.textLabel.frame = textLabelFrame;
    }
}

@end
