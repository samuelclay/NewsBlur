//
//  InteractionsModule.h
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface InteractionsModule : UIView <UITableViewDelegate, UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
    UITableView *interactionsTable;
    NSMutableArray *interactionsArray;
    UIPopoverController *popoverController;
    
    BOOL pageFetching;
    BOOL pageFinished;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) UITableView *interactionsTable;
@property (nonatomic) NSArray *interactionsArray;
@property (nonatomic, strong) UIPopoverController *popoverController;

@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;

- (void)fetchInteractionsDetail:(int)page;
- (void)finishLoadInteractions:(ASIHTTPRequest *)request;
- (void)refreshWithInteractions:(NSMutableArray *)interactions;
- (void)requestFailed:(ASIHTTPRequest *)request;

- (void)fetchNextPage:(void(^)())callback;
- (void)checkScroll;

@end