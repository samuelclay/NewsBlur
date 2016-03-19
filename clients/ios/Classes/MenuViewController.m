//
//  MenuViewController.m
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "MenuViewController.h"
#import "MenuTableViewCell.h"

NSString * const MenuTitle = @"title";
NSString * const MenuIcon = @"icon";
NSString * const MenuDestructive = @"destructive";
NSString * const MenuSegmentTitles = @"segmentTitles";
NSString * const MenuSegmentIndex = @"segmentIndex";
NSString * const MenuSelectionShouldDismiss = @"selectionShouldDismiss";
NSString * const MenuHandler = @"handler";

#define kMenuOptionHeight 38

@interface MenuViewController () <UIPopoverPresentationControllerDelegate>

@property (nonatomic, strong) NSMutableArray *items;

@end

@implementation MenuViewController

- (id)init {
    if ((self = [super init])) {
        self.items = [NSMutableArray array];
        self.checkedRow = -1;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.menuTableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.menuTableView.scrollEnabled = self.preferredContentSize.height > self.view.frame.size.height;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (CGSize)preferredContentSize {
    CGSize size = CGSizeMake(100.0, 0.0);
    UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
    
    for (NSDictionary *item in self.items) {
        if (item[MenuSegmentTitles]) {
            size.width = MAX(size.width, 240.0);
        } else {
            size.width = MAX(size.width, [item[MenuTitle] sizeWithAttributes:@{NSFontAttributeName : font}].width);
        }
    }
    
    size.width = MIN(size.width + 50.0, 240.0);
    size.height = size.height + (self.items.count * 38.0);
    
    if (self.navigationController.viewControllers.count > 1) {
        size.width = MAX(size.width, self.view.frame.size.width);
    }
    
    self.navigationController.preferredContentSize = size;
    
    return size;
}

- (void)addTitle:(NSString *)title iconImage:(UIImage *)image destructive:(BOOL)isDestructive selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    [self.items addObject:@{MenuTitle: title.uppercaseString, MenuIcon: image, MenuDestructive: @(isDestructive), MenuSelectionShouldDismiss: @(selectionShouldDismiss), MenuHandler: handler}];
}

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    [self addTitle:title iconImage:[UIImage imageNamed:iconName] destructive:[iconName isEqualToString:@"menu_icn_delete.png"] || [iconName isEqualToString:@"menu_icn_mute.png"]selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addTitle:(NSString *)title iconTemplateName:(NSString *)iconTemplateName selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    [self addTitle:title iconImage:[[UIImage imageNamed:iconTemplateName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] destructive:NO selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addSegmentedControlWithTitles:(NSArray *)titles selectIndex:(NSUInteger)selectIndex selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler {
    [self.items addObject:@{MenuSegmentTitles : titles, MenuSegmentIndex : @(selectIndex), MenuSelectionShouldDismiss : @(selectionShouldDismiss), MenuHandler : handler}];
}

- (UITableViewCell *)makeSegmentedTableCellForItem:(NSDictionary *)item forRow:(NSUInteger)row {
    UITableViewCell *cell = [UITableViewCell new];
    cell.frame = CGRectMake(0.0, 0.0, 240.0, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake(8, 7, cell.frame.size.width - 8 * 2, kMenuOptionHeight - 7 * 2)];
    NSArray *segmentTitles = item[MenuSegmentTitles];
    
    for (NSUInteger idx = 0; idx < segmentTitles.count; idx++) {
        [segmentedControl insertSegmentWithTitle:[segmentTitles[idx] uppercaseString] atIndex:idx animated:NO];
        [segmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:idx];
    }
    
    segmentedControl.selectedSegmentIndex = [item[MenuSegmentIndex] integerValue];
    segmentedControl.tag = row;
    segmentedControl.backgroundColor = UIColorFromRGB(0xeeeeee);
    [segmentedControl setTitleTextAttributes:@{NSFontAttributeName : [UIFont fontWithName:@"Helvetica-Bold" size:11.0]} forState:UIControlStateNormal];
    [segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    [cell addSubview:segmentedControl];
    
    return cell;
}

- (void)segmentedValueChanged:(id)sender {
    NSDictionary *item = self.items[[sender tag]];
    NSUInteger idx = [sender selectedSegmentIndex];
    
    if (item[MenuHandler]) {
        MenuItemSegmentedHandler handler = item[MenuHandler];
        BOOL shouldDismiss = [item[MenuSelectionShouldDismiss] boolValue];
        
        if (shouldDismiss) {
            [self dismissViewControllerAnimated:YES completion:^{
                handler(idx);
            }];
        } else {
            handler(idx);
        }
    }
}

- (void)showFromNavigationController:(UINavigationController *)navigationController barButtonItem:(UIBarButtonItem *)barButtonItem {
    UIViewController *presentedViewController = navigationController.presentedViewController;
    if (presentedViewController && presentedViewController.presentationController.presentationStyle == UIModalPresentationPopover) {
        [presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
    self.modalPresentationStyle = UIModalPresentationPopover;
    
    UIPopoverPresentationController *popoverPresentationController = self.popoverPresentationController;
    popoverPresentationController.delegate = self;
    popoverPresentationController.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
    popoverPresentationController.barButtonItem = barButtonItem;
    
    [navigationController presentViewController:self animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    
    if (item[MenuSegmentTitles]) {
        return [self makeSegmentedTableCellForItem:item forRow:indexPath.row];
    } else {
        static NSString *CellIndentifier = @"MenuTableCell";
        MenuTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
        
        if (cell == nil) {
            cell = [[MenuTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIndentifier];
        }
        
        NSString *title = item[MenuTitle];
        NSInteger indent = 0;
        
        if ([title hasPrefix:@"\t"]) {
            NSArray *components = [title componentsSeparatedByString:@"\t"];
            title = components.lastObject;
            indent = components.count;
        }
        
        cell.indentationLevel = indent;
        cell.destructive = [item[MenuDestructive] boolValue];
        cell.tintColor = UIColorFromFixedRGB(0x303030);
        cell.textLabel.text = title;
        cell.imageView.image = item[MenuIcon];
        cell.imageView.tintColor = UIColorFromRGB(0x303030);

        if (self.checkedRow == indexPath.row) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kMenuOptionHeight;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    
    if (item[MenuSegmentTitles]) {
        return nil;
    } else {
        return indexPath;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    
    if (item[MenuSegmentTitles]) {
        return;
    }
    
    if (item[MenuHandler]) {
        MenuItemHandler handler = item[MenuHandler];
        BOOL shouldDismiss = [item[MenuSelectionShouldDismiss] boolValue];
        
        if (shouldDismiss) {
            [self dismissViewControllerAnimated:YES completion:^{
                handler();
            }];
        } else {
            handler();
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

@end
