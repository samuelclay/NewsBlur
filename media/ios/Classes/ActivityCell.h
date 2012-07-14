//
//  ActivityCell.h
//  NewsBlur
//
//  Created by Roy Yang on 7/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OHAttributedLabel.h"

@interface ActivityCell : UIView {
    OHAttributedLabel *activityLabel;
}

@property (retain, nonatomic) OHAttributedLabel *activityLabel;

- (int)refreshActivity:(NSDictionary *)activity withUsername:(NSString *)username;

@end
