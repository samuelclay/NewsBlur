//
//  OSKPagedHorizontalLayout.h
//  Overshare
//
//  Created by Jared Sinclair on 10/14/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKPagedHorizontalLayout;

@protocol OSKPagedHorizontalLayoutDelegate <NSObject>

- (NSInteger)numberOfItemsForLayout:(OSKPagedHorizontalLayout *)layout;
- (CGSize)itemSizeForLayout:(OSKPagedHorizontalLayout *)layout;
- (UIEdgeInsets)insetsForLayout:(OSKPagedHorizontalLayout *)layout;
- (CGSize)availablePageSizeForLayout:(OSKPagedHorizontalLayout *)layout;
- (void)layout:(OSKPagedHorizontalLayout *)layout didChangeNumberOfPages:(NSInteger)numberOfPages;

@end

@interface OSKPagedHorizontalLayout : UICollectionViewLayout

@property (weak, nonatomic) id <OSKPagedHorizontalLayoutDelegate> oskDelegate;

- (NSInteger)numberOfPages;

@end
