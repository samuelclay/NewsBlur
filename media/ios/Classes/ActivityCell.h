//
//  ActivityCell.h
//  NewsBlur
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ActivityCell : UIView {
    UILabel *activityLabel;
}

@property (retain, nonatomic) UILabel *activityLabel;

- (void)refreshActivity:(NSDictionary *)activity withUsername:(NSString *)username;

@end
