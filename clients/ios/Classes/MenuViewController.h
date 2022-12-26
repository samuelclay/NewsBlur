//
//  MenuViewController.h
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^MenuItemHandler)(void);
typedef void (^MenuItemSegmentedHandler)(NSUInteger selectedIndex);

@interface MenuViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (weak) IBOutlet UITableView *menuTableView;

@property (nonatomic) NSInteger checkedRow;

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler;
- (void)addTitle:(NSString *)title iconName:(NSString *)iconName destructive:(BOOL)isDestructive selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler;
- (void)addTitle:(NSString *)title iconName:(NSString *)iconName iconColor:(UIColor *)iconColor selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler;
- (void)addTitle:(NSString *)title iconTemplateName:(NSString *)iconTemplateName selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler;
- (void)addSegmentedControlWithTitles:(NSArray *)titles selectIndex:(NSUInteger)selectIndex selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler;
- (void)addSegmentedControlWithTitles:(NSArray *)titles values:(NSArray *)values preferenceKey:(NSString *)preferenceKey selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler;
- (void)addSegmentedControlWithTitles:(NSArray *)titles values:(NSArray *)values defaultValue:(NSString *)defaultValue preferenceKey:(NSString *)preferenceKey selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler;
- (void)addThemeSegmentedControl;

- (void)showFromNavigationController:(UINavigationController *)navigationController barButtonItem:(UIBarButtonItem *)barButtonItem;
- (void)showFromNavigationController:(UINavigationController *)navigationController barButtonItem:(UIBarButtonItem *)barButtonItem permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections;

@end
