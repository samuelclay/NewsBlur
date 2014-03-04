//
//  UIView+OSKUtilities.m
//  Overshare
//
//  Created by Jared Sinclair on 10/16/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "UIView+OSKUtilities.h"

@implementation UIView (OSKUtilities)

- (void)osk_setYOrigin:(CGFloat)yOrigin {
    CGRect frame = self.frame;
    frame.origin.y = yOrigin;
    [self setFrame:frame];
}

@end
