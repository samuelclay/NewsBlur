//
//  ActivityCell.h
//  NewsBlur
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ActivityCell : UITableViewCell {
    UILabel *activityLabel;
    UIImageView *faviconView;
    int topMargin;
    int bottomMargin;
    int leftMargin;
    int rightMargin;
    int avatarSize;
}

@property (nonatomic, strong) UILabel *activityLabel;
@property (nonatomic, strong) UIImageView *faviconView;
@property (readwrite) int topMargin;
@property (readwrite) int bottomMargin;
@property (readwrite) int leftMargin;
@property (readwrite) int rightMargin;
@property (readwrite) int avatarSize;

- (int)setActivity:(NSDictionary *)activity withUserProfile:(NSDictionary *)userProfile withWidth:(int)width;
- (NSString *)stripFormatting:(NSString *)str;

@end
