//
//  ActivityCell.h
//  NewsBlur
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OHAttributedLabel.h"

@interface ActivityCell : UITableViewCell {
    OHAttributedLabel *activityLabel;
    UIImageView *faviconView;
}

@property (nonatomic, strong) OHAttributedLabel *activityLabel;
@property (nonatomic, strong) UIImageView *faviconView;

- (int)setActivity:(NSDictionary *)activity withUsername:(NSString *)username withWidth:(int)width;
- (NSString *)stripFormatting:(NSString *)str;

@end
