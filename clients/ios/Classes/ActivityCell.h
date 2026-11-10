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
// ActivityCell.h takes the avatar frame measured from the left edge; ActivityCell.m mirrors it right to left.
@property (nonatomic) CGRect faviconLeftToRightFrame;

+ (BOOL)shouldCollapseActivity:(NSDictionary *)activity;
- (void)setActivity:(NSDictionary *)activity withUserProfile:(NSDictionary *)userProfile;
- (NSString *)stripFormatting:(NSString *)str;

@end
