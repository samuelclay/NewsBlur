//
//  FolderTitleView.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"


@class NewsBlurAppDelegate;

@interface FolderTitleView : UIControl {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

- (UIControl *)drawWithRect:(CGRect)rect inSection:(NSInteger)section;

@end
