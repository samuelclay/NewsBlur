//
//  SiteCell.h
//  NewsBlur
//
//  Created by Roy Yang on 8/14/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ABTableViewCell.h"
#import "NewsBlur-Swift.h"

@interface SiteCell : ABTableViewCell {
    NewsBlurAppDelegate *appDelegate;
    // River view    
    NSString *siteTitle;
    UIImage *siteFavicon;
    UIColor *feedColorBar;
    UIColor *feedColorBarTopBorder;
    
    BOOL hasAlpha;
    BOOL isRead;
}

@property (nonatomic) NSString *siteTitle;
@property (nonatomic) UIImage *siteFavicon;
@property (nonatomic) UIColor *feedColorBar;
@property (nonatomic) UIColor *feedColorBarTopBorder;

@property (readwrite) BOOL hasAlpha;
@property (readwrite) BOOL isRead;

- (UIImage *)imageByApplyingAlpha:(UIImage *)image withAlpha:(CGFloat) alpha;

@end
