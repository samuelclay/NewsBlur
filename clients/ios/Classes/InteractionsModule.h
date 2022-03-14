//
//  InteractionsModule.h
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@class NewsBlurAppDelegate;

@interface InteractionsModule : UIView <UITableViewDelegate, UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
    UITableView *interactionsTable;
    NSMutableArray *interactionsArray;
    
    BOOL pageFetching;
    BOOL pageFinished;
    int interactionsPage;
}

@property (nonatomic, strong) UITableView *interactionsTable;
@property (nonatomic) NSArray *interactionsArray;

@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;
@property (readwrite) int interactionsPage;

- (void)refreshWithInteractions:(NSArray *)interactions;

- (void)fetchInteractionsDetail:(int)page;

- (void)checkScroll;

@end
