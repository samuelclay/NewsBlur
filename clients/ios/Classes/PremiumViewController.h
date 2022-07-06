//
//  PremiumViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/9/17.
//  Copyright © 2017 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@class SAConfettiView;

@interface PremiumViewController : BaseViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UITableView *premiumTable;


- (IBAction)closeDialog:(id)sender;
- (IBAction)restorePurchase:(id)sender;

- (void)loadedProducts;
- (void)finishedTransaction;

@end
