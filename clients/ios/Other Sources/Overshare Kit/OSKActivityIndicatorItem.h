//
//  OSKActivityIndicatorItem.h
//  Overshare
//
//  Created by Jared Sinclair on 10/19/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

typedef NS_ENUM(NSInteger, OSKActivityIndicatorItemPosition) {
    OSKActivityIndicatorItemPosition_Right,
    OSKActivityIndicatorItemPosition_Left,
};

@interface OSKActivityIndicatorItem : UIBarButtonItem

@property (assign, nonatomic) OSKActivityIndicatorItemPosition position;

+ (instancetype)item:(UIActivityIndicatorViewStyle)style;
- (void)startSpinning;
- (void)stopSpinning;

@end
