//
//  FolderTitleView.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "UnreadCountView.h"


@class NewsBlurAppDelegate;

@interface FolderTitleView : UIView
<UIGestureRecognizerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    UIFontDescriptor *fontDescriptorSize;
}

@property (assign, nonatomic) int section;
@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) UnreadCountView *unreadCount;
@property (nonatomic) UIButton *invisibleHeaderButton;

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer;

@end
