//
//  FeedTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/18/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "UnreadCountView.h"
#import "ABTableViewCell.h"

@class NewsBlurAppDelegate;

@interface FeedTableCell : ABTableViewCell {    
    NewsBlurAppDelegate *appDelegate;
    
    NSString *feedTitle;
    UIImage *feedFavicon;
    int _positiveCount;
    int _neutralCount;
    int _negativeCount;
    NSString *_negativeCountStr;
    BOOL isSocial;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *feedTitle;
@property (nonatomic) UIImage *feedFavicon;
@property (assign, nonatomic) int positiveCount;
@property (assign, nonatomic) int neutralCount;
@property (assign, nonatomic) int negativeCount;
@property (assign, nonatomic) BOOL isSocial;
@property (nonatomic) NSString *negativeCountStr;

@end
