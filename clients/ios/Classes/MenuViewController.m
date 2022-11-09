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
NSString * const MenuIconColor = @"iconColor";
NSString * const MenuDestructive = @"destructive";
NSString * const MenuThemeSegment = @"theme";
NSString * const MenuSegmentTitles = @"segmentTitles";
NSString * const MenuSegmentIndex = @"segmentIndex";
NSString * const MenuSelectionShouldDismiss = @"selectionShouldDismiss";
NSString * const MenuHandler = @"handler";

#define kMenuOptionHeight 38

@interface MenuViewController () <UIPopoverPresentationControllerDelegate, UINavigationControllerDelegate>

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
    UIFont *font = [UIFont fontWithName:@"WhitneySSm-Medium" size:15.0];
    
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
    [self.items addObject:@{MenuTitle: title, MenuIcon: image, MenuDestructive: @(isDestructive), MenuSelectionShouldDismiss: @(selectionShouldDismiss), MenuHandler: handler}];
}

- (void)addTitle:(NSString *)title iconImage:(UIImage *)image iconColor:(UIColor *)iconColor destructive:(BOOL)isDestructive selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    [self.items addObject:@{MenuTitle: title, MenuIcon: image, MenuIconColor: iconColor, MenuDestructive: @(isDestructive), MenuSelectionShouldDismiss: @(selectionShouldDismiss), MenuHandler: handler}];
}

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    [self addTitle:title iconImage:[UIImage imageNamed:iconName] destructive:NO selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName iconColor:(UIColor *)iconColor selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    UIImage *image = [Utilities imageWithImage:[UIImage imageNamed:iconName] convertToSize:CGSizeMake(20.0, 20.0)];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self addTitle:title iconImage:image iconColor:iconColor destructive:NO selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName destructive:(BOOL)isDestructive selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    [self addTitle:title iconImage:[UIImage imageNamed:iconName] destructive:isDestructive selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addTitle:(NSString *)title iconTemplateName:(NSString *)iconTemplateName selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    [self addTitle:title iconImage:[[UIImage imageNamed:iconTemplateName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] destructive:NO selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addSegmentedControlWithTitles:(NSArray *)titles selectIndex:(NSUInteger)selectIndex selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler {
    [self.items addObject:@{MenuSegmentTitles : titles, MenuSegmentIndex : @(selectIndex), MenuSelectionShouldDismiss : @(selectionShouldDismiss), MenuHandler : handler}];
}

- (void)addSegmentedControlWithTitles:(NSArray *)titles values:(NSArray *)values preferenceKey:(NSString *)preferenceKey selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler {
    [self addSegmentedControlWithTitles:titles values:values defaultValue:nil preferenceKey:preferenceKey selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addSegmentedControlWithTitles:(NSArray *)titles values:(NSArray *)values defaultValue:(NSString *)defaultValue preferenceKey:(NSString *)preferenceKey selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    id value = [userPreferences objectForKey:preferenceKey];
    NSUInteger valueIndex = [values indexOfObject:value];
    
    if (valueIndex == NSNotFound && defaultValue != nil) {
        valueIndex = [values indexOfObject:defaultValue];
    }
    
    if (valueIndex == NSNotFound) {
        valueIndex = 0;
    }
    
    [self addSegmentedControlWithTitles:titles selectIndex:valueIndex selectionShouldDismiss:selectionShouldDismiss handler:^(NSUInteger selectedIndex) {
        [userPreferences setObject:values[selectedIndex] forKey:preferenceKey];
        
        if (handler != nil) {
            handler(selectedIndex);
        }
    }];
}

- (void)addThemeSegmentedControl {
    [self.items addObject:@{MenuSegmentTitles : @[], MenuThemeSegment : @YES}];
}

- (UIImage *)themeImageWithName:(NSString *)name selected:(BOOL)selected {
    if (selected) {
        name = [name stringByAppendingString:@"-sel"];
    }
    
    return [[UIImage imageNamed:name] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (UITableViewCell *)makeThemeSegmentedTableCell {
    UITableViewCell *cell = [UITableViewCell new];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    NSString *theme = [ThemeManager themeManager].theme;
    NSArray *values = @[ThemeStyleLight, ThemeStyleSepia, ThemeStyleMedium, ThemeStyleDark];
    NSUInteger valueIndex = [values indexOfObject:theme];
    
    if (valueIndex < 0) {
        valueIndex = 0;
    }
    
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake(8, 4, cell.frame.size.width - 8 * 2, kMenuOptionHeight - 4 * 2)];
    
    [segmentedControl addTarget:self action:@selector(changeTheme:) forControlEvents:UIControlEventValueChanged];
    
    UIImage *lightImage = [self themeImageWithName:@"theme_color_light" selected:valueIndex == 0];
    UIImage *sepiaImage = [self themeImageWithName:@"theme_color_sepia" selected:valueIndex == 1];
    UIImage *mediumImage = [self themeImageWithName:@"theme_color_medium" selected:valueIndex == 2];
    UIImage *darkImage = [self themeImageWithName:@"theme_color_dark" selected:valueIndex == 3];
    
    [segmentedControl insertSegmentWithImage:lightImage atIndex:0 animated: NO];
    [segmentedControl insertSegmentWithImage:sepiaImage atIndex:1 animated: NO];
    [segmentedControl insertSegmentWithImage:mediumImage atIndex:2 animated: NO];
    [segmentedControl insertSegmentWithImage:darkImage atIndex:3 animated: NO];
    
    [[ThemeManager themeManager] updateThemeSegmentedControl:segmentedControl];
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, segmentedControl.frame.size.height), NO, 0.0);
    UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [segmentedControl setDividerImage:blankImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    segmentedControl.tintColor = [UIColor clearColor];
    segmentedControl.backgroundColor = [UIColor clearColor];
    
    segmentedControl.selectedSegmentIndex = valueIndex;
    
    [cell.contentView addSubview:segmentedControl];
    
    return cell;
}

- (IBAction)changeTheme:(UISegmentedControl *)sender {
    NSArray *values = @[ThemeStyleLight, ThemeStyleSepia, ThemeStyleMedium, ThemeStyleDark];
    
    [ThemeManager themeManager].theme = [values objectAtIndex:sender.selectedSegmentIndex];
    
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
    [self.menuTableView reloadData];
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
        NSString *title = segmentTitles[idx];
        
        if ([title hasSuffix:@".png"]) {
            UIImage *image = [UIImage imageNamed:title];
            
            [segmentedControl insertSegmentWithImage:image atIndex:idx animated:NO];
        } else {
            [segmentedControl insertSegmentWithTitle:title atIndex:idx animated:NO];
        }
        
        [segmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:idx];
    }
    
    segmentedControl.apportionsSegmentWidthsByContent = YES;
    segmentedControl.selectedSegmentIndex = [item[MenuSegmentIndex] integerValue];
    segmentedControl.tag = row;
    segmentedControl.backgroundColor = UIColorFromRGB(0xeeeeee);
    [segmentedControl setTitleTextAttributes:@{NSFontAttributeName : [UIFont fontWithName:@"WhitneySSm-Medium" size:12.0]} forState:UIControlStateNormal];
    [segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    [[ThemeManager themeManager] updateSegmentedControl:segmentedControl];
    
    [cell.contentView addSubview:segmentedControl];
    
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
    [self showFromNavigationController:navigationController barButtonItem:barButtonItem permittedArrowDirections:UIPopoverArrowDirectionUp];
}

- (void)showFromNavigationController:(UINavigationController *)navigationController barButtonItem:(UIBarButtonItem *)barButtonItem permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections {
    UIViewController *presentedViewController = navigationController.presentedViewController;
    if (presentedViewController && presentedViewController.presentationController.presentationStyle == UIModalPresentationPopover) {
        [presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
    UINavigationController *embeddedNavController = [[UINavigationController alloc] initWithRootViewController:self];
    
    embeddedNavController.navigationBarHidden = YES;
    embeddedNavController.modalPresentationStyle = UIModalPresentationPopover;
    embeddedNavController.delegate = self;
    
    UIPopoverPresentationController *popoverPresentationController = embeddedNavController.popoverPresentationController;
    popoverPresentationController.delegate = self;
    popoverPresentationController.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    popoverPresentationController.permittedArrowDirections = permittedArrowDirections;
    popoverPresentationController.barButtonItem = barButtonItem;
    
    [navigationController presentViewController:embeddedNavController animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    
    if (item[MenuThemeSegment]) {
        return [self makeThemeSegmentedTableCell];
    } else if (item[MenuSegmentTitles]) {
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
        
        if (item[MenuIconColor]) {
            cell.imageView.tintColor = item[MenuIconColor];
        } else {
            cell.imageView.tintColor = UIColorFromRGB(0x303030);
        }
        
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

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [navController setNavigationBarHidden:viewController == self animated:YES];
}

@end
