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
    UIPopoverController *popoverController;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) UITableView *interactionsTable;
@property (nonatomic) NSArray *interactionsArray;
@property (nonatomic, strong) UIPopoverController *popoverController;

- (void)refreshWithInteractions:(NSMutableArray *)interactions;

@end