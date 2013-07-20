/*
 *  WEPopoverParentView.h
 *  WEPopover
 *
 *  Created by Werner Altewischer on 02/09/10.
 *  Copyright 2010 Werner IT Consultancy. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol WEPopoverParentView

@optional
- (CGRect)displayAreaForPopover;

@end