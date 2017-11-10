//
//  PremiumViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/9/17.
//  Copyright © 2017 NewsBlur. All rights reserved.
//

#import "PremiumViewController.h"

#define kPremium24ProductIdentifier @"newsblur_premium_auto_renew_24"
#define kPremium36ProductIdentifier @"newsblur_premium_auto_renew_36"

@interface PremiumViewController ()

@end

@implementation PremiumViewController

@synthesize appDelegate;
@synthesize productsTable;
@synthesize reasonsTable;
@synthesize spinner;
@synthesize navigationBar;
@synthesize doneButton;
@synthesize restoreButton;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    products = [NSArray array];
    reasons = @[@[@"Enable every site by going premium", @"g_icn_buffer"],
                         @[@"Sites updated up to 10x more often", @"g_icn_lightning"],
                         @[@"River of News (reading by folder)", @"g_icn_folder_black"],
                         @[@"Search sites and folders", @"g_icn_search_black"],
                         @[@"Save stories with searchable tags", @"g_icn_tag_black"],
                         @[@"Privacy options for your blurblog", @"g_icn_privacy"],
                         @[@"Custom RSS feeds for folders and saved stories", @"g_icn_folder_black"],
                         @[@"Text view conveniently extracts the story", @"g_icn_textview_black"],
                         @[@"You feed Shiloh, my poor, hungry dog, for 12 days", @"g_icn_eating"],
                         ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadProducts];
}

- (void)closeDialog:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - StoreKit

- (void)loadProducts {
    [spinner startAnimating];
    productsTable.hidden = YES;
    
    if ([SKPaymentQueue canMakePayments]){
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                              initWithProductIdentifiers:[NSSet setWithObjects:kPremium24ProductIdentifier,
                                                                          kPremium36ProductIdentifier, nil]];
        productsRequest.delegate = self;
        
        [productsRequest start];
    } else {
        NSLog(@"User cannot make payments due to parental controls");
    }
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    SKProduct *validProduct = nil;
    NSUInteger count = [response.products count];
    if (count > 0){
        products = response.products;
        
        spinner.hidden = YES;
        productsTable.hidden = NO;
        [productsTable reloadData];
    } else if (!validProduct) {
        NSLog(@"No products available");
        //this is called if your product id is not valid, this shouldn't be called unless that happens.
    }
}

- (void)purchase:(SKProduct *)product {
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (IBAction)restorePurchase:(id)sender {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"received restored transactions: %lu", (unsigned long)queue.transactions.count);
    for (SKPaymentTransaction *transaction in queue.transactions) {
        if (transaction.transactionState == SKPaymentTransactionStateRestored) {
            NSLog(@"Transaction state -> Restored");
            
            //NSString *productID = transaction.payment.productIdentifier;
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing: NSLog(@"Transaction state -> Purchasing");
                //called when the user is in the process of purchasing, do not add any of your own code here.
                break;
            
            case SKPaymentTransactionStatePurchased:
                //this is called when the user has successfully purchased the package (Cha-Ching!)
                
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                NSLog(@"Transaction state -> Purchased");
                break;
            
            case SKPaymentTransactionStateRestored:
                NSLog(@"Transaction state -> Restored");
                //add the same code as you did from SKPaymentTransactionStatePurchased here
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            
            case SKPaymentTransactionStateFailed:
            case SKPaymentTransactionStateDeferred:
                //called when the transaction does not finish
                if (transaction.error.code == SKErrorPaymentCancelled) {
                    NSLog(@"Transaction state -> Cancelled");
                    //the user cancelled the payment ;(
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
        }
    }
}

#pragma mark - Table Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == reasonsTable) {
        return [reasons count];
    } else if (tableView == productsTable) {
        return [products count];
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIndentifier = @"PremiumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIndentifier];
    }

    if (tableView == reasonsTable) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = reasons[indexPath.row][0];
        CGSize itemSize = CGSizeMake(16, 16);
        cell.imageView.image = [UIImage imageNamed:reasons[indexPath.row][1]];
        UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
        CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
        [cell.imageView.image drawInRect:imageRect];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else if (tableView == productsTable) {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = products[indexPath.row].localizedTitle;
        cell.imageView.image = [UIImage imageNamed:reasons[indexPath.row][1]];
    }
    
    return cell;
}
@end
