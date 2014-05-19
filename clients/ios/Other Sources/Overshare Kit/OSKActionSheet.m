//
//  OSKActionSheet.h
//  Overshare Kit
//
//  Created by Jared Sinclair October 18, 2013.
//  Copyright (c) 2013 Jared Sinclair & Justin Williams LLC. All rights reserved.
//

#import "OSKActionSheet.h"

#import "OSKLogger.h"
#import "OSKPresentationManager.h"

@implementation OSKActionSheetButtonItem

- (id)initWithTitle:(NSString *)title actionBlock:(OSKActionSheetActionBlock)actionBlock {
    self = [super init];
    if (self) {
        _title = title;
        _actionBlock = [actionBlock copy];
    }
    return self;
}

@end

@interface OSKActionSheet () <UIActionSheetDelegate>

@property (strong, nonatomic) OSKActionSheetButtonItem *cancelButtonItem;
@property (strong, nonatomic) OSKActionSheetButtonItem *destructiveButtonItem;
@property (strong, nonatomic) NSMutableArray *buttonItems;
@property (assign, nonatomic) BOOL shouldKeepOverlayVisibleAfterActionItemPresses;

@end

@implementation OSKActionSheet

+ (OSKActionSheetButtonItem *)okayItem {
    NSString *title = [[OSKPresentationManager sharedInstance] localizedText_Okay];
    OSKActionSheetButtonItem *item = [[OSKActionSheetButtonItem alloc] initWithTitle:title actionBlock:nil];
    return item;
}

+ (OSKActionSheetButtonItem *)cancelItem {
    NSString *title = [[OSKPresentationManager sharedInstance] localizedText_Cancel];
    OSKActionSheetButtonItem *item = [[OSKActionSheetButtonItem alloc] initWithTitle:title actionBlock:nil];
    return item;
}

- (id)initWithTitle:(NSString *)optionalTitle
   cancelButtonItem:(OSKActionSheetButtonItem *)cancelButtonItem
destructiveButtonItem:(OSKActionSheetButtonItem *)destructiveButtonItem
   otherButtonItems:(NSArray *)otherButtonItems {
    
    self = [super initWithTitle:optionalTitle
                       delegate:nil
              cancelButtonTitle:nil
         destructiveButtonTitle:nil
              otherButtonTitles:nil];
    if (self) {
        self.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
        _cancelButtonItem = cancelButtonItem;
        _destructiveButtonItem = destructiveButtonItem;
        if (otherButtonItems.count) {
            _buttonItems = [NSMutableArray arrayWithCapacity:otherButtonItems.count];
            for (OSKActionSheetButtonItem *buttonItem in otherButtonItems) {
                [_buttonItems addObject:buttonItem];
                [self addButtonWithTitle:buttonItem.title];
            }
        }
        NSInteger buttonCount = _buttonItems.count;
        if (destructiveButtonItem) {
            [self addButtonWithTitle:destructiveButtonItem.title];
            [self setDestructiveButtonIndex:buttonCount];
            buttonCount += 1;
        }
        if (cancelButtonItem) {
            [self addButtonWithTitle:cancelButtonItem.title];
            [self setCancelButtonIndex:buttonCount];
        }
        self.delegate = self;
    }
    return self;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        if (self.cancelButtonItem.actionBlock) {
            self.cancelButtonItem.actionBlock();
        }
    }
    else if (buttonIndex == actionSheet.destructiveButtonIndex) {
        if (self.destructiveButtonItem.actionBlock) {
            self.destructiveButtonItem.actionBlock();
        }
    }
    else {
        OSKActionSheetButtonItem *item = [self.buttonItems objectAtIndex:buttonIndex];
        if (item.actionBlock) {
            item.actionBlock();
        }
    }
}

- (void)showInView:(UIView *)view {
    if (view != nil) {
        [super showInView:view];
    } else {
        OSKLog(@"Prevented crasher: Invalid parameter not satisfying: view != nil");
    }
}

@end













