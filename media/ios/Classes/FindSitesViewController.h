//
//  findSitesViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/31/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface FindSitesViewController : UIViewController 
<UITableViewDataSource, UITableViewDataSource, UISearchBarDelegate> {
    NewsBlurAppDelegate *appDelegate;
    UISearchBar *sitesSearchBar;
    UITableView *sitesTable;
    
    NSArray *sites;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UISearchBar *sitesSearchBar;
@property (nonatomic) IBOutlet UITableView *sitesTable;
@property (nonatomic) NSArray *sites;


- (void)doCancelButton;
- (void)loadSitesList:(NSString *)query;
- (void)requestFinished:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;

@end
