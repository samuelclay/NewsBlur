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
    NBFeedListSaved = 3,
    NBFeedListFolder = 4
} NBFeedListType;

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (assign, nonatomic) NSInteger psWidth;
@property (assign, nonatomic) NSInteger psPadding;
@property (assign, nonatomic) NSInteger ntWidth;
@property (assign, nonatomic) NSInteger ntPadding;
@property (assign, nonatomic) NSInteger psCount;
@property (assign, nonatomic) NSInteger ntCount;
@property (assign, nonatomic) NSInteger blueCount;
@property (assign, nonatomic) CGRect rect;

- (void)drawInRect:(CGRect)r ps:(NSInteger)ps nt:(NSInteger)nt listType:(NBFeedListType)listType;
- (void)calculateOffsets:(NSInteger)ps nt:(NSInteger)nt;
- (NSInteger)offsetWidth;

@end
