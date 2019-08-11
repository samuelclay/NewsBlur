//
//  PremiumManager.h
//  NewsBlur
//
//  Created by David Sinclair on 2018-10-04.
//  Copyright © 2018 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "NewsBlurAppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface PremiumManager : NSObject

@property (nonatomic, strong) NSArray<SKProduct *> *products;
@property (nonatomic, strong) NSArray<NSArray<NSString *> *> *reasons;

- (void)loadProducts;
- (void)purchase:(SKProduct *)product;
- (void)restorePurchase;

@end

NS_ASSUME_NONNULL_END
