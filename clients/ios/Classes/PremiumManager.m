//
//  PremiumManager.m
//  NewsBlur
//
//  Created by David Sinclair on 2018-10-04.
//  Copyright © 2018 NewsBlur. All rights reserved.
//

#import "PremiumManager.h"
#import "PremiumViewController.h"

#define kPremium24ProductIdentifier @"newsblur_premium_auto_renew_24"
#define kPremium36ProductIdentifier @"newsblur_premium_auto_renew_36"

@interface PremiumManager () <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) SKProductsRequest *request;

@end


@implementation PremiumManager

- (instancetype)init {
    if ((self = [super init])) {
        self.products = [NSArray array];
        self.reasons = @[@[@"Enable every site by going premium", @"g_icn_buffer"],
                    @[@"Sites updated up to 10x more often", @"g_icn_lightning"],
                    @[@"River of News (reading by folder)", @"g_icn_folder_black"],
                    @[@"Search sites and folders", @"g_icn_search_black"],
                    @[@"Save stories with searchable tags", @"g_icn_tag_black"],
                    @[@"Privacy options for your blurblog", @"g_icn_privacy"],
                    @[@"Custom RSS feeds for folders and saved stories", @"g_icn_folder_black"],
                    @[@"Text view conveniently extracts the story", @"g_icn_textview_black"],
                    @[@"You feed Shiloh, my poor, hungry dog, for a month", @"g_icn_eating"],
                    ];
    }
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    return self;
}

- (NewsBlurAppDelegate *)appDelegate {
    return [NewsBlurAppDelegate sharedAppDelegate];
}

- (void)loadProducts {
    if ([SKPaymentQueue canMakePayments]){
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                              initWithProductIdentifiers:[NSSet setWithObjects:
                                                                          kPremium24ProductIdentifier,
                                                                          kPremium36ProductIdentifier, nil]];
        productsRequest.delegate = self;
        self.request = productsRequest;
        [productsRequest start];
    } else {
        NSLog(@"User cannot make payments due to parental controls");
    }
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    SKProduct *validProduct = nil;
    NSUInteger count = [response.products count];
    if (count > 0){
        self.products = response.products;
        
        [self.appDelegate.premiumViewController loadedProducts];
    } else if (!validProduct) {
        NSLog(@"No products available");
        //this is called if your product id is not valid, this shouldn't be called unless that happens.
    }
}

- (void)purchase:(SKProduct *)product {
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)restorePurchase {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"received restored transactions: %lu", (unsigned long)queue.transactions.count);
    
    for (SKPaymentTransaction *transaction in queue.transactions) {
        if (transaction.transactionState == SKPaymentTransactionStateRestored) {
            NSLog(@"Transaction state -> Restored");
            
            [self finishTransaction:transaction];
            return;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if (error.code == SKErrorPaymentCancelled) {
        NSLog(@"Restore cancelled");
        
        [self.appDelegate.premiumViewController finishedTransaction];
    } else {
        NSLog(@"Restore failed");
        
        [self.appDelegate.premiumViewController informError:@"Restore failed!"];
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
                
                NSLog(@"Transaction state -> Purchased");
                
                [self finishTransaction:transaction];
                break;
                
            case SKPaymentTransactionStateRestored:
                NSLog(@"Transaction state -> Restored");
                //add the same code as you did from SKPaymentTransactionStatePurchased here
                
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
                
                [self.appDelegate.premiumViewController informError:@"Transaction failed!"];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
        }
    }
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) {
        NSLog(@" No receipt found!");
        [self.appDelegate.premiumViewController informError:@"No receipt found"];
        //        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/profile/save_ios_receipt/",
                           self.appDelegate.url];
    NSDictionary *params = @{
                             //                             @"receipt": [receipt base64EncodedStringWithOptions:0],
                             @"transaction_identifier": transaction.originalTransaction.transactionIdentifier,
                             @"product_identifier": transaction.payment.productIdentifier,
                             };
    
    [self.appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Sent iOS receipt: %@", params);
        [self.appDelegate.premiumViewController finishedTransaction];
        NSDictionary *results = (NSDictionary *)responseObject;
        self.appDelegate.isPremium = [[results objectForKey:@"is_premium"] integerValue] == 1;
        id premiumExpire = [results objectForKey:@"premium_expire"];
        if (premiumExpire && ![premiumExpire isKindOfClass:[NSNull class]] && premiumExpire != 0) {
            self.appDelegate.premiumExpire = [premiumExpire integerValue];
        }
        
        [self loadProducts];
        [self.appDelegate reloadFeedsView:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"Failed to send receipt: %@", params);
        [self.appDelegate.premiumViewController finishedTransaction];
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self.appDelegate.premiumViewController informError:error statusCode:httpResponse.statusCode];
        
        [self loadProducts];
    }];
}

@end
