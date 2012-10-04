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

@interface FolderTitleView : UIView {
    NewsBlurAppDelegate *appDelegate;
}

@property (assign, nonatomic) int section;
@property (nonatomic) NewsBlurAppDelegate *appDelegate;

@end
