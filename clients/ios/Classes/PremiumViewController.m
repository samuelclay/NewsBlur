//
//  PremiumViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/9/17.
//  Copyright © 2017 NewsBlur. All rights reserved.
//

#import "PremiumViewController.h"
#import "NewsBlur-Swift.h"

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
@synthesize freeView;
@synthesize premiumView;
@synthesize confettiView;
@synthesize productsHeight;
@synthesize labelTitle;
@synthesize labelSubtitle;
@synthesize labelPremiumTitle;
@synthesize labelPremiumExpire;

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
                         @[@"You feed Shiloh, my poor, hungry dog, for a month", @"g_icn_eating"],
                         ];

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Done"
                                                                     style: UIBarButtonItemStylePlain
                                                                    target: self
                                                                    action: @selector(closeDialog:)];
    [self.navigationItem setLeftBarButtonItem:cancelButton];
    
    self.productsTable.tableFooterView = [UIView new];
    self.reasonsTable.tableFooterView = [self makeShilohCell];
    self.productsTable.separatorColor = [UIColor clearColor];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIBarButtonItem *restoreButton = [[UIBarButtonItem alloc] initWithTitle: @"Restore"
                                                                      style: UIBarButtonItemStylePlain
                                                                     target: self
                                                                     action: @selector(restorePurchase:)];
    [self.navigationItem setRightBarButtonItem:restoreButton];

    self.navigationItem.title = @"NewsBlur Premium";
    [self loadProducts];
    [self updateTheme];
    [confettiView setNeedsLayout];
    [confettiView startConfetti];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [confettiView setNeedsLayout];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [confettiView stopConfetti];
}

- (void)closeDialog:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateTheme {
    [super updateTheme];
    
    self.productsTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.reasonsTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.labelTitle.textColor = UIColorFromRGB(0x0c0c0c);
    self.labelSubtitle.textColor = UIColorFromRGB(0x0c0c0c);
    self.labelPremiumExpire.textColor = UIColorFromRGB(0x0c0c0c);
    self.labelPremiumTitle.textColor = UIColorFromRGB(0x0c0c0c);
    self.labelPremiumExpire.shadowColor = UIColorFromRGB(0xf4f4f4);
    self.labelPremiumTitle.shadowColor = UIColorFromRGB(0xf4f4f4);

    [self.productsTable reloadData];
    [self.reasonsTable reloadData];
}

#pragma mark - StoreKit

- (void)loadProducts {
    [spinner startAnimating];
    productsTable.hidden = YES;
    
    if ([SKPaymentQueue canMakePayments]){
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                              initWithProductIdentifiers:[NSSet setWithObjects:
                                                                          kPremium24ProductIdentifier,
                                                                          kPremium36ProductIdentifier, nil]];
        productsRequest.delegate = self;
        request = productsRequest;
        [productsRequest start];
    } else {
        NSLog(@"User cannot make payments due to parental controls");
    }
    
    if (appDelegate.isPremium) {
        freeView.hidden = YES;
        premiumView.hidden = NO;
        self.navigationItem.rightBarButtonItem = nil;
        
        if (appDelegate.premiumExpire != 0) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:appDelegate.premiumExpire];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"MMMM d, yyyy"];
            labelPremiumExpire.text = [NSString stringWithFormat:@"Your premium subscription will renew on %@", [dateFormatter stringFromDate:date]];
        } else {
            labelPremiumExpire.text = @"Your premium subscription is set to never expire. Whoa!";
        }
    } else {
        freeView.hidden = NO;
        premiumView.hidden = YES;
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
    
    productsTable.hidden = YES;
    spinner.hidden = NO;
}

- (IBAction)restorePurchase:(id)sender {
    productsTable.hidden = YES;
    spinner.hidden = NO;
    
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

            [self finishTransaction:transaction];
            return;
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
                
                [self finishTransaction:transaction];
                break;
            
            case SKPaymentTransactionStateRestored:
                NSLog(@"Transaction state -> Restored");
                //add the same code as you did from SKPaymentTransactionStatePurchased here
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

                [self finishTransaction:transaction];
                break;
            
            case SKPaymentTransactionStateDeferred:
                NSLog(@"Transaction state -> Deferred");
            case SKPaymentTransactionStateFailed:
                NSLog(@"Transaction state -> Failed");
                //called when the transaction does not finish
                if (transaction.error.code == SKErrorPaymentCancelled) {
                    NSLog(@"Transaction state -> Cancelled");
                    //the user cancelled the payment ;(
                }
                
                [self informError:@"Transaction failed!"];
                productsTable.hidden = NO;
                spinner.hidden = YES;
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
        }
    }
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction {
    productsTable.hidden = YES;
    spinner.hidden = NO;

    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) {
        NSLog(@" No receipt found!");
        [self informError:@"No receipt found"];
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/profile/save_ios_receipt/",
                           appDelegate.url];
    NSDictionary *params = @{
                             @"receipt": [receipt base64EncodedStringWithOptions:0],
                             @"transaction_identifier": transaction.originalTransaction.transactionIdentifier,
                             @"product_identifier": transaction.payment.productIdentifier,
                             };
    
    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Sent iOS receipt: %@", params);
        productsTable.hidden = NO;
        spinner.hidden = YES;
        NSDictionary *results = (NSDictionary *)responseObject;
        appDelegate.isPremium = [[results objectForKey:@"is_premium"] integerValue] == 1;
        id premiumExpire = [results objectForKey:@"premium_expire"];
        if (premiumExpire && ![premiumExpire isKindOfClass:[NSNull class]] && premiumExpire != 0) {
            appDelegate.premiumExpire = [premiumExpire integerValue];
        }

        [self loadProducts];
        [appDelegate reloadFeedsView:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"Failed to send receipt: %@", params);
        productsTable.hidden = NO;
        spinner.hidden = YES;

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self informError:error statusCode:httpResponse.statusCode];
        
        [self loadProducts];
    }];

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
    UITableViewCell *cell;
    
    if (tableView == reasonsTable) {
        static NSString *ReasonsCellIndentifier = @"PremiumReasonsCell";
        cell = [tableView dequeueReusableCellWithIdentifier:ReasonsCellIndentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ReasonsCellIndentifier];
        }
        
        cell.backgroundColor = UIColorFromRGB(0xf4f4f4);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = reasons[indexPath.row][0];
        cell.textLabel.font = [UIFont systemFontOfSize:14.f weight:UIFontWeightLight];
        cell.textLabel.textColor = UIColorFromRGB(0x0c0c0c);
        cell.textLabel.numberOfLines = 2;
        CGSize itemSize = CGSizeMake(18, 18);
        cell.imageView.image = [UIImage imageNamed:reasons[indexPath.row][1]];
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.clipsToBounds = NO;
        UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
        CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
        [cell.imageView.image drawInRect:imageRect];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else { //} if (tableView == productsTable) {
        static NSString *CellIndentifier = @"PremiumCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIndentifier];
        }

        SKProduct *product = products[indexPath.row];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = UIColorFromRGB(0xf4f4f4);
        cell.textLabel.textColor = UIColorFromRGB(0x203070);
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.textColor = UIColorFromRGB(0x0c0c0c);
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [formatter setLocale:product.priceLocale];
        
        if (!product.localizedTitle) {
            cell.textLabel.text = [NSString stringWithFormat:@"NewsBlur Premium Subscription"];
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%@", product.localizedTitle];
        }
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ per year (%@/month)", [formatter stringFromNumber:product.price], [formatter stringFromNumber:@(round([product.price doubleValue] / 12.f))]];;
        
        UILabel *label = [[UILabel alloc] init];
        label.text = @"👉🏽";
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor;
        label.font = [UIFont systemFontOfSize:18];
        CGSize measuredSize = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
        label.frame = CGRectMake(0, 0, measuredSize.width, measuredSize.height);
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, label.opaque, 0.0);
        [label.layer renderInContext:UIGraphicsGetCurrentContext()];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

- (UIView *)makeShilohCell {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 96+12+12)];
    UIImageView *imgView = [[UIImageView alloc] init];
    imgView.translatesAutoresizingMaskIntoConstraints = NO;
    imgView.tag = 1;
    imgView.contentMode = UIViewContentModeScaleAspectFit;
    [view addSubview:imgView];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    [view addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1.0 constant:12]];
    [imgView addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:96]];

    UIImageView *_imgView = (UIImageView *)[view viewWithTag:1];
    _imgView.image = [UIImage imageNamed:@"Shiloh.jpg"];
    
    return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == productsTable) {
        [self purchase:products[indexPath.row]];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
@end
