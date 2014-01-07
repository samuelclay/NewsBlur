//
//  OSKAlertView.h
//  Overshare Kit
//
//  Created by Jared Sinclair October 18, 2013.
//  Copyright (c) 2013 Jared Sinclair & Justin Williams LLC. All rights reserved.
//

@import UIKit;

typedef void (^OSKAlertViewActionBlock)(void);

@interface OSKAlertViewButtonItem : NSObject

@property (copy, nonatomic) OSKAlertViewActionBlock actionBlock;
@property (copy, nonatomic) NSString *title;

- (id)initWithTitle:(NSString *)title actionBlock:(OSKAlertViewActionBlock)actionBlock;

@end

@interface OSKAlertView : UIAlertView <UIAlertViewDelegate>

+ (OSKAlertViewButtonItem *)cancelItem;

+ (OSKAlertViewButtonItem *)okayItem;

- (id)initWithTitle:(NSString *)title
            message:(NSString *)message
   cancelButtonItem:(OSKAlertViewButtonItem *)cancelButtonItem
   otherButtonItems:(NSArray *)otherButtonItems;

@end
