//
//  UnreadCountView.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/3/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@class NewsBlurAppDelegate;

@interface UnreadCountView : UIView

typedef enum {
    NBFeedListFeed = 1,
    NBFeedListSocial = 2,
    NBFeedListFolder = 3
} NBFeedListType;

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (assign, nonatomic) int psWidth;
@property (assign, nonatomic) int psPadding;
@property (assign, nonatomic) int ntWidth;
@property (assign, nonatomic) int ntPadding;
@property (assign, nonatomic) CGRect rect;

- (void)drawInRect:(CGRect)r ps:(int)ps nt:(int)nt listType:(NBFeedListType)listType;
- (int)offsetWidth;

@end
