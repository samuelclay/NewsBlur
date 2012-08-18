//
//  AddSiteTableCell.h
//  NewsBlur
//
//  Created by Roy Yang on 8/7/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ABTableViewCell.h"

@interface AddSiteTableCell : ABTableViewCell {
    NewsBlurAppDelegate *appDelegate;
    
    NSString *siteTitle;
    NSString *siteUrl;
    NSString *siteSubscribers;

    UIImage *siteFavicon;
    
    UIColor *feedColorBar;
    UIColor *feedColorBarTopBorder;
}

@property (nonatomic) NSString *siteTitle;
@property (nonatomic) NSString *siteUrl;
@property (nonatomic) NSString *siteSubscribers;
@property (nonatomic) UIImage *siteFavicon;

@property (nonatomic) UIColor *feedColorBar;
@property (nonatomic) UIColor *feedColorBarTopBorder;



@end
