//
//  FollowGrid.h
//  NewsBlur
//
//  Created by Roy Yang on 8/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FollowGrid : UITableViewCell {
    NewsBlurAppDelegate *appDelegate;
    
    NSDictionary *profiles;
    NSArray *followList;
    
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSDictionary *profiles;
@property (nonatomic) NSArray *followList;

- (void)refreshWithWidth:(int)width;

@end
