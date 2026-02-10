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

@interface PremiumViewController : BaseViewController

@property (nonatomic) IBOutlet UITableView *premiumTable;  // Legacy, hidden - now using SwiftUI
@property (nonatomic) BOOL scrollToArchive;
@property (nonatomic) BOOL scrollToPro;

- (IBAction)closeDialog:(id)sender;
- (IBAction)restorePurchase:(id)sender;

- (void)loadedProducts;
- (void)finishedTransaction;
- (void)configureScrollToArchive:(BOOL)scrollToArchive scrollToPro:(BOOL)scrollToPro;

@end
