//
//  FeedChooserViewController.m
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "FeedChooserViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NSObject+SBJSON.h"
#import "MenuViewController.h"
#import "FeedChooserTitleView.h"
#import "FeedChooserViewCell.h"
#import "FeedChooserItem.h"

static const CGFloat kTableViewRowHeight = 31.0;
static const CGFloat kFolderTitleHeight = 36.0;

@interface FeedChooserViewController () <FeedChooserTitleDelegate>

@property (nonatomic, strong) UIBarButtonItem *selectionItem;
@property (nonatomic, strong) UIBarButtonItem *sortItem;
@property (nonatomic, strong) UIBarButtonItem *moveItem;
@property (nonatomic, strong) UIBarButtonItem *deleteItem;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *indexTitles;
@property (nonatomic, strong) NSArray *folders;
@property (nonatomic) FeedChooserSort sort;
@property (nonatomic) BOOL ascending;
@property (nonatomic) BOOL flat;
@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;

@end

@implementation FeedChooserViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    self.selectionItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"barbutton_selection.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showSelectionMenu)];
    self.sortItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"barbutton_sort.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showSortMenu)];
    
    if (self.operation == FeedChooserOperationOrganizeSites) {
        self.moveItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"menu_icn_move.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showMoveMenu)];
        self.deleteItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"menu_icn_delete.png"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteFeeds)];
        
        self.navigationItem.leftBarButtonItems = @[self.selectionItem, self.sortItem];
        self.navigationItem.rightBarButtonItems = @[doneItem, self.deleteItem, self.moveItem];
        self.navigationItem.title = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"Organize Sites" : @"Organize";
    } else {
        self.navigationItem.leftBarButtonItems = @[self.selectionItem, self.sortItem];
        self.navigationItem.rightBarButtonItem = doneItem;
        self.navigationItem.title = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"Mute Sites" : @"Mute";
    }
    
    self.tableView.editing = YES;
    self.tableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.tableView.separatorColor = UIColorFromRGB(0x909090);
    self.tableView.sectionIndexColor = UIColorFromRGB(0x303030);
    self.tableView.sectionIndexBackgroundColor = UIColorFromRGB(0xDCDFD6);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedLoadingFeedsNotification:) name:@"FinishedLoadingFeedsNotification" object:nil];
    
    [self rebuildItemsAnimated:NO];
    
    if (self.operation == FeedChooserOperationMuteSites) {
        #warning *** to be implemented ***: select only the unmuted sites
        
        [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
            [self select:YES section:section];
        }];
    }
}

- (void)rebuildItemsAnimated:(BOOL)animated {
    NewsBlurAppDelegate *appDelegate = self.appDelegate;
    FeedChooserItem *section = nil;
    
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *indexTitles = [NSMutableArray array];
    NSMutableArray *folders = [NSMutableArray array];
    
    if (self.flat) {
        section = [FeedChooserItem makeFolderWithTitle:@""];
        [sections addObject:section];
    }
    
    for (NSString *folderName in appDelegate.dictFoldersArray) {
        if (![folderName hasPrefix:@"river_"] && ![folderName isEqualToString:@"read_stories"] && ![folderName isEqualToString:@"saved_stories"]) {
            FeedChooserItem *folder = [FeedChooserItem makeFolderWithTitle:folderName];
            [folders addObject:folder];
            
            if (!self.flat) {
                section = folder;
                [sections addObject:section];
                [indexTitles addObject:section.title.length ? [section.title substringToIndex:1] : @"-"];
            }
            
            for (id feedId in appDelegate.dictFolders[folderName]) {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
                
                if (![appDelegate isSocialFeed:feedIdStr] && ![appDelegate isSavedFeed:feedIdStr]) {
                    [section addItemWithInfo:appDelegate.dictFeeds[feedIdStr]];
                }
            }
        }
    }
    
    self.sections = sections;
    self.indexTitles = indexTitles;
    self.folders = folders;
    
    [self.tableView reloadData];
    [self sortItemsAnimated:animated];
    [self updateControls];
}

- (void)sortItemsAnimated:(BOOL)animated {
    [self.tableView beginUpdates];
    
    NSString *key = [FeedChooserItem keyForSort:self.sort];
    
    [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
        NSArray *oldItems = [NSArray arrayWithArray:folder.contents];
        
        if (self.sort == FeedChooserSortName) {
            [folder.contents sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:key ascending:self.ascending selector:@selector(caseInsensitiveCompare:)], [NSSortDescriptor sortDescriptorWithKey:@"info.feed_title" ascending:self.ascending selector:@selector(caseInsensitiveCompare:)]]];
        } else {
            [folder.contents sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:key ascending:self.ascending], [NSSortDescriptor sortDescriptorWithKey:@"info.feed_title" ascending:self.ascending selector:@selector(caseInsensitiveCompare:)]]];
        }
        
        if (animated) {
            [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
                NSUInteger newRow = [folder.contents indexOfObject:oldItems[row]];
                
                [self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] toIndexPath:[NSIndexPath indexPathForRow:newRow inSection:section]];
            }];
        }
    }];
    
    [self.tableView endUpdates];
    
    if (!animated) {
        [self.tableView reloadData];
    }
}

- (FeedChooserItem *)itemForIndexPath:(NSIndexPath *)indexPath {
    FeedChooserItem *folder = self.sections[indexPath.section];
    
    return folder.contents[indexPath.row];
}

- (NSIndexPath *)indexPathForItem:(FeedChooserItem *)item {
    __block NSIndexPath *indexPath = nil;
    
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *localIndexPath, FeedChooserItem *localItem) {
        if ([item.identifier isEqualToString:localItem.identifier]) {
            indexPath = localIndexPath;
        }
    }];
    
    return indexPath;
}

- (NewsBlurAppDelegate *)appDelegate {
    return [NewsBlurAppDelegate sharedAppDelegate];
}

- (void)enumerateSectionsUsingBlock:(void (^)(NSUInteger section, FeedChooserItem *folder))block {
    if (!block) {
        return;
    }
    
    for (NSUInteger section = 0; section < self.sections.count; section++) {
        FeedChooserItem *folder = self.sections[section];
        
        block(section, folder);
    }
}

- (void)enumerateRowsInSection:(NSUInteger)section usingBlock:(void (^)(NSUInteger row, FeedChooserItem *item))block {
    if (!block) {
        return;
    }
    
    FeedChooserItem *folder = self.sections[section];
    
    for (NSUInteger row = 0; row < folder.contents.count; row++) {
        FeedChooserItem *item = folder.contents[row];
        
        block(row, item);
    }
}

- (void)enumerateAllRowsUsingBlock:(void (^)(NSIndexPath *indexPath, FeedChooserItem *item))block {
    if (!block) {
        return;
    }
    
    [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
        [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
            
            block(indexPath, item);
        }];
    }];
}

- (BOOL)isSelectionInSection:(NSUInteger)section {
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    
    for (NSIndexPath *indexPath in selection) {
        if (indexPath.section == section) {
            return YES;
        }
    }
    
    return NO;
}

- (NSArray *)selectedItemIdentifiers {
    NSMutableArray *identifiers = [NSMutableArray array];
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    
    for (NSIndexPath *indexPath in selection) {
        [identifiers addObject:[self itemForIndexPath:indexPath].identifier];
    }
    
    return identifiers;
}

- (void)selectItemsWithIdentifiers:(NSArray *)itemIdentifiers animated:(BOOL)animated {
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *indexPath, FeedChooserItem *item) {
        if ([itemIdentifiers containsObject:item.identifier]) {
            [self.tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:UITableViewScrollPositionNone];
        } else {
            [self.tableView deselectRowAtIndexPath:indexPath animated:animated];
        }
    }];
    
    [self updateControls];
}

- (void)select:(BOOL)select section:(NSUInteger)section {
    [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
        if (select) {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] animated:YES scrollPosition:UITableViewScrollPositionNone];
        } else {
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] animated:YES];
        }
    }];
    
    [self updateControls];
}

- (void)updateControls {
    BOOL hasSelection = self.tableView.indexPathsForSelectedRows.count > 0;
    
    self.moveItem.enabled = hasSelection;
    self.deleteItem.enabled = hasSelection;
}

#pragma mark - Title delegate methods

- (void)didSelectTitleView:(UIButton *)sender {
    NSUInteger section = sender.tag;
    BOOL select = ![self isSelectionInSection:section];
    
    [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
        [self select:select section:section];
    }];
}

#pragma mark - Target/action methods

- (void)showSelectionMenu {
    MenuViewController *viewController = [MenuViewController new];
    
    [viewController addTitle:@"Select All" iconName:@"barbutton_selection.png" selectionShouldDismiss:YES handler:^{
        [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
            [self select:YES section:section];
        }];
    }];
    
    [viewController addTitle:@"Select None" iconName:@"barbutton_selection_off.png" selectionShouldDismiss:YES handler:^{
        [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
            [self select:NO section:section];
        }];
    }];
    
    [viewController showFromNavigationController:self.navigationController barButtonItem:self.selectionItem];
}

- (void)sort:(FeedChooserSort)sort {
    NSArray *identifiers = [self selectedItemIdentifiers];
    
    // Rebuild to get the new info values (which also quietly sorts in the old order), then sort with animation:
    [self rebuildItemsAnimated:NO];
    self.sort = sort;
    [self sortItemsAnimated:YES];
    
    [self selectItemsWithIdentifiers:identifiers animated:NO];
}

- (void)showSortMenu {
    MenuViewController *viewController = [MenuViewController new];
    
    [viewController addTitle:@"Name" iconName:@"barbutton_sort.png" selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortName];
    }];
    
    [viewController addTitle:@"Subscribers" iconName:@"barbutton_sort.png" selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortSubscribers];
    }];
    
    [viewController addTitle:@"Stories per Month" iconName:@"barbutton_sort.png" selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortFrequency];
    }];
    
    [viewController addTitle:@"Most Recent Story" iconName:@"barbutton_sort.png" selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortRecency];
    }];
    
    [viewController addTitle:@"Number of Opens" iconName:@"barbutton_sort.png" selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortOpens];
    }];
    
    viewController.checkedRow = self.sort;
    
    [viewController addSegmentedControlWithTitles:@[@"Ascending", @"Descending"] selectIndex:self.ascending ? 0 : 1 selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
        NSArray *identifiers = [self selectedItemIdentifiers];
        self.ascending = selectedIndex == 0;
        [self sortItemsAnimated:YES];
        [self selectItemsWithIdentifiers:identifiers animated:NO];
    }];
    
    [viewController addSegmentedControlWithTitles:@[@"Nested", @"Flat"] selectIndex:self.flat ? 1 : 0 selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
        NSArray *identifiers = [self selectedItemIdentifiers];
        self.flat = selectedIndex == 1;
        [self rebuildItemsAnimated:YES];
        [self selectItemsWithIdentifiers:identifiers animated:NO];
    }];
    
    [viewController showFromNavigationController:self.navigationController barButtonItem:self.sortItem];
}

- (void)moveToFolder:(FeedChooserItem *)toFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Moving...";
    
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    __block NSUInteger remaining = selection.count;
    
    for (NSIndexPath *indexPath in selection) {
        FeedChooserItem *fromFolder = self.sections[indexPath.section];
        FeedChooserItem *item = fromFolder.contents[indexPath.row];
        
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/move_feed_to_folder", self.appDelegate.url];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:fromFolder.identifier forKey:@"in_folder"];
        [request setPostValue:toFolder.identifier forKey:@"to_folder"];
        [request setPostValue:item.identifier forKey:@"feed_id"];
        [request setDelegate:self];
        [request setCompletionBlock:^(void) {
            remaining--;
            
            if (remaining <= 0) {
                HUD.labelText = @"Reloading...";
                [self.appDelegate reloadFeedsView:YES];
            }
        }];
        [request setTimeOutSeconds:30];
        [request startAsynchronous];
    }
}

/* this is what I want to do, but I don't think I got the parameters right, as it doesn't do anything (no error either):
- (void)moveToFolder:(FeedChooserItem *)toFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Moving...";
    
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    NSMutableArray *feedsByFolder = [NSMutableArray arrayWithCapacity:selection.count];
    
    for (NSIndexPath *indexPath in selection) {
        FeedChooserItem *fromFolder = self.sections[indexPath.section];
        FeedChooserItem *item = fromFolder.contents[indexPath.row];
        
        [feedsByFolder addObject:@{@"feed_id" : item.identifier, @"in_folder" : fromFolder.identifier}];
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/move_feeds_by_folder_to_folder", self.appDelegate.url];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedsByFolder.JSONRepresentation forKey:@"feeds_by_folder"];
    [request setPostValue:toFolder.identifier forKey:@"to_folder"];
    [request setDelegate:self];
    [request setCompletionBlock:^(void) {
        HUD.labelText = @"Reloading...";
        [self.appDelegate reloadFeedsView:YES];
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}
*/

- (void)showMoveMenu {
    MenuViewController *viewController = [MenuViewController new];
    
    for (FeedChooserItem *folder in self.folders) {
        NSString *title = folder.title;
        NSString *iconName = @"menu_icn_move.png";
        
        if (!title.length) {
            title = @"Top Level";
            iconName = @"menu_icn_all.png";
        } else {
            NSArray *components = [title componentsSeparatedByString:@" - "];
            title = components.lastObject;
            for (NSUInteger idx = 0; idx < components.count; idx++) {
                title = [@"\t" stringByAppendingString:title];
            }
        }
        
        [viewController addTitle:title iconName:iconName selectionShouldDismiss:YES handler:^{
            [self moveToFolder:folder];
        }];
    }
    
    [viewController showFromNavigationController:self.navigationController barButtonItem:self.moveItem];
}

- (void)deleteFeeds {
    MenuViewController *viewController = [MenuViewController new];
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    
    NSString *title = selection.count == 1 ? @"Delete selected site?" : [NSString stringWithFormat:@"Delete %@ sites?", @(selection.count)];
    
    [viewController addTitle:title iconName:@"menu_icn_delete.png" selectionShouldDismiss:YES handler:^{
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        HUD.labelText = @"Deleting...";
        __block NSUInteger remaining = selection.count;
        
        for (NSIndexPath *indexPath in selection) {
            FeedChooserItem *folder = self.sections[indexPath.section];
            FeedChooserItem *item = folder.contents[indexPath.row];
            
            NSString *theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/delete_feed", self.appDelegate.url];
            NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
            
            __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
            [request setDelegate:self];
            [request addPostValue:item.identifier forKey:@"feed_id"];
            [request addPostValue:folder.identifier forKey:@"in_folder"];
            [request setCompletionBlock:^(void) {
                remaining--;
                
                if (remaining <= 0) {
                    HUD.labelText = @"Reloading...";
                    [self.appDelegate reloadFeedsView:YES];
                }
            }];
            [request setTimeOutSeconds:30];
            [request setTag:item.identifier.integerValue];
            [request startAsynchronous];
        }
    }];
    
    [viewController showFromNavigationController:self.navigationController barButtonItem:self.deleteItem];
}

- (void)finishedLoadingFeedsNotification:(NSNotification *)note {
    [self rebuildItemsAnimated:YES];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)done {
    if (self.operation == FeedChooserOperationMuteSites) {
        #warning *** to be implemented ***: save updated mute states
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.appDelegate.hasNoSites) {
        return 0;
    } else {
        return self.sections.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    FeedChooserItem *item = self.sections[section];
    return item.title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    FeedChooserItem *item = self.sections[section];
    NSArray *contents = item.contents;
    return contents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIndentifier = @"FeedChooserCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (!cell) {
        cell = [[FeedChooserViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIndentifier];
    }
    
    FeedChooserItem *item = [self itemForIndexPath:indexPath];
    
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = [item detailForSort:self.sort];
    cell.imageView.image = item.icon;
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CGRect rect = CGRectMake(0.0, 0.0, tableView.frame.size.width, kFolderTitleHeight);
    FeedChooserTitleView *titleView = [[FeedChooserTitleView alloc] initWithFrame:rect];
    FeedChooserItem *item = self.sections[section];
    
    titleView.delegate = self;
    titleView.section = section;
    titleView.title = item.title;
    
    return titleView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    FeedChooserItem *item = self.sections[section];
    
    return !item.title.length ? 0.0 : kFolderTitleHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kTableViewRowHeight;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)theTableView {
    return self.indexTitles;
}

- (NSInteger)tableView:(UITableView *)theTableView sectionForSectionIndexTitle:(NSString *)indexTitle atIndex:(NSInteger)indexIndex {
    return indexIndex;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self updateControls];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self updateControls];
}

@end
