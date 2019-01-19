//
//  EventWindow.h
//  NewsBlur
//
//  Created by Samuel Clay on 9/17/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EventWindow : UIWindow {
    CGPoint    tapLocation;
    NSTimer    *contextualMenuTimer;
    BOOL       unmoved;
    UIView     *tapDetectingView;
}

@property (nonatomic) UIView *tapDetectingView;

@end
