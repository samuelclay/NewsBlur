/*
 *  UIBarButtonItem+WEPopover.h
 *  WEPopover
 *
 *  Created by Werner Altewischer on 07/05/11.
 *  Copyright 2010 Werner IT Consultancy. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIBarButtonItem(WEPopover)

- (CGRect)frameInView:(UIView *)v;
- (UIView *)superview;

@end
