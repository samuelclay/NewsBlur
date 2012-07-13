//
//  InteractionsModule.h
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface InteractionsModule : UIView <UITableViewDelegate, UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
    UITableView *interactionsTable;
    NSMutableArray *interactionsArray;
}

@property (nonatomic, retain) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) UITableView *interactionsTable;
@property (nonatomic, retain) NSArray *interactionsArray;

- (void)refreshWithInteractions:(NSMutableArray *)interactions;

@end