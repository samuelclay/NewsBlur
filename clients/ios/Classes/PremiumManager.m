//
//  PremiumManager.m
//  NewsBlur
//
//  Created by David Sinclair on 2018-10-04.
//  Copyright © 2018 NewsBlur. All rights reserved.
//

#import "PremiumManager.h"
#import "PremiumViewController.h"

#define kPremium36ProductIdentifier @"newsblur_premium_auto_renew_36"
#define kPremiumArchiveProductIdentifier @"newsblur_premium_archive"
#define kPremiumProProductIdentifier @"newsblur_premium_pro"

@interface PremiumManager () <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) SKProductsRequest *request;

@end


@implementation PremiumManager

- (instancetype)init {
    if ((self = [super init])) {
        self.premiumProduct = nil;
        self.premiumArchiveProduct = nil;
        self.premiumProProduct = nil;
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
                                                                          kPremium36ProductIdentifier,
                                                                          kPremiumArchiveProductIdentifier,
                                                                          kPremiumProProductIdentifier,
                                                                          nil]];
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
    if (count > 0) {
        for (SKProduct *product in response.products) {
            if ([product.productIdentifier isEqualToString:kPremium36ProductIdentifier]) {
                self.premiumProduct = product;
            } else if ([product.productIdentifier isEqualToString:kPremiumArchiveProductIdentifier]) {
                self.premiumArchiveProduct = product;
            } else if ([product.productIdentifier isEqualToString:kPremiumProProductIdentifier]) {
                self.premiumProProduct = product;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate.premiumViewController loadedProducts];
        });
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error.code == SKErrorPaymentCancelled) {
            NSLog(@"Restore cancelled");
            
            [self.appDelegate.premiumViewController finishedTransaction];
        } else {
            NSLog(@"Restore failed");
            
            [self.appDelegate.premiumViewController informError:@"Restore failed!"];
        }
    });
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
                
                [self saveReceipt:transaction isComplete:NO];
                break;
                
            case SKPaymentTransactionStateFailed:
                NSLog(@"Transaction state -> Failed");
                //called when the transaction does not finish
                if (transaction.error.code == SKErrorPaymentCancelled) {
                    NSLog(@"Transaction state -> Cancelled");
                    //the user cancelled the payment ;(
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.appDelegate.premiumViewController informError:@"Transaction failed!"];
                });
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate.premiumViewController informError:@"No receipt found"];
        });
        //        return;
    }
    
    [self saveReceipt:transaction isComplete:YES];
}

- (void)saveReceipt:(SKPaymentTransaction *)transaction isComplete:(BOOL)isComplete {
    NSString *urlString = [NSString stringWithFormat:@"%@/profile/save_ios_receipt/",
                           self.appDelegate.url];
    NSString *transactionIdentifier = isComplete ? transaction.originalTransaction.transactionIdentifier : @"in-progress";
    transactionIdentifier = transactionIdentifier ?: @"missing";
    NSString *productIdentifier = transaction.payment.productIdentifier ?: @"missing";
    
    NSDictionary *params = @{
                             //                             @"receipt": [receipt base64EncodedStringWithOptions:0],
        @"transaction_identifier": transactionIdentifier,
                             @"product_identifier": productIdentifier,
                             };
    
    [self.appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Sent iOS receipt: %@", params);
        [self.appDelegate.premiumViewController finishedTransaction];
        NSDictionary *results = (NSDictionary *)responseObject;
        self.appDelegate.isPremium = [[results objectForKey:@"is_premium"] integerValue] == 1;
        self.appDelegate.isPremiumArchive = [[results objectForKey:@"is_archive"] integerValue] == 1;
        self.appDelegate.isPremiumPro = [[results objectForKey:@"is_pro"] integerValue] == 1;
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
