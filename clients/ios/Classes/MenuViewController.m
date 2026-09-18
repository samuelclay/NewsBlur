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
static NSString * const MenuFeedListIcon = @"feedListIcon";
NSString * const MenuDestructive = @"destructive";
NSString * const MenuThemeSegment = @"theme";
NSString * const MenuSegmentTitles = @"segmentTitles";
NSString * const MenuSegmentIndex = @"segmentIndex";
NSString * const MenuSelectionShouldDismiss = @"selectionShouldDismiss";
NSString * const MenuHandler = @"handler";

#define kMenuOptionHeight 48

@interface MenuViewController () <UIPopoverPresentationControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableIndexSet *sectionStarts;

@end

@implementation MenuViewController

- (id)init {
    if ((self = [super init])) {
        self.items = [NSMutableArray array];
        self.sectionStarts = [NSMutableIndexSet indexSetWithIndex:0];
        self.checkedRow = -1;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.menuTableView.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    self.menuTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.menuTableView.contentInset = UIEdgeInsetsMake(8, 0, 8, 0);
    self.menuTableView.sectionHeaderTopPadding = 0;
    self.menuTableView.accessibilityIdentifier = @"grouped-action-menu";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.menuTableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self updateScrolling];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateScrolling];
}

- (void)updateScrolling {
    self.menuTableView.scrollEnabled = self.menuTableView.contentSize.height + 16 > self.menuTableView.bounds.size.height;
    self.menuTableView.alwaysBounceVertical = NO;
}

- (void)startNewSection {
    // MenuViewController.m keeps item indices stable for checked rows and segmented-control callbacks.
    if (self.items.count > 0) [self.sectionStarts addIndex:self.items.count];
}

- (NSUInteger)startOfSection:(NSInteger)section {
    NSUInteger start = self.sectionStarts.firstIndex;
    for (NSInteger index = 0; index < section; index++) start = [self.sectionStarts indexGreaterThanIndex:start];
    return start;
}

- (NSUInteger)itemIndexAtIndexPath:(NSIndexPath *)indexPath {
    return [self startOfSection:indexPath.section] + indexPath.row;
}

- (void)setCheckedRow:(NSInteger)checkedRow {
    if (_checkedRow == checkedRow) return;
    _checkedRow = checkedRow;
    if (!self.isViewLoaded) return;

    // MenuViewController.m updates persistent submenu checks without replacing their visible cells.
    for (NSIndexPath *indexPath in self.menuTableView.indexPathsForVisibleRows) {
        UITableViewCell *cell = [self.menuTableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = [self itemIndexAtIndexPath:indexPath] == checkedRow ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (CGSize)preferredContentSize {
    CGSize size = CGSizeMake(280.0, 16.0);
    UIFont *font = MenuTableViewCell.menuFont;
    
    for (NSDictionary *item in self.items) {
        if (item[MenuSegmentTitles]) {
            size.width = MAX(size.width, 280.0);
        } else {
            size.width = MAX(size.width, [item[MenuTitle] sizeWithAttributes:@{NSFontAttributeName : font}].width + 80);
        }
    }
    
    UIWindow *window = self.viewIfLoaded.window ?: self.presentingViewController.view.window;
    CGSize available = window ? window.bounds.size : UIScreen.mainScreen.bounds.size;
    size.width = MIN(size.width, MIN(320, MAX(200, available.width - 32)));
    for (NSDictionary *item in self.items) {
        size.height += item[MenuSegmentTitles] ? kMenuOptionHeight : [MenuTableViewCell heightForTitle:item[MenuTitle] width:size.width];
    }
    size.height += MAX(0, [self numberOfSectionsInTableView:self.menuTableView] - 1) * 12;
    size.height = MIN(size.height, MAX(160, available.height - 100));
    
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

- (void)addFeedListTitle:(NSString *)title iconName:(NSString *)iconName selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemHandler)handler {
    // MenuViewController.m matches Android's 18-point, aspect-fit, monochrome feed menu icons.
    UIImage *source = [UIImage imageNamed:iconName];
    CGFloat side = 18.0;
    CGFloat scale = side / MAX(source.size.width, source.size.height);
    CGSize size = CGSizeMake(source.size.width * scale, source.size.height * scale);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [source drawInRect:CGRectMake((side - size.width) / 2, (side - size.height) / 2, size.width, size.height)];
    }];
    [self.items addObject:@{MenuTitle: title, MenuIcon: [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate],
                           MenuFeedListIcon: @YES, MenuDestructive: @NO,
                           MenuSelectionShouldDismiss: @(selectionShouldDismiss), MenuHandler: handler}];
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

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName iconColor:(UIColor *)iconColor submenuTitles:(NSArray *)titles values:(NSArray *)values overrideSelectedValue:(id)overrideSelectedValue defaultValue:(id)defaultValue preferenceKey:(NSString *)preferenceKey selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSubmenuHandler)handler {
    __weak MenuViewController *weakParentController = self;
    UIImage *image = [Utilities imageWithImage:[UIImage imageNamed:iconName] convertToSize:CGSizeMake(20.0, 20.0)];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    [self addTitle:title iconImage:image iconColor:iconColor destructive:NO selectionShouldDismiss:NO handler:^{
        MenuViewController *viewController = [MenuViewController new];
        __weak MenuViewController *weakSubmenuController = viewController;
        viewController.title = title;
        id selectedValue = overrideSelectedValue ?: [[NSUserDefaults standardUserDefaults] objectForKey:preferenceKey] ?: defaultValue;
        
        for (NSUInteger idx = 0; idx < titles.count; idx++) {
            NSString *submenuTitle = titles[idx];
            id submenuValue = values[idx];
            BOOL selected = [submenuValue isEqual:selectedValue];
            
            [viewController addTitle:submenuTitle iconName:nil iconColor:iconColor selectionShouldDismiss:selectionShouldDismiss handler:^{
                [[NSUserDefaults standardUserDefaults] setObject:submenuValue forKey:preferenceKey];
                weakSubmenuController.checkedRow = idx;
                handler(submenuValue);
            }];
            
            if (selected) {
                viewController.checkedRow = idx;
            }
        }
        
        [weakParentController.navigationController showViewController:viewController sender:weakParentController];
    }];
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
    
    [self addSegmentedControlWithTitles:titles values:values defaultValue:defaultValue selectValue:value preferenceKey:preferenceKey selectionShouldDismiss:selectionShouldDismiss handler:handler];
}

- (void)addSegmentedControlWithTitles:(NSArray *)titles values:(NSArray *)values defaultValue:(NSString *)defaultValue selectValue:(id)value preferenceKey:(NSString *)preferenceKey selectionShouldDismiss:(BOOL)selectionShouldDismiss handler:(MenuItemSegmentedHandler)handler {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
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

    UIImage *image = [UIImage imageNamed:name];

    // Scale to a consistent size that fits well in the segmented control
    CGFloat size = 22.0;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomMac) {
        size = 20.0;
    }

    image = [Utilities imageWithImage:image convertToSize:CGSizeMake(size, size)];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    return image;
}

- (UITableViewCell *)makeThemeSegmentedTableCell {
    UITableViewCell *cell = [UITableViewCell new];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;

    // Determine which theme segment to select based on user's actual choice
    // If user chose Auto, show Auto selected (not the resolved theme)
    NSString *themeStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme_style"];
    NSUInteger valueIndex;

    if ([themeStyle isEqualToString:@"auto"] || themeStyle == nil) {
        valueIndex = 0; // Auto
    } else {
        // User chose light or dark mode - show the specific variant
        NSString *effectiveTheme = [ThemeManager themeManager].effectiveTheme;
        NSArray *values = @[ThemeStyleAuto, ThemeStyleLight, ThemeStyleSepia, ThemeStyleMedium, ThemeStyleDark];
        valueIndex = [values indexOfObject:effectiveTheme];
        if (valueIndex == NSNotFound) {
            valueIndex = 0;
        }
    }
    
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake(8, 7, cell.frame.size.width - 8 * 2, kMenuOptionHeight - 7 * 2)];
    segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [segmentedControl addTarget:self action:@selector(changeTheme:) forControlEvents:UIControlEventValueChanged];

    UIImage *lightImage = [self themeImageWithName:@"theme_color_light" selected:NO];
    UIImage *sepiaImage = [self themeImageWithName:@"theme_color_sepia" selected:NO];
    UIImage *mediumImage = [self themeImageWithName:@"theme_color_medium" selected:NO];
    UIImage *darkImage = [self themeImageWithName:@"theme_color_dark" selected:NO];

    [segmentedControl insertSegmentWithTitle:@"Auto" atIndex:0 animated:NO];
    [segmentedControl insertSegmentWithImage:lightImage atIndex:1 animated:NO];
    [segmentedControl insertSegmentWithImage:sepiaImage atIndex:2 animated:NO];
    [segmentedControl insertSegmentWithImage:mediumImage atIndex:3 animated:NO];
    [segmentedControl insertSegmentWithImage:darkImage atIndex:4 animated:NO];

#if !TARGET_OS_MACCATALYST
    segmentedControl.backgroundColor = UIColorFromRGB(0xeeeeee);
#endif
    [segmentedControl setTitleTextAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"WhitneySSm-Medium" size:12.0f]} forState:UIControlStateNormal];

    [[ThemeManager themeManager] updateSegmentedControl:segmentedControl];

    segmentedControl.selectedSegmentIndex = valueIndex;

    // Show white pill for all selections (Auto and color themes)
    segmentedControl.selectedSegmentTintColor = UIColorFromLightSepiaMediumDarkRGB(0xdce6f0, 0xFAF5ED, 0xbbbbbb, 0x888890);

    [cell.contentView addSubview:segmentedControl];

    return cell;
}

- (IBAction)changeTheme:(UISegmentedControl *)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSInteger selectedIndex = sender.selectedSegmentIndex;

    // Update the new theme system: theme_style + theme_light/theme_dark
    switch (selectedIndex) {
        case 0:
            // Auto - follow system
            [userPreferences setObject:@"auto" forKey:@"theme_style"];
            break;
        case 1:
            // Light (Normal)
            [userPreferences setObject:@"light" forKey:@"theme_style"];
            [userPreferences setObject:ThemeStyleLight forKey:@"theme_light"];
            break;
        case 2:
            // Sepia
            [userPreferences setObject:@"light" forKey:@"theme_style"];
            [userPreferences setObject:ThemeStyleSepia forKey:@"theme_light"];
            break;
        case 3:
            // Gray (Medium)
            [userPreferences setObject:@"dark" forKey:@"theme_style"];
            [userPreferences setObject:ThemeStyleMedium forKey:@"theme_dark"];
            break;
        case 4:
            // Black (Dark)
            [userPreferences setObject:@"dark" forKey:@"theme_style"];
            [userPreferences setObject:ThemeStyleDark forKey:@"theme_dark"];
            break;

        default:
            break;
    }

    [userPreferences synchronize];
    [[ThemeManager themeManager] updateTheme];

    self.menuTableView.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    self.navigationController.popoverPresentationController.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    [self.menuTableView reloadData];
}

- (UITableViewCell *)makeSegmentedTableCellForItem:(NSDictionary *)item forRow:(NSUInteger)row {
    UITableViewCell *cell = [UITableViewCell new];
    cell.frame = CGRectMake(0.0, 0.0, 240.0, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;

    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake(8, 7, cell.frame.size.width - 8 * 2, kMenuOptionHeight - 7 * 2)];
    segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    NSArray *segmentTitles = item[MenuSegmentTitles];
    
    for (NSUInteger idx = 0; idx < segmentTitles.count; idx++) {
        NSString *title = segmentTitles[idx];
        
        if ([title hasSuffix:@".png"]) {
            UIImage *image = [UIImage imageNamed:title];
            
            if (image.size.width > 50) {
                image = [Utilities imageWithImage:image convertToSize:CGSizeMake(16, 16)];
            }
            
            [segmentedControl insertSegmentWithImage:image atIndex:idx animated:NO];
        } else {
            [segmentedControl insertSegmentWithTitle:title atIndex:idx animated:NO];
        }
        
        [segmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:idx];
    }
    
    segmentedControl.apportionsSegmentWidthsByContent = YES;
    segmentedControl.selectedSegmentIndex = [item[MenuSegmentIndex] integerValue];
    segmentedControl.tag = row;
#if !TARGET_OS_MACCATALYST
    segmentedControl.backgroundColor = UIColorFromRGB(0xeeeeee);
#endif
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
    [self showFromNavigationController:navigationController barButtonItem:barButtonItem sourceView:nil sourceRect:CGRectZero permittedArrowDirections:permittedArrowDirections];
}

- (void)showFromNavigationController:(UINavigationController *)navigationController barButtonItem:(UIBarButtonItem *)barButtonItem sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections {
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
    popoverPresentationController.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    popoverPresentationController.permittedArrowDirections = permittedArrowDirections;
    popoverPresentationController.barButtonItem = barButtonItem;
    popoverPresentationController.sourceView = sourceView;
    popoverPresentationController.sourceRect = sourceRect;
    
    [navigationController presentViewController:embeddedNavController animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return MAX(1, [self.sectionStarts countOfIndexesInRange:NSMakeRange(0, self.items.count)]);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger start = [self startOfSection:section];
    NSUInteger next = [self.sectionStarts indexGreaterThanIndex:start];
    return MIN(next, self.items.count) - start;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return section == 0 ? 0 : 12;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) return nil;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 12)];
    header.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14, 5.5, MAX(0, header.bounds.size.width - 28), 1 / MAX(1, self.traitCollection.displayScale))];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    line.backgroundColor = MenuTableViewCell.menuSeparatorColor;
    [header addSubview:line];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return 0; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger itemIndex = [self itemIndexAtIndexPath:indexPath];
    NSDictionary *item = self.items[itemIndex];
    
    if (item[MenuThemeSegment]) {
        return [self makeThemeSegmentedTableCell];
    } else if (item[MenuSegmentTitles]) {
        return [self makeSegmentedTableCellForItem:item forRow:itemIndex];
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
        cell.tintColor = UIColorFromRGB(0x303030);
        cell.textLabel.text = title;
        cell.imageView.image = item[MenuIcon];
        
        cell.imageView.tintColor = MenuTableViewCell.menuIconColor;
        
        if (self.checkedRow == itemIndex) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[[self itemIndexAtIndexPath:indexPath]];
    return item[MenuSegmentTitles] ? kMenuOptionHeight : [MenuTableViewCell heightForTitle:item[MenuTitle] width:tableView.bounds.size.width];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[[self itemIndexAtIndexPath:indexPath]];
    
    if (item[MenuSegmentTitles]) {
        return nil;
    } else {
        return indexPath;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[[self itemIndexAtIndexPath:indexPath]];
    
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
