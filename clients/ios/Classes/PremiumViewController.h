//
//  PremiumViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/9/17.
//  Copyright © 2017 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import "NewsBlurAppDelegate.h"

@class SAConfettiView;

@interface PremiumViewController : BaseViewController <UITableViewDelegate, UITableViewDataSource, SKProductsRequestDelegate, SKPaymentTransactionObserver> {
    NewsBlurAppDelegate *appDelegate;
    NSArray<SKProduct *> *products;
    
    NSArray *reasons;
    SKProductsRequest *request;
    
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic) IBOutlet UITableView *productsTable;
@property (nonatomic) IBOutlet UITableView *reasonsTable;
@property (nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (nonatomic) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic) IBOutlet UIBarButtonItem *restoreButton;
@property (nonatomic) IBOutlet UIView *freeView;
@property (nonatomic) IBOutlet UIView *premiumView;
@property (nonatomic) IBOutlet SAConfettiView *confettiView;
@property (nonatomic) IBOutlet NSLayoutConstraint *productsHeight;
@property (nonatomic) IBOutlet UILabel *labelTitle;
@property (nonatomic) IBOutlet UILabel *labelSubtitle;
@property (nonatomic) IBOutlet UILabel *labelPremiumTitle;
@property (nonatomic) IBOutlet UILabel *labelPremiumExpire;


- (IBAction)closeDialog:(id)sender;
- (IBAction)restorePurchase:(id)sender;

@end
