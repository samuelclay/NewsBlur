//
//  OSKActionSheet.h
//  Overshare Kit
//
//  Created by Jared Sinclair October 18, 2013.
//  Copyright (c) 2013 Jared Sinclair & Justin Williams LLC. All rights reserved.
//

@import UIKit;

#define OSKActionSheetCancelButtonItem [[OSKActionSheetButtonItem alloc] initWithTitle:@"Cancel" actionBlock:nil]

typedef void (^OSKActionSheetActionBlock)(void);

@interface OSKActionSheetButtonItem : NSObject

@property (copy, nonatomic) OSKActionSheetActionBlock actionBlock;
@property (copy, nonatomic) NSString *title;

- (id)initWithTitle:(NSString *)title actionBlock:(OSKActionSheetActionBlock)actionBlock;

@end

@interface OSKActionSheet : UIActionSheet

+ (OSKActionSheetButtonItem *)okayItem;
+ (OSKActionSheetButtonItem *)cancelItem;

- (id)initWithTitle:(NSString *)optionalTitle
   cancelButtonItem:(OSKActionSheetButtonItem *)cancelButtonItem
destructiveButtonItem:(OSKActionSheetButtonItem *)destructiveButtonItem
   otherButtonItems:(NSArray *)otherButtonItems;

@end




