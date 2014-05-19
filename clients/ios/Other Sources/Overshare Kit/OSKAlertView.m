//
//  OSKAlertView.m
//  Overshare Kit
//
//  Created by Jared Sinclair October 18, 2013.
//  Copyright (c) 2013 Jared Sinclair & Justin Williams LLC. All rights reserved.
//

#import "OSKAlertView.h"

#import "OSKPresentationManager.h"

@implementation OSKAlertViewButtonItem

- (id)initWithTitle:(NSString *)title actionBlock:(OSKAlertViewActionBlock)actionBlock {
    self = [super init];
    if (self) {
        _title = title;
        _actionBlock = [actionBlock copy];
    }
    return self;
}

@end

@interface OSKAlertView ()

@property (strong, nonatomic) NSMutableArray *buttonItems;
@property (strong, nonatomic) OSKAlertViewButtonItem *cancelButtonItem;

@end

@implementation OSKAlertView

+ (OSKAlertViewButtonItem *)okayItem {
    NSString *title = [[OSKPresentationManager sharedInstance] localizedText_Okay];
    OSKAlertViewButtonItem *item = [[OSKAlertViewButtonItem alloc] initWithTitle:title actionBlock:nil];
    return item;
}

+ (OSKAlertViewButtonItem *)cancelItem {
    NSString *title = [[OSKPresentationManager sharedInstance] localizedText_Cancel];
    OSKAlertViewButtonItem *item = [[OSKAlertViewButtonItem alloc] initWithTitle:title actionBlock:nil];
    return item;
}

- (id)initWithTitle:(NSString *)title
            message:(NSString *)message
   cancelButtonItem:(OSKAlertViewButtonItem *)cancelButtonItem
   otherButtonItems:(NSArray *)otherButtonItems {
    self = [super init];
    if (self) {
        [self setTitle:title];
        [self setMessage:message];
        [self setDelegate:self];
        _buttonItems = [NSMutableArray array];
        
        [self addButtonWithTitle:cancelButtonItem.title];
        [self setCancelButtonIndex:0];
        _cancelButtonItem = cancelButtonItem;
        [_buttonItems addObject:cancelButtonItem];
        
        for (OSKAlertViewButtonItem *buttonItem in otherButtonItems) {
            [self addButtonWithTitle:buttonItem.title];
            [_buttonItems addObject:buttonItem];  
        }
    }
    return self;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        if (self.cancelButtonItem.actionBlock) {
            self.cancelButtonItem.actionBlock();
        }
    }
    else {
        OSKAlertViewButtonItem *item = [self.buttonItems objectAtIndex:buttonIndex];
        if (item.actionBlock) {
            item.actionBlock();
        }
    }
}

@end









