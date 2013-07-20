//
// Created by Jesper Kamstrup Linnet on 14/07/13.
// Copyright (c) 2013 NewsBlur. All rights reserved.
//


#import <Foundation/Foundation.h>

@class MBProgressHUD;


@interface CheckmarkHud : NSObject

- (void)flashCheckmarkHud:(NSString *)messageType onView:(UIView *)view;

@end